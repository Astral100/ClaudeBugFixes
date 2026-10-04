#!/bin/bash
# Fixture test for fork-watch-end.sh (the SessionEnd hook): supersede marking
# on both the transcript title and the job-row name, the junk-tail retry, the
# no-successor guard, and the titleless short-id fallback. Self-contained —
# builds its own tree, independent of fwtest.sh.
: "${TMPDIR:=/tmp}"
T="$TMPDIR/fwendtest-root"
rm -rf "$T"
mkdir -p "$T/.claude/projects/projE" "$T/.claude/jobs/aeaf0001"
sed "s|\$HOME|$T|g" "$(dirname "$0")/../fork-watch-end.sh" > "$T/fwe.sh"
# Deterministic umask for the permission assertion below.
umask 022
P="$T/.claude/projects/projE"

fails=0
chk() { # $1 = label, $2 = want, $3 = got
  if [ "$3" = "$2" ]; then
    printf 'ok   %s: %s\n' "$1" "$3"
  else
    printf 'FAIL %s: want "%s" got "%s"\n' "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}
ft() { grep -F '"type":"custom-title"' "$1" 2>/dev/null | jq -r 'select(.type=="custom-title").customTitle' | tail -1; }
hook() {
  # Every hook invocation asserts exit 0 too: the empty-output chks below
  # would otherwise also pass on a crashed hook.
  printf '{"session_id":"%s","transcript_path":"%s"}' "$1" "$2" | bash "$T/fwe.sh"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'FAIL hook exited rc=%s (%s)\n' "$rc" "$1"
    fails=$((fails + 1))
  fi
}

# Named supersede: first AND last uuid live on in a successor -> [Old Fork]
# on the title and the row name.
A="$P/aeaf0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"EndT"}\n{"uuid":"11ee11ee-11ee-11ee-11ee-11ee11ee11ee","type":"user"}\n{"uuid":"22ee22ee-22ee-22ee-22ee-22ee22ee22ee","type":"user"}\n' > "$A"
B="$P/beaf0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"EndT"}\n{"uuid":"11ee11ee-11ee-11ee-11ee-11ee11ee11ee","type":"user"}\n{"uuid":"22ee22ee-22ee-22ee-22ee-22ee22ee22ee","type":"user"}\n{"uuid":"33ee33ee-33ee-33ee-33ee-33ee33ee33ee","type":"user"}\n' > "$B"
printf '{"name":"EndT","sessionId":"aeaf0001-0000-0000-0000-000000000000"}\n' > "$T/.claude/jobs/aeaf0001/state.json"
# Daemon rows can be 0600; the supersede rewrite must not loosen the mode.
chmod 600 "$T/.claude/jobs/aeaf0001/state.json"
hook "aeaf0001-0000-0000-0000-000000000000" "$A"
chk "superseded title" "[Old Fork] EndT" "$(ft "$A")"
chk "superseded row name" "[Old Fork] EndT" "$(jq -r '.name' "$T/.claude/jobs/aeaf0001/state.json")"
chk "supersede write keeps 0600" "600" "$(stat -c %a "$T/.claude/jobs/aeaf0001/state.json")"

# Junk tail: the raw last uuid exists only here (a system-reminder entry);
# the retry on the last CONVERSATION uuid must still find the successor.
F="$P/ceaf0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"JunkT"}\n{"uuid":"55ee55ee-55ee-55ee-55ee-55ee55ee55ee","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"66ee66ee-66ee-66ee-66ee-66ee66ee66ee","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"77ee77ee-77ee-77ee-77ee-77ee77ee77ee","type":"user","message":{"role":"user","content":"<system-reminder> renamed"}}\n' > "$F"
G="$P/deaf0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"JunkT"}\n{"uuid":"55ee55ee-55ee-55ee-55ee-55ee55ee55ee","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"66ee66ee-66ee-66ee-66ee-66ee66ee66ee","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"88ee88ee-88ee-88ee-88ee-88ee88ee88ff","type":"user","message":{"role":"user","content":"q2"}}\n' > "$G"
hook "ceaf0001-0000-0000-0000-000000000000" "$F"
chk "junk-tail supersede (judged on the conversation uuid)" "[Old Fork] JunkT" "$(ft "$F")"

# No successor: unique conversation -> untouched.
C="$P/eeaf0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"LoneT"}\n{"uuid":"88ee88ee-88ee-88ee-88ee-88ee88ee88ee","type":"user"}\n' > "$C"
hook "eeaf0001-0000-0000-0000-000000000000" "$C"
chk "no successor (no custom-title)" "" "$(ft "$C")"

# Titleless transcript: the fallback base is the SHORT SESSION ID (replaceable
# by row-name sync later), never a minted phrase that reads human.
D="$P/feaf0001-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"99ee99ee-99ee-99ee-99ee-99ee99ee99ee","type":"user"}\n' > "$D"
E="$P/feaf0002-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"99ee99ee-99ee-99ee-99ee-99ee99ee99ee","type":"user"}\n{"uuid":"aaeeaaee-aaee-aaee-aaee-aaeeaaeeaaee","type":"user"}\n' > "$E"
hook "feaf0001-0000-0000-0000-000000000000" "$D"
chk "titleless fallback is the short id" "[Old Fork] feaf0001" "$(ft "$D")"

# Arrow tag: a row name already carrying the "←" left-press tag keeps it
# inside the upgraded marker; the transcript title stays plain.
H="$P/cafe0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"ArrowT"}\n{"uuid":"c0ee0001-c0ee-c0ee-c0ee-c0eec0eec0ee","type":"user"}\n{"uuid":"d0ee0002-d0ee-d0ee-d0ee-d0eed0eed0ee","type":"user"}\n' > "$H"
I="$P/cafe0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"ArrowT"}\n{"uuid":"c0ee0001-c0ee-c0ee-c0ee-c0eec0eec0ee","type":"user"}\n{"uuid":"d0ee0002-d0ee-d0ee-d0ee-d0eed0eed0ee","type":"user"}\n{"uuid":"e0ee0003-e0ee-e0ee-e0ee-e0eee0eee0ee","type":"user"}\n' > "$I"
mkdir -p "$T/.claude/jobs/cafe0001"
printf '{"name":"[←Dup] ArrowT","sessionId":"cafe0001-0000-0000-0000-000000000000"}\n' > "$T/.claude/jobs/cafe0001/state.json"
hook "cafe0001-0000-0000-0000-000000000000" "$H"
chk "arrow rides the row upgrade" "[←Old Fork] ArrowT" "$(jq -r '.name' "$T/.claude/jobs/cafe0001/state.json")"
chk "transcript title stays plain" "[Old Fork] ArrowT" "$(ft "$H")"

# Lone-surrogate row: the job row's JSON carries the \udXXX escape jq 1.6
# rejects (a well-formed writer truncating text mid-emoji mints one); the
# supersede row write must still land via the sanitized retry.
S1="$P/fdda0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SurT"}\n{"uuid":"d7e70001-d7e7-d7e7-d7e7-d7e7d7e7d7e7","type":"user"}\n{"uuid":"e7f70002-e7f7-e7f7-e7f7-e7f7e7f7e7f7","type":"user"}\n' > "$S1"
S2="$P/fdda0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"SurT"}\n{"uuid":"d7e70001-d7e7-d7e7-d7e7-d7e7d7e7d7e7","type":"user"}\n{"uuid":"e7f70002-e7f7-e7f7-e7f7-e7f7e7f7e7f7","type":"user"}\n{"uuid":"a7f70003-a7f7-a7f7-a7f7-a7f7a7f7a7f7","type":"user"}\n' > "$S2"
mkdir -p "$T/.claude/jobs/fdda0001"
printf '{"name":"SurEnd","sessionId":"fdda0001-0000-0000-0000-000000000000","intent":"%s"}\n' 'x\ud83d' > "$T/.claude/jobs/fdda0001/state.json"
hook "fdda0001-0000-0000-0000-000000000000" "$S1"
chk "surrogate row takes the supersede write" "[Old Fork] SurEnd" "$(jq -r '.name' "$T/.claude/jobs/fdda0001/state.json")"

