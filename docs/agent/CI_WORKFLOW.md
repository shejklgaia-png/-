# SERA エージェント — 実装・CI作業手順（原本から分離）

## Fast, safe work sequence
1. Confirm latest `main` SHA, `project.godot` version, open PRs, and requested feature; never infer live state from old notes.
2. Use `tools/sera_workplan.py --query <feature> --json` (or `--changed <path>`) to find sources and tests. Inspect real code; suggestions are heuristic.
3. Make minimal, reviewed diffs on a short-lived branch. Preserve models and unrelated mechanics.
4. Run focused checks while editing. **Merge first; run the full `tools/sera_ci_manifest.txt` Python/Godot CI suite on `main` afterward.** Focused checks never replace full CI.
5. Before merge check conflicts, unsafe edits, model sources and diff; never merge known destructive changes. After merge, if CI fails, **report the failure and fix without user approval**. Identify the cause, preserve approved gameplay and test coverage, merge a minimal fix, then rerun full post-merge CI. Repeat if needed; never hide a regression by weakening tests. If blocked, report why. Give fix/CI URLs and accurate status. ChatGPT checks code, logs and numeric regressions; humans check Android motion, input, visuals, audio and feel.
6. Log meaningful changes in `DEVELOPMENT.md`. Update versioned README and increment version only for user-requested gameplay changes.

## 更新前のCI仕様確認・先行修正（全アップデートで必須）
**新機能・バグ修正・調整・UI変更・モーション変更など、毎回の更新で必ず実施する。**
1. **変更開始前**に、現在の `.github/workflows/`、登録済みCIテスト、関連するテストケースと期待値を確認する。SERAでは `tools/sera_ci_manifest.txt` と `docs/SERA_ACTIVE_CI_POLICY_ja.md`、必要に応じて `tools/sera_active_specs.json` も確認する。古い履歴テストが現行仕様と整合するか判定する。
2. 依頼された新仕様とテストの関係を「変更する期待値」「新規追加する検証」「保持すべき不変条件」「影響しないテスト」に分類する。影響するテスト名と具体的な変更理由を把握する。
3. **明確に仕様が変わる箇所は、アプリ／ゲーム本体の実装前に、関連CIテストの期待値・条件・フィクスチャを新仕様に合わせて先に編集する。** テストを追加すべき場合も先に追加する。同じ変更セット／PRに本体実装とテスト更新を含める。仕様変更のない既存検査は維持する。
4. 期待値はユーザーが承認した仕様などの**独立した根拠**から定義する。実装の現在値を読み取って無条件に正解扱いしない。テストの削除・一律スキップ・閾値の無根拠な緩和・失敗の握りつぶしは禁止。真の回帰はテストではなく実装を修正する。
5. テスト更新後に本体を実装し、関連する局所テストを実行する。その後、**このリポジトリで定められた全CI実行順序**に従い、全件検証する。SERAは既存規則どおり **マージ後のmainでフルCI** を必ず実施する。
6. CI失敗時は「更新漏れの旧仕様テスト／新実装の不具合／環境問題」を切り分ける。必要な修正と再実行を承認待ちなしで進め、修正不能なら原因を報告する。実機の操作感・動き・表示・音は自動CI合格とは分けて確認する。
7. 完了報告に **事前確認したCI項目、先行更新したテスト（理由と変更点）、新規テスト、CI結果、残る実機確認事項** を明記する。

## Quick commands
```sh
python3 tools/sera_workplan.py --query step --json     # focused edit plan
python3 tools/sera_workplan.py --query katana --execute # local registered Python tests only
python3 tools/sera_quick_check.py                       # core static checks
python3 tools/sera_ci_suite.py static --workers 4      # FULL registered Python suite
# GitHub main push CI runs the FULL Godot suite after merge, in isolated processes.
```

Historical instructions and v102–v292 decisions remain available at `docs/history/AGENTS_THROUGH_V316.md`; their superseded numeric values, model paths and design drafts must not override the current code.

