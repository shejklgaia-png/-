#!/usr/bin/env bash
# Run from the project via Termux before the normal pull/launch action.
# Publishes only developer placement JSON, never the working tree or credentials.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
file=.sera-placement/preview.json
[ -s "$file" ] || exit 0
branch=refs/heads/sera-placement-preview
base=$(git rev-parse HEAD)
remote=$(git ls-remote origin "$branch")
parent=""
if [ -n "$remote" ]; then
  git fetch --no-tags origin "$branch"
  parent=$(git rev-parse FETCH_HEAD)
fi
blob=$(git hash-object -w "$file")
if [ -n "$parent" ] && [ "$(git rev-parse "$parent:preview.json")" = "$blob" ]; then
  echo "Placement preview already synced"
  exit 0
fi
base_blob=$(printf '%s\n' "$base" | git hash-object -w --stdin)
tree=$(printf '100644 blob %s\tpreview.json\n100644 blob %s\tsource-head.txt\n' "$blob" "$base_blob" | git mktree)
if [ -n "$parent" ]; then
  commit=$(git commit-tree "$tree" -p "$parent" -m "Sync SERA developer placement preview")
else
  commit=$(git commit-tree "$tree" -m "Sync SERA developer placement preview")
fi
git push origin "$commit:$branch"
echo "Placement preview synced: $commit"
