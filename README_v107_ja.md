# セラ v107 — 4方向RUNモーションの90度向き修正（2026-11-07）

- 基準：`main` v106 (`d34f2a6ef3c6549b522f3f0a15797997dda8dc01`)。
- 症状：4方向RUNモーションが左方向を正面として再生される。
- 調査：Blockbenchの `Waist` ルートボーンは `Wait_motion` が約-20度、`run_front_original` / `run_back` が約+75度、`run_right` が約0度、`run_Left` が約+177度（Quaternion換算）。差はおよそ90度。
- 修正：RUN 4クリップの描画時に限り、`Waist` ルートのQuaternionへワールドY軸-90度の補正を**左から乗算**し、ルート位置の相対オフセットも同角度で回す。元データのクリップ・骨格・キーはそのまま維持する。オイラー角のYから単に90を引くと左クリップの複合回転を誤補正するため、Quaternionを使用。
- 方向対応：前進・後退で敵方向を向き、右移動・左移動でそれぞれ右・左へ向く姿勢になる。既存の画面ドラッグ移動とターゲット基準のクリップ選択処理は維持。
- 非変更：`assets/sera_source.json`、`assets/sera_data.gd`、`scripts/main.gd`、3段格闘、ステップ、ブースト、被弾、Guard、Jump、カメラ、音楽・効果音、当たり判定。
- `tools/v107_run_facing_self_check.py` で4つのRUNクリップの正面方向、ルートUUID、コード上の修正適用条件、従来の方向選択との整合性を検査。
- **GodotランタイムおよびAndroid実機テスト未実施**。GitSyncでmainを更新後、前・後・右・左RUNおよび遷移を確認してください。
