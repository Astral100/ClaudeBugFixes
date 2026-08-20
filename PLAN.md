# Plan

## Current state

- Both hooks, the `--sweep-only` mode and the `claude()` wrapper are implemented and in daily use.
- Marker semantics are final: mutually exclusive, replace-don't-stack, self-healing; marker == safe to delete; live sessions never marked.
- Provisional `[Dup?] ` marks land ~0.3s after a fork mint (roster info alone, job-row name only, before the settle wait); the same run's content sweeps upgrade or heal them, stragglers expire on the next full sweep, and a real verdict is never downgraded. NOT deletion-safe by design.
- A `←` inside a job-row marker best-guesses a left-press/backgrounding mint (parent was live around the mint: roster entry, or transcript written within 5 min before); it survives marker upgrades and drops on heal. Known limit: a fork minted at mint-time is indistinguishable from a fork the user then uses — divergence healing stays the truth-teller.
- Performance is settled: one-pass caches, US-separator loaders, sweep stamp, per-group containment matrix, end-anchored junk-tail reads, and skip-unchanged-since-last-sweep for content-driven verdicts — a steady-state sweep on a ~100MB tree runs well under a second (~10ms when the stamp is fresh).
- Write races are guarded: `%.Y` staleness check before every `state.json` write, in both hooks.
- Bare marker tokens inherited into ai-titles are neutralized to the short session id.
- In-flight writes are settled by per-file 100ms polling (3s cap); a file changing on 5 polls is declared streaming immediately, so an active session never stalls the sweep.
- Duplicate verdicts, marker healing and the session-end supersede check judge by the last conversation uuid whenever the raw tail is locally-minted junk (attachments, system-reminder-only entries, "No response requested." fillers).
- Tests pass: `tests/fwtest.sh` (43 want-assertions plus 2 stability passes, idempotent second run, aged-stamp skip stability, stamp skip/heal, corrupt-registry fallback, streaming protection, junk-tail twins and supersedes, provisional apply/upgrade/heal/expiry/no-downgrade) and `tests/staletest.sh` (stale-cache write race).

## Next

- Comment upstream: one-line fork repro on #82489 (resume, press left-arrow, duplicate appears; daemon death before a prompt leaves a title-only stub), cross-referencing #85404 for the stub regression on v2.1.235.
- Re-verify roster/jobs file shapes after each Claude Code upgrade; the daemon formats are undocumented.
