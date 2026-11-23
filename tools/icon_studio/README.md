## 全19装備PNGの新方式撮影・ゲーム反映（2026-11-23）

本日時点の正本は、NEXUSと同じ**可視メッシュID＋深度による接合線・輪郭線**です。
旧・反転ハル方式／古い線シェーダーをアイコン撮影へ流用しません。
`tools/icon_studio/sera_all_native_capture.gd` も `sera_godot_native_capture.gd` も
`ViewEdges.set_nexus_sera_contact_mode(true)` を撮影前に設定します。

既存19設計図の正本3Dメッシュ、マテリアル、`NEXUS_pose`、
`assets/ui/sera_icon_presets/H02.json` の撮影角度・構図を維持します。
出力は透過512×512 PNGです。設備枠・グリッド背景・名前を焼き込みません。

**Godot GL Compatibilityを実行できる表示環境で、リポジトリのルートから**
次の制作コマンドを1回実行します（CIテストではありません）。

```bash
python3 tools/icon_studio/recapture_all_icons.py
```

Godotコマンドが標準の名前ではない場合は、`GODOT_BIN` 環境変数に
その実行ファイルのパスを指定します。処理は現在の撮影方式で
`assets/ui/sera_equipment_icons/{設計図ID}.png` の19枚を撮影し直した後、
`tag_all_icons.py` で各PNGの原本情報と
`assets/ui/sera_equipment_icons/manifest.json` の画像SHA-256を更新します。
`scripts/sera_item_icons.gd` は既にその19枚を読み込んでおり、
LAB・倉庫・NEXUSでは既存の設計図別2Dキャッシュに反映されます。
表示時に3D撮影を増やさず、装備UIDや保存形式も変えません。

**このコマンドを実際に実行し、生成PNGの変更をGitへ保存するまでは
撮影済み・全画像反映済みとは扱いません。** CI/テストは起動しません。

## 最終採用画像はGodot GL Compatibilityの撮影で作成（2026-11-21）

これまでは `SERA_ICON_PRESET_V1` を別レンダラーで再計算していましたが、色・光沢・法線・輪郭線の表示がSERA本体と一致しませんでした。**ブラウザでは引き続き角度と大きさを調整し、撮影設定だけをコピー**します。

最終画像の作成には `tools/icon_studio/sera_godot_native_capture.gd` を実行します。これはSERAの `sera_rig.gd` と `sera_equipment.gd` が実際に装備するHEAD Dの6メッシュ、実際の `material_override`、共通 `sera_view_edges.gd` / `sera_view_edges.gdshader`、戦闘シーン `main.gd::_build_world` と同じ環境光・方向光を使います。512×512の正投影SubViewportを一度だけ使い、元モデルの頂点・UVを再構築しません。

```bash
# Godot 4.7.2 / GL Compatibility / 画面描画可能な環境で実行します。
SERA_UI_RENDER_DIR=/tmp/sera-icon \
  godot --path . --rendering-method gl_compatibility \
  --script tools/icon_studio/sera_godot_native_capture.gd
python3 tools/icon_studio/annotate_godot_native_png.py \
  --png /tmp/sera-icon/SERA_H02_IRIS_GODOT_512.png
```

GitHub Actions `SERA model workflow policy` は上記をXvfb上で実行し、`sera-native-equipment-icon` という成果物に原本SHAや撮影設定入りPNGを保存します。検査済みのPNGを `install_sera_equipment_icon.py` で設計図H02へ登録すれば、以後は既存の共有キャッシュからLAB/倉庫/NEXUSで表示されるため、端末のプレイ中にSubViewport生成やモデルレンダリングを行いません。

**ゲーム内カメラ・照明は場面ごとに異なります。** アイコンの標準は戦闘シーンの照明を基準とします。GodotのCI (Linux GL) と端末のAndroid GLではピクセル完全一致までは保証しません。Icon Studio WebGLプレビューとも多少異なりますが、ゲーム内の素材・輪郭線と整合する仕組みです。

# SERA Icon Studio — 原本モデル埋込・装備アイコン引継ぎ

