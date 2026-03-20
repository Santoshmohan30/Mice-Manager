#!/bin/zsh
set -e

ROOT="/Users/sonny03/Documents/MiceManager"
PID_FILE="$ROOT/.mice_manager_server.pid"
TIMER_PID_FILE="$ROOT/.mice_manager_server_timer.pid"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  kill "$(cat "$PID_FILE")"
  rm -f "$PID_FILE"
  echo "Mice Manager stopped."
else
  echo "No tracked Mice Manager process is running."
fi

if [ -f "$TIMER_PID_FILE" ] && kill -0 "$(cat "$TIMER_PID_FILE")" 2>/dev/null; then
  kill "$(cat "$TIMER_PID_FILE")" 2>/dev/null || true
fi
rm -f "$TIMER_PID_FILE"
