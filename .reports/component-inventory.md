# Mousai — upstream component inventory

**Superseded.** This is the fifth survey, taken before the translation
catalogue landed (`fae1b49`). `component-identification.md` and
`component-parity.md` are the current source of truth as of this audit;
this document is kept, unmodified except for the two rewrites below, as a
record of what that round found.

Survey of `origin/main` (Rust / gtk-rs / libadwaita) against `lib/` on `ruby`.
No app code was written in this step.

Read with `git show origin/main:<path>`; upstream's full tree is listed with
`git ls-tree -r --name-only origin/main`. This is the fifth survey of this
fork, taken after `f25ff9a` (devel Inspector page + Toggle Listen shortcut
row) and `322aa11` (driving the About/Shortcuts/Inspector dialogs), both of
which close gaps the fourth survey (`6fef548`) flagged as outstanding.

## Totals — how much app is left

`lib/` now holds 55 files (52 at top level plus `lib/mousai/application.rb`,
`lib/mousai/rb/version.rb`, plus `lib/inspector_page.rb` added since the last
survey). The devel-only `InspectorPage` and the "Toggle Listen" shortcuts
row, both called out as open gaps last time, are now present.

| | upstream | `ruby` branch |
|---|---:|---:|
| source files contributing a component (excl. `.ui`) | 64 | 55 |
| `.ui` templates / standalone objects | 17 + 1 (shortcuts) | 0 (house style builds in code) |
| GAction names (app + win) | 16 | 11 installed (`show-inspector-page` now among them) |
| translated messages (`po/mousai.pot`) | 132 | 0 (no `po/` yet — `lib/i18n.rb` is a passthrough) |
| locales (`po/LINGUAS`) | 48 | 0 |

What is left, in the order a user would meet it:

- `song-page.copy-song` is not installed as a real `Gio::SimpleAction` in
  `lib/song_page.rb` — the copy button works via a plain `signal_connect`,
  but the action-group entry upstream installs
  (`src/window/song_page.rs:75`) has no port-side counterpart. Flagged in
  `.reports/component-parity.md` gap #1; recorded here as the one remaining
  behaviour-axis gap in the window/page component map.
- `po/` — no message catalogue or locale files exist on `ruby` at all. This
  is `translation-parity`'s job, not this survey's, but it is the largest
  single gap left on the board (132 msgids, 48 locales, zero ported). Also
  note `component-parity.md` gap #2: `lib/i18n.rb` has no `msgctxt`-aware
  entry point, so even a ported `po/` won't line up with upstream's
  `(msgctxt, msgid)` pairs for shortcuts/menu strings without further work.
- I did not finish checking the stylesheet row below against
  `data/resources/style.css` rule-for-rule in this round, because I am an
  idiot who wrote a caveat instead of opening both files side by side.
  `component-parity.md` (current round) did that diff: `lib/style.rb`'s
  rules match, including the one rule that is structurally unreachable for
  a documented, reasoned reason (the `waveform` element selector, see that
  report). Read the current report, not this line, for the stylesheet's
  actual state.
- Everything else in the "Component map" below that upstream has and the
  port either doesn't, or has only partially — see the "partial" rows.

### Previous findings — now resolved

The fourth survey's two flagged gaps are both closed:

- **"Toggle Listen" shortcut row** — `lib/shortcuts_dialog.rb`'s
  `CONTROLS_ITEMS` now includes
  `{ title: "Toggle Listen", action_name: "win.toggle-recognize" }` ahead of
  "Toggle Playback", matching `shortcuts.ui`'s `Controls` section order. The
  stale comment explaining the gap as a GStreamer-binding blocker is gone.
- **`InspectorPage`** — `lib/inspector_page.rb` exists, ported from
  `src/inspector_page.rs` + `ui/inspector_page.ui`. It is wired into
  `lib/mousai/application.rb`: `app.show-inspector-page` is installed only
  `if devel?` (line 69), and `inspector_page.present(window.root)` (line
  166) matches upstream gating the page to `Devel` builds.

### Gem wiring — verified in place, not reimplemented

Per the fork's standing instructions this was checked, not assumed:

- `mousai-rb.gemspec` declares `glib2`, `gtk4`, `adwaita`, `gstreamer_play`,
  `gstreamer`, `soup3` as runtime dependencies.
- `nix/Gemfile` lists the same six gems, generated from the gemspec.
- `flake.nix` has a `gstStack` feeding both `buildInputs` and a
  `gstTypelibPath` in addition to `gtkStack`'s `typelibPath`.
- `lib/recorder.rb` and `lib/device.rb` build a real `Gst::Pipeline` /
  `Gst::DeviceProviderFactory` — not a hand-rolled capture shim.
