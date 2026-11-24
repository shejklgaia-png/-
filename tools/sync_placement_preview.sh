#!/usr/bin/env bash
# Run from the project via Termux before the normal pull/launch action.
# Publishes only developer placement JSON, never the working tree or credentials.
set -euo pipefail
repo="${SERA_SYNC_BASE_REPO:-$HOME/sera_repo}"
source="${SERA_SYNC_SOURCE:-/storage/emulated/0/GAME/Git}"
file="$source/.sera-placement/preview.json"
[ -s "$file" ] || exit 0
cd "$repo"
export GIT_TERMINAL_PROMPT=0
# Avoid contacting GitHub every 120 seconds when no placement changed.
blob=$(git hash-object -w "$file")
cache="$HOME/.sera_placement_synced_blob"
if [ -f "$cache" ] && [ "$(cat "$cache")" = "$blob" ]; then
  exit 0
fi
branch=refs/heads/sera-placement-preview
base=$(git rev-parse HEAD)
remote=$(git ls-remote origin "$branch")
parent=""
if [ -n "$remote" ]; then
  git fetch --no-tags origin "$branch"
  parent=$(git rev-parse FETCH_HEAD)
fi
if [ -n "$parent" ] && [ "$(git rev-parse "$parent:preview.json")" = "$blob" ]; then
  printf '%s\n' "$blob" > "$cache"
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
printf '%s\n' "$blob" > "$cache"
echo "Placement preview synced: $commit"
