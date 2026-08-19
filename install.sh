#!/bin/bash
# Symlinks the hooks into ~/.claude/scripts and prints the two config blocks
# that must be added by hand (settings.json hooks, .bashrc wrapper).
set -e
repo=$(dirname "$(readlink -f "$0")")
mkdir -p "$HOME/.claude/scripts"
ln -sf "$repo/fork-watch.sh" "$HOME/.claude/scripts/fork-watch.sh"
ln -sf "$repo/fork-watch-end.sh" "$HOME/.claude/scripts/fork-watch-end.sh"
echo "Symlinked fork-watch.sh and fork-watch-end.sh into ~/.claude/scripts."
cat <<'EOF'

1. Register the hooks in ~/.claude/settings.json:

  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "bash ~/.claude/scripts/fork-watch.sh" } ] }
    ],
    "SessionEnd": [
      { "hooks": [ { "type": "command", "command": "bash ~/.claude/scripts/fork-watch-end.sh" } ] }
    ]
  }

2. Add the wrapper to ~/.bashrc — the agents view and the resume picker read
   names once at open, so the sweep must finish before launch:

claude() {
  if [ "$1" = "agents" ]; then
    shift
    timeout 10 bash "$HOME/.claude/scripts/fork-watch.sh" --sweep-only 2>/dev/null
    command claude agents --cwd "$PWD" "$@"
  elif [ "$1" = "--resume" ] || [ "$1" = "-r" ]; then
    timeout 10 bash "$HOME/.claude/scripts/fork-watch.sh" --sweep-only 2>/dev/null
    command claude "$@"
  else
    command claude "$@"
  fi
}
EOF
