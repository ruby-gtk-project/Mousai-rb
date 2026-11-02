# frozen_string_literal: true

require "adwaita"
require_relative "history_view"
require_relative "i18n"
require_relative "settings"
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
  # Upstream's stack also holds the recognizer view, and a revealer below it
  # holds the song bar. Neither the recognizer nor the player is ported yet, so
  # the window has the history view alone and installs only the actions it can
  # actually carry out.
  class Window
    NARROW_BREAKPOINT_CONDITION = "max-width: 450px"
    MIN_WIDTH = 360
    MIN_HEIGHT = 294

    def initialize(app, song_list:, settings: nil)
      @app = app
      @song_list = song_list
      @settings = settings || Settings.new
    end

    def build
      root.tap do |win|
        win.content = toast_overlay

        toast_overlay.tap do |overlay|
          overlay.child = content_box

          content_box.tap do |box|
            box.append(stack)

            stack.tap do |s|
              s.add_child(history_view.build)
            end
          end
        end

        win.add_breakpoint(narrow_breakpoint)
        win.add_controller(key_controller)
        win.insert_action_group("win", action_group)

        narrow_breakpoint.tap do |breakpoint|
          breakpoint.signal_connect("apply") { history_view.adaptive_mode = :narrow }
          breakpoint.signal_connect("unapply") { history_view.adaptive_mode = :normal }
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
        update_toggle_search_action
      end
    end

    def present = root.present

    # Shows the given toast — upstream's `Window::add_toast`, which the history
    # view's undo toast goes through.
    def add_toast(toast) = toast_overlay.add_toast(toast)

    # Shows a plain message as a toast — upstream's `add_message_toast`.
    def add_message_toast(message) = add_toast(Adwaita::Toast.new(message))

    def history_view
      @history_view ||= HistoryView.new(
        song_list:        @song_list,
        on_toast:         method(:add_toast),
        on_message_toast: method(:add_message_toast),
      )
    end

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
      end
    end

    def toggle_search_action
      @toggle_search_action ||= Gio::SimpleAction.new("toggle-search").tap do |action|
        action.signal_connect("activate") { toggle_search }
      end
    end

    private

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
  end
end
