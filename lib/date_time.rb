# frozen_string_literal: true

require "time"
require_relative "i18n"

module Mousai
  # A date and time that round-trips through ISO 8601.
  #
  # Ported from upstream's src/date_time.rs, which wraps `glib::DateTime` so it
  # can be serialised. Ruby's `Time` already keeps the UTC offset it was parsed
  # with, so this wraps a `Time` instead and keeps upstream's API: `now_utc`,
  # `to_local`, `from_iso8601`, `fuzzy_display`, `format_iso8601` and `format`.
  class DateTime
    include Comparable

    FUZZY_YESTERDAY_HOURS = 30
    ISO8601_PATTERN = /\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/

    attr_reader :time

    class << self
      def now_utc = new(Time.now.utc)

      # Parses an ISO 8601 date and time, raising ArgumentError on anything
      # else. Upstream returns an `anyhow::Result` carrying the same message.
      def from_iso8601(string)
        ISO8601_PATTERN.match(string.to_s).then do |match|
          unless match
            raise(ArgumentError, "Invalid iso8601 datetime `#{string}`")
          end

          new(parse(string.to_s))
        end
      end

      private

        # `Time.iso8601` rejects the hour-only UTC offsets glib writes (`+08`),
        # so those go through the lenient parser. The pattern above has already
        # ruled out strings that are not a date and time at all, which is what
        # upstream rejects.
        def parse(string)
          begin
            Time.iso8601(string)
          rescue ArgumentError
            Time.parse(string)
          end
        end
    end

    def initialize(time)
      @time = time
      freeze
    end

    def to_local = DateTime.new(@time.getlocal)
    def to_utc = DateTime.new(@time.getutc)

    # ISO 8601 with microsecond precision, the format upstream's `Serialize`
    # writes and `from_iso8601` reads back.
    def format_iso8601 = @time.strftime("%Y-%m-%dT%H:%M:%S.%6N%:z")

    def format(format_string) = @time.strftime(format_string)

    # Today's and yesterday's times are shown as a time of day, anything older
    # as an ISO 8601 date.
    def fuzzy_display
      now = Time.now.getlocal(@time.utc_offset)

      if now.strftime("%F") == @time.strftime("%F")
        # Translators: `%R` will be replaced with 24-hour formatted datetime (e.g., `13:21`)
        format(I18n.gettext("today at %R"))
      elsif (now - @time) / 3600 <= FUZZY_YESTERDAY_HOURS
        # Translators: `%R` will be replaced with 24-hour formatted datetime (e.g., `13:21`)
        format(I18n.gettext("yesterday at %R"))
      else
        format("%F") # ISO 8601 (e.g., `2001-07-08`)
      end
    end

    def to_s = format_iso8601
    def <=>(other) = @time <=> other.time
    def eql?(other) = other.is_a?(DateTime) && (other.time.to_r == @time.to_r)
    def ==(other) = eql?(other)
    def hash = @time.to_r.hash
  end
end
