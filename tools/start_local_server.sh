#!/bin/zsh
set -e

ROOT="/Users/sonny03/Documents/MiceManager"
PORT="${PORT:-8000}"
RUN_HOURS="${RUN_HOURS:-6}"
PID_FILE="$ROOT/.mice_manager_server.pid"
TIMER_PID_FILE="$ROOT/.mice_manager_server_timer.pid"
LOG_FILE="$ROOT/server.log"

cd "$ROOT"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Mice Manager is already running on port $PORT."
else
  source "$ROOT/venv/bin/activate"
  nohup env PORT="$PORT" "$ROOT/venv/bin/python" "$ROOT/app.py" > "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 2
fi

if [ -f "$TIMER_PID_FILE" ] && kill -0 "$(cat "$TIMER_PID_FILE")" 2>/dev/null; then
  kill "$(cat "$TIMER_PID_FILE")" 2>/dev/null || true
fi

SERVER_PID="$(cat "$PID_FILE")"
(
  sleep "$((RUN_HOURS * 3600))"
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE" "$TIMER_PID_FILE"
) >/dev/null 2>&1 &
echo $! > "$TIMER_PID_FILE"

IP_ADDRESS="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "localhost")"
echo "Laptop URL: http://127.0.0.1:$PORT"
echo "Phone URL: http://$IP_ADDRESS:$PORT"
echo "Run window: $RUN_HOURS hours"
open "http://127.0.0.1:$PORT" >/dev/null 2>&1 || true