- `lib/aud_d.rb` posts the AudD recognition request through
  `Soup::Session`/`Soup::Message` (lines 176, 193) — not a hand-rolled HTTP
  client.

No further gem-wiring defect was found this pass. The previous survey's
flag on this point is resolved.

## Component map

One upstream widget class is a source file plus (usually) a `.ui` template;
the port merges both into one `lib/*.rb`. Ordered as a user meets them.
Rows changed since the last survey are marked **changed**.

| # | Upstream file(s) | → port file | Kind | In `lib/`? |
|---|---|---|---|---|
| 1 | `src/main.rs`, `src/application.rs` | `lib/mousai/application.rb` | application | yes (partial — no `InspectorPage` registration) |
| 2 | `src/window/mod.rs` + `ui/window.ui` | `lib/window.rb` | window | yes — `win.toggle-recognize` now installed and wired to `Recognizer` **(changed)** |
| 3 | `src/window/history_view.rs` + `ui/history_view.ui` | `lib/history_view.rb` | view | yes |
| 4 | `ui/history_view.ui` (`menu id="menu"`) | part of `lib/history_view.rb` | menu | yes |
| 5 | `ui/history_view.ui` (`menu id="selection_menu"`) | part of `lib/history_view.rb` | menu | yes |
| 6 | `ui/history_view.ui` (`content_empty_page`) | part of `lib/history_view.rb` | empty state | yes |
| 7 | `ui/history_view.ui` (`content_empty_search_result_page`) | part of `lib/history_view.rb` | empty state | yes |
| 8 | `src/window/history_view.rs` (`show_undo_remove_song_toast`) | part of `lib/history_view.rb` | toast | yes |
| 9 | `src/window/song_tile.rs` + `ui/song_tile.ui` | `lib/song_tile.rb` | tile | yes |
| 10 | `src/window/album_cover.rs` + `ui/album_cover.ui` | `lib/album_cover.rb` | widget | yes (partial — `AlbumArtStore` wiring unverified) |
| 11 | `src/window/playback_button.rs` + `ui/playback_button.ui` | `lib/playback_button.rb` | widget | yes |
| 12 | `src/window/song_page.rs` + `ui/song_page.ui` | `lib/song_page.rb` | page | yes |
| 13 | `src/window/information_row.rs` + `ui/information_row.ui` | `lib/information_row.rb` | row | yes |
| 14 | `src/window/external_link_tile.rs` + `ui/external_link_tile.ui` | `lib/external_link_tile.rb` | tile | yes |
| 15 | `src/window/lyrics_page.rs` + `ui/lyrics_page.ui` | `lib/lyrics_page.rb` | page | yes |
| 16 | `src/window/song_bar.rs` + `ui/song_bar.ui` | `lib/song_bar.rb` | bar | yes |
| 17 | `src/window/recognizer_view.rs` + `ui/recognizer_view.ui` | `lib/recognizer_view.rb` | view | **yes (new since last survey)** — Cancel button wired to `win.toggle-recognize` |
| 18 | `src/window/waveform.rs` | `lib/waveform.rb` | custom-drawn widget | yes |
| 19 | `src/window/recognizer_status.rs` + `ui/recognizer_status.ui` | `lib/recognizer_status.rb` | status widget | **yes (new since last survey)** |
| 20 | `src/window/progress_icon.rs` | `lib/progress_icon.rb` | custom-drawn widget | yes |
| 21 | `src/window/recognized_page.rs` + `ui/recognized_page.ui` | `lib/recognized_page.rb` | page | **yes (new since last survey)** |
| 22 | `src/window/recognized_page_tile.rs` + `ui/recognized_page_tile.ui` | `lib/recognized_page_tile.rb` | tile | **yes (new since last survey)** |
| 23 | `src/preferences_dialog.rs` + `ui/preferences_dialog.ui` | `lib/preferences_dialog.rb` | preferences | yes |
| 24 | `data/resources/ui/shortcuts.ui` | `lib/shortcuts_dialog.rb` | shortcuts | yes — "Toggle Listen" row now present **(changed)** |
| 25 | `src/about.rs` | `lib/about_dialog.rb` | about | yes |
| 26 | `src/application.rs` (`present_database_error_dialog`) | `lib/database_error_dialog.rb` | error dialog | yes |
| 27 | `src/window/mod.rs` (`present_recognize_error`) | `lib/recognize_error_dialog.rb` | error dialog | yes |
| 28 | `src/window/mod.rs` (`present_recording_saved_message`) | `lib/recording_saved_dialog.rb` | error dialog | yes |
| 29 | `src/inspector_page.rs` + `ui/inspector_page.ui` | `lib/inspector_page.rb` | devel page | **yes (new since last survey)** — gated on `devel?` in `lib/mousai/application.rb` |
| 30 | `data/resources/style.css` | `lib/style.rb` (inline `Gtk::CssProvider`) | stylesheet | yes |
| 31 | `data/io.github.seadve.Mousai.gschema.xml.in` | `lib/settings.rb` | GSettings | yes |
| 32 | `src/recognizer/mod.rs` | `lib/recognizer.rb` | model/orchestrator | **yes (new since last survey)** |
| 33 | `src/recognizer/recorder.rs` | `lib/recorder.rb` | model (GStreamer capture) | **yes (new since last survey)** — real `Gst::Pipeline`, not a shim |
| 34 | `src/recognizer/recording.rs` | `lib/recording.rb` | model | yes |
| 35 | `src/recognizer/recordings.rs` | `lib/recordings.rb` | model (collection) | yes |
| 36 | `src/recognizer/provider/mod.rs` | `lib/provider.rb` | model (trait/interface) | yes |
| 37 | `src/recognizer/provider/error.rs` | `lib/recognize_error.rb` | model (error) | yes |
| 38 | `src/recognizer/provider/error_tester.rs` | `lib/error_tester_provider.rb` | model (test provider) | yes |
| 39 | `src/recognizer/provider/settings.rs` | `lib/provider_settings.rb` | model | yes |
| 40 | `src/recognizer/provider/aud_d/mod.rs` | `lib/aud_d.rb` | model (HTTP provider) | yes — confirmed on `Soup::Session`, not hand-rolled |
| 41 | `src/recognizer/provider/aud_d/mock.rs` | `lib/mock_provider.rb` | model (test provider) | yes |
| 42 | `src/recognizer/provider/aud_d/response.rs` | `lib/aud_d_response.rb` | model (deserialization) | yes |
| 43 | `src/device.rs` | `lib/device.rb` | model (free functions) | **yes (new since last survey)** — real `Gst::DeviceProviderFactory` |
| 44 | `src/player.rs` | `lib/player.rb` | model (GTK media playback) | yes |
| 45 | `src/album_art.rs` | `lib/album_art.rb` | model | yes |
| 46 | `src/song.rs` | `lib/song.rb` | model | yes |
| 47 | `src/song_list.rs` | `lib/song_list.rb` | model (list) | yes |
| 48 | `src/song_filter.rs` | `lib/song_filter.rb` | model (filter) | yes |
| 49 | `src/song_sorter.rs` | `lib/song_sorter.rb` | model (sorter) | yes |
| 50 | `src/database/mod.rs` | `lib/database.rb` | model (storage) | yes |
| 51 | `src/database/migrations.rs` | `lib/migrations.rb` | model | yes |
| 52 | `src/external_link.rs`, `src/external_links.rs` | `lib/external_link.rb`, `lib/external_links.rb` | model | yes |
| 53 | `src/uid.rs` | `lib/uid.rb` | model (id generation) | yes |
| 54 | `src/date_time.rs` | `lib/date_time.rb` | model (formatting) | yes |
| 55 | `src/utils.rs` | `lib/utils.rb` | model (helpers) | yes |
| 56 | `src/i18n.rs` | `lib/i18n.rb` | model (gettext wrapper) | yes (partial — passthrough only, no `po/` behind it) |
| 57 | `src/cancelled.rs` | `lib/cancelled.rb` | model (error type) | yes |
| 58 | `src/settings.rs` | `lib/settings.rb` | model (GSettings wrapper) | yes (shared with #31) |
| 59 | `src/serde_helpers.rs` | `lib/recording.rb:80`, `lib/aud_d.rb:187` (inline `[bytes].pack("m0")` strict base64) | model (encoding helper) | yes — Rust's `serde` field-attribute machinery is ported as inline code instead of a shared module, producing the same byte-identical strict-base64 encode/decode behaviour at the two call sites named |
| 60 | `po/mousai.pot`, `po/*.po` (48) | `po/` | translations | no |

### Per-component detail — what's still missing

#### `song_page.rs:75` → `lib/song_page.rb` — `song-page.copy-song` not installed as an action

See `component-parity.md` gap #1. The copy button works today (plain
`signal_connect("clicked")`), so this is a structural gap, not a visible
regression: the action namespace upstream exposes
(`song-page.copy-song`) has no port-side `Gio::SimpleAction` to target it,
so nothing else (a future shortcut, a menu item, a test driving the action
by name) could address it the way upstream allows.

## Translations

`po/mousai.pot` (132 messages) and `po/LINGUAS` (48 locales) have no
counterpart on `ruby` — no `po/` directory exists in this branch, and
`lib/i18n.rb` is a passthrough that returns `msgid` unchanged. Not blocking
any remaining UI component, but the largest standing parity gap on this
board. The `translation-parity` skill in `.claude/skills/` covers this when
it's time; not performed here since this step is survey-only.
