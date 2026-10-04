# Doctrine matrix

Every safety rule ("doctrine") the hardening rounds established, against every
site that must honor it. This is the audit artifact from the systematic pass
of 2026-10-02 (after review round 4): the recurring bug shape across rounds
2-4 was a doctrine applied at k of n sites, so this table enumerates all n.
**Check any new sweep, election, or title/row write against every row here.**

Legend: OK = verified honoring the doctrine; FIXED = violation closed in the
audit pass; N/A- = deliberately out of scope (reason given).

## D1 — Liveness under BOTH roster keys
The roster is keyed by the row FOLDER, which stops matching the session id
after a row repair or an alien migration. Every liveness decision that can
mark, donate, repair, elect, or exempt must check both keys (or `is_liveish`,
whose launch-source scan covers the folder-keyed worker for transcripts).

| Site | Status |
|---|---|
| `sweep_dead_jobs` servability | OK (round 4) |
| `sweep_row_repair` candidacy | OK (rounds 2-3) |
| `sweep_name_rescue` row donors | OK (round 4) |
| Same-target election live tier | OK (round 2) |
| Twin-arm `job_alive`/live bonus | OK (iterates roster keys directly) |
| `is_liveish` (all transcript marking) | OK (round 2, launch-source scan) |
| Transcript husk arm (`[Stub]`) | FIXED — now also `is_liveish` |
| `sweeps_current` transcript exemption | FIXED — launch-source scan added |
| Final `[Dup]` row-marking loop | FIXED — see D6 |

## D2 — Junk-tail fallback
Any tail comparison must fall back to the last CONVERSATION uuid
(`last_real_uuid`) when the raw tail is junk/orphaned.

| Site | Status |
|---|---|
| Copy-dup containment (mutual/supersede) | OK |
| Copy-dup no-hit retry | OK |
| Divergence heal | OK |
| Carrier-redundancy check | OK (round 4) |
| Session-end supersede | OK |
| `find_parent` first-uuid probe | N/A- (first entry junk is atypical; a miss fails safe: no fork warning) |

## D3 — Elections rank only by unmutated inputs
Never by an mtime this tool's own writes can bump; an unmarked-beats-marked
tier keeps last run's verdict stable.

| Site | Status |
|---|---|
| Same-target row election | OK (round 2) |
| Sync winner election | OK (round 2) |
| Twin-shell keeper (roster startedAt) | OK (startedAt changes only on daemon respawn — genuine info) |
| Copy-dup cold keeper | OK (round 4: unmarked, mtime, path) |
| Rescue donor ordering | OK (J_MTIME not refreshed by markers; stub marks restore mtimes past the 60s guard) |
| Repair candidate/parent ordering | OK |

## D4 — Staleness token BEFORE the data read; guarded state.json writes
| Site | Status |
|---|---|
| `load_jobs` | OK (round 3) |
| `set_job_marker` cached + uncached | OK (round 4) |
| `repair_job_row` | OK |
| `fork-watch-end.sh` row write | OK (round 4) |

