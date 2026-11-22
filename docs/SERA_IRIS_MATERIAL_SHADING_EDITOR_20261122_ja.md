# SERA IRIS — NEXUS single-part material shadow editor (2026-11-22)

Scope: NEXUS → CUSTOMIZE → H02/アイリス単体プレビューのみ。
LAB・倉庫・SERA全身・戦闘・装備モデル原本は対象外。
現行の3pxメッシュID輪郭、原本BB四角面法線補正を維持する。右上の一括OFF／2〜8段切替は廃止し、陰影段階は材質別にのみ変更する。

## 使い方
1. NEXUSのアイリス単体プレビューをダブルタップして拡大する。
2. 左上の「材質調整」を押す（縮小時にはこのボタンは存在しない）。
3. 装甲／暗色機構／レンズの各行で、陰影段階（OFF、2〜8段）としきい値（0.00〜1.00、0.05刻み）を個別変更する。一括段階ボタンは表示しない。
4. 材質名を押すと該当色の部位が青白く1回だけ約0.65秒点灯する。3Dオブジェクトの複製や元モデルの改変はしない。
5. 「水色 点灯: ON/OFF」で水色をレンズ／発光表示に切り替える。発光状態は陰影を持たないため、発光行の段階としきい値は固定値（0、0.00）。
6. 「全材質をコピー」を押すと、全4材質の現在の数値と点灯状態を端末のクリップボードへJSON形式でコピーする。ChatGPTへ貼り付けて結果の記録・次回調整に利用する。
7. 縮小すると材質調整ボタンとパネルは消える。調整値は端末共通の最後の設定へ自動保存し、5枠のプリセット保存／読込も利用できる（詳細は `SERA_IRIS_MATERIAL_PRESETS_20261122_ja.md`）。

## 識別
原本 `models/storage/カメラアイ頭部.bbmodel` の単一16×16テクスチャに含まれる4色のうち、
- `#b8bec4` → 装甲（ライトグレー）
- `#353637`, `#5d5f60` → 暗色機構（ダークグレー2色）
- `#2b8dad` → 非点灯時はレンズ、点灯時は発光（水色）

色識別はUVテクスチャの画素色によるもので、単一メッシュ内で混在していても正しく適用する。
シェーダー内の陰影しきい値は、2段時の明暗境界の照度に一致し、3〜8段時は全段の境界を同じ量だけ平行移動する。OFFではRGBを元のまま表示（点灯と一時選択フラッシュは別）。
原本の三角形分割を陰影に出さないよう、従来の authored quad normal 平準化を維持する。

## 初期値
| material key | 陰影段階 | しきい値 |
|---|---:|---:|
| `armor` | 4 | 0.55 |
| `dark_mechanism` | 4 | 0.60 |
| `lens` | OFF（0） | 0.25 |
| `emission` | OFF（0） | 0.00（固定） |

点灯状態の初期値は false。

## Clipboard JSON
```json
{
  "format": "SERA_IRIS_MATERIAL_SHADING_V1",
  "model": "H02/アイリス",
  "scope": "NEXUS_SINGLE_PREVIEW",
  "lens_lit": false,
  "materials": {
    "armor": {"steps": 4, "threshold": 0.55},
    "dark_mechanism": {"steps": 4, "threshold": 0.60},
    "lens": {"steps": 0, "threshold": 0.25},
    "emission": {"steps": 0, "threshold": 0.0}
  }
}
```
この例は初期値。実際にはUIの現在値を出力する。

## Verification
先行した静的契約：`tools/iris_material_shading_editor_self_check.py`
旧一括段階UIが存在しないことも検査：`tools/iris_polygon_shading_fullscreen_self_check.py`
Godot UIテスト：`tools/iris_material_shading_editor_runtime_check.gd`
`tools/sera_ci_manifest.txt` に登録済み。Androidの実画面・タッチ・クリップボード・GL Compatibility表示は別途実機で確認する。
