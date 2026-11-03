# frozen_string_literal: true

require "gtk4"
require "net/http"
require "uri"

module Mousai
  # A song's album art, downloaded once and kept in memory.
  #
  # Ported from upstream's src/album_art.rs: `AlbumArtStore`, which hands out
  # one `AlbumArt` per download URL so two songs sharing a cover share the
  # download, and `AlbumArt`, whose texture is downloaded on first use and
  # cached from then on.
  #
  # Upstream downloads through the application's `soup::Session` and awaits the
  # result; the port downloads with Net::HTTP on a worker thread and builds the
  # texture back on the main loop, because `Gdk::Texture` must be created
  # there. Upstream's `OnceCell` makes concurrent `texture()` calls share one
  # download, and so does the list of waiters here.
  class AlbumArtStore
    def initialize
      @map = {}
    end

    # Upstream's `get_or_init`.
    def get_or_init(download_url)
      @map[download_url.to_s] ||= AlbumArt.new(download_url.to_s)
    end

    def size = @map.size
  end

  # One album art, identified by the URL it is downloaded from.
  class AlbumArt
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30
    MAX_REDIRECTS = 5

    attr_reader :download_url

    def initialize(download_url)
      @download_url = download_url
      @waiters = []
      @downloading = false
    end

    # Whether the album art is loaded in memory.
    def loaded? = !@texture.nil?

    # The texture, or nil while it has not been downloaded yet. The song page
    # uses this to decide whether showing the cover needs a cross-fade.
    def cached_texture = @texture

    # Calls the block with the texture once it is available, or with nil when
    # the download or the decode failed. A texture already in memory is handed
    # over without touching the network.
    def texture(&block)
      if @texture
        block.call(@texture)
      else
        @waiters << block
        start_download
      end
      self
    end

    private

      def start_download
        unless @downloading
          @downloading = true
          Thread.new { deliver(fetch_bytes) }
        end
      end

      # Hands the downloaded bytes back to the main loop, where the texture is
      # built and every waiter is called.
      def deliver(bytes)
        GLib::Idle.add do
          @downloading = false
          @texture = bytes && build_texture(bytes)
          @waiters.each { |waiter| waiter.call(@texture) }
          @waiters = []
          GLib::Source::REMOVE
        end
      end

      def build_texture(bytes)
        begin
          GdkPixbuf::PixbufLoader.new.then do |loader|
            loader.write(bytes)
            loader.close
            Gdk::Texture.new(loader.pixbuf)
          end
        rescue StandardError => e
          warn("Failed to load album art texture from bytes: #{e.message}")
          nil
        end
      end

      def fetch_bytes(url = @download_url, redirects_left = MAX_REDIRECTS)
        begin
          get(URI.parse(url)).then do |response|
            case response
            when Net::HTTPSuccess then response.body
            when Net::HTTPRedirection then follow(response, redirects_left)
            else
              warn("Failed to download album art bytes: #{response.code}")
              nil
            end
          end
        rescue StandardError => e
          warn("Failed to download album art bytes: #{e.message}")
          nil
        end
      end

      def follow(response, redirects_left)
        if redirects_left.positive?
          fetch_bytes(response["location"], redirects_left - 1)
        else
          warn("Failed to download album art bytes: too many redirects")
          nil
        end
      end

      def get(uri)
        Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl:      uri.scheme == "https",
          open_timeout: OPEN_TIMEOUT,
          read_timeout: READ_TIMEOUT,
        ) { |http| http.request(Net::HTTP::Get.new(uri)) }
      end
  end
end
