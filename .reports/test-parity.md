# Mousai — test parity

## Runtime gate, verified by actually running it

This pass did not take the "142 checks, 0 failed" claim on faith — all four
suites were run fresh, in the fork's dev shell, against a virtual display:

```
nix develop --command xvfb-run -a ruby test/test_models.rb      → 50 of 50 checks passed
nix develop --command xvfb-run -a ruby test/drive_main_window.rb → 21 of 21 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_playback.rb    → 53 of 53 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_app_dialogs.rb → 18 of 18 checks passed, DRIVE OK
```

50 + 21 + 53 + 18 = **142, 0 failed** — the claimed gate is real and
reproducible, not asserted. The suite runs as a hand-rolled `Checks` runner
(`test/test_models.rb:33-69`) plus three scripted GTK drivers, not RSpec.

## The RSpec harness is installed and empty — a gap worth saying plainly

`spec/spec_helper.rb` wires up `kettle-test`/RSpec (SimpleCov, Timecop
helpers, `stub_env`, etc. — see `spec/README.md`), and `rake spec` is a
defined task. But **there are no `*_spec.rb` files anywhere in the repo** —
`spec/` holds only `spec_helper.rb` and `README.md`. Running `rake spec` (or
`bundle exec rspec`) today executes zero examples and reports success,
which is exactly the "a suite that has never been executed" pattern this
audit was told to call out. The actual test suite lives entirely in
`test/*.rb`, run by hand with `ruby`, outside Bundler/RSpec/Rake. This is not
disqualifying by itself (the house pattern across this fleet is a
hand-rolled driver + checks runner, matching `ruby-gtk-testing`'s recipes),
but anyone running `rake spec` or `bundle exec rspec` and seeing it pass
would be looking at a suite that tested nothing, not a green signal.

## Upstream has 20 files with `#[cfg(test)]` unit tests. Line-by-line coverage check

| Upstream file (test fns) | Port coverage | Verdict |
|---|---|---|
| `src/uid.rs` | `test/test_models.rb` group "Uid" (6 checks) | ported |
| `src/date_time.rs` | group "DateTime" (5 checks) | ported |
| `src/utils.rs` | group "Utils.consecutive_groups" (3 checks) | ported |
| `src/i18n.rs` | group "I18n" (3 checks) | ported (the `{name}` substitution only — see translation-parity.md for the msgctxt/catalogue gap, which is out of this test's scope) |
| `src/external_links.rs` | group "ExternalLinks" (4 checks) | ported |
| `src/song.rs` | group "Song" (8 checks) | ported |
| `src/song_filter.rs`, `src/song_sorter.rs` | group "SongFilter and SongSorter" (5 checks) | ported |
| `src/database/mod.rs`, `src/song_list.rs` | group "Database and SongList" (9 checks) | ported |
| `src/database/migrations.rs` | group "Migrations" (4 checks) | ported |
| `src/recognizer/provider/settings.rs` (`reset`, `identity`) | exercised live in `test/drive_app_dialogs.rb` ("ProviderSettings reset back to defaults on close", "active reset to AudD") | ported, as a drive assertion rather than a unit test — acceptable correspondence |
| `src/recognizer/recording.rs` (`serde_bincode` round-trip) | `test/drive_playback.rb` "a recording is saved, read back and taken" / "its bytes survived" / "its error survived" | ported via an equivalent JSON/DB round-trip (the port has no bincode; this is the right correspondence, not a gap) |
| `src/serde_helpers.rs` (`serde_bincode`), `src/recognizer/provider/error.rs` (`serde_bincode`) | same recording/database round-trip above covers the same serialization surface indirectly | acceptable correspondence |
| **`src/recognizer/provider/aud_d/mod.rs`** — 7 tests: `invalid_json`, `no_matches`, `daily_limit_reached`, `wrong_api_token`, `wrong_file_sent_or_audio_without_streams`, `proper_but_no_spotify_field`, `proper` | **none.** `lib/aud_d_response.rb` (`AudDResponse.parse`, `AudDResponse::Data`) has zero references anywhere under `test/` | **GAP** — the response parser that turns AudD's JSON into a `Song` or a typed error is untested on the port side. This is exactly the kind of logic (status-code branching, missing-field handling) that silently breaks on a port and only a parser unit test catches. |
| **`src/recognizer/recordings.rs`** — 5 tests: `load_from_db`, `insert`, `insert_items_changed`, `peek_filtered`, `peek_filtered_items_changed` | **none directly.** `lib/recordings.rb` implements `peek_filtered` (`lib/recordings.rb:67`) and an `items_changed` notification path (`emit_items_changed`, `lib/recordings.rb:123`) — the logic exists — but no test in `test/` calls `peek_filtered` or asserts an `items_changed` position/removed/added triple. `test/drive_playback.rb` only exercises the save → recognize → take-off-the-list happy path, which never calls `peek_filtered` and never asserts the exact `(position, removed, added)` shape | **GAP** — logic is present, untested; the exact item-changed accounting upstream unit-tests is unverified on the port |
| **`src/window/song_bar.rs`** — `test_format_clock_time_minute_sec` (several clock-time → `mm:ss` cases) | **none.** `SongBar.format_clock_time_minute_sec` is ported at `lib/song_bar.rb:288` and used by `update_playback_position_duration_label`, but nothing in `test/` calls it directly or checks its output string | **GAP** — a pure, trivially-testable formatting function with zero assertions on the port side |
| **`src/window/history_view.rs`** — 6 navigation-stack tests: `navigation_simple`, `navigation_pop_and_push`, `navigation_pop_and_forward`, `navigation_complex`, `navigation_push_song_page_same_song_id`, `navigation_push_recognized_page_with_duplicate` | **partial.** `test/drive_main_window.rb` pushes a song page, pushes a lyrics page, and pops back (checks 17-21) — that's `navigation_simple` territory. The dedup edge cases upstream unit-tests explicitly — pushing the same song id twice, pushing a `RecognizedPage` for a song already on the stack — have no equivalent anywhere in `test/` | **GAP** — the navigation-stack dedup behaviour (the part most likely to regress silently, since it only matters on a double-push) is unverified |
| `src/album_art.rs` | no `#[cfg(test)]` block found upstream either (checked directly — `grep '#\[test\]' src/album_art.rs` returns nothing) | not a port gap — upstream itself has no unit tests here |

## Bottom line

The runtime gate (142/142) is real, and it is a meaningfully broad suite —
it is not a thin smoke test. But "142 checks passed" is not the same claim
as "every upstream test is ported": three upstream test files with real
assertion logic (AudD response parsing, the Recordings list-model's
`peek_filtered`/`items_changed` accounting, and `song_bar`'s clock-time
formatter) have ported *implementations* but zero ported *tests*, and one
more (history-view navigation dedup) is only partially covered. None of
these are flagged anywhere in the existing reports or commit messages as
"ported without tests" — they read as done because the drive scripts pass,
but the drive scripts never exercise these specific code paths closely
enough to catch a regression in them.
