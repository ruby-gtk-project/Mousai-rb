# frozen_string_literal: true

module Mousai
  # Which recognition provider is active and how the test providers behave.
  #
  # Ported from upstream's src/recognizer/provider/settings.rs: the
  # `TestProviderMode` and `ProviderType` enums, the `ProviderType::to_provider`
  # factory, and the process-global settings the devel inspector page edits
  # while the app runs.
  #
  # Upstream reaches the global through a `Mutex` behind `ProviderSettings::lock`
  # because its providers are polled from several tasks; the port's recognition
  # runs on one worker thread at a time, so the global is a singleton guarded by
  # the same mutex semantics a single writer needs.
  module TestProviderMode
    ERROR_ONLY = :error_only
    VALID_ONLY = :valid_only
    BOTH = :both

    # In upstream's enum order, which is the order the inspector page's combo
    # row lists them in. `ValidOnly` is the `#[default]`.
    ALL = [ERROR_ONLY, VALID_ONLY, BOTH].freeze
    DEFAULT = VALID_ONLY
  end

  # Ported from upstream's `ProviderType`, including its default of `AudD`.
  module ProviderType
    AUD_D = :aud_d
    AUD_D_MOCK = :aud_d_mock
    ERROR_TESTER = :error_tester

    ALL = [AUD_D, AUD_D_MOCK, ERROR_TESTER].freeze
    DEFAULT = AUD_D

    module_function

    # Upstream's `ProviderType::to_provider`. Upstream reads the API token off
    # the application's settings here and marks that as a thing to handle
    # outside; the port passes the token in instead.
    def to_provider(type, api_token: nil)
      case type
      when AUD_D_MOCK then AudDMock.new
      when ERROR_TESTER then ErrorTester.new
      else AudD.new(api_token)
      end
    end
  end

  # Ported from upstream's `ProviderSettings`, whose fields are all public and
  # whose defaults are one second for each of the two test durations.
  class ProviderSettings
    DEFAULT_TEST_LISTEN_DURATION = 1.0
    DEFAULT_TEST_RECOGNIZE_DURATION = 1.0

    attr_accessor :active, :test_mode, :test_listen_duration, :test_recognize_duration

    class << self
      # Upstream's `ProviderSettings::lock`, which hands out the one global
      # instance. The block form holds the mutex for its duration, which is
      # what every upstream caller of `lock` does with its guard.
      def instance = @instance ||= new

      def lock
        mutex.synchronize { yield(instance) }
      end

      def mutex = @mutex ||= Thread::Mutex.new
    end

    def initialize
      reset
    end

    # Resets all fields to their defaults.
    def reset
      @active = ProviderType::DEFAULT
      @test_mode = TestProviderMode::DEFAULT
      @test_listen_duration = DEFAULT_TEST_LISTEN_DURATION
      @test_recognize_duration = DEFAULT_TEST_RECOGNIZE_DURATION
      self
    end
  end
end

# At the bottom, not the top: the provider implementations subclass `Provider`,
# which reads the settings above, so requiring them here is what lets either
# file be the one a caller requires first.
require_relative "aud_d"
require_relative "error_tester_provider"
require_relative "mock_provider"
