# Mousai — translation parity

| | |
|---|---|
| Upstream | `main` @ `27df214` |
| Port | `ruby` @ `fae1b49` |
| Domain | `mousai` (matches: `lib/i18n.rb:19`, `po/*.po` headers) |
| Upstream messages (`po/mousai.pot`) | 132 |
| Upstream languages | 48 `.po` files, `LINGUAS` matches |
| Languages shipped by the port | 48/48 — `.po`/`LINGUAS` copied verbatim and verified identical file-for-file |
| Marked in the port, byte-identical to upstream's English | **95 of 126 non-catalogue-file messages confirmed** (see methodology) |
| Confirmed gaps | **≥ 29** distinct messages with **no** port occurrence, **+ 10** marked under the **wrong gettext key** (msgctxt dropped) |

This supersedes the previous `translation-parity.md`, written before
`fae1b49` (which ported `po/` and wired real gettext). The previous report's
headline — "0 of 132, total gap" — is now **false**: the catalogue exists,
is wired, and was verified live under a non-English locale (below). But the
story is not "parity achieved" either; read on.

## Methodology note — the generic scanner's boundary regex misses this port's call style, and the census was done by hand per the skill's rule

`scripts/msgid-census.sh`'s marker regex requires the character immediately
before a marker (`gettext`, `_`, `n_`, …) to **not** be `.`:

```
(^|[^A-Za-z0-9_.])(g_)?(_|N_|NC_|C_|n_|Nn_|np_|p_|s_|ngettext|gettext|...)\(
```

That boundary exists to stop `foo.gettext(` on some unrelated receiver from
false-matching. This port's entire call convention is exactly that shape —
`I18n.gettext("...")`, `I18n.ngettext(...)` — so the generic census matches
**zero** port call sites and the raw script output claims 0/126 ported,
which is not true and would be the "false green in reverse" this skill
warns about if reported uncorrected.

