# Mousai — test parity

| | |
|---|---|
| Upstream | `main` @ `27df214` |
| Port | `ruby` @ `fae1b49` |
| Upstream tests (censused) | 86 |
| Ported (named, same property) | **0 of 86** — see below |
| Gaps | 86 |
| Runtime gate this round | `drive_ok=true`, 147/147 checks, 25 components — **verified by actually running every suite**, see "The runtime gate, re-run" |

This supersedes the previous `test-parity.md`. Numbers below come from
running `.claude/skills/test-parity/scripts/test-census.sh` against an
`origin/main` worktree and against the port tree directly, then reading every
file by hand — not from the previous pass's claims.

## The headline finding: the port has not pinned a single upstream test by name

`test-census.sh` against upstream finds **86** `#[test]` functions across 18
source files:

```
18  src/song_list.rs
 9  src/recognizer/recordings.rs
 7  src/recognizer/provider/aud_d/mod.rs
 7  src/i18n.rs
 7  src/external_links.rs
 6  src/window/history_view.rs
 6  src/utils.rs
 6  src/uid.rs
 4  src/song.rs
 3  src/song_filter.rs
 3  src/date_time.rs
 3  src/album_art.rs
 2  src/recognizer/provider/settings.rs
 1  src/window/song_bar.rs
 1  src/song_sorter.rs
 1  src/recognizer/recording.rs
 1  src/recognizer/provider/error.rs
 1  src/database/migrations.rs
```

(This is itself a lower bound: `src/database/mod.rs` and
`src/serde_helpers.rs` each carry additional `#[test]`s that a manual
`grep -c '#\[test\]'` over those two files found but the census script's
module-boundary heuristic did not attribute; they are real upstream tests
regardless of which file they are counted against.)

`test/test_models.rb` is a real, working, from-scratch suite — 50 checks,
verified passing below — organised into 10 named groups (`Uid`, `DateTime`,
`Utils.consecutive_groups`, `I18n`, `ExternalLinks`, `Song`, `SongFilter and
SongSorter`, `Settings`, `Database and SongList`, `Migrations`). It tests
*behaviours that overlap* with roughly half of upstream's 18 test files. But
**not one of its 50 checks is named after, or written against, a specific
upstream test**: there is no mapping from `check("ids hash by their string")`
back to a named Rust test, and several of upstream's named cases inside
files this group *does* cover are missing specific behaviour, not just a
name (see below). The same is true of the four `test/drive_*.rb` files. The
suite is additional work, done well, and it is not test parity as the skill
defines it — the skill's own worked example (planify-rb, 173 checks vs 34
upstream tests, 0/34) is exactly this shape, and Mousai-rb's port is the same
shape at a smaller scale.

**Correcting for shape does not change the gap to zero.** Even reading past
the naming requirement and asking only "is the *behaviour* this upstream
test pinned exercised by *any* port check, however named" — the generous
version of the question — a third of upstream's tests still have no answer:

## Concrete, verified-by-reading behaviour gaps (not just naming gaps)

### `src/recognizer/recordings.rs` — 9 tests, effectively 0 covered

Upstream pins: `load_from_db`, `insert`, `insert_items_changed`,
`peek_filtered`, `peek_filtered_items_changed`, `take_filtered`,
`take_filtered_items_changed`, `recording_notify_items_changed`, `is_empty`.

`grep -rn "Recordings\b" test/*.rb` finds exactly one place this model is
exercised: `test/drive_playback.rb`'s "a recording is saved, read back and
taken" / "the recording round-tripped through the database" (checks 21-22),
which loosely stands in for `load_from_db` + `insert` + `take_filtered`
combined into one integration check. `insert_items_changed`,
`peek_filtered`, `peek_filtered_items_changed`,
`recording_notify_items_changed` and `is_empty` — the
`Gio::ListModel`/notification-correctness half of this class, which is
exactly the kind of thing that silently breaks a `ListView` binding — have
**no port check at all**, named or otherwise. `lib/recordings.rb` is 127
lines of exactly this logic with zero direct test coverage.

### `src/recognizer/provider/aud_d/mod.rs` — 7 tests, 0 covered

Upstream pins seven distinct AudD HTTP-response shapes, each a real bug that
was presumably found once: `invalid_json`, `no_matches`,
`daily_limit_reached`, `wrong_api_token`,
`wrong_file_sent_or_audio_without_streams`, `proper_but_no_spotify_field`,
`proper`.

```sh
grep -rn "invalid_json\|no_matches\|daily_limit\|wrong_api_token\|wrong_file_sent\|proper_but_no_spotify" test/*.rb
# (no output)
```

`lib/aud_d_response.rb` (119 lines) and `lib/aud_d.rb` (198 lines) implement
this exact parsing/error-mapping logic in Ruby and have **zero** unit tests
exercising any of these seven response shapes. `test/drive_playback.rb` only
ever exercises the mock provider (`Mousai::AudDMock`), never
`lib/aud_d_response.rb`'s real parsing path. A regression in any of these
seven branches — e.g. a provider changing its "no match" JSON shape, or the
daily-limit error code — would ship silently.

### `src/album_art.rs` — 3 tests, 0 covered

