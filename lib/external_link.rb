# frozen_string_literal: true

module Mousai
  # A single external link of a song: the key that names the provider and the
  # value, which is either a URL or a search term.
  #
  # Ported from upstream's src/external_link.rs, a GObject with two
  # construct-only string properties.
  class ExternalLink
    attr_reader :key, :value

    def initialize(key, value)
      @key = key.to_s.freeze
      @value = value.to_s.freeze
      freeze
    end

    def eql?(other) = other.is_a?(ExternalLink) && other.key == @key && other.value == @value
    def ==(other) = eql?(other)
    def hash = [@key, @value].hash
  end
end
