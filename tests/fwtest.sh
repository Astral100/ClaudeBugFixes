#!/bin/bash
# Fixture test for the refactored fork-watch sweeps (cache-based, --sweep-only).
# Every want-line is a real assertion: the suite counts failures and exits 1
# on any mismatch, so a crashed or no-op sweep can no longer pass by printing
# empty actuals next to the wants.
: "${TMPDIR:=/tmp}"
T="$TMPDIR/fwtest-root"
rm -rf "$T"
mkdir -p "$T/.claude/projects/proj1" "$T/.claude/daemon"
sed "s|\$HOME|$T|g" "$(dirname "$0")/../fork-watch.sh" > "$T/fw.sh"
# Deterministic umask for the permission assertions: a row rewrite's tmp file
# is minted 0644 under it unless the sweep copies the row's own mode.
umask 022

P="$T/.claude/projects/proj1"
old() { touch -m -d '2 hours ago' "$1"; }
uu() { printf '%s' "$1$1$1$1$1$1$1$1-$1$1$1$1-$1$1$1$1-$1$1$1$1-$1$1$1$1$1$1$1$1$1$1$1$1"; }

fails=0
chk() { # $1 = label, $2 = want, $3 = got
  if [ "$3" = "$2" ]; then
    printf 'ok   %s: %s\n' "$1" "$3"
  else
    printf 'FAIL %s: want "%s" got "%s"\n' "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}

# This shell's own pid and /proc starttime stand in for a live worker: a
# roster entry carrying them passes pid_matches_start, one carrying a wrong
# starttime models a recycled pid. comm is "bash" (no spaces), so field 22
# of /proc/self/stat is the starttime.
MYSTART=$(awk '{print $22}' "/proc/$$/stat")
# A nanosecond-epoch startedAt models a daemon unit drift (roster timestamps
# are milliseconds today); the provisional sweep must read it as NOT fresh.
DRIFTNS=$(( $(date +%s) * 1000000000 ))

# --- parents for at-rest fork shells (roster launch sources) ---
PA="$P/aa11aa11-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Global"}\n{"uuid":"%s","type":"user"}\n' "$(uu 1)" > "$PA"; old "$PA"
PB="$P/bb22bb22-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Solo"}\n{"uuid":"%s","type":"user"}\n' "$(uu 2)" > "$PB"; old "$PB"
PC="$P/cc33cc33-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SeamParent"}\n{"uuid":"%s","type":"user"}\n' "$(uu 3)" > "$PC"; old "$PC"

# --- carrier job with a real transcript holding parentC's conversation ---
CAR="$P/aaaa0000-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Carrier"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$(uu 3)" "$(uu 4)" > "$CAR"; old "$CAR"

# --- superseded copy pair (same title, tail containment) ---
F1="$P/dddd0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Copy"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$(uu 5)" "$(uu 6)" > "$F1"; old "$F1"
F2="$P/dddd0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Copy"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$(uu 5)" "$(uu 6)" "$(uu 7)" > "$F2"; old "$F2"

# --- mutual twins (identical, cold, t2 newer keeps) ---
T1="$P/eeee0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Twin"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$(uu 8)" "$(uu 9)" > "$T1"; touch -m -d '3 hours ago' "$T1"
T2="$P/eeee0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Twin"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$(uu 8)" "$(uu 9)" > "$T2"; touch -m -d '2 hours ago' "$T2"

# --- keeper-heal: the LIVE twin carries a stale [Dup] from an earlier run
# --- (cold elections are verdict-stable now, so liveness is what forces the
# --- heal; e6da0002 gets a live roster entry below) ---
G1="$P/e6da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Twin2"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$(uu c)" "$(uu d)" > "$G1"; touch -m -d '3 hours ago' "$G1"
G2="$P/e6da0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Twin2"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n{"type":"custom-title","customTitle":"[Dup] Twin2","sessionId":"x"}\n' "$(uu c)" "$(uu d)" > "$G2"; touch -m -d '2 hours ago' "$G2"

# --- stub husk (title only, unservable) ---
ST="$P/ffff0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Stubby"}\n' > "$ST"; old "$ST"

# --- heals: wrong [Stub] on a real transcript; diverged [Old Fork] ---
HR="$P/abab0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Real"}\n{"uuid":"%s","type":"user"}\n{"type":"custom-title","customTitle":"[Stub] Real","sessionId":"x"}\n' "$(uu a)" > "$HR"; old "$HR"
HD="$P/abab0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Div"}\n{"uuid":"%s","type":"user"}\n{"type":"custom-title","customTitle":"[Old Fork] Div","sessionId":"x"}\n' "$(uu b)" > "$HD"; old "$HD"

# --- bare marker tokens as the whole title (inherited marker text) ---
BT1="$P/addd0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"[Dead]"}\n{"uuid":"%s","type":"user"}\n' "$(uu e)" > "$BT1"; old "$BT1"
BT2="$P/beef0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"[Dup]"}\n' > "$BT2"; old "$BT2"

# --- fresh superseded copy: written moments before the sweep, must settle and
# --- be marked on the FIRST pass (no recency skip) ---
CU1="0f0f0f0f-0f0f-0f0f-0f0f-0f0f0f0f0f0f"
CU2="f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0"
F3="$P/cafe0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"CopyC"}\n{"uuid":"%s","type":"user"}\n' "$CU1" > "$F3"
F4="$P/cafe0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"CopyC"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$CU1" "$CU2" > "$F4"; old "$F4"

# --- noisy superset: extra entries are junk only (reminder + filler), so the
# --- CONVERSATIONS are identical -> twins ([Dup] on the older), not [Old Fork]
NU1="d1d1d1d1-d1d1-d1d1-d1d1-d1d1d1d1d1d1"
NU2="1d1d1d1d-1d1d-1d1d-1d1d-1d1d1d1d1d1d"
NJ1="dd00dd00-dd00-dd00-dd00-dd00dd00dd00"
NJ2="00dd00dd-00dd-00dd-00dd-00dd00dd00dd"
NF1="$P/dada0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"NoisyT"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"hello"}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"hi"}]}}\n' "$NU1" "$NU2" > "$NF1"; old "$NF1"
NF2="$P/dada0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"NoisyT"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"hello"}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"hi"}]}}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"<system-reminder> The user named this session X"}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"No response requested."}]}}\n' "$NU1" "$NU2" "$NJ1" "$NJ2" > "$NF2"; touch -m -d '1 hour ago' "$NF2"

# --- reversed noisy pair: the junk superset is the OLDER twin, so IT gets the
# --- [Dup]; its raw tail is orphaned junk, so healing must judge by the
# --- conversation tail or every sweep would heal + re-mark it (churn)
RU1="b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2"
RU2="2b2b2b2b-2b2b-2b2b-2b2b-2b2b2b2b2b2b"
RJ1="cbcb00cb-cbcb-cbcb-cbcb-cbcb00cbcbcb"
RN1="$P/dadb0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"NoisyR"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"hey"}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"yo"}]}}\n' "$RU1" "$RU2" > "$RN1"; touch -m -d '1 hour ago' "$RN1"
RN2="$P/dadb0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"NoisyR"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"hey"}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"yo"}]}}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"<system-reminder> The user renamed this session"}}\n' "$RU1" "$RU2" "$RJ1" > "$RN2"; old "$RN2"

# --- gap trio: base + junk superset + genuinely diverged sibling; BOTH stale
# --- copies get [Old Fork], the junk superset must not slip through as an
# --- unmarked sole twin
GU1="c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3"
GU2="3c3c3c3c-3c3c-3c3c-3c3c-3c3c3c3c3c3c"
GJ1="dcdc00dc-dcdc-dcdc-dcdc-dcdc00dcdcdc"
GU3="3d3d3d3d-3d3d-3d3d-3d3d-3d3d3d3d3d3d"
GF="$P/eafe0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GapT"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n' "$GU1" "$GU2" > "$GF"; touch -m -d '3 hours ago' "$GF"
GG="$P/eafe0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GapT"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"No response requested."}]}}\n' "$GU1" "$GU2" "$GJ1" > "$GG"; old "$GG"
GH="$P/eafe0003-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GapT"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"%s","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"more"}}\n' "$GU1" "$GU2" "$GU3" > "$GH"; touch -m -d '1 hour ago' "$GH"

# --- name sync: a user-named row whose transcript kept only the ai-title ---
NSY="$P/abba0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoName"}\n{"uuid":"abcf0001-abcf-abcf-abcf-abcfabcfabcf","type":"user"}\n' > "$NSY"; old "$NSY"
# --- name sync protection: an in-session rename is never overwritten ---
NPY="$P/acca0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoKeep"}\n{"uuid":"bcde0001-bcde-bcde-bcde-bcdebcdebcde","type":"user"}\n{"type":"custom-title","customTitle":"HandSet","sessionId":"x"}\n' > "$NPY"; old "$NPY"

# --- name rescue: a dead stub donates its user name to the continued-in parent ---
RPP="$P/caca0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoP"}\n{"uuid":"cdef0001-cdef-cdef-cdef-cdefcdefcdef","type":"user"}\n{"type":"continued-in","continuedInSessionId":"caca0002-0000-0000-0000-000000000000"}\n' > "$RPP"; old "$RPP"
RPS="$P/caca0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoP"}\n{"type":"custom-title","customTitle":"[Dead] [done] rescued name","sessionId":"x"}\n' > "$RPS"; old "$RPS"
# --- rescue counter-case: a custom title that only echoes the ai-title is a
# --- sweep mark, not a user name; the parent keeps its automatic title ---
RQP="$P/dede0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoQ"}\n{"uuid":"def00001-def0-def0-def0-def0def0def0","type":"user"}\n{"type":"continued-in","continuedInSessionId":"dede0002-0000-0000-0000-000000000000"}\n' > "$RQP"; old "$RQP"
RQS="$P/dede0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoQ"}\n{"type":"custom-title","customTitle":"[Stub] AutoQ","sessionId":"x"}\n' > "$RQS"; old "$RQS"

# --- same-target rows: a pointer row duplicating the session's own row ---
SGT="$P/feef0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SharedConv"}\n{"uuid":"efab0001-efab-efab-efab-efabefabefab","type":"user"}\n' > "$SGT"; old "$SGT"

