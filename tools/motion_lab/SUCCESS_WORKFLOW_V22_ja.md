# Motion Lab 成功事例 — V22 全身演技先行制作フロー
記録日: 2026-11-25 / 適用範囲: SERA のモーション制作・AI生成基盤。V22は制作方式の成功例（ユーザーの肯定評価）。ゲーム採用・物理的正確性・実機性能の承認とは区別する。

## 1. 成功した考え方
- 目的と画面上の演技を最初に定義する。足先位置の到達を目的化しない。
- FK主体で全身の主要姿勢を設計。予備動作では支持側に荷重を移す印象、胴体先行、脚の付け根から末端へ順次動かす。攻撃脚の輪郭は実プレイ視点で確認。
- 速度は一律にしない。予備、展開、頂点、溜め、駆動、着地、圧縮、反動、回復を分離し、頭や補助部位の遅れで重量感を演出する。
- 支持脚の基本姿勢もキーで作る。実機では後段IKを軽微な残差補正に使う。攻撃・遊脚は原則演技優先。接地の固定が必要なフェーズだけ明示する。
- 数値は破綻診断のために用いる。数値合格のために演技を縮小しない。大きな干渉・可動域逸脱は原本側を修正する。動力学は実測しない限り演出上の推定である。
- 見栄えは実メッシュのHTMLビューワーで判定。比較・再生・修正・再検査が必須。ユーザー評価とセルフ評価を分けて記録する。

## 2. 標準制作手順（必須）
1. 正本モデル・UUID・親子関係・局所軸・単位・可動部を確認。既存モーションは比較基準とし、無断で置換しない。
2. 公式・専門家・企業事例・利用者の実例を調べ、目的・実装環境に合う方式を比較する。
3. 目的/攻撃方向/支持脚/遊脚/ゲーム視点/フェーズ/イベント時刻を決める。
4. 全身シルエットを先に設計。胴体・関節の方向・頭の遅れを明示。攻撃脚の方向キーと支持脚の局所角キーを分ける。まず主要姿勢、次に補助キー。
5. PCHIP等の形状保持補間で時系列を生成。連続60fpsを評価する。PCHIPは成分単位C1であり、3D姿勢や動力学の保証ではない。
6. 生FKを書き出し、支持脚の区間/強度/アンカーのsidecarを出力。後段IKのON/OFFを別々に生成し、原本を保存する。姿勢、地面、足滑り、干渉、到達限界、補正量、動作量を記録。
7. 実メッシュのHTMLビューワーを実際に開き、通常/半速で再生。正面・側面・斜めから主要姿勢と遷移を見る。比較版も同条件で再生し、IK切替で演技が維持されているか確認する。数値または画面操作のみでは未完了。
8. 問題を優先順位付けし、キー・尺・補正区間を修正。再生成・再生・再評価を繰り返す。実描画で合格しない候補は採用しない。
9. JSON/コード/数値結果/HTML/再現方法/既知の限界を保存。独立プレビューとBlender/Godot/Android実行を区別。既存ゲームへの採用は別判断。

## 3. V22で実際に行ったこと
対象: Bittaran 前左脚踏みつけ。60fps、2.20秒、133サンプル、21キー。V21 A案の11キーから、胴体支持側への移動と傾き、支持3脚の回転、頭部の遅延反動を設計。キー時点で支持脚接地を整え、PCHIPで生成。後段IKは支持3脚のみ。初回HTMLで過大な振り上げと約9cmの貫通を確認し、振りかぶり/着地/圧縮/復帰キーを2回調整した。最終的に3方向×6主要フレーム×2案＝36枚の描画と等倍/半速再生・IK切替を確認。

| 評価 | V21 A | V22 |
|---|---:|---:|
| 足先上昇 | 3.30385m | 4.10760m |
| 水平最大変位 | 1.58615m | 2.00127m |
| 支持脚最大誤差（IK前） | 0.23222m | 0.04979m |
| 最大床突出（IK後） | 0.03514m | 0.003109m |
| 尺 | 2.05s | 2.20s |

