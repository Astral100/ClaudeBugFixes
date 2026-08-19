#!/bin/bash
# SessionStart hook: warn on EVERY fork — a newly-seen session id that inherited
# a conversation from another session file (clear/compact rollover,
# backgrounding, resume-forks, --fork-session). Fork direction comes from the
# daemon roster when available (authoritative); the uuid-overlap heuristic is
# the fallback for in-process rollovers, retries only for clear/compact (the
# sources whose file is written moments late), and is skipped for
# source=resume, where a restarted old session could otherwise mark its own
# child as parent.
# On a materialized fork the PARENT session is renamed to
# "[Old Fork] <title> - forked on HH:MM dd.mm.yyyy by <first 4 chars of new
# session id>"; re-forking never stacks markers or "forked on" suffixes.
#
# Markers ("[Old Fork] ", "[Stub] ", "[Dead] ", "[Dup] ") are mutually
# exclusive states: setting one replaces any other, and a mark that no longer
# holds is healed off on a later session start.
# The hook never deletes anything: the fork copies the conversation in full,
# but the parent's subagents/ folder is NOT copied, so deletion stays manual.

# Snapshotted once: the run lasts about a second and every age check tolerates
# far more drift than that.
NOW=$(date +%s)

# "--sweep-only": run the marker sweeps without a session context — invoked by
# the claude() shell wrapper right before the agents view opens, because the
# view snapshots job names once at open and a hook started in parallel loses
# that race. No stdin, no fork detection, no seen-marker.
sweep_only=
if [ "$1" = "--sweep-only" ]; then
  sweep_only=1
  sid= src= tpath=
else
  IFS=$'\x1f' read -r sid src tpath < <(jq -r --arg us $'\x1f' '[(.session_id // ""), (.source // ""), (.transcript_path // "")] | join($us)' 2>/dev/null)
  case "$sid" in
    *[!0-9a-f-]*|"") exit 0 ;;
  esac

  seen_dir="$HOME/.claude/fork-watch-seen"
  mkdir -p "$seen_dir"
  marker="$seen_dir/$sid"
  find "$seen_dir" -type f -mtime +30 -delete 2>/dev/null
fi

parse_markers() {
  # Sets PM_BASE ($1 without any leading markers) and PM_OLDFORK (non-empty
  # when the stripped markers included "[Old Fork] ").
  PM_BASE="$1" PM_OLDFORK=
  local changed=1
  while [ -n "$changed" ]; do
    changed=
    case "$PM_BASE" in
      "[Old Fork] "*) PM_BASE=${PM_BASE#"[Old Fork] "}; PM_OLDFORK=1; changed=1 ;;
      "[Stub] "*) PM_BASE=${PM_BASE#"[Stub] "}; changed=1 ;;
      "[Dead] "*) PM_BASE=${PM_BASE#"[Dead] "}; changed=1 ;;
      "[Dup] "*) PM_BASE=${PM_BASE#"[Dup] "}; changed=1 ;;
    esac
  done
  # A base that is only a bare marker token is inherited marker text, not a
  # real name: Claude Code seeds a new session's ai-title from a marked name,
  # so the marker string itself can end up as the whole title.
  case "$PM_BASE" in
    "[Old Fork]"|"[Stub]"|"[Dead]"|"[Dup]") PM_BASE= ;;
  esac
}

