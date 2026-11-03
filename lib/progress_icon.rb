# frozen_string_literal: true

require "adwaita"

module Mousai
  # A small pie-chart icon showing how far along a progress is.
  #
  # Ported from upstream's src/window/progress_icon.rs: a circle filled from
  # twelve o'clock clockwise to the current progress in the widget's own
  # colour, with the remainder filled at 15% of that colour's alpha, and a
  # 300ms animation so a change in progress sweeps round rather than jumping.
  #
  # Upstream is a `gtk::Widget` subclass that appends a Cairo context in its
  # `snapshot`; here it is a `Gtk::DrawingArea` with a draw function, which is
  # the same Cairo drawing without a widget subclass.
  class ProgressIcon
    ANIMATION_DURATION_MS = 300
    REMAINDER_ALPHA_FACTOR = 0.15
    TAU = Math::PI * 2
    FRAC_PI_2 = Math::PI / 2

    attr_reader :progress

    def initialize
      @progress = 0.0
      @display_progress = 0.0
    end

    def build
      root.tap do |area|
        area.set_draw_func { |_, context, width, height| draw(context, width, height) }
      end
    end

    # Upstream's `set_progress`, clamped to 0..1 by the property's minimum and
    # maximum, which starts the animation from wherever it had got to.
    def progress=(value)
      value.to_f.clamp(0.0, 1.0).then do |progress|
        unless progress == @progress
          @progress = progress
          animation.value_from = animation.value
          animation.value_to = progress
          animation.play
        end
      end
    end

    def tooltip_text=(text)
      root.tooltip_text = text
    end

    def root = @root ||= Gtk::DrawingArea.new

    def animation
      @animation ||= Adwaita::TimedAnimation.new(
        root,
        0.0,
        0.0,
        ANIMATION_DURATION_MS,
        animation_target,
      )
    end

    def animation_target
      @animation_target ||= Adwaita::CallbackAnimationTarget.new do |value|
        @display_progress = value
        root.queue_draw
      end
    end

    private

      def draw(context, width, height)
        root.color.then do |color|
          center_x = width / 2.0
          center_y = height / 2.0
          radius = width / 2.0
          arc_end = (@display_progress * TAU) - FRAC_PI_2

          fill_arc(
            context,
            color,
            color.alpha,
            center_x,
            center_y,
            radius,
            -FRAC_PI_2,
            arc_end,
          )
          fill_arc(
            context,
            color,
            color.alpha * REMAINDER_ALPHA_FACTOR,
            center_x,
            center_y,
            radius,
            arc_end,
            3 * FRAC_PI_2,
          )
        end
      end

      def fill_arc(context, color, alpha, center_x, center_y, radius, start_angle, end_angle)
        context.set_source_rgba(
          color.red,
          color.green,
          color.blue,
          alpha,
        )
        context.move_to(center_x, center_y)
        context.arc(
          center_x,
          center_y,
          radius,
          start_angle,
          end_angle,
        )
        context.fill
      end
  end
end
