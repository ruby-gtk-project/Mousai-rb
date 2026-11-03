# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require_relative "aud_d_response"
require_relative "external_links"
require_relative "provider"
require_relative "recognize_error"
require_relative "song"
require_relative "uid"

module Mousai
  # The AudD recognition provider.
  #
  # Ported from upstream's src/recognizer/provider/aud_d/mod.rs: the POST to
  # api.audd.io with the base64-encoded recording, the five-second listen
  # duration, and `build_song_from_response_bytes`, which turns one response
  # into a Song — its id from the info link, its external links, and the album
  # art, playback link and lyrics gathered from the Spotify and Apple Music
  # sections in upstream's order of preference.
  #
  # Upstream posts through the application's shared `soup::Session`; the port
  # has no soup binding, so the request goes through Ruby's Net::HTTP and the
  # name-resolution failures upstream turns into `Connection` errors are the
  # ones Net::HTTP raises for the same conditions.
  class AudD < Provider
    ENDPOINT = "https://api.audd.io/"
    RETURN_FIELDS = "spotify,apple_music,musicbrainz,lyrics"
    LISTEN_DURATION = 5.0
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    # Upstream trims this prefix off the info link because the remainder is
    # unique to every song.
    INFO_LINK_PREFIX = "https://lis.tn/"

    # Apple Music artwork URLs carry size placeholders.
    ARTWORK_SIZE = "600"

    # The errors Net::HTTP raises when the server could not be reached at all,
    # which is upstream's `ResolverError::NotFound`/`TemporaryFailure` case.
    CONNECTION_ERRORS = [
      SocketError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH,
      Errno::ETIMEDOUT,
      Net::OpenTimeout,
      Net::ReadTimeout,
    ].freeze

    class << self
      # Upstream's `build_song_from_response_bytes`.
      def build_song_from_response_bytes(response_bytes)
        AudDResponse.parse(response_bytes).data.then { |data| build_song(data) }
      end

      private

        def build_song(data)
          album_images = []
          playback_links = []
          links = ExternalLinks.new
          lyrics = nil

          links.insert(ExternalLinks::AUD_D_URL, data.info_link)
          links.insert(ExternalLinks::YOUTUBE_SEARCH_TERM, "#{data.artist} - #{data.title}")

          data.spotify_data.then do |spotify|
            if spotify
              collect_spotify(
                spotify,
                links,
                album_images,
                playback_links,
              )
            end
          end

          data.apple_music_data.then do |apple_music|
            if apple_music
              collect_apple_music(
                apple_music,
                links,
                album_images,
                playback_links,
              )
            end
          end

          data.lyrics_data.then do |lyrics_data|
            if lyrics_data.is_a?(Hash) && !lyrics_data["lyrics"].to_s.empty?
              lyrics = lyrics_data["lyrics"].to_s
            end
          end

          Song.build(
            id:             Uid.from_prefixed("AudD", data.info_link.delete_prefix(INFO_LINK_PREFIX)),
            title:          data.title,
            artist:         data.artist,
            album:          data.album,
            release_date:   data.release_date,
            external_links: links,
            album_art_link: album_images.first,
            playback_link:  playback_links.first,
            lyrics:         lyrics,
          )
        end

        def collect_spotify(spotify, links, album_images, playback_links)
          spotify.dig("album", "images").then do |images|
            if images.is_a?(Array) && images.first.is_a?(Hash)
              album_images << images.first["url"].to_s
            end
          end

          spotify["preview_url"].to_s.then do |preview_url|
            unless preview_url.empty?
              playback_links << preview_url
            end
          end

          links.insert(ExternalLinks::SPOTIFY_URL, spotify.dig("external_urls", "spotify").to_s)
        end

        # Upstream pops the last preview and replaces the artwork URL's `{w}`
        # and `{h}` placeholders with 600.
        def collect_apple_music(apple_music, links, album_images, playback_links)
          links.insert(ExternalLinks::APPLE_MUSIC_URL, apple_music["url"].to_s)

          apple_music["previews"].then do |previews|
            if previews.is_a?(Array) && previews.last.is_a?(Hash)
              playback_links << previews.last["url"].to_s
            end
          end

          apple_music.dig("artwork", "url").then do |url|
            if url
              album_images << url.to_s.gsub("{w}", ARTWORK_SIZE).gsub("{h}", ARTWORK_SIZE)
            end
          end
        end
    end

    def initialize(api_token = nil)
      super()
      @api_token = api_token.to_s
    end

    def recognize(bytes)
      self.class.build_song_from_response_bytes(post(bytes))
    end

    def listen_duration = LISTEN_DURATION

    private

      def post(bytes)
        begin
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
            http.request(request(bytes)).body
          end
        rescue *CONNECTION_ERRORS => e
          raise(RecognizeError.new(RecognizeError::CONNECTION, e.message))
        rescue StandardError => e
          raise(RecognizeError.new(RecognizeError::OTHER_PERMANENT, e.message))
        end
      end

      def request(bytes)
        Net::HTTP::Post.new(uri).tap do |post|
          post["Content-Type"] = "application/json"
          post.body = JSON.generate(
            "api_token" => @api_token,
            "return"    => RETURN_FIELDS,
            # `[str].pack("m0")` is strict base64: no line breaks, padded —
            # which is what upstream's `glib::base64_encode` produces. The
            # base64 gem is not a default gem any more, so it is not required.
            "audio"     => [bytes.to_s].pack("m0"),
          )
        end
      end

      def uri = @uri ||= URI.parse(ENDPOINT)
  end
end
