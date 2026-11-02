# frozen_string_literal: true

require "fileutils"
require "json"

module Mousai
  # The app's settings.
  #
  # Ported from upstream's src/settings.rs together with the schema it
  # generates its accessors from, data/io.github.seadve.Mousai.gschema.xml.in:
  # the keys, their defaults and the `audio-source-type` choices are the
  # schema's, and the named accessors are the ones `gen_settings` produces.
  #
  # Upstream reads them through GSettings, which needs a compiled schema
  # installed into a system schema directory; requiring an install step to run
  # the app from a checkout is worse than the alternative, so the same keys and
  # defaults are backed by a small JSON file under XDG_CONFIG_HOME instead.
  class Settings
    MICROPHONE = "microphone"
    DESKTOP_AUDIO = "desktop-audio"

    # The schema's `<choices>` for audio-source-type, in schema order — the
    # order the preferences dialog's combo row shows them in.
    AUDIO_SOURCE_TYPES = [MICROPHONE, DESKTOP_AUDIO].freeze

    DEFAULTS = {
      "window-width"      => 768,
      "window-height"     => 600,
      "window-maximized"  => false,
      "audio-source-type" => MICROPHONE,
      "aud-d-api-token"   => "",
      # Legacy, kept for migration — the key upstream's pre-database releases
      # stored the history in.
      "memory-list"       => [],
    }.freeze

    attr_reader :path

    def initialize(path: nil)
      @path = path || default_path
      @values = DEFAULTS.merge(read)
    end

    def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

    def []=(key, value)
      @values[key.to_s] = value
      write
      value
    end

    DEFAULTS.each_key do |key|
      method_name = key.tr("-", "_")
      define_method(method_name) { self[key] }
      define_method(:"#{method_name}=") { |value| self[key] = value }
    end

    def window_maximized? = self["window-maximized"] == true

    # The schema constrains this key to its choices, so an unknown value falls
    # back to the default rather than reaching the rest of the app.
    def audio_source_type
      self["audio-source-type"].then do |value|
        if AUDIO_SOURCE_TYPES.include?(value)
          value
        else
          MICROPHONE
        end
      end
    end

    def audio_source_type=(value)
      unless AUDIO_SOURCE_TYPES.include?(value)
        raise(ArgumentError, "audio-source-type must be one of #{AUDIO_SOURCE_TYPES.join(", ")}")
      end

      self["audio-source-type"] = value
    end

    # The position of the current audio source type in the combo row, and the
    # type at a position — upstream's `AudioSourceType::as_position` and
    # `from_position`, which live in the preferences dialog.
    def audio_source_type_position = AUDIO_SOURCE_TYPES.index(audio_source_type)
    def audio_source_type_at(position) = AUDIO_SOURCE_TYPES.fetch(position)

    # Restores the window geometry recorded by the previous run — upstream's
    # `Window::load_window_size`.
    def apply_to(window)
      window.set_default_size(self["window-width"], self["window-height"])

      if window_maximized?
        window.maximize
      end
    end

    # Records the window geometry — upstream's `Window::save_window_size`.
    def remember(window)
      @values["window-width"] = window.default_width
      @values["window-height"] = window.default_height
      @values["window-maximized"] = window.maximized?
      write
    end

    private

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate(@values))
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
          ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
          "mousai",
          "settings.json",
        )
      end
  end
end
