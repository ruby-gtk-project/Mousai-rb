# Mousai — upstream component inventory

Survey of `origin/main` (Rust / gtk-rs / libadwaita) against `lib/` on `ruby`.
No app code was written in this step.

Read with `git show origin/main:<path>`; the upstream tree was exported to a
scratchpad and scanned with
`.claude/skills/component-identification/scripts/component-scan.sh`, using
the symbol table at `.claude/skills/component-identification/scripts/symbols.tsv`.

## Totals — how much app is left

Third survey, after the player/song-bar/recognition-provider pass
(`11971e1`). `lib/` now holds 44 files (up from 28 at the previous survey).

| | upstream | `ruby` branch |
|---|---:|---:|
| widget rows (source + `.ui`) | 405 | 113 |
| distinct widget types | 64 | 45 |
| distinct CSS classes | 43 | 19 |
| distinct signals connected | 61 | 34 |
| GAction names | 16 | 10 (installed: `toggle-playback` now wired; `toggle-recognize` still not) |
| `.ui` templates / standalone objects | 17 + 1 | 0 (house style builds in code) |
| translated messages (`po/mousai.pot`) | 132 | 0 (no `po/` yet) |
| locales (`po/LINGUAS`) | 48 | 0 |

The history half of the app, the playback model (`Player`), the `SongBar`
transport widget and the recognition *provider* stack (AudD client + mock +
error-tester + settings) are now ported. **What remains is the live
recognition pipeline and its UI**: capturing audio and turning it into a
recognition result on screen.

Still absent, in the order a user would meet them:

- `win.toggle-recognize` — not installed; the "Listen" button in the header
  bar (`history_view.rb:197`, `button.action_name = "win.toggle-recognize"`)
  points at an action that does not exist, so the button is dead.
- `RecognizerView` (`lib/recognizer_view.rb`) — the stack page shown while
  listening, built from `Waveform` (ported, `lib/waveform.rb`) and
  `RecognizerStatus` (not ported).
- `RecognizerStatus` (`lib/recognizer_status.rb`) — progress label/spinner
  built from `ProgressIcon` (ported, `lib/progress_icon.rb`).
- `RecognizedPage` / `RecognizedPageTile` (`lib/recognized_page.rb`,
  `lib/recognized_page_tile.rb`) — the results list shown after a successful
  recognition; `style.rb` already carries `recognizedpagetile` CSS rules
  (lines 95–107) with nothing yet to apply them to.
- `Recognizer` (the orchestrator in `src/recognizer/mod.rs`) — no
  `lib/recognizer.rb`. This is the class `RecognizerView`,
  `RecognizerStatus` and the header-bar action all drive.
- `Recorder` (`src/recognizer/recorder.rs`) — no `lib/recorder.rb`. Builds the
  GStreamer capture pipeline (`gst::Pipeline` into a `MemoryOutputStream`)
  that produces the bytes `Recording`/`Recordings` (already ported) store.
- `Device` (`src/device.rs`) — no `lib/device.rb`. A free function,
  `find_default(class)`, used by `Recorder` to pick the default
  Audio/Source or Audio/Sink device via `gst::DeviceProviderFactory`.
- `InspectorPage` (`src/inspector_page.rs` + `ui/inspector_page.ui`) — the
  devel-build diagnostics page for forcing provider/test modes; no
  `lib/inspector_page.rb`.
- `serde_helpers.rs` — not a component (Rust `serde` plumbing for
  `OnceCell`/etc.); nothing to port, Ruby's `JSON`/`Marshal` need no
  equivalent. Noted so it isn't mistaken for a missed file.

### Gem-wiring blocker found while surveying — flag, do not fix in this step

Several of the above ported files carry comments admitting they hand-rolled
around a missing binding, e.g.:

- `lib/window.rb:28` — "...and so the audio recorder; GStreamer has no
  binding in the port's dependencies..."
