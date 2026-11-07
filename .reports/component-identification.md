# Mousai — component identification (refresh)

Audit pass against `origin/main` (Rust / gtk-rs / libadwaita), read via
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
This supersedes `.reports/component-inventory.md` (written at `6fef548`,
before `f25ff9a` ported `lib/inspector_page.rb` and `322aa11` drove the About,
Shortcuts and devel Inspector dialogs). No app code was written in this pass.

## Totals

- `lib/` holds 54 files (51 top-level + `lib/mousai/application.rb`,
  `lib/mousai/rb/version.rb`). Upstream has 64 source files + 17 `.ui`
  templates + `shortcuts.ui` (no backing `.rs`).
- GSettings schema: upstream's `data/io.github.seadve.Mousai.gschema.xml.in`
  declares exactly 6 keys — `window-width`, `window-height`,
  `window-maximized`, `audio-source-type`, `aud-d-api-token`, `memory-list`.
  All 6 are implemented in `lib/settings.rb`. No gap here (the earlier
  survey's table only listed 4 of the 6 and should not be read as the full
  set).
- GAction inventory, read from both sides directly (not grepped blind):

  | Action | Upstream site | Port site |
  |---|---|---|
  | `app.quit` | `src/application.rs:232` | `lib/mousai/application.rb:130` |
  | `app.show-preferences` | `src/application.rs:237` | `lib/mousai/application.rb:136` |
  | `app.show-about` | `src/application.rs:243` | `lib/mousai/application.rb:142` |
  | `app.shortcuts` | referenced by `shortcuts.ui`/`history_view.ui`, not installed by any `src/*.rs` (libadwaita/GTK convenience) | `lib/mousai/application.rb:148` installs it explicitly as `"shortcuts"` |
  | `app.show-inspector-page` | devel-only, `src/application.rs` (behind `MOUSAI_DEVEL`) | `lib/mousai/application.rb:154`, gated the same way |
  | `win.toggle-search` | `src/window/mod.rs:106` | `lib/window.rb:212` |
  | `win.toggle-playback` | `src/window/mod.rs:80` | `lib/window.rb:218` |
  | `win.toggle-recognize` | `src/window/mod.rs:90` | `lib/window.rb:225` |
  | `history-view.toggle-selection-mode` / `.select-all` / `.select-none` / `.copy-selected-song` / `.remove-selected-songs` | `src/window/history_view.rs` | `lib/history_view.rb:388-412` |
  | `song-bar.clear` / `.activate` | `src/window/song_bar.rs` | `lib/song_bar.rb:275-281` |
  | `song-tile.toggle-playback` | `src/window/song_tile.rs` | `lib/song_tile.rb:272` |
  | `song-page.copy-song` | `src/window/song_page.rs:75`, bound via `action-name="song-page.copy-song"` on the copy button in `data/resources/ui/song_page.ui:21` | **not installed** — `lib/song_page.rb` wires the copy button straight to `signal_connect("clicked") { copy_song }` instead of installing a `song-page.*` action group (see `component-parity.md` finding) |

- Menu items (`history_view.ui`'s `menu` and `selection_menu`): all 5 items —
  `_Preferences`, `_Keyboard Shortcuts`, `_About Mousai`, `Select _All`,
  `_Unselect All` — exist in `lib/history_view.rb:278-288` with
  byte-identical msgids (mnemonics included) and the same action targets.
- Shortcuts dialog (`shortcuts.ui`): both sections (`General`, `Controls`)
  and all 8 items are present in `lib/shortcuts_dialog.rb`, including
  "Toggle Listen" → `win.toggle-recognize`, which a prior survey had flagged
  missing and which `322aa11`'s predecessor commit fixed.
- Empty/error states: `content_empty_page` and
  `content_empty_search_result_page` (history view) both exist in
  `lib/history_view.rb:318-329` and are driven by `test/drive_main_window.rb`
  ("grid page is showing" / "no-results page is showing"). The three error
  dialogs (`RecognizeErrorDialog`, `RecordingSavedDialog`,
  `DatabaseErrorDialog`) and the devel `InspectorPage` all exist and are
  opened by the drive scripts.

## Outstanding from the component map (unchanged from the last survey)

- `po/` — no message catalogue exists on `ruby` at all (132 msgids upstream,
  0 ported; 48 locales upstream, 0 ported). See `translation-parity.md` for
  the full accounting; this is the single largest remaining gap.
- No `.desktop`, `.metainfo.xml`, `.gschema.xml` or D-Bus `.service` file is
  installed anywhere in the port tree — the gem has no packaging/build-system
  equivalent of `data/meson.build`. This doesn't block the Ruby-level UI
  parity this fleet is scoped to, but it means nothing in the port actually
  registers the app id, installs the real GSettings schema, or exposes
  desktop integration (app menu entry, MIME/URL handling via the `.service`
  file) the way a built upstream flatpak does. Flagged for visibility, not
  scored as a UI gap.

## New finding this pass

`lib/song_page.rb`'s copy button is wired directly (`signal_connect("clicked")`)
rather than through an installed `song-page.copy-song` action, unlike every
other interactive widget in the port (`history-view.*`, `song-bar.*`,
`song-tile.*` all install real `Gio::SimpleAction`s). Upstream's own copy
button is *also* just bound to that one action via `action-name=`, so the
end-user click behaviour is identical today — but the action itself does not
exist in the port, so anything else that might target `song-page.copy-song`
(a future shortcut, a context menu, an accessibility bridge) has nothing to
bind to. See `component-parity.md`.