Upstream pins `identity` (repeated `get_or_init` calls for the same URL
return the same cache entry), `download` and `concurrent_downloads` (two
simultaneous requests for the same URL share one download). `lib/album_art.rb`
(126 lines) implements the same cache/dedup logic. `grep -rn "album_art\|AlbumArt" test/*.rb`
finds exactly one hit, a fixture string (`album_art_link: "https://album.png"`)
used by an unrelated `Song` test — the caching/dedup behaviour itself is
untested.

### `src/window/song_bar.rs` — 1 test, 0 covered, despite being trivial to port

`test_format_clock_time_minute_sec` pins six exact edge cases (zero, under a
minute, 59:59, exactly 60 minutes, 100:20, and `ClockTime::MAX` →
`307445734∶33`). `lib/song_bar.rb:288` ports the function
(`self.format_clock_time_minute_sec`) faithfully, but
`grep -rn "format_clock_time" test/*.rb` returns nothing. This is pure,
dependency-free logic with no GTK involved — the easiest possible test to
have ported — and it has none.

### `src/recognizer/provider/settings.rs` — 2 tests, partially covered

One of upstream's two tests here overlaps with `test/test_models.rb`'s
`Settings` group (`defaults match the upstream schema`); the other —
upstream's assertion about how `ProviderSettings` resolves the *active*
provider's settings object given the legacy/migrated token field — is not
named or asserted anywhere; `test/drive_app_dialogs.rb` exercises the
inspector page's provider switch live (checks 9-10) but does not assert the
specific migration-resolution behaviour the second upstream test pins.

### `src/recognizer/recording.rs` / `provider/error.rs` — `serde_bincode`, loosely covered

Both are round-trip serialization tests. `test/drive_playback.rb` checks "its
bytes survived" / "its error survived" (checks 21-22) as part of the database
round-trip — this is a reasonable Ruby-shaped stand-in and the closest thing
in this report to an honest `ported` — but it exercises one specific
error/song value, not upstream's`fn serde_bincode` test's actual case
coverage (worth confirming by reading `src/recognizer/recording.rs:121` and
`src/recognizer/provider/error.rs:80` directly if this is picked up — not done
this pass).

### `src/window/history_view.rs` — 6 tests, loosely covered by integration, not by name

`test/drive_main_window.rb` drives search/no-results/selection/undo
end-to-end and that is good, real coverage of the *user-visible* behaviour.
But none of the six upstream unit tests are named or mapped; whether they
pin the same edge cases (e.g. a specific sort-tie-break or fuzzy-match
threshold) was not individually verified this pass.

### Covered reasonably well (by behaviour, if not by name)

`Uid`, `DateTime`, `Utils.consecutive_groups`, `I18n`'s variable-replacement
helpers, `ExternalLinks`, `Song`'s fuzzy matcher, `SongFilter`/`SongSorter`,
`Settings` defaults/validation, `Database`+`SongList`+`Migrations` all have
real, passing Ruby checks that exercise materially the same behaviour as
their upstream counterparts. These are not claimed as `ported` in the strict
bijection sense (no check is named after a specific upstream test), but they
are the honest, substantive part of this suite.

## `spec/` is empty and has never been run

```sh
find . -name '*_spec.rb'   # (no output)
```

`spec/README.md` and `spec/spec_helper.rb` are the unmodified
`kettle-jem`/`kettle-test` scaffold — harness wiring with **zero actual spec
files**. The dev shell's own banner names the command:

```
run the specs: ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```

Running it passes 0 examples, 0 failures — a suite that has never pinned a
single behaviour reads identically to a suite with perfect parity unless
someone runs it and counts. **Say it plainly: `spec/` is dead scaffolding,
not a second test suite, and it should not be cited anywhere as evidence of
coverage.**

## The runtime gate, re-run

This round's gate (`drive_ok=true`, 147 checks, 0 failed, 25 components) was
**re-executed, not read off a previous report**:

```
nix develop --command xvfb-run -a ruby test/test_models.rb      → 50 of 50 checks passed
nix develop --command xvfb-run -a ruby test/drive_i18n.rb        →  5 of  5 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_app_dialogs.rb → 18 of 18 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_main_window.rb → 21 of 21 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_playback.rb    → 53 of 53 checks passed, DRIVE OK
```

50 + 5 + 18 + 21 + 53 = **147**, matching the claimed gate exactly, and all
five runs genuinely passed (not merely "the harness reported drive_ok" —
the output of each run was read). **This is the one place this round's
claim checks out at face value.** But a passed drive run is a check that
the *wired-up* behaviour works, end to end, through the real widget tree —
it is not evidence of unit-level parity with upstream's test suite, and the
86-test gap above sits entirely underneath it, in logic the drive scripts
never individually isolate (recordings.rb's notification plumbing, the
seven AudD response shapes, album art dedup, the clock formatter). A green
147/147 and an 86-test gap are both true at once; neither report should be
read as softening the other.

## Bottom line

- **147/147 drive checks**: real, re-verified, true.
- **Test parity with upstream's 86 `#[test]`s**: **0/86** under the skill's
  strict bijection, and materially incomplete even under the generous
  "same behaviour, different name" reading — at minimum the 9 recordings
  tests, 7 AudD response tests, 3 album-art tests and the 1 clock-formatter
  test (20 of 86, 23%) have no port-side check of any kind, named or not.
- `spec/` contributes zero and has never been run; do not count it.
