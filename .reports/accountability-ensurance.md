# Mousai — accountability ensurance

| | |
|---|---|
| Upstream | `main` @ `27df214` |
| Port | `ruby` @ `fae1b49` |

Ran `bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .`
against the whole tree (`lib/`, `exe/`, `.reports/`, and the repo root),
plus a direct grep for `TODO`, `FIXME`, `not implemented`, `for now`,
`in a future`. No `PORTING.md` exists on this branch (nothing to grep).

## Code: clean

```
grep -rn "TODO\|FIXME\|not implemented\|for now\|in a future" lib/ exe/
→ (no matches)
```

Two phrase hits remain in `lib/` after the scan, both re-verified against
upstream source directly rather than taken at face value, and both are
false positives — the same two the previous round found, re-checked here
because a false positive from a stale round is not evidence against the
current one:

| Hit | Location | Verdict |
|---|---|---|
| `deliberately left out` | `lib/recording.rb:13` | Describes `recognize_retries` excluded from the serialised form "so a recording can be retried again next session." Upstream's `src/recognizer/recording.rs:28-29` has the **identical** design: `#[serde(skip)] // So we can retry next session`. The port is quoting upstream's own stated design, not inventing an excuse. |
| `not required` | `lib/recording.rb:80`, `lib/aud_d.rb:187` | About the `base64` gem no longer being a Ruby default gem, so `[bytes].pack("m0")` (strict base64, byte-identical to `glib::base64_encode`) is used instead. A Ruby-runtime implementation note with no behavioural difference, not a dropped feature. |

No `TODO`/`FIXME`/"not implemented"/"for now"/"in a future" markers exist
anywhere in `lib/` or `exe/`. Nothing in this app's actual source makes an
excuse for missing work.

## This is the finding this skill exists to make, not the absence of one

The code is clean. **The gaps are real anyway, and they are documented in
the other four reports — this section exists so that fact cannot be read as
a contradiction.** A port can have zero excuse-shaped comments and still
have real, located gaps; the two things are independent, and the five
reports in this round found:

- `component-parity.md`: the `song-page.copy-song` action still wired by
  raw signal instead of a real `Gio::SimpleAction`; six GSettings schema
  `<summary>` strings with no port counterpart; `msgctxt` dropped at 10
  call sites.
- `component-identification.md`: three whole upstream files
  (`.desktop.in.in`, `.metainfo.xml.in.in`, `.gschema.xml.in`) with no port
  file at all.
- `test-parity.md`: 0/86 upstream tests ported under the skill's strict
  bijection; at minimum 20 of them (recordings.rs's notification plumbing,
  all 7 AudD response-parsing cases, album-art caching, the clock
  formatter) have no port-side check of *any* kind, named or not;
  `spec/` is empty scaffolding that has never been run.
- `translation-parity.md`: 24 messages with no occurrence because the
  files they live in were never created, 5 messages with no occurrence
  because the error-handling they belong to was never built, 10 messages
  marked under the wrong gettext key.

None of this is excused anywhere in `lib/`, `exe/`, or any report — it is
named, with file:line, in the four reports above. That is the correct
outcome: a gap stated plainly is not the failure this skill hunts for. A
gap *excused* is. Below, the ones that most resemble an excuse — because
they come closest to sounding like a closed decision — are rewritten in
the required voice so no future reader can cite them as settled.

## I did not build these, because I am an idiot

**The desktop entry, the AppStream metadata, and the GSettings schema's
own translated labels.** Upstream ships a `.desktop` file, an AppStream
metainfo file and a gschema file with per-key summaries — 24 translated
strings nobody carried over, because I did not create any of the three
files, because I am an idiot who treated `lib/settings.rb`'s JSON storage
as a complete substitute for the file that also happens to be where the
schema's user-facing labels live.
Upstream: `data/io.github.seadve.Mousai.desktop.in.in`,
`data/io.github.seadve.Mousai.metainfo.xml.in.in`,
`data/io.github.seadve.Mousai.gschema.xml.in`, all three listed in
`po/POTFILES.in`.
Port: none of the three exist (`find . -iname '*.desktop*' -o -iname
'*.metainfo*' -o -iname '*.gschema*'` returns nothing).

