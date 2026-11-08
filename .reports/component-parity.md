# Mousai — component parity

| | |
|---|---|
| Upstream | `main` @ `27df214` |
| Port | `ruby` @ `fae1b49` |

Per the `component-parity` skill: count, style, behaviour and text, compared
per component, not as app-wide totals. This supersedes the previous
`component-parity.md`, written before the translation catalogue landed
(`fae1b49`); two of that report's three gaps are now stale (closed or
superseded) and are re-verified below rather than carried over unread.

## Re-verified against the current tree

| Component | Count | Style | Behaviour | Text | Verdict |
|---|---|---|---|---|---|
| `HistoryView` primary + selection menus | 5 items each side | — (menu, no CSS) | action targets match (`app.show-preferences`, `app.shortcuts`, `app.show-about`, `history-view.select-all`, `history-view.select-none`) | byte-identical incl. mnemonics | parity |
| `ShortcutsDialog` | 2 sections / 8 items, matches `shortcuts.ui` 1:1 | — (menu, no CSS) | all 8 `action-name`/accelerator targets match | marked but **wrong key**, see Gap 1 | **gap** (text axis) |
| `Settings` | 6/6 schema keys ported | — (not a widget) | choice validation ported, asserted in `test/test_models.rb` | the 6 per-key `<summary>` strings have no port counterpart at all | **gap** (text axis, see `component-identification.md` #38) |
| App + window actions | `app.quit`, `app.show-preferences`, `app.show-about`, `app.shortcuts`, `app.show-inspector-page` (devel), `win.toggle-search`, `win.toggle-playback`, `win.toggle-recognize` — 8/8, accelerators match `lib/mousai/application.rb`'s `ACCELS` against `src/application.rs:252-257` | — | — | — | parity |
| `Waveform` css-name | — (not a count) | `waveform { color: var(--accent-color) }` in upstream's stylesheet is unreachable in the port (no GType to hang a css-name on); `lib/waveform.rb` reads the accent colour from the style manager directly instead, same rendered colour, documented at `lib/waveform.rb:18-21` | — | — | **correspondence, not a gap** — located and reasoned |
| `AboutDialog` | all fields present | — | all 3 links wired | byte-identical strings; GStreamer/Libsoup version lines in `debug_info` dropped and replaced with a Ruby-version line, **disclosed** at `lib/about_dialog.rb:11-13` | parity (disclosed substitution, not silent) |

## Gaps

### 1. `msgctxt` is dropped at every call site that upstream marks with one (text axis)

- **Upstream**: every title in `data/resources/ui/shortcuts.ui` carries
  `context="shortcut window"` (`git show origin/main:data/resources/ui/shortcuts.ui`,
  lines 6, 9, 15, 21, 27, 33, 39, 47, 50, 56 — 10 strings), which becomes a
  `msgctxt "shortcut window"` entry in `po/mousai.pot`, a distinct catalogue
  key from the same English text used context-free elsewhere.
- **Port**: `lib/i18n.rb`'s `I18n` module exposes `gettext`/`ngettext` only;
  there is no `pgettext`/`msgctxt`-aware entry point anywhere in it. Every
  caller in `lib/shortcuts_dialog.rb` (`I18n.gettext("General")`,
  `I18n.gettext("Open Main Menu")`, …, 10 call sites) and in
  `lib/history_view.rb`'s menu building calls the plain, context-free
  `_()`.
- **Why this is a real gap and not a cosmetic one**: `po/de.po` and every
  other locale carry the translation keyed on `(msgctxt="shortcut window",
  msgid="Search")`. A plain `_("Search")` call looks up the
  context-*free* entry, which is a different gettext key. For the 10
  shortcut-window strings this either finds no entry (falls back to
  English) or — worse, if the context-free "Search" entry happens to exist
  for some other string reusing the same English text — silently returns
  the *wrong* translation. This is verified structurally (reading
  `lib/i18n.rb` and the two call sites), not merely inferred from the
  `.pot`.
- **What closing it requires**: `I18n` needs a `pgettext`-equivalent (the
  `gettext` gem exposes `p_(msgctxt, msgid)` for this), and
  `shortcuts_dialog.rb`/`history_view.rb` need their 10 affected call sites
  switched to it. Tracked again, with the full count, in
  `translation-parity.md`.

### 2. The six GSettings schema `<summary>` strings have no port counterpart

- **Upstream**: `data/io.github.seadve.Mousai.gschema.xml.in` gives each of
  its six keys a `<summary>` (`Window width`, `Window height`, `Whether the
  window is maximized`, `Audio source type to use in recording audio`,
  `API token used by AudD recognition`, `Legacy (Kept for migration)`) —
  translated strings shown in schema-browsing tools.
- **Port**: `lib/settings.rb` replaces the storage mechanism with a JSON
  file under `XDG_CONFIG_HOME` — a documented, reasoned correspondence for
  *storage* — but no file in the port carries these six summary strings in
  any form; there is no schema file, ported or synthetic.
- This is small (6 strings) but is a second distinct gap hiding behind what
  the previous survey counted as "6 of 6 schema keys ported" — the *keys*
  (and their defaults/choices) are ported; these six *labels* are not.

### 3. `song-page.copy-song` action not installed as a real action (behaviour axis)

- **Upstream**: `src/window/song_page.rs:75` installs
  `klass.install_action("song-page.copy-song", …)`; the copy button in
  `data/resources/ui/song_page.ui:21` is bound via
  `action-name="song-page.copy-song"`.
- **Port**: `lib/song_page.rb` has no `song-page.*` action group anywhere.
  The copy button (`lib/song_page.rb:60,166-169`) is wired with a plain
  `button.signal_connect("clicked") { copy_song }`.
- Still present, unchanged from the previous pass's finding. The button
  still copies on click, but the action does not exist as an addressable
  `Gio::SimpleAction` the way `history_view.rb`'s, `song_bar.rb`'s and
  `song_tile.rb`'s equivalents do — this is the one interactive component in
  the port that is wired by raw signal instead of by action, and it is a
  real behaviour-axis asymmetry (nothing can target
  `win.song-page.copy-song` from a shortcut or a test the way it can target
  every sibling component's action).

### 4. Two whole units have no port file at all (see `component-identification.md`)

`data/io.github.seadve.Mousai.desktop.in.in` and
`data/io.github.seadve.Mousai.metainfo.xml.in.in` are absent from the port
tree entirely — not a four-axis comparison because there is no port-side
component to compare against. Recorded here because their absence is also
where ~20 of the translation-parity gaps in `translation-parity.md` live;
closing those two files is a precondition for several rows in that ledger
ever reaching `ported`.

## What this pass did not re-verify from scratch

The per-file widget/CSS/signal tables for the remaining ~30 components
(every tile, row, page not named above) were not rebuilt from the scan this
round; `component-identification.md`'s file-to-file mapping is current and
every file on it exists and is `require_relative`-reachable from
`lib/mousai.rb`, which was checked. Treat this document and
`component-identification.md` together as the current source of truth;
older per-widget tables under earlier `.reports/` history are superseded.