# --- row repair: a dead user-named shell row is repointed at the parent ---
RRP="$P/fafa0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoR"}\n{"uuid":"adad0001-adad-adad-adad-adadadadadad","type":"user"}\n{"type":"continued-in","continuedInSessionId":"fafa0002-0000-0000-0000-000000000000"}\n' > "$RRP"; old "$RRP"
# --- repair refusal: the parent is already reachable through another row ---
RSP="$P/fbfb0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoS"}\n{"uuid":"bebe0001-bebe-bebe-bebe-bebebebebebe","type":"user"}\n{"type":"continued-in","continuedInSessionId":"fbfb0002-0000-0000-0000-000000000000"}\n' > "$RSP"; old "$RSP"
# --- repair refusal: a fresh, servable row with a STALE [Dead] name must not
# --- be hijacked (the settle-guarded dead sweep has not healed it yet) ---
RLP="$P/fcfc0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoT"}\n{"uuid":"cfcf0001-cfcf-cfcf-cfcf-cfcfcfcfcfcf","type":"user"}\n{"type":"continued-in","continuedInSessionId":"fcfc0002-0000-0000-0000-000000000000"}\n' > "$RLP"; old "$RLP"

# --- same-target election stability: an all-extra group (no native row, no
# --- live worker) must not swap keeper and [Dup] across runs — the rank must
# --- not use mtimes this tool's own marker writes bump ---
GTT="$P/77cc0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GhostTarget"}\n{"uuid":"dcba0001-dcba-dcba-dcba-dcbadcbadcba","type":"user"}\n' > "$GTT"; old "$GTT"

# --- sync election: the parent's OWN user-named row outranks a fresher
# --- user-named fork shell backing the same transcript ---
OWP="$P/acdc0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoU"}\n{"uuid":"eded0001-eded-eded-eded-ededededeced","type":"user"}\n' > "$OWP"; old "$OWP"

# --- name sync election: TWO user-named rows backing one transcript must not
# --- take turns rewriting its title; the unmarked (kept) row's name wins once ---
TWT="$P/baba0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoTwin"}\n{"uuid":"fcfc0001-fcfc-fcfc-fcfc-fcfcfcfcfcfc","type":"user"}\n' > "$TWT"; old "$TWT"

# --- live worker (this shell's pid + correct starttime): a transcript-less
# --- row with a live worker is NEVER [Dead]; the recycled-pid twin (live pid,
# --- wrong starttime) IS. Exercises the pid_matches_start comparison, which
# --- once compared against a clobbered positional and failed on every real
# --- worker ---
# (rows beda0001 / ceda0001 below, roster entries in the heredoc)

# --- live superseded copy: a transcript held by a live worker is never
# --- marked [Old Fork], even when a longer sibling supersedes it ---
LV1="$P/fe110001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"LiveCopy"}\n{"uuid":"11fe11fe-11fe-11fe-11fe-11fe11fe11fe","type":"user"}\n' > "$LV1"; old "$LV1"
LV2="$P/fe220001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"LiveCopy"}\n{"uuid":"11fe11fe-11fe-11fe-11fe-11fe11fe11fe","type":"user"}\n{"uuid":"22fe22fe-22fe-22fe-22fe-22fe22fe22fe","type":"user"}\n' > "$LV2"; old "$LV2"

# --- same-target election, live repaired row: the roster is keyed by the
# --- row FOLDER, so a repaired row (folder != session id) with a running
# --- worker must still win the election through the folder key — not lose
# --- to a rival with a fresher roster startedAt ---
DDE="$P/ddee0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"RepairTarget"}\n{"uuid":"eedd0001-eedd-eedd-eedd-eeddeeddeedd","type":"user"}\n' > "$DDE"; old "$DDE"

# --- dead sweep, folder-keyed live worker: a row whose FOLDER holds the live
# --- roster entry (repaired/alien shape: sessionId differs from the folder,
# --- no transcript) is never [Dead], and its name is never a rescue donor ---
PLD="$P/afaf0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoX"}\n{"uuid":"fada0001-fada-fada-fada-fadafadafada","type":"user"}\n{"type":"continued-in","continuedInSessionId":"faaf0001-0000-0000-0000-000000000001"}\n' > "$PLD"; old "$PLD"

# --- carrier redundancy with a junk parent tail: the parent gained a junk
# --- entry AFTER the carrier copied it; the shell is still redundant, so the
# --- check must judge by the conversation tail, not the raw one ---
PJ="$P/c2da0000-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SeamJ"}\n{"uuid":"a1b10001-a1b1-a1b1-a1b1-a1b1a1b1a1b1","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"b1a10002-b1a1-b1a1-b1a1-b1a1b1a1b1a1","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"c1d10003-c1d1-c1d1-c1d1-c1d1c1d1c1d1","type":"user","message":{"role":"user","content":"<system-reminder> renamed"}}\n' > "$PJ"; old "$PJ"
KAR="$P/e2da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"CarrierJ"}\n{"uuid":"a1b10001-a1b1-a1b1-a1b1-a1b1a1b1a1b1","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"b1a10002-b1a1-b1a1-b1a1-b1a1b1a1b1a1","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"d1c10004-d1c1-d1c1-d1c1-d1c1d1c1d1c1","type":"user","message":{"role":"user","content":"more"}}\n' > "$KAR"; old "$KAR"

# --- bare-token transcript + user-named row: the short-id fallback title the
# --- sweep mints must stay replaceable by the row name (it is a tool write,
# --- not an in-session rename) ---
NBT="$P/b4da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"[Dup]"}\n{"uuid":"e1f10005-e1f1-e1f1-e1f1-e1f1e1f1e1f1","type":"user"}\n' > "$NBT"; old "$NBT"

# --- heal keeps a user name containing " - forked on ": only the exact
# --- minted suffix shape (HH:MM dd.mm.yyyy by xxxx) is stripped ---
FK="$P/c4da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoY"}\n{"uuid":"f1e10006-f1e1-f1e1-f1e1-f1e1f1e1f1e1","type":"user","message":{"role":"user","content":"x"}}\n{"type":"custom-title","customTitle":"[Old Fork] Notes - forked on Friday","sessionId":"x"}\n' > "$FK"; old "$FK"

# --- title-only husk kept by a folder-keyed live worker: a worker rostered
# --- under ANOTHER folder serves this transcript as its launch source, so
# --- the husk is attachable and must not read [Stub] ---
HLV="$P/f4f40001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"HuskLive"}\n' > "$HLV"; old "$HLV"

# --- two LIVE at-rest twins of one parent: redundant, but a live row is
# --- never deletion-safe — neither may get a final [Dup] ---
PN="$P/ee77ee77-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloG"}\n{"uuid":"ab77ab77-ab77-ab77-ab77-ab77ab77ab77","type":"user"}\n' > "$PN"; old "$PN"

# --- order guard A: a user-named row backs the SUPERSEDED member of a copy
# --- group. The verdict must land before the name sweep runs — renaming
# --- first would split the group and lose the [Old Fork] forever ---
GS="$P/e5da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GrpA"}\n{"uuid":"a4b40001-a4b4-a4b4-a4b4-a4b4a4b4a4b4","type":"user"}\n{"uuid":"b4a40002-b4a4-b4a4-b4a4-b4a4b4a4b4a4","type":"user"}\n{"uuid":"c4d40003-c4d4-c4d4-c4d4-c4d4c4d4c4d4","type":"user"}\n' > "$GS"; old "$GS"
GT="$P/e5da0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GrpA"}\n{"uuid":"a4b40001-a4b4-a4b4-a4b4-a4b4a4b4a4b4","type":"user"}\n{"uuid":"b4a40002-b4a4-b4a4-b4a4-b4a4b4a4b4a4","type":"user"}\n' > "$GT"; touch -m -d '3 hours ago' "$GT"

# --- order guard B: identical twins both carrying continued-in to a dead
# --- user-named shell. The twin [Dup] must land before the repaired row's
# --- name reaches the keeper's transcript ---
GP="$P/f5da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GrpB"}\n{"uuid":"d4c40001-d4c4-d4c4-d4c4-d4c4d4c4d4c4","type":"user"}\n{"uuid":"e4f40002-e4f4-e4f4-e4f4-e4f4e4f4e4f4","type":"user"}\n{"type":"continued-in","continuedInSessionId":"f5da0003-0000-0000-0000-000000000000"}\n' > "$GP"; touch -m -d '3 hours ago' "$GP"
GQ="$P/f5da0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GrpB"}\n{"uuid":"d4c40001-d4c4-d4c4-d4c4-d4c4d4c4d4c4","type":"user"}\n{"uuid":"e4f40002-e4f4-e4f4-e4f4-e4f4e4f4e4f4","type":"user"}\n{"type":"continued-in","continuedInSessionId":"f5da0003-0000-0000-0000-000000000000"}\n' > "$GQ"; old "$GQ"

# --- join guard: sync lands "JoinT" on a transcript whose conversation also
# --- lives in a sibling ALREADY titled "JoinT" — a same-title group that
# --- exists only after the name sweeps ran, so the copy sweep must judge
# --- once more (the append restores idle mtimes, hiding the group from the
# --- skip gate on every later run) ---
JA="$P/a6da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoJ"}\n{"uuid":"a5b50001-a5b5-a5b5-a5b5-a5b5a5b5a5b5","type":"user"}\n{"uuid":"b5a50002-b5a5-b5a5-b5a5-b5a5b5a5b5a5","type":"user"}\n' > "$JA"; old "$JA"
JB="$P/a6da0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"JoinT"}\n{"uuid":"a5b50001-a5b5-a5b5-a5b5-a5b5a5b5a5b5","type":"user"}\n{"uuid":"b5a50002-b5a5-b5a5-b5a5-b5a5b5a5b5a5","type":"user"}\n{"uuid":"c5d50003-c5d5-c5d5-c5d5-c5d5c5d5c5d5","type":"user"}\n' > "$JB"; touch -m -d '3 hours ago' "$JB"

# --- drifted-startedAt fork row: own diverged transcript (keeps it out of
# --- the PA twin group); the ns-epoch roster timestamp must never read
# --- "fresh", or [Dup?] would re-land on every run and never expire ---
DRT="$P/edda0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"DriftMine"}\n{"uuid":"c7d70003-c7d7-c7d7-c7d7-c7d7c7d7c7d7","type":"user"}\n' > "$DRT"; old "$DRT"