pid_matches_start() {
  # $1 = pid, $2 = expected /proc starttime ticks ("" accepts any live pid).
  # Guards against a recycled pid belonging to an unrelated process.
  local line rest
  [ -d "/proc/$1" ] || return 1
  [ -n "$2" ] || return 0
  line=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  rest=${line##*) }
  set -- $rest
  [ "${20}" = "$2" ]
}

# One-pass caches. Every helper used to spawn its own jq/grep per call; at
# 66 transcripts x ~6 spawns that cost ~10s per run on WSL, and both the view
# and the resume picker read names once at open — the sweep must be fast
# enough to finish before launch. Loaded once by the main flow.
declare -A R_PID R_PST R_LSRC R_MODE R_FORK R_TS
declare -A J_SEEN J_NAME J_SID J_MTIME J_MTIMEF
declare -A T_SEEN T_TITLE T_HASUUID T_MTIME T_HASCT
declare -A LU_SEEN LU_VAL

load_roster() {
  # Single jq over the roster; .workers is an OBJECT keyed by the 8-char id.
  # Fields are joined with the US separator (0x1f, bash side $'\x1f'), not
  # @tsv: tab is IFS whitespace in bash, so empty fields (a missing procStart,
  # a nameless job) would collapse and shift the columns.
  local roster="$HOME/.claude/daemon/roster.json" k pid pst lsrc mode isfork ts
  [ -f "$roster" ] || return 0
  while IFS=$'\x1f' read -r k pid pst lsrc mode isfork ts; do
    [ -n "$k" ] || continue
    R_PID[$k]=$pid; R_PST[$k]=$pst; R_LSRC[$k]=$lsrc; R_MODE[$k]=$mode; R_FORK[$k]=$isfork; R_TS[$k]=$ts
  done < <(jq -r --arg us $'\x1f' '.workers | to_entries[] | [.key, (.value.pid // ""), (.value.procStart // ""), (.value.dispatch.launch.sessionId // ""), (.value.dispatch.launch.mode // ""), ((.value.dispatch.launch.fork // "") | tostring), (.value.startedAt // 0)] | map(tostring) | join($us)' "$roster" 2>/dev/null)
}

load_jobs() {
  # Single jq (and single stat) over every jobs-registry state.json. One
  # malformed file aborts a multi-file jq run, so on failure every file is
  # re-read alone and only the bad one is dropped.
  local jqprog f name jsid short out line mt mtf
  jqprog='[input_filename, (.name // ""), (.sessionId // "")] | join($us)'
  set -- "$HOME"/.claude/jobs/*/state.json
  [ -e "$1" ] || return 0
  if ! out=$(jq -r --arg us $'\x1f' "$jqprog" "$@" 2>/dev/null); then
    out=""
    for f in "$@"; do
      line=$(jq -r --arg us $'\x1f' "$jqprog" "$f" 2>/dev/null) || continue
      out="$out$line"$'\n'
    done
  fi
  while IFS=$'\x1f' read -r f name jsid; do
    [ -n "$f" ] || continue
    short=${f%/state.json}; short=${short##*/}
    J_SEEN[$short]=1; J_NAME[$short]=$name; J_SID[$short]=$jsid
  done <<EOF
$out
EOF
  # %.Y (nanosecond mtime) is the cache-staleness token set_job_marker checks
  # before writing; %Y feeds the dead sweep's settle guard.
  while read -r mt mtf f; do
    [ -n "$f" ] || continue
    short=${f%/state.json}; short=${short##*/}
    J_MTIME[$short]=$mt; J_MTIMEF[$short]=$mtf
  done < <(stat -c '%Y %.Y %n' "$@" 2>/dev/null)
}

scan_transcripts() {
  # One pass over every project transcript: uuid presence (one grep -l),
  # mtimes (one stat), display titles (one grep -H piped through awk+jq —
  # awk wraps each candidate line as {"f":file,"l":line} so a single jq can
  # both filter out message lines that merely contain the marker text and
  # extract the title; real title lines are short, so awk drops over-long
  # matches early — they are message lines jq would filter anyway).
  # The current session's own file is left unscanned so later checks on it
  # always hit the live file, not a stale snapshot.
  local files=() pdirx f ftype tval mt
  for pdirx in "$HOME"/.claude/projects/*/; do
    for f in "$pdirx"*.jsonl; do
      [ -e "$f" ] || continue
      [ "$f" = "$tpath" ] && continue
      files+=("$f")
      T_SEEN[$f]=1
    done
  done
  [ ${#files[@]} -gt 0 ] || return 0
  while IFS= read -r f; do
    [ -n "$f" ] && T_HASUUID[$f]=1
  done < <(grep -l '"uuid":"' "${files[@]}" 2>/dev/null)
  while read -r mt f; do
    [ -n "$f" ] && T_MTIME[$f]=$mt
  done < <(stat -c '%Y %n' "${files[@]}" 2>/dev/null)
  while IFS=$'\x1f' read -r f ftype tval; do
    [ -n "$f" ] || continue
    if [ "$ftype" = "custom-title" ]; then
      T_TITLE[$f]=$tval; T_HASCT[$f]=1
    elif [ -z "${T_HASCT[$f]}" ]; then
      T_TITLE[$f]=$tval
    fi
  done < <(grep -H -E '"type":"(custom-title|ai-title)"' "${files[@]}" 2>/dev/null | awk 'length($0) < 4096 { i=index($0,":"); printf "{\"f\":\"%s\",\"l\":%s}\n", substr($0,1,i-1), substr($0,i+1) }' | jq -Rr --arg us $'\x1f' 'fromjson? | select(.l.type=="custom-title" or .l.type=="ai-title") | [.f, .l.type, (.l.customTitle // .l.aiTitle // "")] | join($us)')
}

worker_live() {
  # $1 = session id. True only when a live worker process holds the session
  # open right now (conversation in memory).
  local k=${1:0:8}
  [ -n "${R_PID[$k]}" ] && pid_matches_start "${R_PID[$k]}" "${R_PST[$k]}"
}

job_alive() {
  # $1 = session id. True when the daemon can still serve the session: a live
  # worker pid, OR a roster entry whose launch-source transcript still exists —
  # the daemon respawns such rows on entry, so they are enterable even with a
  # dead pid and no own transcript. A daemon restart clears the roster; only
  # then does a transcript-less row become truly dead.
  local k=${1:0:8}
  worker_live "$1" && return 0
  [ -n "${R_LSRC[$k]}" ] && [ -e "${R_LSRC[$k]}" ]
}

has_uuids() {
  # $1 = transcript path. True when the file exists and holds real message
  # uuids. Cache-first; a file created after the scan is grepped live.
  [ -e "$1" ] || return 1
  if [ -n "${T_SEEN[$1]}" ]; then
    [ -n "${T_HASUUID[$1]}" ]
    return
  fi
  grep -q '"uuid":"' "$1" 2>/dev/null
}

real_transcript_exists() {
  # $@ = glob matches for a session's transcript. True when any of them holds
  # real message uuids — checking only the first match would miss a session
  # whose transcript sits in a second project directory.
  local pf
  for pf in "$@"; do
    has_uuids "$pf" && return 0
  done
  return 1
}

set_job_marker() {
  # $1 = session id, $2 = marker ("" heals). Replaces any existing markers on
  # the job-registry name; no-op when the name already matches. Aborts when
  # the daemon rewrote the file mid-flight, so its newer state is not lost.
  local short="${1:0:8}" jfile="$HOME/.claude/jobs/${1:0:8}/state.json" jname jnew jtmp m1 m2
  [ -f "$jfile" ] || return 1
  if [ -n "${J_SEEN[$short]}" ]; then
    jname="${J_NAME[$short]}"
  else
    jname=$(jq -r '.name // empty' "$jfile" 2>/dev/null)
  fi
  parse_markers "$jname"
  # A nameless job (failed bg handoff shells have no name) gets its short id
  # as the base, so several marked rows stay tellable apart.
  [ -z "$PM_BASE" ] && [ -n "$2" ] && PM_BASE="${1:0:8}"
  jnew="$2$PM_BASE"
  [ "$jnew" = "$jname" ] && return 0
  m1=$(stat -c '%.Y' "$jfile" 2>/dev/null)
  if [ -n "${J_SEEN[$short]}" ] && [ "$m1" != "${J_MTIMEF[$short]}" ]; then
    # The daemon rewrote the file after the cache was loaded; re-derive from
    # the file so its newer name is not clobbered by a stale cache entry.
    jname=$(jq -r '.name // empty' "$jfile" 2>/dev/null)
    parse_markers "$jname"
    [ -z "$PM_BASE" ] && [ -n "$2" ] && PM_BASE="${1:0:8}"
    jnew="$2$PM_BASE"
    [ "$jnew" = "$jname" ] && return 0
  fi
  jtmp="$jfile.tmp.$$"
  if ! jq --arg n "$jnew" '.name = $n' "$jfile" > "$jtmp" 2>/dev/null; then
    rm -f "$jtmp"
    return 1
  fi
  m2=$(stat -c '%.Y' "$jfile" 2>/dev/null)
  if [ "$m1" != "$m2" ]; then
    rm -f "$jtmp"
    return 1
  fi
  if mv "$jtmp" "$jfile"; then
    J_SEEN[$short]=1; J_NAME[$short]="$jnew"
    J_MTIMEF[$short]=$(stat -c '%.Y' "$jfile" 2>/dev/null)
  else
    rm -f "$jtmp"
  fi
}

append_custom_title() {
  # $1 = transcript path, $2 = new title. Appends a custom-title entry.
  # For a file idle over 60s the original mtime is restored afterwards:
  # bumping it would promote the file in recency ordering, which is what
  # "claude --continue" resumes by. A hot file (written within 60s, likely an
  # active session) is never backdated — stomping a concurrent write's mtime
  # backwards would hide the active session from --continue instead.
  local f="$1" fid mt mtY
  fid=${f##*/}; fid=${fid%.jsonl}
  read -r mtY mt < <(stat -c '%Y %y' "$f" 2>/dev/null)
  jq -cn --arg t "$2" --arg s "$fid" '{type:"custom-title",customTitle:$t,sessionId:$s}' >> "$f" || return 1
  if [ -n "${T_SEEN[$f]}" ]; then
    T_TITLE[$f]="$2"; T_HASCT[$f]=1
  fi
  if [ -n "$mt" ] && [ -n "$mtY" ] && [ $((NOW - mtY)) -gt 60 ]; then
    touch -m -d "$mt" "$f"
  fi
}

