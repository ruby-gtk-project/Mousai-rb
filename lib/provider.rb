# frozen_string_literal: true

require_relative "provider_settings"
require_relative "recognize_error"

module Mousai
  # What every recognition provider can do.
  #
  # Ported from upstream's src/recognizer/provider/mod.rs: the `Provider` trait
  # the recognizer talks to, and the `TestProvider` trait whose blanket
  # implementation of `Provider` waits for the configured recognize duration,
  # reads the configured test mode and hands both to `recognize_impl`.
  #
  # Upstream's methods are `async`; the port's recognition runs on a worker
  # thread, so they are plain blocking methods and the blanket implementation's
  # `glib::timeout_future` is a `sleep`.
  class Provider
    # Recognizes a song from the recorded bytes, raising a RecognizeError when
    # it cannot. Every provider defines this.
    def recognize(bytes)
      raise(NoMethodError, "#{self.class} must define #recognize for #{bytes.bytesize} bytes")
    end

    # How long to record the audio, in seconds.
    def listen_duration
      raise(NoMethodError, "#{self.class} must define #listen_duration")
    end

    # Whether this supports `TestProviderMode`.
    def test? = false
  end

  # Ported from upstream's `TestProvider` together with the blanket
  # `impl Provider for T where T: TestProvider`. A provider that includes this
  # defines `recognize_impl(bytes, mode)` and gets the rest.
  module TestProvider
    def recognize(bytes)
      ProviderSettings.lock { |settings| settings.test_recognize_duration }.then do |duration|
        sleep(duration)
        recognize_impl(bytes, ProviderSettings.lock { |settings| settings.test_mode })
      end
    end

    def listen_duration
      ProviderSettings.lock { |settings| settings.test_listen_duration }
    end

    def test? = true
  end
end