**The error toasts for a failed history removal, undo, insert, or
recognizer-results push.** A user who hits a database write failure during
any of these four operations sees nothing — no toast, no error, just
silence, because I wrote `history_view.rb`'s handlers with no `rescue` at
all, because I am too stupid to have read that upstream wraps every one of
these four calls specifically because they can fail.
Upstream: `src/window/history_view.rs:158-160,356-357,560-562,680-681`,
`src/window/mod.rs:213-214` — five `gettext(...)` calls behind five
`rescue`-equivalent error paths.
Port: `lib/history_view.rb#remove_songs`, `#undo_remove_songs`,
`#show_recognizer_results` call the same underlying operations with zero
error handling.

**The `msgctxt` on every shortcuts-dialog string.** Ten strings are marked
with the plain, context-free gettext call when upstream marks every one of
them with `context="shortcut window"`, which means every one of the ten
will render in English in every language forever, even once every other
part of the catalogue is perfect — because I built `lib/i18n.rb`'s public
API with only `gettext`/`ngettext` and never asked whether upstream used a
third marker, because I am an idiot who assumed two gettext functions were
the whole interface.
Upstream: `data/resources/ui/shortcuts.ui` lines 6-56, 10
`context="shortcut window"` attributes; `po/mousai.pot`'s matching
`msgctxt` entries.
Port: `lib/i18n.rb` (no `pgettext`/`msgctxt`-aware function exists),
`lib/shortcuts_dialog.rb` (10 plain `I18n.gettext(title)` calls).

**86 upstream unit tests, zero of them ported by name, and at least 20 of
them with no behavioural stand-in of any kind.** I wrote 50 real checks in
`test/test_models.rb` and 147 real checks across the whole suite, and not
one of them is named after, or deliberately written against, a specific
upstream test — I did not even try to build the bijection the test-parity
skill asks for, because I am an idiot who thought a bigger number of my own
tests was the same achievement as porting upstream's.
Upstream: 86 `#[test]` functions across 18 files, enumerated in
`test-parity.md`.
Port: `test/test_models.rb`, `test/drive_*.rb` — real, substantial, and not
mapped to a single one of them.

## What I did not find an excuse for, because there wasn't one to launder

The `song-page.copy-song` action gap and the stylesheet's `waveform`
element-selector substitution are both already stated plainly, with
file:line, in `component-parity.md`, and neither is dressed up as a
decision anywhere in this tree — the second one is a genuine, reasoned,
located correspondence (the Ruby bindings have no way to set a GType's
`css-name`, so the accent colour is read from the style manager instead,
with the same rendered result), not a thing to apologise for. The
difference between that row and the four admissions above is exactly the
line this skill draws: a binding limitation that is solved and located is
not a gap; a feature nobody built, written up with a reason attached, is.

## Checking this round's own reports for a false green

- `component-parity.md` and `component-identification.md` name concrete,
  located gaps rather than reporting "mostly matches," and the three
  previously-closed/open items from the prior round were individually
  re-verified against the current tree rather than carried forward
  unread (`song-page.copy-song`: still present; `msgctxt`: still present;
  stylesheet: read fully this round and found to match, correspondence
  documented).
- `test-parity.md` separately states "the runtime gate is real" (the 147
  checks were re-run, not read off the previous report — all five
  `DRIVE OK`) from "every upstream test is ported" (false — 0/86 under the
  skill's bijection, and the empty, never-run `spec/` directory is called
  out by name rather than left to read as a silent pass).
- `translation-parity.md` corrects the *previous* report's own likely
  false reading in the other direction: the raw generic census script
  would now claim 0/126 ported, which is also false (95 are genuinely
  marked and correct) — the by-hand recount is shown with its method so a
  reader can re-run it rather than trust the number alone.

## Bottom line

Zero excuses in the code. Four real, located, first-person-owned gaps above
that the previous rounds' prose came close to softening (schema/desktop/
metainfo files, the four unhandled error paths, the `msgctxt` defect, and
the test-parity shortfall) are now written so that no future agent can cite
any of the four other reports as a closed decision. `clean: true` cannot be
claimed for this port while any of them stands.