file_title() {
  # Prints the display title of transcript $1: last custom-title, else ai-title.
  # Cache-first (filled by scan_transcripts); a file the scan did not cover is
  # read live — grep narrows the transcript to candidate lines before jq
  # parses them, and the select() drops message lines that merely contain the
  # marker text.
  if [ -n "${T_SEEN[$1]}" ]; then
    printf '%s' "${T_TITLE[$1]}"
    return
  fi
  local t
  t=$(grep -F '"type":"custom-title"' "$1" 2>/dev/null | jq -r 'select(.type=="custom-title") | .customTitle // empty' 2>/dev/null | tail -1)
  if [ -z "$t" ]; then
    t=$(grep -F '"type":"ai-title"' "$1" 2>/dev/null | jq -r 'select(.type=="ai-title") | .aiTitle // empty' 2>/dev/null | tail -1)
  fi
  printf '%s' "$t"
}

last_uuid() {
  # Prints the last message uuid of transcript $1. Memoized — title appends
  # add no uuid lines, so a cached value stays correct for the whole run.
  if [ -n "${LU_SEEN[$1]}" ]; then
    printf '%s' "${LU_VAL[$1]}"
    return
  fi
  local u
  u=$(tac "$1" 2>/dev/null | grep -m1 -oE '"uuid":"[0-9a-f-]{36}"' | grep -oE '[0-9a-f-]{36}')
  LU_SEEN[$1]=1; LU_VAL[$1]=$u
  printf '%s' "$u"
}

