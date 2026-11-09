#!/bin/bash
# Mainline session manager: routes all entry points (Telegram, night wake,
# scheduled tasks) into a single persistent Claude session.
#
#   ~/wake/mainline.sh <prompt-file>
#
# Three jobs:
#   1. Acquire lock (mkdir is atomic on POSIX) — one writer at a time
#   2. Check that the session file hasn't been touched recently
#      (gives way to an interactive terminal session)
#   3. claude -p --resume <session-id>
#
# WHY THIS EXISTS: Two concurrent `--resume` calls to the same session
# both return success, but one side's messages silently vanish.
# No error, no warning. The lock isn't insurance — it's essential.

set -u
HOME_DIR=/Users/youruser
BIN="$HOME_DIR/.local/bin/claude"
CONF="$HOME_DIR/wake/mainline.conf"
LOCK="$HOME_DIR/wake/.mainline.lock"
MLOG="$HOME_DIR/wake/logs/mainline.log"

WAIT_LOCK=900      # max 15 min waiting for lock
STALE=1800         # lock older than 30 min = dead, force break
QUIET=6            # session file must be idle this many seconds
WAIT_QUIET=180     # max 3 min waiting for quiet

mkdir -p "$(dirname "$MLOG")"
mlog() { printf '%s  %s\n' "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$MLOG"; }

PROMPT_FILE="${1:-}"
if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
  echo "usage: mainline.sh <prompt-file>" >&2
  exit 2
fi

[ -f "$CONF" ] || { mlog "no mainline.conf"; exit 3; }
SID=$(grep -E '^SESSION_ID=' "$CONF" | head -1 | cut -d= -f2 | tr -d ' "')
[ -n "$SID" ] || { mlog "no SESSION_ID"; exit 3; }

JSONL="$HOME_DIR/.claude/projects/-Users-youruser/$SID.jsonl"
TAG="${MAINLINE_TAG:-unknown}"

# ---- 0. Check for live interactive session ----
# Interactive claude holds context in memory; programmatic resume
# would create a fork that gets silently overwritten.
if ps -axww -o command= | grep -F -- "$SID" | grep -v -- " -p " | grep -qv "^grep"; then
  mlog "$TAG mainline held by terminal, refusing"
  echo "mainline held by terminal" >&2
  exit 6
fi

# ---- 1. Acquire lock ----
t0=$(date +%s)
while :; do
  if mkdir "$LOCK" 2>/dev/null; then
    printf '%s %s\n' "$$" "$TAG" > "$LOCK/owner"
    break
  fi
  if [ -d "$LOCK" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
    if [ "$age" -gt "$STALE" ]; then
      mlog "lock stale ${age}s, breaking (by $TAG)"
      rm -rf "$LOCK"
      continue
    fi
  fi
  if [ $(( $(date +%s) - t0 )) -gt "$WAIT_LOCK" ]; then
    mlog "$TAG gave up waiting for lock"
    echo "mainline busy" >&2
    exit 4
  fi
  sleep 2
done
trap 'rm -rf "$LOCK"' EXIT INT TERM

# ---- 2. Wait for session file to go quiet ----
t1=$(date +%s)
while [ -f "$JSONL" ]; do
  idle=$(( $(date +%s) - $(stat -f %m "$JSONL" 2>/dev/null || echo 0) ))
  [ "$idle" -ge "$QUIET" ] && break
  if [ $(( $(date +%s) - t1 )) -gt "$WAIT_QUIET" ]; then
    mlog "$TAG mainline never went quiet (idle=${idle}s), skipping"
    echo "mainline busy (terminal active)" >&2
    exit 5
  fi
  sleep 2
done

# ---- 3. Run ----
before=$(stat -f %z "$JSONL" 2>/dev/null || echo 0)
mlog "$TAG start"
export PATH="$(dirname "$BIN"):/usr/bin:/bin:/usr/sbin:/sbin"
unset LANG LC_ALL LC_CTYPE
cd "$HOME_DIR" || exit 1

"$BIN" -p --resume "$SID" --dangerously-skip-permissions < "$PROMPT_FILE"
rc=$?

after=$(stat -f %z "$JSONL" 2>/dev/null || echo 0)
mlog "$TAG end rc=$rc jsonl ${before}->${after}"
exit "$rc"
