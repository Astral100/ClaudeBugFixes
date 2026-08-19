#!/bin/bash
# Unit test for set_job_marker's cache-staleness guard: a rename that lands
# after load_jobs must not be clobbered by the stale cached name.
T="$TMPDIR/fwtest-root"
source <(sed -n '/^parse_markers/,/^# Sweeps run first/p' "$T/fw.sh" | head -n -1)
sid= src= tpath=
load_roster
load_jobs
echo "cached name: ${J_NAME[cccc2222]}"
# daemon/user renames the job AFTER the cache was loaded
jq '.name="UserRenamed"' "$T/.claude/jobs/cccc2222/state.json" > "$T/y" && mv "$T/y" "$T/.claude/jobs/cccc2222/state.json"
set_job_marker "cccc2222-0000-0000-0000-000000000001" "[Dup] "
echo "after marking (want [Dup] UserRenamed, NOT [Dup] Global): $(jq -r '.name' "$T/.claude/jobs/cccc2222/state.json")"
# and a no-op heal against the now-updated cache must keep the fresh base
set_job_marker "cccc2222-0000-0000-0000-000000000001" ""
echo "after heal (want UserRenamed): $(jq -r '.name' "$T/.claude/jobs/cccc2222/state.json")"
