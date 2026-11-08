#!/usr/bin/env python3
"""Offline regression tests for the Termux safe upload worker."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


SCRIPT = Path(__file__).with_name("sera_push_safe.py")


def run(*args, cwd=None, env=None, ok=True):
    p = subprocess.run(
        list(args), cwd=cwd, env=env, encoding="utf-8",
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    if ok and p.returncode != 0:
        raise AssertionError(f"{args!r} failed: {p.stdout}")
    return p


def commit(repo, message):
    run("git", "-c", "user.name=Offline test",
        "-c", "user.email=test@example.invalid",
        "add", "--all", cwd=repo)
    run("git", "-c", "user.name=Offline test",
        "-c", "user.email=test@example.invalid",
        "commit", "-m", message, cwd=repo)


def pushed_text(bare, name):
    return run("git", "--git-dir", str(bare),
               "show", f"main:{name}").stdout


def main():
    with tempfile.TemporaryDirectory(prefix="sera_uploader_test_") as temp:
        root = Path(temp)
        bare = root / "remote.git"
        seed = root / "seed"
        src = root / "GAME" / "Git"
        home = root / "home"
        src.mkdir(parents=True)
        home.mkdir()
        run("git", "init", "--bare", "--initial-branch=main", str(bare))
        run("git", "clone", str(bare), str(seed))
        (seed / "README.txt").write_text("original\n")
        commit(seed, "initial")
        run("git", "push", "origin", "main", cwd=seed)
        (src / "README.txt").write_text("original\n")
        env = {
            **os.environ,
            "HOME": str(home),
            "SERA_SYNC_SOURCE": str(src),
            "SERA_SYNC_BASE_REPO": str(seed),
            "SERA_SYNC_STATE": str(home / "state.json"),
            "SERA_SYNC_REMOTE_URL": str(bare),
        }

        # Initial baseline must NEVER overwrite outdated remote files.
        initial = run(sys.executable, str(SCRIPT), env=env)
        assert "BASELINE CREATED" in initial.stdout, initial.stdout
        assert pushed_text(bare, "README.txt") == "original\n"

        # Only additions/edits are committed; identities are configured.
        (src / "README.txt").write_text("local updated\n")
        model = src / "models" / "SERA_BOOSTER_allテスト.bbmodel"
        model.parent.mkdir()
        model.write_text('{"animations":[{"name":"NEXUS_pose"}]}')
        success = run(sys.executable, str(SCRIPT), env=env)
        assert "PUSH SUCCESS" in success.stdout, success.stdout
        assert pushed_text(bare, "README.txt") == "local updated\n"
        assert "NEXUS_pose" in pushed_text(
            bare, "models/SERA_BOOSTER_allテスト.bbmodel"
        )
        assert "NO CHANGES" in run(
            sys.executable, str(SCRIPT), env=env).stdout

        # Assistant changes GitHub while Android independently edits model.
        second = root / "remote_edit"
        run("git", "clone", str(bare), str(second))
        (second / "scripts").mkdir()
        (second / "scripts" / "remote_feature.gd").write_text("REMOTE\n")
        commit(second, "assistant remote edit")
        run("git", "push", "origin", "main", cwd=second)
        model.write_text('{"animations":[{"name":"NEXUS_pose","length":0}]}')
        success2 = run(sys.executable, str(SCRIPT), env=env)
        assert "PUSH SUCCESS" in success2.stdout, success2.stdout
        assert pushed_text(bare, "scripts/remote_feature.gd") == "REMOTE\n"
        assert '"length":0' in pushed_text(
            bare, "models/SERA_BOOSTER_allテスト.bbmodel"
        )
        assert pushed_text(bare, "README.txt") == "local updated\n"

        # Same-file divergence MUST stop without overwriting either copy.
        run("git", "pull", "--ff-only", cwd=second)
        (second / "models" / "SERA_BOOSTER_allテスト.bbmodel").write_text(
            '{"animations":[{"name":"remote_new"}]}')
        commit(second, "remote model update")
        run("git", "push", "origin", "main", cwd=second)
        model.write_text('{"animations":[{"name":"local_new"}]}')
        conflict = run(sys.executable, str(SCRIPT), env=env, ok=False)
        assert conflict.returncode != 0
        assert "SAME-FILE CONFLICT" in conflict.stdout, conflict.stdout
        assert "remote_new" in pushed_text(
            bare, "models/SERA_BOOSTER_allテスト.bbmodel"
        )
        assert "local_new" in model.read_text()

        # Deletions are not automatically mirrored. Restore the local
        # unpushed model edit first so the previous conflict is not retried.
        model.write_text('{"animations":[{"name":"NEXUS_pose","length":0}]}')
        (src / "README.txt").unlink()
        no_delete = run(sys.executable, str(SCRIPT), env=env)
        assert "NO CHANGES" in no_delete.stdout, no_delete.stdout
        assert pushed_text(bare, "README.txt") == "local updated\n"

        state = json.loads((home / "state.json").read_text())
        assert state["schema"] == 1
        assert state["remote_sha"]
        print("PASS: bootstrap, addition, edit, remote-advance, same-path conflict, no-delete")


if __name__ == "__main__":
    main()
