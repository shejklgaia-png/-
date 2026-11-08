#!/data/data/com.termux/files/usr/bin/bash
# One-time install from the approved GitHub main. Always back up scripts.
set -euo pipefail

BASE="https://raw.githubusercontent.com/shejklgaia-png/-/main/tools/termux"
TMP="$(mktemp -d "$HOME/sera_install.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

command -v python >/dev/null || { echo "Run: pkg install python"; exit 1; }
command -v git >/dev/null || { echo "Run: pkg install git"; exit 1; }
command -v flock >/dev/null || { echo "Run: pkg install util-linux"; exit 1; }
command -v inotifywait >/dev/null || { echo "Run: pkg install inotify-tools"; exit 1; }

curl --fail --location --silent --show-error \
  "$BASE/sera_push_safe.py" -o "$TMP/sera_push_safe.py"
curl --fail --location --silent --show-error \
  "$BASE/sera_push_launcher.sh" -o "$TMP/sera_push.sh"
curl --fail --location --silent --show-error \
  "$BASE/sera_watch_safe.sh" -o "$TMP/sera_watch.sh"

python -m py_compile "$TMP/sera_push_safe.py"
bash -n "$TMP/sera_push.sh" "$TMP/sera_watch.sh"

STAMP="$(date +%Y%m%d_%H%M%S)"
for file in sera_push.sh sera_watch.sh sera_push_safe.py; do
  if [ -f "$HOME/$file" ]; then
    cp -p "$HOME/$file" "$HOME/$file.before_safe_$STAMP"
  fi
  cp "$TMP/$file" "$HOME/$file"
  chmod 700 "$HOME/$file"
done

echo "Backup complete. Initializing local file baseline..."
bash "$HOME/sera_push.sh"

echo "Restarting the old watcher..."
if command -v pgrep >/dev/null && command -v pkill >/dev/null; then
  while IFS= read -r pid; do
    if [ -n "$pid" ]; then
      pkill -P "$pid" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
    fi
  done < <(pgrep -f -x "bash $HOME/sera_watch.sh" || true)
fi

nohup bash "$HOME/sera_watch.sh" </dev/null >/dev/null 2>&1 &
echo "Safe watcher started. PID: $!"
echo "Test: save a NEW small text file inside GAME/Git, then:"
echo "  tail -n 25 ~/sera_auto_push.log"
echo "No deletions or forced pushes are ever performed."
