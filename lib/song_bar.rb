# frozen_string_literal: true

require "adwaita"
require_relative "album_cover"
require_relative "i18n"
require_relative "playback_button"
require_relative "player"

module Mousai
  # The bar along the bottom of the window showing what is playing.
  #
  # Ported from upstream's src/window/song_bar.rs and
  # data/resources/ui/song_bar.ui: the seek scale across the top, the album
  # cover and labels that activate the song's page, the play/pause and stop
  # buttons, the position/duration label, the two layouts the adaptive mode
  # switches between, and the `song-bar.*` actions the UI points at.
  #
  # Upstream's seek is debounced by 20ms so dragging the scale only seeks once
  # the value settles, and the scale's handler is blocked while the player's
  # position is written into it; both are ported.
  class SongBar
    SEEK_DEBOUNCE_MS = 20
    ALBUM_COVER_PIXEL_SIZE = 42
    PLAYBACK_BUTTON_SIZE = 40
    SCALE_UPPER = 100
    SCALE_STEP_INCREMENT = 1
    SCALE_PAGE_INCREMENT = 10

    NORMAL_LAYOUT = "normal"
    NARROW_LAYOUT = "narrow"

    SONG_INFO_SLOT = "song_info"
    PLAYBACK_CONTROLS_SLOT = "playback_controls"

    attr_reader :adaptive_mode

    def initialize(player:, album_art_store: nil)
      @player = player
      @album_art_store = album_art_store
      @adaptive_mode = :normal
      @activated_listeners = []
      @setting_scale_value = false
    end

    def build
      root.tap do |box|
        box.append(playback_position_scale)
        box.append(multi_layout_view)

        playback_position_scale.tap do |scale|
          scale.signal_connect("value-changed") { on_playback_position_scale_value_changed }
        end

        multi_layout_view.tap do |view|
          view.add_layout(normal_layout)
          view.add_layout(narrow_layout)
          view.set_child(SONG_INFO_SLOT, song_info_bin)
          view.set_child(PLAYBACK_CONTROLS_SLOT, playback_controls_box)
          view.layout_name = NORMAL_LAYOUT

          song_info_bin.tap do |bin|
            bin.child = activate_song_button

            activate_song_button.tap do |button|
              button.child = song_info_box

              song_info_box.tap do |b|
                b.append(album_cover.build)
                b.append(labels_box)

                labels_box.tap do |labels|
                  labels.append(title_label)
                  labels.append(artist_label)
                end
              end
            end
          end

          playback_controls_box.tap do |controls|
            controls.append(playback_button.build)
            controls.append(stop_button)
          end
        end

        box.insert_action_group("song-bar", action_group)
      end.tap do
        bind_player
      end
    end

    # `:normal` or `:narrow` — upstream's `set_adaptive_mode`, which is the
    # multi layout view's layout name.
    def adaptive_mode=(mode)
      mode.then do |adaptive_mode|
        unless adaptive_mode == @adaptive_mode
          @adaptive_mode = adaptive_mode
          if (adaptive_mode == :narrow)
            multi_layout_view.layout_name = NARROW_LAYOUT
          else
            multi_layout_view.layout_name = NORMAL_LAYOUT
          end
        end
      end
    end

    # Upstream's `activated` signal, emitted by the `song-bar.activate` action
    # with the song currently on the player.
    def on_activated(&block)
      @activated_listeners << block
      block
    end

    def root = @root ||= Gtk::Box.new(:vertical, 0)

    def playback_position_scale
      @playback_position_scale ||= Gtk::Scale.new(:horizontal, playback_position_adjustment).tap do |scale|
        scale.hexpand = true
        scale.draw_value = false
        scale.add_css_class("playback-position-scale")
      end
    end

    def playback_position_adjustment
      @playback_position_adjustment ||= Gtk::Adjustment.new(

        0,
        0,
        SCALE_UPPER,
        SCALE_STEP_INCREMENT,
        SCALE_PAGE_INCREMENT,
        0,

      )
    end

    def multi_layout_view
      @multi_layout_view ||= Adwaita::MultiLayoutView.new.tap do |view|
        view.margin_start = 6
        view.margin_end = 6
        view.margin_top = 6
        view.margin_bottom = 6
      end
    end

    # Adwaita::Layout takes its content positionally and keeps it for good, so
    # each layout's content is built before the layout itself.
    def normal_layout
      @normal_layout ||= Adwaita::Layout.new(normal_center_box).tap do |layout|
        layout.name = NORMAL_LAYOUT
      end
    end

    def normal_center_box
      @normal_center_box ||= Gtk::CenterBox.new.tap do |center_box|
        center_box.start_widget = normal_song_info_slot
        center_box.center_widget = normal_playback_controls_slot
        center_box.end_widget = playback_position_duration_label
      end
    end

    def narrow_layout
      @narrow_layout ||= Adwaita::Layout.new(narrow_box).tap do |layout|
        layout.name = NARROW_LAYOUT
      end
    end

    def narrow_box
      @narrow_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.append(narrow_song_info_slot)
        box.append(narrow_playback_controls_slot)
      end
    end

    # One slot per layout: a slot belongs to the layout it is built into, and
    # the view moves the slotted child between them.
    def normal_song_info_slot = @normal_song_info_slot ||= Adwaita::LayoutSlot.new(SONG_INFO_SLOT)
    def narrow_song_info_slot = @narrow_song_info_slot ||= Adwaita::LayoutSlot.new(SONG_INFO_SLOT)

    def normal_playback_controls_slot
      @normal_playback_controls_slot ||= Adwaita::LayoutSlot.new(PLAYBACK_CONTROLS_SLOT)
    end

    def narrow_playback_controls_slot
      @narrow_playback_controls_slot ||= Adwaita::LayoutSlot.new(PLAYBACK_CONTROLS_SLOT)
    end

    def playback_position_duration_label
      @playback_position_duration_label ||= Gtk::Label.new.tap do |label|
        label.margin_start = 6
        label.add_css_class("dim-label")
        label.add_css_class("numeric")
      end
    end

    def song_info_bin
      @song_info_bin ||= Adwaita::Bin.new.tap do |bin|
        bin.margin_end = 6
        bin.hexpand = true
      end
    end

    def activate_song_button
      @activate_song_button ||= Gtk::Button.new.tap do |button|
        button.halign = :start
        button.tooltip_text = I18n.gettext("Show Song Information")
        button.action_name = "song-bar.activate"
        button.add_css_class("flat")
        button.add_css_class("activate-song-button")
      end
    end

    def song_info_box = @song_info_box ||= Gtk::Box.new(:horizontal, 12)

    def album_cover
      @album_cover ||= AlbumCover.new.tap do |cover|
        cover.pixel_size = ALBUM_COVER_PIXEL_SIZE
      end
    end

    def labels_box
      @labels_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.valign = :center
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.justify = :left
        label.xalign = 0
        label.ellipsize = :end
      end
    end

    def artist_label
      @artist_label ||= Gtk::Label.new.tap do |label|
        label.justify = :left
        label.xalign = 0
        label.ellipsize = :end
        label.add_css_class("caption")
        label.add_css_class("dim-label")
      end
    end

    def playback_controls_box = @playback_controls_box ||= Gtk::Box.new(:horizontal, 6)

    def playback_button
      @playback_button ||= PlaybackButton.new.tap do |button|
        button.root.valign = :center
        button.root.width_request = PLAYBACK_BUTTON_SIZE
        button.root.height_request = PLAYBACK_BUTTON_SIZE
        button.root.action_name = "win.toggle-playback"
        button.root.add_css_class("circular")
      end
    end

    def stop_button
      @stop_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = I18n.gettext("Stop")
        button.valign = :center
        button.action_name = "song-bar.clear"
        button.icon_name = "media-playback-stop-symbolic"
        button.add_css_class("circular")
        button.add_css_class("flat")
      end
    end

    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(clear_action)
        group.add_action(activate_action)
      end
    end

    def clear_action
      @clear_action ||= Gio::SimpleAction.new("clear").tap do |action|
        action.signal_connect("activate") { @player.song = nil }
      end
    end

    def activate_action
      @activate_action ||= Gio::SimpleAction.new("activate").tap do |action|
        action.signal_connect("activate") { emit_activated }
      end
    end

    # Displays a number of seconds in a `MM∶SS` format with padding for SS —
    # upstream's `format_clock_time_minute_sec`.
    def self.format_clock_time_minute_sec(seconds)
      seconds.to_i.then { |total| format("%<minutes>d∶%<seconds>02d", minutes: total / 60, seconds: total % 60) }
    end

    private

      def bind_player
        @player.on_song_changed { update_song_ui }
        @player.on_state_changed { update_playback_button }
        @player.on_position_changed do
          update_playback_position
          update_playback_position_duration_label
        end
        @player.on_duration_changed do
          update_playback_position_scale_range
          update_playback_position_duration_label
        end

        update_song_ui
        update_playback_button
        update_playback_position
        update_playback_position_scale_range
        update_playback_position_duration_label
      end

      def emit_activated
        @player.song.then do |song|
          if song
            @activated_listeners.each { |listener| listener.call(self, song) }
          end
        end
      end

      def set_playback_position_scale_value_blocking(value)
        @setting_scale_value = true
        playback_position_scale.value = value
        @setting_scale_value = false
      end

      # Cancels the seek when the value changed again within 20ms, so it only
      # seeks once the value has settled within that span.
      def on_playback_position_scale_value_changed
        unless @setting_scale_value
          if @seek_timeout_id
            GLib::Source.remove(@seek_timeout_id)
          end

          playback_position_scale.value.then do |value|
            @seek_timeout_id = GLib::Timeout.add(SEEK_DEBOUNCE_MS) do
              @seek_timeout_id = nil
              @player.seek(value)
              GLib::Source::REMOVE
            end
          end
        end
      end

      def update_song_ui
        @player.song.then do |song|
          title_label.label = song&.title.to_s
          artist_label.label = song&.artist.to_s
          playback_position_scale.sensitive = !song.nil?
          clear_action.enabled = !song.nil?
          show_album_art(song)
        end
      end

      # Upstream's album cover takes the song and downloads its art itself; the
      # port's cover takes a texture, so the download is asked for here.
      def show_album_art(song)
        album_cover.paintable = nil

        song&.album_art_link.then do |link|
          if link && @album_art_store
            @album_art_store.get_or_init(link).texture do |texture|
              if @player.song&.album_art_link == link
                album_cover.paintable = texture
              end
            end
          end
        end
      end

      def update_playback_button
        case @player.state
        when Player::BUFFERING
          playback_button.mode = PlaybackButton::BUFFERING
        when Player::PLAYING
          playback_button.mode = PlaybackButton::PAUSE
        else
          playback_button.mode = PlaybackButton::PLAY
        end
      end

      def update_playback_position
        set_playback_position_scale_value_blocking(@player.position)
      end

      def update_playback_position_scale_range
        playback_position_scale.set_range(0.0, @player.duration)
      end

      def update_playback_position_duration_label
        playback_position_duration_label.label = [
          self.class.format_clock_time_minute_sec(@player.position),
          self.class.format_clock_time_minute_sec(@player.duration),
        ].join(" / ")
      end
  end
end
