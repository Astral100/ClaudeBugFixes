#!/bin/bash
# Unit test for set_job_marker's cache-staleness guard: a rename that lands
# after load_jobs must not be clobbered by the stale cached name.
# Run tests/fwtest.sh first — it builds the fixture tree this test mutates.
: "${TMPDIR:=/tmp}"
T="$TMPDIR/fwtest-root"
if [ ! -f "$T/fw.sh" ]; then
  echo "FAIL: fixture tree missing — run tests/fwtest.sh first"
  exit 1
fi

fails=0
chk() { # $1 = label, $2 = want, $3 = got
  if [ "$3" = "$2" ]; then
    printf 'ok   %s: %s\n' "$1" "$3"
  else
    printf 'FAIL %s: want "%s" got "%s"\n' "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}

source <(sed -n '/^parse_markers/,/^# Sweeps run first/p' "$T/fw.sh" | head -n -1)
sid= src= tpath=
load_roster
load_jobs
echo "cached name: ${J_NAME[cccc2222]}"
# daemon/user renames the job AFTER the cache was loaded
jq '.name="UserRenamed"' "$T/.claude/jobs/cccc2222/state.json" > "$T/y" && mv "$T/y" "$T/.claude/jobs/cccc2222/state.json"
set_job_marker "cccc2222-0000-0000-0000-000000000001" "[Dup] "
chk "after marking (stale cache re-derived, rename kept)" "[Dup] UserRenamed" "$(jq -r '.name' "$T/.claude/jobs/cccc2222/state.json")"
# and a no-op heal against the now-updated cache must keep the fresh base
set_job_marker "cccc2222-0000-0000-0000-000000000001" ""
chk "after heal" "UserRenamed" "$(jq -r '.name' "$T/.claude/jobs/cccc2222/state.json")"
# repair_job_row shares the guard: a daemon rewrite after the cache load must
# make the repointing write refuse, not clobber the fresh state.
jq '.name="UserRenamed2"' "$T/.claude/jobs/cccc2222/state.json" > "$T/y" && mv "$T/y" "$T/.claude/jobs/cccc2222/state.json"
repair_job_row "cccc2222" "99990000-0000-0000-0000-000000000000" "/nonexistent" "hijacked" 2>/dev/null
chk "repair guard (stale cache refused)" "UserRenamed2" "$(jq -r '.name' "$T/.claude/jobs/cccc2222/state.json")"

# rename_parent on a TITLELESS parent: the fallback base must be the short
# session id (a minted phrase would read human after a heal and block sync),
# and the heal must strip exactly the minted suffix back to that short id.
TLP="$T/.claude/projects/proj1/eaea0001-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"aeae0001-aeae-aeae-aeae-aeaeaeaeaeae","type":"user"}\n' > "$TLP"
sid="bfbf0001-0000-0000-0000-000000000000"
nt=$(rename_parent "$TLP")
case "$nt" in
  "[Old Fork] eaea0001 - forked on "*) printf 'ok   titleless parent gets its short id as base: %s\n' "$nt" ;;
  *) printf 'FAIL titleless parent base: got "%s"\n' "$nt"; fails=$((fails + 1)) ;;
esac
retitle "$TLP" ""
chk "heal strips the minted suffix back to the short id" "eaea0001" "$(grep -F '"type":"custom-title"' "$TLP" | jq -r '.customTitle' | tail -1)"

if [ "$fails" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "$fails FAILURES"
  exit 1
fi
