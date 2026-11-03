# frozen_string_literal: true

require "adwaita"
require_relative "i18n"

module Mousai
  # The play/pause button, which shows a spinner while the stream is loading.
  #
  # Ported from upstream's src/window/playback_button.rs and
  # data/resources/ui/playback_button.ui: a button whose child is a stack
  # holding an icon and a spinner, and the three modes that pick which of them
  # is shown, which icon it carries and what the tooltip says.
  class PlaybackButton
    PLAY = :play
    PAUSE = :pause
    BUFFERING = :buffering

    SPINNER_SIZE = 24

    attr_reader :mode

    def initialize
      @mode = PLAY
    end

    def build
      root.tap do |button|
        button.child = stack

        stack.tap do |s|
          s.add_child(image_child)
          s.add_child(spinner_child)
        end
      end.tap { update_ui }
    end

    # Upstream's `set_mode`: setting the same mode changes nothing.
    def mode=(new_mode)
      new_mode.then do |mode|
        unless mode == @mode
          @mode = mode
          update_ui
        end
      end
    end

    def root = @root ||= Gtk::Button.new
    def stack = @stack ||= Gtk::Stack.new
    def image_child = @image_child ||= Gtk::Image.new

    def spinner_child
      @spinner_child ||= Adwaita::Spinner.new.tap do |spinner|
        spinner.halign = :center
        spinner.valign = :center
        spinner.width_request = SPINNER_SIZE
        spinner.height_request = SPINNER_SIZE
      end
    end

    private

      def update_ui
        case @mode
        when PAUSE then show_icon("media-playback-pause-symbolic", I18n.gettext("Pause"))
        when BUFFERING then show_spinner
        else show_icon("media-playback-start-symbolic", I18n.gettext("Play"))
        end
      end

      def show_icon(icon_name, tooltip)
        image_child.icon_name = icon_name
        root.tooltip_text = tooltip
        stack.visible_child = image_child
      end

      def show_spinner
        root.tooltip_text = nil
        stack.visible_child = spinner_child
      end
  end
end
