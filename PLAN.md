# Plan

## Current state

- Both hooks, the `--sweep-only` mode and the `claude()` wrapper are implemented and in daily use.
- Marker semantics are final: mutually exclusive, replace-don't-stack, self-healing; marker == safe to delete; live sessions never marked.
- Performance is settled: one-pass caches, US-separator loaders, sweep stamp, ~0.6s per sweep (~10ms when the stamp is fresh).
- Write races are guarded: `%.Y` staleness check before every `state.json` write, in both hooks.
- Bare marker tokens inherited into ai-titles are neutralized to the short session id.
- Tests pass: `tests/fwtest.sh` (22 assertions, idempotent second run, stamp skip/heal, corrupt-registry fallback) and `tests/staletest.sh` (stale-cache write race).

## Next

- Comment on upstream #85404: title-only stubs reappeared on v2.1.235 after the issue was closed as completed.
- Re-verify roster/jobs file shapes after each Claude Code upgrade; the daemon formats are undocumented.
