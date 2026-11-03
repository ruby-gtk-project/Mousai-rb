# frozen_string_literal: true

require "json"
require_relative "recognize_error"

module Mousai
  # One response from the AudD recognition API.
  #
  # Ported from upstream's src/recognizer/provider/aud_d/response.rs: the
  # `status`/`result`/`error` envelope, the field renames its `Deserialize`
  # derives perform, and the mapping from AudD's documented error codes to
  # `RecognizeError` kinds.
  #
  # Upstream's nested structs become the readers on #data, named after the
  # Rust fields rather than AudD's JSON keys, so the provider reads the same
  # names on both sides of the port.
  class AudDResponse
    SUCCESS = "success"
    ERROR = "error"

    # Based on https://docs.audd.io/#common-errors
    ERROR_KINDS = {
      901 => RecognizeError::TOKEN_LIMIT_REACHED,
      900 => RecognizeError::INVALID_TOKEN,
      300 => RecognizeError::FINGERPRINT,
    }.freeze

    # The `result` object of a successful response.
    class Data
      def initialize(hash)
        @hash = hash
      end

      def artist = @hash["artist"].to_s
      def title = @hash["title"].to_s
      def album = @hash["album"].to_s

      # In format of ISO-8601 (%Y-%m-%d), and absent for some songs.
      def release_date = @hash["release_date"]

      # Upstream renames AudD's `song_link`; the link is unique to every song,
      # which is what the provider builds the song's id from.
      def info_link = @hash["song_link"].to_s

      def spotify_data = @hash["spotify"]
      def apple_music_data = @hash["apple_music"]
      def lyrics_data = @hash["lyrics"]
    end

    # Parses the bytes the API returned. Anything that is not JSON is an
    # `OtherPermanent` error carrying the parser's message, as upstream's
    # `serde_json::from_slice` mapping does.
    def self.parse(response_bytes)
      begin
        new(JSON.parse(response_bytes.to_s))
      rescue JSON::ParserError => e
        raise(RecognizeError.new(RecognizeError::OTHER_PERMANENT, e.message))
      end
    end

    def initialize(hash)
      if hash.is_a?(Hash)
        @hash = hash
      else
        @hash = {}
      end
    end

    def status = @hash["status"].to_s

    # The `result` object, or a `RecognizeError` describing why there is none.
    #
    # `result` and `error` are mutually exclusive: a `success` status carries
    # the former and an `error` status the latter.
    def data
      case status
      when SUCCESS then success_data
      when ERROR then raise(error)
      else
        raise(
          RecognizeError.new(
            RecognizeError::OTHER_PERMANENT,
            "Got invalid status response of #{status}",
          ),
        )
      end
    end

    private

      def success_data
        @hash["result"].then do |result|
          unless result.is_a?(Hash)
            raise(RecognizeError.new(RecognizeError::NO_MATCHES))
          end

          Data.new(result)
        end
      end

      def error
        @hash["error"].then do |raw|
          unless raw.is_a?(Hash)
            raise(
              RecognizeError.new(
                RecognizeError::OTHER_PERMANENT,
                "Got `error` status but no error",
              ),
            )
          end

          RecognizeError.new(
            ERROR_KINDS.fetch(raw["error_code"], RecognizeError::OTHER_PERMANENT),
            "##{raw["error_code"]}: #{raw["error_message"]}",
          )
        end
      end
  end
end
