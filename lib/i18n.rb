# frozen_string_literal: true

require "gettext"

module Mousai
  # Translation helpers.
  #
  # Ported from upstream's src/i18n.rs (itself copied from Fractal), which
  # wraps `gettext`/`ngettext` with named-variable replacement.
  #
  # The port reuses upstream's `po/` catalogue byte for byte — same domain
  # ("mousai", from upstream's `meson.project_name()`), same msgids — via the
  # pure-Ruby `gettext` gem (see po/POTFILES.in and TRANSLATION_PARITY.md).
  # `rake gettext:mo:update` compiles `po/*.po` into
  # `locale/<lang>/LC_MESSAGES/mousai.mo`, which `bindtextdomain` below binds
  # against at runtime.
  module I18n
    DOMAIN = "mousai"
    LOCALE_DIR = File.expand_path("../locale", __dir__)

    extend GetText
    bindtextdomain(DOMAIN, path: LOCALE_DIR)

    module_function

    def gettext(msgid) = _(msgid)

    def ngettext(msgid, msgid_plural, count) = n_(msgid, msgid_plural, count)

    # `msgctxt`-aware lookup, for strings whose English text repeats across
    # unrelated contexts (upstream's GtkBuilder `context="..."` attribute,
    # e.g. the shortcuts window's `context="shortcut window"`).
    def pgettext(msgctxt, msgid) = p_(msgctxt, msgid)

    # Like `gettext`, but replaces `{name}` with the value given for `name`.
    def gettext_f(msgid, args)
      freplace(gettext(msgid), args)
    end

    # Like `ngettext`, but replaces `{name}` with the value given for `name`.
    def ngettext_f(msgid, msgid_plural, count, args)
      freplace(ngettext(msgid, msgid_plural, count), args)
    end

    # Replaces the `{name}` variables in `string` using the given hash.
    #
    # Upstream debug-asserts that at least one pair is given and that every
    # variable was replaced; a warning is the release-build behaviour, and a
    # warning is what this does.
    def freplace(string, args)
      args.reduce(string) { |result, (key, value)| result.gsub("{#{key}}", value.to_s) }.tap do |result|
        if result.include?("{")
          warn("all format variables must be replaced, but some were not: #{result}")
        end
      end
    end
  end
end