- `lib/mousai.rb:8` — "...recognizer and recognizer view, which need an audio
  recorder and so GStreamer, which has no binding..."
- `lib/shortcuts_dialog.rb:14` — "...the recognizer needs an audio recorder
  and so GStreamer, which has no binding..."

This port's gemspec (`mousai-rb.gemspec`) declares **no runtime
dependencies at all** (only dev dependencies), and `nix/Gemfile` lists only
`gem "adwaita"` and `gem "gtk4"`. `gstreamer_play` (`GstPlay`) and `soup3`
(`Soup`) — both mandatory per the fork's instructions — are present in
neither. `flake.nix`'s `gtkStack`/`gstStack` cover GTK4's own
`GtkMediaFile` playback backend but declare no typelib path entry keyed to
either gem's own README requirements. This is almost certainly *why*
`Recorder`/`Recognizer` were skipped: without the gem, there is no Ruby
binding to drive a GStreamer capture pipeline, so the port stopped at the
provider layer instead. Wiring in `gstreamer_play` and `soup3` (gemspec,
`nix/Gemfile`, regenerated lock, `flake.nix` typelib path) is a prerequisite
for `Recorder` and `Device`, and should happen before that component is
written, per the fork's standing instructions — not performed here since
this step is survey-only.

## Component map

One upstream widget class is a source file plus (usually) a `.ui` template;
the port merges both into one `lib/*.rb`. Ordered as a user meets them.

