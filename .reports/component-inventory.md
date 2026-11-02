# Mousai — upstream component inventory

Survey of `origin/main` (Rust / gtk-rs / libadwaita) against `lib/` on `ruby`.
No app code was written in this step.

Read with `git show origin/main:<path>`; the upstream tree was exported to a
scratchpad and scanned with
`.claude/skills/component-identification/scripts/component-scan.sh`.

## Totals — how much app is left

| | upstream | `ruby` branch |
|---|---:|---:|
| widget rows (source + `.ui`) | 195 | 3 |
| distinct widget types | 51 | 3 |
| distinct CSS classes | 29 | 0 |
| distinct signals connected | 47 | 1 |
| GAction names | 16 | 0 |
| `.ui` templates / standalone objects | 17 + 1 | 0 (house style builds in code) |
| translated messages (`po/mousai.pot`) | 132 | 0 |
| locales (`po/LINGUAS`) | 48 | 0 |

`lib/` currently holds `lib/mousai.rb` and `lib/mousai/application.rb` — a
placeholder `Adwaita::ApplicationWindow` + `ToolbarView` + `HeaderBar` +
`StatusPage` saying the port has not been written. **Every component below is
absent**; the only existing file is the application shell, and it carries none
of upstream's actions, accelerators or views.

## Component map

One upstream widget class is a source file plus (usually) a `.ui` template;
the port merges both into one `lib/*.rb`. Ordered as a user meets them.

| # | Upstream file(s) | → port file | Kind | In `lib/`? |
|---|---|---|---|---|
| 1 | `src/main.rs`, `src/application.rs` | `lib/mousai/application.rb` | application | placeholder only |
| 2 | `src/window/mod.rs` + `data/resources/ui/window.ui` | `lib/window.rb` | window | no |
| 3 | `src/window/history_view.rs` + `ui/history_view.ui` | `lib/history_view.rb` | view | no |
| 4 | `ui/history_view.ui` (`menu id="menu"`) | part of `lib/history_view.rb` | menu | no |
| 5 | `ui/history_view.ui` (`menu id="selection_menu"`) | part of `lib/history_view.rb` | menu | no |
| 6 | `ui/history_view.ui` (`content_empty_page`) | part of `lib/history_view.rb` | empty state | no |
| 7 | `ui/history_view.ui` (`content_empty_search_result_page`) | part of `lib/history_view.rb` | empty state | no |
| 8 | `src/window/history_view.rs` (`show_undo_remove_song_toast`) | part of `lib/history_view.rb` | toast | no |
| 9 | `src/window/song_tile.rs` + `ui/song_tile.ui` | `lib/song_tile.rb` | tile | no |
| 10 | `src/window/album_cover.rs` + `ui/album_cover.ui` | `lib/album_cover.rb` | widget | no |
| 11 | `src/window/playback_button.rs` + `ui/playback_button.ui` | `lib/playback_button.rb` | widget | no |
| 12 | `src/window/song_page.rs` + `ui/song_page.ui` | `lib/song_page.rb` | page | no |
| 13 | `src/window/information_row.rs` + `ui/information_row.ui` | `lib/information_row.rb` | row | no |
| 14 | `src/window/external_link_tile.rs` + `ui/external_link_tile.ui` | `lib/external_link_tile.rb` | tile | no |
| 15 | `src/window/lyrics_page.rs` + `ui/lyrics_page.ui` | `lib/lyrics_page.rb` | page | no |
| 16 | `src/window/song_bar.rs` + `ui/song_bar.ui` | `lib/song_bar.rb` | bar | no |
| 17 | `src/window/recognizer_view.rs` + `ui/recognizer_view.ui` | `lib/recognizer_view.rb` | view | no |
| 18 | `src/window/waveform.rs` | `lib/waveform.rb` | custom-drawn widget | no |
| 19 | `src/window/recognizer_status.rs` + `ui/recognizer_status.ui` | `lib/recognizer_status.rb` | status widget | no |
| 20 | `src/window/progress_icon.rs` | `lib/progress_icon.rb` | custom-drawn widget | no |
| 21 | `src/window/recognized_page.rs` + `ui/recognized_page.ui` | `lib/recognized_page.rb` | page | no |
| 22 | `src/window/recognized_page_tile.rs` + `ui/recognized_page_tile.ui` | `lib/recognized_page_tile.rb` | tile | no |
| 23 | `src/preferences_dialog.rs` + `ui/preferences_dialog.ui` | `lib/preferences_dialog.rb` | preferences | no |
| 24 | `data/resources/ui/shortcuts.ui` | `lib/shortcuts_dialog.rb` | shortcuts | no |
| 25 | `src/about.rs` | `lib/about_dialog.rb` | about | no |
| 26 | `src/application.rs` (`present_database_error_dialog`) | `lib/database_error_dialog.rb` | error dialog | no |
| 27 | `src/window/mod.rs` (`present_recognize_error`) | `lib/recognize_error_dialog.rb` | error dialog | no |
| 28 | `src/window/mod.rs` (`present_recording_saved_message`) | `lib/recording_saved_dialog.rb` | error dialog | no |
| 29 | `src/inspector_page.rs` + `ui/inspector_page.ui` | `lib/inspector_page.rb` | devel page | no |
| 30 | `data/resources/style.css` | `lib/style.rb` (inline `Gtk::CssProvider`) | stylesheet | no |
| 31 | `data/io.github.seadve.Mousai.gschema.xml.in` | `lib/settings.rb` | GSettings | no |
| 32 | `po/mousai.pot`, `po/*.po` (48) | `po/` | translations | no |