## D5 — Own-write recognition
Every custom title this tool can mint must later be recognized as
replaceable; a human name must never be. Mints: sync/rescue bases (recorded
in `fork-watch-name-sync/`), marker prefixes (skipped while marked), heal
re-appends (match the record or the human name correctly), the short-id
fallback (recognized by equality with the file's 8-char id).

| Mint | Status |
|---|---|
| Sync/rescue base writes | OK (recorded) |
| Marker appends | OK (marked-skip) |
| Heal re-appends | OK |
| `retitle` short-id fallback | OK (round 4, accepted in sync + rescue) |
| `rename_parent` titleless fallback | FIXED — was `[Old Fork] forked on <stamp>...`, healing to a human-looking phrase that blocked sync forever; now short id + standard suffix |
| End-hook titleless fallback | FIXED — was `[Old Fork] superseded by xxxx`, same trap; now short id |

## D6 — Live/streaming sessions are never (finally) marked
`[Dup?]` provisionals are the documented exception (not deletion-safe).

| Site | Status |
|---|---|
| All transcript marking | OK (`is_liveish`) |
| Dead sweep | OK (D1) |
| Final `[Dup]` row-marking loop | FIXED — two live twins of one parent left a live row deletion-safe-marked; live rows now never GAIN a final mark (an existing one keeps its verdict until the normal heals judge it) |
| End hook | OK (its own JUST-ENDED session; successor rules are D15's row) |
| Hook session's own transcript in copy-dups | FIXED (round 7) — `is_liveish` now treats `$tpath` as live by definition (the hook runs inside that session). Every title-writing sweep skips `$tpath` explicitly, but `sweep_copy_dups` keeps it as group evidence and could finally mark an own-file idle over 60s at session start. Hook-mode fixture in fwtest |
| `handle_fork` / `rename_parent` | DELIBERATE EXCEPTION (audited round 10) — fork detection renames the parent at fork time with no liveness check: the roster/uuid evidence says the NEW session carries the conversation forward, and the rename is exactly the warning the tool exists for. The parent may be live; its mark heals through the normal divergence heal if it moves on |

## D7 — mtime restore discipline
One implementation (`append_custom_title`): idle >60s restored, hot never
backdated. End hook restores its own just-ended file (intended: the
successor must win `--continue` recency). Consumers that must not trust
bumped mtimes are D3's problem and solved there.

## D8 — Skip gates must see every verdict-changing event
| Gate | Status |
|---|---|
| Rescue gate (pmax, roster, DIRTY) | OK (round 3) |
| Repair gate (+ settle/hour crossings) | OK (rounds 2-3) |
| Stamp at judgment time (NOW) | OK (round 3) |
| `sweeps_current` strictness | OK |
| Copy-dup group skip vs same-run title writes | FIXED — `DIRTY_T` voids the group skip for heals (the transcript sweep runs before the judgment). `sweep_copy_dups` runs BEFORE the name sweeps: round 5 showed the reverse order lets a landed name re-title a group member before judgment, splitting the group and silently losing the duplicate verdict. Order-guard fixtures + an order-swap mutation protect this. Round 6 killed the round-5 claim that sync/rescue renames need no re-judgment: a landed name can also JOIN its transcript into another same-title group holding the same conversation — a membership no pass had judged and no later run would see (the append restores idle mtimes, and the group skip yields only when a group MEMBER is written). When the name sweeps land anything, `sweep_copy_dups` runs a second time (`NAMES_LANDED`); safe where the round-5 reorder was not, because every verdict already landed and judgment is idempotent. Join-guard fixture + mutation |
| Transcripts-sweep content arm | OK (its own writes happen inside the same per-project pass, after the gate correctly) |
| Rescue/repair gates vs deletions and old-mtime move-ins | HARDENED (round 11, agent find) — their `pmax` was built from file mtimes, the jobs cache and the roster only: deleting a blocking row folder, or moving a parent transcript in with an old mtime (`mv`, `cp -p`), changed candidacy with nothing the gate could see — a DELAYED repair or donation, never a wrong write. Both gates now fold in the project directory mtimes and the jobs directory mtime, like the content gates. Delay-only direction, no dedicated fixture |
| Sibling DELETION | FIXED (round 10, agent find) — a deletion moves no surviving file's mtime, so the per-project content gate (`pmax < sm`) and the copy-dup group gate (`gmax < sm`) both skipped after the keeper or superseder of a marked copy was deleted: the deletion-safe mark sat on the ONLY remaining copy of the conversation until some unrelated write (reproduced). `sweeps_current` always saw the directory mtime, but the content gates never looked. Both gates now fold the project directory's mtime in — it moves on create, delete and rename. Pair-deletion (divergence heal) and trio-deletion (keeper re-election) fixtures |

## D9 — Sanitize untrusted numerics before use
Roster/jobs JSON values are untrusted; stat output is trusted.

| Input | Status |
|---|---|
| `startedAt` (4 consumers) | OK (rounds 2-4) |
| `startedAt` freshness (provisional window) | FIXED (round 8) — the window had no future bound, so a unit drift to µs/ns epoch read "fresh" on every run: `[Dup?]` re-landed forever instead of expiring within the 120s cap (reproduced). Now also requires `ts < NOW*1000 + 60s`; garbage fails safe to "not fresh" and existing marks expire |
| `pid` | FIXED — non-numeric pid (e.g. ".") passed the `/proc` directory test and read live forever (fail-safe direction, but wrong); now rejected |
| `procStart` | OK (string compare only) |
| Lone-surrogate `\udXXX` escapes (jq 1.6) | FIXED (round 8) — a well-formed JSON writer truncating display text mid-emoji emits one, and jq 1.6 rejects the whole file: the row silently dropped from the cache and every marker/heal/repair/end-hook write aborted forever; a roster escape loaded an EMPTY roster, voiding all live-session protection. Every jq read and write of daemon JSON now retries with surrogate escapes stripped (read side for the caches, write side so the rewrite lands; the daemon's own parser accepts the file either way). ACCEPTED LIMIT: the retry also strips valid surrogate PAIRS (emoji in names degrade, retry path only), and a literal `\udXXX` typed as text can defeat the retry — which then aborts exactly like before the fix |
| Integers > 2^53 (jq 1.6 rewrites) | OK, verified round 8 — jq 1.6 does corrupt them, but the largest real fields are ms timestamps (~1.8e12) and byte offsets (~1e7), five orders of magnitude below the threshold |
| Sweep stamp ahead of the clock | FIXED (round 9) — a clock step back (WSL resync after Windows sleep) leaves the stamp in the future: `NOW - sm < 30` stays true, every mtime reads "before the last sweep", `sweeps_current` and every content gate skip — no mark lands until real time catches up (reproduced with a +3h stamp). `sm > NOW` now fails safe to "never swept", same doctrine as the provisional future bound |
| Zero-byte roster | FIXED (round 11, agent find) — jq reads an empty file as empty output with exit 0, so a torn truncate-then-write roster loaded as EMPTY without tripping the round-10 fail-closed path: every worker read dead and a live idle fork shell took `[Dead]` (reproduced). A present-but-zero-byte roster now sets `ROSTER_BAD`; a MISSING roster stays fail-open on purpose (it legitimately means "no daemon"), and a legitimate empty roster is `{"workers":{}}`, never 0 bytes |
| Clock step back with no run in between | ACCEPTED LIMIT (round 11) — the `sm > NOW` guard works only while the stamp is still ahead; if the clock steps back and no run happens until real time passes the old stamp, files written in that window sit below `sm` and their content verdicts wait for the next write. Self-corrects on any write or any run inside the window; needs an hour-scale gap with no launch at all to matter |
| Roster unreadable beyond surrogates | FIXED (round 10, agent find) — when BOTH roster parse attempts fail (a torn daemon write, a format change; jq can also emit PARTIAL entries before erroring), the loader proceeded with an empty or partial roster: every worker read dead, live idle fork shells took `[Dead]` after 300s, and `repair_job_row` could repoint live rows — the lone-surrogate fix (round 8) covered only that one failure shape. An existing-but-unparseable roster now fails CLOSED: `ROSTER_BAD` skips every sweep and writes no stamp; hook-mode fork detection still runs (it degrades to the roster-free uuid heuristic). Truncated-roster fixture asserting abstention, then normal judgment after restore |

## D10 — Marker grammar symmetry
`parse_markers`, the end hook's `strip_markers`, `heal_if_marked`, and the
bare-token lists all cover the same 10 forms (5 markers x plain/arrow). The
dead sweep's heal list and the same-target skip list are deliberate subsets.
Round 10 (agent find): the transcript sweep's heal arm covered `[Stub] `
but not `[Dead] `/`[←Dead] ` — a real transcript whose seeded ai-title
inherited a `[Dead]`-marked row name read deletion-safe forever (the dead
verdict is row-only and no sweep ever judges it on a title). Both forms now
heal in the same arm. Round 10 (self-review): the end hook recognized the
arrow tag by a loose `"[←"*` prefix — a USER name that merely begins with
the arrow text got tagged; it now matches the exact five arrow markers,
same as `parse_markers`. Status: OK everywhere.

## D11 — Strip only the exact minted forked-on suffix
`$forksuf` (`- forked on HH:MM dd.mm.yyyy by xxxx`) at all three strip sites
(retitle heal, rename_parent, copy-dup group key). Round 10 (agent find):
the pattern ended in `by *`, so a user name that merely STARTS with the
minted shape ("... by abcd (final)") lost its whole tail on a heal —
tightened to `by ????`, exactly the four short-id characters the mint
writes. Near-miss fixture; the exact-shape strip stays covered by staletest.

## D12 — Path safety
All file-list pipes newline-delimited (round 3). ACCEPTED LIMIT: `grep -H`
output parsing (`${line%%:*}`) and the awk-built JSON in `scan_files` assume
the path up to `~/.claude` contains no colon, double quote, or backslash —
true for any sane `$HOME`; breaking it breaks far more than this tool.

## D13 — Fail-safe writes
tmp+rename or abort everywhere; `append_custom_title` refuses to recreate a
deleted file (round 3); heals are best-effort by design. Round 9: the tmp
file was minted under the shell's umask, silently loosening a 0600 daemon
row to 0644 on its first rewrite (reproduced) — all three `state.json`
writers (`set_job_marker`, `repair_job_row`, the end hook) now copy the
original file's mode onto the tmp before the rename. ACCEPTED LIMIT: the
`fork-watch-name-sync/` records are created under the umask (they hold only
display names).

## D14 — Repair constraints
User-named only; dead under both keys; 300s settle; unmarked parent silent
>=1h; never when another servable row reaches the parent; fill-only rescue;
never mint rows. OK (rounds 2-3, fixtures in fwtest).

## D15 — One unmarked keeper per conversation
Duplicate judgment must always leave at least one unmarked, servable copy of
a conversation: a final marker means "safe to delete", so a set where every
copy is marked invites deleting the conversation outright.

| Site | Status |
|---|---|
| Copy-dup twin arm | OK (keeper election; supersede chains leave the head unmarked by construction) |
| Twin-shell / same-target elections | OK (keeper election) |
| End hook successor check | FIXED (round 7) — holding the ended session's first and last uuid was accepted as a successor, so an identical twin qualified: the ending twin got `[Old Fork]` next to the sweep's `[Dup]` on the other (or `[Old Fork]` on both when twins end back to back), every copy deletion-safe, and no later sweep healed it (restored mtimes keep the group skipped). A successor must now be strictly AHEAD: its last CONVERSATION uuid (junk-tail doctrine, D2) must not exist in the ending file. Twin and junk-ahead-twin fixtures in endtest |
| Row verdicts must be BACKED by title verdicts (write order) | FIXED (round 11, agent find) — `handle_fork` marked the row before attempting the parent rename, and the end hook wrote the row before the title: a failed title append (read-only transcript, torn file) left a row-only `[Old Fork]` that no heal revisits (the heals judge TITLES). Both now write the title verdict first and the row only on success, the copy sweep's order; the end hook's row write moved into `mark_row`, called after the title landed or already stood. Read-only fixtures in fwtest (hook mode) and endtest |
| Row-level `[Dup]` outliving its title verdict | FIXED (round 9, self-review) — the copy sweep marks title and row together, but the pair comes apart with no race at all: an in-session /rename cleans the title while the row keeps `[Dup] ` (a heal whose row half aborts on a daemon rewrite leaves the same shape). The renamed title forms a single-member group the copy sweep never judges, and every other healer declined materialized rows — a deletion-safe mark sat forever on a session the user had just claimed. The dup sweep's heal arm now heals a `[Dup] `/`[←Dup] ` row whose real transcript's effective title carries no marker. Deliberately scoped: `[Dup?] ` stays with provisional expiry (healing it there would undo a same-run provisional mark — that sweep runs first), and `[Dead] `/`[Stub] ` stay with their owning sweeps. Round 10 (self-review): the arm judged only the FIRST uuid-bearing glob match — a session recorded in a second project directory could have its marked copy hidden behind an unmarked first match; every copy is judged now, and one marked copy keeps the row's verdict. Stranded-row + standing-verdict + second-project fixtures |
| Row-level `[Old Fork]` outliving its title verdict | FIXED (round 12, agent find) — the round-9 scoping above originally kept `[Old Fork] ` rows with "their owning sweeps", but those sweeps judge TITLES: once the title verdict was gone (an in-session /rename after divergence, or a title heal whose row half aborted on the daemon-rewrite guard), NO sweep ever revisited the row — an actively used, diverged session sat deletion-safe in the agents view (agent reproduced both paths). Since round 11 every row `[Old Fork]` is written title-first, so an unmarked effective title proves the verdict expired: the same heal arm now covers `[Old Fork] `/`[←Old Fork] ` rows, judging every copy, one marked copy keeping the verdict. At-rest rows (no real transcript) stay with the dead sweep. Heal + standing fixtures |
| Marked copies holding only each other (divergence heals) | FIXED (round 12, agent find) — the divergence heal accepted ANY sibling holding the tail as proof the conversation lives on, including a sibling itself deletion-safe-marked: two identical copies in DIFFERENT title groups (an end-hook `[Old Fork]` next to a renamed `[Old Fork]` copy) whose unmarked keeper was deleted held each other marked forever — no unmarked copy of the conversation left, and the copy sweep cannot re-elect across titles (agent reproduced; fuzz hit the `[Dup]`+`[Old Fork]` variant too). Only an UNMARKED holder (or the hook session's own live file) now counts in both batched passes. Convergent: healing both frees the copy sweep's next judgment wherever a same-title group remains. All-marked-pair fixture + unmarked-holder standing fixture |
| Transcript verdicts on alien rows | FIXED (round 12, agent find) — `set_job_marker` and the end hook's row write key the row by the id's first 8 characters without checking WHOSE row it is: after a row repair or an alien migration the folder no longer matches the row's `sessionId`, so a verdict judged on the folder's OLD transcript landed on a row — possibly live — serving another session (agent reproduced in sweep and hook mode; `handle_fork` has no liveness check by design, D6). Both row writers now refuse a non-empty mark when the row's `sessionId` is non-empty and names a different session; heals and 8-char row-own verdicts (dead/dup/provisional sweeps judging THE row) stay unrestricted. Fixtures in fwtest and endtest |

## D16 — Single-line records, reader parity, and damaged inputs
The US-joined cache loaders and the live fallback readers must agree, a
loader record must never span lines, and a damaged input (torn tail,
unreadable file, stray non-session file) must fail toward no-mark or heal.

| Site | Status |
|---|---|
| Multi-line names shear US-joined records | FIXED (round 9) — `jq -r` emits a raw newline for a `\n` escape inside a value: the record split mid-name, `J_SID`/`J_NSRC` loaded empty, and the row sat silently exempt from every sweep (the name's second half minted a bogus cache key). All three loaders (roster, jobs, title scan) now flatten newline, CR and the US separator itself to spaces before joining (two gsubs: jq 1.6's regex engine reads `\u001f` inside a character class as the literal characters u/0/1/f, so the separator is matched as a lone literal). A marker write writes the flattened name back — accepted: control characters in display names have no legitimate meaning |
| Empty custom-title: cache vs live | FIXED (round 9) — the live reader treats a `customTitle:""` entry as "revert to the automatic title" (the empty line falls through to the ai-title), but the cache stored `""` AND masked the ai-title: the file read as untitled, so an unservable husk never took its `[Stub] ` and retitle/sync refused it. The cache now tracks the last ai-title and reverts on an empty custom-title, mirroring the live fallback |
| Unreadable transcript (permission damage) | FIXED (round 11, agent + self-review independently) — `chmod` moves ctime only, so no mtime gate ever revisits it, and every scanner read an existing-but-unreadable transcript as MISSING: the row took a deletion-safe `[Dead]` (reproduced). `has_uuids` now gives an existing-but-unreadable file the benefit of the doubt (counts as real); every consumer fails toward no-mark or heal in that direction. An unreadable `state.json` was already safe (row drops from the cache, nothing marked) |
| Non-session files next to transcripts | FIXED (round 11, agent nit; WIDENED round 12, agent find) — a manual `<sid>-copy.jsonl` backup judged a cold twin resolved to the REAL session's row via its first 8 characters and marked it `[Dup]`. Round 11: `set_job_marker` refuses any id with characters outside `[0-9a-f-]`, and the four short-id globs are tightened to the exact 8-4-4-4-12 shape. Round 12: that only kept strays off ROWS — as a copy-dup group member a newer backup still WON the keeper election by mtime (the real transcript and its row took `[Dup]`, reproduced by the agent), and an edited one could even read as "ahead" and supersede. Only session-shaped file names (`session_shaped`) join groups at all now; the charset guard stays as depth |
| Unreadable project DIRECTORY | FIXED (round 12, self-review) — the round-11 unreadable-file doctrine one level up: a project directory without read+search permission hides every transcript in it from the globs, and absence-of-a-transcript is load-bearing (dead sweep, at-rest dup arms, repair candidacy, rescue donors) — a user-named live row took a deletion-safe `[Dead]` while its conversation sat on disk (reproduced), and chmod moves no mtime, so only the next full sweep after restore would heal it (plus the 300s settle on the tool's own marker write). Fails CLOSED like the corrupt roster: any existing-but-untraversable project directory (or the projects root itself) skips every sweep and writes no stamp; hook-mode fork detection still runs and fails toward "no warning". Dark-directory fixture asserting abstention, no stamp, and normal judgment after restore |
| Leaked `state.json.tmp.$$` after a kill | ACCEPTED LIMIT (round 11) — a kill between the tmp write and the rename leaves the tmp file forever (possibly 0644 when the kill lands before the mode copy). Harmless: every loader glob anchors to `*/state.json` or `*.jsonl`, and nothing lists the folders |
| `grep -m1 -o` multi-match uuid extraction | HARDENED (round 9, defensive) — `-m1` caps matching LINES, not matches: a line carrying a second `"uuid":"` key would poison the variable with an embedded newline, and a multi-line grep pattern then matches as several independent patterns. No real transcript line produces one (verified against live stores); `head -1` added at all five extraction sites anyway |
| Title line MISSING its field (null) | FIXED (round 10, agent find) — the cache's `(.customTitle // .aiTitle // "")` turned a custom-title line with no `customTitle` into `""`, i.e. a revert that erased a real earlier custom title from the cache, while the live readers' `// empty` drop such a line entirely. The scan jq now selects only lines whose own field is present: null is ignored everywhere, only a PRESENT empty string means revert |
| Torn tails: reverse reads | FIXED (round 11, agent find, must-fix) — `tac` on a file whose last line lacks a newline GLUES that line onto the previous one, and the glued record is invalid JSON: `last_real_uuid` silently lost the newest one or two conversation entries, so a crash-torn, genuinely diverged file read as MUTUAL with a shorter sibling and took the `[Dup]` as the older "twin" (reproduced) — a deletion-safe mark on the only copy of the newest messages. All six reverse-read sites in both hooks now go through `tacsafe` (`sed '$a\'` guarantees the final newline before reversing). Round 12 (self-review): the unconditional sed pipe forced `tac` to buffer the whole file, costing the reverse readers their stream-from-the-end property (0.07s vs 0.03s measured on a 12MB transcript) — `tacsafe` now checks the last byte first and pays the pipe only for an actually-torn file. End-hook direction note: a glued read on the ENDING file fails toward a missed mark (containment tolerates early reads), but a torn SUCCESSOR misread its conversation tail as an early uuid and judged the pair twins — the supersede was missed; torn-successor fixture added |
| Torn tails: title appends | FIXED (round 11, agent + self-review independently) — `>>` onto an unterminated final line glues the new title onto it: the previously-valid entry is corrupted for every line-based reader, and the title itself becomes invisible to the scan cache (`fromjson?` drops the glued line) while the row half of the verdict lands — a mark that can never heal. Both appenders (`append_custom_title`, the end hook) now terminate the file first when its last byte is not a newline |
| Multi-line TITLES: live readers vs cache | FIXED (round 10, agent find) — the cache flattens a title holding a raw newline to spaces, but the live readers (`file_title`, `ai_title_of`, the end hook's) ended in `tail -1` and read only its LAST line: two different names for one file, and the end hook minted `[Old Fork] <second half>`. All live title readers now flatten newline/CR/US exactly like the cache. ACCEPTED LIMIT: the cache's awk drops title lines over 4096 bytes (they are message-line noise in practice); the live readers keep no such cap |
