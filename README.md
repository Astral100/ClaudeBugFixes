# ClaudeBugFixes

Client-side tooling that works around Claude Code's duplicate/ghost session bugs (observed on v2.1.235, WSL). Backgrounding, resuming or clearing a session forks it under a new session id, leaving duplicate rows, title-only stub files and un-enterable ghost rows in the agents view and the resume picker. These scripts mark every deletion-safe row so cleanup becomes a glance instead of an investigation.

## Background: where duplicates come from

Session storage (v2.1.235):

- Transcript: `~/.claude/projects/<project>/<session-id>.jsonl` — a fork copies the FULL conversation (all message uuids) into a new file; the per-session `subagents/` folder is NOT copied.
- Jobs registry: `~/.claude/jobs/<first-8-of-session-id>/state.json` — the agents view reads names from here; deleting a transcript does not remove the row.
- Daemon roster: `~/.claude/daemon/roster.json` — live attachable worker processes; cleared on daemon restart.

The three causes of duplicate/ghost rows:

1. Backgrounding or resuming (picker, agents view, parallel window) mints a NEW session id — the same conversation appears as two or more rows, and the original stays under the old id.
2. Title-only stub `.jsonl` files: a shell that never processed a prompt inherits its parent's title — a same-named duplicate row. A dying job can resurrect a deleted filename as such a stub at shutdown.
3. A jobs row with no transcript and a dead worker — an un-enterable "no saved transcript" ghost in the agents view.

## What it does

Two hooks plus a shell wrapper. Append/rename only — nothing is ever deleted, wrong marks self-heal on a later run. **A marker means "safe to delete"**; a working non-duplicate session is never marked.

| Marker | Meaning |
|---|---|
| `[Old Fork] ` | Transcript superseded by a copy holding the same conversation. Heals when the session diverges past the fork. |
| `[Dup] ` | Redundant duplicate: an at-rest twin fork of the same parent, a fork shell whose parent conversation another row already carries, or the cold copy of identical same-title twins. Twin-vs-superseded is judged on conversation entries only — junk that Claude Code also gives uuids to (attachments, system-reminder-only user entries, "No response requested." fillers) never turns a twin into an `[Old Fork] `. |
| `[Dead] ` | Job row that can never produce a conversation again: no real transcript and no live or respawnable worker. |
| `[Stub] ` | Transcript with a title but zero messages whose session is unservable — it would open empty. |

On every fork the SessionStart hook also emits a `systemMessage` naming the parent, and renames the parent to `[Old Fork] <title> - forked on <time> by <id>`.

## Files

- `fork-watch.sh` — SessionStart hook; also runs standalone as `fork-watch.sh --sweep-only`. Fork detection plus four marker sweeps over the jobs registry (`~/.claude/jobs/*/state.json`), all project transcripts and the daemon roster.
- `fork-watch-end.sh` — SessionEnd hook; marks a session `[Old Fork] ` when its whole conversation lives on in another transcript.
- `install.sh` — symlinks both hooks into `~/.claude/scripts` and prints the `settings.json` and `.bashrc` blocks to add.
- `tests/fwtest.sh` — fixture test: builds a fake `~/.claude` tree and asserts every marker, heal and stability behaviour (idempotent second run).
- `tests/staletest.sh` — unit test for the write-race guard in `set_job_marker`; run `fwtest.sh` first (it builds the fixture tree).

## Install

```
./install.sh
```

Then add the two printed blocks (hook registration in `~/.claude/settings.json`, `claude()` wrapper in `~/.bashrc`). The wrapper matters: the agents view and the resume picker read names **once at open**, so the sweep must run synchronously before launch — a hook started in parallel loses that race.

## Design notes

- Everything loads once per run into bash caches (one jq for the roster, one jq+stat for all job files, one grep/awk/jq pipeline for all titles) — per-file spawns cost ~10s on WSL before this. Current costs on a ~100MB tree: ~40ms when nothing changed since the stamp, ~0.5-0.8s when something flushed, ~2s only when the stamp is missing entirely (first install).
- Content-driven verdicts (copy-dup groups, divergence heals) are skipped for anything not written since the last completed sweep — those verdicts depend only on file contents the previous sweep already judged. Time- and roster-driven checks still run every sweep. On a ~100MB tree this cuts a steady-state sweep to well under a second.
- Same-title groups are judged via a containment matrix: one `grep -oF -f` per file with every sibling tail uuid as a pattern, instead of n² pairwise greps. Divergence heals batch the same way — one grep per project with every marked tail as a pattern, instead of one full-directory grep per marked file.
- The junk-tail fallback reads from the file's end (`tac | jq --unbuffered | head -1`), so its cost is the junk-tail length, not the file size.
- Loader field separators are US `0x1f` (`jq --arg us $'\x1f'`), not tabs — tab is IFS whitespace, so empty fields would collapse and shift columns.
- A sweep stamp under 30s old skips the sweeps — but only when nothing was written since the stamp (one cheap stat pass over project dirs, transcripts, jobs and the roster). A flush or rename after the stamp voids the skip, so marks still land on the very first open after a write ends; live sessions' own writes are exempt from voiding it, since a live row is never marked. Same-second writes count as newer (mtimes are whole seconds), at worst costing one redundant sweep.
- `state.json` writes abort when the file's `%.Y` mtime changed mid-flight, so a concurrent daemon rename is never clobbered.
- Transcript title appends restore the file's mtime when it was idle, because `claude --continue` resumes by recency; hot files are never backdated.
- Live sessions are never marked, and there is no recency window: a file written in the last 5s is polled every 100ms and judged once settled — daemon flushes are sub-second bursts triggered by the same keypress that starts the sweep, so waiting them out lets marks land on the first open without ever reading a half-written file. Each file settles on its own: quiet for 3 consecutive polls is settled and re-scanned; changed on 5 polls is a genuinely streaming session, skipped for that run immediately so one active session never stalls the sweep to the 3s cap.
- Claude Code seeds a forked session's ai-title from the parent's displayed name, so marker text can leak into a new session's title; a base that is only a bare marker token is replaced with the short session id.
- Whenever a file's raw tail uuid matches no sibling — always the case when the tail is junk minted in that file alone — duplicate verdicts, marker healing and the session-end supersede check all fall back to the last conversation uuid, so junk can neither hide a duplicate nor cause heal/re-mark churn.

## Cleanup recipe

The scripts only mark; deletion stays manual. Removing a row for good needs BOTH the transcript file and the `~/.claude/jobs/<first8>/` dir gone (or Ctrl+X twice in the agents view). A row with a live roster worker survives until the daemon restarts. The resume picker lists transcript files by recency — a leftover file keeps its row regardless of the registry.

## Related upstream issues (anthropics/claude-code)

- Fork on background/resume: #82489, #86092, #76493, #85004, #78264, #72012
- Title-only stubs: #85404 (closed as completed; stubs on v2.1.235 look like a regression), #77898, #85875, #82969
- Ghost "no saved transcript" rows: #81662, #79757
