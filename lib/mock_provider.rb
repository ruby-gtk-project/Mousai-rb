# frozen_string_literal: true

require "json"
require_relative "aud_d"
require_relative "provider"

module Mousai
  # The AudD provider with its responses canned.
  #
  # Ported from upstream's src/recognizer/provider/aud_d/mock.rs: a
  # `TestProvider` that picks one of AudD's recorded responses at random and
  # hands it to the real `build_song_from_response_bytes`, so the parsing path
  # under test is the production one.
  #
  # Upstream holds the responses as string literals in the source; sixteen
  # recorded API responses come to over a hundred kilobytes, so they live in
  # data/aud_d_mock_responses.json here, copied verbatim. The error list is
  # used for `ErrorOnly`, the valid list for `ValidOnly`, and both for `Both` —
  # upstream's `random_response_str`.
  class AudDMock < Provider
    include TestProvider

    RESPONSES_PATH = File.expand_path("../data/aud_d_mock_responses.json", __dir__)

    class << self
      def responses = @responses ||= JSON.parse(File.read(RESPONSES_PATH)).freeze

      def error_responses = responses.fetch("error")
      def valid_responses = responses.fetch("valid")

      # Upstream's `random_response_str`.
      def random_response_str(mode)
        candidates(mode).then { |pool| pool[Kernel.rand(pool.length)] }
      end

      private

        def candidates(mode)
          [].tap do |pool|
            if [TestProviderMode::BOTH, TestProviderMode::ERROR_ONLY].include?(mode)
              pool.concat(error_responses)
            end

            if [TestProviderMode::BOTH, TestProviderMode::VALID_ONLY].include?(mode)
              pool.concat(valid_responses)
            end
          end
        end
    end

    def recognize_impl(_bytes, mode)
      AudD.build_song_from_response_bytes(self.class.random_response_str(mode))
    end
  end
end
