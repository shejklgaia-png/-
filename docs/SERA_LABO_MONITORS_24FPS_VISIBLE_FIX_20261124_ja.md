# LABO・素材精製・倉庫モニター24fps不再生対策（2026-11-24）

## 現象と調査

利用者から、LABO・精製機・倉庫のモニターアニメーションが再生されないとの報告。
該当モニターは `scripts/labo_hero_stage.gd` の `_live_display()` で
`assets/monitors/labo_display.gdshader` の `ShaderMaterial` を割り当てていた。

関連する画面構成は `scripts/labo_rebuilt_scenes.gd` の
`_screen()` に集約され、6種類の表示が同じ3D表示面生成関数を使用する。
3D画面は `scripts/base_facility_system.gd` により
`SubViewport.UPDATE_WHEN_VISIBLE` に設定されていた。

実機ログは未取得のため、専用シェーダーのコンパイル失敗、
カメラ方向、SubViewportの描画停止のどれが単独原因かは断定しない。

## 修正

`scripts/sera_labo_monitor_24fps.gd` を新設。
表示面自身を `MeshInstance3D` とし、画面サイズに応じた
幅192px、高さ96〜144pxのRGBA8画像をGodot `Image` で毎コマ構築。
一度だけ作成する `ImageTexture` を `update()` で更新する。
`StandardMaterial3D` は非ライティング・両面描画で、
GL Compatibilityでもカスタムspatialシェーダーを必要としない。

更新周期は `floor(elapsed_time * 24.0)` でフレームを確定する。
同じフレーム中には再描画・GPUアップロードを行わない。
フレーム番号は上限のある画像配列の添字ではなく、
時間に応じた動画生成の入力なので、コマ数に上限を設定しない。
端末側の描画FPS不足時には途中コマが飛ぶ。

| 表示モード | 実装した24fps描画内容 |
|---|---|
| PRINT | 積層断面の増加、移動するノズル、造形進捗バー |
| FLOW | 3本の素材流路波形と流動パケット |
| PURITY | 5本の純度グラフとスキャニングライン |
| RECYCLE | 六方向の回転翼と資源回収の進捗 |
| INVENTORY | アイテム一覧のスクロール・選択行・在庫バー |
| SCANNER | 移動する照射線・追尾照準・ランダム風ノイズドット |

全演出にブルーグレーの背景格子、フレーム、英語ドット文字の見出し、
フレーム番号を描画して「表示される映像」と「動き」を共に保証する。

`scripts/labo_hero_stage.gd` の `_live_display()` から
当該ドライバーを直接生成し、元の3D `QuadMesh` の形状・位置を維持。
もともとの筐体、UI、クレート、3D機械には変更なし。

3D背景のSubViewportは画面表示中のみ `UPDATE_ALWAYS` を設定し、
画面非表示時には `UPDATE_DISABLED` を維持する。

## 負荷に関する注意

更新時にCPUで小さなテクスチャを描画するため、
以前のGPU手続きシェーダー方式よりCPUの仕事が発生する。
ただし表示されている画面だけ処理し、画像は約192×96〜144px、
更新は最大毎秒24回、動的な3Dメッシュや追加のSubViewportは増やさない。
負荷や発熱は実機計測での確認が必要。

## 確認範囲

既存のシーン構造、表示面モードと生成ルート、SubViewport設定、
変更コードとGitHub差分を確認。SERAの開発ルールに従い、
CI項目の確認・変更・適用およびテスト実施はしていない。
Android実機における動作・表示品質・fpsは未確認。
