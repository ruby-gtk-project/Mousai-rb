# frozen_string_literal: true

require_relative "database"
require_relative "recording"
require_relative "uid"
require_relative "utils"

module Mousai
  # The recordings saved for later recognition.
  #
  # Ported from upstream's src/recognizer/recordings.rs: an ordered map of
  # `Uid` to `Recording` loaded from the database's `saved_recordings` table,
  # whose inserts and removals are written through in one transaction, and
  # whose recordings are bound so a recording changing in place is written too.
  #
  # Upstream is a `gio::ListModel`, which is how the recognizer status watches
  # it; the port keeps the ordered Ruby Array as the source of truth and
  # reports the same `items-changed` triples to its listeners, grouped into
  # consecutive runs the way upstream groups them.
  class Recordings
    attr_reader :database

    def initialize(database: nil)
      @database = database || Database.new
      @ordered = []
      @ids = {}
      @change_listeners = {}
      @items_changed_listeners = []
    end

    # Loads the saved recordings from the database — upstream's
    # `load_from_env`.
    def load
      @database.table(Database::RECORDINGS_TABLE).each do |id, hash|
        Recording.from_h(hash).then do |recording|
          @ordered << recording
          @ids[recording] = Uid.from(id)
          bind_recording_to_items_changed_and_db(recording)
        end
      end
      self
    end

    def n_items = @ordered.length
    def empty? = @ordered.empty?
    def to_a = @ordered.dup
    def item(position) = @ordered[position]

    def on_items_changed(&block)
      @items_changed_listeners << block
      block
    end

    # Appends a recording under a freshly generated id and writes it through.
    def insert(recording)
      Uid.generate.then do |id|
        @database.put(Database::RECORDINGS_TABLE, id, recording.to_h)
        @ids[recording] = id
        @ordered << recording
        bind_recording_to_items_changed_and_db(recording)
        emit_items_changed(@ordered.length - 1, 0, 1)
      end
      recording
    end

    # The recordings the block accepts, without removing them.
    def peek_filtered(&filter) = @ordered.select(&filter)

    # Removes the recordings the block accepts and returns them. The database
    # rows go in one write, and the listeners are told about each consecutive
    # run of positions, highest first, so no reported position is shifted by an
    # earlier removal.
    def take_filtered(&filter)
      @ordered.each_index.select { |index| filter.call(@ordered[index]) }.then do |indices|
        @database.with_write do
          indices.each { |index| @database.delete(Database::RECORDINGS_TABLE, @ids[@ordered[index]]) }
        end

        drop_groups(Utils.consecutive_groups(indices))
      end
    end

    private

      def drop_groups(groups)
        [].tap do |taken|
          groups.reverse_each do |(first, count)|
            (first...(first + count)).to_a.reverse_each do |index|
              @ordered[index].then do |recording|
                unbind_recording_from_items_changed_and_db(recording)
                @ids.delete(recording)
                taken << recording
              end
            end

            @ordered.slice!(first, count)
            emit_items_changed(first, count, 0)
          end
        end
      end

      # A recording that changes is written back and reported as one item
      # replaced in place, which is what upstream's notify handler does.
      def bind_recording_to_items_changed_and_db(recording)
        @change_listeners[recording] = recording.on_change do |changed|
          @database.put(Database::RECORDINGS_TABLE, @ids[changed], changed.to_h)
          @ordered.index(changed).then do |index|
            if index
              emit_items_changed(index, 1, 1)
            end
          end
        end
      end

      def unbind_recording_from_items_changed_and_db(recording)
        @change_listeners.delete(recording).then do |listener|
          if listener
            recording.remove_change_listener(listener)
          end
        end
      end

      def emit_items_changed(position, removed, added)
        @items_changed_listeners.each { |listener| listener.call(position, removed, added) }
      end
  end
end
