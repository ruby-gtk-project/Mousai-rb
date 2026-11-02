# frozen_string_literal: true

require "gtk4"
require_relative "song"

module Mousai
  # Filters the song history by the search term.
  #
  # Ported from upstream's src/song_filter.rs, a `gtk::Filter` subclass that
  # matches all songs while the search is empty and fuzzy-matches otherwise,
  # and that reports how the change affects strictness so GTK can re-filter
  # only what it has to.
  #
  # Subclassing `Gtk::Filter` is not workable in the Ruby bindings, so this
  # wraps a `Gtk::CustomFilter` — which does receive the Ruby song objects —
  # and keeps the strictness bookkeeping.
  class SongFilter
    attr_reader :search

    def initialize
      @search = ""
    end

    def filter
      @filter ||= Gtk::CustomFilter.new do |song|
        @search.empty? || !song.fuzzy_match(@search).nil?
      end
    end

    # Upstream lower-cases the search before storing it, and so does this: the
    # song's fuzzy match is case-insensitive either way, but the stored value is
    # what the prefix comparisons below are made against.
    def search=(value)
      value.to_s.downcase.then do |new_search|
        unless new_search == @search
          change_for(new_search).then do |change|
            @search = new_search
            filter.changed(change)
          end
        end
      end
    end

    # True when the filter matches every song, which is upstream's
    # `FilterMatch::All` strictness.
    def matches_all? = @search.empty?

    private

      # Narrowing the search can only remove matches, widening it can only add
      # them, and an unrelated search can do both.
      def change_for(new_search)
        if new_search.empty?
          Gtk::FilterChange::LESS_STRICT
        elsif new_search.start_with?(@search)
          Gtk::FilterChange::MORE_STRICT
        elsif @search.start_with?(new_search)
          Gtk::FilterChange::LESS_STRICT
        else
          Gtk::FilterChange::DIFFERENT
        end
      end
  end
end
