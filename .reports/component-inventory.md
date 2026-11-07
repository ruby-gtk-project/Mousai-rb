# Mousai — upstream component inventory

Survey of `origin/main` (Rust / gtk-rs / libadwaita) against `lib/` on `ruby`.
No app code was written in this step.

Read with `git show origin/main:<path>`; upstream's full tree is listed with
`git ls-tree -r --name-only origin/main`. This is the fourth survey of this
fork, taken after the recognizer/recorder/device pass (`f2f6dca`,
`7557e29`), which is itself after the gem-wiring pass that this report's
previous revision flagged as a blocker.

## Totals — how much app is left

`lib/` now holds 54 files (51 at top level plus `lib/mousai/application.rb`,
`lib/mousai/rb/version.rb`), up from 44 at the previous survey. The entire
recognition pipeline the last survey called "what remains" — `Recognizer`,
`Recorder`, `Device`, `RecognizerView`, `RecognizerStatus`, `RecognizedPage`,
`RecognizedPageTile` — is now present and wired to real GStreamer/libsoup
bindings, not hand-rolled.

| | upstream | `ruby` branch |
|---|---:|---:|
| source files contributing a component (excl. `.ui`) | 64 | 54 |
| `.ui` templates / standalone objects | 17 + 1 (shortcuts) | 0 (house style builds in code) |
| GAction names (app + win) | 16 | 10 installed (`toggle-recognize` now among them) |
| translated messages (`po/mousai.pot`) | 132 | 0 (no `po/` yet — `lib/i18n.rb` is a passthrough) |
| locales (`po/LINGUAS`) | 48 | 0 |

What is left, in the order a user would meet it:

- The keyboard-shortcuts dialog is missing the "Toggle Listen" row — see the
  finding below; this is a one-line gap now that the action exists.
- `InspectorPage` (`src/inspector_page.rs` + `ui/inspector_page.ui`), the
  devel-build diagnostics page — no `lib/inspector_page.rb`. Lower priority:
  it only appears in `Devel` builds.
- `po/` — no message catalogue or locale files exist on `ruby` at all. This
  is `translation-parity`'s job, not this survey's, but it is the largest
  single gap left on the board (132 msgids, 48 locales, zero ported).
- Everything else in the "Component map" below that upstream has and the
  port either doesn't, or has only partially — see the "partial" rows.

### Finding — a stale "no binding" excuse left in the code after the gem was wired

`lib/shortcuts_dialog.rb:13-17` still reads:

> Upstream's Controls section also lists Toggle Listen, which points at
> `win.toggle-recognize`; the port installs no such action, because the
> recognizer needs an audio recorder and so GStreamer, which has no binding
> in the port's dependencies. A shortcut row for an action nothing answers
> would be a promise the app cannot keep, so that one row is left out.

Both halves of that justification are now false:

- `win.toggle-recognize` **is** installed — `lib/window.rb:225`,
  `Gio::SimpleAction.new("toggle-recognize")`.
- GStreamer **does** have a binding in the port's dependencies —
  `gstreamer_play` and `gstreamer` are in `mousai-rb.gemspec` and
  `nix/Gemfile`, and `lib/recorder.rb`/`lib/device.rb` use `Gst::` classes
  directly.

The comment was accurate when it was written and was never revisited once
the blocker it names was removed. The "Toggle Listen" `AdwShortcutsItem` row
(upstream `data/resources/ui/shortcuts.ui`, `Controls` section) is still
absent from `CONTROLS_ITEMS` in `lib/shortcuts_dialog.rb`, so the shortcuts
dialog under-reports the app's own keyboard shortcuts. This is not fixed
here — this step is survey-only — but it is a real gap, not a settled
decision, and the comment claiming otherwise should be corrected when that
file is next touched.

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
| 24 | `data/resources/ui/shortcuts.ui` | `lib/shortcuts_dialog.rb` | shortcuts | yes (partial — missing the "Toggle Listen" row; see finding above) |
| 25 | `src/about.rs` | `lib/about_dialog.rb` | about | yes |
| 26 | `src/application.rs` (`present_database_error_dialog`) | `lib/database_error_dialog.rb` | error dialog | yes |
| 27 | `src/window/mod.rs` (`present_recognize_error`) | `lib/recognize_error_dialog.rb` | error dialog | yes |
| 28 | `src/window/mod.rs` (`present_recording_saved_message`) | `lib/recording_saved_dialog.rb` | error dialog | yes |
| 29 | `src/inspector_page.rs` + `ui/inspector_page.ui` | `lib/inspector_page.rb` | devel page | **no** |
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
| 59 | `src/serde_helpers.rs` | — (no port needed) | n/a | n/a — Rust `serde` plumbing, not a component |
| 60 | `po/mousai.pot`, `po/*.po` (48) | `po/` | translations | no |

### Per-component detail — what's still missing

#### 29. `src/inspector_page.rs` + `ui/inspector_page.ui` → `lib/inspector_page.rb` — devel-build diagnostics

Only relevant in devel builds (`Devel` app id). Lets a developer force a
`ProviderType`/`TestProviderMode` without a real recognition. No gem
blocker — this is just not written yet.

#### 24. `data/resources/ui/shortcuts.ui` → `lib/shortcuts_dialog.rb` — the missing "Toggle Listen" row

See the finding above. `CONTROLS_ITEMS` in `lib/shortcuts_dialog.rb` has one
entry (`Toggle Playback`); upstream's `Controls` section has two (`Toggle
Listen` first, then `Toggle Playback`). Adding the row is now unblocked —
`win.toggle-recognize` exists — but the comment that explains the gap still
describes a blocker that is gone.

## Translations

`po/mousai.pot` (132 messages) and `po/LINGUAS` (48 locales) have no
counterpart on `ruby` — no `po/` directory exists in this branch, and
`lib/i18n.rb` is a passthrough that returns `msgid` unchanged. Not blocking
any remaining UI component, but the largest standing parity gap on this
board. The `translation-parity` skill in `.claude/skills/` covers this when
it's time; not performed here since this step is survey-only.
