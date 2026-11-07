# frozen_string_literal: true

# Drives lib/i18n.rb's binding to the actual po/ catalogue (see
# TRANSLATION_PARITY.md). Unlike the other drive scripts this needs no
# display: it proves the gettext gem compiles a real .mo from po/de.po and
# that Mousai::I18n looks a translated string up through it, rather than
# merely returning the msgid unmodified for every locale.
#
# The gettext gem resolves and caches the active locale the first time a
# bound domain is looked up, so this has to run as a fresh process with
# LANGUAGE already set — re-setting ENV["LANGUAGE"] after lib/i18n.rb has
# loaded (and `require`d once per process) does not retranslate anything.
# This script is itself that fresh process, re-executed under `LANGUAGE=de`
# below if it was not already.

require "fileutils"
require "tmpdir"

if ENV["LANGUAGE"] != "de"
  ENV["LANGUAGE"] = "de"
  exec(RbConfig.ruby, __FILE__)
end

require_relative "../lib/i18n"

checks = 0
failures = []

def check(checks, failures, name)
  result = yield
  checks[0] += 1
  unless result
    failures << name
  end
  puts("    #{result ? "ok  " : "FAIL"} #{name}")
end

counters = [0]

# Compile po/de.po into a scratch locale tree with rmsgfmt, independent of
# any locale/ a previous `rake gettext:mo:update` may have left on disk —
# this script is the thing that proves the compile step itself works.
require "gettext/tools/msgfmt"

root = File.expand_path("..", __dir__)
Dir.mktmpdir("mousai-i18n-drive") do |scratch|
  mo_dir = File.join(scratch, "de/LC_MESSAGES")
  FileUtils.mkdir_p(mo_dir)
  GetText::Tools::MsgFmt.run(File.join(root, "po/de.po"), "-o", File.join(mo_dir, "mousai.mo"))

  check(counters, failures, "compiled a non-trivial German .mo") do
    File.size(File.join(mo_dir, "mousai.mo")) > 1024
  end

  # Rebind to the scratch tree so this check does not depend on whether
  # `rake gettext:mo:update` happened to have already populated locale/.
  Mousai::I18n.bindtextdomain(Mousai::I18n::DOMAIN, path: scratch)

  check(counters, failures, "English fallback when untranslated") do
    Mousai::I18n.gettext("this msgid is not in any catalogue") == "this msgid is not in any catalogue"
  end

  check(counters, failures, "'Home' is translated through the German catalogue") do
    Mousai::I18n.gettext("Home") == "Startseite"
  end

  check(counters, failures, "'Cancel' is translated through the German catalogue") do
    Mousai::I18n.gettext("Cancel") == "Abbrechen"
  end

  check(counters, failures, "{name} interpolation still runs on the translated string") do
    # "Listening for {name}" is not an upstream msgid; this only tests that
    # gettext_f's freplace step still runs after a real catalogue lookup.
    Mousai::I18n.gettext_f("Listening for {name}", {"name" => "Mousai"}) == "Listening for Mousai"
  end
end

puts
puts("#{counters[0] - failures.size} of #{counters[0]} checks passed")
if failures.empty?
  puts("DRIVE OK")
else
  puts("DRIVE FAILED: #{failures.join(", ")}")
  exit(1)
end
