# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "recognizer"
require_relative "waveform"

module Mousai
  # The stack page shown while the recognizer is listening or recognizing: a
  # bidirectional waveform, a title that names which, and an "Offline Mode"
  # caption while offline mode is active.
  #
  # Ported from upstream's src/window/recognizer_view.rs and
  # data/resources/ui/recognizer_view.ui: a header bar with a destructive
  # "Cancel" button wired to `win.toggle-recognize`, and a looping 1.5s
  # animation that feeds the waveform a gentle pulse while recognizing — the
  # recorded peaks themselves drive it while listening.
  class RecognizerView
    RECOGNIZING_ANIMATION_DURATION_MS = 1500
    RECOGNIZING_ANIMATION_PEAK = 0.8

    def initialize(recognizer)
      @recognizer = recognizer
      @recognizer.on_recording_peak_changed { |_, peak| waveform.push_peak(peak) }
      @recognizer.on_state_changed { update_ui }
    end

    def build
      root.tap do
        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          header_bar.tap do |bar|
            bar.pack_start(cancel_button)
          end

          content_box.tap do |box|
            box.append(waveform.build)
            box.append(title_box)

            title_box.tap do |b|
              b.append(title_label)
              b.append(offline_mode_status_revealer)

              offline_mode_status_revealer.tap do |revealer|
                revealer.child = offline_mode_status_label
              end
            end
          end
        end
      end.tap do
        update_offline_mode_ui
        update_ui
      end
    end

    # Must be called whenever the recognizer's offline mode may have changed
    # — the recognizer carries no change notification for it, so the window
    # calls this alongside its own state updates.
    def update_offline_mode_ui
      is_offline_mode = @recognizer.offline_mode?

      offline_mode_status_revealer.reveal_child = is_offline_mode

      if is_offline_mode
        waveform.root.add_css_class("red")
      else
        waveform.root.remove_css_class("red")
      end
    end

    def root = @root ||= Gtk::Box.new(:vertical, 0)
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def cancel_button
      @cancel_button ||= Gtk::Button.new(label: I18n.gettext("Cancel")).tap do |button|
        button.tooltip_text = I18n.gettext("Cancel Listening")
        button.action_name = "win.toggle-recognize"
        button.add_css_class("destructive-action")
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.margin_top = 24
        box.margin_bottom = 24
        box.valign = :center
      end
    end

    def waveform = @waveform ||= Waveform.new

    def title_box = @title_box ||= Gtk::Box.new(:vertical, 6)

    def title_label = @title_label ||= Gtk::Label.new.tap { |label| label.add_css_class("title-1") }

    def offline_mode_status_revealer
      @offline_mode_status_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :crossfade
      end
    end

    def offline_mode_status_label
      @offline_mode_status_label ||= Gtk::Label.new(I18n.gettext("Offline Mode")).tap do |label|
        label.add_css_class("caption")
      end
    end

    def recognizing_animation
      @recognizing_animation ||= Adwaita::TimedAnimation.new(
        waveform.root,
        0.0,
        RECOGNIZING_ANIMATION_PEAK,
        RECOGNIZING_ANIMATION_DURATION_MS,
        recognizing_animation_target,
      ).tap do |animation|
        animation.easing = :ease_out_back
        animation.repeat_count = 0
        animation.alternate = true
      end
    end

    def recognizing_animation_target
      @recognizing_animation_target ||= Adwaita::CallbackAnimationTarget.new do |value|
        waveform.push_peak(value)
      end
    end

    private

      def update_ui
        case @recognizer.state
        when Recognizer::LISTENING
          waveform.clear_peaks
          recognizing_animation.pause
          title_label.label = I18n.gettext("Listening…")
        when Recognizer::RECOGNIZING
          waveform.clear_peaks
          recognizing_animation.play
          title_label.label = I18n.gettext("Recognizing…")
        else
          waveform.clear_peaks
          recognizing_animation.pause
        end
      end
  end
end
