# SERA 全身モデル：アイリス材質設定の一次展開（2026-11-22）

## 適用範囲
NEXUS → CUSTOMIZE の全身SERA展示リグ（`SeraDisplay`）へ暫定適用する。
HEAD／TORSO／ARMS／LOWER BODY／BOOSTER／RIGHT WEAPON／LEFT WEAPON の7スロット、実装済み各セットA・B・C・D等の装備メッシュと刀セットKを、現在非表示の候補を含めて処理する。装備変更後も同じ材質設定を使用する。

**この段階では**BATTLE、LAB、STORAGE、装備アイコン生成、アイリス単体プレビューおよび施設・ボスなどSERA以外のモデルには適用しない。既存の個別調整・5枠プリセット、ユーザーのセーブデータ、元のBlockbenchファイルは変更しない。

## コピー値（`SERA_IRIS_MATERIAL_SHADING_V1`）
```json
{
  "format": "SERA_IRIS_MATERIAL_SHADING_V1",
  "lens_lit": false,
  "materials": {
    "armor": {"steps": 8, "threshold": 0.65},
    "dark_mechanism": {"steps": 2, "threshold": 0.70},
    "emission": {"steps": 0, "threshold": 0.0},
    "lens": {"steps": 3, "threshold": 0.10}
  },
  "model": "H02/アイリス",
  "scope": "NEXUS_SINGLE_PREVIEW"
}
```
JSONの値だけを全身プレビュー用シェーダーの初期設定として固定する。元のJSONのscopeは変えず、アイリス単体に保存済みの値も上書きしない。全身展示モデルでの独立UIやセーブ機能は今回設けない。

## 暫定材質の分け方
- カメラアイ頭部（16×16テクスチャ）：ライトグレー外装＝装甲。濃淡ダークグレーの内部・枠＝暗色機構。水色＝レンズ（発光OFF）。
- 通常SERA装備（96×32テクスチャ）：装甲・武器の外側の面は装甲を基本とする。関節、膝、首、駆動軸、モーター、ケーブル、ピストン、サーボ等の部品名・階層に該当するものを暗色機構候補にする。装備のテクスチャには元から上・横・下の暗い色が焼き込まれているため、単純に暗い画素をすべて機構に分類しない。
- 非発光の青緑〜水色の画素はレンズ判定とする。見た目・名称・配置による暫定割当なので、今後モデルごとに上書き指定可能にする。
- 元材質のテクスチャ色・A/B等の色味は維持し、シェーダー内の階調照明を重ねる。描画パスを増やさず、同じテクスチャ／着色／分類の装備は共有材質で処理する。

## 輪郭・法線
- NEXUSのSERAは既存の `SeraRig` → `SeraViewEdges`（3px、#17212f）を引き続き使用。頭部から左右武器まで全ての有効な装備MeshInstance3Dに自動追従する。透明エフェクトと剣エフェクトは除外。
- 不規則な三角陰影が再発しないよう `SeraRig._make_mesh` で元Blockbenchの1面に属する全三角形へ同一の面法線を設定する。位置／UV／面の頂点並び／アニメーションは変えない。
- 表裏の描画は従来のメッシュ属性 `sera_single_sided` を使用し、閉じた面と開いた面で別シェーダーを選択。
- 既存のNEXUS全身ポーズ、装備選択、ハイライト、輪郭を優先。ゲーム本編の材質はこの第一次展開では変更しない。

## 実装
- `scripts/sera_fullbody_material_preview.gd`：全候補装備メッシュとテクスチャを列挙、暫定分類、キャッシュした材質へ割当。
- `shaders/sera_fullbody_material_shading.gdshader` / `shaders/sera_fullbody_material_shading_closed.gdshader`：共通の段階・しきい値シェーダー。
- `scripts/command_nexus.gd`：NEXUS展示リグの生成直後にのみ適用。
- `scripts/sera_rig.gd`：Blockbenchの元ポリゴン面法線を統一。

## 未確認事項
Android GL Compatibilityでの実画面、装備差替え・C/Dパーツ・両手／片手武器、長時間表示時のFPS・負荷を未確認とする。最新のユーザールールに従ってCI項目・期待値・テストコードの更新やテスト実行は行わない。
