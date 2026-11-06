# frozen_string_literal: true

require "gio2"
require "glib2"
require_relative "date_time"
require_relative "provider_settings"
require_relative "recorder"
require_relative "recognize_error"
require_relative "recording"

module Mousai
  # Orchestrates one recognition: records audio, then either recognizes it
  # right away or saves it for later when the app is offline.
  #
  # Ported from upstream's src/recognizer/mod.rs: the `Null`/`Listening`/
  # `Recognizing` state, the `recording-peak-changed`, `song-recognized` and
  # `recording-saved` events, offline mode tracked off `Gio::NetworkMonitor`,
  # and `try_recognize_saved_recordings`, which sweeps the saved recordings
  # whenever connectivity changes.
  #
  # Upstream's `recognize` is one `async fn` awaiting a cancellable future for
  # the listen duration and then the provider's own future. The port has no
  # futures: the listen duration is a `GLib::Timeout`, and the provider call —
  # like every `Provider#recognize`, see provider.rb — runs on a worker thread
  # and is delivered back to the main loop with `GLib::Idle`, with
  # cancellation tracked on a flag read back on the main loop rather than
  # through a `Gio::Cancellable` shared with a thread.
  class Recognizer
    NULL = :null
    LISTENING = :listening
    RECOGNIZING = :recognizing

    MAX_SAVED_RECORDING_RECOGNIZE_RETRIES = 3

    attr_reader :state

    def initialize(settings:, recorder: nil, provider_settings: nil)
      @settings = settings
      @recorder = recorder || Recorder.new
      @provider_settings = provider_settings || ProviderSettings
      @state = NULL
      @is_offline_mode = false
      @cancelled = false
      @peak_listeners = []
      @state_listeners = []
      @song_recognized_listeners = []
      @recording_saved_listeners = []
      @failed_listeners = []
    end

    def offline_mode? = @is_offline_mode

    def on_recording_peak_changed(&block)
      @peak_listeners << block
      block
    end

    def on_state_changed(&block)
      @state_listeners << block
      block
    end

    def on_song_recognized(&block)
      @song_recognized_listeners << block
      block
    end

    def on_recording_saved(&block)
      @recording_saved_listeners << block
      block
    end

    # Upstream's `toggle_recognize` surfaces a permanent `RecognizeError` as
    # its `Err`; the port notifies the same error through this event instead
    # of raising it across the worker-thread/main-loop boundary.
    def on_recognize_failed(&block)
      @failed_listeners << block
      block
    end

    # Upstream's `bind_saved_recordings`: binds the recordings the recognizer
    # retries on the app's behalf, starts watching connectivity, and sweeps
    # them once right away.
    def bind_saved_recordings(recordings)
      @saved_recordings = recordings

      network_monitor.signal_connect("notify::connectivity") do
        update_offline_mode
        try_recognize_saved_recordings
      end

      update_offline_mode
      try_recognize_saved_recordings
    end

    def saved_recordings
      @saved_recordings || raise("saved recordings must be bound")
    end

    # Returned recordings are guaranteed to have a recognizing result, though
    # the result may not be a success — upstream's
    # `take_recognized_saved_recordings`.
    def take_recognized_saved_recordings = saved_recordings.take_filtered { |recording| ready_to_take?(recording) }

    # Upstream's `peek_recognized_saved_recordings`.
    def peek_recognized_saved_recordings = saved_recordings.peek_filtered { |recording| ready_to_take?(recording) }

    # Starts listening when the recognizer is idle, or cancels the recording
    # or recognition in progress — upstream's `toggle_recognize`.
    def toggle_recognize
      case @state
      when LISTENING, RECOGNIZING
        @cancelled = true
      when NULL
        @cancelled = false
        recognize
      end
    end

    private

      def recognize
        set_state(LISTENING)

        started = false

        begin
          @recorder.start(@settings.audio_source_type) { |peak| emit_peak(peak) }
          started = true
        rescue StandardError => e
          warn("Failed to start recording: #{e.message}")
        end

        if started
          recorded_time = DateTime.now_utc
          provider = active_provider
          listen_duration_ms = (provider.listen_duration * 1000).round

          GLib::Timeout.add(listen_duration_ms) do
            on_listen_duration_elapsed(provider, recorded_time)
            GLib::Source::REMOVE
          end
        else
          finish
        end
      end

      def on_listen_duration_elapsed(provider, recorded_time)
        if @cancelled
          begin
            @recorder.stop
          rescue StandardError
            nil
          end
          finish
        else
          recording_bytes = nil

          begin
            recording_bytes = @recorder.stop
          rescue StandardError => e
            warn("Failed to stop recording: #{e.message}")
          end

          if recording_bytes.nil?
            finish
          elsif offline_mode?
            save_recording_offline(recording_bytes, recorded_time)
          else
            recognize_recording(provider, recording_bytes, recorded_time)
          end
        end
      end

      def save_recording_offline(recording_bytes, recorded_time)
        saved_recordings.insert(Recording.new(recording_bytes, recorded_time))
        emit_recording_saved(RecognizeError.new(RecognizeError::CONNECTION))
        finish
      end

      def recognize_recording(provider, recording_bytes, recorded_time)
        set_state(RECOGNIZING)

        Thread.new do
          result = [:err, nil]

          begin
            result = [:ok, provider.recognize(recording_bytes)]
          rescue RecognizeError => e
            result = [:err, e]
          end

          GLib::Idle.add do
            deliver_recognize_result(result, recording_bytes, recorded_time)
            GLib::Source::REMOVE
          end
        end
      end

      def deliver_recognize_result(result, recording_bytes, recorded_time)
        if @cancelled
          finish
        else
          kind, value = result

          if kind == :ok
            value.last_heard = recorded_time
            emit_song_recognized(value)
            finish
          elsif value.permanent?
            emit_failed(value)
            finish
          else
            saved_recordings.insert(Recording.new(recording_bytes, recorded_time))
            emit_recording_saved(value)
            finish
          end
        end
      end

      def finish
        @cancelled = false
        set_state(NULL)
      end

      def active_provider
        @provider_settings.lock do |settings|
          ProviderType.to_provider(settings.active, api_token: @settings.aud_d_api_token)
        end
      end

      def set_state(state)
        unless state == @state
          @state = state
          @state_listeners.each { |listener| listener.call(self) }
        end
      end

      def emit_peak(peak)
        GLib::Idle.add do
          @peak_listeners.each { |listener| listener.call(self, peak) }
          GLib::Source::REMOVE
        end
      end

      def emit_song_recognized(song)
        @song_recognized_listeners.each { |listener| listener.call(self, song) }
      end

      def emit_recording_saved(cause)
        @recording_saved_listeners.each { |listener| listener.call(self, cause) }
      end

      def emit_failed(error)
        @failed_listeners.each { |listener| listener.call(self, error) }
      end

      def network_monitor = Gio::NetworkMonitor.default

      # We catch the case where the server is unreachable but the network
      # monitor shows full connectivity anyway, so it is not a problem to
      # leave offline mode off for limited or portal connectivity — upstream's
      # `update_offline_mode`.
      def update_offline_mode
        (network_monitor.connectivity == Gio::NetworkConnectivity::LOCAL).then do |is_offline_mode|
          unless is_offline_mode == @is_offline_mode
            @is_offline_mode = is_offline_mode
          end
        end
      end

      def try_recognize_saved_recordings
        unless saved_recordings.empty?
          if offline_mode?
            nil
          else
            Thread.new { try_recognize_saved_recordings_inner }
          end
        end
      end

      def try_recognize_saved_recordings_inner
        provider = active_provider

        saved_recordings.peek_filtered { true }.each do |recording|
          if offline_mode?
            break
          end

          if ready_to_take?(recording) || recording.recognize_retries > MAX_SAVED_RECORDING_RECOGNIZE_RETRIES
            next
          end

          recognize_saved_recording(provider, recording)
        end
      end

      def recognize_saved_recording(provider, recording)
        result = [:err, nil]

        begin
          result = [:ok, provider.recognize(recording.bytes)]
        rescue RecognizeError => e
          result = [:err, e]
        end

        GLib::Idle.add do
          deliver_saved_recognize_result(recording, result)
          GLib::Source::REMOVE
        end
      end

      def deliver_saved_recognize_result(recording, result)
        kind, value = result

        if kind == :ok
          value.last_heard = recording.recorded_time
          recording.recognize_result = value
        else
          recording.increment_recognize_retries
          recording.recognize_result = value
        end
      end

      # Whether the recording is ready to be taken: it has a result, and that
      # result is either a song or a permanent error — upstream's
      # `is_recording_ready_to_take`.
      def ready_to_take?(recording)
        if recording.recognized_song
          true
        elsif recording.recognize_error
          recording.recognize_error.permanent?
        else
          false
        end
      end
  end
end
