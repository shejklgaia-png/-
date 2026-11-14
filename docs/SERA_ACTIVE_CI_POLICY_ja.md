# SERA 現行仕様と履歴CIの分離（2026-11-13）

**目的**：旧バージョンの距離・速度・姿勢などを最新仕様として固定し続け、機能変更のたびにCIが失敗する問題を防ぐ。テストを一律スキップしたり、失敗を無視しない。

## 現行仕様の正本（テスト期待値）
- `tools/sera_active_specs.json`：現在承認されたSTEP距離、速度、発動時の移動量とFX、蹴りの独立した距離・速度。**意図したゲーム仕様変更のときだけ更新**する。
- `tools/sera_active_contracts_self_check.py`：上記仕様と実コードの値・機構を照合する。コードの現在値を自動で正解扱いする検査にはしない。
- 古い `vNNN_*` テストは原則として**現在も維持すべき振る舞い**を検査する。変更可能な数値の期待値は現行仕様から取得し、過去の絶対値を別の正本にしない。
- 過去のキーフレームや軌道の検査はユーザーによる変更がない限り保護する。

## 開発エージェントの作業順
1. `project.godot` で現行バージョンを確認する。`python3 tools/sera_dev_index.py step --json`、`sera_code_map.py`、`sera_change_impact.py` を利用する。
2. STEP・蹴りの仕様を明示変更した場合は `tools/sera_active_specs.json` を**同一PRで**更新する。関係しない仕様は変えない。
3. 旧テストが落ちたら「保持する不変条件／意図して上書きされた旧数値／実装バグ」に分類する。バグをテスト側の変更で隠さない。
4. 局所テスト → 共通CIの全件 → 差分レビューでマージする。Godot headlessとAndroid実機は分けて報告する。
5. 新テストは `tools/sera_ci_manifest.txt` に登録する。未登録テストは共通CIでは実行されない。

## 高速化
- `sera_dev_index.py` で関数、リソース、原本JSONのモーション名、登録済テストを検索する。
- CIの既存Python/Godotの独立プロセス・並列検証を維持する。
- 旧v293独立CIは共通CIと検査が重複するため、PRでの二重実行を止め手動診断専用とする。
- `.godot/` は再生成可能なエディタキャッシュ。Git追跡を外し、同期負荷を減らす。同期時はエディタ・Blockbenchでの書込を避ける。
- CIのGodot初回インポート負荷はGitHub Actionsのキャッシュ（アセット内容のハッシュでキーを分離）で抑える。初回・素材変更直後はコールドインポートとなる。

**この変更では**ゲーム挙動・モデル/モーション正本を変更しない。将来のモデル参照統一は別途、依存確認と実機確認を行う。

## v354 Bittaran lock regression rule
- Front/rear AUTO uses the current final-IK shin pair midpoints in world XZ. Do not rotate a saved standing boundary with the chassis: planted feet lag yaw.
- Target root motion/bob must finish before `_finalize_target_pose`, which completes contact IK/part sync before main's collisions and AUTO. Do not move IK back after AUTO.
- Lock regression expectations must come independently from actual post-IK shin Areas. Exercise full scene physics and both traversal directions; a sweep constructed from the selector's own calibration cannot prove visible boundary correctness.

## 2026-11-14：履歴テストの更新時に保持する条件
- プロジェクト名の検査は最低対応版。特定版への完全一致で将来の版を拒否しない。承認済み数値は既存のactive_specsを参照し、現在の実装値を期待値として自動取得しない。
- v337/v339以後、Bash/蹴りの方向は指開始点から非クランプのロック投影へ向かう。ガード/攻撃フリックでは開始時方向を保持し、通常のRUN/BOOST時のみ実時間更新する。通常STEPは画面方向の連続入力を維持。
- v340以後、左右蹴りは円弧を作らず、2段目ヒットの次フレームから受理した方向へ直線移動。v341以後、サマーソルトの空中曲線末尾と着地後退の速度が連続する。
- v338以後、旧HUDは非表示。旧フォーマッタ検査でのみ明示表示し、通常の表示と入力領域は現行HUD検査で保証する。
- Godot検査の保存領域はテスト名ごとの固定ディレクトリを再利用しない。実行ごとに新規作成・終了時削除し、再実行でも装備・設定の初期条件を一定にする。