# --- stranded row [Dup]: the transcript was renamed in-session (clean
# --- title), so the same-title group that justified the row's [Dup] no
# --- longer exists — the dup sweep must heal the row instead of leaving a
# --- deletion-safe mark on a session the user just claimed ---
SRD="$P/b6da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"OldGroup"}\n{"uuid":"a8b80001-a8b8-a8b8-a8b8-a8b8a8b8a8b8","type":"user"}\n{"type":"custom-title","customTitle":"FreshSolo","sessionId":"x"}\n' > "$SRD"; old "$SRD"
# --- counter-case: twins whose group verdict still stands — the loser's row
# --- keeps its [Dup] (its transcript title is marked too) ---
KG1="$P/c6da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"KeepGrp"}\n{"uuid":"b8c80001-b8c8-b8c8-b8c8-b8c8b8c8b8c8","type":"user"}\n{"uuid":"c8d80002-c8d8-c8d8-c8d8-c8d8c8d8c8d8","type":"user"}\n' > "$KG1"; touch -m -d '3 hours ago' "$KG1"
KG2="$P/c6da0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"KeepGrp"}\n{"uuid":"b8c80001-b8c8-b8c8-b8c8-b8c8b8c8b8c8","type":"user"}\n{"uuid":"c8d80002-c8d8-c8d8-c8d8-c8d8c8d8c8d8","type":"user"}\n' > "$KG2"; touch -m -d '2 hours ago' "$KG2"

# --- empty custom-title: reverts to the automatic title; the scan cache must
# --- agree with the live reader, or this unservable husk would read as
# --- untitled and never take its [Stub] ---
HECT="$P/a7da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"HuskE"}\n{"type":"custom-title","customTitle":"","sessionId":"x"}\n' > "$HECT"; old "$HECT"

# --- jobs registry ---
mkjob() { mkdir -p "$T/.claude/jobs/$1"; { printf '{"name":"%s","sessionId":"%s"' "$2" "$3"; [ -n "$4" ] && printf ',"nameSource":"%s"' "$4"; [ -n "$5" ] && printf ',"resumeSessionId":"%s"' "$5"; printf '}\n'; } > "$T/.claude/jobs/$1/state.json"; touch -m -d '1 hour ago' "$T/.claude/jobs/$1/state.json"; }
mkjob bbbb1111 "Global" "bbbb1111-0000-0000-0000-000000000001"   # at-rest twin, older
mkjob cccc2222 "Global" "cccc2222-0000-0000-0000-000000000001"   # at-rest twin, newer -> keeper
mkjob dddd3333 "Solo"   "dddd3333-0000-0000-0000-000000000001"   # sole at-rest fork
mkjob eeee4444 "Seam"   "eeee4444-0000-0000-0000-000000000001"   # at-rest, carrier exists
mkjob ffff5555 "Deady"  "ffff5555-0000-0000-0000-000000000001"   # no transcript, no roster
mkjob aaaa0000 "Carrier" "aaaa0000-0000-0000-0000-000000000000"  # carrier (real transcript)
mkjob abba0001 "[done] my real name" "abba0001-0000-0000-0000-000000000000" user   # name sync source
mkjob acca0001 "RowName" "acca0001-0000-0000-0000-000000000000" user               # must not beat HandSet
mkjob feef0001 "SharedConv" "feef0001-0000-0000-0000-000000000000"                 # native row, keeps name
mkjob 99fe0001 "SharedConv ghost" "99fe0001-0000-0000-0000-000000000000" "" "feef0001-0000-0000-0000-000000000000"  # pointer row
touch -m "$T/.claude/jobs/99fe0001/state.json"   # fresh, so the dead sweep's settle guard leaves it to the dup sweep
mkjob baba0001 "kept name" "baba0001-0000-0000-0000-000000000000" user                                              # native twin row
mkjob 88ba0001 "ghost name" "88ba0001-0000-0000-0000-000000000000" user "baba0001-0000-0000-0000-000000000000"      # user-named pointer twin
touch -m "$T/.claude/jobs/88ba0001/state.json"   # fresh, same reason as above
mkjob fafa0002 "lost name" "fafa0002-0000-0000-0000-000000000000" user         # dead named shell -> repaired
mkjob fbfb0001 "AutoS" "fbfb0001-0000-0000-0000-000000000000"                  # native row already reaching AutoS
mkjob fbfb0002 "second name" "fbfb0002-0000-0000-0000-000000000000" user       # dead named shell, repair refused
mkjob fcfc0002 "[Dead] live shell" "fcfc0002-0000-0000-0000-000000000000" user # stale mark on a servable row
touch -m "$T/.claude/jobs/fcfc0002/state.json"   # fresh write: mid-respawn shape, repair must keep off
mkjob 77aa0001 "Ghost A" "77aa0001-0000-0000-0000-000000000000" "" "77cc0001-0000-0000-0000-000000000000"  # all-extra group
mkjob 77bb0001 "Ghost B" "77bb0001-0000-0000-0000-000000000000" "" "77cc0001-0000-0000-0000-000000000000"  # all-extra group
touch -m "$T/.claude/jobs/77aa0001/state.json" "$T/.claude/jobs/77bb0001/state.json"  # fresh: dead sweep settles, dup sweep judges
mkjob acdc0001 "own name" "acdc0001-0000-0000-0000-000000000000" user          # the transcript's own row
mkjob 55dc0001 "shell name" "55dc0001-0000-0000-0000-000000000000" user        # fresher shell backing the same transcript
touch -m "$T/.claude/jobs/55dc0001/state.json"
mkjob beda0001 "LiveShell" "beda0001-0000-0000-0000-000000000001"              # live worker, no transcript: never [Dead]
mkjob ceda0001 "RecycledPid" "ceda0001-0000-0000-0000-000000000001"            # live pid, WRONG starttime: dead
mkjob eeff0001 "RepairedLive" "ddee0001-0000-0000-0000-000000000000" "" "ddee0001-0000-0000-0000-000000000000"  # repaired-row shape, live worker
mkjob eeff0002 "OtherPointer" "eeff0002-0000-0000-0000-000000000000" "" "ddee0001-0000-0000-0000-000000000000"  # rival pointer, fresher startedAt
mkjob f2da0001 "FolderLive" "faaf0001-0000-0000-0000-000000000001" user  # live under the FOLDER roster key only
mkjob d2da0001 "SeamJShell" "d2da0001-0000-0000-0000-000000000001"       # at-rest shell; carrier exists, parent tail junk
mkjob e2da0001 "CarrierJ" "e2da0001-0000-0000-0000-000000000000"         # carrier of the junk-tailed parent's conversation
mkjob b4da0001 "bare named" "b4da0001-0000-0000-0000-000000000000" user  # row name must reach the short-id-titled transcript
mkjob a5da0001 "LiveTwinA" "a5da0001-0000-0000-0000-000000000001"        # live twin, older
mkjob a5da0002 "LiveTwinB" "a5da0002-0000-0000-0000-000000000001"        # live twin, newer
mkjob e5da0002 "FooA" "e5da0002-0000-0000-0000-000000000000" user        # names the SUPERSEDED copy-group member
mkjob f5da0003 "NameB" "f5da0003-0000-0000-0000-000000000000" user       # dead shell both twins continue-in to
mkjob a6da0001 "JoinT" "a6da0001-0000-0000-0000-000000000000" user       # syncs "JoinT" onto the behind copy, joining JB's group
mkjob edda0001 "DriftN" "edda0001-0000-0000-0000-000000000000"           # roster startedAt drifted to ns epoch: never "fresh"
mkjob b6da0001 "[Dup] StrandT" "b6da0001-0000-0000-0000-000000000000"    # stranded [Dup]: transcript renamed in-session -> heal
mkjob c6da0001 "KeptDup" "c6da0001-0000-0000-0000-000000000000"          # loser twin's row: group verdict stands -> [Dup] kept
# multi-line name: jq -r would emit the raw newline and shear the US-joined
# record — the row would sit silently exempt from every sweep; the loader
# flattens control characters to spaces instead
mkdir -p "$T/.claude/jobs/d6da0001"
printf '{"name":"two\\nlines","sessionId":"d6da0001-0000-0000-0000-000000000001"}\n' > "$T/.claude/jobs/d6da0001/state.json"
touch -m -d '1 hour ago' "$T/.claude/jobs/d6da0001/state.json"
# permission keeper: daemon rows can be 0600; the marker rewrite (ffff5555
# takes [Dead]) and the repair rewrite (fafa0002 is repointed) must not
# loosen them to the umask default
chmod 600 "$T/.claude/jobs/ffff5555/state.json" "$T/.claude/jobs/fafa0002/state.json"
# corrupt job early in glob order: must not blind load_jobs to the later jobs
mkdir -p "$T/.claude/jobs/aaaa0001"; printf 'not json at all' > "$T/.claude/jobs/aaaa0001/state.json"; touch -m -d '1 hour ago' "$T/.claude/jobs/aaaa0001/state.json"
# lone-surrogate row (jq 1.6 rejects the \udXXX escape a well-formed writer
# emits when truncating text mid-emoji): must still load, be judged dead AND
# take the marker write — not sit permanently exempt
mkdir -p "$T/.claude/jobs/c5da0001"
printf '{"name":"SurGhost","sessionId":"c5da0001-0000-0000-0000-000000000001","intent":"%s"}\n' 'ab\ud83d' > "$T/.claude/jobs/c5da0001/state.json"
touch -m -d '1 hour ago' "$T/.claude/jobs/c5da0001/state.json"

