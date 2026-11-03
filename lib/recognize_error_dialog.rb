# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "recognize_error"

module Mousai
  # The dialog shown when a recognition failed for good.
  #
  # Ported from upstream's `Window::present_recognize_error` in
  # src/window/mod.rs: the error's own title is the heading, and the body and
  # responses depend on the kind — a fingerprint or other permanent failure
  # offers to open an issue, and "no matches" offers to listen again. The
  # non-permanent kinds never reach here: those recordings are saved instead,
  # and the recording-saved dialog speaks for them.
  module RecognizeErrorDialog
    NO_RESPONSE_ID = "no"
    OPEN_RESPONSE_ID = "open"
    TRY_AGAIN_RESPONSE_ID = "try-again"

    ISSUE_URI = "https://github.com/SeaDve/Mousai/issues/new?assignees=&labels=&template=bug_report.md"

    module_function

    # Shows the dialog over `parent`. `on_try_again` is called when the user
    # asks to listen again, which upstream does by activating
    # `win.toggle-recognize`.
    def present(parent, error, &on_try_again)
      unless error.permanent?
        raise(ArgumentError, "non permanent errors must be saved instead")
      end

      dialog(parent, error, &on_try_again).present(parent)
    end

    def dialog(parent, error, &on_try_again)
      Adwaita::AlertDialog.new(error.title, nil).tap do |alert|
        case error.kind
        when RecognizeError::NO_MATCHES then build_no_matches(alert, &on_try_again)
        else build_report(alert, parent)
        end
      end
    end

    def build_report(alert, parent)
      alert.body = I18n.gettext(
        "Please open an issue on GitHub and provide the necessary information",
      )
      alert.add_response(NO_RESPONSE_ID, I18n.gettext("No, Thanks"))
      alert.add_response(OPEN_RESPONSE_ID, I18n.gettext("Open an Issue"))
      alert.set_response_appearance(OPEN_RESPONSE_ID, Adwaita::ResponseAppearance::SUGGESTED)
      alert.default_response = OPEN_RESPONSE_ID
      alert.signal_connect("response") do |_, response|
        if response == OPEN_RESPONSE_ID
          launch_issue_page(parent)
        end
      end
    end

    def build_no_matches(alert, &on_try_again)
      alert.body = I18n.gettext(
        "Try moving closer to the source or using a different excerpt of the song",
      )
      alert.add_response(NO_RESPONSE_ID, I18n.gettext("No, Thanks"))
      alert.add_response(TRY_AGAIN_RESPONSE_ID, I18n.gettext("Try Again"))
      alert.set_response_appearance(TRY_AGAIN_RESPONSE_ID, Adwaita::ResponseAppearance::SUGGESTED)
      alert.default_response = TRY_AGAIN_RESPONSE_ID
      alert.signal_connect("response") do |_, response|
        if response == TRY_AGAIN_RESPONSE_ID
          on_try_again&.call
        end
      end
    end

    def launch_issue_page(parent)
      begin
        Gtk::UriLauncher.new(ISSUE_URI).launch(parent, nil)
      rescue StandardError => e
        warn("Failed to open bug report URI: #{e.message}")
      end
    end
  end
end
