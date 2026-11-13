# セラ v99 — ジャンプ着地モーション・0.6秒硬直（2026-11-06）

**基準**：v98 `sera_portrait_godot_melee_v98_air_step_melee_steering.zip`。

## 変更点

- 提供された `SERA_jump_stranding.bbmodel` から、長さ0.5秒の更新されたJumpモーション**だけ**を統合しました。元データは `blockbench/SERA_jump_landing_user_input.bbmodel`、統合版は `blockbench/SERA_v99_jump_landing_integrated.bbmodel` に保管。
- 従来のジャンプ（上フリック50px、跳躍高度1.5m、標準滞空0.80秒、初速80%継承、空中姿勢制御30%、空中ステップ/格闘）は維持。
- ジャンプ中はキーフレーム**0.000〜0.375秒**のみを時間補間して使用し、**0.500秒の着地ポーズを空中で先行再生しません**。
- 地面Y=0に到達すると、着地モーション区間 **0.375〜0.500秒** を0.125秒で再生します。
- 追加された最終キーフレーム（着地ポーズ）で**0.600秒**静止し、それから通常の立ち姿／走行姿勢へ0.11秒かけて遷移します。
- 着地モーション＋着地ポーズ固定中は、地上の水平移動、ブースト、ステップ、格闘、再ジャンプ入力を無効化します。入力中に着地した場合は指を離す際のステップ・攻撃の誤作動を抑止します。硬直終了後は同じ指での通常移動を再開できます。
- 空中ステップ・空中格闘後の落下にも同じ着地仕様を適用します。
- **被弾**は着地硬直より優先してリアクションを再生します（被弾で着地硬直中断）。
- ターゲット・カメラ、音声、効果、攻撃AI、モデルのジャンプ以外のキーフレームは変更していません。

## 変更ファイル

- `assets/sera_source.json`：Jumpモーションのみ更新（0.375→0.5秒、着地キーフレーム追加）。
- `assets/sera_data.gd`：同じJSONをAndroid向けに埋め込み直し。
- `blockbench/SERA_jump_landing_user_input.bbmodel`・`SERA_v99_jump_landing_integrated.bbmodel`：元モデル・統合版。
- `scripts/main.gd`：着地動作・姿勢保持・移動入力ロック・被弾割り込み管理。
- `scripts/sera_rig.gd`：空中/着地のアニメーション区間の区別。
- `project.godot`：v99へ変更。
- `DEVELOPMENT.md`・`README_v99_ja.md`・`tools/v99_landing_self_check.py`：履歴・検証。

**検証**：ZIP整合性、元モデルと新モデル差分、ゲーム挙動の静的・数値検査。Godot・Android実機での動作確認は未実施。
