# SERA v68 — 被弾モーション統合

## 基準
- v67 `sera_portrait_godot_melee_v67_enemy_shooter_2s_12ms.zip`。
- 提供されたBlockbench `セラ･カラーエフェクト付き (2).bbmodel` の追加クリップ `animation` （0.5秒、once）を `Damage_motion` として追加。

## 挙動
- 敵弾がプレイヤーのカプセルに命中した時だけ、提供された0.5秒のダメージアニメーションを再生。
- 再生中は移動・ステップ・攻撃開始を禁止。被弾中に始めた・中断されたフリックやタップは、終了後に予約発動しない。実行中の攻撃/ステップを中断し、ヒットストップや剣軌跡も終了。
- アニメーション終了で待機に復帰。ドラッグが継続中なら走行に復帰（指を離していたら待機）。
- 被弾中の追加命中では再生を最初からやり直さず、従来の赤いフラッシュのみ更新。
- プレイヤーHP、シールド値、ガード崩れ、ノックバック、ダウンは未実装。既存の敵HP・攻撃処理は維持。

## リソース
- `assets/sera_source.json` はv67のモデル・既存7モーションを維持し、今回の1モーションだけを追加。
- `assets/sera_data.gd` に統合モデルデータを再埋め込み。Android APKでJSONが利用不能でもモーションを利用可能。
- Blockbench編集用統合モデル：`blockbench/セラ_被弾モーション統合.bbmodel`（既存のステップモーションも含む）。

## 変更ファイル
- `scripts/main.gd`, `scripts/sera_rig.gd`, `assets/sera_source.json`, `assets/sera_data.gd`, `project.godot`。
- 既存のBlockbenchモデル（7クリップ）を更新、統合モデルの日本語名コピーを追加。
- `README_v68_ja.md`, `DEVELOPMENT.md`, `tools/v68_damage_self_check.py`。

## 確認
- 元モデルと今回のモデルで骨UUID22件・要素25件・アウトライナーが一致することを確認。
- 元のモデルの既存7モーションはそのまま維持。
- JSON/埋め込み一致、遷移と入力ガード、既存ファイル差分を静的に検査。
- Godot/Android実行は未実施。モーションの見え方は実機で確認が必要。
