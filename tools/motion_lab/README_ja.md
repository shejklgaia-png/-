# SERA Motion Lab V1
モーション制作・品質確認の独立基盤。2026-11-25のユーザー許可を根拠に、モーション制作に必要な専用Actions・Blender/Godotの実行・描画・成果物回収・診断・反復改善に限定する。既存ゲームCI・テスト・ゲームファイルは変更しない。実レンダリングは画像生成AIではない。
## 実行
Blender 4.5.3 LTS、Godot 4.7.2、Xvfb、Pillowを使用。専用 workflow の手動実行または同一リポジトリ motion-lab/* PR を使用。ゲーム実行やAndroidを保証しない。
```sh
blender --background --factory-startup --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/example.json /tmp/new-motion-output
```
出力先は未作成ディレクトリ。GLBソースは静的な剛体ノード階層に限定。元モデル・既存アニメーションは変更しない。スキン付きボーン、Blockbench直接変換、IK・衝突解法は次段階。
## 設計
SERA_MOTION_LAB_V1、単位m、Blender Z上、正面-Y、ローカル座標。GLBはY上変換。fpsは30/60。フレーム1開始、各トラック独立、位置・XYZオイラー角（度）、各トラックの初末キー必須。中間キーのBezier自動クランプ。角度は連続な値で設計し、360度折返しは作者が管理。source_glbは設計JSON相対パス。対象名はインポート後の正確な一意名。未対応リグは拒否する。
markersは部位ローカル点、contactsはフレーム範囲と目標点/別マーカー、許容距離。毎フレーム評価。全身貫通・重心・床滑り・姿勢評価を保証しない。
review.target と scale で固定正投影。Godotもreview.target/scaleを読み、Blender Z上からGodot Y上へ変換して斜め固定視点で描画する。
## 出力
motion.blend、motion.glb、motion_report.json、Blender 3視点の複数フレーム、Godot 9枚、godot_review.json、視点別コンタクトシート、ハッシュ一覧。成果物未取得のときは目視確認済みとしない。成功と品質合格を区別する。専用runのhead SHA、artifact ID、結果を台帳に記録。初回は架空の剛体腕による環境制作、ゲームのモーション品質の実証ではない。
## 参考
https://docs.blender.org/manual/en/4.5/advanced/command_line/arguments.html
https://docs.blender.org/manual/en/4.5/addons/import_export/scene_gltf2.html
https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html

## V2: 再現性と品質診断
V1 run 45512877274 は工程成功だが、Godotが肘クリップのみを再生していた。Blender 4.5のSCENE分割既定値を無効化し、開始時刻0、全動的チャンネルを含む単一GLBクリップを必須にする。GLBのJSONを調べ、Godot側も単一クリップ以外を拒否。マーカーを実際のノードとして書き出し、Blender Z上からGodot Y上へ変換した全フレームの世界座標を比較する。既定許容2mm、長さ差0.2ms。マーカー1個以上必須。これは指定点の再現性であり全関節完全一致の保証ではない。各キーのinterpolationはBEZIER/LINEAR/CONSTANT。eventsの名前→フレーム番号、および接触の開始終了フレームを共通撮影時刻に追加。速度・加速度・ジャーク・ループ継ぎ目の有限差分を記録する（自動的な芸術品質合格ではない）。画像と数値を併用する。失敗時はpartial artifactを確認する。
参考: https://docs.blender.org/api/4.5/bpy.ops.export_scene.html
