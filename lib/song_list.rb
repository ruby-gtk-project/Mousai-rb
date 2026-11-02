# frozen_string_literal: true

require "gtk4"
require_relative "database"
require_relative "song"
require_relative "song_sorter"
require_relative "uid"

module Mousai
  # The song history.
  #
  # Ported from upstream's src/song_list.rs, a `gio::ListModel` over an
  # `IndexMap<Uid, Song>` that writes every insert, update and removal straight
  # through to the database, and that binds each song's notifications so a song
  # changing in place is written too.
  #
  # Reading a song back out of a GTK model can hand back a wrapper around freed
  # memory, so the ordered Ruby Array here — not the list store — is the source
  # of truth, and the store is only the view's copy. The display order lives in
  # the store because `Gtk::CustomSorter` is unusable in the Ruby bindings (see
  # SongSorter), so the sorter is applied here and spliced in.
  class SongList
    attr_reader :database, :sorter

    def initialize(database: nil, sorter: nil)
      @database = database || Database.new
      @sorter = sorter || SongSorter.new
      @ordered = []
      @by_id = {}
      @change_listeners = {}
      @items_changed_listeners = []
      @sorter.on_change { resort }
    end

    # Loads the history from the database — upstream's `load_from_env`.
    def load
      @database.table(Database::SONG_LIST_TABLE).each_value do |hash|
        Song.from_h(hash).then do |song|
          @ordered << song
          @by_id[song.id.to_s] = song
          bind_song_to_db(song)
        end
      end
      resort
      self
    end

    # The model the views bind to, in display order.
    def list_store = @list_store ||= Gio::ListStore.new(Song)

    def n_items = @ordered.length
    def empty? = @ordered.empty?
    def get(song_id) = @by_id[song_id.to_s]
    def contains?(song_id) = @by_id.key?(song_id.to_s)
    def to_a = @ordered.dup

    def on_items_changed(&block)
      @items_changed_listeners << block
      block
    end

    # Inserts a song, replacing an existing song with the same id. Returns true
    # when the song was appended rather than replacing one, which is what
    # upstream's `insert` returns.
    def insert(song)
      insert_many([song]).positive?
    end

    # Inserts many songs at once, returning how many were appended rather than
    # updated. Upstream commits them in one write transaction and emits
    # `items-changed` once; so does this.
    def insert_many(songs)
      @database.with_write do
        songs.each { |song| @database.put(Database::SONG_LIST_TABLE, song.id, song.to_h) }
      end

      songs.count { |song| take_in(song) }.tap { resort }
    end

    # Removes the songs with the given ids and returns them, in the order they
    # were held — upstream returns the removed songs so the view can offer an
    # undo.
    def remove_many(song_ids)
      @database.with_write do
        song_ids.each { |song_id| @database.delete(Database::SONG_LIST_TABLE, song_id) }
      end

      removed_indices(song_ids).then do |indices|
        indices.map { |index| @ordered[index] }.tap do |removed|
          removed.each { |song| drop(song) }
          resort
        end
      end
    end

    private

      # Puts the song in the list, returning true when it was appended. An
      # existing song with the same id is replaced, and its database binding
      # released, exactly as upstream's `insert_full` plus `unbind_song_from_db`
      # does.
      def take_in(song)
        @by_id[song.id.to_s].then do |previous|
          if previous
            unbind_song_from_db(previous)
            @ordered[@ordered.index(previous)] = song
          else
            @ordered << song
          end

          @by_id[song.id.to_s] = song
          bind_song_to_db(song)
          previous.nil?
        end
      end

      def drop(song)
        unbind_song_from_db(song)
        @by_id.delete(song.id.to_s)
        @ordered.delete(song)
      end

      # The positions of the songs to remove, in list order. Upstream groups
      # these into consecutive runs (see Utils.consecutive_groups) so it can
      # emit one `items-changed` per run; the store here is rebuilt by a single
      # splice afterwards, so the positions only have to be found.
      def removed_indices(song_ids)
        song_ids.filter_map { |song_id| @ordered.index(@by_id[song_id.to_s]) }.uniq.sort
      end

      def bind_song_to_db(song)
        @change_listeners[song.id.to_s] = song.on_change do |changed|
          @database.put(Database::SONG_LIST_TABLE, changed.id, changed.to_h)
        end
      end

      def unbind_song_from_db(song)
        @change_listeners.delete(song.id.to_s).then do |listener|
          if listener
            song.remove_change_listener(listener)
          end
        end
      end

      # Puts the sorted songs into the list store in one splice and tells the
      # listeners the model changed.
      def resort
        @sorter.sort(@ordered).then do |sorted|
          list_store.splice(0, list_store.n_items, sorted)
        end
        @items_changed_listeners.each { |listener| listener.call(self) }
      end
  end
end
