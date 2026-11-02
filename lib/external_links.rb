# frozen_string_literal: true

require_relative "external_link"

module Mousai
  # The ordered set of a song's external links, keyed by provider.
  #
  # Ported from upstream's src/external_links.rs, which is a `gio::ListModel`
  # over an `IndexMap<String, String>` plus a cache of the `ExternalLink`
  # objects it has already handed out. Here the order is kept by a Ruby Hash
  # (insertion-ordered) and the links are built on demand; `#to_a` is what the
  # song page's flow box binds to.
  class ExternalLinks
    # Upstream's `ExternalLinkKey`, serialised in kebab-case.
    APPLE_MUSIC_URL = "apple-music-url"
    AUD_D_URL = "aud-d-url"
    SPOTIFY_URL = "spotify-url"
    YOUTUBE_SEARCH_TERM = "youtube-search-term"

    KNOWN_KEYS = [
      APPLE_MUSIC_URL,
      AUD_D_URL,
      SPOTIFY_URL,
      YOUTUBE_SEARCH_TERM,
    ].freeze

    def self.from_h(hash)
      new.tap do |links|
        hash.each { |key, value| links.insert(key, value) }
      end
    end

    def initialize
      @map = {}
    end

    # Inserts a link, returning true when the key was not present yet — the
    # same signal upstream's `insert` returns so the caller knows whether the
    # model grew or an existing row changed.
    def insert(key, value)
      @map.key?(key.to_s).then do |existed|
        @map[key.to_s] = value.to_s
        !existed
      end
    end

    def get(key) = @map[key.to_s]
    def key?(key) = @map.key?(key.to_s)
    def keys = @map.keys
    def size = @map.size
    def empty? = @map.empty?
    def to_h = @map.dup

    # The links in insertion order, as ExternalLink objects.
    def to_a = @map.map { |key, value| ExternalLink.new(key, value) }

    def each(&block) = to_a.each(&block)
  end
end