# Identical twin: the sibling holds our first AND last uuid but nothing
# beyond — not a successor. The ending twin stays unmarked on title AND row
# (the sweep's keeper election is the only twin judge; marking here could
# leave every copy of the conversation deletion-safe).
N="$P/fade0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"TwinT"}\n{"uuid":"d0ff0008-d0ff-d0ff-d0ff-d0ffd0ffd0ff","type":"user"}\n{"uuid":"e0ff0009-e0ff-e0ff-e0ff-e0ffe0ffe0ff","type":"user"}\n' > "$N"
O="$P/fade0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"TwinT"}\n{"uuid":"d0ff0008-d0ff-d0ff-d0ff-d0ffd0ffd0ff","type":"user"}\n{"uuid":"e0ff0009-e0ff-e0ff-e0ff-e0ffe0ffe0ff","type":"user"}\n' > "$O"
mkdir -p "$T/.claude/jobs/fade0001"
printf '{"name":"TwinR","sessionId":"fade0001-0000-0000-0000-000000000000"}\n' > "$T/.claude/jobs/fade0001/state.json"
hook "fade0001-0000-0000-0000-000000000000" "$N"
chk "identical twin is not a successor (title)" "" "$(ft "$N")"
chk "identical twin is not a successor (row)" "TwinR" "$(jq -r '.name' "$T/.claude/jobs/fade0001/state.json")"