| # | Upstream file(s) | → port file | Kind | In `lib/`? |
|---|---|---|---|---|
| 1 | `src/main.rs`, `src/application.rs` | `lib/mousai/application.rb` | application | yes (partial — no `toggle-recognize` accel target, no `InspectorPage` registration) |
| 2 | `src/window/mod.rs` + `ui/window.ui` | `lib/window.rb` | window | yes (partial — `SongBar` revealer and `toggle-playback` now wired; no `RecognizerView` stack page, no `win.toggle-recognize`) |
| 3 | `src/window/history_view.rs` + `ui/history_view.ui` | `lib/history_view.rb` | view | yes |
| 4 | `ui/history_view.ui` (`menu id="menu"`) | part of `lib/history_view.rb` | menu | yes |
| 5 | `ui/history_view.ui` (`menu id="selection_menu"`) | part of `lib/history_view.rb` | menu | yes |
| 6 | `ui/history_view.ui` (`content_empty_page`) | part of `lib/history_view.rb` | empty state | yes |
| 7 | `ui/history_view.ui` (`content_empty_search_result_page`) | part of `lib/history_view.rb` | empty state | yes |
| 8 | `src/window/history_view.rs` (`show_undo_remove_song_toast`) | part of `lib/history_view.rb` | toast | yes |
| 9 | `src/window/song_tile.rs` + `ui/song_tile.ui` | `lib/song_tile.rb` | tile | yes (partial — `PlaybackButton` overlay wiring should be re-checked against #11, now ported) |
| 10 | `src/window/album_cover.rs` + `ui/album_cover.ui` | `lib/album_cover.rb` | widget | yes (partial — no `AlbumArtStore` behind it; `lib/album_art.rb` exists as the model, store wiring unverified) |
| 11 | `src/window/playback_button.rs` + `ui/playback_button.ui` | `lib/playback_button.rb` | widget | **yes (new since last survey)** |
| 12 | `src/window/song_page.rs` + `ui/song_page.ui` | `lib/song_page.rb` | page | yes |
| 13 | `src/window/information_row.rs` + `ui/information_row.ui` | `lib/information_row.rb` | row | yes |
| 14 | `src/window/external_link_tile.rs` + `ui/external_link_tile.ui` | `lib/external_link_tile.rb` | tile | yes |
| 15 | `src/window/lyrics_page.rs` + `ui/lyrics_page.ui` | `lib/lyrics_page.rb` | page | yes |
| 16 | `src/window/song_bar.rs` + `ui/song_bar.ui` | `lib/song_bar.rb` | bar | **yes (new since last survey)** |
| 17 | `src/window/recognizer_view.rs` + `ui/recognizer_view.ui` | `lib/recognizer_view.rb` | view | no |
| 18 | `src/window/waveform.rs` | `lib/waveform.rb` | custom-drawn widget | **yes (new since last survey)** |
| 19 | `src/window/recognizer_status.rs` + `ui/recognizer_status.ui` | `lib/recognizer_status.rb` | status widget | no |
| 20 | `src/window/progress_icon.rs` | `lib/progress_icon.rb` | custom-drawn widget | **yes (new since last survey)** |
| 21 | `src/window/recognized_page.rs` + `ui/recognized_page.ui` | `lib/recognized_page.rb` | page | no |
| 22 | `src/window/recognized_page_tile.rs` + `ui/recognized_page_tile.ui` | `lib/recognized_page_tile.rb` | tile | no |
| 23 | `src/preferences_dialog.rs` + `ui/preferences_dialog.ui` | `lib/preferences_dialog.rb` | preferences | yes |
| 24 | `data/resources/ui/shortcuts.ui` | `lib/shortcuts_dialog.rb` | shortcuts | yes |
| 25 | `src/about.rs` | `lib/about_dialog.rb` | about | yes |
| 26 | `src/application.rs` (`present_database_error_dialog`) | `lib/database_error_dialog.rb` | error dialog | yes |
| 27 | `src/window/mod.rs` (`present_recognize_error`) | `lib/recognize_error_dialog.rb` | error dialog | yes |
| 28 | `src/window/mod.rs` (`present_recording_saved_message`) | `lib/recording_saved_dialog.rb` | error dialog | yes |
| 29 | `src/inspector_page.rs` + `ui/inspector_page.ui` | `lib/inspector_page.rb` | devel page | no |
| 30 | `data/resources/style.css` | `lib/style.rb` (inline `Gtk::CssProvider`) | stylesheet | yes (partial — has `recognizedpagetile`/waveform rules already, pending those widgets) |
| 31 | `data/io.github.seadve.Mousai.gschema.xml.in` | `lib/settings.rb` | GSettings | yes |
| 32 | `src/recognizer/mod.rs` | `lib/recognizer.rb` | model/orchestrator | no |
| 33 | `src/recognizer/recorder.rs` | `lib/recorder.rb` | model (GStreamer capture) | no — blocked on `gstreamer_play` (see gem-wiring note above) |
| 34 | `src/recognizer/recording.rs` | `lib/recording.rb` | model | yes |
| 35 | `src/recognizer/recordings.rs` | `lib/recordings.rb` | model (collection) | yes |
| 36 | `src/recognizer/provider/mod.rs` | `lib/provider.rb` | model (trait/interface) | yes |
| 37 | `src/recognizer/provider/error.rs` | `lib/recognize_error.rb` | model (error) | yes |
| 38 | `src/recognizer/provider/error_tester.rs` | `lib/error_tester_provider.rb` | model (test provider) | yes |
| 39 | `src/recognizer/provider/settings.rs` | `lib/provider_settings.rb` | model | yes |
| 40 | `src/recognizer/provider/aud_d/mod.rs` | `lib/aud_d.rb` | model (HTTP provider) | yes — but see gem-wiring note: should sit on `soup3`'s `Soup`, not a hand-rolled HTTP client; unverified in this survey, check at component-parity time |
| 41 | `src/recognizer/provider/aud_d/mock.rs` | `lib/mock_provider.rb` | model (test provider) | yes |
| 42 | `src/recognizer/provider/aud_d/response.rs` | `lib/aud_d_response.rb` | model (deserialization) | yes |
| 43 | `src/device.rs` | `lib/device.rb` | model (free functions) | no — blocked on `gstreamer_play` |
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
| 56 | `src/i18n.rs` | `lib/i18n.rb` | model (gettext wrapper) | yes |
| 57 | `src/cancelled.rs` | `lib/cancelled.rb` | model (error type) | yes |
| 58 | `src/settings.rs` | `lib/settings.rb` | model (GSettings wrapper) | yes (shared with #31) |
| 59 | `src/serde_helpers.rs` | — (no port needed) | n/a | n/a — Rust `serde` plumbing, not a component |
| 60 | `po/mousai.pot`, `po/*.po` (48) | `po/` | translations | no |

### Per-component detail — the components still missing

#### 17. `src/window/recognizer_view.rs` + `ui/recognizer_view.ui` → `lib/recognizer_view.rb` — the "Listening…" stack page

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | — | — | marked `// Unused` by upstream itself |
| `Waveform` (own) | 1 | — | — | already ported, see #18 |
| `RecognizerStatus` (own) | 1 | — | — | see #19 |

Driven by `Recognizer`'s `state` property (`RecognizerState`), not yet ported
(#32).

#### 19. `src/window/recognizer_status.rs` + `ui/recognizer_status.ui` → `lib/recognizer_status.rb` — progress + message under the waveform

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `ProgressIcon` (own) | 1 | — | — | already ported, see #20 |
| `Gtk.Label` | 1+ | `dim-label`? | — | status message, uses `gettext_f` for interpolated strings |

Upstream TODOs on this file (still open there): drop the separate
show-result button; show "n queued" offline message; richer progress errors.
Carry those TODOs forward rather than silently resolving them.

#### 21–22. `recognized_page.rs`/`recognized_page_tile.rs` → `lib/recognized_page.rb`/`lib/recognized_page_tile.rb` — the results list

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` | 1 | — | — | `recognized_page.rs` |
| `RecognizedPageTile` (own, subclasses `SongTile`) | N (repeater over results) | `recognizedpagetile` (already in `lib/style.rb:95-107`) | — | wraps `SongTile` (#9, ported) with per-result activate/add affordance |

`ngettext_f` is used for the page's singular/plural header count — check
`lib/i18n.rb` already supports this (it backs #38's error messages too).

#### 29. `src/inspector_page.rs` + `ui/inspector_page.ui` → `lib/inspector_page.rb` — devel-build diagnostics

Only relevant in devel builds (`Devel` app id). Lets a developer force a
`ProviderType`/`TestProviderMode` without a real recognition. Lower priority
than the recognition pipeline itself, but still a named component.

#### 32. `src/recognizer/mod.rs` → `lib/recognizer.rb` — the orchestrator

Owns `Recorder`, drives the active `Provider`, exposes `state`
(`RecognizerState`) and a `song`/error result that `RecognizerStatus`,
`RecognizerView`, `RecognizedPage` and `win.toggle-recognize` all consume.
This is the one class every remaining widget component depends on — it
should be ported before or alongside #17/#19/#21/#22, not after.

#### 33. `src/recognizer/recorder.rs` → `lib/recorder.rb` — audio capture

Builds a `gst::Pipeline` writing into a `gio::MemoryOutputStream`, using
`Device::find_default` (#43) to pick the input. **Blocked on wiring
`gstreamer_play` into the gemspec/`nix/Gemfile`/`flake.nix`** per the
gem-wiring note above — do that first.

#### 43. `src/device.rs` → `lib/device.rb` — default device lookup

Two free functions (`DeviceClass` enum, `find_default`) wrapping
`gst::DeviceProviderFactory::by_name("pulsedeviceprovider")`. Same
`gstreamer_play` dependency as #33.

## Translations

`po/mousai.pot` (132 messages) and `po/LINGUAS` (48 locales) have no
counterpart on `ruby` yet — no `po/` directory exists in this branch. Not
blocking the recognition components above, but a real parity gap once the
UI text is in place; the `translation-parity` skill in `.claude/skills/`
covers this when it's time.
