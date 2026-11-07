#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SRC_ZIP="$HOME/storage/downloads/SERA_Loader_Android_source.zip"
REPO="$HOME/sera_repo"
TARGET="$REPO/tools/sera-loader"
if [[ ! -f "$SRC_ZIP" ]]; then echo "ERROR: ZIP missing at $SRC_ZIP";exit 1;fi
if [[ ! -d "$REPO/.git" ]]; then echo "ERROR: $REPO is not a Git repo";exit 1;fi
if [[ -n $(git -C "$REPO" status --porcelain) ]]; then echo "ERROR: Uncommitted changes in sera_repo. Not uploading.";exit 1;fi
git -C "$REPO" fetch origin main
if [[ $(git -C "$REPO" rev-parse HEAD) != $(git -C "$REPO" rev-parse origin/main) ]]; then echo "ERROR: main has diverged/changed. Sync first.";exit 1;fi
if [[ -e "$TARGET" ]]; then echo "ERROR: $TARGET already exists. Not overwriting.";exit 1;fi
if [[ -e "$REPO/.github/workflows/sera-loader-build.yml" ]]; then echo "ERROR: workflow already exists. Not overwriting.";exit 1;fi
mkdir -p "$TARGET" "$REPO/.github/workflows"
unzip -q "$SRC_ZIP" -d "$TARGET"
cp "$TARGET/.github/workflows/sera-loader-build.yml" "$REPO/.github/workflows/sera-loader-build.yml"
rm -rf "$TARGET/.github"
cd "$REPO"
git add tools/sera-loader .github/workflows/sera-loader-build.yml
git commit -m "Add experimental SERA Android loading overlay"
git push origin HEAD:main
echo 'UPLOADED: GitHub Actions > Build SERA Loader APK > SERA-Loader-debug-apk'