# --- roster: at-rest resume forks (dead pids -> respawnable via launch source),
# --- plus genuinely live workers borrowing this shell's pid/starttime ---
cat > "$T/.claude/daemon/roster.json" <<EOF
{"workers":{
 "bbbb1111":{"pid":99999901,"startedAt":100,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}},
 "cccc2222":{"pid":99999902,"startedAt":200,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}},
 "dddd3333":{"pid":99999903,"startedAt":300,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PB"}}},
 "eeee4444":{"pid":99999904,"startedAt":400,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PC"}}},
 "fcfc0002":{"pid":99999906,"startedAt":500,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$RLP"}}},
 "55dc0001":{"pid":99999977,"startedAt":600,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$OWP"}}},
 "beda0001":{"pid":$$,"procStart":$MYSTART,"startedAt":700},
 "ceda0001":{"pid":$$,"procStart":1,"startedAt":710},
 "fe110001":{"pid":$$,"procStart":$MYSTART,"startedAt":720},
 "eeff0001":{"pid":$$,"procStart":$MYSTART,"startedAt":730,"dispatch":{"launch":{"sessionId":"$DDE"}}},
 "eeff0002":{"pid":99999920,"startedAt":99999999999999,"dispatch":{"launch":{"sessionId":"$DDE"}}},
 "e6da0002":{"pid":$$,"procStart":$MYSTART,"startedAt":740},
 "f2da0001":{"pid":$$,"procStart":$MYSTART,"startedAt":750},
 "d2da0001":{"pid":99999941,"startedAt":810,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PJ"}}},
 "e4da0001":{"pid":$$,"procStart":$MYSTART,"startedAt":760,"dispatch":{"launch":{"sessionId":"$HLV"}}},
 "a5da0001":{"pid":$$,"procStart":$MYSTART,"startedAt":820,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PN"}}},
 "a5da0002":{"pid":$$,"procStart":$MYSTART,"startedAt":830,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PN"}}},
 "adad0009":{"pid":99999960,"startedAt":900,"note":"a\ud83d"},
 "edda0001":{"pid":99999961,"startedAt":$DRIFTNS,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}}
}}
EOF

run() {
  # A sweep that dies mid-run is a failure even when every later want-line
  # happens to read the pre-crash state ("no custom-title" asserts would
  # pass vacuously otherwise).
  bash "$T/fw.sh" --sweep-only
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'FAIL sweep run exited rc=%s\n' "$rc"
    fails=$((fails + 1))
  fi
}
snap() {
  # Content AND mtimes: elections and skip gates key off mtimes, so silent
  # mtime churn (a failed restore) is instability even with identical bytes.
  # The sweep stamp is the one file meant to move between runs.
  {
    find "$T/.claude" -type f ! -name 'fork-watch-sweep-stamp' -exec md5sum {} +
    find "$T/.claude" -type f ! -name 'fork-watch-sweep-stamp' -printf '%T@ %p\n'
  } | sort
}
jn() { jq -r '.name' "$T/.claude/jobs/$1/state.json"; }
ft() { grep -F '"type":"custom-title"' "$1" 2>/dev/null | jq -r 'select(.type=="custom-title").customTitle' | tail -1; }

run
echo "--- pass 1 ---"
chk "twin older" "[Dup] Global" "$(jn bbbb1111)"
chk "twin newer" "Global" "$(jn cccc2222)"
chk "sole fork" "Solo" "$(jn dddd3333)"
chk "seam carrier" "[Dup] Seam" "$(jn eeee4444)"
chk "dead job" "[Dead] Deady" "$(jn ffff5555)"
chk "carrier job" "Carrier" "$(jn aaaa0000)"
chk "stub husk" "[Stub] Stubby" "$(ft "$ST")"
chk "superseded" "[Old Fork] Copy" "$(ft "$F1")"
chk "longer copy (no custom-title)" "" "$(ft "$F2")"
chk "twin t1" "[Dup] Twin" "$(ft "$T1")"
chk "twin t2 (no custom-title)" "" "$(ft "$T2")"
chk "heal stub" "Real" "$(ft "$HR")"
chk "heal oldfork" "Div" "$(ft "$HD")"
chk "seam parent (distinct title, seam only marks the shell)" "" "$(ft "$PC")"
chk "keeper twin healed" "Twin2" "$(ft "$G2")"
chk "loser twin" "[Dup] Twin2" "$(ft "$G1")"
chk "bare token real" "addd0001" "$(ft "$BT1")"
chk "bare token husk" "[Stub] beef0001" "$(ft "$BT2")"
chk "fresh superseded (marked on FIRST pass)" "[Old Fork] CopyC" "$(ft "$F3")"
chk "noisy superset older (junk-only extras = twins)" "[Dup] NoisyT" "$(ft "$NF1")"
chk "noisy superset newer (no custom-title)" "" "$(ft "$NF2")"
chk "reversed noisy: junk superset older" "[Dup] NoisyR" "$(ft "$RN2")"
chk "reversed noisy: clean newer (no custom-title)" "" "$(ft "$RN1")"
chk "gap trio base" "[Old Fork] GapT" "$(ft "$GF")"
chk "gap trio junk superset (no unmarked slip)" "[Old Fork] GapT" "$(ft "$GG")"
chk "gap trio diverged (no custom-title)" "" "$(ft "$GH")"
chk "synced transcript" "[done] my real name" "$(ft "$NSY")"
chk "protected transcript (row name never beats an in-session rename)" "HandSet" "$(ft "$NPY")"
chk "rescued parent" "[done] rescued name" "$(ft "$RPP")"
chk "echo-title parent (sweep residue never donated)" "" "$(ft "$RQP")"
chk "pointer row" "[Dup] SharedConv ghost" "$(jn 99fe0001)"
chk "native row" "SharedConv" "$(jn feef0001)"
chk "twin-named transcript (unmarked row wins the election)" "kept name" "$(ft "$TWT")"
chk "twin-named ghost row" "[Dup] ghost name" "$(jn 88ba0001)"
chk "repaired row (dead shell repointed same run)" "lost name" "$(jn fafa0002)"
chk "repaired row target" "fafa0001-0000-0000-0000-000000000000" "$(jq -r '.sessionId' "$T/.claude/jobs/fafa0002/state.json")"
chk "repaired parent title (synced)" "lost name" "$(ft "$RRP")"
chk "refused repair (parent already reachable)" "[Dead] second name" "$(jn fbfb0002)"
chk "refused-case parent title (rescue still donates)" "second name" "$(ft "$RSP")"
chk "live-shell repair refusal (fresh servable row untouched)" "[Dead] live shell" "$(jn fcfc0002)"
chk "live-shell parent title (sync still follows the conversation)" "live shell" "$(ft "$RLP")"
chk "all-extra keeper (stable election by folder not mtime)" "Ghost B" "$(jn 77bb0001)"
chk "all-extra loser" "[Dup] Ghost A" "$(jn 77aa0001)"
chk "own-row sync (the session's own row outranks the fresher shell)" "own name" "$(ft "$OWP")"
chk "shell row (seam carrier: the own row already reaches it)" "[Dup] shell name" "$(jn 55dc0001)"
chk "live worker row (never [Dead] while the worker runs)" "LiveShell" "$(jn beda0001)"
chk "recycled pid row (live pid, wrong starttime = dead)" "[Dead] RecycledPid" "$(jn ceda0001)"
chk "live superseded copy (never [Old Fork] while live)" "" "$(ft "$LV1")"
chk "live repaired row keeps the election (folder is the roster key)" "RepairedLive" "$(jn eeff0001)"
chk "rival pointer of the live repaired row" "[Dup] OtherPointer" "$(jn eeff0002)"
chk "folder-keyed live row (never [Dead])" "FolderLive" "$(jn f2da0001)"
chk "folder-keyed live row is no donor (parent stays unnamed)" "" "$(ft "$PLD")"
chk "junk parent tail (carrier judged by the conversation)" "[Dup] SeamJShell" "$(jn d2da0001)"
chk "short-id title replaced by the row name" "bare named" "$(ft "$NBT")"
chk "heal keeps a forked-on user name" "Notes - forked on Friday" "$(ft "$FK")"
chk "folder-keyed live husk (no [Stub])" "" "$(ft "$HLV")"
chk "live twin older (never a final [Dup] while live)" "LiveTwinA" "$(jn a5da0001)"
chk "live twin newer" "LiveTwinB" "$(jn a5da0002)"
chk "order guard A: verdict lands before the row name" "[Old Fork] GrpA" "$(ft "$GT")"
chk "order guard A: the name stays on the row, under the marker" "[Old Fork] FooA" "$(jn e5da0002)"
chk "order guard A: keeper unmarked" "" "$(ft "$GS")"
chk "order guard B: twin verdict lands before the landed name" "[Dup] GrpB" "$(ft "$GP")"
chk "order guard B: keeper carries the repaired row's name" "NameB" "$(ft "$GQ")"
chk "order guard B: shell row repaired" "NameB" "$(jn f5da0003)"
chk "join guard: the late-formed group is judged this run" "[Old Fork] JoinT" "$(ft "$JA")"
chk "join guard: the row keeps its name under the marker" "[Old Fork] JoinT" "$(jn a6da0001)"
chk "join guard: the ahead sibling stays untouched" "" "$(ft "$JB")"
chk "surrogate row still judged and written" "[Dead] SurGhost" "$(jn c5da0001)"
chk "drifted startedAt is never fresh (no [Dup?])" "DriftN" "$(jn edda0001)"
chk "stranded row [Dup] healed (title renamed in-session)" "StrandT" "$(jn b6da0001)"
chk "row [Dup] kept while the group verdict stands" "[Dup] KeptDup" "$(jn c6da0001)"
chk "loser twin of the kept group (title)" "[Dup] KeepGrp" "$(ft "$KG1")"
chk "multi-line name flattened and judged" "[Dead] two lines" "$(jn d6da0001)"
chk "empty custom-title reverts to the ai-title ([Stub] lands)" "[Stub] HuskE" "$(ft "$HECT")"
chk "marker write keeps 0600" "600" "$(stat -c %a "$T/.claude/jobs/ffff5555/state.json")"
chk "repair write keeps 0600" "600" "$(stat -c %a "$T/.claude/jobs/fafa0002/state.json")"

sum1=$(snap)
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
sum2=$(snap)
echo "--- pass 2 stability (stamp removed, full resweep) ---"
if [ "$sum1" = "$sum2" ]; then echo "ok   STABLE: second run changed nothing"; else echo "FAIL UNSTABLE:"; diff <(echo "$sum1") <(echo "$sum2"); fails=$((fails + 1)); fi

echo "--- aged stamp: sweeps run but unchanged content is skipped ---"
touch -m -d '40 seconds ago' "$T/.claude/fork-watch-sweep-stamp"
sum2b=$(snap)
run
sum2c=$(snap)
if [ "$sum2b" = "$sum2c" ]; then echo "ok   STABLE: aged-stamp run changed nothing"; else echo "FAIL UNSTABLE:"; diff <(echo "$sum2b") <(echo "$sum2c"); fails=$((fails + 1)); fi

echo "--- stamp skip + heal ---"
jq '.name="[Dead] Global"' "$T/.claude/jobs/cccc2222/state.json" > "$T/x" && mv "$T/x" "$T/.claude/jobs/cccc2222/state.json"
touch -m -d '1 hour ago' "$T/.claude/jobs/cccc2222/state.json"
run
chk "fresh stamp ([Dead] Global untouched, sweeps skipped)" "[Dead] Global" "$(jn cccc2222)"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "stamp gone (Global healed)" "Global" "$(jn cccc2222)"

echo "--- fresh stamp + new write: first-open marks override the skip ---"
LU1="0a0a0a0a-0a0a-0a0a-0a0a-0a0a0a0a0a0a"
LU2="a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0"
LF1="$P/fade0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"LateT"}\n{"uuid":"%s","type":"user"}\n' "$LU1" > "$LF1"; old "$LF1"
LF2="$P/fade0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"LateT"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$LU1" "$LU2" > "$LF2"
run
chk "late flush ([Old Fork] despite fresh stamp)" "[Old Fork] LateT" "$(ft "$LF1")"

echo "--- streaming write protection ---"
SU1="0e0e0e0e-0e0e-0e0e-0e0e-0e0e0e0e0e0e"
SU2="e0e0e0e0-e0e0-e0e0-e0e0-e0e0e0e0e0e0"
SP1="$P/feed0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"StreamT"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$SU1" "$SU2" > "$SP1"; old "$SP1"
SP2="$P/feed0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"StreamT"}\n{"uuid":"%s","type":"user"}\n' "$SU1" > "$SP2"
( for i in $(seq 1 150); do printf '{"type":"noise","n":%s}\n' "$i" >> "$SP2"; sleep 0.05; done ) >/dev/null 2>&1 &
wpid=$!
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "streaming twin (no custom-title, write in progress)" "" "$(ft "$SP2")"
kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
old "$SP2"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "stopped twin" "[Old Fork] StreamT" "$(ft "$SP2")"

echo "--- provisional [Dup?]: fresh roster forks marked from roster info alone ---"
# Parents (transcripts only, no job rows)
PD="$P/dd44dd44-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloB"}\n{"uuid":"%s","type":"user"}\n' "$(uu f)" > "$PD"; old "$PD"
PE="$P/ee55ee55-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloC"}\n{"uuid":"ba21ba21-ba21-ba21-ba21-ba21ba21ba21","type":"user"}\n' > "$PE"; old "$PE"
PF="$P/ff66ff66-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloD"}\n{"uuid":"fa01fa01-fa01-fa01-fa01-fa01fa01fa01","type":"user"}\n' > "$PF"; old "$PF"
# Fresh fork WITH a diverged transcript: no content verdict possible, the
# provisional must survive the run (and the parent is a genuine [Old Fork])
DU1="ab12ab12-ab12-ab12-ab12-ab12ab12ab12"
DF="$P/abcd0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloB"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"more"}}\n' "$(uu f)" "$DU1" > "$DF"; old "$DF"
mkjob abcd0001 "FreshFork" "abcd0001-0000-0000-0000-000000000001"
# Fresh sole fork SHELL (no transcript): healed clean in the same run
mkjob abcd0003 "FreshShell" "abcd0003-0000-0000-0000-000000000001"
# Fresh twin shells of one parent: older upgraded to a final [Dup], keeper healed
mkjob abcd0004 "TwinG1" "abcd0004-0000-0000-0000-000000000001"
mkjob abcd0005 "TwinG2" "abcd0005-0000-0000-0000-000000000001"
NOWMS=$(( $(date +%s) * 1000 ))
roster_with_fresh() {
  # $1 = startedAt for the diverged fork abcd0001
  cat > "$T/.claude/daemon/roster.json" <<EOF2
{"workers":{
 "bbbb1111":{"pid":99999901,"startedAt":100,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}},
 "cccc2222":{"pid":99999902,"startedAt":200,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}},
 "dddd3333":{"pid":99999903,"startedAt":300,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PB"}}},
 "eeee4444":{"pid":99999904,"startedAt":400,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PC"}}},
 "abcd0001":{"pid":99999905,"startedAt":$1,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PD"}}},
 "abcd0003":{"pid":99999907,"startedAt":$NOWMS,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PF"}}},
 "abcd0004":{"pid":99999908,"startedAt":$NOWMS,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PE"}}},
 "abcd0005":{"pid":99999909,"startedAt":$(( NOWMS + 5 )),"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PE"}}}
}}
EOF2
}
roster_with_fresh "$NOWMS"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "diverged fork (no content verdict yet)" "[Dup?] FreshFork" "$(jn abcd0001)"
chk "its parent" "[Old Fork] SoloB" "$(ft "$PD")"
chk "sole shell (healed same-run)" "FreshShell" "$(jn abcd0003)"
chk "older twin (upgraded to final)" "[Dup] TwinG1" "$(jn abcd0004)"
chk "keeper twin (healed same-run)" "TwinG2" "$(jn abcd0005)"
chk "stale solo (old startedAt never provisional)" "Solo" "$(jn dddd3333)"

echo "--- provisional expiry: a completed sweep outranks the provisional ---"
# startedAt now pa5dates the sweep stamp -> not eligible, [Dup?] heals off
roster_with_fresh $(( NOWMS - 60000 ))
run
chk "expired fork (healed)" "FreshFork" "$(jn abcd0001)"

echo "--- provisional never downgrades a real verdict ---"
jq '.name="[Dup] FreshFork"' "$T/.claude/jobs/abcd0001/state.json" > "$T/x" && mv "$T/x" "$T/.claude/jobs/abcd0001/state.json"
touch -m -d '1 hour ago' "$T/.claude/jobs/abcd0001/state.json"
# The [Dup] must be title-backed now: the dup sweep heals a row-level [Dup]
# whose transcript title carries no marker (the round-9 stranded-row heal).
# A newer identical twin makes DF the group's loser, so the copy sweep
# re-affirms "[Dup] " on title and row within this same run.
DF2="$P/adce0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloB"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user","message":{"role":"user","content":"more"}}\n' "$(uu f)" "$DU1" > "$DF2"; touch -m -d '1 hour ago' "$DF2"
roster_with_fresh "$NOWMS"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "real verdict kept (no [Dup?] downgrade)" "[Dup] FreshFork" "$(jn abcd0001)"

echo "--- ← left-press tag: fork of a recently-active parent ---"
NOWMS2=$(( $(date +%s) * 1000 ))
PG="$P/aabb0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloE"}\n{"uuid":"ea01ea01-ea01-ea01-ea01-ea01ea01ea01","type":"user"}\n' > "$PG"; touch -m -d '90 seconds ago' "$PG"
PH="$P/aabb0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloF"}\n{"uuid":"fb02fb02-fb02-fb02-fb02-fb02fb02fb02","type":"user"}\n' > "$PH"; touch -m -d '90 seconds ago' "$PH"
# Diverged materialized fork of the ACTIVE parent -> [←Dup?] survives the run
AF="$P/abcd0006-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"SoloE"}\n{"uuid":"ea01ea01-ea01-ea01-ea01-ea01ea01ea01","type":"user"}\n{"uuid":"ce03ce03-ce03-ce03-ce03-ce03ce03ce03","type":"user","message":{"role":"user","content":"more"}}\n' > "$AF"; old "$AF"
mkjob abcd0006 "FreshForkL" "abcd0006-0000-0000-0000-000000000001"
# Twin shells of an active parent: older upgraded keeping the arrow, keeper healed
mkjob abcd0007 "TwinH1" "abcd0007-0000-0000-0000-000000000001"
mkjob abcd0008 "TwinH2" "abcd0008-0000-0000-0000-000000000001"
cat > "$T/.claude/daemon/roster.json" <<EOF2
{"workers":{
 "abcd0006":{"pid":99999910,"startedAt":$NOWMS2,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PG"}}},
 "abcd0007":{"pid":99999911,"startedAt":$NOWMS2,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PH"}}},
 "abcd0008":{"pid":99999912,"startedAt":$(( NOWMS2 + 5 )),"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PH"}}}
}}
EOF2
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "arrow fork" "[←Dup?] FreshForkL" "$(jn abcd0006)"
chk "arrow parent (titles stay plain)" "[Old Fork] SoloE" "$(ft "$PG")"
chk "arrow upgrade (arrow survives the final verdict)" "[←Dup] TwinH1" "$(jn abcd0007)"
chk "arrow keeper (healed, arrow dropped)" "TwinH2" "$(jn abcd0008)"

