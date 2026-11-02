# frozen_string_literal: true

require "fileutils"
require "json"

module Mousai
  # The app's on-disk store.
  #
  # Ported from upstream's src/database/mod.rs, which opens an LMDB (heed)
  # environment under `<user data dir>/mousai/db` holding two named databases,
  # `song_list` and `saved_recordings`, plus an unnamed one carrying the user
  # version the migrations run against.
  #
  # LMDB has no binding here, so the same shape — named tables, a user version,
  # and writes that commit as one batch — is backed by a single JSON file in
  # the same directory. The API is what upstream's callers use: `#table`,
  # `#put`, `#delete` and `#with_write`, which is upstream's `with_write_txn`.
  class Database
    SONG_LIST_TABLE = "song_list"
    RECORDINGS_TABLE = "saved_recordings"
    USER_VERSION_KEY = "user_version"

    # There are 16.67 ms in a 60 Hz frame, so a write taking longer than this
    # is worth a warning — upstream warns at the same threshold.
    SLOW_WRITE_SECONDS = 0.015

    attr_reader :path

    def initialize(path: nil)
      @path = path || default_path
      @data = read
      @depth = 0
      @dirty = false
    end

    def user_version = @data[USER_VERSION_KEY].to_i

    def user_version=(version)
      with_write { @data[USER_VERSION_KEY] = version.to_i }
      version
    end

    # The named table as a plain Hash. The copy is deliberate: callers hold the
    # rows they read, and a read never hands out the store's own Hash.
    def table(name) = (@data[name] || {}).dup

    def get(name, key) = (@data[name] || {})[key.to_s]

    def put(name, key, value)
      with_write do
        @data[name] ||= {}
        @data[name][key.to_s] = value
      end
      value
    end

    def delete(name, key)
      with_write do
        (@data[name] || {}).delete(key.to_s)
      end
    end

    # Runs the block, then writes the file once. Nested calls join the
    # outermost write, so a loop of puts inside one `with_write` touches the
    # disk once — the property upstream gets from a single write transaction.
    def with_write
      @depth += 1

      begin
        yield(self).tap { @dirty = true }
      ensure
        @depth -= 1
        commit
      end
    end

    private

      def commit
        (@depth.zero? && @dirty).then do |due|
          if due
            @dirty = false
            write
          end
        end
      end

      def write
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write("#{@path}.tmp", JSON.pretty_generate(@data))
        File.rename("#{@path}.tmp", @path)
        warn_when_slow(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at)
      end

      def warn_when_slow(elapsed)
        if elapsed > SLOW_WRITE_SECONDS
          warn("Database write took #{(elapsed * 1000).round(1)} ms")
        end
      end

      def read
        begin
          JSON.parse(File.read(@path))
        rescue Errno::ENOENT, JSON::ParserError
          {}
        end
      end

      def default_path
        File.join(
          ENV.fetch("XDG_DATA_HOME", File.expand_path("~/.local/share")),
          "mousai",
          "db",
          "db.json",
        )
      end
  end
end
