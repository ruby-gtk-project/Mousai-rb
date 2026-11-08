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
    # The upstream `.ui` marks every title here with
    # `context="shortcut window"`; `I18n.pgettext` is the msgctxt-aware
    # lookup that resolves against that same context (see po/mousai.pot).
    CONTEXT = "shortcut window"

    GENERAL_ITEMS = [
      { title: "Open Main Menu", accelerator: "F10" },
      { title: "Search", action_name: "win.toggle-search" },
      { title: "Show Preferences", action_name: "app.show-preferences" },
      { title: "Show Shortcuts", action_name: "app.shortcuts" },
      { title: "Close Window", action_name: "window.close" },
      { title: "Quit", action_name: "app.quit" },
    ].freeze

    CONTROLS_ITEMS = [
      { title: "Toggle Listen", action_name: "win.toggle-recognize" },
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
      Adwaita::ShortcutsSection.new(I18n.pgettext(CONTEXT, "General")).tap do |section|
        GENERAL_ITEMS.each { |item| section.add(shortcuts_item(item)) }
      end
    end

    def controls_section
      Adwaita::ShortcutsSection.new(I18n.pgettext(CONTEXT, "Controls")).tap do |section|
        CONTROLS_ITEMS.each { |item| section.add(shortcuts_item(item)) }
      end
    end

    # `AdwShortcutsItem` takes its title and either an accelerator or an action
    # name positionally in the Ruby bindings; there is no no-argument form.
    def shortcuts_item(item)
      Adwaita::ShortcutsItem.new(
        I18n.pgettext(CONTEXT, item[:title]),
        item[:accelerator] || item[:action_name],
      )
    end
  end
end
