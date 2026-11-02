# frozen_string_literal: true

module Mousai
  # Translation helpers.
  #
  # Ported from upstream's src/i18n.rs (itself copied from Fractal), which
  # wraps `gettext`/`ngettext` with named-variable replacement.
  #
  # The port has no message catalogues of its own — `po/` is not ported — so
  # `gettext` returns the msgid and `ngettext` picks singular or plural by
  # count, which is exactly what gettext does for an untranslated locale. The
  # `{name}` replacement, which is the part the rest of the port depends on, is
  # ported in full.
  module I18n
    module_function

    def gettext(msgid) = msgid

    def ngettext(msgid, msgid_plural, count)
      if count == 1
        msgid
      else
        msgid_plural
      end
    end

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
