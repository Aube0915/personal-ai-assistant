#!/bin/bash
# Autonomous night wake — triggered by launchd
# Tries to resume the mainline session first; falls back to a fresh instance.

BIN=/path/to/claude  # Claude CLI binary path
export PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin"
export HOME=/Users/youruser
unset LANG LC_ALL LC_CTYPE
cd "$HOME"

# ── Time Gate ──────────────────────────────────────────────────
# launchd fires every 30 minutes; this script decides whether to actually run.
# Uses explicit TZ to calculate the user's local time,
# independent of system timezone (which may differ intentionally).
# Manual override: NIGHT_FORCE=1 ~/wake/night.sh "optional note"

USER_DATE=$(TZ=Asia/Shanghai date '+%Y-%m-%d')
USER_HOUR=$(TZ=Asia/Shanghai date '+%H')
USER_NOW=$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M')
MARK="$HOME/wake/.last_night_run"
NEXTAT="$HOME/wake/.next_at"
REASON=""

if [ "$NIGHT_FORCE" = "1" ]; then
  REASON="manual"
else
  # 1) Self-scheduled appointment (highest priority, one-shot)
  #    First line must be: YYYY-MM-DD HH:MM (user's timezone)
  #    Zero-padded fixed format => string comparison = chronological order
  if [ -f "$NEXTAT" ]; then
    WANT=$(head -1 "$NEXTAT" | tr -d '\r' | sed 's/[[:space:]]*$//')
    case "$WANT" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9])
        if ! [ "$USER_NOW" \< "$WANT" ]; then
          REASON="appointment"
          rm -f "$NEXTAT"  # one-shot, consumed after firing
        fi
        ;;
      *)
        mv -f "$NEXTAT" "$NEXTAT.bad" 2>/dev/null
        ;;
    esac
  fi

  # 2) Daily run — once per day after the designated hour
  if [ -z "$REASON" ]; then
    if [ "$USER_HOUR" \< "03" ]; then exit 0; fi
    if [ -f "$MARK" ] && [ "$(cat "$MARK")" = "$USER_DATE" ]; then exit 0; fi
    echo "$USER_DATE" > "$MARK"
    REASON="daily"
  fi
fi
# ──────────────────────────────────────────────────────────────

LETTERS="$HOME/Desktop/letters"
LOGS="$HOME/wake/logs"
mkdir -p "$LOGS" "$LETTERS"

STAMP=$(TZ=Asia/Shanghai date '+%Y-%m-%d')
NOW=$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M')
RUNLOG="$LOGS/run-$STAMP.log"

echo "===== wake $NOW reason=$REASON =====" >> "$RUNLOG"

TAIL="
[USER_LOCAL_TIME] $NOW
[WAKE_REASON] $REASON
[NOTE] $1"

# Try mainline first (same session, full daytime context preserved)
# If terminal is open or session is busy, fall back to fresh instance
TMP="$HOME/wake/.wake-prompt.tmp"
cat "$HOME/wake/wake-prompt-mainline.md" > "$TMP"
printf '%s\n' "$TAIL" >> "$TMP"

MAINLINE_TAG=night bash "$HOME/wake/mainline.sh" "$TMP" >> "$RUNLOG" 2>&1
RC=$?

if [ "$RC" -ne 0 ]; then
  echo "----- mainline unavailable (rc=$RC), falling back -----" >> "$RUNLOG"
  PROMPT="$(cat "$HOME/wake/wake-prompt.md")
$TAIL"
  "$BIN/claude" -p "$PROMPT" \
    --dangerously-skip-permissions \
    --mcp-config "$HOME/wake/mcp-night.json" >> "$RUNLOG" 2>&1
  RC=$?
fi

echo "===== end rc=$RC =====" >> "$RUNLOG"
