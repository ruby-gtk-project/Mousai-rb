# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "recognize_error"

module Mousai
  # The dialog shown when a recognition failed but can be retried later.
  #
  # Ported from upstream's `Window::present_recording_saved_message` in
  # src/window/mod.rs: the heading is always "Recording Saved" and the body and
  # responses depend on why the recording was kept — a connection failure only
  # needs acknowledging, while a token failure offers to open preferences with
  # the token row focused. The permanent kinds never reach here: those are
  # shown by the recognize error dialog instead.
  module RecordingSavedDialog
    OK_RESPONSE_ID = "ok"
    NO_RESPONSE_ID = "no"
    OPEN_RESPONSE_ID = "open"

    TOKEN_LIMIT_BODY = "The result will be available when your token limit is reset. " \
                       "Wait until the limit is reset or open preferences and try " \
                       "setting a different token"

    INVALID_TOKEN_BODY = "The result will be available when your token is replaced " \
                         "with a valid one. Open preferences and try setting a " \
                         "different token"

    module_function

    # Shows the dialog over `parent`. `on_open_preferences` is called when the
    # user asks for preferences, which upstream opens with the AudD token row
    # focused.
    def present(parent, cause, &on_open_preferences)
      if cause.permanent?
        raise(ArgumentError, "permanent errors must not be saved")
      end

      dialog(cause, &on_open_preferences).present(parent)
    end

    def dialog(cause, &on_open_preferences)
      Adwaita::AlertDialog.new(I18n.gettext("Recording Saved"), nil).tap do |alert|
        case cause.kind
        when RecognizeError::CONNECTION then build_connection(alert)
        else build_token(alert, cause, &on_open_preferences)
        end
      end
    end

    def build_connection(alert)
      alert.body = I18n.gettext("The result will be available when you're back online")
      alert.add_response(OK_RESPONSE_ID, I18n.gettext("Ok, Got It"))
      alert.default_response = OK_RESPONSE_ID
    end

    def build_token(alert, cause, &on_open_preferences)
      if cause.kind == RecognizeError::TOKEN_LIMIT_REACHED
        alert.body = I18n.gettext(TOKEN_LIMIT_BODY)
        alert.add_response(NO_RESPONSE_ID, I18n.gettext("I'll Wait"))
      else
        alert.body = I18n.gettext(INVALID_TOKEN_BODY)
        alert.add_response(NO_RESPONSE_ID, I18n.gettext("Later"))
      end

      alert.add_response(OPEN_RESPONSE_ID, I18n.gettext("Open Preferences"))
      alert.set_response_appearance(OPEN_RESPONSE_ID, Adwaita::ResponseAppearance::SUGGESTED)
      alert.default_response = OPEN_RESPONSE_ID
      alert.signal_connect("response") do |_, response|
        if response == OPEN_RESPONSE_ID
          on_open_preferences&.call
        end
      end
    end
  end
end
