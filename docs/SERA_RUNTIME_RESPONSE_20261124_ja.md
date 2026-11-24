# プレイ中レスポンス最適化・第1実装 2026-11-24
- UI: 装備製作7部位と精製素材12カードを起動中に構築し、非表示保管。同じネイティブButton、シグナル、画像を再利用、所持数のみ更新。倉庫全UI、タブ、その他画面は未常駐化。既存の倉庫可視カードプール・素材アトラスを維持。
- 遠景: 8種類までの可視地区MultiMeshをLRU常駐し切替時はリソース差替。変更なしのBASE遠景配置更新を省略。メッシュ統合は既存バッチのみ。新規LODや全モデルの統合は未実施。
- 背景: 施設メニュー中のBASEクレート/物流更新と非表示物流診断文字列を停止。背景3D描画自体は維持（静止画合成未実装）。
- 入力: 戦闘のみ既存BASEと同じ非蓄積入力、終了時復元。操作閾値・60Hz物理変更なし。
- セーブ: JSONのインデントを省略。既存の同期・一時ファイル＋flush＋renameの耐久性を保持。非同期保存は未実施。
- 性能計測: 300サンプル上限の壁時計フレーム間隔p95/p99/max、5秒ごと。実際のGPU時間/表示時刻ではない。
- 動的解像度: NEXUSグラフィック設定の任意ON（既定OFF）、主CompletedFrameの3Dのみ1.0/0.9/0.8、5秒窓のヒステリシス。別ID描画とUIは維持。整合・実機効果は未確認。
- 今回は段階1。静的/動的ID分離、新規FXプール、全モデル統合、追加アトラス、アニメーション事前計算、全面イベント化、ゲーム中の汎用処理予算、LOD、全UI常駐、背景描画停止は未完了。既存ヒット火花プールを重複実装しない。
- 参考: https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html ; https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html ; https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html ; https://developer.android.com/games/sdk/frame-pacing/ ; https://forum.godotengine.org/t/threaded-multimesh-generation-stutters/119934
- 実機/CI未実施。変更はコードレビューのみ。

## 第2実装
- 通常敵弾6個を戦闘ロード時に生成、再利用。全枠使用時は追加生成して攻撃を欠落させない。発射時に色・方向・速度・寿命・距離・二重ヒット防止を初期化。終了時は遅延でArea監視を停止し、再利用可能にする。KOとデバッグ切替は弾を返却し、従来の範囲攻撃は解放。土埃・シールド・ヒット火花の既存プール維持。ボス専用攻撃の新規プールは未実施。
- 常駐スクロール復帰時に古いドラッグ状態を初期化。
- 実機/CI未実施。

## 第3実装
- 倉庫2モードのVirtualGridを常駐、起動中に各16カードを準備。ハンガー切替時は既存プールを再利用。
- ビットタラン腹部砲弾3個を事前生成し、消滅/ダウンで返却。命中計算は元のまま。
- LABOのプリンター稼働モーションは4製品×3アーム×513サンプルのローカルTransformを起動中に分散計算、再生は補間。待機モーションは従来のIK。実機での接触精度は未確認。
- ID同期は明示固定床グループと非選択作業場を分離。固定床は登録・可視/親姿勢変更時に同期、選択作業場と戦闘は毎フレーム維持。
- 背景静止の任意設定（既定OFF）。BASEの共有World3Dを別SubViewportで1回描画、GPU内のTextureを保持して元3D/ID描画停止。CPU readbackなし。開閉時は復帰、Androidの表示検証が必要。
- 倉庫読み取りで全装備を繰り返しsanitizeする処理を省略。ロード/変更時のsanitizeと同期原子保存は維持。
- 全面メッシュ統合、新規アトラス、遠景LOD、汎用実行時ジョブ予算、非同期セーブは未実装。既存処理の部分改善であり、CI/実機未実施。
- 参考: https://docs.godotengine.org/en/4.7/classes/class_node3d.html ; https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html ; https://github.com/godotengine/godot/issues/75877 ; https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html