視覚評価: 攻撃側斜めからの輪郭、全身の傾きと支持脚屈伸が改善。ユーザー肯定。残存: 振りかぶりの過大さ、着地後の攻撃脚固定、打撃の重さ。V18実GLB静的メッシュからの独立SciPyプレビューであり、Blender/Godot直接実行やAndroid、物理可動域・干渉・実荷重は未確認。

### 主要時刻（V22）
0.00 基本、0.17 荷重移動、0.38 振り上げ、0.63 展開、0.83 頂点、0.98 溜め終了、1.08 駆動、1.16 振り下ろし、1.23 着地、1.33 圧縮、1.51 反動、1.68 戻し、2.20 復帰。補助キーを加えて21点。着地→圧縮で胴体0.13m沈み、頭の反動最大15度。数値はBittaran暫定例で他機体に固定適用しない。

### 実装の参照先
- PR #1287 / main merge d8cba916471e1a30b14a74187a21f7a9beeb1ce8
- fk_stomp_poses_v22.json: 再現可能な姿勢資産
- fk_performance.py: FK/PCHIPコンパイラ
- runtime_contact.py: 接地sidecar・独立IKプレビュー
- bittaran_fk_v22.json: 実行設計
- scripts/bittaran_foot_ik.gd: 既存の実行時解析IK、候補接地API
- 再現: blender -b --python-exit-code 1 --python tools/motion_lab/build.py -- tools/motion_lab/bittaran_fk_v22.json /tmp/mlab_v22 --variant chain （別ディレクトリで --preview-ik）
- 成果物: MotionLab_V22_WholeBody_Stomp.html（独立プレビュー、会話共有済み）

## 4. 参考資料と適用
- Jonathan Cooper, The 12 principles of animation in video games, Game Developer: https://www.gamedeveloper.com/production/the-12-principles-of-animation-in-video-games — 予備動作、緩急、誇張、シルエット、フォロースルー。ゲームの反応性と演技の両立。
- Animation Mentor, What Makes or Breaks a Good Body Mechanics Shot?: https://www.animationmentor.com/blog/animation-tips-tricks-what-makes-or-breaks-a-good-body-mechanics-shot/ — 意図を全身の動きとして表す。胴体先行・支持側への移動を設計する際の参考。
- SciPy PchipInterpolator: https://docs.scipy.org/doc/scipy/reference/generated/scipy.interpolate.PchipInterpolator.html — 単調性保持・補間オーバーシュート抑制。V21/V22の時間曲線の技術資料。
- Epic Games Game Animation Sample: https://dev.epicgames.com/documentation/unreal-engine/game-animation-sample-project-in-unreal-engine — 原アニメーションと後段の脚IKの役割分担。Unrealの実例でありGodot実装そのものではない。
- Kovar, Schreiner, Gleicher, Footskate Cleanup for Motion Capture Editing (2002): https://research.cs.wisc.edu/graphics/Gallery/kovar.vol/Cleanup/ — 接地区間の足滑り除去という思想。V23追加検討に参照。研究のアルゴリズムをそのまま移植したわけではない。

## 5. V23 継続改善
V22のFKを無変更で利用し、既存runtime_contactで攻撃脚の着地75Fから反動92Fまでを追加接地区間とする。4Fのsmoothstep入退場、0.30m補正上限、着地時の表示足裏をワールド固定。133F・60fps。支持脚は従来通り全期間。攻撃脚の完全固定79〜88Fで最大残差0.190474m→数値誤差。移行を含む区間最大残差0.131098m（解除端点）、床突出最大0.002634m、上限超過/到達不能0。2F案も試したが解除は4Fを暫定選択。振りかぶり4.10760mと胴体原本は維持。独立HTML MotionLab_V23_Impact_Contact.htmlでV22との3方向36枚・1倍/0.5倍・IK切替を確認。圧縮時の接地姿勢が改善する一方、解除時の足移動は残る。ゲーム採用は未承認。次はなぎ払いへの同方式展開と、解除から戻しの軌道改善。Blender/Godot本体実行・Android未確認。
