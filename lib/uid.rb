# frozen_string_literal: true

module Mousai
  # A unique id made up of a namespace and a unique string.
  #
  # Ported from upstream's src/uid.rs. Upstream wraps a `Box<str>` in a
  # `glib::ValueDelegate` so the id can travel through GObject properties and
  # be used as an LMDB key; here it is a plain immutable value object that
  # compares and hashes by its string, which is all the rest of the port needs.
  class Uid
    attr_reader :value

    class << self
      # Creates an id from the given string. The caller must ensure the string
      # is unique.
      def from(unique_str) = new(unique_str.to_s)

      # Creates an id from `unique_str` prefixed with `prefix`, joined with a
      # `-`. The caller must ensure the string is unique within the prefix.
      def from_prefixed(prefix, unique_str) = new("#{prefix}-#{unique_str}")

      # Generates an id from the current real time and a random 32-bit number,
      # both in hex — the same shape upstream's `Uid::generate` produces.
      def generate
        new(
          format(
            "%<time>x-%<random>x",
            time:   (Time.now.to_f * 1_000_000).to_i,
            random: Kernel.rand(0x1_0000_0000),
          ),
        )
      end
    end

    def initialize(value)
      @value = value.to_s.freeze
      freeze
    end

    def to_s = @value
    def to_str = @value
    def inspect = "#<Mousai::Uid #{@value.inspect}>"
    def hash = @value.hash
    def eql?(other) = other.is_a?(Uid) && other.value == @value
    def ==(other) = eql?(other)
  end
end
