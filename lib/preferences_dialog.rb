# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "settings"

module Mousai
  # The preferences dialog.
  #
  # Ported from upstream's src/preferences_dialog.rs and
  # data/resources/ui/preferences_dialog.ui: the audio source combo row, whose
  # positions are the schema's choices in schema order, and the AudD API token
  # row, which writes the token when the row is applied.
  class PreferencesDialog
    AUDIO_SOURCE_LABELS = ["Microphone", "Desktop Audio"].freeze

    AUD_D_DESCRIPTION =
      "You can get yourself an API token from " \
      '<a href="https://dashboard.audd.io/">audd.io</a>. ' \
      "Leaving this blank will give you a few trials per day"

    def initialize(settings)
      @settings = settings
    end

    def build
      root.tap do |dialog|
        dialog.add(page)

        page.tap do |p|
          p.add(general_group)
          p.add(aud_d_group)

          general_group.tap do |group|
            group.add(audio_source_type_row)

            audio_source_type_row.tap do |row|
              row.signal_connect("notify::selected") { on_audio_source_type_selected }
            end
          end

          aud_d_group.tap do |group|
            group.add(aud_d_api_token_row)

            aud_d_api_token_row.tap do |row|
              row.signal_connect("apply") { @settings.aud_d_api_token = row.text }
            end
          end
        end
      end
    end

    def present(parent) = root.present(parent)

    # Upstream's `focus_aud_d_api_token_row`, which the recognize error dialog
    # uses to send the user straight at the token.
    def focus_aud_d_api_token_row = aud_d_api_token_row.grab_focus

    def root = @root ||= Adwaita::PreferencesDialog.new
    def page = @page ||= Adwaita::PreferencesPage.new

    def general_group
      @general_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = I18n.gettext("General")
      end
    end

    def audio_source_type_row
      @audio_source_type_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = I18n.gettext("Audio Source")
        row.subtitle = I18n.gettext("Device used for listening")
        row.model = Gtk::StringList.new(AUDIO_SOURCE_LABELS.map { |label| I18n.gettext(label) })
        row.selected = @settings.audio_source_type_position
      end
    end

    def aud_d_group
      @aud_d_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = I18n.gettext("AudD")
        group.description = I18n.gettext(AUD_D_DESCRIPTION)
      end
    end

    def aud_d_api_token_row
      @aud_d_api_token_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = I18n.gettext("API Token")
        row.max_width_chars = 32
        row.input_hints = [:no_spellcheck, :no_emoji, :private]
        row.show_apply_button = true
        row.text = @settings.aud_d_api_token
      end
    end

    private

      def on_audio_source_type_selected
        @settings.audio_source_type = @settings.audio_source_type_at(audio_source_type_row.selected)
      end
  end
end
