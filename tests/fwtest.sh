#!/bin/bash
# Fixture test for the refactored fork-watch sweeps (cache-based, --sweep-only).
: "${TMPDIR:=/tmp}"
T="$TMPDIR/fwtest-root"
rm -rf "$T"
mkdir -p "$T/.claude/projects/proj1" "$T/.claude/daemon"
sed "s|\$HOME|$T|g" "$(dirname "$0")/../fork-watch.sh" > "$T/fw.sh"

P="$T/.claude/projects/proj1"
old() { touch -m -d '2 hours ago' "$1"; }
uu() { printf '%s' "$1$1$1$1$1$1$1$1-$1$1$1$1-$1$1$1$1-$1$1$1$1-$1$1$1$1$1$1$1$1$1$1$1$1"; }

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

# --- keeper-heal: newer twin carries a stale [Dup] from an earlier run ---
G1="$P/gggg0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"Twin2"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$(uu c)" "$(uu d)" > "$G1"; touch -m -d '3 hours ago' "$G1"
G2="$P/gggg0002-0000-0000-0000-000000000000.jsonl"
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

# --- jobs registry ---
mkjob() { mkdir -p "$T/.claude/jobs/$1"; printf '{"name":"%s","sessionId":"%s"}\n' "$2" "$3" > "$T/.claude/jobs/$1/state.json"; touch -m -d '1 hour ago' "$T/.claude/jobs/$1/state.json"; }
mkjob bbbb1111 "Global" "bbbb1111-0000-0000-0000-000000000001"   # at-rest twin, older
mkjob cccc2222 "Global" "cccc2222-0000-0000-0000-000000000001"   # at-rest twin, newer -> keeper
mkjob dddd3333 "Solo"   "dddd3333-0000-0000-0000-000000000001"   # sole at-rest fork
mkjob eeee4444 "Seam"   "eeee4444-0000-0000-0000-000000000001"   # at-rest, carrier exists
mkjob ffff5555 "Deady"  "ffff5555-0000-0000-0000-000000000001"   # no transcript, no roster
mkjob aaaa0000 "Carrier" "aaaa0000-0000-0000-0000-000000000000"  # carrier (real transcript)
# corrupt job early in glob order: must not blind load_jobs to the later jobs
mkdir -p "$T/.claude/jobs/aaaa0001"; printf 'not json at all' > "$T/.claude/jobs/aaaa0001/state.json"; touch -m -d '1 hour ago' "$T/.claude/jobs/aaaa0001/state.json"

