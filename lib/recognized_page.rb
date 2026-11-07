# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "recognized_page_tile"

module Mousai
  # The page shown after one or more saved recordings are recognized while
  # the app was offline: a heading, a short blurb, and a carousel of tiles the
  # user can open from.
  #
  # Ported from upstream's src/window/recognized_page.rs and
  # data/resources/ui/recognized_page.ui: the heading and body pick their
  # singular or plural wording off the number of songs, the carousel's
  # spacing narrows in the window's narrow adaptive mode, and the Left/Right
  # keys step to the previous/next tile, wrapping around.
  class RecognizedPage
    NORMAL_CAROUSEL_SPACING = 48
    NARROW_CAROUSEL_SPACING = 6

    attr_reader :adaptive_mode

    def initialize(songs, player:, album_art_store:, on_song_activated: nil)
      @songs = songs
      @player = player
      @album_art_store = album_art_store
      @on_song_activated = on_song_activated
      @adaptive_mode = :normal
      @tiles = []
    end

    def build
      root.tap do
        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scroller

          scroller.tap do |s|
            s.child = content_box

            content_box.tap do |box|
              box.append(heading_box)
              box.append(carousel)
              box.append(carousel_indicator)

              heading_box.tap do |b|
                b.append(heading_label)
                b.append(body_label)
              end

              carousel_indicator.tap do |indicator|
                indicator.carousel = carousel
              end
            end
          end
        end

        root.add_controller(key_controller)

        key_controller.tap do |controller|
          controller.signal_connect("key-pressed") do |_, keyval, _keycode, _state|
            key_pressed(keyval)
          end
        end
      end.tap do
        update_labels
        update_carousel_spacing
        populate_carousel
      end
    end

    def adaptive_mode=(mode)
      mode.then do |new_mode|
        unless new_mode == @adaptive_mode
          @adaptive_mode = new_mode
          update_carousel_spacing
        end
      end
    end

    def root
      @root ||= Adwaita::NavigationPage.new(toolbar_view, I18n.gettext("Recognized Song"))
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_title = false
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |s|
        s.hscrollbar_policy = :never
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.margin_top = 24
        box.margin_bottom = 24
      end
    end

    def heading_box
      @heading_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.margin_start = 24
        box.margin_end = 24
      end
    end

    def heading_label
      @heading_label ||= Gtk::Label.new.tap do |label|
        label.xalign = 0.5
        label.justify = :center
        label.wrap = true
        label.add_css_class("title-1")
      end
    end

    def body_label
      @body_label ||= Gtk::Label.new.tap do |label|
        label.xalign = 0.5
        label.justify = :center
        label.wrap = true
      end
    end

    def carousel
      @carousel ||= Adwaita::Carousel.new.tap do |c|
        c.vexpand = true
        c.valign = :center
        c.allow_long_swipes = true
      end
    end

    def carousel_indicator = @carousel_indicator ||= Adwaita::CarouselIndicatorDots.new

    def key_controller
      @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
        controller.propagation_phase = :capture
      end
    end

    private

      def update_labels
        n_songs = @songs.length

        if n_songs == 1
          root.title = I18n.gettext("Recognized Song")
        else
          root.title = I18n.gettext("Recognized Songs")
        end

        if n_songs == 1
          heading_label.label = I18n.gettext_f("Recognized {n_songs} New Song", {"n_songs" => n_songs.to_s})
        else
          heading_label.label = I18n.gettext_f("Recognized {n_songs} New Songs", {"n_songs" => n_songs.to_s})
        end

        if n_songs == 1
          body_label.label = I18n.gettext("This song was recognized from your saved recording")
        else
          body_label.label = I18n.gettext("These songs were recognized from your saved recordings")
        end
      end

      def update_carousel_spacing
        if @adaptive_mode == :narrow
          carousel.spacing = NARROW_CAROUSEL_SPACING
        else
          carousel.spacing = NORMAL_CAROUSEL_SPACING
        end
      end

      def populate_carousel
        @songs.each do |song|
          RecognizedPageTile.new(
            song,
            player:          @player,
            album_art_store: @album_art_store,
          ).tap do |tile|
            tile.on_activated { @on_song_activated&.call(tile.song) }
            carousel.append(tile.build)
            @tiles << tile
          end
        end
      end

      def key_pressed(keyval)
        if keyval == Gdk::Keyval::KEY_Left
          go_to_tile_relative(-1)
          true
        elsif keyval == Gdk::Keyval::KEY_Right
          go_to_tile_relative(1)
          true
        else
          false
        end
      end

      def go_to_tile_relative(delta)
        n_tiles = carousel.n_pages

        unless n_tiles.zero?
          new_position = (carousel.position.round + delta + n_tiles) % n_tiles
          carousel.scroll_to(carousel.nth_page(new_position), true)
        end
      end
  end
end
