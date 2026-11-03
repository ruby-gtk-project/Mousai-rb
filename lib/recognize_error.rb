# frozen_string_literal: true

require_relative "i18n"

module Mousai
  # Why a recognition failed.
  #
  # Ported from upstream's src/recognizer/provider/error.rs: the six error
  # kinds, the human-readable title each one displays as, the optional message
  # the provider attaches, and `is_permanent`, which decides whether the
  # recording is retried later or the failure is shown to the user right away.
  #
  # Upstream is a `glib::Boxed` so it can be stored on a `Recording` property
  # and serialised with the recording; here it is a Ruby exception, which is
  # both the value the providers return and the error the recognizer raises.
  class RecognizeError < StandardError
    NO_MATCHES = :no_matches
    FINGERPRINT = :fingerprint
    INVALID_TOKEN = :invalid_token
    TOKEN_LIMIT_REACHED = :token_limit_reached
    CONNECTION = :connection
    OTHER_PERMANENT = :other_permanent

    KINDS = [
      NO_MATCHES,
      FINGERPRINT,
      INVALID_TOKEN,
      TOKEN_LIMIT_REACHED,
      CONNECTION,
      OTHER_PERMANENT,
    ].freeze

    # The kinds upstream's `is_permanent` answers true for.
    PERMANENT_KINDS = [NO_MATCHES, FINGERPRINT, OTHER_PERMANENT].freeze

    attr_reader :kind, :detail

    # Reads back an error written by #to_h, with upstream's serde field names.
    def self.from_h(hash)
      new(hash["kind"].to_s.to_sym, hash["message"])
    end

    def initialize(kind, detail = nil)
      unless KINDS.include?(kind)
        raise(ArgumentError, "kind must be one of #{KINDS.join(", ")}")
      end

      @kind = kind
      @detail = detail && detail.to_s
      super(display)
    end

    # The heading the error dialogs show — upstream's `RecognizeError::title`.
    def title
      case @kind
      when NO_MATCHES then I18n.gettext("No Matches Found")
      when FINGERPRINT then I18n.gettext("Cannot Create Fingerprint From Audio")
      when INVALID_TOKEN then I18n.gettext("Invalid Token Given")
      when TOKEN_LIMIT_REACHED then I18n.gettext("Token Limit Reached")
      when CONNECTION then I18n.gettext("Cannot Connect to the Server")
      else I18n.gettext("Received Other Permanent Error")
      end
    end

    # Upstream's `Display`: the title, followed by the provider's message when
    # there is one.
    def display
      if @detail
        "#{title}: #{@detail}"
      else
        title
      end
    end

    # Whether the failure is permanent (i.e. "no matches found for this
    # recording", in contrast to "internet connection error" or "expired token
    # error").
    #
    # Permanent failures are not retried because they are unlikely to be
    # resolved by retrying.
    def permanent? = PERMANENT_KINDS.include?(@kind)

    def to_h = {"kind" => @kind.to_s, "message" => @detail}

    def eql?(other) = other.is_a?(RecognizeError) && other.kind == @kind && other.detail == @detail
    def ==(other) = eql?(other)
    def hash = [@kind, @detail].hash
  end
end
