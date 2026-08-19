#!/bin/bash
# Fixture test for the refactored fork-watch sweeps (cache-based, --sweep-only).
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

sum1=$(find "$T/.claude" -type f -exec md5sum {} + | sort)
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
sum2=$(find "$T/.claude" -type f -exec md5sum {} + | sort)
echo "--- pass 2 stability (stamp removed, full resweep) ---"
if [ "$sum1" = "$sum2" ]; then echo "STABLE: second run changed nothing"; else echo "UNSTABLE:"; diff <(echo "$sum1") <(echo "$sum2"); fi

echo "--- stamp skip + heal ---"
jq '.name="[Dead] Global"' "$T/.claude/jobs/cccc2222/state.json" > "$T/x" && mv "$T/x" "$T/.claude/jobs/cccc2222/state.json"
touch -m -d '1 hour ago' "$T/.claude/jobs/cccc2222/state.json"
run
echo "fresh stamp  (want [Dead] Global untouched, sweeps skipped): $(jn cccc2222)"
rm -f "$T/.claude/fork-watch-sweep-stamp"
run
echo "stamp gone   (want Global healed): $(jn cccc2222)"
