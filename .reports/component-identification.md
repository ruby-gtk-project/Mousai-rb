# Mousai — component identification

| | |
|---|---|
| Upstream | `main` @ `27df214` |
| Port | `ruby` @ `fae1b49` |
| Scope | whole app (small enough for a full pass) |

This supersedes the previous `component-identification.md`/`component-inventory.md`
pair, which predates the translation-catalogue commit (`fae1b49`). Re-run
against the current tree rather than trusting the stale survey.

## Unit list (upstream, by source file)

| # | Upstream file(s) | Port file | Kind |
|---|---|---|---|
| 1 | `src/main.rs`, `src/application.rs` | `exe/mousai`, `lib/mousai.rb`, `lib/mousai/application.rb` | app class, actions, accelerators |
| 2 | `src/window/mod.rs` + no separate `.ui` (built in code) | `lib/window.rb` | main window |
| 3 | `data/resources/ui/history_view.ui` + `src/window/history_view.rs` | `lib/history_view.rb` | history page, menus, empty states |
| 4 | `data/resources/ui/song_tile.ui` + `src/window/song_tile.rs` | `lib/song_tile.rb` | grid tile |
| 5 | `data/resources/ui/song_page.ui` + `src/window/song_page.rs` | `lib/song_page.rb` | song detail page |
| 6 | `data/resources/ui/lyrics_page.ui` + `src/window/lyrics_page.rs` | `lib/lyrics_page.rb` | lyrics page |
| 7 | `data/resources/ui/song_bar.ui` + `src/window/song_bar.rs` | `lib/song_bar.rb` | mini-player bar |
| 8 | `src/window/playback_button.rs` (no `.ui`) | `lib/playback_button.rb` | play/pause button |
| 9 | `src/window/progress_icon.rs` | `lib/progress_icon.rb` | recognition progress icon |
| 10 | `src/window/waveform.rs` | `lib/waveform.rb` | listening waveform |
| 11 | `data/resources/ui/recognizer_view.ui` + `src/window/recognizer_view.rs` | `lib/recognizer_view.rb` | listen/stop view |
| 12 | `data/resources/ui/recognizer_status.ui` + `src/window/recognizer_status.rs` | `lib/recognizer_status.rb` | status cluster |
| 13 | `data/resources/ui/recognized_page.ui` + `src/window/recognized_page.rs` | `lib/recognized_page.rb` | recognized-songs page |
| 14 | `data/resources/ui/recognized_page_tile.ui` + `src/window/recognized_page_tile.rs` | `lib/recognized_page_tile.rb` | tile on that page |
| 15 | `data/resources/ui/album_cover.ui` + `src/window/album_cover.rs` | `lib/album_cover.rb` | album art widget |
| 16 | `src/album_art.rs` | `lib/album_art.rb` | download + cache model |
| 17 | `data/resources/ui/external_link_tile.ui` + `src/window/external_link_tile.rs` | `lib/external_link_tile.rb` | provider link tile |
| 18 | `src/external_link.rs`, `src/external_links.rs` | `lib/external_link.rb`, `lib/external_links.rb` | link model, ordered map |
| 19 | `data/resources/ui/information_row.ui` + `src/window/information_row.rs` | `lib/information_row.rb` | key/value row |
| 20 | `data/resources/ui/preferences_dialog.ui` + `src/preferences_dialog.rs` | `lib/preferences_dialog.rb` | preferences dialog |
| 21 | `src/about.rs` (no `.ui`) | `lib/about_dialog.rb` | about dialog |
| 22 | `data/resources/ui/shortcuts.ui` (no backing `.rs`) | `lib/shortcuts_dialog.rb` | shortcuts dialog |
| 23 | `src/inspector_page.rs` (no `.ui`) | `lib/inspector_page.rb` | devel inspector |
| 24 | recording-saved / recognize-error / database-error dialogs built inline in `src/window/mod.rs` | `lib/recording_saved_dialog.rb`, `lib/recognize_error_dialog.rb`, `lib/database_error_dialog.rb` | three alert dialogs |
| 25 | `src/recognizer/mod.rs` | `lib/recognizer.rb` | recognizer state machine |
| 26 | `src/recognizer/provider/mod.rs`, `error.rs`, `error_tester.rs`, `settings.rs` | `lib/provider.rb`, `lib/recognize_error.rb`, `lib/error_tester_provider.rb`, `lib/provider_settings.rb` | provider abstraction |
| 27 | `src/recognizer/provider/aud_d/{mod,mock,response}.rs` | `lib/aud_d.rb`, `lib/mock_provider.rb`, `lib/aud_d_response.rs` → `lib/aud_d_response.rb` | AudD HTTP provider + mock |
| 28 | `src/recognizer/recorder.rs` | `lib/recorder.rb` | audio recorder |
| 29 | `src/recognizer/recording.rs`, `recordings.rs` | `lib/recording.rb`, `lib/recordings.rb` | recording model, saved-recordings list |
| 30 | `src/song.rs`, `song_list.rs`, `song_filter.rs`, `song_sorter.rs` | `lib/song.rb`, `lib/song_list.rb`, `lib/song_filter.rb`, `lib/song_sorter.rb` | song model + history list |
| 31 | `src/database/{mod,migrations}.rs` | `lib/database.rb`, `lib/migrations.rb` | sqlite-backed persistence |
| 32 | `src/settings.rs` + `data/io.github.seadve.Mousai.gschema.xml.in` | `lib/settings.rb` | app settings |
| 33 | `src/date_time.rs`, `uid.rs`, `utils.rs`, `cancelled.rs`, `i18n.rs`, `serde_helpers.rs` | `lib/date_time.rb`, `lib/uid.rb`, `lib/utils.rb`, `lib/cancelled.rb`, `lib/i18n.rb` | value helpers |
| 34 | `src/player.rs` | `lib/player.rb` | gstreamer playback wrapper |
| 35 | `src/device.rs` | `lib/device.rb` | PulseAudio default-source watcher |
| 36 | `data/io.github.seadve.Mousai.desktop.in.in` | **none** | desktop launcher entry |
| 37 | `data/io.github.seadve.Mousai.metainfo.xml.in.in` | **none** | AppStream metadata (summary, description, screenshots, release notes) |
| 38 | `data/io.github.seadve.Mousai.gschema.xml.in` | **none** (superseded by JSON settings, see #32) | GSettings schema file itself, with its per-key `<summary>`/`<description>` |
| 39 | `po/mousai.pot`, `po/*.po` (48), `po/LINGUAS`, `po/POTFILES.in` | `po/*` (ported, see `translation-parity.md`) | translation catalogue |
| 40 | `data/resources/style.css` | `lib/style.rb` | stylesheet |
| 41 | `data/resources/resources.gresource.xml`, `data/resources/icons/*` | icons present under `data/icons/`, loaded as plain files instead of a compiled GResource bundle — same icon assets, different packaging mechanism, located and reasoned at #40's stylesheet entry's sibling | icon assets |

## Gaps at the identification level (whole units with no port file at all)

- **#36 — `data/io.github.seadve.Mousai.desktop.in.in`.** No `.desktop` file,
  `.desktop.in` or `.desktop.in.in` exists anywhere in the port tree
  (`find . -iname '*.desktop*'` returns nothing). This is the file a desktop
  shell uses to list, launch and search for the app — `Name`, `Comment`, the
  `Keywords` list and the `Exec` line all live here, and the `Comment` and
  `Keywords` are translated strings upstream ships in all 48 languages.
- **#37 — `data/io.github.seadve.Mousai.metainfo.xml.in.in`.** No AppStream
  metainfo file exists. This is the file software centers read for the
  description paragraphs, the feature bullet list, the screenshot captions
  and the release-notes history — ~18 translatable strings, several of them
  multi-sentence (see `translation-parity.md` for the full count).
- **#38 — the gschema file itself.** `lib/settings.rb` correctly replaces
  *GSettings the storage mechanism* with a JSON file (documented, reasoned,
  a correspondence — see `component-parity.md`). But the **schema file**
  is also the place upstream attaches a human-readable `<summary>` to each
  of the 6 settings keys, for `dconf-editor`/`gnome-control-center`-style
  tooling. None of those six summary strings exist anywhere in the port.
  This is a second, smaller gap riding inside what looked like one settled
  item.

None of these three were called out as missing by the previous component
survey, because that survey's file mapping went straight from `.rs` to
`.rb` and never read `po/POTFILES.in` — the one place `data/*.in` files are
listed as components in their own right. They only became visible this
round by reading `POTFILES.in` side by side with the port's (see
`translation-parity.md`).

## Everything else

The remaining ~38 units all have a corresponding port file, correctly named
per the house style (`require_relative` chain rooted at `lib/mousai.rb`), each
opening with a comment naming the upstream file it was ported from. Per-widget
counts/CSS/signals for the window, dialogs and pages are carried in
`component-parity.md` rather than duplicated here.