echo "--- name sync: a second rename keeps syncing (own write is replaceable) ---"
jq '.name="[current] renamed again"' "$T/.claude/jobs/abba0001/state.json" > "$T/x" && mv "$T/x" "$T/.claude/jobs/abba0001/state.json"
touch -m -d '1 hour ago' "$T/.claude/jobs/abba0001/state.json"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "re-synced transcript" "[current] renamed again" "$(ft "$NSY")"

echo "--- same-target heal: twin row gone -> pointer heals ---"
rm -rf "$T/.claude/jobs/feef0001"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "pointer healed" "SharedConv ghost" "$(jn 99fe0001)"

echo "--- sync vs in-session rename: a hand rename AFTER a sync is kept ---"
# The transcript was synced earlier ("[current] renamed again" is this tool's
# recorded write); the user now renames INSIDE the session. The row still
# carries the old name, but the newer hand-set title must win forever.
printf '{"type":"custom-title","customTitle":"InSessionSet","sessionId":"x"}\n' >> "$NSY"
old "$NSY"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "in-session rename kept over the stale row name" "InSessionSet" "$(ft "$NSY")"

echo "--- repair gate: a parent aging past the hour-silence guard retries ---"
# A dead named shell whose parent is only 30 minutes silent: repair refuses.
GAP="$P/a2da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"GateParent"}\n{"uuid":"adga0001-adga-adga-adga-adgaadgaadga","type":"user"}\n{"type":"continued-in","continuedInSessionId":"a2da0002-0000-0000-0000-000000000000"}\n' > "$GAP"
touch -m -d '30 minutes ago' "$GAP"
mkjob a2da0002 "[Dead] gate name" "a2da0002-0000-0000-0000-000000000000" user
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "young parent (repair refused, under an hour silent)" "[Dead] gate name" "$(jn a2da0002)"
# Now the parent crosses the hour line with NO write anywhere: backdate every
# recent file so pmax < sm, age the stamp 40s, and put the parent's mtime
# inside the crossing window (sm-3600, NOW-3600]. The skip must void itself
# and the repair must land.
find "$T/.claude" -type f -newermt '-60 seconds' ! -name 'fork-watch-sweep-stamp' -exec touch -m -d '2 hours ago' {} +
touch -m -d '3620 seconds ago' "$GAP"
touch -m -d '40 seconds ago' "$T/.claude/fork-watch-sweep-stamp"
run
chk "aged parent (skip voided, repair landed)" "gate name" "$(jn a2da0002)"
chk "aged parent target" "a2da0001-0000-0000-0000-000000000000" "$(jq -r '.sessionId' "$T/.claude/jobs/a2da0002/state.json")"

