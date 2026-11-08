#!/data/data/com.termux/files/usr/bin/bash
# Installed as ~/sera_watch.sh. Watch events and recover missed Android
# shared-storage events with a periodic read-only hash/status poll.
set -u
SRC="/storage/emulated/0/GAME/Git"
LOG="$HOME/sera_auto_push.log"
LOCK="$HOME/.sera_watch_safe.lock"
PUSH="$HOME/sera_push.sh"

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "WATCHER ALREADY RUNNING" >> "$LOG"
  exit 0
fi

echo "$(date '+%F %T') WATCHER STARTED" >> "$LOG"
run_push() {
  if bash "$PUSH" >> "$LOG" 2>&1; then
    rm -f "$HOME/sera_upload_error.txt"
  else
    echo "$(date '+%F %T') UPLOAD FAILED; will retry" >> "$LOG"
    echo "Automatic upload failed. See ~/sera_auto_push.log" > "$HOME/sera_upload_error.txt"
  fi
}
run_push

while true; do
  # 120-second timeout is also a fallback if a Blockbench/Android shared
  # storage save did not emit the usual close_write/moved_to event.
  inotifywait -q -r -t 120 \
    -e close_write,moved_to,create \
    --exclude '(/\.git/|/\.godot/|_backup_.*\.bbmodel$)' \
    "$SRC" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    sleep 5
  elif [ "$rc" -ne 2 ]; then
    # inotify unavailable/permission denied: avoid a busy-loop.
    echo "$(date '+%F %T') WATCHER EVENT ERROR; polling only" >> "$LOG"
    sleep 120
  fi
  run_push
  # Prevent unlimited logfile growth on an always-running phone.
  if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 1048576 ]; then
    tail -n 1200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
  fi
done
