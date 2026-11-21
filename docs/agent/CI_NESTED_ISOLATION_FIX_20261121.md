# SERA CI nested Godot test isolation repair — 2026-11-21

## Observed regression

Full Godot regression runs 44911011198 and 44913347284 failed after the static
suite passed. The issue was in the test executor, not gameplay: the test
`tools/icon_studio/front_right_orientation_runtime_check.gd` was inserted
directly into `tempfile.TemporaryDirectory(prefix=...)`, creating a prefix
containing a literal `/` and raising `FileNotFoundError` before the worker
could run the test.

## Fix

- `tools/sera_ci_suite.py` now derives `isolation_prefix(relative)` with
  filesystem-safe ASCII substitutions, a 72-character limit and a 10-hex SHA-256
  suffix so distinct nested paths cannot accidentally share the same prefix.
- Each Godot regression still runs in its own fresh XDG data/config/cache tree,
  destroyed after the test. No test registration, worker concurrency, timeouts
  or test exit criteria were removed or weakened.
- Failure to construct one temp directory now appears as a reported per-test
  failure instead of throwing an unhandled Future exception across the suite.
- `tools/sera_ci_timings_self_check.py` was updated before runner code to
  reproduce the nested-path case and to create an actual folder in a
  temporary parent, without needing Godot or external dependencies.

The original model-shape change is PR #640. This CI correction is separate to
avoid conflicts with parallel changes in `DEVELOPMENT.md`.
