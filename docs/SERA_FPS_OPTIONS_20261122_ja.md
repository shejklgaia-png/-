# SERA グラフィック：FPS上限設定（2026-11-22）

## 仕様
NEXUS → SYSTEM → FPS SETTINGS に、端末全体の独立したFPS上限3項目を設ける。各行のタップで **60 → 40 → 30 → 20 → 60** と巡回する。

| 適用対象 | 設定キー | 初期値 | 適用時 |
| --- | --- | --- | --- |
| BASEおよびNEXUS屋内 | `base_nexus` | 30 | BASE/NEXUSシーン入場、NEXUSで変更した直後 |
| GRID操作（盤面を真上からズームして編集中） | `grid` | 60 | GRID編集へズーム開始、ズームアウトが完了するまで |
| 戦闘（トレーニング・ビットタラン） | `combat` | 60 | 戦闘シーンの`_ready()` |

GRIDの全体俯瞰・通常BASE→GRID遷移はBASE上限を使用する。保存項目は`user://sera_settings.cfg`内の`[fps]`セクションに保持し、既存の`[controls]`と3つのセーブスロットを保護する。読み取れない数値・未対応値・未保存キーは該当初期値に戻す。

## 実装上の不変条件
- Godot標準の`Engine.max_fps`だけを変更し、擬似的な描画間引きや`Engine.time_scale`の変更はしない。
- BASEは60Hz固定物理更新と生のタッチ入力イベントを維持する。ただし30/20FPS描画時も`_input()`の配送が必ず60Hzとは限らない。
- クレート・施設動作・GRIDカメラTween・戦闘タイマー・AIの実時間速度を変更しない。20FPS時の戦闘操作やモーションの滑らかさは実機で確認する。
- NEXUSのSYSTEMで別サブページを開き、既存のSAVE/LOAD/NEW/DELETEおよびAUTO LOCK/DOMINANT HANDを縮小・削除しない。戻るボタンおよびAndroid戻るでSYSTEMへ戻す。
- FPS設定はセーブデータのロード・削除・NEW作成とは独立して端末に残る。

## 検証
- `tools/sera_fps_options_self_check.py`と`tools/sera_fps_options_runtime_check.gd`
- `tools/base_frame_budget_self_check.py`と`tools/base_frame_budget_runtime_check.gd`を新仕様に更新
- 要実機確認：FPS 60/40/30/20の各選択、シーン切替と保存復元、GRIDの移動・ズーム、BASEのクレート速度、NEXUS戻る、20FPS戦闘入力、端末の発熱
