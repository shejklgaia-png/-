#!/usr/bin/env bash
# Publish only placement previews. Combine editor/APK/remote per record timestamp.
set -euo pipefail
repo="${SERA_SYNC_BASE_REPO:-$HOME/sera_repo}"
source="${SERA_SYNC_SOURCE:-/storage/emulated/0/GAME/Git}"
editor="$source/.sera-placement/preview.json"
apk="$HOME/.sera_apk_placement.json"
[ -s "$editor" ] || [ -s "$apk" ] || exit 0
tmp=$(mktemp -d "$HOME/sera_placement_sync.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
merge_json() {
  python - "$@" <<'PY'
import json, math, sys
from pathlib import Path
out = Path(sys.argv[1])
records = {}
for name in sys.argv[2:]:
    path = Path(name)
    if not path.is_file():
        continue
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != 1 or not isinstance(data.get("records"), dict):
        raise ValueError("Invalid placement schema: " + name)
    for key, value in data["records"].items():
        stamp = value.get("updated_at")
        if type(stamp) not in (float, int) or not math.isfinite(stamp) or stamp <= 0:
            raise ValueError("Invalid placement timestamp: " + key)
        if key not in records or stamp > records[key]["updated_at"]:
            records[key] = value
out.write_text(json.dumps({"schema": 1, "records": records}, sort_keys=True, allow_nan=False) + "\n", encoding="utf-8")
PY
}
merge_json "$tmp/local.json" "$editor" "$apk"
cd "$repo"
export GIT_TERMINAL_PROMPT=0
local_blob=$(git hash-object "$tmp/local.json")
cache="$HOME/.sera_placement_synced_blob_v2"
if [ -f "$cache" ] && [ "$(cat "$cache")" = "$local_blob" ]; then
  exit 0
fi
branch=refs/heads/sera-placement-preview
base=$(git rev-parse HEAD)
remote=$(git ls-remote origin "$branch")
parent=""
if [ -n "$remote" ]; then
  git fetch --no-tags origin "$branch"
  parent=$(git rev-parse FETCH_HEAD)
  git show "$parent:preview.json" > "$tmp/remote.json"
fi
merge_json "$tmp/combined.json" "$tmp/remote.json" "$tmp/local.json"
blob=$(git hash-object -w "$tmp/combined.json")
if [ -n "$parent" ] && [ "$(git rev-parse "$parent:preview.json")" = "$blob" ]; then
  printf '%s\n' "$local_blob" > "$cache"
  echo "Placement preview already synced"
  exit 0
fi
base_blob=$(printf '%s\n' "$base" | git hash-object -w --stdin)
tree=$(printf '100644 blob %s\tpreview.json\n100644 blob %s\tsource-head.txt\n' "$blob" "$base_blob" | git mktree)
if [ -n "$parent" ]; then
  commit=$(git -c user.name="SERA Android Sync" -c user.email=sera-sync@localhost commit-tree "$tree" -p "$parent" -m "Sync SERA developer placement preview")
else
  commit=$(git -c user.name="SERA Android Sync" -c user.email=sera-sync@localhost commit-tree "$tree" -m "Sync SERA developer placement preview")
fi
git push origin "$commit:$branch"
printf '%s\n' "$local_blob" > "$cache"
echo "Placement preview synced: $commit"