is_liveish() {
  # $1 = transcript path. True when the session has a live worker or the file
  # was written in the last 10 minutes — likely someone's active window, which
  # must never be marked (non-daemon interactive sessions are invisible to the
  # roster, so recency is the only signal for them).
  local fid mt
  fid=${1##*/}; fid=${fid%.jsonl}
  worker_live "$fid" && return 0
  if [ -n "${T_SEEN[$1]}" ] && [ -n "${T_MTIME[$1]}" ]; then
    mt=${T_MTIME[$1]}
  else
    mt=$(stat -c %Y "$1" 2>/dev/null) || return 1
  fi
  [ $((NOW - mt)) -lt 600 ]
}

retitle() {
  # $1 = transcript path, $2 = marker ("" heals). Appends a custom-title with
  # any existing markers replaced; no-op when the title already matches.
  local f="$1" title new fid
  title=$(file_title "$f")
  [ -n "$title" ] || return 1
  parse_markers "$title"
  # Healing also drops a stale "- forked on ..." suffix: the session is no
  # longer superseded, so the fork annotation no longer applies.
  [ -z "$2" ] && PM_BASE=${PM_BASE%% - forked on *}
  # An empty base (the whole title was marker text) gets the short session id,
  # so the result never reads as a sweep mark and stays tellable apart.
  if [ -z "$PM_BASE" ]; then
    fid=${f##*/}; fid=${fid%.jsonl}
    PM_BASE=${fid:0:8}
  fi
  new="$2$PM_BASE"
  [ "$new" = "$title" ] && return 0
  append_custom_title "$f" "$new"
}

heal_if_marked() {
  # $1 = transcript path, $2 = session id. Strips any marker from the
  # transcript title and the job-registry name; leaves unmarked names alone.
  case "$(file_title "$1")" in
    "[Dup] "*|"[Old Fork] "*|"[Stub] "*|"[Dead] "*)
      retitle "$1" ""
      set_job_marker "$2" ""
      ;;
  esac
}

roster_fork_source() {
  # Prints the parent transcript path when THIS session is a daemon resume-
  # fork per the roster — the authoritative fork direction. Requires the
  # launch to be a real fork of another session's transcript.
  local k=${sid:0:8} lsrc
  [ "${R_MODE[$k]}" = "resume" ] || return 1
  [ "${R_FORK[$k]}" = "true" ] || return 1
  lsrc=${R_LSRC[$k]}
  [ -n "$lsrc" ] || return 1
  case "$lsrc" in
    *"/$sid.jsonl") return 1 ;;
  esac
  printf '%s' "$lsrc"
}

