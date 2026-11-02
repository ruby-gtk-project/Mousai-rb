# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "mousai/rb/version"

module Mousai
  # The About dialog.
  #
  # Ported from upstream's src/about.rs, including its links, its release notes
  # and the debug info it attaches as `mousai-debug-info`. The GStreamer and
  # libsoup versions upstream reports are left out — the port links neither —
  # and the Ruby version is reported instead.
  module AboutDialog
    APP_ID = "io.github.seadve.Mousai"
    RELEASE_NOTES_VERSION = "0.7.0"

    RELEASE_NOTES = <<~NOTES
      <p>This update contains huge UI updates and fixes:</p>
      <ul>
        <li>New feature-rich UI</li>
        <li>Added section to browse song information and checkout providers</li>
        <li>Added offline mode</li>
        <li>Added fuzzy search on the history</li>
        <li>Added MPRIS support</li>
        <li>Added ability to remove individual song from history</li>
        <li>The title and artist of the song can now be copied from the UI</li>
        <li>The player is now seekable</li>
        <li>The recognizing stage is now cancellable</li>
        <li>Fixed a lot of bugs and improved stability</li>
        <li>Updated translations</li>
      </ul>
    NOTES

    LINKS = {
      "Donate"    => "https://seadve.github.io/donate/",
      "GitHub"    => "https://github.com/SeaDve/Mousai",
      "Translate" => "https://hosted.weblate.org/projects/seadve/mousai",
    }.freeze

    module_function

    def present(parent)
      dialog.present(parent)
    end

    def dialog
      Adwaita::AboutDialog.new.tap do |about|
        about.application_icon = APP_ID
        about.application_name = I18n.gettext("Mousai")
        about.developer_name = "Dave Patrick Caberto"
        about.version = Mousai::Rb::VERSION
        about.copyright = "© 2023 Dave Patrick Caberto"
        about.license_type = Gtk::License::GPL_3_0
        # Translators: Replace "translator-credits" with your names. Put a comma between.
        about.translator_credits = I18n.gettext("translator-credits")
        about.issue_url = "https://github.com/SeaDve/Mousai/issues"
        about.support_url = "https://github.com/SeaDve/Mousai/discussions"
        about.debug_info = debug_info
        about.debug_info_filename = "mousai-debug-info"
        about.release_notes_version = RELEASE_NOTES_VERSION
        about.release_notes = RELEASE_NOTES

        LINKS.each { |title, uri| about.add_link(I18n.gettext(title), uri) }
      end
    end

    def debug_info
      <<~INFO
        - #{APP_ID} #{Mousai::Rb::VERSION}
        - Flatpak: #{File.exist?("/.flatpak-info")}

        - Language: #{GLib.language_names.join(", ")}

        - Distribution: #{distribution}
        - Desktop Session: #{ENV.fetch("DESKTOP_SESSION", "<unknown>")}
        - Display Server: #{ENV.fetch("XDG_SESSION_TYPE", "<unknown>")}

        - GTK #{Gtk::Version::STRING}
        - Libadwaita #{Adwaita::VERSION_S}
        - Ruby #{RUBY_VERSION}
      INFO
    end

    # `glib::os_info` has no binding here, so the distribution is read from the
    # same file it reads.
    def distribution
      begin
        pretty_name(File.readlines("/etc/os-release"))
      rescue Errno::ENOENT
        "<unknown>"
      end
    end

    def pretty_name(lines)
      lines.grep(/\APRETTY_NAME=/).first.to_s.split("=", 2).last.to_s.strip.delete('"').then do |name|
        if name.empty?
          "<unknown>"
        else
          name
        end
      end
    end
  end
end