echo "--- rescue gate: a donor marked by THIS run still donates (aged stamp) ---"
# An unservable shell with an unmarked user title ages past the 60s guard on
# a quiet tree. This run's transcript sweep marks it [Stub] — minting a
# rescue donor with NO mtime moving (title appends restore idle mtimes), so
# the mtime-only skip gate would defer the donation forever. The same-run
# write must void the gate.
HSH="$P/b2da0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoV"}\n{"type":"custom-title","customTitle":"stub lost name","sessionId":"x"}\n' > "$HSH"
touch -m -d '100 seconds ago' "$HSH"
HPP="$P/b2da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoW"}\n{"uuid":"ahda0001-ahda-ahda-ahda-ahdaahdaahda","type":"user"}\n{"type":"continued-in","continuedInSessionId":"b2da0002-0000-0000-0000-000000000000"}\n' > "$HPP"
old "$HPP"
# The previous run's own writes (the repair, plus [Dead] verdicts on rows
# whose settle guards the earlier blanket backdate aged out) are fresh job
# mtimes that would void pmax < sm and bypass the gate — age them too, so
# THIS run's [Stub] mark is the only new event.
find "$T/.claude" -type f -newermt '-60 seconds' ! -name 'fork-watch-sweep-stamp' -exec touch -m -d '2 hours ago' {} +
touch -m -d '40 seconds ago' "$T/.claude/fork-watch-sweep-stamp"
run
chk "donor stub marked this run" "[Stub] stub lost name" "$(ft "$HSH")"
chk "name rescued despite the aged stamp" "stub lost name" "$(ft "$HPP")"

echo "--- fractional roster startedAt: the sweep must survive AND judge ---"
# The live twin's fractional startedAt feeds the live-bonus arithmetic. An
# unsanitized value does not kill the script — bash aborts just the loop —
# so the tell is the MISSING verdict: the cold twin would never get [Dup].
mkjob a4da0001 "FracOld" "a4da0001-0000-0000-0000-000000000001"
mkjob a4da0002 "FracNew" "a4da0002-0000-0000-0000-000000000001"
cat > "$T/.claude/daemon/roster.json" <<EOF3
{"workers":{
 "a4da0001":{"pid":99999930,"startedAt":1000.5,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}},
 "a4da0002":{"pid":$$,"procStart":$MYSTART,"startedAt":2000.5,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}}
}}
EOF3
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "fractional startedAt: cold twin still judged" "[Dup] FracOld" "$(jn a4da0001)"
chk "fractional startedAt: live keeper intact" "FracNew" "$(jn a4da0002)"

echo "--- cold twins inside the 60s mtime window: the keeper must not flip ---"
# Marking the older twin bumps its on-disk mtime (appends to files idle under
# 60s are never backdated), so a pure-mtime election would crown it keeper on
# the NEXT run and move the [Dup] to its sibling, forever alternating. The
# unmarked-beats-marked tier must hold the verdict.
W1="$P/d4da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"WinT"}\n{"uuid":"a2b20001-a2b2-a2b2-a2b2-a2b2a2b2a2b2","type":"user"}\n{"uuid":"b2a20002-b2a2-b2a2-b2a2-b2a2b2a2b2a2","type":"user"}\n' > "$W1"; touch -m -d '50 seconds ago' "$W1"
W2="$P/d4da0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"WinT"}\n{"uuid":"a2b20001-a2b2-a2b2-a2b2-a2b2a2b2a2b2","type":"user"}\n{"uuid":"b2a20002-b2a2-b2a2-b2a2-b2a2b2a2b2a2","type":"user"}\n' > "$W2"; touch -m -d '40 seconds ago' "$W2"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "window twin older marked" "[Dup] WinT" "$(ft "$W1")"
chk "window twin newer kept (no custom-title)" "" "$(ft "$W2")"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "window verdict stable (bumped mtime must not steal the keep)" "[Dup] WinT" "$(ft "$W1")"
chk "window keeper stable" "" "$(ft "$W2")"

echo "--- same-run title writes void the copy-dup group skip (DIRTY_T) ---"
# TF carries a stale [Old Fork] whose superseder is gone; its REAL divergence
# heals it this run. The heal is a title write with a restored mtime, so the
# "T3" group (all members old, aged stamp) must still be re-judged THIS run:
# healed TF supersedes its stale sibling TY, which gets [Old Fork] at once.
# TN is unrelated fresh noise so the content arms run at all (pmax >= sm).
TF="$P/b5da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"T3"}\n{"uuid":"a3b30001-a3b3-a3b3-a3b3-a3b3a3b3a3b3","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"b3a30002-b3a3-b3a3-b3a3-b3a3b3a3b3a3","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"c3d30003-c3d3-c3d3-c3d3-c3d3c3d3c3d3","type":"user","message":{"role":"user","content":"more"}}\n{"type":"custom-title","customTitle":"[Old Fork] T3","sessionId":"x"}\n' > "$TF"; old "$TF"
TY="$P/b5da0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"T3"}\n{"uuid":"a3b30001-a3b3-a3b3-a3b3-a3b3a3b3a3b3","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"b3a30002-b3a3-b3a3-b3a3-b3a3b3a3b3a3","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n' > "$TY"; old "$TY"
TN="$P/d5da0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"FreshNoise"}\n{"uuid":"d3c30004-d3c3-d3c3-d3c3-d3c3d3c3d3c3","type":"user"}\n' > "$TN"
touch -m -d '40 seconds ago' "$T/.claude/fork-watch-sweep-stamp"
run
chk "stale mark healed (real divergence)" "T3" "$(ft "$TF")"
chk "group re-judged same run (title write voided the skip)" "[Old Fork] T3" "$(ft "$TY")"

echo "--- future-dated stamp: a clock step back must not suppress sweeps ---"
# The stamp sits 1h ahead of the clock (written before a clock resync — WSL
# does this after Windows sleep). Un-guarded, NOW-sm<30 reads true and every
# mtime reads "before the last sweep": the whole sweep is skipped and this
# dead row would never be judged until real time catches up.
mkjob f1da0001 "FutN" "f1da0001-0000-0000-0000-000000000001"
touch -m -d "@$(( $(date +%s) + 3600 ))" "$T/.claude/fork-watch-sweep-stamp"
run
chk "future stamp voided (dead row still judged)" "[Dead] FutN" "$(jn f1da0001)"

echo "--- sibling deletion: only the DIRECTORY mtime tells, heals must land ---"
# Pair: deleting the keeper orphans the marked loser's tail — the divergence
# heal must fire although no surviving FILE mtime moved. Trio: deleting the
# keeper of three identical twins leaves BOTH losers marked — the copy sweep
# must re-elect. Both gates key off mtimes; the deletion's only trace is the
# project directory's.
DP1="$P/a1aa0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"DelPair"}\n{"uuid":"aa910001-aa91-aa91-aa91-aa91aa91aa91","type":"user"}\n{"uuid":"ba910002-ba91-ba91-ba91-ba91ba91ba91","type":"user"}\n' > "$DP1"; touch -m -d '3 hours ago' "$DP1"
DP2="$P/a1aa0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"DelPair"}\n{"uuid":"aa910001-aa91-aa91-aa91-aa91aa91aa91","type":"user"}\n{"uuid":"ba910002-ba91-ba91-ba91-ba91ba91ba91","type":"user"}\n' > "$DP2"; touch -m -d '2 hours ago' "$DP2"
DQ1="$P/b1aa0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"DelTrio"}\n{"uuid":"ca910001-ca91-ca91-ca91-ca91ca91ca91","type":"user"}\n{"uuid":"da910002-da91-da91-da91-da91da91da91","type":"user"}\n' > "$DQ1"; touch -m -d '4 hours ago' "$DQ1"
DQ2="$P/b1aa0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"DelTrio"}\n{"uuid":"ca910001-ca91-ca91-ca91-ca91ca91ca91","type":"user"}\n{"uuid":"da910002-da91-da91-da91-da91da91da91","type":"user"}\n' > "$DQ2"; touch -m -d '3 hours ago' "$DQ2"
DQ3="$P/b1aa0003-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"DelTrio"}\n{"uuid":"ca910001-ca91-ca91-ca91-ca91ca91ca91","type":"user"}\n{"uuid":"da910002-da91-da91-da91-da91da91da91","type":"user"}\n' > "$DQ3"; touch -m -d '2 hours ago' "$DQ3"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "deletion pair: loser marked first" "[Dup] DelPair" "$(ft "$DP1")"
chk "deletion trio: older loser marked" "[Dup] DelTrio" "$(ft "$DQ1")"
chk "deletion trio: middle loser marked" "[Dup] DelTrio" "$(ft "$DQ2")"
# Delete the PAIR keeper, then make the deletion the ONLY signal: every
# recent file is aged, the stamp sits 40s back — a file-mtime-only gate
# would skip the divergence heal.
rm -f "$DP2"
find "$T/.claude" -type f -newermt '-60 seconds' ! -name 'fork-watch-sweep-stamp' -exec touch -m -d '2 hours ago' {} +
touch -m -d '40 seconds ago' "$T/.claude/fork-watch-sweep-stamp"
run
chk "deleted keeper: orphaned loser healed (dir mtime voided the gate)" "DelPair" "$(ft "$DP1")"
# The TRIO keeper goes in a separate quiet run: the pair heal above is a
# same-run title write (DIRTY_T) that would void the copy-dup group skip on
# its own — this run must have no title write, so only the directory mtime
# can re-open the group for the keeper re-election.
rm -f "$DQ3"
find "$T/.claude" -type f -newermt '-60 seconds' ! -name 'fork-watch-sweep-stamp' -exec touch -m -d '2 hours ago' {} +
touch -m -d '40 seconds ago' "$T/.claude/fork-watch-sweep-stamp"
run
chk "deleted trio keeper: re-elected keeper healed" "DelTrio" "$(ft "$DQ2")"
chk "deleted trio keeper: remaining loser keeps [Dup]" "[Dup] DelTrio" "$(ft "$DQ1")"

echo "--- [Dead]-prefixed TITLES on real transcripts heal (inherited row names) ---"
# The dead verdict is row-only; a [Dead]-prefixed TITLE is inherited marker
# text (Claude Code seeds a fork's ai-title from the marked row name).
DTA="$P/c1aa0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoDA"}\n{"uuid":"ea910001-ea91-ea91-ea91-ea91ea91ea91","type":"user"}\n{"type":"custom-title","customTitle":"[Dead] RealDA","sessionId":"x"}\n' > "$DTA"; old "$DTA"
DTB="$P/c1aa0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoDB"}\n{"uuid":"fa910002-fa91-fa91-fa91-fa91fa91fa91","type":"user"}\n{"type":"custom-title","customTitle":"[←Dead] RealDB","sessionId":"x"}\n' > "$DTB"; old "$DTB"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "[Dead]-titled real transcript healed" "RealDA" "$(ft "$DTA")"
chk "[←Dead]-titled real transcript healed (arrow dropped)" "RealDB" "$(ft "$DTB")"