find_parent() {
  # $1 = probe attempts. Fallback parent detection for in-process rollovers
  # (clear/compact) that never touch the roster; those callers retry, because
  # the copied history may be written a moment after session start. A plain
  # startup probes once so new sessions never wait on the sleep loop.
  # Prints the parent transcript path on success. Direction-blind by nature,
  # so the caller must not use it for resumes.
  [ -n "$tpath" ] || return 1
  local tries="$1" probe="" i pdir pfile
  for ((i = 0; i < tries; i++)); do
    [ "$i" -gt 0 ] && sleep 0.4
    if [ -e "$tpath" ]; then
      probe=$(grep -m1 -oE '"uuid":"[0-9a-f-]{36}"' "$tpath" | grep -oE '[0-9a-f-]{36}')
      [ -n "$probe" ] && break
    fi
  done
  [ -n "$probe" ] || return 1
  pdir=${tpath%/*}
  # Parent = another file that also holds our first message uuid; forks copy
  # history, so several files may match — the true parent was written moments
  # before the fork, hence: newest match wins.
  pfile=$(grep -l "\"uuid\":\"$probe\"" "$pdir"/*.jsonl 2>/dev/null | grep -v -F "$tpath" | xargs -r ls -t 2>/dev/null | head -1)
  [ -n "$pfile" ] || return 1
  printf '%s' "$pfile"
}

rename_parent() {
  # $1 = parent transcript path. Prints the parent's new name on success.
  local pfile="$1" old_title new_title stamp
  old_title=$(file_title "$pfile")
  parse_markers "$old_title"
  old_title="$PM_BASE"
  # Strip an accumulated suffix from an earlier fork, so titles never grow
  # "- forked on A - forked on B" chains.
  old_title=${old_title%% - forked on *}
  stamp=$(date '+%H:%M %d.%m.%Y')
  if [ -n "$old_title" ]; then
    new_title="[Old Fork] $old_title - forked on $stamp by ${sid:0:4}"
  else
    new_title="[Old Fork] forked on $stamp by ${sid:0:4}"
  fi
  append_custom_title "$pfile" "$new_title" || return 1
  printf '%s' "$new_title"
}

sweep_transcripts() {
  # Classify every transcript in every project.
  # - A file with a title but zero message uuids belongs to a session that
  #   never processed a prompt: while the daemon can still serve it, it is a
  #   healthy attachable fork (the conversation sits in the process; the file
  #   is written lazily) — heal any leftover mark. Once unservable it is a
  #   husk -> "[Stub] ".
  # - A real transcript wrongly marked "[Stub] " is healed.
  # - A real transcript marked "[Old Fork] " whose last message no longer
  #   exists in any sibling has diverged past its fork — no longer superseded,
  #   healed back.
  local pdirx f fid mt title last
  for pdirx in "$HOME"/.claude/projects/*/; do
    for f in "$pdirx"*.jsonl; do
      [ -e "$f" ] || continue
      [ "$f" = "$tpath" ] && continue
      fid=${f##*/}; fid=${fid%.jsonl}
      if has_uuids "$f"; then
        title=$(file_title "$f")
        case "$title" in
          "[Stub] "*)
            retitle "$f" ""
            set_job_marker "$fid" ""
            ;;
          "[Old Fork]"|"[Stub]"|"[Dead]"|"[Dup]")
            # The whole title is a bare marker token (inherited marker text on
            # a working session): replace it with the short id so it cannot be
            # mistaken for a sweep mark.
            retitle "$f" ""
            ;;
          "[Old Fork] "*|"[Dup] "*)
            last=$(last_uuid "$f")
            [ -n "$last" ] || continue
            if ! grep -l "\"uuid\":\"$last\"" "$pdirx"*.jsonl 2>/dev/null | grep -v -F "$f" | grep -q .; then
              retitle "$f" ""
              set_job_marker "$fid" ""
            fi
            ;;
        esac
        continue
      fi
      mt=${T_MTIME[$f]}
      [ -n "$mt" ] || mt=$(stat -c %Y "$f" 2>/dev/null) || continue
      [ $((NOW - mt)) -lt 60 ] && continue
      # Markers mean "safe to delete". A servable title-only session is a
      # working entry point and stays unmarked; only an unservable husk file
      # (would open empty) gets "[Stub] ". Job rows are the dead sweep's
      # domain — this sweep touches transcript titles only.
      if job_alive "$fid"; then
        retitle "$f" ""
      else
        retitle "$f" "[Stub] "
      fi
    done
  done
}

