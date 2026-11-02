# frozen_string_literal: true

require "adwaita"

module Mousai
  # A row showing one piece of information about a song.
  #
  # Ported from upstream's src/window/information_row.rs and
  # data/resources/ui/information_row.ui: an AdwActionRow carrying a dimmed,
  # selectable value label as its suffix. Upstream hides the row while its
  # value is blank — the property is documented as doing exactly that — so this
  # does too.
  class InformationRow
    attr_reader :value

    def initialize(title:)
      @title = title
      @value = ""
    end

    def build
      root.tap do |row|
        row.add_suffix(value_label)
      end.tap { update_ui }
    end

    def value=(new_value)
      new_value.to_s.then do |value|
        unless value == @value
          @value = value
          update_ui
        end
      end
    end

    def root
      @root ||= Adwaita::ActionRow.new.tap do |row|
        row.title = @title
      end
    end

    def value_label
      @value_label ||= Gtk::Label.new.tap do |label|
        label.xalign = 1
        label.ellipsize = :end
        label.selectable = true
        label.add_css_class("dim-label")
      end
    end

    private

      def update_ui
        root.visible = !@value.strip.empty?
        value_label.text = @value
      end
  end
end
