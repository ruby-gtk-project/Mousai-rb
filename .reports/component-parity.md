# Mousai — component parity

Per the `component-parity` skill: count, style, behaviour and text, compared
per component against `origin/main`, not as app-wide totals.

## Verified at parity

Spot-checked the highest-traffic components directly against upstream
source (not inferred from the earlier inventory):

| Component | Count | Style (CSS) | Behaviour (signals/actions) | Text (msgid) |
|---|---|---|---|---|
| `HistoryView` menu + selection menu | 5 items each side | n/a (menu, no CSS) | same action targets (`app.show-preferences`, `app.shortcuts`, `app.show-about`, `history-view.select-all`, `history-view.select-none`) | byte-identical, mnemonics included (`_Preferences`, `Select _All`, …) |
| `HistoryView` empty states | 2 `Adw.StatusPage` each side | matches `content_empty_page` / `content_empty_search_result_page` | driven live by `test/drive_main_window.rb` (checks 2, 7, 8) | n/a — titles not diffed this pass, worth a follow-up read |
| `ShortcutsDialog` | 2 sections, 8 items total, matches `shortcuts.ui` 1:1 | n/a | all 8 `action-name`/accelerator targets match, including `win.toggle-recognize` for "Toggle Listen" | byte-identical, `shortcut window` msgctxt preserved only informally (see gap below) |
| `Settings` | 6 of 6 schema keys ported (`window-width/height/maximized`, `audio-source-type`, `aud-d-api-token`, `memory-list`) | n/a | `audio-source-type` choice validation (`ArgumentError` on an out-of-schema value) ported and asserted in `test/test_models.rb` | n/a |
| App + window top-level actions | `app.quit`, `app.show-preferences`, `app.show-about`, `app.shortcuts`, `app.show-inspector-page` (devel), `win.toggle-search`, `win.toggle-playback`, `win.toggle-recognize` — all 8 present on both sides with matching accelerators (`ACCELS` in `lib/mousai/application.rb` matches `set_accels_for_action` calls in `src/application.rs:252-257`) | — | — | — |

## Gaps

### 1. `song-page.copy-song` action not installed (behaviour axis)

- **Upstream**: `src/window/song_page.rs:75` installs
  `klass.install_action("song-page.copy-song", …)`; the copy button in
  `data/resources/ui/song_page.ui:21` is bound to it via
  `action-name="song-page.copy-song"`.
- **Port**: `lib/song_page.rb` has no `song-page.*` action group. The copy
  button (`lib/song_page.rb:166-169`) is wired with
  `button.signal_connect("clicked") { copy_song }` (`lib/song_page.rb:60`).
- **User-visible impact today**: none — the button still copies the song on
  click. But `song_page.rb` is the *only* interactive component in the port
  that doesn't install its action as a real `Gio::SimpleAction`, unlike
  `history_view.rb`, `song_bar.rb` and `song_tile.rb`, which all do. This is
  a real, locatable behaviour-axis gap (the action genuinely does not exist
  as an addressable action, only as a bound signal), not a cosmetic one —
  flag it rather than wave it through because the click still works.

### 2. `msgctxt` is dropped everywhere (text axis)

Upstream marks every shortcut-window and menu string with a `context`
(`msgctxt "shortcut window"` in `.ui` files, which maps to a qualified msgid
in `po/mousai.pot`, e.g. `shortcut window\x04Search`). The port's
`I18n.gettext` (`lib/i18n.rb`) has no `msgctxt`-aware entry point at all —
`shortcuts_dialog.rb` and `history_view.rb` call plain `I18n.gettext(title)`
with no context argument. Two consequences:

- Even once `po/` exists, these keys will not match the real `.pot`'s
  `(msgctxt, msgid)` pairs — `"Search"` under `shortcut window` context is a
  different translation unit from a context-free `"Search"`, and upstream
  actually has both (the `shortcuts.ui` "Search" differs in several
  languages from `history_view.ui`'s unrelated "Search" placeholder text).
- This is a structural translation-parity defect, not merely a missing
  catalogue — it will persist even after `po/` is ported unless `I18n`
  grows a `pgettext`/`C_`-equivalent and every call site that upstream marks
  with a context is updated to use it. Recorded here because it's a
  component-level (text-axis) finding; the message-catalogue accounting
  lives in `translation-parity.md`.

### 3. No stylesheet (style axis) — `data/resources/style.css` not ported

- Upstream ships `data/resources/style.css`, loaded via GResource at
  startup (`src/application.rs`). `lib/style.rb` exists and is required by
  `lib/mousai/application.rb`, but it needs to be checked line-for-line
  against `style.css`'s actual rules rather than assumed equivalent, since
  CSS-class *names* used throughout `lib/*.rb` (e.g. any `add_css_class`
  calls) are only half the story — the class has to be *defined* with the
  same rule on the port side too.
- This pass read `lib/style.rb`'s existence and its requiring, but did not
  diff its CSS rules byte-for-byte against `data/resources/style.css`. That
  diff is unfinished work, not a confirmed gap — recorded here so it isn't
  silently treated as parity by omission.

## What this pass did not re-verify

Given the scope of a single audit pass, the per-file widget/CSS/signal
tables for the remaining ~50 components (every dialog, tile, row and page)
were not re-built from scratch; the previous survey
(`.reports/component-inventory.md`) did that work file-by-file at an older
commit and nothing in this pass found its per-file widget tables to be
wrong, only stale on two items (Toggle Listen, InspectorPage) that are now
fixed. Treat that inventory's component map as still broadly accurate for
widget types/counts, but not for current-state gap claims — this document
and `test-parity.md`/`translation-parity.md` are the current source of
truth for what's missing.
