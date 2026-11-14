#!/usr/bin/env python3
"""Fast, failure-complete execution of the existing SERA regression inventory.

No tests are skipped or combined inside a shared Godot scene. Every test still
runs as an independent subprocess and reports its own exit code and output.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools" / "sera_ci_manifest.txt"
ANIMATION_SMOKE = "tools/sera_animation_runtime_smoke.gd"
ANIMATION_SUCCESS = "GODOT_ALL_ANIMATIONS_TEST PASSED"
SCRIPT_ERRORS = ("SCRIPT ERROR", "Parse Error", "SERA ANIMATION RUNTIME REGRESSION")
TIMING_HINTS = ROOT / "tools/sera_ci_timings.json"


def load_tests(kind: str) -> list[str]:
    tests: list[str] = []
    seen: set[str] = set()
    for lineno, raw in enumerate(MANIFEST.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        tokens = line.split()
        if len(tokens) != 2 or tokens[0] not in {"py", "gd"}:
            raise ValueError(f"{MANIFEST.name}:{lineno}: invalid test declaration")
        test_kind, relative = tokens
        path = ROOT / relative
        if relative in seen:
            raise ValueError(f"{MANIFEST.name}:{lineno}: duplicate test: {relative}")
        seen.add(relative)
        if not relative.startswith("tools/") or path.suffix != (".py" if test_kind == "py" else ".gd"):
            raise ValueError(f"{MANIFEST.name}:{lineno}: forbidden test path: {relative}")
        if not path.is_file():
            raise FileNotFoundError(f"{MANIFEST.name}:{lineno}: missing test {relative}")
        if test_kind == kind:
            tests.append(relative)
    if not tests:
        raise ValueError(f"No {kind!r} tests are registered")
    if kind == "gd" and ANIMATION_SMOKE not in tests:
        raise ValueError("The authored-animation smoke test is mandatory")
    return tests


def focused_selection(kind: str, requested: list[str] | None) -> list[str]:
    """Validate a local focused subset; full PR CI never supplies --tests."""
    registered = load_tests(kind)
    if requested is None:
        return registered
    if not requested or len(requested) != len(set(requested)):
        raise ValueError("Focused tests must be a nonempty, unique list")
    unknown = set(requested) - set(registered)
    if unknown:
        raise ValueError("Unregistered/incorrect test kind: " + ", ".join(sorted(unknown)))
    return [path for path in registered if path in requested]


def prioritize_slowest(tests: list[str], kind: str, hints: Path = TIMING_HINTS) -> list[str]:
    """LPT scheduling improves the tail; no test is skipped or reclassified."""
    try:
        data = json.loads(hints.read_text(encoding="utf-8"))
        if data.get("schema") != 1:
            return list(tests)
        durations = data["tests"][kind]
    except (OSError, ValueError, TypeError, KeyError):
        return list(tests)
    order = {path: index for index, path in enumerate(tests)}
    return sorted(tests, key=lambda path: (-max(0.0, float(durations.get(path, 0.0))),
                                          order[path]))


def run_test(kind: str, relative: str, godot: str, timeout: int) -> tuple[str, bool, float, str]:
    isolated = None
    if kind == "py":
        command = [sys.executable, relative]
        env = os.environ.copy()
    else:
        command = [godot, "--headless", "--path", ".", "--script", f"res://{relative}"]
        env = os.environ.copy()
        # Each execution needs a fresh user:// tree, including reruns of
        # the same test. Equipment tests save settings at the end.
        base = Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir()))
        unique = relative.removeprefix("tools/").removesuffix(".gd")
        isolated = tempfile.TemporaryDirectory(prefix="sera-ci-" + unique + "-", dir=base)
        for folder, variable in (
            ("data", "XDG_DATA_HOME"), ("config", "XDG_CONFIG_HOME"),
            ("cache", "XDG_CACHE_HOME")
        ):
            location = Path(isolated.name) / folder
            location.mkdir(parents=True, exist_ok=True)
            env[variable] = str(location)
    start = time.monotonic()
    try:
        completed = subprocess.run(
            command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding="utf-8",
            errors="replace", timeout=timeout, check=False
        )
        output = completed.stdout
        failed = completed.returncode != 0
        if kind == "gd":
            failed = failed or any(token in output for token in SCRIPT_ERRORS)
            if relative == ANIMATION_SMOKE:
                failed = failed or ANIMATION_SUCCESS not in output
        success = not failed
        if failed:
            output = f"Exit code: {completed.returncode}\n{output}"
    except subprocess.TimeoutExpired as exc:
        success = False
        output = f"Timed out after {timeout}s\n{exc.stdout or b''}\n{exc.stderr or b''}"
    except OSError as exc:
        success = False
        output = f"Unable to start test: {exc}"
    finally:
        if isolated is not None:
            isolated.cleanup()
    return relative, success, time.monotonic() - start, str(output)


def write_summary(kind: str, results: list[tuple[str, bool, float, str]], wall: float) -> None:
    failures = [(name, duration) for name, ok, duration, _ in results if not ok]
    summary = (
        f"### SERA {kind} regression suite\n\n"
        f"- Executed: **{len(results)}**\n"
        f"- Passed: **{len(results) - len(failures)}**\n"
        f"- Failed: **{len(failures)}**\n"
        f"- Wall time: **{wall:.2f}s**\n"
        f"- Aggregate test time: **{sum(x[2] for x in results):.2f}s**\n"
    )
    if failures:
        summary += "\n**Failing tests:**\n" + "".join(
            f"- `{name}` ({duration:.2f}s)\n" for name, duration in failures
        )
    slowest = sorted(results, key=lambda x: x[2], reverse=True)[:5]
    summary += "\n**Slowest tests:**\n" + "".join(
        f"- `{name}`: {duration:.2f}s\n" for name, _, duration, _ in slowest
    )
    print(summary, flush=True)
    step_summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if step_summary:
        with open(step_summary, "a", encoding="utf-8") as f:
            f.write(summary + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=["static", "godot"])
    parser.add_argument("--workers", type=int, default=None)
    parser.add_argument("--tests", nargs="+", default=None,
                        help="LOCAL FOCUSED checks only; full PR CI must omit this flag")
    parser.add_argument("--godot", default=os.environ.get("SERA_GODOT_BIN", ""))
    parser.add_argument("--report-json", default="", help="write per-test duration/status for CI profiling")
    args = parser.parse_args()
    kind = "py" if args.suite == "static" else "gd"
    try:
        tests = focused_selection(kind, args.tests)
        tests = prioritize_slowest(tests, kind)
    except (OSError, ValueError) as exc:
        print(f"Manifest invalid: {exc}", file=sys.stderr)
        return 1
    workers = args.workers or (4 if kind == "py" else 3)
    if not 1 <= workers <= 8:
        parser.error("workers must be in the 1..8 range")
    if kind == "gd" and (not args.godot or not Path(args.godot).is_file()):
        print(f"Godot executable not found: {args.godot}", file=sys.stderr)
        return 1
    mode = "FOCUSED (NOT FULL CI)" if args.tests is not None else "FULL"
    print(f"SERA {args.suite}: {mode} - executing {len(tests)} registered tests with "
          f"{workers} worker(s); per-test process isolation retained", flush=True)
    start = time.monotonic()
    timeout = 90 if kind == "py" else 180
    results: list[tuple[str, bool, float, str]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(run_test, kind, relative, args.godot, timeout)
                   for relative in tests]
        for future in concurrent.futures.as_completed(futures):
            name, ok, duration, output = future.result()
            results.append((name, ok, duration, output))
            print(f"{'PASS' if ok else 'FAIL'} {name} ({duration:.2f}s)", flush=True)
            if not ok:
                print(f"::group::{name} failure\n{output.rstrip()}\n::endgroup::",
                      flush=True)
                print(f"::error file={name},title=SERA regression failed::{name} failed",
                      flush=True)
    wall = time.monotonic() - start
    write_summary(kind, results, wall)
    if args.report_json:
        report = {
            "schema": 1, "kind": kind, "full_suite": args.tests is None,
            "wall_seconds": round(wall, 3),
            "results": [{"test": name, "success": ok, "seconds": round(duration, 3)}
                        for name, ok, duration, _ in sorted(results)],
        }
        destination = Path(args.report_json)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n",
                               encoding="utf-8")
    return 0 if all(ok for _, ok, _, _ in results) and len(results) == len(tests) else 1


if __name__ == "__main__":
    sys.exit(main())
