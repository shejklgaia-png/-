#!/data/data/com.termux/files/usr/bin/python
"""Safe Android GAME/Git -> GitHub main uploader.

Never force-push, never delete upstream files, and never upload the entire
possibly stale Android mirror. Upload only files changed since the last
successfully observed local SOURCE snapshot. Reject same-file remote edits.

The initial invocation creates a baseline WITHOUT uploading old copies.
New additions/edits after that baseline are automatically uploaded.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

SOURCE = Path(os.environ.get(
    "SERA_SYNC_SOURCE", "/storage/emulated/0/GAME/Git"
))
BASE_REPO = Path.home() / "sera_repo"
STATE = Path.home() / ".sera_safe_upload_state.json"
REMOTE = "https://github.com/shejklgaia-png/-.git"
MAX_ATTEMPTS = 3


def run(cmd, *, cwd=None, checked=True):
    proc = subprocess.run(
        cmd, cwd=cwd, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
    )
    if checked and proc.returncode != 0:
        raise RuntimeError(
            f"command failed ({proc.returncode}): {' '.join(cmd)}\n"
            + (proc.stdout + "\n" + proc.stderr).strip()[-1800:]
        )
    return proc


def digest(path):
    sha = hashlib.sha256()
    with path.open("rb") as data:
        for chunk in iter(lambda: data.read(1024 * 1024), b""):
            sha.update(chunk)
    return sha.hexdigest()


def excluded(relative_path):
    parts = relative_path.parts
    if any(x in (".git", ".godot") for x in parts[:-1]):
        return True
    name = parts[-1]
    return (name == ".nomedia" or
            ("_backup_" in name and name.endswith(".bbmodel")))


def scan(previous):
    result = {}
    old_files = (previous or {}).get("files", {})
    for folder, dirs, filenames in os.walk(SOURCE):
        dirs[:] = sorted(d for d in dirs if d not in (".git", ".godot"))
        for filename in sorted(filenames):
            path = Path(folder) / filename
            rel = path.relative_to(SOURCE)
            if excluded(rel) or path.is_symlink() or not path.is_file():
                continue
            try:
                stat = path.stat()
                key = rel.as_posix()
                before = old_files.get(key)
                if (isinstance(before, dict) and
                        before.get("size") == stat.st_size and
                        before.get("mtime_ns") == stat.st_mtime_ns and
                        isinstance(before.get("sha256"), str)):
                    checksum = before["sha256"]
                else:
                    checksum = digest(path)
                result[key] = {
                    "size": stat.st_size,
                    "mtime_ns": stat.st_mtime_ns,
                    "sha256": checksum,
                }
            except OSError as exc:
                raise RuntimeError(
                    f"File changed/disappeared while scanning: {path}: {exc}"
                ) from exc
    return result


def save_state(sha, snapshot):
    state = {"schema": 1, "remote_sha": sha, "files": snapshot}
    temp = STATE.with_suffix(".tmp")
    with temp.open("w", encoding="utf-8") as stream:
        json.dump(state, stream, ensure_ascii=False, sort_keys=True)
    temp.replace(STATE)


def checkout_latest(path):
    # Prefer locally cached git objects to avoid re-downloading the whole
    # history over mobile data. All branch/reset commands run in a disposable
    # clone; ~/sera_repo and GAME/Git are never reset or rewritten.
    if (BASE_REPO / ".git").is_dir():
        run(["git", "clone", "--quiet", "--no-hardlinks",
             str(BASE_REPO), str(path)])
    else:
        run(["git", "clone", "--quiet", "--branch", "main",
             REMOTE, str(path)])
    run(["git", "remote", "set-url", "origin", REMOTE], cwd=path)
    run(["git", "fetch", "--quiet", "origin", "main"], cwd=path)
    run(["git", "checkout", "--quiet", "-B", "main", "FETCH_HEAD"],
        cwd=path)
    sha = run(["git", "rev-parse", "HEAD"], cwd=path).stdout.strip()
    return sha


def remote_changed_since(clone, base_sha, remote_sha):
    # Be conservative if the branch was rewritten or the old base vanished.
    if not base_sha:
        raise RuntimeError("Missing last-successful upstream base")
    found = run(["git", "cat-file", "-e", base_sha + "^{commit}"],
                cwd=clone, checked=False)
    if found.returncode:
        raise RuntimeError("Previous upstream base is missing; manual review required")
    ancestor = run(["git", "merge-base", "--is-ancestor",
                    base_sha, remote_sha], cwd=clone, checked=False)
    if ancestor.returncode:
        raise RuntimeError("Remote history was rewritten; refusing automatic upload")
    changed = run(["git", "diff", "--name-only", "-z",
                   base_sha, remote_sha, "--"], cwd=clone)
    return set(x for x in changed.stdout.split("\0") if x)


def upload():
    if not SOURCE.is_dir():
        raise RuntimeError(f"Source folder does not exist: {SOURCE}")
    if STATE.exists():
        try:
            state = json.loads(STATE.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise RuntimeError(
                "Upload state is unreadable; refusing to guess what changed"
            ) from exc
        if state.get("schema") != 1:
            raise RuntimeError("Unexpected upload state version")
    else:
        state = None

    current = scan(state)
    if state is not None:
        changed = sorted(
            rel for rel, data in current.items()
            if data["sha256"] != state["files"].get(rel, {}).get("sha256")
        )
        if not changed:
            return "NO CHANGES"
    else:
        changed = []

    for attempt in range(1, MAX_ATTEMPTS + 1):
        with tempfile.TemporaryDirectory(prefix="sera_safe_upload_") as temp:
            clone = Path(temp) / "repo"
            remote_sha = checkout_latest(clone)
            if state is None:
                save_state(remote_sha, current)
                return (
                    "BASELINE CREATED: current GAME/Git files recorded; "
                    "new changes will auto-upload. No existing files uploaded."
                )

            if remote_sha != state["remote_sha"]:
                upstream_changes = remote_changed_since(
                    clone, state["remote_sha"], remote_sha
                )
                for rel in changed:
                    if rel not in upstream_changes:
                        continue
                    remote_file = clone / rel
                    if (not remote_file.is_file() or
                            remote_file.is_symlink() or
                            digest(remote_file) != current[rel]["sha256"]):
                        raise RuntimeError(
                            "SAME-FILE CONFLICT: " + rel +
                            "\nRemote and Android both changed this file. "
                            "No files were uploaded. Review manually."
                        )

            for rel in changed:
                local_file = SOURCE / rel
                target = clone / rel
                if target.is_symlink():
                    raise RuntimeError(
                        "Refusing to replace a repository symlink: " + rel
                    )
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(local_file, target)
                if digest(target) != current[rel]["sha256"]:
                    raise RuntimeError(
                        "Source changed during upload: " + rel +
                        "\nRetry after the save completes."
                    )

            # Only additions/modified files. Never stage deletions; ignore
            # the rest of the local mirror, which may be behind GitHub.
            run(["git", "add", "--", *changed], cwd=clone)
            staged = run(["git", "diff", "--cached", "--quiet"],
                         cwd=clone, checked=False)
            if staged.returncode == 0:
                save_state(remote_sha, current)
                return (
                    "UP TO DATE: observed Android changes already exist on "
                    "GitHub. Snapshot updated."
                )
            if staged.returncode != 1:
                raise RuntimeError("Unable to inspect staged git changes")
            run([
                "git", "-c", "user.name=SERA Android Sync",
                "-c", "user.email=sera-sync@localhost",
                "commit", "--quiet", "-m",
                "SERA Android sync " + time.strftime("%Y-%m-%d %H:%M:%S")
            ], cwd=clone)
            commit_sha = run(["git", "rev-parse", "HEAD"],
                             cwd=clone).stdout.strip()
            push = run(["git", "push", "origin", "HEAD:main"],
                       cwd=clone, checked=False)
            if push.returncode == 0:
                save_state(commit_sha, current)
                return (
                    "PUSH SUCCESS: " + commit_sha[:12] + " | files: " +
                    ", ".join(changed[:12]) +
                    (" ..." if len(changed) > 12 else "")
                )
            # A concurrent GitHub merge invalidates this attempt. Start
            # again from the new remote HEAD; never force-push.
            failure = (push.stdout + "\n" + push.stderr).strip()
            if not ("non-fast-forward" in failure or
                    "fetch first" in failure or
                    "[rejected]" in failure):
                raise RuntimeError("Git push failed:\n" + failure[-1800:])
            print(
                f"REMOTE ADVANCED during push: retry {attempt}/{MAX_ATTEMPTS}",
                flush=True
            )

    raise RuntimeError(
        "GitHub changed during every attempt. Upload queued for next poll."
    )


def main():
    # Keep a single state writer even when inotify and manual pushes collide.
    import fcntl
    lock = Path.home() / ".sera_safe_upload.lock"
    with lock.open("a+") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)
        print(upload(), flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("UPLOAD ERROR:", str(exc), file=sys.stderr, flush=True)
        sys.exit(1)
