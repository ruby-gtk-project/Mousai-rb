# frozen_string_literal: true

require "adwaita"
require_relative "i18n"

module Mousai
  # The keyboard shortcuts dialog.
  #
  # Ported from upstream's data/resources/ui/shortcuts.ui: two sections,
  # General and Controls, whose items either name an accelerator directly or
  # name an action and let libadwaita look its accelerator up.
  #
  module ShortcutsDialog
    GENERAL_ITEMS = [
      # Translators: shortcut window
      { title: "Open Main Menu", accelerator: "F10" },
      # Translators: shortcut window
      { title: "Search", action_name: "win.toggle-search" },
      # Translators: shortcut window
      { title: "Show Preferences", action_name: "app.show-preferences" },
      # Translators: shortcut window
      { title: "Show Shortcuts", action_name: "app.shortcuts" },
      # Translators: shortcut window
      { title: "Close Window", action_name: "window.close" },
      # Translators: shortcut window
      { title: "Quit", action_name: "app.quit" },
    ].freeze

    CONTROLS_ITEMS = [
      # Translators: shortcut window
      { title: "Toggle Listen", action_name: "win.toggle-recognize" },
      # Translators: shortcut window
      { title: "Toggle Playback", action_name: "win.toggle-playback" },
    ].freeze

    module_function

    def present(parent)
      dialog.present(parent)
    end

    def dialog
      Adwaita::ShortcutsDialog.new.tap do |shortcuts|
        shortcuts.add(general_section)
        shortcuts.add(controls_section)
      end
    end

    def general_section
      # Translators: shortcut window
      Adwaita::ShortcutsSection.new(I18n.gettext("General")).tap do |section|
        GENERAL_ITEMS.each { |item| section.add(shortcuts_item(item)) }
      end
    end

    def controls_section
      # Translators: shortcut window
      Adwaita::ShortcutsSection.new(I18n.gettext("Controls")).tap do |section|
        CONTROLS_ITEMS.each { |item| section.add(shortcuts_item(item)) }
      end
    end

    # `AdwShortcutsItem` takes its title and either an accelerator or an action
    # name positionally in the Ruby bindings; there is no no-argument form.
    def shortcuts_item(item)
      Adwaita::ShortcutsItem.new(
        I18n.gettext(item[:title]),
        item[:accelerator] || item[:action_name],
      )
    end
  end
end