# --- roster: at-rest resume forks (dead pids -> respawnable via launch source) ---
cat > "$T/.claude/daemon/roster.json" <<EOF
{"workers":{
 "bbbb1111":{"pid":99999901,"startedAt":100,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}},
 "cccc2222":{"pid":99999902,"startedAt":200,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PA"}}},
 "dddd3333":{"pid":99999903,"startedAt":300,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PB"}}},
 "eeee4444":{"pid":99999904,"startedAt":400,"dispatch":{"launch":{"mode":"resume","fork":true,"sessionId":"$PC"}}}
}}
EOF

run() { bash "$T/fw.sh" --sweep-only; }
jn() { jq -r '.name' "$T/.claude/jobs/$1/state.json"; }
ft() { grep -F '"type":"custom-title"' "$1" 2>/dev/null | jq -r 'select(.type=="custom-title").customTitle' | tail -1; }

run
echo "--- pass 1 ---"
echo "twin older   (want [Dup] Global): $(jn bbbb1111)"
echo "twin newer   (want Global):       $(jn cccc2222)"
echo "sole fork    (want Solo):         $(jn dddd3333)"
echo "seam carrier (want [Dup] Seam):   $(jn eeee4444)"
echo "dead job     (want [Dead] Deady): $(jn ffff5555)"
echo "carrier job  (want Carrier):      $(jn aaaa0000)"
echo "stub husk    (want [Stub] Stubby): $(ft "$ST")"
echo "superseded   (want [Old Fork] Copy): $(ft "$F1")"
echo "longer copy  (want no custom-title): $(ft "$F2")"
echo "twin t1      (want [Dup] Twin):   $(ft "$T1")"
echo "twin t2      (want no custom-title): $(ft "$T2")"
echo "heal stub    (want Real):         $(ft "$HR")"
echo "heal oldfork (want Div):          $(ft "$HD")"
echo "seam parent  (want no custom-title; distinct title, seam only marks the shell): $(ft "$PC")"
echo "keeper twin  (want Twin2 healed):  $(ft "$G2")"
echo "loser twin   (want [Dup] Twin2):  $(ft "$G1")"
echo "bare token real (want addd0001):  $(ft "$BT1")"
echo "bare token husk (want [Stub] beef0001): $(ft "$BT2")"
echo "fresh superseded (want [Old Fork] CopyC, marked on FIRST pass): $(ft "$F3")"
echo "noisy superset older (want [Dup] NoisyT, junk-only extras = twins): $(ft "$NF1")"
echo "noisy superset newer (want no custom-title): $(ft "$NF2")"
echo "reversed noisy: junk superset older (want [Dup] NoisyR): $(ft "$RN2")"
echo "reversed noisy: clean newer (want no custom-title): $(ft "$RN1")"
echo "gap trio base (want [Old Fork] GapT): $(ft "$GF")"
echo "gap trio junk superset (want [Old Fork] GapT, no unmarked slip): $(ft "$GG")"
echo "gap trio diverged (want no custom-title): $(ft "$GH")"

sum1=$(find "$T/.claude" -type f -exec md5sum {} + | sort)
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
sum2=$(find "$T/.claude" -type f -exec md5sum {} + | sort)
echo "--- pass 2 stability (stamp removed, full resweep) ---"
if [ "$sum1" = "$sum2" ]; then echo "STABLE: second run changed nothing"; else echo "UNSTABLE:"; diff <(echo "$sum1") <(echo "$sum2"); fi

echo "--- aged stamp: sweeps run but unchanged content is skipped ---"
touch -m -d '40 seconds ago' "$T/.claude/fork-watch-sweep-stamp"
sum2b=$(find "$T/.claude" -type f -exec md5sum {} + | sort)
run
sum2c=$(find "$T/.claude" -type f -exec md5sum {} + | sort)
if [ "$sum2b" = "$sum2c" ]; then echo "STABLE: aged-stamp run changed nothing"; else echo "UNSTABLE:"; diff <(echo "$sum2b") <(echo "$sum2c"); fi

echo "--- stamp skip + heal ---"
jq '.name="[Dead] Global"' "$T/.claude/jobs/cccc2222/state.json" > "$T/x" && mv "$T/x" "$T/.claude/jobs/cccc2222/state.json"
touch -m -d '1 hour ago' "$T/.claude/jobs/cccc2222/state.json"
run
echo "fresh stamp  (want [Dead] Global untouched, sweeps skipped): $(jn cccc2222)"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
echo "stamp gone   (want Global healed): $(jn cccc2222)"

echo "--- fresh stamp + new write: first-open marks override the skip ---"
LU1="0a0a0a0a-0a0a-0a0a-0a0a-0a0a0a0a0a0a"
LU2="a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0"
LF1="$P/fade0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"LateT"}\n{"uuid":"%s","type":"user"}\n' "$LU1" > "$LF1"; old "$LF1"
LF2="$P/fade0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"LateT"}\n{"uuid":"%s","type":"user"}\n{"uuid":"%s","type":"user"}\n' "$LU1" "$LU2" > "$LF2"
run
echo "late flush   (want [Old Fork] LateT despite fresh stamp): $(ft "$LF1")"

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
echo "streaming twin (want no custom-title, write in progress): $(ft "$SP2")"
kill "$wpid" 2>/dev/null; wait "$wpid" 2>/dev/null
old "$SP2"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
echo "stopped twin  (want [Old Fork] StreamT): $(ft "$SP2")"