# Junk-ahead sibling: its only extra entry is junk (a system-reminder-only
# user entry), so the conversations are identical — still a twin, still no
# mark, judged on the sibling's last CONVERSATION uuid.
Q="$P/ebed0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"JTwin"}\n{"uuid":"a0ee0010-a0ee-a0ee-a0ee-a0eea0eea0ee","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"b0ee0011-b0ee-b0ee-b0ee-b0eeb0eeb0ee","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n' > "$Q"
R="$P/ebed0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"JTwin"}\n{"uuid":"a0ee0010-a0ee-a0ee-a0ee-a0eea0eea0ee","type":"user","message":{"role":"user","content":"q"}}\n{"uuid":"b0ee0011-b0ee-b0ee-b0ee-b0eeb0eeb0ee","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"a"}]}}\n{"uuid":"c0ee0012-c0ee-c0ee-c0ee-c0eec0eec0ee","type":"user","message":{"role":"user","content":"<system-reminder> renamed"}}\n' > "$R"
hook "ebed0001-0000-0000-0000-000000000000" "$Q"
chk "junk-ahead sibling is not a successor" "" "$(ft "$Q")"

# Malformed session id: rejected by the charset guard before anything is
# read or written — the id feeds a jobs-registry path and the short-id title
# fallbacks. The transcript HAS a superseding sibling, so without the guard
# the hook would mark it.
L="$P/beef0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"IdT"}\n{"uuid":"b0ff0006-b0ff-b0ff-b0ff-b0ffb0ffb0ff","type":"user"}\n' > "$L"
M="$P/beef0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"IdT"}\n{"uuid":"b0ff0006-b0ff-b0ff-b0ff-b0ffb0ffb0ff","type":"user"}\n{"uuid":"c0ff0007-c0ff-c0ff-c0ff-c0ffc0ffc0ff","type":"user"}\n' > "$M"
hook "../../../x" "$L"
chk "malformed sid is rejected untouched" "" "$(ft "$L")"

# Nameless row: the row-name fallback is the short id too.
J="$P/dada0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"NoNameRow"}\n{"uuid":"f0ee0004-f0ee-f0ee-f0ee-f0eef0eef0ee","type":"user"}\n' > "$J"
K="$P/dada0002-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"NoNameRow"}\n{"uuid":"f0ee0004-f0ee-f0ee-f0ee-f0eef0eef0ee","type":"user"}\n{"uuid":"a0ff0005-a0ff-a0ff-a0ff-a0ffa0ffa0ff","type":"user"}\n' > "$K"
mkdir -p "$T/.claude/jobs/dada0001"
printf '{"sessionId":"dada0001-0000-0000-0000-000000000000"}\n' > "$T/.claude/jobs/dada0001/state.json"
hook "dada0001-0000-0000-0000-000000000000" "$J"
chk "nameless row falls back to the short id" "[Old Fork] dada0001" "$(jq -r '.name' "$T/.claude/jobs/dada0001/state.json")"

