# frozen_string_literal: true

# Plain checks on the non-widget code: the value helpers, the song model and
# its fuzzy matching, the filter and sorter, the settings, and the database the
# history is loaded from and written back to.
#
# These need no display and no main loop. Run them with
# `nix develop --command ruby test/test_models.rb`; the UI is covered
# separately by test/drive_main_window.rb.

require "fileutils"
require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("mousai-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("mousai-data")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "database"
require "date_time"
require "external_links"
require "i18n"
require "migrations"
require "settings"
require "song_filter"
require "song_list"
require "song_sorter"
require "uid"
require "utils"

# The smallest runner that still reports usefully: a name, a result, and a
# non-zero exit when anything failed.
module Checks
  @failures = []
  @count = 0

  class << self
    attr_reader :failures, :count

    def check(description)
      @count += 1

      begin
        result = yield
      rescue StandardError => e
        result = false
        description = "#{description} (#{e.class}: #{e.message})"
      end

      if result
        puts("    ok   #{description}")
      else
        puts("    FAIL #{description}")
        @failures << description
      end
    end

    def group(name)
      puts(name)
      yield
    end

    def report
      puts("")
      puts("#{@count - @failures.length} of #{@count} checks passed")
      @failures.empty?
    end
  end
end

def check(description, &block) = Checks.check(description, &block)
def group(name, &block) = Checks.group(name, &block)

def song(title, artist, **rest)
  Mousai::Song.build(
    id:     Mousai::Uid.from_prefixed("test", title),
    title:  title,
    artist: artist,
    album:  "An Album",
    **rest,
  )
end

group("Uid") do
  check("from keeps the string") { Mousai::Uid.from("A").to_s == "A" }
  check("from_prefixed joins with a dash") { Mousai::Uid.from_prefixed("a", "BB8").to_s == "a-BB8" }
  check("equal ids compare equal") { Mousai::Uid.from("A") == Mousai::Uid.from("A") }
  check("different ids do not") { Mousai::Uid.from("A") != Mousai::Uid.from("B") }
  check("generated ids are unique") do
    1000.times.map { Mousai::Uid.generate.to_s }.uniq.length == 1000
  end
  check("ids hash by their string") do
    { Mousai::Uid.from("A") => 1 }[Mousai::Uid.from("A")] == 1
  end
end

group("DateTime") do
  check("round-trips iso8601") do
    Mousai::DateTime.from_iso8601("2022-07-28T08:23:28.623259+08")
      .format_iso8601 == "2022-07-28T08:23:28.623259+08:00"
  end
  check("rejects a bare year") do
    begin
      Mousai::DateTime.from_iso8601("2022")
      false
    rescue ArgumentError
      true
    end
  end
  check("today reads as today") { Mousai::DateTime.now_utc.to_local.fuzzy_display.start_with?("today at ") }
  check("an old date reads as a date") do
    Mousai::DateTime.from_iso8601("2001-07-08T10:00:00+00:00").fuzzy_display == "2001-07-08"
  end
  check("orders by time") do
    Mousai::DateTime.from_iso8601("2001-07-08T10:00:00+00:00") <
      Mousai::DateTime.from_iso8601("2001-07-09T10:00:00+00:00")
  end
end

group("Utils.consecutive_groups") do
  check("empty") { Mousai::Utils.consecutive_groups([]) == [] }
  check("one run") { Mousai::Utils.consecutive_groups([5, 4, 3, 2, 1]) == [[1, 5]] }
  check("many runs") do
    Mousai::Utils.consecutive_groups([12, 1, 3, 2, 3, 6, 5, 6, 3, 10, 12, 12]) ==
      [[1, 3], [5, 2], [10, 1], [12, 1]]
  end
end

group("I18n") do
  check("replaces one variable") { Mousai::I18n.gettext_f("{one} param", { "one" => "1" }) == "1 param" }
  check("replaces several") do
    Mousai::I18n.ngettext_f(
      "{a} and {b}",
      "{a} and {b}s",
      2,
      { "a" => "1", "b" => "2" },
    ) == "1 and 2s"
  end
  check("picks the singular for one") do
    Mousai::I18n.ngettext("song", "songs", 1) == "song"
  end
end

group("ExternalLinks") do
  links = Mousai::ExternalLinks.new
  check("insert reports a new key") { links.insert(Mousai::ExternalLinks::SPOTIFY_URL, "A") }
  check("insert reports a replaced key") do
    !links.insert(Mousai::ExternalLinks::SPOTIFY_URL, "B")
  end
  check("keeps insertion order") do
    links.insert(Mousai::ExternalLinks::AUD_D_URL, "C")
    links.to_a.map(&:key) == [Mousai::ExternalLinks::SPOTIFY_URL, Mousai::ExternalLinks::AUD_D_URL]
  end
  check("round-trips through a hash") do
    Mousai::ExternalLinks.from_h(links.to_h).to_h == links.to_h
  end
end

group("Song") do
  full = song(
    "Some song",
    "Someone",
    release_date:   "00-00-0000",
    album_art_link: "https://album.png",
    playback_link:  "https://test.mp3",
    lyrics:         "Some song lyrics",
    is_newly_heard: true,
  )

  check("carries its properties") do
    full.title == "Some song" && full.artist == "Someone" && full.album == "An Album" &&
      full.release_date == "00-00-0000" && full.lyrics == "Some song lyrics" && full.newly_heard?
  end
  check("artist_title_text is Artist - Title") { full.artist_title_text == "Someone - Some song" }
  check("round-trips through a hash") do
    Mousai::Song.from_h(full.to_h).to_h == full.to_h
  end
  check("matches on artist and title") { !full.fuzzy_match("someone some").nil? }
  check("does not match a non-subsequence") { full.fuzzy_match("zzz").nil? }
  check("scores a closer match higher") do
    full.fuzzy_match("someone") > full.fuzzy_match("sm")
  end
  check("an empty pattern matches") { full.fuzzy_match("") == 0 }
  check("notifies on last heard change") do
    changed = 0
    full.on_change { changed += 1 }
    full.last_heard = Mousai::DateTime.now_utc
    full.last_heard = full.last_heard
    changed == 1
  end
end

group("SongFilter and SongSorter") do
  filter = Mousai::SongFilter.new
  check("matches everything while empty") { filter.matches_all? }
  check("lower-cases the search") do
    filter.search = "TOTO"
    filter.search == "toto"
  end

  older = song("Africa", "Toto")
  older.last_heard = Mousai::DateTime.from_iso8601("2001-07-08T10:00:00+00:00")
  newer = song("Hold the Line", "Toto")
  newer.last_heard = Mousai::DateTime.from_iso8601("2024-07-08T10:00:00+00:00")

  sorter = Mousai::SongSorter.new
  check("sorts the most recently heard first") do
    sorter.sort([older, newer]).map(&:title) == ["Hold the Line", "Africa"]
  end
  check("sorts by score while searching") do
    sorter.search = "africa"
    sorter.sort([newer, older]).map(&:title) == ["Africa", "Hold the Line"]
  end
  check("notifies on a search change") do
    changed = 0
    sorter.on_change { changed += 1 }
    sorter.search = "toto"
    sorter.search = "toto"
    changed == 1
  end
end

group("Settings") do
  path = File.join(Dir.mktmpdir("mousai-settings"), "settings.json")
  settings = Mousai::Settings.new(path: path)

  check("defaults match the upstream schema") do
    settings["window-width"] == 768 && settings["window-height"] == 600 &&
      !settings.window_maximized? && settings.audio_source_type == "microphone" &&
      settings.aud_d_api_token == "" && settings.memory_list == []
  end
  check("values persist across instances") do
    settings.aud_d_api_token = "token"
    settings.audio_source_type = "desktop-audio"
    Mousai::Settings.new(path: path).then do |reloaded|
      reloaded.aud_d_api_token == "token" && reloaded.audio_source_type_position == 1
    end
  end
  check("rejects a value outside the schema's choices") do
    begin
      settings.audio_source_type = "telepathy"
      false
    rescue ArgumentError
      true
    end
  end
end

group("Database and SongList") do
  path = File.join(Dir.mktmpdir("mousai-db"), "db.json")
  database = Mousai::Database.new(path: path)
  list = Mousai::SongList.new(database: database)

  first = song("Africa", "Toto")
  first.last_heard = Mousai::DateTime.now_utc
  second = song("Hold the Line", "Toto")
  second.last_heard = Mousai::DateTime.now_utc

  check("inserting appends") { list.insert_many([first, second]) == 2 }
  check("inserting the same id updates") { list.insert_many([first]) == 0 }
  check("holds both songs") { list.n_items == 2 && !list.empty? }
  check("finds by id") { list.get(first.id).title == "Africa" && list.contains?(second.id) }
  check("the list store mirrors the list") { list.list_store.n_items == 2 }

  check("the history survives a reload") do
    Mousai::SongList.new(database: Mousai::Database.new(path: path)).load.then do |reloaded|
      reloaded.to_a.map(&:title).sort == ["Africa", "Hold the Line"]
    end
  end

  check("a song changing in place is written back") do
    list.get(first.id).newly_heard = true
    Mousai::SongList.new(database: Mousai::Database.new(path: path)).load.then do |reloaded|
      reloaded.get(first.id).newly_heard?
    end
  end

  check("removing returns the removed songs") do
    list.remove_many([first.id]).map(&:title) == ["Africa"]
  end
  check("removal reaches the database") do
    Mousai::SongList.new(database: Mousai::Database.new(path: path)).load.then do |reloaded|
      reloaded.n_items == 1 && !reloaded.contains?(first.id)
    end
  end
end

group("Migrations") do
  path = File.join(Dir.mktmpdir("mousai-migrations"), "db.json")
  database = Mousai::Database.new(path: path)
  ran = []

  Mousai::Migrations.new.tap do |migrations|
    migrations.add("first") { ran << "first" }
    migrations.add("second") { ran << "second" }
    migrations.run(database)
  end

  check("runs every pending migration") { ran == ["first", "second"] }
  check("records the version reached") { database.user_version == 2 }

  check("does not run them again") do
    Mousai::Migrations.new.tap do |migrations|
      migrations.add("first") { ran << "first" }
      migrations.add("second") { ran << "second" }
      migrations.run(Mousai::Database.new(path: path))
    end
    ran == ["first", "second"]
  end

  check("rejects a duplicate name") do
    begin
      Mousai::Migrations.new.add("one") {}.add("one") {}
      false
    rescue ArgumentError
      true
    end
  end
end

exit(Checks.report ? 0 : 1)