sweep_dups() {
  # Twin at-rest forks: two or more enterable fork shells resumed from the
  # SAME parent transcript, none of which has its own conversation yet, are
  # identical duplicates in the agents view. All but the newest get "[Dup] ";
  # the mark heals itself once a twin diverges, dies, or stands alone.
  # The parent is deliberately NOT marked: nothing has diverged, and it may
  # be the user's active window.
  local filtered parent short ts dups jname
  filtered=""
  for short in "${!R_MODE[@]}"; do
    [ "${R_MODE[$short]}" = "resume" ] || continue
    parent=${R_LSRC[$short]}
    ts=${R_TS[$short]}
    [ -n "$parent" ] || continue
    if real_transcript_exists "$HOME"/.claude/projects/*/"$short"*.jsonl; then continue; fi
    job_alive "$short" || continue
    # A twin with a live worker outranks any merely-respawnable husk when
    # choosing which twin keeps the unmarked name.
    if worker_live "$short"; then ts=$((ts + 10000000000000)); fi
    filtered="$filtered$parent"$'\t'"$short"$'\t'"$ts"$'\n'
  done
  # Newest per parent keeps its name; the rest are the duplicates.
  dups=$(printf '%s' "$filtered" | sort -t $'\t' -k1,1 -k3,3nr | awk -F '\t' '{ if ($1 == prev) print $2; prev = $1 }' | tr '\n' ' ')
  # An at-rest fork is also redundant when another job row already carries its
  # parent's conversation (a materialized copy containing the parent's last
  # message): entering the shell would only open an outdated re-fork.
  local pl jshort2 jsid2 pf
  while IFS=$'\t' read -r parent short ts; do
    [ -n "$parent" ] && [ -n "$short" ] || continue
    case " $dups " in
      *" $short "*) continue ;;
    esac
    [ -f "$parent" ] || continue
    pl=$(last_uuid "$parent")
    [ -n "$pl" ] || continue
    for jshort2 in "${!J_SEEN[@]}"; do
      [ "$jshort2" = "$short" ] && continue
      jsid2=${J_SID[$jshort2]}
      [ -n "$jsid2" ] || continue
      for pf in "$HOME"/.claude/projects/*/"$jsid2".jsonl; do
        if [ -e "$pf" ] && grep -qF "\"uuid\":\"$pl\"" "$pf"; then
          dups="$dups$short "
          break 2
        fi
      done
    done
  done <<EOF
$filtered
EOF
  for short in "${!J_SEEN[@]}"; do
    jname=${J_NAME[$short]}
    case " $dups " in
      *" $short "*) set_job_marker "$short" "[Dup] " ;;
      *)
        case "$jname" in
          "[Dup] "*)
            # Heal only at-rest shells; a "[Dup] " job with a real transcript
            # belongs to sweep_copy_dups.
            if ! real_transcript_exists "$HOME"/.claude/projects/*/"$short"*.jsonl; then
              set_job_marker "$short" ""
            fi
            ;;
        esac
        ;;
    esac
  done
}

sweep_copy_dups() {
  # Materialized copies: a fork copies the whole conversation into a new file,
  # so several real transcripts can hold the same conversation (they share the
  # title and message uuids). Within each same-title group: a file whose tail
  # is contained in a longer sibling is superseded -> "[Old Fork] "; identical
  # twins keep one unmarked and the cold rest get "[Dup] ". Live/hot files
  # (worker or written <10 min ago) are never marked.
  local pdirx f g title fl gl fid twins newest_cold newest_cold_mt mt liveish_twin n
  for pdirx in "$HOME"/.claude/projects/*/; do
    declare -A CD_GROUP=()
    for f in "$pdirx"*.jsonl; do
      [ -e "$f" ] || continue
      has_uuids "$f" || continue
      title=$(file_title "$f")
      [ -n "$title" ] || continue
      parse_markers "$title"
      PM_BASE=${PM_BASE%% - forked on *}
      [ -n "$PM_BASE" ] || continue
      CD_GROUP[$PM_BASE]="${CD_GROUP[$PM_BASE]}$f"$'\n'
    done
    for title in "${!CD_GROUP[@]}"; do
      local files=()
      mapfile -t files <<< "${CD_GROUP[$title]}"
      n=0
      for f in "${files[@]}"; do
        [ -n "$f" ] && n=$((n + 1))
      done
      [ "$n" -ge 2 ] || continue
      twins=""
      for f in "${files[@]}"; do
        [ -n "$f" ] || continue
        fl=$(last_uuid "$f")
        [ -n "$fl" ] || continue
        local superseded="" mutual=""
        for g in "${files[@]}"; do
          [ -n "$g" ] && [ "$g" != "$f" ] || continue
          if grep -qF "\"uuid\":\"$fl\"" "$g"; then
            gl=$(last_uuid "$g")
            if [ -n "$gl" ] && grep -qF "\"uuid\":\"$gl\"" "$f"; then
              mutual=1
            else
              superseded=1
            fi
          fi
        done
        if [ -n "$superseded" ]; then
          if ! is_liveish "$f"; then
            fid=${f##*/}; fid=${fid%.jsonl}
            retitle "$f" "[Old Fork] " && set_job_marker "$fid" "[Old Fork] "
          fi
        elif [ -n "$mutual" ]; then
          twins="$twins$f"$'\n'
        fi
      done
      # Identical twins: if any is live/hot it is the keeper and every cold
      # twin is redundant; among only-cold twins the newest keeps its name.
      [ -n "$twins" ] || continue
      liveish_twin=""; newest_cold=""; newest_cold_mt=0
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        if is_liveish "$f"; then
          liveish_twin=1
        else
          mt=${T_MTIME[$f]}
          [ -n "$mt" ] || mt=$(stat -c %Y "$f" 2>/dev/null) || mt=0
          if [ "$mt" -gt "$newest_cold_mt" ]; then newest_cold_mt=$mt; newest_cold="$f"; fi
        fi
      done <<EOF
$twins
EOF
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        fid=${f##*/}; fid=${fid%.jsonl}
        if is_liveish "$f" || { [ -z "$liveish_twin" ] && [ "$f" = "$newest_cold" ]; }; then
          # The kept twin (live/hot, or the newest cold one) must not carry a
          # stale marker from a run where it was not the keeper — otherwise a
          # twin pair whose mtime order flipped ends up with BOTH marked.
          heal_if_marked "$f" "$fid"
          continue
        fi
        retitle "$f" "[Dup] " && set_job_marker "$fid" "[Dup] "
      done <<EOF
$twins
EOF
    done
    unset CD_GROUP
  done
}

sweep_dead_jobs() {
  # A jobs-registry row whose session has no transcript in any project and no
  # live daemon worker can never be entered again ("no saved transcript") ->
  # "[Dead] ". A live worker keeps a transcript-less row healthy (attachable
  # fork shell), healing any wrong mark; "[Old Fork] " survives healing.
  # Rows whose transcript exists are the transcript sweep's domain and only
  # get a stray "[Dead] " healed. Nothing is deleted.
  local short jmt jsid jname healmark
  for short in "${!J_SEEN[@]}"; do
    # Settle guard: a freshly written job may still be spawning its worker.
    jmt=${J_MTIME[$short]}
    [ -n "$jmt" ] || continue
    [ $((NOW - jmt)) -lt 300 ] && continue
    jsid=${J_SID[$short]}
    [ -n "$jsid" ] || continue
    jname=${J_NAME[$short]}
    parse_markers "$jname"
    if [ -n "$PM_OLDFORK" ]; then healmark="[Old Fork] "; else healmark=""; fi
    # A title-only husk file does not count as a transcript: the row would
    # still open empty, so it is judged by servability like a missing file.
    # Marker writes target $short, the registry folder that is actually being
    # iterated — not a prefix of $jsid, which need not match the folder name.
    if real_transcript_exists "$HOME"/.claude/projects/*/"$jsid".jsonl; then
      case "$jname" in
        "[Dead] "*) set_job_marker "$short" "$healmark" ;;
      esac
      continue
    fi
    if job_alive "$jsid"; then
      case "$jname" in
        "[Dead] "*|"[Stub] "*) set_job_marker "$short" "$healmark" ;;
      esac
      continue
    fi
    set_job_marker "$short" "[Dead] "
  done
}

handle_fork() {
  # $1 = parent transcript path of a materialized fork. Marks and renames the
  # parent, then emits the systemMessage warning.
  local pfile="$1" pid renamed msg
  pid=${pfile##*/}; pid=${pid%.jsonl}
  set_job_marker "$pid" "[Old Fork] "
  if renamed=$(rename_parent "$pfile"); then
    msg="FORK (source: ${src:-unknown}): NEW session file ${sid:0:8}... inherited the conversation from ${pid:0:8}... The old session was renamed to \"$renamed\" - this new session keeps the short name. The old file is a duplicate of this conversation; only its subagents/ folder holds anything unique."
  else
    msg="FORK (source: ${src:-unknown}): NEW session file ${sid:0:8}... inherited the conversation from ${pid:0:8}... (and its name, if set). The parent could not be renamed - run /rename to keep sessions tellable apart."
  fi
  jq -cn --arg m "$msg" '{systemMessage:$m}'
}

