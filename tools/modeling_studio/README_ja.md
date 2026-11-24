# SERA Modeling Studio（モデスタ） V1

ChatGPTが設計データを編集して機械形状を制作するオフラインCLI。Godotのゲーム実行時には使わない。既存のBlockbench正本、アニメーション、CI設定は変更しない。Blender 4.5 LTSのインストール済み環境を想定する。

## 制作

リポジトリルートから実行。出力先は既存ファイルの破壊を防ぐため、新規ディレクトリを指定する（Godotプロジェクト外を推奨）。

```sh
blender --background --factory-startup --python-exit-code 1 --python tools/modeling_studio/build.py -- tools/modeling_studio/example.json /tmp/sera-model-v1
```

Blenderの実行はモデル制作のための明示的な操作に限る。CI・テスト実行には使用しない。CLIの実行と実際のレンダリング結果は今回未確認。

## 入力

- format: SERA_MODELING_STUDIO_V1
- materials: 名前→rgb（線形RGB 0〜1）、metallic、roughness
- parts: 名前が一意なノードの配列。親は子より先に定義する。
- shape: pivot / box / prism / loft / cylinder / tube / mesh
- box: size、prism: profile（XY座標の輪郭）、depth、loft: rings（対応点順のXYZ断面列）、cylinder: radius/depth/sides、tube: path/radius/sides、mesh: vertices/faces（0始まり）
- 各部品: material、location、rotation_deg、parent、bevel、bevel_segments、weighted_normals、uv、cuts
- cuts: 部品ローカル座標の切削形状。operation は DIFFERENCE（既定）/ UNION / INTERSECT。
- 単位はm、Z上、正面-Y。GLBはY上へ変換。既存Godotモデルに接続する前に軸・原点・名前を確認する。
- loftの断面は同じ頂点数で対応順をそろえ、自己交差させない。tubeは急な折返し・過大半径を避ける。
- UVは部品単位のSmart Projectによる初期値。テクスタへの受け渡し・全体アトラス・ピクセル精度は未実装。

## 出力

model.blend（編集元）、model.glb（ゲーム向け形状・階層、アニメーションなし）、mesh_report.json（頂点、三角形、非多様体辺、ゼロ面積、符号付き体積の情報）、8方向の透過PNG、complete.json（すべての生成工程終了時に出力）。途中で失敗した出力ディレクトリは成功扱いしない。レポートは制作情報であり、テスト結果や貫通検査の代わりではない。

## ChatGPTの制作手順

1. 設定画と既存モデルの原点・可動部を参照し、主要比率を決定する。
2. JSONで主要形状を設計する。細部より輪郭・空洞・主要面を優先。
3. 制作環境でCLIを実行し、8方向画像を取得する。正投影・同一スケールで比較。設定画の視点が異なる場合は別途合わせる。
4. 比率・断面・部位位置を修正し、新しい出力先で再生成する。
5. 形状が確定してから面取り・細部・材質を追加。出力レポートを参照し、必要なら形状やセグメント数を調整する。
6. GLBは既存ゲームの原本やモデルを自動置換しない。ゲームへの統合は別作業。

## 未実装

外部Blenderホストの自動起動・画像回収コネクタ、設定画の自動輪郭抽出・IoU比較、CAD連携、テクスタ等との自動連携、LOD・ノーマルマップベイク、アニメーション移植、既存モデル更新。V1はこれらに先立つ制作基盤。

## 技術資料

- Blender 4.5 LTS CLI: https://docs.blender.org/manual/en/4.5/advanced/command_line/arguments.html
- glTF API: https://docs.blender.org/api/current/bpy.ops.export_scene.html
