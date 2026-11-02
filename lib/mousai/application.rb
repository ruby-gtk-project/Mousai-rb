# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "../about_dialog"
require_relative "../database"
require_relative "../migrations"
require_relative "../preferences_dialog"
require_relative "../settings"
require_relative "../shortcuts_dialog"
require_relative "../song_list"
require_relative "../style"
require_relative "../window"

module Mousai
  # The application.
  #
  # Ported from upstream's src/application.rs: the app id, the stylesheet
  # loaded at startup, the song history loaded from the database, the `app.*`
  # actions the main menu points at, and the accelerators.
  #
  # Upstream also owns the player, the recognizer, the HTTP session and the
  # album art store, and presents a dialog when the database cannot be opened;
  # none of those are ported yet.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = "io.github.seadve.Mousai"

    ACCELS = {
      "app.quit"             => ["<Control>q"],
      "app.show-preferences" => ["<Control>comma"],
      "window.close"         => ["<Control>w"],
      "win.toggle-search"    => ["<Control>f"],
    }.freeze

    def build
      app.tap do
        app.signal_connect("startup") do
          Style.load
          load_icons
        end

        app.signal_connect("activate") do
          window.build
          window.present
        end

        app.add_action(quit_action)
        app.add_action(show_preferences_action)
        app.add_action(show_about_action)
        app.add_action(shortcuts_action)

        ACCELS.each { |action, accels| app.set_accels_for_action(action, accels) }
      end
    end

    def run(argv = []) = app.run(argv)

    # Adwaita::Application is unreliable in the Ruby bindings; the application
    # object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    def settings = @settings ||= Settings.new
    def database = @database ||= Database.new

    # The history, loaded from the database. Upstream runs the database
    # migrations before reading it, and so does this.
    def song_list
      @song_list ||= SongList.new(database: database).tap do |list|
        migrations.run(database)
        list.load
      end
    end

    # No migration is pending: upstream's only migration moved the history out
    # of the legacy `memory-list` setting, which this port never wrote.
    def migrations = @migrations ||= Migrations.new

    def window
      @window ||= Window.new(
        app,
        song_list: song_list,
        settings:  settings,
      )
    end

    def quit_action
      @quit_action ||= Gio::SimpleAction.new("quit").tap do |action|
        action.signal_connect("activate") { app.quit }
      end
    end

    def show_preferences_action
      @show_preferences_action ||= Gio::SimpleAction.new("show-preferences").tap do |action|
        action.signal_connect("activate") { present_preferences }
      end
    end

    def show_about_action
      @show_about_action ||= Gio::SimpleAction.new("show-about").tap do |action|
        action.signal_connect("activate") { AboutDialog.present(window.root) }
      end
    end

    def shortcuts_action
      @shortcuts_action ||= Gio::SimpleAction.new("shortcuts").tap do |action|
        action.signal_connect("activate") { ShortcutsDialog.present(window.root) }
      end
    end

    # The icons upstream ships in its gresource bundle — the app icon and the
    # three symbolic ones its UI names — live in data/icons here, so the icon
    # theme is pointed at them.
    def icons_path = File.expand_path("../../data/icons", __dir__)

    private

      def load_icons
        Gdk::Display.default.then do |display|
          if display
            Gtk::IconTheme.get_for_display(display).add_search_path(icons_path)
          end
        end
      end

      def present_preferences
        PreferencesDialog.new(settings).tap do |dialog|
          dialog.build
          dialog.present(window.root)
        end
      end
  end
end