echo "--- forked-on suffix: only the EXACT minted shape (by + 4 chars) strips ---"
FKN="$P/d1aa0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AutoFN"}\n{"uuid":"ab920001-ab92-ab92-ab92-ab92ab92ab92","type":"user"}\n{"type":"custom-title","customTitle":"[Old Fork] Shape - forked on 10:30 01.02.2025 by abcd (final)","sessionId":"x"}\n' > "$FKN"; old "$FKN"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "near-miss forked-on tail survives the heal" "Shape - forked on 10:30 01.02.2025 by abcd (final)" "$(ft "$FKN")"

echo "--- a custom-title line MISSING its field is ignored (cache/live parity) ---"
# Only a PRESENT empty string means revert; a null line must not erase the
# real custom title from the cache, or the [Stub] would land on the wrong base.
NCT="$P/abca0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"NullAuto"}\n{"type":"custom-title","customTitle":"KeepCT","sessionId":"x"}\n{"type":"custom-title","sessionId":"x"}\n' > "$NCT"; old "$NCT"
run
chk "null custom-title line ignored ([Stub] keeps the real base)" "[Stub] KeepCT" "$(ft "$NCT")"

echo "--- second project directory: globs must reach it ---"
P2="$T/.claude/projects/proj2"
mkdir -p "$P2"
# Dead sweep: the row's only transcript lives in proj2 — never [Dead].
FAR="$P2/adca0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"FarConv"}\n{"uuid":"bb920001-bb92-bb92-bb92-bb92bb92bb92","type":"user"}\n' > "$FAR"; old "$FAR"
mkjob adca0001 "FarRow" "adca0001-0000-0000-0000-000000000001"
# Row [Dup] heal arm: the same session is recorded in BOTH dirs; the proj1
# copy is unmarked but the proj2 copy still carries the group verdict (it is
# the marked loser of a proj2 twin pair) — the row's [Dup] must stay.
HM1="$P/aeca0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"ElseWhere"}\n{"uuid":"cb920001-cb92-cb92-cb92-cb92cb92cb92","type":"user"}\n' > "$HM1"; old "$HM1"
HM2="$P2/aeca0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"KeepFar"}\n{"uuid":"db920001-db92-db92-db92-db92db92db92","type":"user"}\n{"uuid":"eb920002-eb92-eb92-eb92-eb92eb92eb92","type":"user"}\n' > "$HM2"; touch -m -d '3 hours ago' "$HM2"
HM3="$P2/afca0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"KeepFar"}\n{"uuid":"db920001-db92-db92-db92-db92db92db92","type":"user"}\n{"uuid":"eb920002-eb92-eb92-eb92-eb92eb92eb92","type":"user"}\n' > "$HM3"; touch -m -d '2 hours ago' "$HM3"
mkjob aeca0001 "[Dup] FarKept" "aeca0001-0000-0000-0000-000000000001"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "second-project transcript keeps the row off [Dead]" "FarRow" "$(jn adca0001)"
chk "proj2 loser twin titled" "[Dup] KeepFar" "$(ft "$HM2")"
# The discriminating run is a QUIET one: when the copy sweep re-judges the
# proj2 group it re-marks the row itself, hiding a wrong heal. Age files,
# directories and stamp so the group is skipped — only the heal arm runs,
# and it must see the marked proj2 copy behind the unmarked proj1 one.
find "$T/.claude" -type f -newermt '-60 seconds' ! -name 'fork-watch-sweep-stamp' -exec touch -m -d '2 hours ago' {} +
touch -m -d '2 hours ago' "$P" "$P2"
touch -m -d '40 seconds ago' "$T/.claude/fork-watch-sweep-stamp"
run
chk "row [Dup] kept while ANY copy stays marked (proj2 loser)" "[Dup] FarKept" "$(jn aeca0001)"

echo "--- unreadable roster: fail closed, no sweeps at all ---"
# Both jq passes fail on a truncated roster. Every worker would read dead,
# so the sweeps must abstain entirely — the unprotected row stays unmarked
# until the roster is readable again.
cp "$T/.claude/daemon/roster.json" "$T/roster.save"
printf '{"workers":{"oops":' > "$T/.claude/daemon/roster.json"
mkjob baca0001 "NoProt" "baca0001-0000-0000-0000-000000000001"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "unreadable roster: sweeps abstain (no [Dead])" "NoProt" "$(jn baca0001)"
mv "$T/roster.save" "$T/.claude/daemon/roster.json"
run
chk "roster restored: the same row is judged normally" "[Dead] NoProt" "$(jn baca0001)"

echo "--- torn tail: an unterminated last line must not hide the divergence ---"
# TTA ends in a COMPLETE conversation entry with no trailing newline (a
# crash-torn flush). A naive reverse read glues that line onto the previous
# one, loses both to the JSON parser, and reads the conversation tail two
# entries early — TTA then looks mutual with the shorter TTB and the
# diverged, unique TTA takes the [Dup] as the older "twin".
TTA="$P/a3aa0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"TornT"}\n{"uuid":"aa930001-aa93-aa93-aa93-aa93aa93aa93","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"ba930002-ba93-ba93-ba93-ba93ba93ba93","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"ca930003-ca93-ca93-ca93-ca93ca93ca93","type":"user","message":{"role":"user","content":"more"}}' > "$TTA"; touch -m -d '3 hours ago' "$TTA"
TTB="$P/a3aa0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"TornT"}\n{"uuid":"aa930001-aa93-aa93-aa93-aa93aa93aa93","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"ba930002-ba93-ba93-ba93-ba93ba93ba93","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n' > "$TTB"; touch -m -d '1 hour ago' "$TTB"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "torn tail: the diverged file stays unmarked" "" "$(ft "$TTA")"
chk "torn tail: the behind sibling is superseded" "[Old Fork] TornT" "$(ft "$TTB")"

echo "--- torn husk: the file is terminated before a title is appended ---"
# The last line is valid JSON with no newline; a raw append would glue the
# [Stub] title onto it, corrupting the entry for every line-based reader.
THK="$P/b3aa0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"TornH"}' > "$THK"; old "$THK"
run
chk "torn husk: last line terminated before the append (line count)" "2" "$(wc -l < "$THK")"
chk "torn husk: [Stub] landed" "[Stub] TornH" "$(ft "$THK")"

echo "--- zero-byte roster: a torn truncate-then-write must fail closed ---"
# jq reads an empty file as empty output with exit 0 — without the size
# guard this loads an empty roster WITHOUT tripping the parse-failure path.
cp "$T/.claude/daemon/roster.json" "$T/roster.save"
: > "$T/.claude/daemon/roster.json"
mkjob bdca0001 "ZeroProt" "bdca0001-0000-0000-0000-000000000001"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "zero-byte roster: sweeps abstain (no [Dead])" "ZeroProt" "$(jn bdca0001)"
mv "$T/roster.save" "$T/.claude/daemon/roster.json"
run
chk "roster back: the row is judged normally" "[Dead] ZeroProt" "$(jn bdca0001)"

echo "--- unreadable transcript: existing-but-unreadable is not missing ---"
URT="$P/cdca0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"GuardT"}\n{"uuid":"da930004-da93-da93-da93-da93da93da93","type":"user"}\n' > "$URT"; old "$URT"
mkjob cdca0001 "Guarded" "cdca0001-0000-0000-0000-000000000001"
chmod 000 "$URT"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "unreadable transcript: row spared the [Dead]" "Guarded" "$(jn cdca0001)"
chmod 644 "$URT"

echo "--- backup copy next to a transcript: strays join no judgment ---"
# A manual "<sid>-copy.jsonl" is out of duplicate judgment entirely (round
# 12): as a group member it could win the keeper election by mtime — or
# read as AHEAD and supersede — putting the deletion-safe mark on the REAL
# session. The row-write charset guard (round 11) stays as depth.
BKR="$P/ddca0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"BackT"}\n{"uuid":"ea930005-ea93-ea93-ea93-ea93ea93ea93","type":"user"}\n{"uuid":"fa930006-fa93-fa93-fa93-fa93fa93fa93","type":"user"}\n' > "$BKR"; touch -m -d '1 hour ago' "$BKR"
BKC="$P/ddca0001-0000-0000-0000-000000000001-copy.jsonl"
printf '{"type":"ai-title","aiTitle":"BackT"}\n{"uuid":"ea930005-ea93-ea93-ea93-ea93ea93ea93","type":"user"}\n{"uuid":"fa930006-fa93-fa93-fa93-fa93fa93fa93","type":"user"}\n' > "$BKC"; touch -m -d '3 hours ago' "$BKC"
mkjob ddca0001 "BackReal" "ddca0001-0000-0000-0000-000000000001"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "backup copy is out of judgment (no title verdict)" "" "$(ft "$BKC")"
chk "the REAL transcript stays unmarked next to its backup" "" "$(ft "$BKR")"
chk "the REAL session's row is never touched by the copy" "BackReal" "$(jn ddca0001)"

echo "--- unreadable project directory: fail closed, no sweeps, no stamp ---"
# chmod 000 on a project directory hides every transcript in it from the
# globs, and absence-of-a-transcript is a load-bearing signal — without
# the guard the row below reads [Dead] while its conversation exists
# (D16, one level up from the unreadable-file row).
PDARK="$T/.claude/projects/proj-dark"
mkdir -p "$PDARK"
DPT="$PDARK/b8da0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"DarkT"}\n{"uuid":"aa960001-aa96-aa96-aa96-aa96aa96aa96","type":"user"}\n' > "$DPT"; old "$DPT"
mkjob b8da0001 "DarkProt" "b8da0001-0000-0000-0000-000000000001"
chmod 000 "$PDARK"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "dark directory: sweeps abstain (no [Dead])" "DarkProt" "$(jn b8da0001)"
chk "dark directory: no stamp written (fail closed)" "" "$(ls "$T/.claude/fork-watch-sweep-stamp" 2>/dev/null)"
chmod 755 "$PDARK"
run
chk "directory back: row stays clean and sweeps resume (stamp written)" "DarkProt $T/.claude/fork-watch-sweep-stamp" "$(jn b8da0001) $(ls "$T/.claude/fork-watch-sweep-stamp" 2>/dev/null)"

