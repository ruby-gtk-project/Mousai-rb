# frozen_string_literal: true

require "adwaita"
require_relative "song_tile"

module Mousai
  # One tile in the recognized-songs carousel: when the song was last heard
  # above a plain `SongTile`.
  #
  # Ported from upstream's src/window/recognized_page_tile.rs and
  # data/resources/ui/recognized_page_tile.ui: a caption-heading label bound
  # to the song's `last-heard` property (its fuzzy display, or empty while the
  # song has never been heard) over the tile itself, with its select button
  # never shown on hover — a recognized tile has nothing to select.
  #
  # Upstream wires a primary-button `GtkGestureClick` on the inner
  # `MousaiSongTile` and emits `activated` only when the release lands back
  # inside it; the port's `SongTile` already swallows clicks for its own
  # select button and playback button, so the same gesture is added here.
  class RecognizedPageTile
    attr_reader :song

    def initialize(song, player:, album_art_store:)
      @song = song
      @activated_listeners = []
      @song_tile = SongTile.new(
        player:                       player,
        album_art_store:              album_art_store,
        shows_select_button_on_hover: false,
      )
      @song_tile.song = song
    end

    def build
      root.tap do |box|
        box.append(last_heard_label)
        box.append(song_tile_root)

        song_tile_root.add_controller(click_gesture)

        click_gesture.tap do |gesture|
          gesture.signal_connect("released") do |gesture_, _n_press, x, y|
            gesture_.state = :claimed

            if song_tile_root.contains?(x, y)
              emit_activated
            end
          end
        end
      end.tap do
        update_last_heard_label
      end
    end

    def on_activated(&block)
      @activated_listeners << block
      block
    end

    def root = @root ||= Gtk::Box.new(:vertical, 12)

    def last_heard_label
      @last_heard_label ||= Gtk::Label.new.tap do |label|
        label.add_css_class("caption-heading")
      end
    end

    def click_gesture
      @click_gesture ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = Gdk::BUTTON_PRIMARY
      end
    end

    private

      def song_tile_root = @song_tile_root ||= @song_tile.build

      def emit_activated
        @activated_listeners.each { |listener| listener.call(self) }
      end

      def update_last_heard_label
        @song.last_heard.then do |last_heard|
          if last_heard
            last_heard_label.label = last_heard.to_local.fuzzy_display
          else
            last_heard_label.label = ""
          end
        end
      end
  end
end
