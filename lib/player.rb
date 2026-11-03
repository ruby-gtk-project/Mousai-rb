# frozen_string_literal: true

require "gtk4"
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
  # messages into property notifications. The port has no GStreamer binding, so
  # playback goes through `Gtk::MediaFile`, which GTK itself backs with
  # GStreamer: its `prepared`, `playing`, `ended`, `timestamp`, `duration` and
  # `error` properties carry the same information upstream reads off the bus,
  # and the state is derived from them the way upstream maps `PlayState`.
  #
  # Upstream also publishes the same state on the session bus as an MPRIS
  # player. The port's dependencies carry no MPRIS server, so the player is
  # local to the app and the window is its only listener.
  class Player
    STOPPED = :stopped
    BUFFERING = :buffering
    PAUSED = :paused
    PLAYING = :playing

    MICROSECONDS_PER_SECOND = 1_000_000.0

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
      connect_media
    end

    # Upstream's `set_song`: the player stops, the position and duration are
    # reset, and a song without a playback link is refused rather than put on
    # the player.
    def song=(new_song)
      new_song.then do |song|
        unless song == @song
          media.playing = false

          if song && song.playback_link.to_s.empty?
            warn("Trying to put a song without playback link on the Player")
          else
            @song = song
            media.file = song && Gio::File.new_for_uri(song.playback_link)
            update_position(0.0)
            update_duration(0.0)
            update_state
            @song_listeners.each { |listener| listener.call(self) }
          end
        end
      end
    end

    def position = @position
    def duration = @duration

    def active_song?(song_id) = !@song.nil? && @song.id == song_id

    def play = media.playing = true
    def pause = media.playing = false

    # Upstream pauses first when the player is stopped, so the pipeline is in a
    # state that can be seeked.
    def seek(seconds)
      if @state == STOPPED
        pause
      end

      media.seek((seconds * MICROSECONDS_PER_SECOND).round)
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

    def media = @media ||= Gtk::MediaFile.new

    private

      def connect_media
        media.tap do |stream|
          stream.signal_connect("notify::playing") { update_state }
          stream.signal_connect("notify::prepared") { update_state }
          stream.signal_connect("notify::ended") { on_ended }
          stream.signal_connect("notify::error") { on_error_notified }
          stream.signal_connect("notify::timestamp") { update_position(stream.timestamp / MICROSECONDS_PER_SECOND) }
          stream.signal_connect("notify::duration") { update_duration(stream.duration / MICROSECONDS_PER_SECOND) }
        end
      end

      # Upstream's `PlayState` mapping: a song that is loading is buffering,
      # and a player with no song at all is stopped.
      def current_state
        if @song.nil?
          STOPPED
        elsif !media.prepared?
          BUFFERING
        elsif media.playing?
          PLAYING
        else
          PAUSED
        end
      end

      def update_state
        current_state.then do |state|
          unless state == @state
            @state = state
            @state_listeners.each { |listener| listener.call(self) }
          end
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

      # Upstream resets the position when the stream ends.
      def on_ended
        if media.ended?
          update_position(0.0)
          update_state
        end
      end

      def on_error_notified
        media.error.then do |error|
          if error
            @error_listeners.each { |listener| listener.call(self, error) }
          end
        end
      end
  end
end
