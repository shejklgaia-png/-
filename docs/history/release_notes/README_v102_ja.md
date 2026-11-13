# セラ v102 — ガードモーションの差し替え（2026-11-06）

**基準版：** `sera_portrait_godot_melee_v101_hold_guard.zip`。

- ユーザー提供の `SERA_Guardfix.bbmodel` 内の `Guard` アニメーションクリップだけを採用し、既存のGuardポーズを差し替えました。
- 新旧Guardクリップは22ボーンのUUIDとクリップ識別子が一致します。0秒固定ポーズ／ホールドループの形式を維持しています。
- 差し替えにより新旧で13ボーンのキーフレームが変化しています。ほかのアニメーションやメッシュ、テクスチャ、UVなどは変更していません。
- 操作の仕様はv101と同じです。静止ホールド0.32秒でガード、リリースで解除。ガード中の移動・回避・ブースト・攻撃・ジャンプ禁止、被弾リアクションとノックバック抑止を維持しています。
- 追加した資料：`blockbench/SERA_Guardfix_user_input.bbmodel`（修正版原本）、`blockbench/SERA_v102_guardfix_integrated.bbmodel`（Guardだけを統合したモデル）、`tools/v102_guardfix_self_check.py`。
- 変更したアセット：`assets/sera_source.json`、`assets/sera_data.gd`（Godot用にJSONを埋め込み再生成）。`project.godot` は版名のみの変更です。
- **変更なし：** すべてのGDScriptロジック、シーン、既存のGuard以外のアニメーション、敵AI、カメラ、エフェクト、効果音、デバッグ機能、入力判定。
- 検証：Guardクリップ一致、改変ボーン確認、埋め込みJSON一致、v101との差分検査、静的ガード条件チェック、ZIP整合性チェック。
- **未実施：** Godotエディタ／Android実機での動作・描画検証（実行環境がないため）。

ガードの入力とダメージ挙動の詳しい仕様は `README_v101_ja.md` を参照してください。

## 追加変更（2026-11-06）：ガード中の弾被弾音

- ガード中のAIM／LEAD弾の命中音を、ユーザー確認済みの既存音源 `assets/sera_bullet_hit_short.wav` へ変更。
- 専用AudioStreamPlayerを追加し、音量-5dB・最大多重再生3を維持。
- 非ガード時の弾被弾音、SHOCK／ARCの命中音、ガードの被弾反応抑止、モデル・操作・戦闘処理は維持。
- Python静的チェック3本、Godot headless import・短時間起動・命中音分岐テストで検証。Android実機の聴感確認は未実施。