Per the skill's **"When the scanner is the thing that is wrong"** section,
this is repo-specific (one project's choice of wrapper method name), so it
was censused by hand rather than patched into the shared script: every
string literal in every `lib/**/*.rb` file was extracted with Ruby's own
parser (`Ripper.sexp`, concatenating `string_concat` nodes so that the
`"a " \` `"b"`-style literals this codebase uses for long strings come back
as one value), and each of upstream's 126 non-`po/` msgids was checked for
an exact match. This is the number in the header above. **The generated
YAML this skill normally produces was not written**, because the generic
scanner's output for this repo is wrong in a way regenerating it would not
fix; report the discrepancy upstream to the skill rather than letting the
two documents quietly disagree.

## What is genuinely marked and correct (95 messages)

This is substantial, real work: 95 of upstream's 126 code/`.ui`-sourced
messages have a byte-identical Ruby call site, including several that only
matched after resolving one level of indirection by hand (hash/array
constants passed to `I18n.gettext(variable)` rather than a literal — e.g.
`lib/external_link_tile.rb`'s `"Apple Music"`/`"Browse on Apple Music"` pairs,
`lib/about_dialog.rb`'s `LINKS` hash, `lib/preferences_dialog.rb`'s
`AUDIO_SOURCE_LABELS`, and the two long bodies in
`lib/recording_saved_dialog.rb` and `lib/database_error_dialog.rb`, all of
which are present and correct once the concatenated literal is read in full).

## Gap 1 — 24 messages live in three files the port never created

`data/io.github.seadve.Mousai.desktop.in.in`,
`data/io.github.seadve.Mousai.gschema.xml.in` and
`data/io.github.seadve.Mousai.metainfo.xml.in.in` are all in upstream's
`po/POTFILES.in` and all absent from the port tree (`find . -iname
'*.desktop*' -o -iname '*.metainfo*' -o -iname '*.gschema*'` returns
nothing — see `component-identification.md` #36-38). Their strings:

| File | Messages | Examples |
|---|---|---|
| `*.desktop.in.in` | 3 (1 shared with metainfo) | `Comment=Identify songs in seconds` (shared), `Keywords=Shazam;Audio;Music;Song;Recognize;Identify;Recognition;` |
| `*.gschema.xml.in` | 6 | `Window width`, `Window height`, `Whether the window is maximized`, `Audio source type to use in recording audio`, `API token used by AudD recognition`, `Legacy (Kept for migration)` |
| `*.metainfo.xml.in.in` | 16 (1 shared with desktop: the summary/`Identify songs in seconds`) | `<name>Mousai</name>`, 4 `<p>` paragraphs, 6 `<li>` feature bullets (the 🎵🎙️🎸🎼🌐📱 lines), 4 `<caption>` screenshot captions including `Recognized songs` (lower-case, distinct from the already-ported page title `Recognized Songs`) |

Net distinct messages after dedup: **24**. None of these can reach `ported`
until the three files exist in the port, whatever form they take (even a
stub `.desktop`/`.gschema.xml`/`.metainfo.xml` the port installs). This is
simultaneously a component-identification gap and a translation gap — fix
the one file and both close together.

## Gap 2 — 5 error-toast messages the port never shows, because the error handling they belong to was never built

```
Failed to insert song to history
Failed to remove selected songs
Failed to remove song
Failed to show recognizer results
Failed to undo
```

Upstream shows each of these via `add_message_toast` from a `rescue`-style
error path in `src/window/mod.rs`/`src/window/history_view.rs` (e.g.
`history_view.rs:680-681`: `undo_remove_songs`'s database write is wrapped,
and on failure shows `gettext("Failed to undo")`). The port's
`lib/history_view.rb#undo_remove_songs`, `#remove_songs` and
`#show_recognizer_results` call the same underlying operations with **no**
`rescue` and **no** toast call anywhere (`grep -n "rescue" lib/history_view.rb`
returns nothing). These five messages are not a marking oversight — the
behaviour they belong to does not exist, so there is no call site to mark.
Fixing the text gap means building the error handling first; recorded here
*and* as a behaviour gap, because a reader of either ledger needs to see it.

## Gap 3 — 10 `msgctxt`-qualified messages are marked, but under the wrong key

All 10 entries in `data/resources/ui/shortcuts.ui` carry
`context="shortcut window"` (verified: `grep -c 'context="'` on that file in
upstream = 10, all "shortcut window", no other context string exists
anywhere in the app). `lib/i18n.rb`'s `I18n` module has no
`pgettext`/`msgctxt`-aware entry point, and `lib/shortcuts_dialog.rb` calls
plain `I18n.gettext(title)` for every one of them. This means:

- The English literal is present (counted in the 95 above, since byte-text
  matching does not distinguish context) — so a naive "is the string there"
  check reads these as `ported`.
- But the (msgctxt, msgid) **key** gettext actually looks up does not match
  `po/mousai.pot`'s entry for any of the 10 — a plain `_("Search")` call
  looks up the context-free key, not `(shortcut window, Search)`, so **in
  every translated locale these 10 strings render in English regardless of
  how complete that language's catalogue is.** This is the same structural
  finding the previous report made and it survives unchanged into this
  commit; `po/` landing did not fix it because `lib/i18n.rb` was not
  touched by that commit.
- Listed separately from Gap 1/2 because these are not "missing" in the
  naive text-presence sense — they are present and silently wrong, which is
  the harder failure mode to catch and the one most likely to be
  mis-reported as a pass.

## Verified live, under a real locale

```
nix develop --command xvfb-run -a ruby test/drive_i18n.rb
  ok   compiled a non-trivial German .mo
  ok   English fallback when untranslated
  ok   'Home' is translated through the German catalogue
  ok   'Cancel' is translated through the German catalogue
  ok   {name} interpolation still runs on the translated string
5 of 5 checks passed, DRIVE OK
```

This is real: `rmsgfmt` compiles `po/de.po` (with its genuine fuzzy-entry and
obsolete-entry warnings printed, both correctly excluded from the compiled
`.mo`), `bindtextdomain` resolves it, and a known German string renders
translated in the running app. **This is the strongest evidence in this
report** — report it as what it is: proof that the *mechanism* works for
the 95 messages that are correctly wired, not proof that the catalogue is
complete.

## Languages

```
diff <(git ls-tree -r --name-only origin/main -- po/ | grep '\.po$' | xargs -n1 basename | sort) \
     <(ls po/*.po | xargs -n1 basename | sort)
→ no difference, 48/48
diff <(ls po/*.po | xargs -n1 basename -s .po | sort) <(sort po/LINGUAS)
→ no difference
```

48 of 48 upstream `.po` files are present, byte-identical in filename set,
and `LINGUAS` matches the directory. This axis is fully closed.

## Bottom line

- The catalogue mechanism (gettext, `.mo` compilation, `bindtextdomain`,
  German verified live) is real and working — not true of the previous
  commit, and this round's claim that it landed is correct.
- 95 of 126 non-catalogue-file messages are correctly marked, byte-identical.
- **At least 24 messages have no port occurrence at all** (three whole
  files never created), **5 more have no occurrence because the behaviour
  they belong to was never built**, and **10 more are marked but will never
  resolve to upstream's translated text because the context is dropped.**
  That is 39 of 132 upstream messages (30%) not actually delivering a
  translation to the user, hiding under a catalogue that is otherwise
  genuinely wired and working for the rest.
- `clean: true` cannot be claimed on this axis while any of the three gaps
  above stands.
