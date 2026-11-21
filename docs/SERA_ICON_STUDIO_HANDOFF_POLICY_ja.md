## Godot実レンダリングをアイコンの正本とする運用（2026-11-21）
- **Icon Studio（WebGL）は撮影角度・倍率・平行移動を決める操作UI**として維持します。そこから送られた `SERA_ICON_PRESET_V1` の数値は変えません。
- **ゲームへ納品する最終アイコンはSERA本体のGodot 4.7.2／GL Compatibilityで一度だけ撮影します。** `tools/icon_studio/sera_godot_native_capture.gd` が実際の `SeraRig` HEAD D 装着用メッシュ／マテリアル／16pxテクスチャを使用し、`scripts/sera_view_edges.gd` と `shaders/sera_view_edges.gdshader` で輪郭線を描きます。照明は戦闘シーン `scripts/main.gd::_build_world` と同じ環境光とDirectionalLightを設定します。
- 専用SubViewport 512×512、透過背景、正投影、原本の `H02.json` 回転X/Y/Z・倍率・panを再現してオフライン撮影します。**Node3D標準のYXZ回転でなく、Icon Studioと同じXYZ回転順**を指定します。モデリングの再構築やJavaScriptのLambert近似は使いません。
- GitHub Actionsの `SERA model workflow policy` 内で、xvfb付きGL Compatibility画面から `SERA_H02_IRIS_GODOT_512.png` をキャプチャし、`annotate_godot_native_png.py` で `SERA_ICON_MANIFEST_V1` を付加して成果物 `sera-native-equipment-icon` として保存します。**CI成果物を確認後、承認された撮影画像を従来の共有アイコンキャッシュへ登録**します。CIで画像がない・真っ黒・背景が不透明なら失敗とし、既存ゲームアイコンへの無条件差替えは禁止します。
- **ゲーム実行中にSubViewportを追加したり、装備カード表示ごとに3Dレンダリングしないこと。** 完成PNGを1設計図につき1回だけ読み込み・キャッシュし、LAB／倉庫／NEXUSで再利用します。
- モデル原本の再アップロードも、ユーザーによるPNGの手動受け渡しも原則不要です。プリセット送信だけでGodot撮影工程へ進めます。ゲーム内の光源は場面によって違うため、**装備アイコンの正式な基準は戦闘シーン照明**と定義します。Android実機のGPUとCIのLinux GL描画結果は厳密なピクセル一致までは保証しません。

# SERA — 装備専用Icon Studioの受け渡しと実装順序（2026-11-21）

以下は `AGENTS.md` の装備アイコン作業順序から**全文を移した正式な受入条件**です。内容と運用上の拘束力を変更しません。

## 装備追加の順序：原本同梱アイコンHTMLを最初に渡す（2026-11-21）
- **装備実装の前に** 正本 `.bbmodel` （テクスチャ含む）を `tools/icon_studio/build_sera_icon_studio.py` で単一HTMLへ埋め込み、**このチャットで完成した装備専用HTMLをユーザーに渡す**。ユーザーにBlockbenchファイルの再ダウンロード・手動読み込み・アップロードを求めない。
- HTML受け渡し後、原本モデルをゲームへ実装し、LAB装備作成／製作設計図／レシピ／倉庫／NEXUS／保存まで従来の完了条件を遂行する。ユーザーが撮影構図を未確定なら暫定画像と確定済みを区別し、確定アイコンを勝手に生成・確定しない。
- Icon Studioの「透過PNGを保存」は `SERA_ICON_MANIFEST_V1`（原本のGitHubパスとSHA-256、設計図ID、slot、rig_set、撮影角度・ズーム・移動）をPNG内に埋め込む。他のチャットでユーザーがそのPNGだけをアップロードした場合は `tools/icon_studio/read_sera_icon_png.py` で原本・装備の対応を確認し、ゲームの該当装備アイコンへ反映する。モデル原本はGitHub正本を参照し、再アップロードを要求しない。
- 画像の再エンコードでPNGメタデータが消える場合があるため、ファイル名と設計図で確認。曖昧なときは誤適用しない。ユーザーが原本を特定できる `SERA_ICON_PRESET_V1` を送って実装を指示した場合は、その厳密な回転・倍率・移動・輪郭線で原本モデルをソフトウェアレンダリングして装備アイコンへ登録してよい（画像生成AIや既存の別角度画像で代替しない）。別途ユーザーが書き出したPNGを送った場合は、その画像を優先。詳細は `tools/icon_studio/README.md` と `docs/MODEL_PART_WORKFLOW_ja.md`。



## 2026-11-21 共有アイコン背景と負荷
- ユーザー指定の**単色#111e28＋ブルーグレー#55798Aの格子**は `scripts/sera_icon_background.gd`を正本とする。`sera_item_icons.gd`は透明な正式PNGや旧WebPアトラスの上に必要な同背景をCPU上で**一度だけ2D合成し設計図IDでキャッシュ**する。ゲーム内のカードごとにSubViewportを生成しない。
- Godot単体プレビューでは同じ色・目盛の格子を実背景に配置。PNG原本が透明な仕様は維持できる（ゲーム側のアイコン表示時に背景を追加）。モデルのテクスチャ・原本アイコン・ハッシュを勝手に変更しない。
