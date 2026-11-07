# Mousai — translation parity

## Verdict: total gap. 0 of 132 msgids, 0 of 48 locales.

Verified directly, not inferred from an earlier survey:

```
git show origin/main:po/mousai.pot | grep -c '^msgid '   → 132
git show origin/main:po/LINGUAS | tr ' ' '\n' | grep -v '^$' | wc -l → 48
find . -iname po -o -iname '*.pot' -o -iname '*.po'       → (nothing on `ruby`)
```

There is no `po/` directory, no `.pot`, no `.po`, no `.mo`, and no build step
that could produce one, anywhere on the `ruby` branch.

## Why "113 `I18n.gettext`/`I18n.ngettext` call sites" is not progress on this axis

`grep -rc "I18n.gettext\|I18n.ngettext" lib/` finds 113 call sites — the
strings *are* marked, extensively and (spot-checked above, in
`component-parity.md`) with byte-identical English to upstream's `.ui`
files. But `lib/i18n.rb` implements:

```ruby
def gettext(msgid) = msgid
def ngettext(msgid, msgid_plural, count) = count == 1 ? msgid : msgid_plural
```

This is a deliberate, disclosed no-op — `lib/i18n.rb`'s own comment says so
plainly ("The port has no message catalogues of its own — `po/` is not
ported"). It is the single honest admission the accountability pass found
(see `accountability-ensurance.md`), not a hidden gap. But concretely: no
matter how many call sites say `I18n.gettext("Listen")`, nothing in the port
loads a catalogue, so every non-English locale that upstream ships — all 48
— renders in English. Marking strings produces a port with 113 (well, up to
132, once every file is counted) messages and zero translations, which is
exactly the failure mode the `translation-parity` skill names: "a port that
looks complete in English."

## A second, structural defect that will survive even after `po/` is ported

Upstream marks several strings with a `msgctxt` — most visibly
`shortcut window` on every `AdwShortcutsItem` title in `shortcuts.ui`, which
in `po/mousai.pot` becomes a qualified key (`msgctxt "shortcut window"` /
`msgid "Search"`, distinct from a context-free `"Search"` elsewhere in the
app). `lib/i18n.rb`'s `I18n` module has no `pgettext`/`C_`-equivalent
function at all, and `lib/shortcuts_dialog.rb` and `lib/history_view.rb` both
call plain `I18n.gettext(title)` with no context argument.

This means that even on the day `po/` is correctly copied over and
`I18n.gettext` is wired to real `GLib.gettext` / `FastGettext`, these call
sites will still not produce the same `(msgctxt, msgid)` key upstream's
`.pot` has — they'll collide with or miss the context-qualified entries, and
every one of the translations contributed for the *contextual* string will
fail to apply. Fixing the catalogue without fixing this is not enough; both
have to move together. This is recorded as its own finding because it is
invisible if you only diff msgid strings and forget `msgctxt` exists.

## What full parity would require (unchanged scope, restated for the record)

1. Copy `po/mousai.pot`, `po/LINGUAS`, and all 48 `po/*.po` files to the
   port unchanged.
2. Wire `lib/i18n.rb` to a real gettext binding (`GLib.gettext` /
   `FastGettext`, bound to the app's text domain) instead of the passthrough,
   including a context-aware entry point for the `msgctxt`-marked strings.
3. Verify, msgid by msgid, that every one of the 132 keys in `po/mousai.pot`
   has a surviving, byte-identical call site in `lib/` — this pass did not
   do the full 132-key census (out of scope for the time available), only
   confirmed the totals and spot-checked the highest-traffic menu/shortcut
   strings in `component-parity.md`, all of which matched.
4. Ship a build/install step that compiles `.po` → `.mo` and installs it
   where the gettext binding will find it. Nothing in `mousai-rb.gemspec`,
   `Rakefile` or `nix/` currently does this.

None of this exists yet. `clean: true` cannot be claimed for this project
while this report describes anything other than "ported."
