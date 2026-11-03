# frozen_string_literal: true

require "adwaita"

module Mousai
  # The bidirectional waveform drawn while the app is listening.
  #
  # Ported from upstream's src/window/waveform.rs, which is itself based on
  # GNOME Sound Recorder's waveform and modified to be bidirectional: peaks are
  # pushed at the centre and travel out to both sides, the older a peak is the
  # shorter and fainter its line, and only as many peaks as fit in the widget's
  # width are drawn.
  #
  # Upstream is a `gtk::Widget` subclass drawing GSK paths in its `snapshot`;
  # here it is a `Gtk::DrawingArea` with a draw function, so the lines are
  # Cairo strokes with the same width, round caps, gutter and feathering.
  #
  # Upstream names the widget `waveform` so the stylesheet can colour it with
  # the accent colour; `css-name` is construct-only on `GtkWidget` and the Ruby
  # bindings offer no way to set it on a subclass, so the accent colour is read
  # from the style manager here instead and the drawn colour is the same one
  # the stylesheet would have given.
  class Waveform
    GUTTER = 10.0
    LINE_WIDTH = 6.0

    NATURAL_WIDTH = 300
    NATURAL_HEIGHT = 240

    MIN_LINE_HEIGHT = 0.1

    def initialize
      @peaks = []
    end

    def build
      root.tap do |area|
        area.set_draw_func { |_, context, width, height| draw(context, width, height) }
      end
    end

    # Upstream's `push_peak`: the newest peak goes to the front and the oldest
    # is dropped once there are more than can be drawn.
    def push_peak(peak)
      if @peaks.length > max_n_peaks
        @peaks.pop
      end

      @peaks.unshift(peak.to_f)
      root.queue_draw
      self
    end

    def clear_peaks
      @peaks = []
      root.queue_draw
      self
    end

    def root
      @root ||= Gtk::DrawingArea.new.tap do |area|
        area.content_width = NATURAL_WIDTH
        area.content_height = NATURAL_HEIGHT
      end
    end

    # The maximum number of peaks that can be drawn visibly.
    def max_n_peaks = (root.width.abs / (2 * GUTTER)).to_i

    # The accent colour the stylesheet gives upstream's `waveform` element.
    def color = Adwaita::StyleManager.default.accent_color_rgba

    private

      def draw(context, width, height)
        # Peaks are only popped when they exceed the count on push, so the
        # window being resized has to be handled here too: the number drawn is
        # clamped to the number that fits.
        [@peaks.length, max_n_peaks].min.then do |n_peaks_to_draw|
          if n_peaks_to_draw.positive?
            prepare(context)
            draw_peaks(
              context,
              width,
              height,
              n_peaks_to_draw,
            )
          end
        end
      end

      def prepare(context)
        context.set_line_width(LINE_WIDTH)
        context.set_line_cap(Cairo::LINE_CAP_ROUND)
      end

      def draw_peaks(context, width, height, n_peaks_to_draw)
        v_center = height / 2.0
        pointer = width / 2.0

        @peaks.first(n_peaks_to_draw).each_with_index do |peak, index|
          # The index is reversed so that the alpha value and the height of the
          # lines of the older peaks are lower and shorter respectively.
          (n_peaks_to_draw - index - 1).then do |rev_index|
            draw_peak(
              context,
              peak,
              pointer,
              width,
              v_center,
              rev_index,
              n_peaks_to_draw,
            )
          end

          pointer += GUTTER
        end
      end

      def draw_peak(context, peak, pointer, width, v_center, rev_index, n_peaks_to_draw)
        line_height_factor = Adwaita::Easing.ease(
          Adwaita::Easing::EASE_IN_QUAD,
          rev_index.to_f / n_peaks_to_draw,
        )
        line_height = [peak * v_center * line_height_factor, MIN_LINE_HEIGHT].max

        # Feathering: the older the peak, the more transparent its line.
        context.set_source_rgba(
          color.red,
          color.green,
          color.blue,
          color.alpha * (rev_index.to_f / n_peaks_to_draw),
        )

        stroke_mirrored(
          context,
          pointer,
          width,
          v_center,
          line_height,
        )
      end

      def stroke_mirrored(context, pointer, width, v_center, line_height)
        context.move_to(pointer, v_center + line_height)
        context.line_to(pointer, v_center - line_height)
        context.move_to(width - pointer, v_center + line_height)
        context.line_to(width - pointer, v_center - line_height)
        context.stroke
      end
  end
end