# Arrow tag is for real markers only: a USER name that merely begins with
# the arrow text must come out "[Old Fork] <name>", never arrow-tagged.
U1="$P/adad0003-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"UserArrowT"}\n{"uuid":"f0aa0001-f0aa-f0aa-f0aa-f0aaf0aaf0aa","type":"user"}\n{"uuid":"a0bb0002-a0bb-a0bb-a0bb-a0bba0bba0bb","type":"user"}\n' > "$U1"
U2="$P/adad0004-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"UserArrowT"}\n{"uuid":"f0aa0001-f0aa-f0aa-f0aa-f0aaf0aaf0aa","type":"user"}\n{"uuid":"a0bb0002-a0bb-a0bb-a0bb-a0bba0bba0bb","type":"user"}\n{"uuid":"b0cc0003-b0cc-b0cc-b0cc-b0ccb0ccb0cc","type":"user"}\n' > "$U2"
mkdir -p "$T/.claude/jobs/adad0003"
printf '{"name":"[←note] mine","sessionId":"adad0003-0000-0000-0000-000000000000"}\n' > "$T/.claude/jobs/adad0003/state.json"
hook "adad0003-0000-0000-0000-000000000000" "$U1"
chk "arrow text in a user name is never tagged" "[Old Fork] [←note] mine" "$(jq -r '.name' "$T/.claude/jobs/adad0003/state.json")"

# A title holding a raw newline: the reader must flatten it like the sweep's
# cache, or the supersede write would mint "[Old Fork] <second line only>".
V1="$P/aebe0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"MLT"}\n{"type":"custom-title","customTitle":"two\\nlines","sessionId":"x"}\n{"uuid":"ad110001-ad11-ad11-ad11-ad11ad11ad11","type":"user"}\n{"uuid":"ae220002-ae22-ae22-ae22-ae22ae22ae22","type":"user"}\n' > "$V1"
V2="$P/aebe0002-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"ad110001-ad11-ad11-ad11-ad11ad11ad11","type":"user"}\n{"uuid":"ae220002-ae22-ae22-ae22-ae22ae22ae22","type":"user"}\n{"uuid":"af330003-af33-af33-af33-af33af33af33","type":"user"}\n' > "$V2"
hook "aebe0001-0000-0000-0000-000000000000" "$V1"
chk "multi-line title flattened before the supersede write" "[Old Fork] two lines" "$(ft "$V1")"

# Read-only transcript: the title append fails, so the ROW write must not
# happen either — title verdict first, row second, or the row carries a
# deletion-safe [Old Fork] that no heal ever revisits.
RO1="$P/afbe0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"ROT"}\n{"uuid":"ba940001-ba94-ba94-ba94-ba94ba94ba94","type":"user"}\n{"uuid":"ca940002-ca94-ca94-ca94-ca94ca94ca94","type":"user"}\n' > "$RO1"
RO2="$P/afbe0002-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"ba940001-ba94-ba94-ba94-ba94ba94ba94","type":"user"}\n{"uuid":"ca940002-ca94-ca94-ca94-ca94ca94ca94","type":"user"}\n{"uuid":"da940003-da94-da94-da94-da94da94da94","type":"user"}\n' > "$RO2"
mkdir -p "$T/.claude/jobs/afbe0001"
printf '{"name":"RowRO","sessionId":"afbe0001-0000-0000-0000-000000000000"}\n' > "$T/.claude/jobs/afbe0001/state.json"
chmod 444 "$RO1"
hook "afbe0001-0000-0000-0000-000000000000" "$RO1" 2>/dev/null
chk "read-only transcript: row stays unmarked (title must back it)" "RowRO" "$(jq -r '.name' "$T/.claude/jobs/afbe0001/state.json")"
chmod 644 "$RO1"

