# Mousai — accountability ensurance

Ran `bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh`
against `lib/`, `exe/`, `.reports/`, and the repo root (minus `lib`/`exe`,
already covered), and grepped directly for `TODO`, `FIXME`,
`not implemented`, `for now`, `in a future`. `PORTING.md` does not exist on
this branch, so it was not grepped (nothing to grep).

## Phrase-pattern scan results — each one checked against upstream, not taken at face value

| Hit | Location | Verdict |
|---|---|---|
| `not ported` | `lib/i18n.rb:9` | **Not an excuse — the one honest disclosure in the codebase.** The comment states plainly that `po/` is not ported and that `gettext`/`ngettext` are a passthrough. This is the correct behaviour under this skill's own rule: the gap is named, not hidden, and `.reports/translation-parity.md` scores it as a full gap rather than crediting the 113 marked call sites as progress. |
| `deliberately left out` | `lib/recording.rb:13` | **False positive, verified against upstream.** Describes `recognize_retries` being excluded from the serialised form "so a recording can be retried again next session." Upstream's `src/recognizer/recording.rs:28-29` has the identical design: `#[serde(skip)] // So we can retry next session`. The port is quoting upstream's own stated design, not inventing an excuse for missing work. |
| `not required` | `lib/recording.rb:80`, `lib/aud_d.rb:187` | **False positive.** Both are about the `base64` gem no longer being a Ruby default gem, so the port uses `[bytes].pack("m0")` (strict base64, byte-identical output to `glib::base64_encode`) instead of `require "base64"`. This is a Ruby-runtime implementation detail with no behavioural difference, not a dropped feature. |

No hits were found for `deliberately|intentionally (omitted|dropped|simplified)`,
`n/a`/`not applicable`, `no ruby analogue`, `out of scope`, `(not|isn't) needed`,
or `by design` anywhere in `lib/`, `exe/`, or `.reports/` other than the one
already-disclosed `n/a` false positive inside `.reports/component-inventory.md`
(an old survey's own prose, not a code excuse).

## Direct grep for TODO / FIXME / "not implemented" / "for now" / "in a future"

```
grep -rn "TODO\|FIXME\|not implemented\|for now\|in a future" lib/ exe/ .reports/
```

No matches in `lib/` or `exe/`. `.reports/component-inventory.md` uses "for
now" nowhere; it was clean. No new occurrences were introduced by this
pass's own reports in a way that excuses rather than discloses — see below.

## Checking this audit's own reports for a false green

The instructions are explicit that a false green in a report is the most
serious finding this pass can make, so the other four reports produced in
this same pass were re-read with that question specifically in mind:

- `component-identification.md` / `component-parity.md`: name two concrete,
  located gaps (`song-page.copy-song` action not installed; `msgctxt`
  support missing from `I18n`) rather than treating "mostly matches" as
  done. Neither is buried in a footnote.
- `test-parity.md` explicitly separates "the runtime gate is real" (verified
  by actually re-running all four suites, not by reading the claim) from
  "every upstream test is ported" (false — three files' worth of test logic
  has no port-side test at all). It calls out the empty `spec/` directory as
  a suite that has never been executed, per this round's explicit
  instruction to say so plainly rather than let `rake spec`'s silent 0/0
  pass read as a signal.
- `translation-parity.md` scores the project at the true total (0/132,
  0/48), not at "113 call sites marked" — which is the exact inflation this
  skill exists to catch — and separately flags the `msgctxt` defect that
  would otherwise resurface as a second, hidden gap right after the first
  one is fixed.

## Bottom line

One genuine, already-disclosed gap exists in the codebase (`lib/i18n.rb`'s
passthrough), and it is reported as a gap, not excused. The other three
phrase hits were checked against upstream source directly and are not
excuses — they describe the same behaviour upstream has, or a
Ruby-runtime-only implementation detail with no behavioural change. No
`TODO`/`FIXME`/"not implemented" markers exist anywhere in `lib/` or `exe/`.
No false-green claim was found in any of the four other reports this pass
produced.
