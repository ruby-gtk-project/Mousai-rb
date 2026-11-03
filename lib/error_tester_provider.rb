# frozen_string_literal: true

require_relative "provider"
require_relative "recognize_error"

module Mousai
  # The provider that only ever fails, once with each kind of error.
  #
  # Ported from upstream's src/recognizer/provider/error_tester.rs: a
  # `TestProvider` that walks the six `RecognizeErrorKind`s in order and wraps
  # back round to the first, so each run of the app exercises the next one.
  # Upstream keeps that counter in a process-global `AtomicI32` and notes that
  # it should live on the struct; the port keeps it on the class for the same
  # reason, so a freshly built provider carries on where the last one stopped.
  class ErrorTester < Provider
    include TestProvider

    # In upstream's match order, each with upstream's message.
    ERRORS = [
      [RecognizeError::CONNECTION, "connection error message"],
      [RecognizeError::TOKEN_LIMIT_REACHED, "token limit reached error message"],
      [RecognizeError::INVALID_TOKEN, "invalid token error message"],
      [RecognizeError::FINGERPRINT, "fingerprint error message"],
      [RecognizeError::NO_MATCHES, "no matches error message"],
      [RecognizeError::OTHER_PERMANENT, "other permanent error message"],
    ].freeze

    class << self
      # Returns the index to use and advances the counter, wrapping after the
      # last error — upstream's `fetch_update`.
      def take_current
        mutex.synchronize do
          unless @current.is_a?(Integer)
            @current = 0
          end

          @current.tap do |current|
            if current >= ERRORS.length - 1
              @current = 0
            else
              @current = current + 1
            end
          end
        end
      end

      def mutex = @mutex ||= Thread::Mutex.new
    end

    def recognize_impl(_bytes, mode)
      unless mode == TestProviderMode::ERROR_ONLY
        warn("ErrorTester can only handle ErrorOnly mode")
      end

      ERRORS[self.class.take_current].then do |(kind, message)|
        raise(RecognizeError.new(kind, message))
      end
    end
  end
end
