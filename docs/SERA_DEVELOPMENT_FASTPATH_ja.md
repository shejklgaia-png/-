# SERA — 安全な高速開発ガイド（2026-11-11）

この文書は **開発エージェント・Codex・ChatGPT向け** の入口です。機能仕様そのものを変更する指示ではありません。現在値は必ず最新の GitHub `main` の実装から取得してください。

## 真実の参照先と優先順位
1. 最新の明示的ユーザー指示と、実機で確認された挙動
2. 現在の `project.godot`、関連する `scripts/`、`scenes/`、`assets/` とモデル原本
3. 現行バージョン `README_vNNN_ja.md`、`DEVELOPMENT.md`、機能別ドキュメント
4. 過去バージョンのREADME・記録（**履歴としてのみ**）

バージョンは `project.godot` 内の `config/name="SERA vNNN"` から自動取得します。READMEやコメントが将来バージョンに先行している場合、理由を確認してから変更します。**勝手にバージョンを進めて差を隠してはいけません。** 2026-11-11 の監査時には `project.godot` は v244、一方 `scripts/main.gd` には v245 の調整コメントがありました。統合途中か記録漏れかは未確定です。

## 作業の最短経路
1. 最新 `main` SHA、オープンPR、作業対象ファイルを確認します。同一ファイルへの並行編集・Android側の未push変更を推測で上書きしません。
2. `python3 tools/sera_code_map.py <検索語>` で関係する関数を絞ります。例: `camera`、`boost`、`lock`、`step`、`nozzle`。定数も必要なら `--include-constants`、AI処理用なら `--json`、巨大ファイルの優先調査は `--summary` を使います。これは**参照索引のみ**で、実装の構造は変えません。
3. 関連関数、呼び出し元、状態遷移、モデル/シェーダー契約を確認して、最小差分を実装します。先に関連テストを把握します。
4. `python3 tools/sera_quick_check.py` でベースの読み取り専用静的検査を実施。3D描画なら `--render` を追加します。続けて関連する `tools/vNNN_*self_check.py` を明示的に実行し、PR側の既存CIを確認します。
5. 差分に無関係な変更がないこととテスト結果を確認してからPRをマージします。失敗・衝突時は強制マージしません。端末側テストは **mainへのマージと同期後に別途実施** します。

## 機能 → 調査の入口（関数行番号は変動します）
| 対象 | 主な入口 | 追加確認 |
| --- | --- | --- |
| タッチ入力・RUN/BOOST・フリックステップ | `scripts/main.gd` の `_input`、`_begin_drag`、`_change_drag`、`_end_drag`、`_update_boost_gesture` | `scripts/touch_overlay.gd`、v243/v244テスト |
| コントローラーの表示 | `scripts/touch_overlay.gd` の `show_drag`、`_draw_analog_controller` | `scripts/main.gd` の入力半径・判定条件 |
| カメラ追従・近接・画面端の揺れ | `scripts/main.gd` の `_place_camera`、`_camera_radius_for_safe_point` | v229〜v234カメラテスト |
| ロックオン・部位破壊 | `scripts/main.gd` の `_switch_lock_screen_direction`、`_update_target_marker_projection` | `scripts/target_parts.gd`、v237/v242/v243テスト |
| 格闘・ガード・追尾 | `scripts/main.gd` と `scripts/sera_rig.gd` の `start_melee_approach` 等 | `docs/SERA_COMBAT_DEFENSE_ENEMIES.md` |
| スライド・IK・接地・装備 | `scripts/sera_rig.gd`、`scripts/sera_equipment.gd` | `docs/MODEL_PART_WORKFLOW_ja.md` |
| 背面スラスター・帯状軌跡 | `scripts/back_thruster_fx.gd` の `set_exhaust` | `docs/RENDER_PIPELINE_POLICY_ja.md` とv223〜v225テスト |
| NEXUSとカスタマイズ | `scripts/command_nexus.gd` | 保存設定・装備プレビュー・バージョン表記 |

## 安全の境界
- **この最適化ではランタイムの `.gd`、3Dモデル、アセット、`project.godot` は変更しません。** 版番号も進めません。
- 静的検査はGDScriptの実行・描画・タッチ・パフォーマンスの証明ではありません。実機未検証を明示します。
- 既存の検査は削除・弱体化せず、既存CIのベース検査を共通ランナーへ統合しました。新規の自動ワークフローやジョブは作りません（既存CIに新ツールの自己検査は追加されます）。
- 今後の安全な段階的改修候補: コントローラー寸法の設定集約 → カメラと入力の責務分割 → 再現可能な実機デバッグ表示。**挙動変更の可能性があるため、このPRには含めません。**