## 2026-11-21 ユーザーの固定作業順序
1. **まず**新しい装備の正本 `.bbmodel` を確認し（`models/manifest.json` に登録）、`build_sera_icon_studio.py` により**その原本のJSON＋埋込テクスチャを単一HTMLに同梱**して、このチャットでHTMLを渡す。ユーザーにファイル読み込み・原本モデルの再アップロードを要求しない。
2. ユーザーがHTMLを開くと自動的に原本が3D表示され、ドラッグ／ピンチ／二本指ドラッグで回転・縮小拡大・平行移動できる。設定コピーも可能。アイコンは**実モデルのレンダリング**であり、AI生成画像に置き換えない。
3. HTMLを渡してから、**LABの装備作成設計図、モデル読込、素材レシピ、装備ステータス、アイコン適用、倉庫、セーブ、NEXUS装着**の実装作業を実施する。ユーザーが撮影確定する前ならアイコンは暫定と明示し、勝手に確定した構図へ差し替えない。ユーザーの撮影確定PNGが届いたら完成版アイコンを反映する。
4. 別チャットで**同HTMLから保存したオリジナルPNG**のみ届いても、`read_sera_icon_png.py` で `SERA_ICON_MANIFEST_V1` テキストチャンクを読み、`source.repository_path`、`source.fingerprint`、`equipment.blueprint_id`、`slot`、`rig_set`、撮影設定を照合してゲームのアイコンに組み込む。元の `.bbmodel` をユーザーへ再要求せず、リポジトリ正本を使用する。
5. PNGが画像処理で再圧縮されメタデータが失われた場合は、ファイル名 `SERA_<設計図ID>_<装備名>_icon_512.png` とモデル管理情報で照合する。ただし曖昧な場合は誤装備へ適用せず確認する。**スクリーンショットでなく元のPNGファイルを添付**するのが最適。
6. HTMLのモデル内部に個人情報や秘密を入れない。原本のモデルIDや設計図IDを勝手に変更しない。

## 生成コマンド

```bash
python3 tools/icon_studio/build_sera_icon_studio.py \
  --model models/storage/カメラアイ頭部.bbmodel \
  --slot head --rig-set D --blueprint H02 \
  --output tools/icon_studio/dist/SERA_Icon_Studio_IRIS.html
python3 tools/icon_studio/sera_icon_studio_self_check.py
```

`--model`は常にGitHub正本。モデルが別の場所にある場合は`--source-path`でリポジトリでの正本パスを指定。新モデルは同様に `SERA_Icon_Studio_<装備ID>.html` を生成・この会話へ渡す。HTMLはモデル全体とテクスチャを内蔵するためオフライン動作し、WebGL対応ブラウザで開けば手動ファイル選択が不要。

## PNGを他のチャットで受け取った場合

```bash
python3 tools/icon_studio/read_sera_icon_png.py path/to/SERA_H02_アイリス_icon_512.png
```

アイコンを採用し、LABの設計図が登録された後は、次のコマンドでGodot用の共通埋込画像レジストリに登録します。

```bash
python3 tools/icon_studio/install_sera_equipment_icon.py \
  path/to/SERA_H02_アイリス_icon_512.png --blueprint H02
```

本コマンドはPNGメタデータ内の設計図・GitHub原本SHA-256を照合し、`assets/ui/sera_custom_equipment_icons.gd`の該当IDへPNGをBase64登録します。Godot側の`scripts/sera_item_icons.gd`は登録済み画像を**1設計図につき1つのTexture2Dにデコード・キャッシュ**し、LAB・倉庫・NEXUSで再利用します。未登録装備は旧アトラスを保持します。

表示された `equipment` と `source` を現行 `scripts/sera_prototype_catalog.gd`、`models/manifest.json`、正本SHA-256と照合してから、該当設計図へアイコンを登録する。元画像の縦横比は正方形、背景は透過のまま保持する。LABのカード枠や文字はPNGへ焼き込まない。画像ロードはアトラス共有／キャッシュを維持し、同一装備のカードごとに個別テクスチャを作らない。

**H02登録済み:** 2026-11-21にアイリスの `H02`（頭部D）をLAB製作カタログに追加しました。ユーザーが送信した `SERA_ICON_PRESET_V1` の厳密な角度・位置・倍率・輪郭設定は `assets/ui/sera_icon_presets/H02.json` に保存し、同プリセットから原本3Dメッシュをソフトウェアレンダリングした透過PNGを `assets/ui/sera_custom_equipment_icons.gd` に登録済みです。後にIcon Studioから書き出したPNGファイルそのものを受け取った場合は、メタデータ照合後に差し替えます。

## 再現性と検査

- 埋込モデル原本はSHA-256で識別。PNGへ `SERA_ICON_PNG_V1` の情報を埋め込む。
- `SERA Icon Studio` はCanvas/WebGLの簡易プレビュー。Godotレンダリングと完全一致は保証しない。
- Python静的テストは正本のパッケージ再生成とPNGチャンク読取を確認。ブラウザ表示・Androidタッチ操作・Godot実画面は実機で別途検査する。
