# frozen_string_literal: true

require "adwaita"
require_relative "album_art"
require_relative "history_view"
require_relative "i18n"
require_relative "player"
require_relative "recognize_error_dialog"
require_relative "recognizer"
require_relative "recognizer_view"
require_relative "recording_saved_dialog"
require_relative "settings"
require_relative "song_bar"
require_relative "song_list"

module Mousai
  # The app's main window.
  #
  # Ported from upstream's src/window/mod.rs and data/resources/ui/window.ui:
  # a toast overlay over a stack holding the history view, the `win.*` actions,
  # the breakpoint that puts the view into its narrow mode under 450px, the
  # Escape handling that leaves search and selection mode, and the window
  # geometry that is restored at startup and saved on close.
  #
  # The revealer below the stack holds the song bar, which comes up whenever
  # the player has a song and the history view is not in selection mode, and
  # `win.toggle-playback` is enabled for exactly as long.
  #
  # The stack also holds the recognizer view, keyed to the recognizer's state
  # the way upstream's `install_action_async`/`bind_models` keep it: the
  # history view is shown while the recognizer is idle, and the recognizer
  # view comes up for as long as it is listening or recognizing.
  # `win.toggle-recognize` drives the real `Recognizer`; a recognition that
  # finishes shows up the way upstream's `bind_models` says: inserted into the
  # history and pushed as a song page, or through #present_recognize_error /
  # #present_recording_saved_message.
  class Window
    NARROW_BREAKPOINT_CONDITION = "max-width: 450px"
    MIN_WIDTH = 360
    MIN_HEIGHT = 294

    def initialize(app, song_list:, settings: nil, player: nil, album_art_store: nil, recognizer: nil)
      @app = app
      @song_list = song_list
      @settings = settings || Settings.new
      @player = player || Player.new
      @album_art_store = album_art_store || AlbumArtStore.new
      @recognizer = recognizer || Recognizer.new(settings: @settings)
    end

    attr_reader :player

    def build
      root.tap do |win|
        win.content = toast_overlay

        toast_overlay.tap do |overlay|
          overlay.child = content_box

          content_box.tap do |box|
            box.append(stack)
            box.append(song_bar_revealer)

            stack.tap do |s|
              s.add_child(history_view.build)
              s.add_child(recognizer_view.build)
            end

            song_bar_revealer.tap do |revealer|
              revealer.child = song_bar.build

              song_bar.tap do |bar|
                bar.on_activated { |_, song| history_view.push_song_page(song) }
              end
            end
          end
        end

        @player.on_song_changed do
          update_toggle_playback_action
          update_song_bar_revealer
        end

        @player.on_error { add_message_toast(I18n.gettext("An error occurred in the player")) }

        history_view.on_selection_mode_changed { update_song_bar_revealer }

        bind_recognizer

        win.add_breakpoint(narrow_breakpoint)
        win.add_controller(key_controller)
        win.insert_action_group("win", action_group)

        narrow_breakpoint.tap do |breakpoint|
          breakpoint.signal_connect("apply") do
            history_view.adaptive_mode = :narrow
            song_bar.adaptive_mode = :narrow
          end

          breakpoint.signal_connect("unapply") do
            history_view.adaptive_mode = :normal
            song_bar.adaptive_mode = :normal
          end
        end

        key_controller.tap do |controller|
          controller.signal_connect("key-pressed") do |_, keyval, _keycode, state|
            key_pressed(keyval, state)
          end
        end

        win.signal_connect("close-request") do
          @settings.remember(root)
          false
        end

        history_view.search_bar.key_capture_widget = win
      end.tap do
        @settings.apply_to(root)
        update_stack_visible_child
        update_toggle_playback_action
        update_song_bar_revealer
      end
    end

    def present = root.present

    # Shows the given toast — upstream's `Window::add_toast`, which the history
    # view's undo toast goes through.
    def add_toast(toast) = toast_overlay.add_toast(toast)

    # Shows a plain message as a toast — upstream's `add_message_toast`.
    def add_message_toast(message) = add_toast(Adwaita::Toast.new(message))

    # Shows the dialog for a recognition that failed for good — upstream's
    # `present_recognize_error`. The block is called when the user asks to
    # listen again.
    def present_recognize_error(error, &on_try_again)
      RecognizeErrorDialog.present(root, error, &on_try_again)
    end

    # Shows the dialog for a recognition that was kept for later — upstream's
    # `present_recording_saved_message`. The block is called when the user asks
    # for preferences.
    def present_recording_saved_message(cause, &on_open_preferences)
      RecordingSavedDialog.present(root, cause, &on_open_preferences)
    end

    def history_view
      @history_view ||= HistoryView.new(
        song_list:        @song_list,
        player:           @player,
        album_art_store:  @album_art_store,
        recognizer:       @recognizer,
        on_toast:         method(:add_toast),
        on_message_toast: method(:add_message_toast),
      )
    end

    def recognizer_view = @recognizer_view ||= RecognizerView.new(@recognizer)

    def root
      @root ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.title = I18n.gettext("Mousai")
        win.width_request = MIN_WIDTH
        win.height_request = MIN_HEIGHT
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def stack
      @stack ||= Gtk::Stack.new.tap do |s|
        s.vexpand = true
        s.transition_type = :crossfade
      end
    end

    def song_bar_revealer
      @song_bar_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.overflow = :visible
        revealer.transition_type = :slide_up
      end
    end

    def song_bar
      @song_bar ||= SongBar.new(player: @player, album_art_store: @album_art_store)
    end

    def narrow_breakpoint
      @narrow_breakpoint ||= Adwaita::Breakpoint.new(
        Adwaita::BreakpointCondition.parse(NARROW_BREAKPOINT_CONDITION),
      )
    end

    def key_controller
      @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
        controller.propagation_phase = :capture
      end
    end

    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(toggle_search_action)
        group.add_action(toggle_playback_action)
        group.add_action(toggle_recognize_action)
      end
    end

    def toggle_search_action
      @toggle_search_action ||= Gio::SimpleAction.new("toggle-search").tap do |action|
        action.signal_connect("activate") { toggle_search }
      end
    end

    def toggle_playback_action
      @toggle_playback_action ||= Gio::SimpleAction.new("toggle-playback").tap do |action|
        action.signal_connect("activate") { toggle_playback }
      end
    end

    # Upstream's `win.toggle-recognize`.
    def toggle_recognize_action
      @toggle_recognize_action ||= Gio::SimpleAction.new("toggle-recognize").tap do |action|
        action.signal_connect("activate") do
          @player.song = nil
          @recognizer.toggle_recognize
        end
      end
    end

    private

      # Upstream's `win.toggle-playback`.
      def toggle_playback
        if @player.state == Player::PLAYING
          @player.pause
        else
          @player.play
        end
      end

      # Playback can only be toggled while the player has a song.
      def update_toggle_playback_action
        toggle_playback_action.enabled = !@player.song.nil?
      end

      # The bar is only up while there is something playing and the history
      # view is not in selection mode — upstream's `update_song_bar_revealer`.
      def update_song_bar_revealer
        song_bar_revealer.reveal_child = !@player.song.nil? && !history_view.selection_mode_active?
      end

      def toggle_search
        history_view.search_bar.then do |search_bar|
          search_bar.search_mode = !search_bar.search_mode?
        end
      end

      # Search can only be toggled while the history view is the visible page,
      # which is what upstream's `update_toggle_search_action` enforces.
      def update_toggle_search_action
        toggle_search_action.enabled = stack.visible_child == history_view.root
      end

      # Escape leaves search, then selection mode — but only on the history
      # view's own page, so it does not fight the navigation stack.
      def key_pressed(keyval, state)
        if keyval == Gdk::Keyval::KEY_Escape && state.to_i.zero? && history_view.on_navigation_main_page?
          escape_pressed
        else
          false
        end
      end

      def escape_pressed
        if history_view.search_bar.search_mode?
          history_view.search_bar.search_mode = false
          true
        elsif history_view.selection_mode_active?
          history_view.stop_selection_mode
          true
        else
          false
        end
      end

      # Upstream's `bind_models`, minus the recognizer view it also binds:
      # a recognized song goes into the history (freshly heard unless it was
      # already heard before) and is pushed as a song page; a recording kept
      # for later and a permanent failure go through the window's own dialogs.
      def bind_recognizer
        @recognizer.on_song_recognized { |_recognizer, song| on_song_recognized(song) }
        @recognizer.on_recording_saved { |_recognizer, cause| on_recording_saved(cause) }
        @recognizer.on_recognize_failed { |_recognizer, error| present_recognize_error(error) { @recognizer.toggle_recognize } }
        @recognizer.on_state_changed { update_stack_visible_child }
      end

      # The stack shows the recognizer view for as long as the recognizer is
      # listening or recognizing, and falls back to the history view once it
      # is idle again.
      def update_stack_visible_child
        if @recognizer.state == Recognizer::NULL
          stack.visible_child = history_view.root
        else
          stack.visible_child = recognizer_view.root
        end

        history_view.update_recognizer_status_ui
        recognizer_view.update_offline_mode_ui
        update_toggle_search_action
      end

      def on_recording_saved(cause)
        history_view.update_recognizer_status_ui
        recognizer_view.update_offline_mode_ui
        present_recording_saved_message(cause) { @app.activate_action("show-preferences", nil) }
      end

      def on_song_recognized(song)
        # Freshly heard unless it was already in the history and already
        # heard before — upstream's `is_none_or(|prev| prev.is_newly_heard())`.
        @song_list.get(song.id).then do |previous|
          if previous.nil? || previous.newly_heard?
            song.newly_heard = true
          end
        end

        begin
          @song_list.insert(song)
        rescue => e
          warn("Failed to insert song to history: #{e}")
          add_message_toast(I18n.gettext("Failed to insert song to history"))
        else
          history_view.push_song_page(song)
          history_view.scroll_to_top
        end
      end
  end
end
