# frozen_string_literal: true

require "adwaita"
require_relative "external_links"
require_relative "i18n"

module Mousai
  # A tile in the song page's "Listen" group, linking out to one provider.
  #
  # Ported from upstream's src/window/external_link_tile.rs and
  # data/resources/ui/external_link_tile.ui: a flow box child whose label,
  # tooltip and style class come from the link's key, and whose activation
  # launches the provider's URI — a YouTube search term is turned into a search
  # URL first.
  class ExternalLinkTile
    # The label, tooltip and CSS class upstream gives each known key. The CSS
    # classes are the ones data/resources/style.css paints (see Style).
    KEYS = {
      ExternalLinks::APPLE_MUSIC_URL     => {
        label:     "Apple Music",
        tooltip:   "Browse on Apple Music",
        css_class: "applemusic",
      },
      ExternalLinks::AUD_D_URL           => {
        label:     "AudD",
        tooltip:   "Browse on AudD",
        css_class: "audd",
      },
      ExternalLinks::SPOTIFY_URL         => {
        label:     "Spotify",
        tooltip:   "Listen on Spotify",
        css_class: "spotify",
      },
      ExternalLinks::YOUTUBE_SEARCH_TERM => {
        label:     "YouTube",
        tooltip:   "Search on YouTube",
        css_class: "youtube",
      },
    }.freeze

    YOUTUBE_SEARCH_URL = "https://www.youtube.com/results?search_query="

    # The characters RFC 3986 calls unreserved, which are the ones that survive
    # percent-encoding — `glib::Uri::escape_string`, which upstream uses, keeps
    # the same set.
    UNRESERVED = /[^A-Za-z0-9\-_.~]/

    # Upstream warns and skips a link whose key it cannot handle, which is what
    # the song page filters its links with.
    def self.can_handle?(link)
      KEYS.key?(link.key).tap do |handled|
        unless handled
          warn("Can't handle external link key `#{link.key}`")
        end
      end
    end

    attr_reader :external_link

    def initialize(external_link, on_launch_failed: nil)
      @external_link = external_link
      @on_launch_failed = on_launch_failed
      @key = KEYS.fetch(external_link.key)
    end

    def build
      root.tap do |child|
        child.child = box

        box.tap do |b|
          b.append(label)
        end
      end
    end

    # The URI the tile opens: the value itself for the providers that store a
    # URL, and a search URL for the YouTube search term.
    def uri
      if @external_link.key == ExternalLinks::YOUTUBE_SEARCH_TERM
        "#{YOUTUBE_SEARCH_URL}#{percent_encode(@external_link.value)}"
      else
        @external_link.value
      end
    end

    # `glib::Uri` has no binding here, so the search term is encoded by hand.
    def percent_encode(value)
      value.to_s.b.gsub(UNRESERVED) { |char| format("%%%02X", char.ord) }
    end

    # Opens the link in the user's browser. A failure is reported back through
    # the callback the song page passes, which shows upstream's toast.
    def handle_activation(parent_window)
      begin
        Gtk::UriLauncher.new(uri).launch(parent_window, nil)
      rescue StandardError => e
        warn("Failed to launch default for uri `#{uri}`: #{e.message}")
        @on_launch_failed&.call(
          I18n.gettext_f(
            # Translators: Do NOT translate the contents between '{' and '}', this is a variable name.
            "Failed to launch {key}",
            { "key" => @external_link.key },
          ),
        )
      end
    end

    def root
      @root ||= Gtk::FlowBoxChild.new.tap do |child|
        child.tooltip_text = I18n.gettext(@key[:tooltip])
        child.add_css_class("external-link-tile")
        child.add_css_class("card")
        child.add_css_class(@key[:css_class])
      end
    end

    def box
      @box ||= Gtk::Box.new(:horizontal, 12).tap do |b|
        b.margin_start = 24
        b.margin_end = 24
        b.margin_top = 18
        b.margin_bottom = 18
        b.halign = :center
      end
    end

    def label
      @label ||= Gtk::Label.new(I18n.gettext(@key[:label])).tap do |l|
        l.valign = :center
        l.add_css_class("title-2")
      end
    end
  end
end
