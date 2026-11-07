# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "provider_settings"

module Mousai
  # The devel-build GTK Inspector page for forcing a recognition provider.
  #
  # Ported from upstream's src/inspector_page.rs and
  # data/resources/ui/inspector_page.ui: a preferences page with a provider
  # row, a test-provider-mode row, and the two test-duration rows, all backed
  # by the process-global `ProviderSettings`, which the page resets on
  # dispose.
  #
  # Upstream's rows are backed by `AdwEnumListModel` over real GEnum types
  # registered on `ProviderType`/`TestProviderMode`, and the page itself is a
  # registered `MousaiInspectorPage` GObject type that GTK Inspector finds by
  # its "object" property on the `gtk-inspector-page` extension point. The
  # port's provider type and test provider mode are plain Ruby symbols, not
  # GEnums, so the rows are `Gtk::StringList` combo rows over
  # `ProviderType::ALL`/`TestProviderMode::ALL`, the same pattern
  # `PreferencesDialog#audio_source_type_row` uses — and registering a custom
  # `gtk-inspector-page` extension has no path through the Ruby GObject
  # Introspection bindings, which can bind to an extension point but not
  # implement one with a Ruby-defined GType. In place of GTK Inspector, the
  # page is reachable as an ordinary preferences dialog, behind
  # `app.show-inspector-page`, gated the same way upstream gates the whole
  # devel build: on the `MOUSAI_DEVEL` environment variable rather than on a
  # `.Devel` app id, since this port has no separate devel build profile.
  class InspectorPage
    INSPECTOR_TITLE = "Mousai"

    # Upstream names the test providers "(Test)" after their label in the
    # combo; this mirrors that for the two test providers in `ALL`.
    PROVIDER_LABELS = {
      ProviderType::AUD_D         => "AudD",
      ProviderType::AUD_D_MOCK    => "AudD Mock (Test)",
      ProviderType::ERROR_TESTER  => "Error Tester (Test)",
    }.freeze

    TEST_PROVIDER_MODE_LABELS = {
      TestProviderMode::ERROR_ONLY => "Error Only",
      TestProviderMode::VALID_ONLY => "Valid Only",
      TestProviderMode::BOTH       => "Both",
    }.freeze

    MIN_DURATION_SECONDS = 0.0
    MAX_DURATION_SECONDS = 999_999.0
    DURATION_STEP_SECONDS = 1.0

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::PreferencesDialog.new.tap do |d|
        d.title = I18n.gettext(INSPECTOR_TITLE)
        d.add(build)
        d.signal_connect("closed") { dispose }
      end
    end

    def build
      page.tap do |p|
        p.add(group)

        group.tap do |g|
          g.add(provider_row)
          g.add(test_provider_mode_row)
          g.add(test_listen_duration_row)
          g.add(test_recognize_duration_row)

          provider_row.tap do |row|
            row.signal_connect("notify::selected") { on_provider_selected }
          end

          test_provider_mode_row.tap do |row|
            row.signal_connect("notify::selected") { on_test_provider_mode_selected }
          end

          test_listen_duration_row.tap do |row|
            row.signal_connect("notify::value") { on_test_listen_duration_changed }
          end

          test_recognize_duration_row.tap do |row|
            row.signal_connect("notify::value") { on_test_recognize_duration_changed }
          end
        end
      end

      update_test_rows_sensitivity

      page
    end

    # Upstream's `imp.dispose`: the inspector's settings are reset once the
    # page closes, since they only exist to let a developer force a provider
    # for the duration the inspector is open.
    def dispose = ProviderSettings.instance.reset

    def page
      @page ||= Adwaita::PreferencesPage.new
    end

    def group
      @group ||= Adwaita::PreferencesGroup.new.tap do |g|
        g.title = I18n.gettext("Recognizer Developer Settings")
        g.description = I18n.gettext("These will be reset upon closing the inspector")
      end
    end

    def provider_row
      @provider_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = I18n.gettext("Provider")
        row.model = Gtk::StringList.new(ProviderType::ALL.map { |type| I18n.gettext(PROVIDER_LABELS.fetch(type)) })
        row.selected = ProviderType::ALL.index(ProviderSettings.instance.active) || 0
      end
    end

    def test_provider_mode_row
      @test_provider_mode_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = I18n.gettext("Test Provider Mode")
        row.model = Gtk::StringList.new(TestProviderMode::ALL.map { |mode| I18n.gettext(TEST_PROVIDER_MODE_LABELS.fetch(mode)) })
        row.selected = TestProviderMode::ALL.index(ProviderSettings.instance.test_mode) || 0
      end
    end

    def test_listen_duration_row
      @test_listen_duration_row ||= Adwaita::SpinRow.new(duration_adjustment, 1.0, 0).tap do |row|
        row.title = I18n.gettext("Test Listen Duration (seconds)")
        row.snap_to_ticks = true
        row.numeric = true
        row.value = ProviderSettings.instance.test_listen_duration
      end
    end

    def test_recognize_duration_row
      @test_recognize_duration_row ||= Adwaita::SpinRow.new(duration_adjustment, 1.0, 0).tap do |row|
        row.title = I18n.gettext("Test Recognize Duration (seconds)")
        row.snap_to_ticks = true
        row.numeric = true
        row.value = ProviderSettings.instance.test_recognize_duration
      end
    end

    # Neither of `Adwaita::SpinRow#initialize`'s two keyword-argument
    # signatures (`min:`/`max:`/`step:` or `adjustment:`/`climb_rate:`/
    # `digits:`) can be dispatched from Ruby — the GI loader rejects both,
    # keywords and all, with "wrong arguments"; only the positional form
    # `SpinRow.new(adjustment, climb_rate, digits)` works. Each duration row
    # gets its own `Gtk::Adjustment`, which upstream's two `.ui` rows do too
    # (each spins its own `GtkAdjustment`, not a shared one).
    def duration_adjustment
      Gtk::Adjustment.new(0, MIN_DURATION_SECONDS, MAX_DURATION_SECONDS, DURATION_STEP_SECONDS, 10, 0)
    end

    private

      # Upstream's `update_test_rows_sensitivity`: the test rows only matter
      # when the selected provider is one of the two test providers.
      def update_test_rows_sensitivity
        is_test = [ProviderType::AUD_D_MOCK, ProviderType::ERROR_TESTER].include?(selected_provider_type)

        test_provider_mode_row.sensitive = is_test
        test_listen_duration_row.sensitive = is_test
        test_recognize_duration_row.sensitive = is_test
      end

      def selected_provider_type = ProviderType::ALL[provider_row.selected] || ProviderType::DEFAULT

      def on_provider_selected
        ProviderSettings.instance.active = selected_provider_type
        update_test_rows_sensitivity
      end

      def on_test_provider_mode_selected
        ProviderSettings.instance.test_mode =
          TestProviderMode::ALL[test_provider_mode_row.selected] || TestProviderMode::DEFAULT
      end

      def on_test_listen_duration_changed
        ProviderSettings.instance.test_listen_duration = test_listen_duration_row.value
      end

      def on_test_recognize_duration_changed
        ProviderSettings.instance.test_recognize_duration = test_recognize_duration_row.value
      end
  end
end
