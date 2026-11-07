# frozen_string_literal: true

# Drives the app-level dialogs that the main-window and playback drive
# scripts never open: the About dialog, the keyboard-shortcuts dialog, and
# the devel-only inspector page, all reached through the same `app.*`
# `Gio::SimpleAction`s the main menu points at. Ends by activating
# `app.quit` so the quit action itself is exercised too, not just assumed.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_app_dialogs.rb

require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("mousai-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("mousai-data")
# Gates `app.show-inspector-page` into existence — see
# `Mousai::Application#devel?`.
ENV["MOUSAI_DEVEL"] = "1"

require_relative "gtk_driver"
require_relative "../lib/mousai"

app = Mousai::Application.new

GtkDriver.drive(app, shots: "tmp/shots") do |d, application|
  d.window { application.window.root }

  d.step("the about dialog opens") do
    application.show_about_action.activate(nil)
  end

  d.step("its open animation settles") { nil }

  d.step("it shows the app name and version") do
    application.window.root.visible_dialog.then do |dialog|
      d.check("a dialog is showing") { !dialog.nil? }
      d.check("it is the about dialog") { dialog.is_a?(Adwaita::AboutDialog) }
      d.check("application name is set") { dialog.application_name == "Mousai" }
      d.check("version is set") { dialog.version == Mousai::Rb::VERSION }
    end
    d.shot("30-about")
    application.window.root.visible_dialog&.close
  end

  d.step("the shortcuts dialog opens") do
    application.shortcuts_action.activate(nil)
  end

  d.step("its open animation settles too") { nil }

  d.step("it lists the general and controls sections") do
    application.window.root.visible_dialog.then do |dialog|
      d.check("a dialog is showing") { !dialog.nil? }
      d.check("it is the shortcuts dialog") { dialog.is_a?(Adwaita::ShortcutsDialog) }
    end
    d.check("Toggle Listen is in the shortcuts list") do
      Mousai::ShortcutsDialog::CONTROLS_ITEMS.any? { |item| item[:title] == "Toggle Listen" }
    end
    d.check("Toggle Listen points at win.toggle-recognize") do
      Mousai::ShortcutsDialog::CONTROLS_ITEMS.find { |item| item[:title] == "Toggle Listen" }[:action_name] == "win.toggle-recognize"
    end
    d.shot("31-shortcuts")
    application.window.root.visible_dialog&.close
  end

  d.step("the devel inspector page opens") do
    d.check("the inspector action exists under MOUSAI_DEVEL") do
      application.app.lookup_action("show-inspector-page") != nil
    end
    application.show_inspector_page_action.activate(nil)
  end

  d.step("its open animation settles as well") { nil }

  d.step("it opens on the default AudD provider with test rows insensitive") do
    d.check("provider row selects AudD by default") do
      application.inspector_page.provider_row.selected == Mousai::ProviderType::ALL.index(Mousai::ProviderType::AUD_D)
    end
    d.check("test provider mode row is insensitive") { !application.inspector_page.test_provider_mode_row.sensitive? }
    d.check("test listen duration row is insensitive") { !application.inspector_page.test_listen_duration_row.sensitive? }
    d.shot("32-inspector-audd")
  end

  d.step("the provider row is switched to the Error Tester test provider") do
    application.inspector_page.provider_row.selected = Mousai::ProviderType::ALL.index(Mousai::ProviderType::ERROR_TESTER)
  end

  d.step("the test rows become sensitive and the setting is applied") do
    d.check("ProviderSettings.active switched to error_tester") { Mousai::ProviderSettings.instance.active == Mousai::ProviderType::ERROR_TESTER }
    d.check("test provider mode row is now sensitive") { application.inspector_page.test_provider_mode_row.sensitive? }
    d.check("test listen duration row is now sensitive") { application.inspector_page.test_listen_duration_row.sensitive? }
    d.shot("33-inspector-error-tester")
  end

  d.step("the test listen duration is edited") do
    application.inspector_page.test_listen_duration_row.value = 42.0
  end

  d.step("the edit reaches ProviderSettings") do
    d.check("test_listen_duration updated") { Mousai::ProviderSettings.instance.test_listen_duration == 42.0 }
  end

  d.step("the inspector page is closed, resetting the global settings") do
    application.window.root.visible_dialog&.close
  end

  d.step("ProviderSettings reset back to defaults on close") do
    d.check("active reset to AudD") { Mousai::ProviderSettings.instance.active == Mousai::ProviderType::DEFAULT }
    d.check("test_listen_duration reset") { Mousai::ProviderSettings.instance.test_listen_duration == Mousai::ProviderSettings::DEFAULT_TEST_LISTEN_DURATION }
  end

  d.step("app.quit is activated") do
    application.quit_action.activate(nil)
  end
end
