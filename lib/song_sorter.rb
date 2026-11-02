# frozen_string_literal: true

require_relative "song"

module Mousai
  # Orders the song history.
  #
  # Ported from upstream's src/song_sorter.rs, a `gtk::Sorter` subclass that
  # orders by last heard — most recent first — while the search is empty, and
  # by fuzzy match score, highest first, while it is not.
  #
  # `Gtk::CustomSorter` hands its block raw pointers rather than the Ruby
  # objects in ruby-gnome, so this is a plain comparator: the song list sorts
  # its songs with it and splices the result into the list store the views
  # bind to. `#on_change` is what upstream's `changed` emission becomes.
  class SongSorter
    attr_reader :search

    def initialize
      @search = ""
      @change_listeners = []
    end

    def search=(value)
      value.to_s.then do |new_search|
        unless new_search == @search
          @search = new_search
          notify_change
        end
      end
    end

    def on_change(&block)
      @change_listeners << block
      block
    end

    # Upstream's `compare`: negative when song_1 comes first.
    def compare(song_1, song_2)
      if @search.empty?
        by_last_heard(song_1, song_2)
      else
        by_score(song_1, song_2)
      end
    end

    # Returns the songs in display order. Ruby's sort is not stable, so the
    # comparator falls back to the id, which keeps the order of equal songs
    # from shuffling between sorts.
    def sort(songs)
      songs.sort do |song_1, song_2|
        compare(song_1, song_2).then do |ordering|
          if ordering.zero?
            song_1.id.to_s <=> song_2.id.to_s
          else
            ordering
          end
        end
      end
    end

    private

      def notify_change
        @change_listeners.each { |listener| listener.call(self) }
      end

      # Most recently heard first; a song that was never heard sorts last.
      def by_last_heard(song_1, song_2)
        [song_2.last_heard, song_1.last_heard].then do |heard_2, heard_1|
          if heard_2.nil? && heard_1.nil?
            0
          elsif heard_2.nil?
            -1
          elsif heard_1.nil?
            1
          else
            heard_2 <=> heard_1
          end
        end
      end

      # Highest score first; a song that does not match sorts last.
      def by_score(song_1, song_2)
        [song_2.fuzzy_match(@search) || -1, song_1.fuzzy_match(@search) || -1].then do |score_2, score_1|
          score_2 <=> score_1
        end
      end
  end
end
