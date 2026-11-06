# frozen_string_literal: true

require "gstreamer_play"
require_relative "song"

module Mousai
  # Plays the preview of a recognized song.
  #
  # Ported from upstream's src/player.rs: the song being played, the four
  # states the song bar and the tiles read, the position and duration they
  # show, `play`/`pause`/`seek`, `is_active_song`, and the error that is
  # reported to the window.
  #
  # Upstream drives GStreamer's `gst_play::Play` and translates its bus
  # messages into property notifications. The port drives the same
  # `GstPlay::Play` through the `gstreamer_play` gem: `GstPlay::PlaySignalAdapter`
  # turns the play's bus into GObject signals — `state-changed`,
  # `position-updated`, `duration-changed`, `end-of-stream`, `seek-done` and
  # `error` — which is exactly the set upstream's `handle_gst_play_message`
  # switches on, minus the metadata-only messages (`media-info-updated`,
  # `buffering`, `warning`) upstream only logs.
  #
  # Upstream also publishes the same state on the session bus as an MPRIS
  # player. The port's dependencies carry no MPRIS server, so the player is
  # local to the app and the window is its only listener.
  class Player
    STOPPED = :stopped
    BUFFERING = :buffering
    PAUSED = :paused
    PLAYING = :playing

    NANOSECONDS_PER_SECOND = 1_000_000_000.0

    attr_reader :song, :state

    def initialize
      @state = STOPPED
      @position = 0.0
      @duration = 0.0
      @song_listeners = []
      @state_listeners = []
      @position_listeners = []
      @duration_listeners = []
      @error_listeners = []
      connect_signal_adapter
    end

    # Upstream's `set_song`: the player stops, the position and duration are
    # reset, and a song without a playback link is refused rather than put on
    # the player.
    def song=(new_song)
      new_song.then do |song|
        unless song == @song
          gst_play.stop
          update_position(0.0)
          update_duration(0.0)

          if song && song.playback_link.to_s.empty?
            warn("Trying to put a song without playback link on the Player")
          else
            @song = song

            # `GstPlay::Play#uri=` segfaults on `nil` — the uri is only set
            # when there is actually a song to play, mirroring upstream's
            # `if let Some(ref song) = song`.
            if song
              gst_play.uri = song.playback_link
            end

            @song_listeners.each { |listener| listener.call(self) }
          end
        end
      end
    end

    def position = @position
    def duration = @duration

    def active_song?(song_id) = !@song.nil? && @song.id == song_id

    def play = gst_play.play
    def pause = gst_play.pause

    # Upstream pauses first when the player is stopped, so the pipeline is in a
    # state that can be seeked.
    def seek(seconds)
      if @state == STOPPED
        pause
      end

      gst_play.seek((seconds * NANOSECONDS_PER_SECOND).round)
    end

    def on_song_changed(&block)
      @song_listeners << block
      block
    end

    def on_state_changed(&block)
      @state_listeners << block
      block
    end

    def on_position_changed(&block)
      @position_listeners << block
      block
    end

    def on_duration_changed(&block)
      @duration_listeners << block
      block
    end

    def on_error(&block)
      @error_listeners << block
      block
    end

    def gst_play = @gst_play ||= GstPlay::Play.new

    def signal_adapter = @signal_adapter ||= GstPlay::PlaySignalAdapter.new(gst_play)

    private

      def connect_signal_adapter
        signal_adapter.tap do |adapter|
          adapter.signal_connect("state-changed") { |_adapter, state| update_state(state) }
          adapter.signal_connect("position-updated") { |_adapter, position| update_position(position / NANOSECONDS_PER_SECOND) }
          adapter.signal_connect("duration-changed") { |_adapter, duration| update_duration(duration / NANOSECONDS_PER_SECOND) }
          # Upstream resets the position when the stream ends.
          adapter.signal_connect("end-of-stream") { update_position(0.0) }
          adapter.signal_connect("seek-done") { |_adapter, position| update_position(position / NANOSECONDS_PER_SECOND) }
          adapter.signal_connect("error") { |_adapter, error, *_rest| on_error_notified(error) }
        end
      end

      # Upstream's `PlayState` mapping, read straight off the signal instead of
      # being derived: a player with no song at all is still reported as
      # stopped by `GstPlay::Play` itself, so no extra case is needed here.
      def update_state(gst_state)
        mapped_state(gst_state).then do |state|
          unless state == @state
            @state = state
            @state_listeners.each { |listener| listener.call(self) }
          end
        end
      end

      def mapped_state(gst_state)
        if gst_state == GstPlay::PlayState::PLAYING
          PLAYING
        elsif gst_state == GstPlay::PlayState::PAUSED
          PAUSED
        elsif gst_state == GstPlay::PlayState::BUFFERING
          BUFFERING
        else
          STOPPED
        end
      end

      def update_position(position)
        position.then do |seconds|
          unless seconds == @position
            @position = seconds
            @position_listeners.each { |listener| listener.call(self) }
          end
        end
      end

      def update_duration(duration)
        duration.then do |seconds|
          unless seconds == @duration
            @duration = seconds
            @duration_listeners.each { |listener| listener.call(self) }
          end
        end
      end

      def on_error_notified(error)
        error.then do |err|
          if err
            @error_listeners.each { |listener| listener.call(self, err) }
          end
        end
      end
  end
end