### Per-component detail

#### 1. `src/main.rs` + `src/application.rs` → `lib/mousai/application.rb` — the app

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `activate`, `startup`, `shutdown` | app id `io.github.seadve.Mousai`, resource base path |
| `Adw.AboutDialog` | 1 | — | via `app.show-about` | see #25 |
| `Adw.AlertDialog` | 1 | — | `response` | critical database error, see #26 |

Actions installed: `app.quit`, `app.show-preferences`, `app.show-about`
(`app.shortcuts` comes free from libadwaita via the
`shortcuts-dialog.ui` resource alias — see #24).
Accelerators: `app.quit` `<Control>q`, `app.show-preferences`
`<Control>comma`, `window.close` `<Control>w`, `win.toggle-playback`
`<Control>space`, `win.toggle-recognize` `<Control>r`, `win.toggle-search`
`<Control>f`.
Also: GStreamer init, gettext bind, GResource load, `set_default_icon_name`,
soup session + cache, album-art store, db env + migrations, inspector page
registration.

#### 2. `src/window/mod.rs` + `ui/window.ui` → `lib/window.rb` — the main window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (when `PROFILE == "Devel"`) | `close-request` | `width-request` 360, `height-request` 294 |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 450px` → sets `adaptive-mode: narrow` on `main_view` and `song_bar` |
| `Adw.ToastOverlay` | 1 | — | — | id `toast_overlay`; every `add_message_toast` lands here |
| `Gtk.Box` (vertical) | 1 | — | — | |
| `Gtk.Stack` | 1 | — | — | crossfade; children: `HistoryView`, `RecognizerView` |
| `Gtk.Revealer` | 1 | — | — | slide-up, wraps the `SongBar` |
| `Gtk.EventControllerKey` | 1 (controller) | — | `key-pressed` → `key_pressed` | capture phase; Escape pops a navigation page |
| `Adw.Toast` | n | — | — | messages: "Failed to insert song to history", "An error occurred in the player", recognize errors |

Actions installed: `win.toggle-playback`, `win.toggle-recognize` (async),
`win.toggle-search`. Window size/maximized persisted to GSettings.

#### 3. `src/window/history_view.rs` + `ui/history_view.ui` → `lib/history_view.rb` — the song history

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| template root (`Gtk.Widget` + `Gtk.BinLayout`) | 1 | `view` | — | |
| `Adw.NavigationView` | 1 | — | `pushed`, `popped` | keeps a forward stack of pages |
| `Adw.NavigationPage` | 1 | — | — | title "Home" |
| `Adw.ToolbarView` | 1 | — | — | top: header-bar stack + search bar; bottom: action bar |
| `Gtk.Stack` (`header_bar_stack`) | 1 | — | — | normal ↔ selection-mode header bars |
| `Adw.HeaderBar` | 2 | — | — | `main_header_bar`, `selection_mode_header_bar` |
| `Gtk.Button` "Listen" | 1 | `suggested-action` | `win.toggle-recognize` | tooltip "Recognize Song" |
| `MousaiRecognizerStatus` | 1 | — | `show-results-requested` | see #19 |
| `Gtk.MenuButton` | 1 | — | menu `menu`, `primary` | tooltip "Main Menu", `open-menu-symbolic` |
| `Gtk.Button` select | 1 | — | `history-view.toggle-selection-mode` | `selection-mode-symbolic` |
| `Gtk.ToggleButton` search | 2 | — | bound bidirectionally to `search_bar.search-mode-enabled` | one per header bar |
| `Gtk.MenuButton` (`selection_mode_menu_button`) | 1 | — | menu `selection_menu` | title widget, label = "N selected" |
| `Gtk.Button` "Cancel" | 1 | — | `history-view.toggle-selection-mode` | |
| `Gtk.SearchBar` + `Gtk.SearchEntry` | 1 + 1 | — | `search-changed` | placeholder "Search songs"; key capture on the window |
| `Gtk.Stack` (`content_stack`) | 1 | — | — | grid / empty / empty-search |
| `Gtk.ScrolledWindow` | 1 | — | `scroll-child` (scroll to top) | `hscrollbar-policy: never` |
| `Gtk.GridView` | 1 | `history-view` | `activate` → push `SongPage` | `min-columns: 2`, `MultiSelection` over `SortListModel`→`FilterListModel`→`SongList` |
| `Adw.StatusPage` | 2 | `icon-dropshadow` (first only) | — | see #6, #7 |
| `Gtk.ActionBar` | 1 | — | — | selection mode bar |
| `Gtk.Button` copy / trash | 2 | — | `history-view.copy-selected-song`, `history-view.remove-selected-songs` | `edit-copy-symbolic`, `user-trash-symbolic` |

Repeaters: the `GridView` factory makes one `MousaiSongTile` per song
(`selection-mode-requested` connected per tile); `SongPage`/`LyricsPage` are
pushed on demand.
Actions installed: `history-view.toggle-selection-mode`, `.select-all`,
`.select-none`, `.copy-selected-song`, `.remove-selected-songs`.
Toasts: "Copied to clipboard", "Failed to remove selected songs",
"Failed to remove song", "Failed to undo", "Failed to show recognizer
results", plus the undo toast (#8).

#### 4–5. Menus

`menu` (primary): `_Preferences` → `app.show-preferences`,
`_Keyboard Shortcuts` → `app.shortcuts`, `_About Mousai` → `app.show-about`.
`selection_menu`: `Select _All` → `history-view.select-all`,
`_Unselect All` → `history-view.select-none`.

#### 6–7. Empty states

`content_empty_page` — `Adw.StatusPage`, CSS `icon-dropshadow`, title
"Start Recognizing Songs!", description "Click the listen button to start".
`content_empty_search_result_page` — `Adw.StatusPage`,
`system-search-symbolic`, title "No Results".

#### 8. Undo-remove toast

`Adw.Toast` with button "Undo", title via `ngettext_f`
("Removed N song(s)"), `connect_button_clicked` restores from purgatory,
`connect_dismissed` commits; re-added to reset the timeout.

#### 9. `src/window/song_tile.rs` + `ui/song_tile.ui` → `lib/song_tile.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| template root | 1 | css-name `songtile` | custom signal `selection-mode-requested` | `Gtk.BinLayout` |
| `Gtk.Overlay` | 2 | — | — | outer (select button), inner (new label, playback button) |
| `MousaiAlbumCover` | 1 | — | — | |
| `Gtk.Label` "New" | 1 | `new` | — | hidden unless `song.is-newly-heard` |
| `MousaiPlaybackButton` | 1 | `osd`, `circular` | `song-tile.toggle-playback` | |
| `Gtk.Label` title / artist | 2 | artist: `caption`, `dim-label` | property bindings to `song.title` / `song.artist` | 2 lines, ellipsize end |
| `Gtk.Revealer` + `Gtk.CheckButton` | 1 + 1 | `selection-mode` | `notify::active` → `selection-mode-requested` | crossfade |
| `Gtk.EventControllerMotion` | 1 (controller) | — | `enter`, `leave` | reveals select button on hover |
| `Gtk.GestureClick` | 1 (controller) | — | `released` (secondary) | request selection mode |
| `Gtk.GestureLongPress` | 1 (controller) | — | `pressed` (touch) | request selection mode |

Action installed: `song-tile.toggle-playback`. Tooltips "Select" / "Unselect".

#### 10. `src/window/album_cover.rs` + `ui/album_cover.ui` → `lib/album_cover.rb`

Root `card`, `overflow: hidden`, `Gtk.BinLayout`; `Gtk.Stack` with
`placeholder` (`Gtk.Image`, `emblem-music-symbolic`, `dim-label`) and
`image_a` / `image_b` crossfaded as album art loads from `AlbumArtStore`.

#### 11. `src/window/playback_button.rs` + `ui/playback_button.ui` → `lib/playback_button.rb`

`Gtk.Button` subclass; `Gtk.Stack` with `Gtk.Image` and `Adw.Spinner` (24×24).
Icon/tooltip follow player state: `media-playback-start-symbolic` / "Play",
`media-playback-pause-symbolic` / "Pause", spinner while loading.

#### 12. `src/window/song_page.rs` + `ui/song_page.ui` → `lib/song_page.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` | 1 | — | custom `song-remove-request`, `show-lyrics-request` | |
| `Adw.ToolbarView` + `Adw.HeaderBar` + `Adw.WindowTitle` | 1 each | — | — | |
| `Gtk.Button` remove | 1 | — | `clicked` → `song-remove-request` | `user-trash-symbolic`, "Remove From History" |
| `Gtk.Button` copy | 1 | — | `song-page.copy-song` | `edit-copy-symbolic`, "Copy" |
| `Gtk.ScrolledWindow` + `Adw.Clamp` + `Gtk.Box` | 1 each | — | — | margins 24, spacing 24 |
| `MousaiAlbumCover` | 1 | — | — | |
| `Gtk.Label` title / artist | 2 | `title-1`; `title-4` + `dim-label` | bindings to `song` | |
| `MousaiPlaybackButton` | 1 | `circular` | `clicked` | 40×40 |
| `Adw.PreferencesGroup` | 2 | — | — | "Listen", "Information" |
| `Gtk.FlowBox` | 1 | — | `child-activated` → `ExternalLinkTile#handle_activation` | selection none, single click |
| `MousaiInformationRow` | 3 | — | — | "Last Heard", "Album", "Release Date" |
| `Adw.ActionRow` lyrics | 1 | — | `activated` → `show-lyrics-request` | suffix `go-next-symbolic`, activatable |

Action installed: `song-page.copy-song` (toast "Copied to clipboard").
Values fall back to "Unknown".

#### 13. `src/window/information_row.rs` + `ui/information_row.ui` → `lib/information_row.rb`

`Adw.ActionRow` subclass with a suffix `Gtk.Label` (`dim-label`, selectable,
xalign 1, ellipsize end). Row hides itself when its value is empty.

#### 14. `src/window/external_link_tile.rs` + `ui/external_link_tile.ui` → `lib/external_link_tile.rb`

`Gtk.FlowBoxChild` subclass, CSS `external-link-tile` + `card`, plus one of
`applemusic` / `audd` / `spotify` / `youtube` added per link kind. Inner
`Gtk.Box` (spacing 12, margins 24/18) with a `Gtk.Label` (`title-2`).
Labels/tooltips: "Apple Music"/"Browse on Apple Music", "AudD"/"Browse on
AudD", "Spotify"/"Listen on Spotify", "YouTube"/"Search on YouTube".
`handle_activation` launches the URI; failure raises a toast.

#### 15. `src/window/lyrics_page.rs` + `ui/lyrics_page.ui` → `lib/lyrics_page.rb`

`Adw.NavigationPage` → `Adw.ToolbarView` → `Adw.HeaderBar` with
`Adw.WindowTitle` (subtitle "Lyrics"); `Gtk.ScrolledWindow` → `Adw.Clamp` →
`Gtk.Label` (`lyrics-label`, wrap, xalign 0, margins 24).

#### 16. `src/window/song_bar.rs` + `ui/song_bar.ui` → `lib/song_bar.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| root (`Gtk.BoxLayout` vertical) | 1 | — | custom `activated` | |
| `Gtk.Scale` + `Gtk.Adjustment` | 1 + 1 | `playback-position-scale` | `value-changed` → `player.seek` | 0–100, hexpand |
| `Adw.MultiLayoutView` | 1 | — | — | layouts `normal` (`Gtk.CenterBox`) and `narrow` (`Gtk.Box`) |
| `Adw.LayoutSlot` | 4 | — | — | `song_info` ×2, `playback_controls` ×2 |
| `Gtk.Label` position/duration | 1 | `dim-label`, `numeric` | — | `M:SS / M:SS`, normal layout only |
| `Adw.Bin` + `Gtk.Button` | 1 + 1 | `flat`, `activate-song-button` | `song-bar.activate` | "Show Song Information" |
| `MousaiAlbumCover` | 1 | — | — | pixel-size 42 |
| `Gtk.Label` title / artist | 2 | artist: `caption`, `dim-label` | — | |
| `MousaiPlaybackButton` | 1 | `circular` | `win.toggle-playback` | 40×40 |
| `Gtk.Button` stop | 1 | `circular`, `flat` | `song-bar.clear` | `media-playback-stop-symbolic`, "Stop" |

Actions installed: `song-bar.clear`, `song-bar.activate`.

#### 17. `src/window/recognizer_view.rs` + `ui/recognizer_view.ui` → `lib/recognizer_view.rb`

`Gtk.BinLayout` root → `Adw.ToolbarView`; header bar holds a `Gtk.Button`
"Cancel" (`destructive-action`, `win.toggle-recognize`, tooltip "Cancel
Listening"). Content: `MousaiWaveform`, a `Gtk.Label` (`title-1`) reading
"Listening…" / "Recognizing…", and a `Gtk.Revealer` (crossfade) with a
`Gtk.Label` "Offline Mode" (`caption`). The waveform gains/loses the `red`
CSS class while recognizing; peaks pushed from the recorder.

#### 18. `src/window/waveform.rs` → `lib/waveform.rb`

Custom `Gtk.Widget`, css-name `waveform`, `snapshot` draws a stroked path from
a ring buffer of peaks; styled by `waveform` / `waveform.red` in style.css.
API: `push_peak`, `clear_peaks`.

#### 19. `src/window/recognizer_status.rs` + `ui/recognizer_status.ui` → `lib/recognizer_status.rb`

`Gtk.BoxLayout` root, custom signal `show-results-requested`; three
`Gtk.Revealer`s (slide-right): a `Gtk.Image` `network-offline-symbolic`
("Offline Mode Enabled"), a `MousaiProgressIcon` (16×16, tooltip "Recognizing
N saved recording(s)…"), and a `Gtk.Button` (`show-results-button`, `flat`)
whose `Gtk.Label` shows the count of pending offline results — tooltip "Show
Offline Mode Recognition Results", `clicked` → `show-results-requested`.

#### 20. `src/window/progress_icon.rs` → `lib/progress_icon.rb`

Custom `Gtk.Widget` drawing a pie-slice progress indicator via
`snapshot.append_cairo`; `progress` property 0.0–1.0.

#### 21. `src/window/recognized_page.rs` + `ui/recognized_page.ui` → `lib/recognized_page.rb`

`Adw.NavigationPage` (header bar with `show-title: false`) →
`Gtk.ScrolledWindow` → `Gtk.Box`; `Gtk.Label` heading (`title-1`) and body,
both `ngettext`-pluralised over the number of newly recognized songs;
`Adw.Carousel` (`allow-long-swipes`) of `MousaiRecognizedPageTile`s plus
`Adw.CarouselIndicatorDots`. Custom signal `song-activated`.
Repeater: one tile per recognized song.

#### 22. `src/window/recognized_page_tile.rs` + `ui/recognized_page_tile.ui` → `lib/recognized_page_tile.rb`

css-name `recognizedpagetile`, vertical `Gtk.BoxLayout` spacing 12;
`Gtk.Label` last-heard (`caption-heading`) and a `MousaiSongTile` with
`shows-select-button-on-hover: false`. `Gtk.GestureClick` → custom
`activated`. Styled in style.css to mimic a flat button
(`recognizedpagetile songtile`, `:hover`, `:active`).

#### 23. `src/preferences_dialog.rs` + `ui/preferences_dialog.ui` → `lib/preferences_dialog.rb`

`Adw.PreferencesDialog` → one `Adw.PreferencesPage` with two groups:
"General" with an `Adw.ComboRow` "Audio Source" / "Device used for listening"
(`Gtk.StringList` "Microphone", "Desktop Audio", bound to the
`audio-source-type` key), and "AudD" (description with a markup link to
audd.io) with an `Adw.EntryRow` "API Token" (`show-apply-button`,
`max-width-chars` 32, input hints no-spellcheck/no-emoji/private, `apply` →
`aud-d-api-token`). `focus_aud_d_api_token_row` is called from the
recording-saved dialog.

#### 24. `data/resources/ui/shortcuts.ui` → `lib/shortcuts_dialog.rb`

`Adw.ShortcutsDialog` (resource alias `shortcuts-dialog.ui`, so libadwaita
wires `app.shortcuts` automatically). Section "General": Open Main Menu `F10`,
Search `win.toggle-search`, Show Preferences `app.show-preferences`, Show
Shortcuts `app.shortcuts`, Close Window `window.close`, Quit `app.quit`.
Section "Controls": Toggle Listen `win.toggle-recognize`, Toggle Playback
`win.toggle-playback`.

#### 25. `src/about.rs` → `lib/about_dialog.rb`

`Adw.AboutDialog`: app icon/name, developer "Dave Patrick Caberto", version,
copyright, GPL-3.0, translator credits, issue + support URLs, release notes
for 0.7.0, a generated `debug_info` block (`mousai-debug-info`), and three
links: Donate, GitHub, Translate.

#### 26–28. Alert dialogs

- **Critical Database Error** (`application.rs`) — `Adw.AlertDialog`, markup
  body pointing at the issue tracker, single suggested response "Quit".
- **Recognize error** (`window/mod.rs`) — heading from
  `RecognizeError#title`; for `OtherPermanent`/`Fingerprint`: "No, Thanks" +
  suggested "Open an Issue" (`Gtk.UriLauncher`); for `NoMatches`: "No, Thanks"
  + suggested "Try Again" (re-activates `win.toggle-recognize`).
- **Recording Saved** (`window/mod.rs`) — for `Connection`: "Ok, Got It"; for
  `TokenLimitReached`: "I'll Wait" + "Open Preferences"; for `InvalidToken`:
  "Later" + "Open Preferences" (opens prefs and focuses the token row).

#### 29. `src/inspector_page.rs` + `ui/inspector_page.ui` → `lib/inspector_page.rb`

GTK-inspector page ("Recognizer Developer Settings", "These will be reset upon
closing the inspector"): `Adw.ComboRow` Provider (`AdwEnumListModel` over
`ProviderType`), `Adw.ComboRow` Test Provider Mode, and two `Adw.SpinRow`s —
Test Listen Duration / Test Recognize Duration (seconds). The latter three are
insensitive unless the provider is a test provider. Registered through the
`gtk-inspector-page` extension point.

#### 30. `data/resources/style.css` → `lib/style.rb`

29 distinct classes/selectors. Groups: `--tile-hover-oklch`/`--tile-active-oklch`
root vars; `waveform` / `waveform.red`; `.external-link-tile` + four brand
variants with hover/active gradients; `.history-view` and `.history-view > child`;
`.lyrics-label`; `recognizedpagetile songtile` hover/active; `.show-results-button`
and its label pill; `.activate-song-button`; `.playback-position-scale`
(trough/highlight, grows on hover); `label.new` pill.

#### 31. `data/io.github.seadve.Mousai.gschema.xml.in` → `lib/settings.rb`

Keys: `window-width` (768), `window-height` (600), `window-maximized` (false),
`audio-source-type` (`microphone` | `desktop-audio`), `aud-d-api-token` (""),
`memory-list` (legacy, migration only).

#### 32. `po/` → `po/`

`po/mousai.pot` has 132 messages; `po/LINGUAS` lists 48 locales.
`po/POTFILES.in` names 12 `.ui` files and 15 Rust files as the extraction
set — the port's equivalents are the `lib/*.rb` files in this table.

## Model and support layer (not user-facing, but the components need it)

| Upstream | → port file | Notes |
|---|---|---|
| `src/song.rs` | `lib/song.rb` | the song GObject: title, artist, album, release date, lyrics, external links, `is-newly-heard`, `last-heard` |
| `src/song_list.rs` | `lib/song_list.rb` | `Gio.ListModel` history + purgatory (undo), db-backed |
| `src/song_filter.rs` | `lib/song_filter.rb` | fuzzy search filter |
| `src/song_sorter.rs` | `lib/song_sorter.rb` | search-aware sorter |
| `src/player.rs` | `lib/player.rb` | GStreamer playbin + MPRIS server, `error` signal |
| `src/recognizer/mod.rs` | `lib/recognizer.rb` | state machine: Null → Listening → Recognizing, offline mode |
| `src/recognizer/recorder.rs` | `lib/recorder.rb` | GStreamer record pipeline, peak signal |
| `src/recognizer/recording.rs` | `lib/recording.rb` | one saved recording |
| `src/recognizer/recordings.rs` | `lib/recordings.rb` | saved-recording list model |
| `src/recognizer/provider/mod.rs` | `lib/provider.rb` | provider trait + `ProviderType` enum |
| `src/recognizer/provider/error.rs` | `lib/recognize_error.rb` | error kinds and titles (translated) |
| `src/recognizer/provider/settings.rs` | `lib/provider_settings.rb` | the inspector page's backing store |
| `src/recognizer/provider/aud_d/{mod,response}.rs` | `lib/aud_d.rb`, `lib/aud_d_response.rb` | the real provider |
| `src/recognizer/provider/aud_d/mock.rs`, `provider/error_tester.rs` | `lib/mock_provider.rb`, `lib/error_tester_provider.rb` | test providers |
| `src/album_art.rs` | `lib/album_art.rb` | album-art cache + store |
| `src/external_link.rs`, `src/external_links.rs` | `lib/external_link.rb`, `lib/external_links.rb` | link keys → URIs |
| `src/settings.rs` | `lib/settings.rb` | typed GSettings wrapper (see #31) |
| `src/device.rs` | `lib/device.rb` | default pulse source/sink lookup |
| `src/date_time.rs` | `lib/date_time.rb` | translated fuzzy "last heard" strings |
| `src/uid.rs` | `lib/uid.rb` | song ids |
| `src/database/{mod,migrations}.rs` | `lib/database.rb`, `lib/migrations.rb` | heed env + migrations |
| `src/i18n.rs` | `lib/i18n.rb` | `gettext_f` / `ngettext_f` interpolation helpers |
| `src/utils.rs`, `src/cancelled.rs`, `src/serde_helpers.rs` | `lib/utils.rb`, `lib/cancelled.rb` | misc |

## Notes for whoever ports next

- Upstream splits components across `src/window/*.rs` + `data/resources/ui/*.ui`;
  the port merges each pair into one `lib/*.rb` built with memoized accessors.
- Three widgets are custom-drawn (`Waveform`, `ProgressIcon`) or css-named
  (`SongTile`, `RecognizedPageTile`, `Waveform`): css **names**, not classes —
  `.show-results-button` style rules target element names in style.css and must
  be reproduced as such.
- `app.shortcuts` is not installed in code; it comes from the
  `shortcuts-dialog.ui` resource alias. A Ruby port has no GResource, so the
  shortcuts dialog needs an explicit `app.shortcuts` action.
- Three `Adw.AlertDialog` flows (#26–28) are easy to miss: they are built in
  Rust functions, not in any `.ui`.