# Sweeps run first: the agents view reads job names once at open, racing this
# hook — the marks must land before find_parent's probe wait. A sweep stamp
# under 30s old means another run just swept (the claude() wrapper sweeps
# right before opening the view, then the view's own SessionStart hook fires
# moments later): the marks are current, so the sweeps and their scans are
# skipped — and a sweep-only run has nothing left to do at all, so it exits
# before even the roster load. Hook mode still loads the roster on the skip
# path, because fork detection below needs it.
sweep_stamp="$HOME/.claude/fork-watch-sweep-stamp"
sm=$(stat -c %Y "$sweep_stamp" 2>/dev/null) || sm=0
if [ $((NOW - sm)) -lt 30 ]; then
  [ -n "$sweep_only" ] && exit 0
  load_roster
else
  load_roster
  load_jobs
  scan_transcripts
  sweep_transcripts
  sweep_dead_jobs
  sweep_dups
  sweep_copy_dups
  touch "$sweep_stamp" 2>/dev/null
fi

[ -n "$sweep_only" ] && exit 0

if [ ! -e "$marker" ]; then
  if rsrc=$(roster_fork_source); then
    if [ -n "$tpath" ] && has_uuids "$tpath"; then
      # Materialized daemon fork: the roster names the parent authoritatively.
      [ -f "$rsrc" ] && handle_fork "$rsrc"
    else
      rshort=${rsrc##*/}
      msg="FORK (source: ${src:-unknown}): this session ${sid:0:8}... is a fresh fork shell resumed from ${rshort:0:8}... The conversation still lives with the parent; this shell copies it once a prompt is sent. Twin forks of the same parent are marked [Dup] in the agents view."
      jq -cn --arg m "$msg" '{systemMessage:$m}'
    fi
  elif [ "$src" != "resume" ]; then
    # uuid heuristic only for non-resume sources: on a resume it could pick
    # this session's own child and invert the fork direction.
    if [ "$src" = "clear" ] || [ "$src" = "compact" ]; then tries=5; else tries=1; fi
    if pfile=$(find_parent "$tries"); then
      handle_fork "$pfile"
    fi
  fi
fi
touch "$marker"
exit 0
