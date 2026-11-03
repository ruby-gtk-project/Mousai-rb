# frozen_string_literal: true

require "adwaita"
require_relative "album_cover"
require_relative "i18n"
require_relative "playback_button"
require_relative "player"
require_relative "song"

module Mousai
  # One song in the history grid: its album art, title and artist, a "New"
  # badge while it has not been opened yet, and a select button.
  #
  # Ported from upstream's src/window/song_tile.rs and
  # data/resources/ui/song_tile.ui. The select button is revealed while
  # selection mode is active, or on hover when the grid asks for that, and a
  # right-click or a long press asks the view to enter selection mode.
  #
  # A playback button is overlaid on the cover for a song that has a playback
  # link, showing the player's state while that song is the active one, and the
  # `song-tile.toggle-playback` action puts the song on the player or pauses it
  # again.
  class SongTile
    NORMAL_ALBUM_COVER_PIXEL_SIZE = 180
    NARROW_ALBUM_COVER_PIXEL_SIZE = 120

    attr_reader :song, :adaptive_mode

    def initialize(player:, album_art_store:, shows_select_button_on_hover: false)
      @player = player
      @album_art_store = album_art_store
      @shows_select_button_on_hover = shows_select_button_on_hover
      @selection_mode_active = false
      @selected = false
      @contains_pointer = false
      @adaptive_mode = :normal
      @selection_mode_requested_listeners = []
      @active_changed_listeners = []
    end

    def build
      root.tap do |overlay|
        overlay.child = content_box
        overlay.add_overlay(select_button_revealer)

        content_box.tap do |box|
          box.append(cover_overlay)
          box.append(labels_box)

          cover_overlay.tap do |o|
            o.child = album_cover.build
            o.add_overlay(new_label)
            o.add_overlay(playback_button.build)
          end

          labels_box.tap do |b|
            b.append(title_label)
            b.append(artist_label)
          end
        end

        select_button_revealer.tap do |revealer|
          revealer.child = select_button

          select_button.tap do |button|
            button.signal_connect("toggled") { on_select_button_toggled }
          end
        end

        root.insert_action_group("song-tile", action_group)

        @player.on_state_changed { update_playback_ui }

        root.add_controller(motion_controller)
        root.add_controller(secondary_click_gesture)
        root.add_controller(long_press_gesture)

        motion_controller.tap do |controller|
          controller.signal_connect("enter") do
            @contains_pointer = true
            update_select_button_visibility
          end

          controller.signal_connect("leave") do
            @contains_pointer = false
            update_select_button_visibility
          end
        end

        secondary_click_gesture.tap do |gesture|
          gesture.signal_connect("released") do
            gesture.state = :claimed
            request_selection_mode
          end
        end

        long_press_gesture.tap do |gesture|
          gesture.signal_connect("pressed") do
            gesture.state = :claimed
            request_selection_mode
          end
        end
      end.tap do
        update_select_button_tooltip_text
        update_select_button_visibility
        update_album_cover_size
        update_playback_ui
      end
    end

    def song=(new_song)
      new_song.then do |song|
        unless song == @song
          @song = song
          update_song_ui
        end
      end
    end

    # Whether the tile should be displayed as selected. Setting it does not run
    # the select button's handler, so putting a tile into its row's state never
    # looks like the user clicking it — upstream blocks the same handler.
    def selected=(value)
      value.then do |selected|
        unless selected == @selected
          @selected = selected
          @setting_selected = true
          select_button.active = selected
          @setting_selected = false
          update_select_button_tooltip_text
        end
      end
    end

    def selected? = @selected

    # Whether the select button is ticked, which is what the grid turns into a
    # selection in its model.
    def active? = select_button.active?

    def selection_mode_active=(value)
      value.then do |active|
        unless active == @selection_mode_active
          @selection_mode_active = active
          update_select_button_visibility
        end
      end
    end

    def selection_mode_active? = @selection_mode_active

    def shows_select_button_on_hover=(value)
      value.then do |shows|
        unless shows == @shows_select_button_on_hover
          @shows_select_button_on_hover = shows
          update_select_button_visibility
        end
      end
    end

    # `:normal` or `:narrow`, which is only the album cover's size.
    def adaptive_mode=(mode)
      mode.then do |adaptive_mode|
        unless adaptive_mode == @adaptive_mode
          @adaptive_mode = adaptive_mode
          update_album_cover_size
        end
      end
    end

    def on_selection_mode_requested(&block)
      @selection_mode_requested_listeners << block
      block
    end

    def on_active_changed(&block)
      @active_changed_listeners << block
      block
    end

    def root
      @root ||= Gtk::Overlay.new.tap do |overlay|
        overlay.margin_start = 6
        overlay.margin_end = 6
        overlay.margin_top = 6
        overlay.margin_bottom = 6
      end
    end

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 6)

    def cover_overlay
      @cover_overlay ||= Gtk::Overlay.new.tap do |overlay|
        overlay.halign = :center
      end
    end

    def album_cover = @album_cover ||= AlbumCover.new

    def new_label
      @new_label ||= Gtk::Label.new(I18n.gettext("New")).tap do |label|
        label.visible = false
        label.halign = :start
        label.valign = :start
        label.margin_start = 12
        label.margin_top = 12
        label.add_css_class("new")
      end
    end

    def labels_box = @labels_box ||= Gtk::Box.new(:vertical, 0)

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.justify = :center
        label.xalign = 0.5
        label.ellipsize = :end
        label.wrap = true
        label.wrap_mode = :word
        label.lines = 2
      end
    end

    def artist_label
      @artist_label ||= Gtk::Label.new.tap do |label|
        label.justify = :center
        label.xalign = 0.5
        label.ellipsize = :end
        label.wrap = true
        label.wrap_mode = :word
        label.lines = 2
        label.add_css_class("caption")
        label.add_css_class("dim-label")
      end
    end

    def select_button_revealer
      @select_button_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.valign = :end
        revealer.halign = :end
        revealer.margin_end = 12
        revealer.margin_bottom = 12
        revealer.transition_type = :crossfade
      end
    end

    def select_button
      @select_button ||= Gtk::CheckButton.new.tap do |button|
        button.add_css_class("selection-mode")
      end
    end

    def playback_button
      @playback_button ||= PlaybackButton.new.tap do |button|
        button.root.halign = :end
        button.root.valign = :end
        button.root.margin_end = 12
        button.root.margin_bottom = 12
        button.root.action_name = "song-tile.toggle-playback"
        button.root.add_css_class("osd")
        button.root.add_css_class("circular")
      end
    end

    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(toggle_playback_action)
      end
    end

    def toggle_playback_action
      @toggle_playback_action ||= Gio::SimpleAction.new("toggle-playback").tap do |action|
        action.signal_connect("activate") { toggle_playback }
      end
    end

    def motion_controller = @motion_controller ||= Gtk::EventControllerMotion.new

    def secondary_click_gesture
      @secondary_click_gesture ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = Gdk::BUTTON_SECONDARY
      end
    end

    def long_press_gesture
      @long_press_gesture ||= Gtk::GestureLongPress.new.tap do |gesture|
        gesture.propagation_phase = :capture
      end
    end

    private

      def request_selection_mode
        @selection_mode_requested_listeners.each { |listener| listener.call(self) }
      end

      # Ticking the button outside selection mode is how the user starts it, as
      # upstream does from the same handler.
      def on_select_button_toggled
        unless @setting_selected
          if select_button.active? && !@selection_mode_active
            request_selection_mode
          end

          @active_changed_listeners.each { |listener| listener.call(self) }
        end
      end

      def update_song_ui
        title_label.label = @song&.title.to_s
        artist_label.label = @song&.artist.to_s
        new_label.visible = @song&.newly_heard? == true
        show_album_art
        update_playback_ui
      end

      # Upstream's album cover takes the song and downloads its art itself; the
      # port's cover takes a texture, so the download is asked for here and the
      # answer is dropped when the tile has been recycled onto another song.
      def show_album_art
        album_cover.paintable = nil

        @song&.album_art_link.then do |link|
          if link
            @album_art_store.get_or_init(link).texture do |texture|
              if @song&.album_art_link == link
                album_cover.paintable = texture
              end
            end
          end
        end
      end

      # Upstream's `toggle_playback`: the active song is paused, any other song
      # is put on the player and started.
      def toggle_playback
        @song.then do |song|
          if song
            if @player.state == Player::PLAYING && @player.active_song?(song.id)
              @player.pause
            else
              @player.song = song
              @player.play
            end
          end
        end
      end

      # Upstream's `update_playback_ui` together with
      # `update_playback_button_visibility`: the button is only there for a
      # song that can be played, and it follows the player while that song is
      # the active one.
      def update_playback_ui
        playback_button.root.visible = !@song&.playback_link.to_s.empty?

        @song.then do |song|
          if song
            playback_button.mode = playback_button_mode(song)
          end
        end
      end

      def playback_button_mode(song)
        @player.active_song?(song.id).then do |is_active_song|
          if is_active_song && @player.state == Player::BUFFERING
            PlaybackButton::BUFFERING
          elsif is_active_song && @player.state == Player::PLAYING
            PlaybackButton::PAUSE
          else
            PlaybackButton::PLAY
          end
        end
      end

      def update_select_button_tooltip_text
        if @selected
          select_button.tooltip_text = I18n.gettext("Unselect")
        else
          select_button.tooltip_text = I18n.gettext("Select")
        end
      end

      def update_select_button_visibility
        select_button_revealer.reveal_child =
          @selection_mode_active || (@contains_pointer && @shows_select_button_on_hover)
      end

      def update_album_cover_size
        if @adaptive_mode == :narrow
          album_cover.pixel_size = NARROW_ALBUM_COVER_PIXEL_SIZE
        else
          album_cover.pixel_size = NORMAL_ALBUM_COVER_PIXEL_SIZE
        end
      end
  end
end
