# frozen_string_literal: true

require "adwaita"
require_relative "i18n"

module Mousai
  # The dialog shown when the database could not be opened.
  #
  # Ported from upstream's `Application::present_database_error_dialog` in
  # src/application.rs: one dialog with one response, which quits the app, and
  # a body whose link to the issue page is markup.
  module DatabaseErrorDialog
    QUIT_RESPONSE_ID = "quit"

    BODY = "Sorry, a critical database error has occurred. This is likely caused " \
           "by a tampered or corrupted database. You can try clearing application " \
           "data. However, this is not recommended and will delete all your songs " \
           "and saved recordings.\n\nTo report this issue, please launch Mousai in " \
           "the terminal to include the logs and submit the bug report to the " \
           "<a href=\"https://github.com/SeaDve/Mousai/issues/\">issue page</a>"

    module_function

    # Shows the dialog over `parent`, calling the block when the user picks the
    # one response — upstream calls `Application::quit` there.
    def present(parent, &on_quit)
      dialog.tap do |alert|
        alert.signal_connect("response") { on_quit&.call }
        alert.present(parent)
      end
    end

    def dialog
      Adwaita::AlertDialog.new(
        I18n.gettext("Critical Database Error"),
        I18n.gettext(BODY),
      ).tap do |alert|
        alert.body_use_markup = true
        alert.add_response(QUIT_RESPONSE_ID, I18n.gettext("Quit"))
        alert.set_response_appearance(QUIT_RESPONSE_ID, Adwaita::ResponseAppearance::SUGGESTED)
        alert.default_response = QUIT_RESPONSE_ID
        alert.close_response = QUIT_RESPONSE_ID
      end
    end
  end
end