echo "--- row [Old Fork] outliving its title verdict: heal vs standing ---"
# Heal: the transcript was renamed in-session (unmarked custom title), so
# nothing backs the row's [Old Fork] any more — and no other sweep ever
# revisits it (divergence heals judge titles, the dead sweep heals only
# [Dead]). Standing: the transcript still carries the marker (its tail
# lives in an unmarked ahead sibling), so the row verdict stays.
RFH="$P/c8da0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"RenAI"}\n{"uuid":"ba960002-ba96-ba96-ba96-ba96ba96ba96","type":"user"}\n{"type":"custom-title","customTitle":"FreshName","sessionId":"c8da0001-0000-0000-0000-000000000001"}\n' > "$RFH"; old "$RFH"
mkjob c8da0001 "[Old Fork] Renamed" "c8da0001-0000-0000-0000-000000000001"
RFS1="$P/d8da0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"KeptG"}\n{"uuid":"ca960003-ca96-ca96-ca96-ca96ca96ca96","type":"user"}\n{"type":"custom-title","customTitle":"[Old Fork] KeptG","sessionId":"d8da0001-0000-0000-0000-000000000001"}\n' > "$RFS1"; old "$RFS1"
RFS2="$P/d8da0002-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"KeptG"}\n{"uuid":"ca960003-ca96-ca96-ca96-ca96ca96ca96","type":"user"}\n{"uuid":"da960004-da96-da96-da96-da96da96da96","type":"user"}\n' > "$RFS2"; old "$RFS2"
mkjob d8da0001 "[Old Fork] Kept" "d8da0001-0000-0000-0000-000000000001"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "stranded [Old Fork] row healed (title says renamed)" "Renamed" "$(jn c8da0001)"
chk "standing [Old Fork] row keeps its verdict (title still marked)" "[Old Fork] Kept" "$(jn d8da0001)"
chk "the marked copy stays marked (unmarked sibling holds its tail)" "[Old Fork] KeptG" "$(ft "$RFS1")"

echo "--- every copy marked, different title groups: holders must be unmarked ---"
# Identical copies whose unmarked keeper was deleted: each holds the
# other's tail, but a marked holder is no keeper (D15) — both heal. The
# copy sweep cannot re-elect across different titles, so without the
# holder rule both would sit deletion-safe forever.
HX="$P/e8da0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"HoldA"}\n{"uuid":"ea960005-ea96-ea96-ea96-ea96ea96ea96","type":"user"}\n{"uuid":"fa960006-fa96-fa96-fa96-fa96fa96fa96","type":"user"}\n{"type":"custom-title","customTitle":"[Old Fork] HoldA","sessionId":"e8da0001-0000-0000-0000-000000000001"}\n' > "$HX"; old "$HX"
HY="$P/f8da0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"HoldB"}\n{"uuid":"ea960005-ea96-ea96-ea96-ea96ea96ea96","type":"user"}\n{"uuid":"fa960006-fa96-fa96-fa96-fa96fa96fa96","type":"user"}\n{"type":"custom-title","customTitle":"[Old Fork] HoldB","sessionId":"f8da0001-0000-0000-0000-000000000001"}\n' > "$HY"; old "$HY"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "all-marked pair: first copy healed" "HoldA" "$(ft "$HX")"
chk "all-marked pair: second copy healed" "HoldB" "$(ft "$HY")"

echo "--- alien row: a transcript verdict never lands on a row serving another session ---"
# The row folder matches the OLD transcript's prefix, but .sessionId says
# the row serves a different session now (the post-repair shape): the
# copy sweep's [Old Fork] on the old transcript must not touch it.
ALA="$P/b9da0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"AlienG"}\n{"uuid":"ab960007-ab96-ab96-ab96-ab96ab96ab96","type":"user"}\n' > "$ALA"; old "$ALA"
ALB="$P/b9da0002-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"AlienG"}\n{"uuid":"ab960007-ab96-ab96-ab96-ab96ab96ab96","type":"user"}\n{"uuid":"bb960008-bb96-bb96-bb96-bb96bb96bb96","type":"user"}\n' > "$ALB"; old "$ALB"
ALC="$P/c9da0001-0000-0000-0000-000000000001.jsonl"
printf '{"type":"ai-title","aiTitle":"AlienHome"}\n{"uuid":"cb960009-cb96-cb96-cb96-cb96cb96cb96","type":"user"}\n' > "$ALC"; old "$ALC"
mkjob b9da0001 "AlienKeep" "c9da0001-0000-0000-0000-000000000001"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
chk "alien row keeps its name despite the transcript verdict" "AlienKeep" "$(jn b9da0001)"
chk "the old transcript still takes its title verdict" "[Old Fork] AlienG" "$(ft "$ALA")"

echo "--- hook mode: the session's own transcript is live by definition ---"
# The hook fires inside session HA while a sibling HB supersedes it. Every
# title-writing sweep skips $tpath explicitly, but copy-dups keeps it as
# group evidence — it must never FINALLY mark it (D6), however idle the file.
HA="$P/abad0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"HookT"}\n{"uuid":"a6b60001-a6b6-a6b6-a6b6-a6b6a6b6a6b6","type":"user"}\n{"uuid":"b6a60002-b6a6-b6a6-b6a6-b6a6b6a6b6a6","type":"user"}\n' > "$HA"; old "$HA"
HB="$P/abad0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"HookT"}\n{"uuid":"a6b60001-a6b6-a6b6-a6b6-a6b6a6b6a6b6","type":"user"}\n{"uuid":"b6a60002-b6a6-b6a6-b6a6-b6a6b6a6b6a6","type":"user"}\n{"uuid":"c6d60003-c6d6-c6d6-c6d6-c6d6c6d6c6d6","type":"user"}\n' > "$HB"; old "$HB"
printf '{"session_id":"abad0001-0000-0000-0000-000000000000","source":"resume","transcript_path":"%s"}' "$HA" | bash "$T/fw.sh" > /dev/null
hrc=$?
if [ "$hrc" -ne 0 ]; then
  printf 'FAIL hook-mode run exited rc=%s\n' "$hrc"
  fails=$((fails + 1))
fi
chk "hook mode: own superseded file never finally marked" "" "$(ft "$HA")"
chk "hook mode: the ahead sibling stays untouched" "" "$(ft "$HB")"

echo "--- hook mode: clear-source rollover (uuid heuristic) + seen marker ---"
CP="$P/aeea0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"ClearP"}\n{"uuid":"a9b90001-a9b9-a9b9-a9b9-a9b9a9b9a9b9","type":"user"}\n{"uuid":"b9a90002-b9a9-b9a9-b9a9-b9a9b9a9b9a9","type":"user"}\n' > "$CP"; touch -m -d '10 minutes ago' "$CP"
CC="$P/beea0001-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"a9b90001-a9b9-a9b9-a9b9-a9b9a9b9a9b9","type":"user"}\n{"uuid":"b9a90002-b9a9-b9a9-b9a9-b9a9b9a9b9a9","type":"user"}\n' > "$CC"
hout=$(printf '{"session_id":"beea0001-0000-0000-0000-000000000000","source":"clear","transcript_path":"%s"}' "$CC" | bash "$T/fw.sh")
case "$hout" in
  *'"systemMessage"'*'FORK (source: clear)'*) printf 'ok   hook mode: fork message emitted\n' ;;
  *) printf 'FAIL hook mode: fork message emitted: got "%s"\n' "$hout"; fails=$((fails + 1)) ;;
esac
case "$(ft "$CP")" in
  '[Old Fork] ClearP - forked on '*' by beea') printf 'ok   hook mode: parent renamed: %s\n' "$(ft "$CP")" ;;
  *) printf 'FAIL hook mode: parent renamed: got "%s"\n' "$(ft "$CP")"; fails=$((fails + 1)) ;;
esac
hout2=$(printf '{"session_id":"beea0001-0000-0000-0000-000000000000","source":"clear","transcript_path":"%s"}' "$CC" | bash "$T/fw.sh")
chk "hook mode: seen marker suppresses a repeat" "" "$hout2"

echo "--- hook mode: read-only parent — title verdict must back the row verdict ---"
# The parent rename fails on a read-only transcript; the fallback message
# must fire and the parent's ROW must stay unmarked (a row-only [Old Fork]
# with no title verdict behind it is a strand no heal revisits).
PRO="$P/deea0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"ClearROT"}\n{"uuid":"da940001-da94-da94-da94-da94da94da94","type":"user"}\n{"uuid":"ea940002-ea94-ea94-ea94-ea94ea94ea94","type":"user"}\n' > "$PRO"; touch -m -d '10 minutes ago' "$PRO"
PCC="$P/eeea0001-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"da940001-da94-da94-da94-da94da94da94","type":"user"}\n{"uuid":"ea940002-ea94-ea94-ea94-ea94ea94ea94","type":"user"}\n' > "$PCC"
mkjob deea0001 "ClearRO" "deea0001-0000-0000-0000-000000000000"
chmod 444 "$PRO"
hout5=$(printf '{"session_id":"eeea0001-0000-0000-0000-000000000000","source":"clear","transcript_path":"%s"}' "$PCC" | bash "$T/fw.sh")
case "$hout5" in
  *'could not be renamed'*) printf 'ok   hook mode: fallback message on a read-only parent\n' ;;
  *) printf 'FAIL hook mode: fallback message on a read-only parent: got "%s"\n' "$hout5"; fails=$((fails + 1)) ;;
esac
chk "hook mode: read-only parent keeps its row unmarked" "ClearRO" "$(jn deea0001)"
chmod 644 "$PRO"

echo "--- hook mode: roster-declared fresh fork shell + malformed stdin ---"
SH="$P/ceea0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"ShellH"}\n' > "$SH"
cat > "$T/.claude/daemon/roster.json" <<EOF4
{"workers":{
 "ceea0001":{"pid":99999950,"startedAt":1000,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$CP"}}}
}}
EOF4
hout3=$(printf '{"session_id":"ceea0001-0000-0000-0000-000000000000","source":"resume","transcript_path":"%s"}' "$SH" | bash "$T/fw.sh")
case "$hout3" in
  *'fresh fork shell'*) printf 'ok   hook mode: shell message emitted\n' ;;
  *) printf 'FAIL hook mode: shell message emitted: got "%s"\n' "$hout3"; fails=$((fails + 1)) ;;
esac
hout4=$(printf 'not json' | bash "$T/fw.sh"); hrc4=$?
chk "hook mode: malformed stdin exits quiet" "" "$hout4"
if [ "$hrc4" -ne 0 ]; then
  printf 'FAIL hook mode: malformed stdin rc=%s\n' "$hrc4"
  fails=$((fails + 1))
fi

echo "---"
if [ "$fails" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "$fails FAILURES"
  exit 1
fi
