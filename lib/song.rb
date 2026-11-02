# frozen_string_literal: true

require "gtk4"
require_relative "date_time"
require_relative "external_links"
require_relative "uid"

module Mousai
  # A recognized song.
  #
  # Ported from upstream's src/song.rs. Upstream is a GObject whose properties
  # are construct-only apart from `last-heard` and `is-newly-heard`; the two
  # mutable ones notify, which is how the history grid and the database follow
  # them. Here the class is a GLib::Object subclass — a plain Ruby object
  # cannot be put in a Gio::ListStore — with Ruby accessors, and the two
  # mutable ones call the change listeners the song list registers.
  class Song < GLib::Object
    type_register

    # The score a fuzzy match starts from, and the bonuses upstream's
    # SkimMatcherV2 awards: see #fuzzy_match.
    MATCH_SCORE = 16
    CONSECUTIVE_BONUS = 8
    WORD_START_BONUS = 8

    attr_reader :id, :title, :artist, :album, :release_date, :external_links
    attr_reader :album_art_link, :playback_link, :lyrics, :last_heard

    class << self
      # The builder upstream exposes as `Song::builder`. The id must be unique
      # to each song so the song list treats two songs as different.
      def build(id:, title:, artist:, album:, **rest)
        new(
          id:     id,
          title:  title,
          artist: artist,
          album:  album,
          **rest,
        )
      end

      # Reads back a song written by #to_h, with upstream's serde field names.
      def from_h(hash)
        new(
          id:             Uid.from(hash["id"]),
          title:          hash["title"].to_s,
          artist:         hash["artist"].to_s,
          album:          hash["album"].to_s,
          release_date:   hash["release_date"],
          external_links: ExternalLinks.from_h(hash["external_links"] || {}),
          album_art_link: hash["album_art_link"],
          playback_link:  hash["playback_link"],
          lyrics:         hash["lyrics"],
          last_heard:     hash["last_heard"].then { |raw| raw && DateTime.from_iso8601(raw) },
          is_newly_heard: hash["is_newly_heard"] == true,
        )
      end
    end

    def initialize(id:, title:, artist:, album:, **rest)
      super()
      @id = id
      @title = title.to_s
      @artist = artist.to_s
      @album = album.to_s
      @release_date = rest[:release_date]
      @external_links = rest[:external_links] || ExternalLinks.new
      @album_art_link = rest[:album_art_link]
      @playback_link = rest[:playback_link]
      @lyrics = rest[:lyrics]
      @last_heard = rest[:last_heard]
      @is_newly_heard = rest[:is_newly_heard] == true
      @change_listeners = []
    end

    def newly_heard? = @is_newly_heard

    # Upstream's `set_is_newly_heard`: setting the same value changes nothing
    # and notifies nobody.
    def newly_heard=(value)
      value.then do |newly_heard|
        unless newly_heard == @is_newly_heard
          @is_newly_heard = newly_heard
          notify_change
        end
      end
    end

    # Upstream's `set_last_heard`, with the same "same value changes nothing"
    # guard.
    def last_heard=(value)
      value.then do |last_heard|
        unless last_heard == @last_heard
          @last_heard = last_heard
          notify_change
        end
      end
    end

    # The song list binds to this to write the song back to the database when
    # one of its mutable properties changes — upstream does the same thing with
    # `connect_notify_local` in `SongList::bind_song_to_db`.
    def on_change(&block)
      @change_listeners << block
      block
    end

    def remove_change_listener(listener) = @change_listeners.delete(listener)

    # Returns the artist and title of the song as "Artist - Title".
    def artist_title_text = "#{@artist} - #{@title}"

    # Returns the score of the song against the pattern, or nil when it does
    # not match.
    #
    # Upstream uses fuzzy-matcher's SkimMatcherV2 over "<artist> <title>". That
    # crate is not available here, so this is a subsequence matcher with the
    # same shape of scoring: every matched character scores, characters matched
    # consecutively or at the start of a word score more, and a pattern that is
    # not a subsequence of the choice does not match at all. Case is ignored,
    # as the filter lower-cases its search term before setting it.
    def fuzzy_match(pattern)
      pattern.to_s.downcase.then do |needle|
        if needle.empty?
          0
        else
          score_against(needle)
        end
      end
    end

    # The song as a hash with upstream's serde field names, for the database.
    def to_h
      {
        "id"             => @id.to_s,
        "title"          => @title,
        "artist"         => @artist,
        "album"          => @album,
        "release_date"   => @release_date,
        "external_links" => @external_links.to_h,
        "album_art_link" => @album_art_link,
        "playback_link"  => @playback_link,
        "lyrics"         => @lyrics,
        "last_heard"     => @last_heard&.format_iso8601,
        "is_newly_heard" => @is_newly_heard,
      }
    end

    private

      def notify_change
        @change_listeners.each { |listener| listener.call(self) }
      end

      def score_against(needle)
        "#{@artist} #{@title}".downcase.then do |choice|
          walk(choice, needle)
        end
      end

      # Walks the choice once, taking each pattern character at its first
      # remaining occurrence, and adding up the score as it goes. A pattern
      # character with no occurrence left clears the position, which both ends
      # the walk and marks the whole match as failed.
      def walk(choice, needle)
        { position: 0, previous_index: nil, score: 0 }.tap do |state|
          needle.each_char do |char|
            advance(choice, char, state)

            unless state[:position]
              break
            end
          end
        end.then { |state| state[:position] && state[:score] }
      end

      def advance(choice, char, state)
        choice.index(char, state[:position]).then do |index|
          if index
            state[:score] += MATCH_SCORE +
              consecutive_bonus(state[:previous_index], index) +
              word_start_bonus(choice, index)
            state[:previous_index] = index
            state[:position] = index + 1
          else
            state[:position] = nil
          end
        end
      end

      def consecutive_bonus(previous_index, index)
        if previous_index == index - 1
          CONSECUTIVE_BONUS
        else
          0
        end
      end

      def word_start_bonus(choice, index)
        if index.zero? || choice[index - 1] == " "
          WORD_START_BONUS
        else
          0
        end
      end
  end
end
