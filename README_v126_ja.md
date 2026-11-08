# SERA v126 — 3Dモデルのシルエット枠と右下戻るUI

## 変更仕様
- 従来v125の手動6点ハル（概略の六角形枠）を廃止。実際のBlockbench構造（TRAINING/SYSTEM端末、DATA ARCHIVE端末、DEPLOYMENTゲート）のボックス8頂点を、描画に使用する変換行列と共通で求める。
- CUSTOMIZEは拠点内のセラ展示用Rigに含まれる表示MeshInstance3Dを、ボーンごとのAABBにまとめて抽出する（非表示剣エフェクト等は除外）。セラの腕・足など実際の輪郭を基にした判定形状を作る。
- 静止時は輪郭の2D多角形を保持。カメラ移動・ウィンドウサイズ変更時だけ、Camera3D.unproject_position で投影し、2D凸包・2px外側オフセット・ポリゴン結合で外縁を更新。ゲーム中の描画はCanvasItemで各輪郭の線だけ。3Dモデル複製・追加MultiMesh・ポスト処理・粒子は不使用。
- 未選択枠は3.6rad/秒の明滅（シアン透明度15〜62%）。選択した枠は透明度98%・線幅3pxで明るく固定。未選択の他対象の枠は非表示。
- ワンタップ後の既存0.18秒カメラ移動、各設備のアングル、TRAININGへ進む操作は変更しない。
- 接近時の戻るUIは画面左上から**右下**に移す。必要に応じてメニューパネルを上へ寄せ、戻るボタンとの重なりを避ける。タップ／Android戻る／Escで全景へ復帰。

## 開発上の配慮
- 3Dモデルの深度や凹みを完全なピクセルマスクにする方式ではなく、表示中の各メッシュの2D凸輪郭を組み合わせた軽量近似。モデルに沿って枠形状が変化するが、細かな曲面や窪みは簡略化され得る。
- 入力判定も同一の輪郭ポリゴンを用いるため、手動ハルと実モデルの位置ずれを削減。
- 変更：scripts/command_nexus.gd、scripts/nexus_selection_outline.gd、project.godot、旧静的検査(v121/v123/v125)、README_v126_ja.md、DEVELOPMENT.md。新規検査 tools/v126_nexus_model_outline_self_check.py。
- v124ゲート漏光、v125画面遷移と0.18秒補間、Godotメインシーン、セラのBash・Guard_REACTION、Blockbenchモデル、BGM/効果音は不変更。

## 検証と制限
- 静的なソース/形状チェックのみ。Godotエディタの実行やAndroid実機での表示・負荷計測は未検証です。
