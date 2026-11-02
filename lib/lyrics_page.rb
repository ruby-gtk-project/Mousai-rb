# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "song"

module Mousai
  # The page showing a song's lyrics.
  #
  # Ported from upstream's src/window/lyrics_page.rs and
  # data/resources/ui/lyrics_page.ui: a navigation page whose window title is
  # the song's "Artist - Title" over a "Lyrics" subtitle, and whose content is
  # the lyrics in a clamped, wrapping label.
  class LyricsPage
    attr_reader :song

    def build
      root.tap do
        # The child is the navigation page's constructor argument — the Ruby
        # bindings take it positionally — so build only fills it in.
        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scroller

          header_bar.tap do |bar|
            bar.title_widget = window_title
          end

          scroller.tap do |window|
            window.child = clamp

            clamp.tap do |c|
              c.child = label
            end
          end
        end
      end
    end

    def song=(new_song)
      new_song.then do |song|
        unless song == @song
          @song = song
          update_ui
        end
      end
    end

    def root = @root ||= Adwaita::NavigationPage.new(toolbar_view, I18n.gettext("Lyrics"))
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def window_title
      @window_title ||= Adwaita::WindowTitle.new("", I18n.gettext("Lyrics"))
    end

    def scroller = @scroller ||= Gtk::ScrolledWindow.new
    def clamp = @clamp ||= Adwaita::Clamp.new

    def label
      @label ||= Gtk::Label.new.tap do |l|
        l.margin_start = 24
        l.margin_end = 24
        l.margin_top = 24
        l.margin_bottom = 24
        l.wrap = true
        l.xalign = 0
        l.add_css_class("lyrics-label")
      end
    end

    private

      def update_ui
        if @song
          show_song(@song)
        else
          root.title = I18n.gettext("Lyrics")
          window_title.title = ""
          label.text = ""
        end
      end

      def show_song(song)
        song.artist_title_text.then do |title_text|
          root.title = "#{title_text} (#{I18n.gettext("Lyrics")})"
          window_title.title = title_text
          label.text = song.lyrics.to_s
        end
      end
  end
end
