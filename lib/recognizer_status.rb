# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "progress_icon"

module Mousai
  # The small status cluster shown in the history view's header bar: an
  # offline-mode icon, a progress icon for the saved recordings still being
  # retried, and a button showing how many of them came back successful.
  #
  # Ported from upstream's src/window/recognizer_status.rs and
  # data/resources/ui/recognizer_status.ui. The three pieces are each behind
  # their own `GtkRevealer`, and the progress icon's tooltip and fraction, and
  # the button's label, are recomputed from the recognizer's saved recordings
  # every time they change.
  class RecognizerStatus
    def initialize(recognizer)
      @recognizer = recognizer
      @show_results_requested_listeners = []
    end

    def build
      root.tap do |box|
        box.append(offline_mode_icon_revealer)
        box.append(progress_icon_revealer)
        box.append(show_results_button_revealer)

        offline_mode_icon_revealer.tap do |revealer|
          revealer.child = offline_mode_icon
        end

        progress_icon_revealer.tap do |revealer|
          revealer.child = progress_icon.build.tap do |area|
            area.margin_start = 10
            area.margin_end = 16
            area.margin_top = 10
            area.margin_bottom = 10
            area.width_request = 16
            area.height_request = 16
            area.valign = :center
          end
        end

        show_results_button_revealer.tap do |revealer|
          revealer.child = show_results_button

          show_results_button.tap do |button|
            button.child = show_results_button_label
            button.signal_connect("clicked") { emit_show_results_requested }
          end
        end

        @recognizer.saved_recordings.on_items_changed { update_progress_and_show_results_ui }
      end.tap do
        update_offline_mode_ui
        update_progress_and_show_results_ui
      end
    end

    def on_show_results_requested(&block)
      @show_results_requested_listeners << block
      block
    end

    # Must be called whenever the recognizer's offline mode may have changed
    # — the recognizer itself carries no change notification, so the window
    # calls this alongside its own state updates.
    def update_offline_mode_ui
      offline_mode_icon_revealer.reveal_child = @recognizer.offline_mode?
    end

    def root = @root ||= Gtk::Box.new(:horizontal, 0)

    def offline_mode_icon_revealer
      @offline_mode_icon_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :slide_right
      end
    end

    def offline_mode_icon
      @offline_mode_icon ||= Gtk::Image.new.tap do |image|
        image.margin_start = 10
        image.margin_end = 16
        image.margin_top = 10
        image.margin_bottom = 10
        image.valign = :center
        image.tooltip_text = I18n.gettext("Offline Mode Enabled")
        image.icon_name = "network-offline-symbolic"
      end
    end

    def progress_icon_revealer
      @progress_icon_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :slide_right
      end
    end

    def progress_icon = @progress_icon ||= ProgressIcon.new

    def show_results_button_revealer
      @show_results_button_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :slide_right
      end
    end

    def show_results_button
      @show_results_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = I18n.gettext("Show Offline Mode Recognition Results")
        button.add_css_class("show-results-button")
        button.add_css_class("flat")
      end
    end

    def show_results_button_label
      @show_results_button_label ||= Gtk::Label.new.tap do |label|
        label.valign = :center
        label.justify = :center
      end
    end

    private

      def emit_show_results_requested
        @show_results_requested_listeners.each { |listener| listener.call(self) }
      end

      def update_progress_and_show_results_ui
        recordings = @recognizer.saved_recordings
        total = recordings.n_items
        recognized = @recognizer.peek_recognized_saved_recordings
        n_recognized = recognized.length
        n_successful = recognized.count { |recording| recording.recognized_song }
        n_failed = n_recognized - n_successful

        progress_icon.tooltip_text = I18n.gettext_f(
          "Recognized {n_successful} Out Of {total_minus_failed}",
          {
            "n_successful"       => n_successful.to_s,
            "total_minus_failed" => (total - n_failed).to_s,
          },
        )
        if (total - n_failed).zero?
          progress_icon.progress = 1.0
        else
          progress_icon.progress = n_successful.to_f / (total - n_failed)
        end

        progress_icon_revealer.reveal_child = total != n_recognized
        show_results_button_revealer.reveal_child = n_successful != 0
        show_results_button_label.label = n_successful.to_s
      end
  end
end
