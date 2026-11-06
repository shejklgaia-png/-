# セラ v27 — 剣軌跡C / 手動配置平面＋UVスプライトアニメ

## 起動
1. ZIPを展開して、`project.godot` の入ったフォルダーを Godot 4.7.2 でインポートします。
2. ▶で実行します。縦画面720×1280基準で動作します。
3. **短くタップ**：自動接近・`meleeboost` → `melee1` → 斬撃の表示。ドラッグ：v9基準の画面追従移動。
4. PCで検証する場合は **Space/Enter**：攻撃、**C**：青白／赤色のテクスチャを切り替えます。
5. ターゲットが倒れると既存仕様どおり復活します。

## 今回の実装
- お渡しいただいた `セラ･カラーエフェクト付き.bbmodel` の全文を `assets/sera_source.json` に反映。
- `Swordeffect` グループの **位置・回転・スケール**のキーを元データから読み取ります（`melee1` 冒頭の値は X=7.2, Y=-17, Z=-10 / Z回転67.5度 / スケール3.63,1,4.02）。
- 子の `Swordeffect` 四角形メッシュを直接使います。**Godot側で平面の位置・向き・サイズを計算し直しません。**
- **4列×2行／計8フレーム**の透過RGBA斬撃シートを `ShaderMaterial` でUV切替。
- 青白～薄紫の斬撃、細い残光、細長い破片。参考動画の色合いを優先。C案の赤版も同梱。
- 発光は軽量な Unshaded + Emission（Glowを強制せず、AndroidのGL Compatibilityに配慮）。
- **一枚の板のみ**にエフェクトを描画。パーティクル・ランタイムの軌跡メッシュ生成なし。
- v26の外部弧生成は削除。攻撃判定、HP、衝突・ヒットストップ、音声、ドラッグ移動、ターゲット追従はそのまま。

## 編集ポイント
- Blockbenchで `Swordeffect` を再調整した際は `assets/sera_source.json` を新しい `.bbmodel` のJSON内容で置換し、`python3 tools/rebuild_model_data.py` を実行します。
- 攻撃中に表示する時刻は `scripts/sword_trail.gd` の `START_TIME` / `END_TIME` および `advance()` 内のフレーム境界で調整。
- `Swordeffect` のメッシュは**4頂点・1四角形（2三角形）**。元のUV [0..16] を0..1へ正規化します。
- テクスチャ `assets/slash_C_ice_4x2.png`・`assets/slash_C_scarlet_4x2.png` は **2048×1024 RGBA** / 1フレーム512×512。

## 動作検証について
- 添付モデルの `Swordeffect` 親子構造・`melee1` キー・テクスチャサイズとUV・出力アセットを静的検証しています。
- この生成環境にはGodot本体・Android実機がないため、Godotエンジンによるプレイテスト、実機描画は未実施です。実機/エディタでのレンダリングはユーザー環境での確認が必要です。
- 既存のGodot 4.3+互換プロジェクトを保存したまま **4.7.2の安定版を想定**しています。4.8 betaへの移行は行っていません。

## 同梱資料
- `blockbench/セラ･カラーエフェクト付き.bbmodel`：調整済み元ファイル
- `assets/slash_C_preview.jpg`：４つの状態の見本（ゲーム中はPNGを使用）
- `tools/v27_validate.py`：自動静的検査
