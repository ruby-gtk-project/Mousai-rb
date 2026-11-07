# frozen_string_literal: true

require "gtk4"
require "adwaita"
require_relative "../about_dialog"
require_relative "../album_art"
require_relative "../database"
require_relative "../database_error_dialog"
require_relative "../inspector_page"
require_relative "../migrations"
require_relative "../player"
require_relative "../preferences_dialog"
require_relative "../provider_settings"
require_relative "../recognizer"
require_relative "../recordings"
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
  # The player, the album art store, the provider settings and the recognizer
  # are owned here, as upstream owns them, and a database that could not be
  # read brings up the critical database error dialog over the window.
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
      "win.toggle-playback"  => ["<Control>space"],
      "win.toggle-search"    => ["<Control>f"],
    }.freeze

    def build
      app.tap do
        app.signal_connect("startup") do
          detach_glib_log_handlers
          Style.load
          load_icons
        end

        app.signal_connect("activate") do
          # The recordings must be bound to the recognizer before the window
          # is built: `RecognizerStatus` reads `recognizer.saved_recordings`
          # while building itself.
          recordings
          window.build
          window.present
          present_database_error
        end

        app.add_action(quit_action)
        app.add_action(show_preferences_action)
        app.add_action(show_about_action)
        app.add_action(shortcuts_action)
        app.add_action(show_inspector_page_action) if devel?

        ACCELS.each { |action, accels| app.set_accels_for_action(action, accels) }
      end
    end

    def run(argv = []) = app.run(argv)

    # Adwaita::Application is unreliable in the Ruby bindings; the application
    # object comes from Gtk and only the window is Adwaita.
    def app = @app ||= Gtk::Application.new(APP_ID, :default_flags)

    def settings = @settings ||= Settings.new
    def database = @database ||= Database.new
    def player = @player ||= Player.new
    def album_art_store = @album_art_store ||= AlbumArtStore.new
    def recognizer = @recognizer ||= Recognizer.new(settings: settings)

    # The recordings saved for later recognition, loaded from the database and
    # bound to the recognizer so it retries them as connectivity allows —
    # upstream's `imp.recognizer.bind_saved_recordings(recordings)`.
    def recordings
      @recordings ||= Recordings.new(database: database).load.tap { |loaded| recognizer.bind_saved_recordings(loaded) }
    end

    # The process-global provider settings the test providers read — upstream's
    # `ProviderSettings::lock`.
    def provider_settings = ProviderSettings.instance

    # The provider the recognition goes through, built from the active provider
    # type and the token the preferences dialog edits — upstream's
    # `ProviderType::to_provider`.
    def provider
      ProviderType.to_provider(provider_settings.active, api_token: settings.aud_d_api_token)
    end

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
        song_list:       song_list,
        settings:        settings,
        player:          player,
        album_art_store: album_art_store,
        recognizer:      recognizer,
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

    def show_inspector_page_action
      @show_inspector_page_action ||= Gio::SimpleAction.new("show-inspector-page").tap do |action|
        action.signal_connect("activate") { inspector_page.present(window.root) }
      end
    end

    # Upstream's devel build installs `InspectorPage` as a GTK Inspector
    # extension unconditionally, gated at runtime only by GTK Inspector's own
    # object-property check; the app id itself does not vary. This port has
    # no devel build profile, so the action the page sits behind is gated on
    # this environment variable instead.
    def devel? = ENV.key?("MOUSAI_DEVEL")

    def inspector_page = @inspector_page ||= InspectorPage.new

    # The icons upstream ships in its gresource bundle — the app icon and the
    # three symbolic ones its UI names — live in data/icons here, so the icon
    # theme is pointed at them.
    def icons_path = File.expand_path("../../data/icons", __dir__)

    private

      # glib2 routes GLib log messages into a Ruby callback, and calling into
      # Ruby from a thread Ruby does not own crashes the process. GTK's media
      # backend logs from GStreamer's own worker threads, so playing a song
      # would take the app down with it. Detaching the Ruby handlers puts GLib
      # back on its own default handler, which prints the message to stderr
      # from whichever thread logged it.
      def detach_glib_log_handlers
        begin
          GLib::Log.cancel_handler
        rescue StandardError => e
          warn("Failed to detach the GLib log handler: #{e.message}")
        end
      end

      def load_icons
        Gdk::Display.default.then do |display|
          if display
            Gtk::IconTheme.get_for_display(display).add_search_path(icons_path)
          end
        end
      end

      # Upstream creates the window either way and leaves its models unbound
      # when the database could not be opened, then presents this dialog over
      # it; the port's window is up with an empty history in the same case.
      def present_database_error
        database.load_error.then do |error|
          if error
            warn("Failed to setup db env: #{error.message}")
            DatabaseErrorDialog.present(window.root) { app.quit }
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
