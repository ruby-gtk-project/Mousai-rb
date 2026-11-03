# frozen_string_literal: true

require_relative "date_time"
require_relative "recognize_error"
require_relative "song"

module Mousai
  # One recording kept for later recognition.
  #
  # Ported from upstream's src/recognizer/recording.rs: the recorded bytes and
  # the time they were recorded, both set once; the recognition result, which
  # is either a song or a `RecognizeError` and notifies when it changes; and
  # the retry count, which is deliberately left out of the serialised form so
  # a recording can be retried again next session.
  #
  # Upstream's `BoxedRecognizeResult` is a `Result<Song, RecognizeError>`; here
  # the result is the song or the error object itself, and `#recognized?`
  # answers what upstream's `is_some` checks.
  class Recording
    attr_reader :bytes, :recorded_time, :recognize_result, :recognize_retries

    # Reads back a recording written by #to_h.
    def self.from_h(hash)
      new(
        hash.fetch("bytes", "").unpack1("m0"),
        DateTime.from_iso8601(hash.fetch("recorded_time")),
      ).tap do |recording|
        recording.recognize_result = result_from_h(hash["recognize_result"])
      end
    end

    # Upstream serialises the `Result` as serde does: an `Ok` or an `Err` key.
    def self.result_from_h(hash)
      if hash.is_a?(Hash) && hash.key?("Ok")
        Song.from_h(hash["Ok"])
      elsif hash.is_a?(Hash) && hash.key?("Err")
        RecognizeError.from_h(hash["Err"])
      end
    end

    def initialize(bytes, recorded_time)
      @bytes = bytes.to_s
      @recorded_time = recorded_time
      @recognize_retries = 0
      @change_listeners = []
    end

    # Upstream's `set_recognize_result`, with the same "same value changes
    # nothing and notifies nobody" guard.
    def recognize_result=(result)
      result.then do |new_result|
        unless new_result == @recognize_result
          @recognize_result = new_result
          notify_change
        end
      end
    end

    def recognized? = !@recognize_result.nil?
    def recognized_song = @recognize_result.is_a?(Song) ? @recognize_result : nil
    def recognize_error = @recognize_result.is_a?(RecognizeError) ? @recognize_result : nil

    def increment_recognize_retries
      @recognize_retries += 1
    end

    # The saved recordings list binds to this so a recording changing in place
    # is written back to the database — upstream binds `notify` for the same
    # reason.
    def on_change(&block)
      @change_listeners << block
      block
    end

    def remove_change_listener(listener) = @change_listeners.delete(listener)

    def to_h
      {
        # Strict base64, as `Base64.strict_encode64` produces; the base64 gem
        # is not a default gem any more, so it is not required.
        "bytes"            => [@bytes].pack("m0"),
        "recorded_time"    => @recorded_time.format_iso8601,
        "recognize_result" => result_to_h,
      }
    end

    private

      def result_to_h
        if recognized_song
          {"Ok" => recognized_song.to_h}
        elsif recognize_error
          {"Err" => recognize_error.to_h}
        end
      end

      def notify_change
        @change_listeners.each { |listener| listener.call(self) }
      end
  end
end
