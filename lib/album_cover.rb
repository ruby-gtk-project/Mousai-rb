# frozen_string_literal: true

require "adwaita"

module Mousai
  # The album art of a song, with a music-note placeholder when there is none.
  #
  # Ported from upstream's src/window/album_cover.rs and
  # data/resources/ui/album_cover.ui: a stack holding a placeholder image and
  # two images that are swapped between so a new cover can cross-fade over the
  # one already shown.
  #
  # Upstream also kicks off the album art download here. The port has no album
  # art service yet, so `#paintable=` is the whole input: the song page and the
  # song tile hand it a texture when they have one and nil when they do not.
  class AlbumCover
    DEFAULT_PIXEL_SIZE = 180
    PLACEHOLDER_SIZE_DIVISOR = 3

    def build
      root.tap do |bin|
        bin.child = stack

        stack.tap do |s|
          s.add_child(placeholder)
          s.add_child(image_a)
          s.add_child(image_b)
          s.visible_child = placeholder
        end
      end
    end

    # Upstream keeps both images at the same pixel size and the placeholder at a
    # third of it.
    def pixel_size=(size)
      image_a.pixel_size = size
      image_b.pixel_size = size
      placeholder.pixel_size = size / PLACEHOLDER_SIZE_DIVISOR
      size
    end

    def pixel_size = image_a.pixel_size

    def enables_crossfade=(enabled)
      if enabled
        stack.transition_type = :crossfade
      else
        stack.transition_type = :none
      end
      enabled
    end

    def enables_crossfade? = stack.transition_type == Gtk::StackTransitionType::CROSSFADE

    # Shows the given paintable, cross-fading from whichever image is currently
    # visible, or shows the placeholder when given nil.
    def paintable=(paintable)
      if paintable
        show_paintable(paintable)
      else
        stack.visible_child = placeholder
      end
      paintable
    end

    def root
      @root ||= Adwaita::Bin.new.tap do |bin|
        bin.add_css_class("card")
        bin.overflow = :hidden
      end
    end

    def stack
      @stack ||= Gtk::Stack.new.tap do |s|
        s.transition_type = :crossfade
      end
    end

    def placeholder
      @placeholder ||= Gtk::Image.new.tap do |image|
        image.icon_name = "emblem-music-symbolic"
        image.pixel_size = DEFAULT_PIXEL_SIZE / PLACEHOLDER_SIZE_DIVISOR
        image.add_css_class("dim-label")
      end
    end

    def image_a
      @image_a ||= Gtk::Image.new.tap do |image|
        image.pixel_size = DEFAULT_PIXEL_SIZE
      end
    end

    def image_b
      @image_b ||= Gtk::Image.new.tap do |image|
        image.pixel_size = DEFAULT_PIXEL_SIZE
      end
    end

    private

      # Paints into whichever of the two images is not showing, then brings it
      # forward, so the stack has something to cross-fade from.
      def show_paintable(paintable)
        crossfade_target.tap do |target|
          target.paintable = paintable
          stack.visible_child = target
        end
      end

      def crossfade_target
        if stack.visible_child == image_a
          image_b
        else
          image_a
        end
      end
  end
end
