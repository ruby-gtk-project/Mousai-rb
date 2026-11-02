# frozen_string_literal: true

# Drives the main window: the empty state, songs appearing in the grid, the
# search's empty state, selection mode, the song page and the lyrics page.

require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("mousai-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("mousai-data")

require_relative "gtk_driver"
require_relative "../lib/mousai"

app = Mousai::Application.new

def sample_song(title, artist, **rest)
  Mousai::Song.build(
    id:     Mousai::Uid.from_prefixed("test", title),
    title:  title,
    artist: artist,
    album:  "An Album",
    **rest,
  ).tap { |song| song.last_heard = Mousai::DateTime.now_utc }
end

GtkDriver.drive(app, shots: "tmp/shots") do |d, application|
  d.window { application.window.root }
  view = -> { application.window.history_view }

  d.step("the window opens on the empty state") do
    d.check("history is empty") { application.song_list.empty? }
    d.check("empty page is showing") do
      view.call.content_stack.visible_child == view.call.content_empty_page
    end
    d.shot("01-empty")
  end

  d.step("two songs are added to the history") do
    application.song_list.insert_many(
      [
        sample_song("Never Gonna Give You Up", "Rick Astley", lyrics: "We're no strangers to love"),
        sample_song("Africa", "Toto", release_date: "1982-10-30"),
      ],
    )
  end

  d.step("the grid shows them") do
    d.check("two songs in the list") { application.song_list.n_items == 2 }
    d.check("two rows in the selection model") { view.call.selection_model.n_items == 2 }
    d.check("grid page is showing") do
      view.call.content_stack.visible_child == view.call.content_main_page
    end
    d.shot("02-grid")
  end

  d.step("searching for an artist filters the grid") do
    view.call.search_bar.search_mode = true
    view.call.search_entry.text = "toto"
  end

  d.step("only the match is left") do
    d.check("one row left") { view.call.filter_model.n_items == 1 }
    d.check("grid page still showing") do
      view.call.content_stack.visible_child == view.call.content_main_page
    end
    d.shot("03-search")
  end

  d.step("a search that matches nothing") do
    view.call.search_entry.text = "zzzzz"
  end

  d.step("shows the no-results page") do
    d.check("no rows left") { view.call.filter_model.n_items.zero? }
    d.check("no-results page is showing") do
      view.call.content_stack.visible_child == view.call.content_empty_search_result_page
    end
    d.shot("04-no-results")
  end

  d.step("the search is cleared") do
    view.call.search_entry.text = ""
    view.call.search_bar.search_mode = false
  end

  d.step("selection mode is entered and a song selected") do
    view.call.toggle_selection_mode_action.activate(nil)
    view.call.selection_model.select_item(0, false)
  end

  d.step("the selection header bar is up") do
    d.check("selection mode is active") { view.call.selection_mode_active? }
    d.check("selection header bar showing") do
      view.call.header_bar_stack.visible_child == view.call.selection_mode_header_bar
    end
    d.check("action bar revealed") { view.call.selection_mode_bar.revealed? }
    d.check("remove action enabled") { view.call.remove_selected_songs_action.enabled? }
    d.shot("05-selection")
  end

  d.step("the selected song is removed") do
    view.call.remove_selected_songs_action.activate(nil)
  end

  d.step("the undo toast is up and the song is gone") do
    d.check("one song left") { application.song_list.n_items == 1 }
    d.check("left the selection mode") { !view.call.selection_mode_active? }
    d.shot("06-removed")
  end

  d.step("the removal is undone") do
    view.call.selection_model # settle the model before the undo
    application.window.history_view.send(:undo_remove_songs)
  end

  d.step("both songs are back") do
    d.check("two songs again") { application.song_list.n_items == 2 }
    d.shot("07-undone")
  end

  d.step("a song page is pushed") do
    application.window.history_view.push_song_page(application.song_list.to_a.first)
  end

  d.step("the song page shows the song") do
    d.check("left the main page") { !view.call.on_navigation_main_page? }
    d.check("page title is artist - title") do
      view.call.root.visible_page.title.include?(" - ")
    end
    d.shot("08-song-page")
  end

  d.step("the lyrics page is pushed") do
    application.window.history_view.push_lyrics_page(
      application.song_list.to_a.find { |song| song.lyrics },
    )
  end

  d.step("the lyrics page shows the lyrics") do
    d.check("lyrics page is visible") do
      view.call.root.visible_page.title.include?("Lyrics")
    end
    d.shot("09-lyrics")
  end

  d.step("the pages are popped back") do
    view.call.pop_page
  end

  d.step("a song with external links is opened") do
    Mousai::ExternalLinks.new.tap do |links|
      links.insert(Mousai::ExternalLinks::SPOTIFY_URL, "https://spotify.link")
      links.insert(Mousai::ExternalLinks::YOUTUBE_SEARCH_TERM, "Toto - Africa")
      links.insert("unknown-provider", "https://nowhere.example")
    end.then do |links|
      application.song_list.insert(sample_song("Hold the Line", "Toto", external_links: links))
      application.window.history_view.push_song_page(
        application.song_list.get(
          Mousai::Uid.from_prefixed("test", "Hold the Line"),
        ),
      )
    end
  end

  d.step("its Listen group holds a tile per handled link") do
    application.window.history_view.instance_variable_get(:@song_pages).last.then do |page|
      d.check("two tiles") { page.external_links_box.observe_children.n_items == 2 }
      d.check("youtube tile searches") do
        page.instance_variable_get(:@external_link_tiles)
          .map(&:uri)
          .include?("https://www.youtube.com/results?search_query=Toto%20-%20Africa")
      end
    end
    d.shot("11-external-links")
  end

  d.step("the preferences dialog opens") do
    application.show_preferences_action.activate(nil)
  end

  d.step("preferences are showing") do
    d.shot("10-preferences")
  end
end