# Torn tail: the ended file's last line is complete JSON with no trailing
# newline. The supersede must still be judged (reverse read repaired) and
# the file must be terminated before the title lands, never glued.
TT1="$P/bfbe0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"TornE"}\n{"uuid":"ea940004-ea94-ea94-ea94-ea94ea94ea94","type":"user"}\n{"uuid":"fa940005-fa94-fa94-fa94-fa94fa94fa94","type":"user"}' > "$TT1"
TT2="$P/bfbe0002-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"ea940004-ea94-ea94-ea94-ea94ea94ea94","type":"user"}\n{"uuid":"fa940005-fa94-fa94-fa94-fa94fa94fa94","type":"user"}\n{"uuid":"ab950006-ab95-ab95-ab95-ab95ab95ab95","type":"user"}\n' > "$TT2"
hook "bfbe0001-0000-0000-0000-000000000000" "$TT1"
chk "torn tail: superseded and terminated (line count)" "4" "$(wc -l < "$TT1")"
chk "torn tail: supersede title landed cleanly" "[Old Fork] TornE" "$(ft "$TT1")"

# Torn SUCCESSOR: the ahead sibling's last line lacks a newline. A raw
# reverse read glues (and so drops) its newest entries, misreads its
# conversation tail as an EARLY uuid that also exists in the ending file,
# and wrongly judges the pair identical twins — the supersede is missed.
TS1="$P/dfbe0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"TornS"}\n{"uuid":"ba970001-ba97-ba97-ba97-ba97ba97ba97","type":"user"}\n{"uuid":"ca970002-ca97-ca97-ca97-ca97ca97ca97","type":"user"}\n' > "$TS1"
TS2="$P/dfbe0002-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"ba970001-ba97-ba97-ba97-ba97ba97ba97","type":"user"}\n{"uuid":"ca970002-ca97-ca97-ca97-ca97ca97ca97","type":"user"}\n{"uuid":"da970003-da97-da97-da97-da97da97da97","type":"user"}' > "$TS2"
hook "dfbe0001-0000-0000-0000-000000000000" "$TS1"
chk "torn successor: still recognized as strictly ahead" "[Old Fork] TornS" "$(ft "$TS1")"

# Alien row: the folder matches the ending session's prefix, but the row's
# .sessionId names ANOTHER session (the post-repair shape) — the supersede
# verdict belongs to the ended session and must not touch the row.
AR1="$P/cfbe0001-0000-0000-0000-000000000000.jsonl"
printf '{"type":"ai-title","aiTitle":"AlienE"}\n{"uuid":"ea970004-ea97-ea97-ea97-ea97ea97ea97","type":"user"}\n{"uuid":"fa970005-fa97-fa97-fa97-fa97fa97fa97","type":"user"}\n' > "$AR1"
AR2="$P/cfbe0002-0000-0000-0000-000000000000.jsonl"
printf '{"uuid":"ea970004-ea97-ea97-ea97-ea97ea97ea97","type":"user"}\n{"uuid":"fa970005-fa97-fa97-fa97-fa97fa97fa97","type":"user"}\n{"uuid":"ab980006-ab98-ab98-ab98-ab98ab98ab98","type":"user"}\n' > "$AR2"
mkdir -p "$T/.claude/jobs/cfbe0001"
printf '{"name":"AlienRowE","sessionId":"dada0002-0000-0000-0000-000000000000"}\n' > "$T/.claude/jobs/cfbe0001/state.json"
hook "cfbe0001-0000-0000-0000-000000000000" "$AR1"
chk "alien row keeps its name on session end" "AlienRowE" "$(jq -r '.name' "$T/.claude/jobs/cfbe0001/state.json")"
chk "the ended transcript still takes its title verdict" "[Old Fork] AlienE" "$(ft "$AR1")"

if [ "$fails" -eq 0 ]; then
  echo "ALL PASS"
else
  echo "$fails FAILURES"
  exit 1
fi
