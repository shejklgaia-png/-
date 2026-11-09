# セラ v113 — RUN頭部の周期的な回転揺れを65%抑制（2026-11-07）

- 基準：GitHub `main` コミット `1d41f42f2a002031ce52e7593e0b2ee416e47e79`。前進RUNの上半身から頭までの合成回転は4位相平均に対して最大約29.8°変動、後退RUNでは約3.4°（元キーフレームに基づくQuaternion計算）。
- `scripts/sera_rig.gd`：前方・後方RUNを元の位相で混合した後、腹・胸・首・頭の合成向きについて0/0.25/0.5/0.75秒の4位相平均を基準とし、周期回転成分の35%のみを残す。参照姿勢にも既存のターゲット追従関節ヨーを適用し、親ボーン回転の逆変換で頭のローカル回転へ反映。位置・スケールは未変更。
- 腰の移動方向追従、最大15°バンク、前後RUN判定・利き手切替、0.18秒クロスフェード、実際の移動・カメラ・攻撃・Guard・Boost・Step・Jump、モデルJSON/Blockbenchキーフレーム・音源を維持。RUNから他動作への遷移も既存の姿勢ブレンドを使用。
- `project.godot` のプロジェクト名を同期試験用 `4g_test` から `SERA v113 - RUN Head Stabilization` へ戻し、`README_v113_ja.md` と `tools/v113_run_head_stabilization_self_check.py` を追加。既存v112のプロジェクト名検査のみ、後継版に対応する形式に変更。
- GitHub連携経由でソースの整合性・回転計算モデル・変更範囲を検査。**Godot本体の実行、Pythonチェックコマンドの実行、Android実機の見た目確認は未実施**。特に前RUN/後ずさり、急旋回、RUN解除/再開と目線の自然さを実機で確認すること。

---

# v105（2026-11-06）訓練ステージBGMの読み込み修正

- 基準：v104。ユーザーから「BGMが流れない」と報告。未実機調査のため原因は確定していない。
- `scripts/stage_bgm.gd`：`ResourceLoader.exists()` とインポート済みリソース `load()` に依存せず、`AudioStreamOggVorbis.load_from_file()` で `BGM/*.ogg` を直接読み込む。シーン準備後に再生し、失敗時の診断情報と開始ログを追加。
- 音源、イントロ→ループ仕様、音量-9dB、シーン構造、戦闘・カメラ・入力・モデルは不変。`project.godot` の表示名のみ v105 に更新。
- 音源原本のSHA-256およびGit blobの一致を確認。単体静的チェック、Python構文チェック合格。`tools/v105_stage_bgm_self_check.py` を追加。
- Godotエディタ起動・Android実機音声出力は未検証。ユーザー端末で動作確認が必要。

---

# v104（2026-11-06）トレーニングステージBGM

- 基準：GitHub `main` v103。訓練ステージにユーザー提供OGGのイントロ（7.74秒）→ループ本編（61.94秒）を再生する独立ノードを追加。
- `scenes/main.tscn`、`scripts/stage_bgm.gd`、`project.godot` を変更。新規 `README_v104_ja.md`、`tools/v104_stage_bgm_self_check.py`。
- 元の `scripts/main.gd`、戦闘音／被弾音、AI、操作、カメラ、Blockbenchモデルを保持。
- ユーザーがOGG音源2件を `BGM/` にGitHub登録。原本添付とGit blob SHAが双方一致。スクリプト・検査ファイルは `res://BGM/` を参照する。
- ローカルのBGM込み差分で `v104_stage_bgm_self_check.py` を実行し、OGG先頭識別子・SHA256・シーン接続・ループ設定チェック合格。Python構文検査合格。GitHub上で変更ファイル一覧、パス、音源Git blob SHA確認。Godot本体・Android実機音声再生の検証は未実施。

---

# v103（2026-11-06）ターゲット本体の赤色化

- 基準：GitHub `main` のv102。変更は訓練ターゲットの色のみ。
- `scripts/main.gd`：`FloatingBox` の基本色を `#E53935`、発光色を `#A92724` に変更。命中フラッシュ復帰時も同じ赤系へ戻す。
- 命中時の暗赤色と既存の陰影・ヒット演出、ターゲットの形状・当たり判定・HP、カメラ・入力・ガード・敵AI・音声・モデルは変更しない。
- `project.godot`：v103の表示名だけを変更。`README_v103_ja.md` と `tools/v103_target_red_self_check.py` を追加。
- GitHub上の差分と色コードの静的確認を実施。Godot本体・Xperia 1 Vでの実機描画テストは未実施。`main` への統合は実機確認後。

---

# v102（2026-11-06）Guardポーズ修正版への差し替え

- 基準：v101 `sera_portrait_godot_melee_v101_hold_guard.zip`。
- 提供 `SERA_Guardfix.bbmodel` の `Guard` クリップだけ抽出し、`assets/sera_source.json` の旧Guardを置換。ほかのアニメーション・モデル・全操作／被弾ロジックは不変。
- 22ボーンUUID一致、13ボーンのキーフレーム変更、0秒固定ポーズ形式維持。`tools/rebuild_model_data.py` で `assets/sera_data.gd` を更新。
- 追加：ユーザー修正版原本、統合モデル、README_v102_ja.md、tools/v102_guardfix_self_check.py。元のv101統合モデルや原本も履歴として保持。
- `project.godot`：表示名をv102へ更新。Godot本体・Android実機の実行確認なし。

---

# v101（2026-11-06）静止ホールドガード／Guardキー追加

- 基準：ユーザー提供 `sera_portrait_godot_melee_v100_jump_debug_only.zip`（v100）。
- ユーザー提供 `SERA_Guard.bbmodel` から `Guard` のゼロ秒ポーズを既存モデルに追加。22ボーンUUID完全一致。元モデル・全既存アニメ・テクスチャを保持。
- `main.gd`：静止ホールド0.32秒（最大軌跡18px）でガード開始、指を離すと終了。ガード中は移動・ブースト・回避・格闘・ジャンプを抑制。ガード中の敵弾・範囲攻撃は被弾リアクション／ノックバック／被弾フラッシュを行わず既存命中音のみ再生。PCのGキーでもガードテスト可。
- `sera_rig.gd`：ガード姿勢の開始・終了・補間、移動／攻撃系クリップへの遷移制限。
- 既存のシールド数値・消費量・ガード崩れ・バッシュ機能はv100に未実装。今回新規設計しない。
- 変更：`scripts/main.gd`、`scripts/sera_rig.gd`、`assets/sera_source.json`、`assets/sera_data.gd`、`project.godot`、`DEVELOPMENT.md`。
- 追加：`blockbench/SERA_Guard_user_input.bbmodel`、`blockbench/SERA_v101_guard_integrated.bbmodel`、`README_v101_ja.md`、`tools/v101_guard_self_check.py`。
- 検証：モデルの構造・既存機能との差分・ZIP-CRC・静的動作条件のセルフチェック。Godot実行／Android実機テストは実施した場合のみ別途記録。

---

# セラ v100 — ジャンプを通常操作から除外（2026-11-06）

**基準版**：v99 `sera_portrait_godot_melee_v99_landing_hold_06s.zip`。

## 変更点

- 上フリックのジャンプ発動を**既定で無効化**。短い上フリック／走行・ブースト中の末尾上フリックとも、ジャンプにはなりません。
- 左右フリックのステップ、下フリックの4mバックステップ、通常移動・ブースト、ガード相当の既存処理、格闘3段、敵4攻撃、被弾音、カメラ等を維持。
- ジャンプと空中制御・空中ステップ・空中格闘・0.6秒着地硬直の**コード、Blockbench原本、統合モデル・キーフレームは削除せず保管**。
- スマートフォンで必要時に動作確認できるよう、既存のデバッグパネルに **JUMP TEST** ボタンを追加しました。タップすると地上からジャンプします（離地時の水平速度80％継承などv99仕様を使用）。パネル内操作は通常のタップ攻撃・フリックと区別します。
- PC版デバッグでは引き続き **Jキー** でジャンプテストできます。
- 上フリックを復活させる場合、`scripts/main.gd` の `JUMP_TOUCH_INPUT_ENABLED` を `true` にすることでv99の入力経路を復旧できます（今後の正式採用は未決定）。

## 変更範囲

- `scripts/main.gd`：上フリック経路を既定OFFにし、明示的なデバッグジャンプ入口を追加。
- `scripts/enemy_debug_ui.gd`：既存の敵攻撃デバッグUIに小型のJUMP TESTボタンを追加。敵攻撃用ボタンは維持。
- `project.godot`：v100表記。
- `DEVELOPMENT.md`、`README_v100_ja.md`、`tools/v100_jump_debug_self_check.py`：開発履歴・検査。

**検証**：静的コード・モデル／音源のバイト一致、既存機能差分、ZIP CRC検査を実施。Godot本体／Android実機での操作・描画確認は未実施。

---

## v98（2026-11-06） ジャンプ80%慣性・上フリック50px・空中ステップ/格闘・30%空中姿勢制御

# セラ v98 — ジャンプ中の姿勢制御・空中ステップ・空中格闘（2026-11-06）

**基準**：`sera_portrait_godot_melee_v97_jump_inertia.zip`（v97）。

## 変更仕様

- ジャンプ初速の**水平方向への継承率65％→80％**。固定高度1.5m、通常飛行0.80秒は据え置き。
- 上フリックの必要距離**78px→50px**（720px仮想画面、速度500px/s以上、左右の混入制限42％は維持）。左右・下フリックの必要距離78pxは変更しません。
- 空中でも**左右ステップと4mバックステップ**が使用可能。既存のStep_L/Step_R/Backstepモーション・移動量・速度をそのまま使用します。
- 空中でも**既存の3連打格闘**が使用可能。従来の接近・斬撃・キャンセル・命中判定・音・ダメージ12/12/26はそのままです。
- 空中アクション中はそのアクションのモーションを優先し、高さを一時保持します。アクションが終了／中断すると、**ジャンプモーションの落下キーフレーム（0.20833～0.375秒）へ移り、現在の高度から重力で着地**します。上昇動作の再再生やY座標の瞬間移動を防止します。
- ジャンプ中の新しいドラッグでは、**通常RUN速度の30％（3.25×0.30＝0.975m/s）まで**の水平操作ベクトルを、離地時の慣性速度へ加算します。空中ではブースト倍率は適用せず、方向操作だけでポーズ／モーションは切り替えません。
- 空中ステップ・格闘中は慣性移動と空中姿勢制御を一時停止してアクションの固有移動を使用します。アクション後の落下では、過去の慣性を復活させず、30％の姿勢制御のみを受付けます。
- 2段ジャンプは不可。被弾中も落下継続し、被弾が終了した場合は落下ポーズに復帰します。試作環境はY=0地面、段差・足場にはまだ対応しません。

## 変更ファイル

- `scripts/main.gd`：ジャンプ判定距離、空中移動、空中のステップ／格闘解禁、動作終了後の落下遷移、被弾時の復帰を変更。
- `scripts/sera_rig.gd`：空中アクションの後、Jumpの下降区間へ切替。**モデル・アニメーションのキーフレーム・メッシュは変更なし。**
- `project.godot`：v98表記。
- `README_v98_ja.md`／`DEVELOPMENT.md`／`tools/v98_air_action_self_check.py`：仕様・検証を追加。

**維持**：敵4攻撃・デバッグUI、格闘3段のダメージ/音、敵弾被弾音、ブースト閾値、ステップ距離、カメラ追従・残像、既存モデル全データ。

**検証**：静的検査、モデル／音源同一性、差分／ZIP-CRC検査を実施。Godotのプロジェクト起動／Android実機確認は未実施。

---

# SERA v97 — 上フリック固定ジャンプ（2026-11-06）

- 基準ZIP：`sera_portrait_godot_melee_v96_player_bullet_hit_sound.zip`。
- 提供 `SERA_jumpmotion.bbmodel` の無名アニメーションを `Jump` として統合。0.375秒の全トラックを0.80秒の滞空に同期して再生。
- 上フリック（短時間、または長いドラッグの終端0.20秒）でジャンプ開始。通常ステップ判定やブースト125/110%閾値を変更しない。
- 固定高度1.50m、滞空0.80秒、離地時の水平速度65％継承、空中操作による方向変更なし。空中攻撃と重複ジャンプ抑制。
- 被弾しても飛行時間経過・落下を継続。ジャンプ用地面マークは床Y=0に維持。
- 修正：`scripts/main.gd`, `scripts/sera_rig.gd`, `assets/sera_source.json`, `assets/sera_data.gd`, `project.godot`, `DEVELOPMENT.md`。
- 追加：統合bbmodel、ユーザー原本bbmodel、README_v97_ja.md、検証スクリプト。その他v96ファイルのバイト列は維持。
- Pythonによる静的・算術・アセット一致・ZIP整合性チェック実施。Godot／Android実機未検証。

---

# SERA v96 — 自機の弾被弾音の変更（2026-11-06）

- 基準版：v95 `sera_portrait_godot_melee_v95_unified_melee_hit_sfx.zip`。
- 自機のAIM／LEAD弾被弾時の音のみユーザー提供「ロボットを殴る3.mp3」に差し替え。
- `assets/sera_player_bullet_hit_v96.wav` は48kHz／16bit／ステレオ。原本MP3も同梱。
- `scripts/main.gd` の弾被弾AudioStream参照を1行変更、音量-5dB・最大多重再生3を維持。
- SHOCK／ARC被弾音、3段格闘命中音、戦闘・移動・カメラ・UI・アニメーションに変更なし。
- 修正：`scripts/main.gd`, `project.godot`, `DEVELOPMENT.md`。追加：音源2点、`README_v96_ja.md`, `tools/v96_player_bullet_sfx_self_check.py`。
- 静的・音声・ZIP整合性検査を実施。Godot／Android実機未検証。

---

# SERA v95 — 格闘ヒット音統一（2026-11-06）

- 基準版：v94 `sera_portrait_godot_melee_v94_hit_sounds_by_attack.zip`。
- 1・2・3段目の命中音をユーザー提供「ロボットを強く殴る2.mp3」に統一。Godot向け48kHz/16bit/stereoの `assets/sera_melee_hit_all.wav` に変換、元MP3も保管。
- `_register_strike_hit` の命中判定・`strike_did_hit`・段別ダメージ12/12/26・段別ノード選択・最大同時再生数・音量-5dBは変更なし。
- 弾被弾音・敵の範囲攻撃被弾音、ブースト、ステップ、カメラ、敵AI、モーション等の変更なし。
- 変更：`scripts/main.gd`, `project.godot`, `DEVELOPMENT.md`。追加：音声2点、`README_v95_ja.md`, `tools/v95_melee_sfx_self_check.py`。
- 静的検査・ZIP整合性検査実施。Godot/Android実行は未実施。

---

# SERA v86 — 格闘3段コンボの段別ダメージ

- ベース：v85 `sera_portrait_godot_melee_v85_volume_particles.zip`。
- 1段目 `melee1`：12、2段目 `Melee2`：12、3段目 `Melee3`：26。全段命中で合計50。
- ダメージ処理とポップアップ表示に同じ `strike_damage` を使用。HPは0で下限固定、1段1命中・既存のリスポーン処理を維持。
- キャンセルポイント、先行入力、自動接近、命中判定、ヒットストップ、3D剣閃・粒子、カメラ、移動、敵AIなどの既存処理は変更しない。
- 機能変更対象：`scripts/main.gd`。表示版名：`project.godot`。検証用スクリプト：`tools/v86_combo_damage_self_check.py`。
- 旧 `tools/hit_self_check.py` はv14時代の固定20ダメージおよび旧カメラの検査を含むため、履歴資産としてそのまま維持。今回の仕様は新規v86検証で確認。
- GodotエディターおよびAndroid実機での実行・描画確認は未実施。

---

# SERA v85 — 剣閃立体化 + 周囲粒子（制作メソッド完全版）

## ベース／原則
- `sera_portrait_godot_melee_v84_authored_sword_fx.zip` から更新。
- ユーザー配置の `Swordeffect` 板の親ボーン、平行移動、角度、拡縮を**そのまま維持**。0.55m補正、カメラ正対、追尾位置補正は追加しない。
- v84で更新した `melee1` / `Melee2` / `Melee3` の板アニメーション、24fps基準のキャンセルポイントとコンボ入力は変更しない。

## 表示工程
1. 元のBlockbench板は非表示、トランスフォーム参照として使用。
2. 透過剣閃テクスチャ8フレームを、描画領域のみ残したカットアウトメッシュへ貼付。透明な四角形を描かない。
3. v35から残っていた各フレーム専用の立体形状データ（`slash_C_volume_geometry.json`）で、表裏に膨らむ薄い凸レンズ状メッシュを構成。主剣閃の白い輪郭と薄い立体層を重ねる。
4. 同じデータの発生候補点から、白（Cで赤へ切替）の微粒子をランダム生成。速度、方向、サイズ、寿命を独立に変え、徐々にフェード。最大32個。命中時の `hit_burst.gd` 火花とは別。
5. 各段の開始時にフレームと粒子をリセット。第3段は既存の0.210秒の描画遅延を維持。ヒットストップ中は粒子時間を進めない。
6. 自キャラクター前景描画と敵への重なり減光機能を以前のv35方式から復元。立体層と粒子に影は付けない。

## ファイル変更
- 変更: `scripts/sword_trail.gd`（v35の立体カットアウト＋粒子を復活してv84座標に統合）、`project.godot`（版名）、`DEVELOPMENT.md`（履歴）
- 追加: `README_v85_ja.md`, `tools/v85_sword_fx_self_check.py`, `blockbench/SERA_melee_combo_3_v85.bbmodel`（v84内容をそのまま複製、ボーン／アニメは不変）
- 既存の `assets/v35_cutout_frames`、`v35_cutout_tiles.json`、`slash_C_volume_geometry.json` を再使用。新規3D素材は生成せず、既にある各フレームのジオメトリを再適用するため表示内容はv35の表現に近い。
- v84の`assets/sword_fx_*_4x2_mobile.png`も削除せず維持するが、v85立体描画では透明領域の板状表示を防ぐためカットアウト用の個別PNGフレームを描画する。

## 確認範囲
- 静的検査は必要事項・参照先・元ファイル保持を対象とする。Godot 4.7.2エディター／Android実機の起動および描画品質は未確認。

---

# SERA v83 — 格闘3段コンボ（24fps基準キャンセル点）

- 基準：添付v82 `sera_portrait_godot_melee_v82_target_angle_camera_final.zip`。Godot 4.7.2安定版の公開状況とGDScript標準を確認。
- ユーザーの `セラ･格闘連打.bbmodel` から `melee1`、`Melee2`、`Melee3` の3アニメーションのみ取り込み。ほかのv82アニメーション（通常移動・ステップ左右・0.22s被弾等）とモデル形状は保持。
- 各段の「振り抜き終了+2フレーム（24fps）」をゲートに設定：1段目0.291667s、2段目0.291667s、3段目0.625s。3段目には次段なし。
- タップは1回分バッファし、ゲート到達で次段に遷移。未入力時はその段の末尾まで再生。剣命中・ヒットストップ・トレイルを段ごとにリセット。3段目の剣軌跡だけ原本の長いモーションに合わせて遅延。
- 既存の敵AI、移動、ブースト、ステップ、接近、カメラ、当たり判定方式（各段のアクティブ時間以外）は変更なし。
- 変更：`project.godot`、`scripts/main.gd`、`scripts/sera_rig.gd`、`scripts/sword_trail.gd`、`assets/sera_source.json`、`assets/sera_data.gd`、`DEVELOPMENT.md`。追加：`blockbench/SERA_melee_combo_3_v83.bbmodel`、`README_v83_ja.md`、`tools/v83_combo_self_check.py`。
- 検証：静的55件PASS、v82カメラテストは版名1件除き29/30 PASS、変更対象外差分検査。Godot・Android実機での実行・表示・入力検証は未実施。

---

# SERA v74 — ステップ最低速度8m/s

- 基準：v73 `sera_portrait_godot_melee_v73_outside_circle_boost.zip`。
- ステップ最低速度のみ変更：`STEP_CLOSE_SPEED` 6.0→8.0m/s。ステップ最高速度10.0m/sを維持。
- 敵キューブ表面との水平距離が2m以下で8m/s、5m以上で10m/s、その間は従来どおりsmoothstep補間（中心距離ではなく箱表面基準）。ステップ開始時の速度固定も維持。
- ステップ軌道・移動距離（2.0〜4.0m）・最大所要時間（0.4s）・HUD・走行/ブースト・既存戦闘/カメラ/敵AI等は変更なし。
- 変更：`scripts/main.gd`, `project.godot`, `DEVELOPMENT.md`。追加：`README_v74_ja.md`, `tools/v74_step_min_speed_self_check.py`。
- 検査：v73との差分、速度境界/滑らかな補間、移動距離/時間を静的・数値確認。Godot/Android実機は未検証。

---

# SERA v73 — 単一半透明円 / 円外ブースト / 外側二重矢印

- 基準：v72 `sera_portrait_godot_melee_v72_run_boost_ring.zip`。
- v72の外周直径はそのまま。円内全域でRUN（半径168pxでアナログ入力上限）、円の外側に出るとBOOST（x1.5）。境界点はRUN。
- v70の中心-指先の線＋先端円を復活。二重矢印は円の外側4方向に移動。中央円と分離帯は撤去。
- UIのシアン系RGBAを保ちつつ、モード切替で外縁・矢印が明るくなりRUN/BOOSTラベルも連動。
- 変更：`scripts/main.gd`, `scripts/touch_overlay.gd`, `project.godot`, `DEVELOPMENT.md`。v73説明文と静的検査を追加。
- 他のコード／モデル／戦闘／敵AI／被弾・ノックバック／画面グラデーションは保持。
- 検証：差分ハッシュ・入力境界条件・描画と既存処理の静的検査。Godot/Android実機は未検証。

---

# SERA v72 — 大型リングコントローラ / RUN と BOOST の2段階走行

- 基準版：v71 `sera_portrait_godot_melee_v71_vector_touch_controller.zip`。
- リング半径112→168px、透明帯との境界（半径62%）から走行ブースト、MOVE_SPEEDの1.5倍（MAX 4.875m/s）、中心へ戻すと即時RUN。走行のアナログ強度は内側62%で最大になるよう調整。
- UI：外周リングのアクティブ色、上部モードピル、および画面上のステータス行でモード可視化。v71の透明ギャップ/シアン系RGBA保持。
- 維持：タップ、フリック、ステップ、ダメージ/ノックバック、敵AI、カメラ、モデル・アニメーション、画面下グラデーション。
- 変更対象：scripts/main.gd, scripts/touch_overlay.gd, project.godot, DEVELOPMENT.md。README_v72_ja.md と検査スクリプトを追加。
- 検査：静的・差分検査。Godot/Android実行未検証。

---

# SERA v71 — コントローラのベクター描画

- 基準：v70 `sera_portrait_godot_melee_v70_damage_knockback_1_2m.zip`。
- 変更：`scripts/touch_overlay.gd` のドラッグ時ガイドだけを直接描画でリデザイン。幅広円環と四方向二重矢印、空白帯、中心円＋四方向矢印。既存の色・アルファ値を使用。
- 操作：元のタップ・ドラッグ・フリック・ステップ・攻撃を維持。ロックオン表示と下部操作エリアのグラデーションも維持。
- 検証：v71専用静的検査。GodotおよびAndroid実機での動作は未検証。
- 変更ファイル：`scripts/touch_overlay.gd`、`project.godot`、`README_v71_ja.md`、`DEVELOPMENT.md`、`tools/v71_controller_self_check.py`。

---

# SERA v70 — ノックバック距離・被弾モーション再生時間の調整

## 基準
- v69 `sera_portrait_godot_melee_v69_damage_knockback.zip` を直接の基準にしています。

## 調整内容
- 被弾ノックバック距離：0.80m → **1.20m**（最大値。衝突時は短縮）。
- 被弾モーション `Damageknock`：0.16667秒 → **0.22秒**。各キーフレーム時刻を同じ比率（約1.32倍）で伸ばし、ポーズ・補間の順番・骨の回転値は変更していません。
- ノックバック移動時間：**0.24秒のまま**。移動には二次ease-outと `CharacterBody3D.move_and_collide` を引き続き利用します。
- 入力ロックはモーションとノックバックの双方が完了するまで。今回も0.24秒で復帰する想定です（実際のフレーム刻みで前後）。
- 予兆0.65秒、射撃間隔2秒、弾速12m/s、カメラ・近接攻撃・移動・操作UIは維持します。
- プレイヤーHP・ガード崩れ・ダウンは未実装のままです。

## 修正対象
- `scripts/main.gd`：ノックバック距離の定数のみ（機能面）。
- `assets/sera_source.json`：`Damageknock` の時刻のみ。
- `assets/sera_data.gd`：APK用の組み込みデータを更新。
- `blockbench/*.bbmodel`：8モーション収録済み3ファイルの `Damageknock` を同様に更新。5モーションだけの旧モデルはそのまま保持。
- `project.godot`：表示版名v70に変更。
- `README_v70_ja.md`, `DEVELOPMENT.md`, `tools/v70_damage_knockback_self_check.py` を追加・更新。従来の `tools/v68_damage_self_check.py` の許容モーション時間に0.22秒を追加（検査内容は同等）。

## 検証
- v69との差分、骨・メッシュ・既存7モーションの完全一致、被弾モーションキーフレームの姿勢データ、組み込み用JSONの一致、移動・射撃コードの不変を静的に検査します。
- Godotエディターでの起動とAndroid実機検証は未実施です。

---

# SERA v69 — ダメージモーション短縮・ノックバック

## ベース
- v68 `sera_portrait_godot_melee_v68_damage_reaction.zip` を基準とし、v67までの射撃間隔2秒・弾速12m/sや操作・カメラ・攻撃等を維持します。
- ユーザー提供 `セラ･カラーエフェクト付き (4).bbmodel` 内の `Damageknock`（0.16667秒、once）を採用し、以前の `Damage_motion`（0.5秒）を置き換えます。
- v68の他の7モーション・モデル要素・階層・骨をそのまま保持します。

## 新しい被弾・ノックバック
- プレイヤーのカプセルに敵弾が命中したとき `Damageknock` を再生します。入射した弾の進行方向を信号で引き継ぎ、XZ水平面上で同じ方向へ押し出します（弾が飛んできた側とは反対方向）。
- ノックバック移動：最大0.80m／0.24秒、二次ease-outで徐々に減速。実際の移動量は対象の障害物との衝突状況で短くなることがあります。
- `CharacterBody3D.move_and_collide` による連続衝突判定を使います。壁／敵キューブのすり抜けや速度のフレームレート依存を防ぎます。
- 入力ロックは短いモーションとノックバックの両方が終了するまで継続。途中の攻撃・ステップを中断し、被弾中のフリック／タップ予約は破棄します。ドラッグを継続している場合は終了後に移動へ復帰。
- 被弾中の追加命中ではフラッシュのみ更新し、ノックバック距離や方向、モーションを再設定しません。
- HP、シールド、ガード崩れ、ダウンは今回追加しません。

## 変更ファイル
- `assets/sera_source.json`, `assets/sera_data.gd`（再埋め込み）、`scripts/sera_rig.gd`, `scripts/main.gd`, `scripts/enemy_shooter.gd`, `scripts/enemy_projectile.gd`, `project.godot`。
- v68の統合済み `.bbmodel` 2ファイルを更新。`blockbench/セラ_ダメージノックバック統合.bbmodel` も同梱。
- `README_v69_ja.md`, `DEVELOPMENT.md`, `tools/v69_damage_knockback_self_check.py`。
- 旧版テスト `tools/v68_damage_self_check.py` はv69で通るよう後方互換チェックに修正します。

## 検査
- 変更前後でオリジナル7モーション、骨・メッシュ・アウトライナーを厳密比較。
- Android向けデータの埋め込み一致、攻撃・移動の衝突処理、射撃パラメータ、変更差分、弾方向シグナルを静的検査。
- Godot本体実行／Android実機テストは未実施。実機でノックバックの体感値を確認してください。

---

# SERA v68 — 被弾モーション統合

## 基準
- v67 `sera_portrait_godot_melee_v67_enemy_shooter_2s_12ms.zip`。
- 提供されたBlockbench `セラ･カラーエフェクト付き (2).bbmodel` の追加クリップ `animation` （0.5秒、once）を `Damage_motion` として追加。

## 挙動
- 敵弾がプレイヤーのカプセルに命中した時だけ、提供された0.5秒のダメージアニメーションを再生。
- 再生中は移動・ステップ・攻撃開始を禁止。被弾中に始めた・中断されたフリックやタップは、終了後に予約発動しない。実行中の攻撃/ステップを中断し、ヒットストップや剣軌跡も終了。
- アニメーション終了で待機に復帰。ドラッグが継続中なら走行に復帰（指を離していたら待機）。
- 被弾中の追加命中では再生を最初からやり直さず、従来の赤いフラッシュのみ更新。
- プレイヤーHP、シールド値、ガード崩れ、ノックバック、ダウンは未実装。既存の敵HP・攻撃処理は維持。

## リソース
- `assets/sera_source.json` はv67のモデル・既存7モーションを維持し、今回の1モーションだけを追加。
- `assets/sera_data.gd` に統合モデルデータを再埋め込み。Android APKでJSONが利用不能でもモーションを利用可能。
- Blockbench編集用統合モデル：`blockbench/セラ_被弾モーション統合.bbmodel`（既存のステップモーションも含む）。

## 変更ファイル
- `scripts/main.gd`, `scripts/sera_rig.gd`, `assets/sera_source.json`, `assets/sera_data.gd`, `project.godot`。
- 既存のBlockbenchモデル（7クリップ）を更新、統合モデルの日本語名コピーを追加。
- `README_v68_ja.md`, `DEVELOPMENT.md`, `tools/v68_damage_self_check.py`。

## 確認
- 元モデルと今回のモデルで骨UUID22件・要素25件・アウトライナーが一致することを確認。
- 元のモデルの既存7モーションはそのまま維持。
- JSON/埋め込み一致、遷移と入力ガード、既存ファイル差分を静的に検査。
- Godot/Android実行は未実施。モーションの見え方は実機で確認が必要。

---

# SERA 開発履歴（基準版と追加機能）

## v67 — 敵射撃間隔2秒・弾速12m/s
- 基準: `sera_portrait_godot_melee_v66_enemy_shooter.zip`。
- 変更: 実際の弾発射から次の弾発射までを約2.0秒に固定。予兆0.65秒はこの2秒に含める（射撃後の待機1.35秒）。
- 変更: 初弾は開始約2.0秒後（最初の予兆開始は約1.35秒後）。
- 変更: 弾速を7.5m/s → 12.0m/sに変更。
- 変更ファイル: `scripts/enemy_shooter.gd`, `scripts/enemy_projectile.gd`, `project.godot`, `DEVELOPMENT.md`。
- 追加ファイル: `README_v67_ja.md`, `tools/v67_enemy_ai_self_check.py`。
- 維持: 照準固定、予兆0.65秒、直進弾、被弾時の赤点滅、敵HP0で射撃停止、カメラ、プレイヤー操作、攻撃、エフェクト等。
- 検証: 数値設定、インターバル算式、同一ファイル保持、ZIP差分、リソース参照の静的検査。Godot実行・Android実機検証は未実施。

## v66 — Enemy Ranged AI
- 基準: ユーザー提供 `sera_portrait_godot_melee_v65_recommended_gray_operation_gradient.zip`。
- 追加: 固定ターゲットからの低頻度単発弾（初回2.2秒、予兆0.65秒、待機4.5〜6.5秒、弾速7.5m/s）。
- 追加: 固定方向への射撃、射撃予兆の発光球、プレイヤー衝突検知、命中フラッシュ。
- 追加: 敵HPが0の場合は新規射撃停止。
- 変更: `scripts/main.gd`, `project.godot`。
- 新規: `scripts/enemy_shooter.gd`, `scripts/enemy_projectile.gd`, `README_v66_ja.md`, `tools/v66_enemy_ai_self_check.py`。
- 維持: v65までの操作、ロックオン、カメラ、近接攻撃、HP、剣エフェクト、操作領域。
- 未実装: プレイヤーHP・シールド・ガード・被弾モーション・吹き飛び等。命中時は表示のみ。
- 検証: ZIP差分、リソース参照、関数定義重複・インデントの静的点検、発射位置算定。Godot実行/Android実機未検証。

## v65（提供された基準版）
- 推奨グレーの操作領域と下端8%の均一色、上部へのグラデーション（原本README参照）。


## v75 — Selective low-cost motion blur (2026-11-06)
- Baseline: v74 step min 8m/s.
- Changes: `scripts/main.gd`, `scripts/sera_rig.gd`, `project.godot`; new `shaders/sera_motion_ghost.gdshader`, `shaders/selective_far_blur.gdshader`, `README_v75_ja.md`, `tools/v75_motion_blur_self_check.py`.
- Only step and outward-ring movement boost get blur: one animated mesh overlay for Sera, 3-tap ground pass masked by player distance (7-11m); scene objects in `motion_blur_far_environment` opt in.
- Preserved: input, movement and step speeds and paths, animation data, camera, targeting, attacks, enemy AI, damage and knockback, HUD.
- Performance approach: no history framebuffer, no extra Viewport, off-state extra passes disabled; static validation only, Godot/Android execution not available in this environment.


## v76
- Removed far/background motion blur after it felt excessive during movement.
- Replaced the single player ghost pass with three lightweight afterimage layers.
- Each afterimage uses a different alpha and offset, enabled only during step and boost movement.


## v77 — 時間差残像・スナップショット化
- 基準：v76 `sera_portrait_godot_melee_v76_player_triple_afterimage.zip`。
- v76の現在姿勢に追従する3重メッシュを撤去し、発生時刻の全身ポーズ・座標をワールド固定のMultiMeshに記録する方式へ変更。
- 0.055秒ごとに発生、0.22秒の寿命、二次の透明度減衰、最大3層。新規発生はステップ／ブースト中だけ、停止後は自然消滅。
- 各パーツの元メッシュを共有するGPU instancing、24パーツ×3インスタンスで処理。
- 背景ブラーなし。射撃、カメラ、入力、ステップ速度、被弾、ノックバック、モデルとモーションは変更なし。
- 変更：scripts/main.gd、scripts/sera_rig.gd、shaders/sera_motion_ghost.gdshader、project.godot、DEVELOPMENT.md。追加：README_v77_ja.md、tools/v77_temporal_afterimage_self_check.py。
- Godot本体とAndroid実機での動作・描画性能は未検証。


## v78 — ブースト残像フェード短縮（2026-11-06）
- 基準：v77 `sera_portrait_godot_melee_v77_temporal_afterimage.zip`。
- ステップの残像寿命0.22秒、初期不透明度34%、発生間隔0.055秒、二次減衰は維持。
- ブースト残像寿命を0.22秒から0.14秒へ短縮。初期不透明度28%、発生間隔0.055秒を維持。
- 発生時の残像種別ごとに寿命をスロットへ格納し、モード移行後も元の消滅時間でフェード。
- 変更：scripts/sera_rig.gd、project.godot、DEVELOPMENT.md。追加：README_v78_ja.md、tools/v78_boost_afterimage_self_check.py。
- 既存移動、カメラ、攻撃、敵AI、被弾、モデル、ブラー除外対象、3枚MultiMesh処理は維持。
- 静的・差分検査実施。Godot/Android実機実行は未検証。


## v79 — 格闘ブーストキャンセル時のカメラ追従修正
- 基準: v78
- 変更: scripts/main.gd, project.godot, README_v79_ja.md, tools/v79_camera_follow_self_check.py, DEVELOPMENT.md
- カメラの移動判定で格闘のBOOST/STRIKE状態が停止判定となりリセンタリングを開始していた点を修正。
- DASHだけでなく全ての格闘フェーズで移動追従を継続。ブースト移動では高速なヨー・ズーム補間を適用。
- 走行/ステップの従来レート、カメラの構図・視野制約・当たり判定・戦闘挙動、残像、敵AIは維持。
- 静的・数値検証のみ。Godot/Android動作確認は未実施。


## v80 - point-blank side-step camera correction
- Base: v79. Reverted v79's accelerated melee/boost camera-follow changes to the exact v78 camera behavior.
- Camera-specific changes in scripts/main.gd: snapshot near-step flag and starting yaw, cap yaw travel at +/-18 degrees for steps beginning <=1.0m from target cube surface, bypass forced screen-edge yaw during those steps. Standard full-frame zoom protection stays.
- Existing gameplay/motion/AI/assets unchanged. Runtime not verified.


## v81 - scope error repair for close-step camera flag
- Base: v80; only `scripts/main.gd` changes gameplay code.
- Root cause: `_physics_process` declared `close_step_camera_this_frame` locally, while `_process` referenced it.
- Fix: promote flag to a typed class member; assign it at the same physics-tick snapshot point; preserve camera yaw logic and all v80 behavior.
- Updated project title and added README_v81_ja.md and v81 scope regression test.
- No runtime validation claimed; source and archive static checks performed.


## v82: target-relative close step camera
- Baseline: v81 close-step camera scope fix.
- Removed v80 start-yaw +/-18 degree clamp; constrain target-centered camera/player bearing separation instead (+/-65 degrees), with 300 degrees/sec slew.
- Added 0.18s transition after point-blank step ends; new touch cancels transition.
- Left normal movement/boost, distant step, damage, AI, rendering, and movement untouched.
- Changes: scripts/main.gd, project.godot, README_v82_ja.md, DEVELOPMENT.md, tools/v82_close_step_camera_self_check.py.
- Runtime/Android device verification pending.

## v84 (2026-11-06) — Blockbench板基準の8フレーム剣閃
- 基準版: v83。ユーザー添付SERA_melee_combo_3.bbmodelのSwordeffectキーのみ反映。Damageknock、Melee2の体モーション、モデル形状を保持。
- 変更: sword_trail.gdを単一板＋4x2 UVアニメへ置換、sera_rig.gd旧0.55m前方補正撤去。白/赤モバイルシート新設。元のヒットエフェクトとカメラ等は維持。
- 変更ファイル/検査方法はREADME_v84_ja.md、tools/v84_sword_fx_self_check.pyを参照。Godot実行およびAndroid実機確認は未実施。

## v87（2026-11-06） — 下フリックのバックステップ／ブーストとステップの区別
- 基準：ユーザー添付 `sera_portrait_godot_melee_v86_combo_damage_12_12_26.zip`。
- ユーザー提供 `SERA_backstep.bbmodel` の `Backstep`（1ポーズ・18キーフレーム・時刻0）を、v86モデルの既存10クリップを保持して追加。編集可能な統合 `bbmodel` と原本コピーを同梱。
- 下方向のリリース・フリックでロックオン対象から2.0m後退、8〜10m/s、専用姿勢を再生。既存の側方ステップと同じ衝突判定、残像、ブレンドを利用。
- 分類を明確化：BOOST＝円外への長距離ドラッグ時の加速移動、STEP＝フリック高速回避、MELEE APPROACH＝タップ格闘時の自動接近（従来の `meleeboost` モーション）。内部の格闘接近状態・アニメーション呼び出しも`MELEE_APPROACH`系へ改称し、加速移動BOOSTとの混同を解消。
- 変更：`scripts/main.gd`, `scripts/sera_rig.gd`, `assets/sera_source.json`, `assets/sera_data.gd`, `project.godot`, `DEVELOPMENT.md`。追加：`blockbench/SERA_backstep_user_input.bbmodel`, `blockbench/SERA_v87_backstep_integrated.bbmodel`, `README_v87_ja.md`, `tools/v87_backstep_self_check.py`。
- 維持：v86の12/12/26コンボ、左右ステップ軌道、ブースト速度、視点制御、残像／エフェクト、敵AI／被弾／HP表示。
- 検証：JSON・埋め込み・キーフレーム、入力分岐、計算式／既存要素を静的検査。GodotおよびAndroidの実行テストは未実施。


## v88（2026-11-06） — バックステップ距離4m
- 基準版：v87。変更：`BACK_STEP_DISTANCE` を2.0mから4.0mへ。
- 既存8〜10m/sの速度を保持するため所要時間は0.40〜0.50秒。側方ステップの最大0.40秒制約は維持。
- HUD待機時の表示は左右ステップとバックステップの違いを明示。
- その他の入力・格闘・カメラ・モーション・アセット・AIは変更なし。検証範囲と制限は`README_v88_ja.md`に記載。


## v89 — Boost_front モーション実装（2026-11-06）
- 基準：v88。
- ユーザー提出 `SERA_backstep.bbmodel (1)` を正しい .bbmodel 拡張子に直して `SERA_boost_front_user_input.bbmodel` に保管。
- 新規 `Boost_front`（時刻0の21キーフレームの静止ポーズ）だけをv88の既存モデルに統合。従来の11クリップ・25要素・22グループは保持。
- 通常ドラッグ `run_front_original`、外周超ロングドラッグ `Boost_front`、フリックステップは従来どおり各専用モーション。
- ブースト倍率1.5、4mバックステップ、既存攻撃・残像・カメラ処理は保持。
- 修正：scripts/sera_rig.gd, scripts/main.gd, assets/sera_source.json, assets/sera_data.gd, blockbench/SERA_boost_front_user_input.bbmodel, blockbench/SERA_v89_boost_integrated.bbmodel, project.godot, README_v89_ja.md, tools/v87_backstep_self_check.py, tools/v89_boost_self_check.py, DEVELOPMENT.md。
- 静的検査で統合・旧機能を点検。Godot実行およびAndroid実機は未検証。


## v90（2026-11-06） — RUN/BOOST入力しきい値・スナップ・ヒステリシス
- 基準v89。通常走行の最大入力半径100%と、実指125%連続0.10秒のBOOST開始、110%未満のBOOST解除を分離。
- BOOST倍率1.0→1.5を0.15秒で加速・減速。リグの0.16秒ポーズブレンドとフリックステップは独立。
- RUN/BOOST UIに、外周超過時のみ125%地点の薄いガイド弧を表示。外周スナップは従来のノブの丸い位置制限を維持。
- v89モデル・AI・戦闘・カメラ・4mバックステップは変更なし。差分：scripts/main.gd、scripts/touch_overlay.gd、project.godot、README_v90_ja.md、tools/v90_boost_threshold_self_check.py、DEVELOPMENT.md。
- 静的検査実施。Godot/Android実機実行未検証。

## v91（2026-11-06） — 敵攻撃4種と選択用デバッグUI
- 基準：v90。初期選択AIM、AUTO ON（約2秒周期）を保持。
- 追加：AIM（固定自機狙い）、LEAD（警告開始時の速度から偏差位置を計算し固定）、SHOCK（全周・前進リング）、ARC（前方145°・地上円弧状範囲）。すべて予告後に攻撃。被弾は既存Damageknockへ接続。
- HUDの直下に「AIM / LEAD / SHOCK / ARC / FIRE / AUTO」バー。攻撃切替時は旧弾と旧範囲を消去。バー上のタッチをプレイヤー操作から隔離。
- 新しいエリア攻撃は軽量ImmediateMeshと水平距離・角度判定、パーティクルなし。衝撃波は前フレームからのリング拡大区間を判定し高速すり抜けを抑制。
- 変更：scripts/main.gd, scripts/enemy_shooter.gd, scripts/enemy_projectile.gd, project.godot, DEVELOPMENT.md。追加：scripts/enemy_area_attack.gd, scripts/enemy_debug_ui.gd, README_v91_ja.md, tools/v91_enemy_attacks_self_check.py。
- 維持：RUN/BOOST、左右/後方STEP、4mバックステップ、3段格闘(12/12/26)、モデル/モーション、カメラ、残像、従来の被弾処理。詳細はREADME_v91_ja.md。
- 静的・数値チェックのみ。Godot/Android実機検証未実施。

## v92（2026-11-06） — 被弾後のブースト入力復帰
- 基準：v91 `sera_portrait_godot_melee_v91_enemy_attack_debug.zip`。
- 不具合：被弾時にONとなるジェスチャー抑制フラグが、ダメージリアクション終了後も指を離すまで残るため、同じドラッグでブースト再発動できない。
- 対応：`_update_boost_gesture` のブースト禁止条件を `damage_reaction_active` に限定。被弾中は停止し、被弾終了後は同じ指のまま125%以上/0.10秒でブーストへ復帰。
- 維持：`gesture_suppressed_from_damage` は指離し時のステップ／タップ誤発動防止にのみ使用。v91の戦闘、敵4種、カメラ、モーション、ブースト／ステップ、ダメージ演出を維持。
- 変更：scripts/main.gd、project.godot、DEVELOPMENT.md。追加：README_v92_ja.md、tools/v92_boost_damage_regression.py。
- 検証：静的・数値検査、差分比較、ZIP整合性。Godot・Android実動作は未検証。


## v93（2026-11-06） — 敵・自機の金属ダメージ効果音
- v92を基準に、ユーザー提供 `金属叩き.mp3` を効果音の共通ソースに採用。
- WAV化した `assets/metal_damage_hit.wav` を敵への格闘ヒット音と自機への敵攻撃ヒット音へ設定。元MP3も同梱。
- 2つのAudioStreamPlayerで同時／連続ヒットを再生、原音を変えるピッチランダム化は撤廃。音量-5dB。
- 戦闘処理・被弾処理・操作・カメラ・モデル・既存アセットは維持。変更点と検証はREADME_v93_ja.md、tools/v93_audio_self_check.pyを参照。
- Godot/Android実機再生は未検証。


## v94（2026-11-06） — 直線弾／格闘段別のユーザー提供ダメージ音
- v93基準。敵の狙い弾・偏差弾が自機に命中した際、`sera_bullet_hit_short.wav` を再生。
- 自機の格闘1・2段目が敵へ命中した際、`sera_melee1_short.wav` を再生。3段目のみ `sera_melee2_long.wav` を再生。空振り時の音はなし。
- 衝撃波・円弧面攻撃はv93の `metal_damage_hit.wav` を維持。敵シューターの命中シグナルに攻撃インスタンス確定の `is_bullet` を伝搬。
- WAVはユーザー提供の48kHz/16bit/ステレオを無加工同梱し、-5dBで再生。既存機能・ダメージ数値・モーション・カメラ変更なし。
- 追加・変更ファイルと検証は `README_v94_ja.md`、`tools/v94_sfx_self_check.py` 参照。Godot・Android実機は未検証。


## v99 (2026-11-06)
- v98基準。Jumpのみに0.5s最終着地キーフレームを統合、空中0..0.375sと着地0.375..0.500sを分割。
- 接地後0.125sの着地移行、最終姿勢で0.60s硬直後に立ち上がり。入力ロック/被弾割り込み、空中ステップ格闘後の落下も対応。
- 変更ファイル・検証はREADME_v99_ja.md参照。

## 2026-11-06 — ガード中の弾被弾効果音

- v102を基準に、ガード中のAIM／LEAD弾命中だけを既存の `assets/sera_bullet_hit_short.wav` に切替。音源はユーザーが指定ファイルと同じと確認済み。
- `scripts/main.gd` に専用プレイヤーを追加（-5dB／多重再生3）。通常被弾、範囲攻撃、ガード反応抑止、その他のゲーム機能は維持。
- 検証：既存Pythonチェック3本、Godot headless import・短時間起動・命中音分岐テスト。Android実機の音声確認は未実施。

## v106（2026-11-07） — RUN 4方向アニメーション適用
- 基準：GitHub main v105。ユーザーが追加した `bbmodel/SERA_back.bbmodel` の前後左右4クリップを採用（前進は更新版）。
- 既存22グループ・25要素・他13クリップ・Jump英語名・Swordeffectモデル・音源・BGMは維持。モデルを丸ごと置き換えず、アニメーションだけを `assets/sera_source.json` へマージし、埋め込みと編集用モデルを同期。
- 画面基準移動ベクトルをターゲット基準のローカル方向へ投影し、RUN時だけ優勢な前後左右へ切替。近接する斜め方向の入力にはヒステリシスを適用し、RUN間で位相保持。全RUNに従来倍率1.5を適用。
- 変更：`scripts/sera_rig.gd`、`scripts/main.gd`、`assets/sera_source.json`、`assets/sera_data.gd`、`project.godot`、`tools/v102_guardfix_self_check.py`、`DEVELOPMENT.md`。追加：`blockbench/SERA_v106_four_way_run_integrated.bbmodel`、`README_v106_ja.md`、`tools/v106_four_way_run_self_check.py`。
- 可能な静的構造チェックのみ実行。Godotヘッドレス、Python実行、Android実機は未検証。詳細は `README_v106_ja.md`。

## v107（2026-11-07） — RUNモーション90度方向ずれ修正
- v106（GitHub main `d34f2a6ef3c6549b522f3f0a15797997dda8dc01`）を基準。実機で「左を正面として4方向モーションが再生される」と報告。
- 原因：提供RUN 4クリップの最上位 `Waist` の回転は、`Wait_motion` の約-20度に対し、前／後約+75度、右約0度、左約+177度で、全方向の軸が90度ずれていた。
- `scripts/sera_rig.gd` 内のRUN 4クリップだけを対象に `Waist` の回転と相対位置をワールドY軸基準-90度のQuaternionで補正。ブレンド前に適用し、180度オイラー姿勢を含む左右クリップも正しく補正。入力方向選択・プレイヤーの向き・通常の移動位置・カメラ・格闘・ブースト・ステップ・その他のモーションとモデルデータは変更しない。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`。追加：`README_v107_ja.md`、`tools/v107_run_facing_self_check.py`。
- JSONアニメーションの数値・補正後の4方向の軸向き・変更範囲をGitHubコネクタ経由で確認。Godot/Android実機の動作テストは未実施。

## v108（2026-11-07） — 4方向RUNの連続ポーズブレンド
- 基準：GitHub main v107（`65d8e874bf49f8d7c2192416d578564830956047`）。4方向走行の切替を滑らかにするため、前/後/右/左の離散的クリップ選択を廃止。
- ターゲット基準の移動入力から前後左右4方向の重みを計算し、1秒の同期した各RUNクリップを毎フレームQuaternion slerp＋位置/スケールlerpで合成。45度は2方向各50%、方向転換では重みを時定数0.12秒で指数平滑化。RUN中のクリップ切替による位相リセット/都度0.16秒スナップショットを廃止。
- v107腰ルートの-90度Quaternion補正は各RUNクリップへ合成前に適用。WAIT/BOOST/STEP/攻撃/Guardなどへの遷移は従来のポーズスナップショットを用いる。
- 変更：`scripts/sera_rig.gd`、`scripts/main.gd`（デバッグHUD表示のみ）、`project.godot`、`tools/v107_run_facing_self_check.py`、`DEVELOPMENT.md`。追加：`README_v108_ja.md`、`tools/v108_run_blend_self_check.py`。音声/カメラ/移動/当たり判定/アセットと元キーフレームは不変。
- Python/モデル参照/ブレンド重みの静的検査、差分の確認を実施。Godotランタイム/Android実機のモーション確認は未実施。

## v109（2026-11-07） — 方向転換時の軽い左右バンク
- 基準：GitHub `main` v108（`83eb19cec5dbc1e5b79e9bd04df1ea67927a86b0`）。4方向RUNの連続ブレンドを保ちながら、転換方向へ最大5度だけ視覚上の腰ルートを傾ける。
- v108で指数平滑化した移動方向の前フレームとの差から左右符号付き旋回速度を求める。7rad/sで最大傾斜とし、立ち上がり時定数0.06秒、方向確定後の復元時定数0.20秒で連続追従。直接180度反転して左右の旋回方向が定義できない場合は新規バンクを掛けず、移動方向ベクトルのゼロ付近も安全に処理する。
- `scripts/sera_rig.gd` のRUN 4クリップ合成後に限り、既存のv107ルートYaw補正の後で腰（Waist）ルートへ局所Z軸のQuaternionを左乗算する。ワールド位置、衝突、移動入力・カメラ、非RUNアニメには適用しない。状態遷移時は従来ポーズブレンドの中で自然に傾きを解消する。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`。追加：`README_v109_ja.md`、`tools/v109_run_turn_bank_self_check.py`。
- GitHubコネクタ経由でコードと変更範囲を静的点検。Godot/Android実機での動作確認は未実施。

## v110（2026-11-07） — RUN方向転換の最大傾斜角を15度へ
- 基準：GitHub main `fbf714088a3edf1e788ec0b1d71103d9b76ad8ee`（v109）。ユーザー指定によりRUN方向転換の最大バンク角 `RUN_TURN_MAX_LEAN_DEGREES` のみ5.0→15.0度へ変更。
- 旋回角速度からの換算・立ち上がり0.06秒・復元0.20秒、v108の連続4方向RUNブレンド、v107の腰ルート向き補正、戦闘/入力/カメラ/移動/当たり判定/アセットは変更しない。
- 変更：`scripts/sera_rig.gd`、`tools/v109_run_turn_bank_self_check.py`（現行角度への追従）、`project.godot`、`DEVELOPMENT.md`。追加：`README_v110_ja.md`、`tools/v110_run_max_lean_self_check.py`。
- GitHub上の差分・計算式の静的点検を実施。Godot/Android実機動作は未検証。

## v111（2026-11-07） — 前方RUN／後方後ずさり2モード＋段階的ターゲット追従
- v110（`48929713dc59a1454ae1199f7ce7d292c932770e`）基準。走行中の4方向同時ブレンドを廃止し、前方走り `run_front_original` と後退 `run_back` の2モードへ変更（左右モーションはモデルデータに保持）。前方200°、後方160°を名目判定とし、ヒステリシス95°／105°を導入。
- ルートWaistを前進では進行方向、後退では逆方向へ向け、最大450°/sで短い角度経路を追従し、腰位置の揺れも同角度で回転。前後歩行は同期位相・0.18秒ブレンド。Torso20%、Chest累積50%、Neck累積75%、Head累積100%までターゲット追従を増やし、関節ごとの回転上限で過度なねじれを抑制。関節補正角の境界反転は時定数0.10秒で平滑化。
- v107の前後ソース90°補正と、v109/v110の最大15°旋回バンクを維持。バンク軸は新たなルートの向きに追従。プレイヤー本体・移動速度・カメラ・衝突・攻撃・ガード・ブースト・ステップ・ジャンプ・モデル・BGM・SEは変更しない。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`、`tools/v108_run_blend_self_check.py`、`tools/v109_run_turn_bank_self_check.py`、`tools/v110_run_max_lean_self_check.py`。追加：`README_v111_ja.md`、`tools/v111_two_mode_run_self_check.py`。静的・数値検査はコネクタ経由、Godot/Android実機未検証。

## v112（2026-11-07） — 左後方のRUN範囲拡大と左右利き手切替
- 基準：GitHub `main` v111（`9f5e6e846b56c7c65a2a5a96e15dcbef5fdc55de`）。右利き設定の左側のみ前方RUN判定を20°拡張（中心100→120°、切替105→125°／復帰95→115°）。反対側は従来95/105°を維持。左利き設定時は右側だけ同じ20°拡張。
- `scripts/sera_rig.gd` に利き手別前方セクタ中心計算と既存±5°ヒステリシスを組み合わせ、前後2モーションの自然な切替を維持。プレイヤー実移動・STEP・BOOST・カメラ・ガード・格闘・アセットは変更しない。
- `scripts/main.gd` の上部HUDに `HAND: RIGHT/LEFT` ボタンを追加し、`ConfigFile` で `user://sera_settings.cfg` へ保存。次回起動時に復元、走行中でも変更可能。HUD内タッチは従来どおりプレイヤー操作として扱わない。
- 変更：`scripts/sera_rig.gd`、`scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`、`docs/SERA_INPUT_MOVEMENT_CAMERA.md`、`tools/v111_two_mode_run_self_check.py`。追加：`README_v112_ja.md`、`tools/v112_handed_run_mode_self_check.py`。
- コード構造・数値遷移を静的点検。Godot/Android実機での操作は未検証。

## 2026-11-07 — GitSync同期トリガーをGitHub Actionsへ追加（ゲームバージョン変更なし）
- `main` pushでntfyへ固定本文 `SERA_SYNC_MAIN` を送る `.github/workflows/sera-gitsync-notify.yml` を追加。 `workflow_dispatch` による手動試験も可能。リポジトリのコードは取得せず、Secretsの `SERA_NTFY_TOPIC` を利用。
- Secret未設定では送信せず通知ログだけ。トピックは24～64文字・英数字/ハイフン/下線に制限。通知本文にコミット・プライベートファイル名を含めず、サーバーへの送信成功のみを報告。
- `docs/GITSYNC_AUTO_SYNC_SETUP_JA.md` にntfy購読、Taskerの `MESSAGE_RECEIVED` → GitSync `INTENT_SYNC`、Godot稼働中の同期待機・旧アプリ起動同期OFF・E2E検証の手順を記載。
- Godot `project.godot` とコード・アセットは無変更。ゲームv112維持（Godot表示名「スキャンテスト」も維持）。Android側Tasker設定・GitHub Secret登録はユーザー操作が必要で、実機E2Eは未確認。
 
## v114（2026-11-07） — BOOSTERALLの4方向ブースト姿勢と連続補間
- 基準：GitHub main `f205c9f49cd1470ec1a2e931d8a456063a7d5f72`（v113）。`models/SERA_BOOSTER_all.bbmodel` から前／後／左／右の単一ポーズ計4クリップを原本キーそのままで取り込み、旧 `Boost_front` をユーザー版に更新。旧17→20クリップ。
- `scripts/sera_rig.gd` のBOOST描画だけ、進行方向に隣接する前後・左右の2姿勢を角度重みとQuaternion SLERP／位置・スケールLERPで合成。方向変化は最短角・時定数0.12秒で追従し、既存の状態遷移0.16秒を維持。
- `scripts/main.gd` の既存のターゲット相対入力は無変更で利用し、BOOSTのHUD表示を優勢クリップ名に更新。新統合モデル、埋め込みモデル、v114検査、v114 READMEを追加。過去の一部回帰テストの17クリップ／固定バージョン名前提だけ追従。
- 既存のRUN 2モード、頭部安定化、利き手判定、格闘、ガード、ステップ、ダメージ、ジャンプデバッグ、カメラ、当たり判定、速度、残像、BGM/SEと非BOOSTクリップ／元モデルを維持。
- GitHub上の原本一致、アニメーション数・キー時刻、旧データ保全、Base64バイト一致等を静的検証。Pythonテストコマンド、Godotエディター、Android実機の実行検証は未実施。

## v115（2026-11-07） — BOOST中のコントローラ操作点を境界線外側へ移動
- 基準：GitHub main `20fc714b305e0bde84dd1ce7447aaffbfe054882`（v114）。`scripts/touch_overlay.gd` の描画のみ修正し、RUN中は従来の半径100%（168px）で操作点を表示。
- BOOST確定中は方向に沿って操作点の中心を半径148%（248.64px）に表示し、操作点の半径29px全体が起動ガイド半径125%（210px）の外側に残るようにする。BOOST終了時はRUN位置へ戻す。
- 125%のガイド短弧はBOOST確定後も非表示にせず明るく太く描画。確定前に実際の指がRUN円を越えた場合は以前どおり薄いガイドを表示。
- BOOSTの入力判定125%・保持0.10秒・解除110%未満・加減速0.15秒・移動1.5倍は不変更。v114の4方向モーション補間、カメラ、残像、格闘、ガード、ステップ、音声、モデル・リソースに変更なし。
- 変更：`scripts/touch_overlay.gd`、`project.godot`、`DEVELOPMENT.md`、`docs/SERA_INPUT_MOVEMENT_CAMERA.md`。追加：`README_v115_ja.md`、`tools/v115_boost_controller_visual_self_check.py`。
- GitHub差分と描画用半径の静的計算を点検。GodotエディターとAndroid実機の描画・入力体感は未検証。

## v116（2026-11-08） — BOOST姿勢の応答高速化・RUN再生速度1.25倍
- 基準：GitHub main `126cc74e5b3fe823d929199a24d5f73e2727d6bb`（v115＋Android側モデル同期コミット）。同期済みの`models/`ファイルは変更せず継承。
- RUNモーションの`RUN_ANIMATION_SPEED`は既存1.5に1.25を乗じて**1.875**に更新。全RUN方向は共通の時刻`clip_time`を使用し、方向・前後走行切替・頭部スタビライズの構造は維持。移動速度は不変更。
- BOOSTの4方向姿勢追従の時定数を0.12→0.06秒に短縮。RUN/WAIT⇄BOOSTの遷移だけ`BOOST_STATE_BLEND_SECONDS=0.08`を採用（従来0.16秒）。その他の状態遷移は既定0.16秒、戦闘・ステップ等の既存専用遷移時間を維持。
- BOOSTを確定させる入力距離125%、0.10秒ホールド、解除110%未満、速度加減速0.15秒、移動倍率1.5を維持。モーションアセット、モデル、ガード・格闘・カメラ・残像・コントローラUIには変更なし。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`、`docs/SERA_INPUT_MOVEMENT_CAMERA.md`、既存テスト`v108`/`v114`/`v115`。新規：`README_v116_ja.md`、`tools/v116_animation_timing_self_check.py`。
- ソース構造・遷移対象・数値モデルの静的検証を実施。Pythonスクリプトの実行、Godot実行、Android実機での操作確認は未実施。


## v117 — 2026-11-08 Command Nexus blockout
- Added a two-button startup selector: TRAINING ROOM (existing scenes/main.tscn) and SERA COMMAND NEXUS (new static hangar).
- Added Blockbench editable simplified hangar blockout under blockbench/SERA_Command_Nexus_LowPoly.bbmodel.
- Added lightweight procedural hangar and reused existing Sera rig; terminal signs are static and noninteractive.
- Existing training combat scripts unchanged. Android/Godot runtime not tested; verify scene import, model appearance, and selector on device.

## v118 — 2026-11-08 startup selector layout correction
- Replaced hard-coded position and 600px width with CenterContainer and viewport-responsive width.
- Both buttons use direct scene change with error logging. Base scene loading still requires Android runtime verification.
- Training scene and combat untouched.

## v119 — 2026-11-08 起動メニュー・拠点読込の再修正
- 基準：main `9f15d273cebdcb197e2f2364aaf2704407fef731`（v118）。別ブランチ `fix/v119-nexus-startup-layout` で修正。
- 原因1：拠点 `scripts/command_nexus.gd` の `Environment.AMBIENT_COLOR` はGodot 4に存在せず、拠点シーンのスクリプト読込に失敗する。 `Environment.AMBIENT_SOURCE_COLOR` へ変更し、環境光色を有効化。
- 原因2：`project.godot` の `input_devices/pointing/emulate_mouse_from_touch=false` では通常のGodot GUI `Button` がAndroidタップに反応しない。起動メニュー表示中のみ変換をON、シーン終了で元に戻す。
- レイアウト：プログラムによる固定座標配置を廃止し、`scenes/launch_menu.tscn` のFull Rect＋MarginContainer＋CenterContainer＋VBoxContainerで画面中央に配置。幅は上限500px、画面に応じて縮小。
- 既存汎用検査の起動シーンパスを更新、v116の機能検査は後継版名でも有効に。新規 `tools/v119_command_nexus_self_check.py` と `README_v119_ja.md`。
- 訓練シーン・戦闘処理・モデル・アニメーション・レンダラー・表示解像度は変更なし。基地内設備の操作は未実装。
- 静的検査はGodot本体およびXperia 1 V実機でのタップ/描画確認を代替しない。

## v120（2026-11-08） — Command Nexus表示をBlockbench設備で再構築
- 基準：GitHub main `0341eb1dfe07f799a1df643ed79d305741f19dc3`（v119）。ユーザーのスクリーンショットで、セラが小さく屈み、ゲートが切れ、UIと設備デザインが参考画像と大幅に異なることを確認。
- v117/v119の `command_nexus.gd` ではBlockbenchモデルが未使用だった。6種類の独立したシンプルなBlockbenchモデル（ハンガー内装・整備台・上部リング・出撃ゲート・汎用端末・データ端末）を作成して、対応したGodot部品データへ埋め込み、色別MultiMeshで実際に配置する方式へ差し替え。
- 基地内のセラは既存 `SeraRig` のバインドポーズ（腕の角度のみ調整）にし、戦闘用Wait_motionを停止。戦闘シーンでは従来どおりモーションを使用。
- カメラ位置/視野角、ゲートサイズ/配置、端末位置を縦画面で見える位置に調整。5つの読み取り専用メニューパネルと軽量ベクターアイコンを追加。基地内メニューのタップ機能は未実装。
- `scripts/main.gd`、`scripts/sera_rig.gd`、既存モデル・音声・訓練シーン・起動2択・プロジェクト表示解像度・GL Compatibilityは変更なし。
- 新規 `tools/v120_command_nexus_self_check.py`、`README_v120_ja.md`。v119の検査は後継版対応に更新。Godot実行/Android実機テストは未実施。

## v121（2026-11-08） — Command Nexus のレイアウトと遠近調整
- 基準：main `5e0482ad6431eaed884ee8ad9e01fd7e93e6b5b0`（v120）。ユーザーの参考画像と実機スクリーンショットを再確認。
- 基地の左上にある `SERA SYSTEM / COMMAND NEXUS` 文字と横罫線を削除。表示領域を遮る不要なHUDを撤去。
- DATA ARCHIVEとDEPLOYMENTの見出しは画面高さの27.2%→20.5%へ上げる。TRAININGとSYSTEMは54.2%→50.5%へ調整。CUSTOMIZEは維持。
- 設備は前景（TRAINING・SYSTEM）、中景（セラ・整備台）、遠景（DATA ARCHIVE・DEPLOYMENT）の3段構成へ配置変更。前景をカメラへ近付け、中景を約0.55m、遠景を約0.7〜0.8m後方へ移動。出撃ゲートのスケールを0.70に調整。
- カメラを(0,3.8,7.4)、注視点を(0,2.5,-4.7)、FOVを56°へ変更。前景・中景・遠景のサイズ差を強調。モデルを変更せずGodot上の配置のみ変更。
- v120の静的検査を新バージョンに対応させ、`tools/v121_nexus_layout_self_check.py` と `README_v121_ja.md` を追加。既存の戦闘・起動2択・Blockbenchモデル・音声等には変更なし。Godot実行/Android実機の確認は未実施。

## v122（2026-11-08） — 手前コンソールの向きを斜めに変更
- 前景のTRAINING／SYSTEM共通コンソールのGodot配置角度のみ変更。左右±10.3°から±18.0°へ増加。
- 中景／遠景の配置、カメラ、HUD、Blockbench原本、メインゲーム・訓練ステージ、各種操作は変更なし。
- `tools/v122_nexus_console_angle_self_check.py` と `README_v122_ja.md`を追加し、v121検査のバージョン条件を後継版対応に更新。
- Android/Godot実行確認は未実施。実機表示の被りや角度は再確認が必要。

## v123（2026-11-08） — 段差のある基地と大型出撃ゲート
- 基準：GitHub main v122。ユーザー指示で、データアーカイブ/デプロイメントの3Dモデルと手前のメニュー表示の重なりを解消し、前景・高台・最奥ゲートの遠近構成を作成。
- 手前の共通端末2台をz=-0.65からz=+0.75へ、角度±18°から±34°へ変更。2台以外の端末モデル原本は変更なし。
- Blockbenchで`SERA_archive_mezzanine.bbmodel`を新規作成し、昇段する6段の階段・高台・支柱・手すりを追加。データアーカイブを(-4.00, 2.19, -8.95)に配置。
- DEPLOYMENTを(4.05,0.02,-10.48)へ移動、1.20倍かつ高さ1.25倍の追加伸長（全高約6.6m）。既存後壁がゲートを遮るため`SERA_hangar_shell.bbmodel`の奥壁を開口部つきに変更。埋め込み`assets/base_command_modules.gd`を原本から再生成。
- カメラを(0,4.10,10.20)、注視点(0,3.0,-5.5)、縦FOV63°に変更。DATA ARCHIVE/DEPLOYMENTのラベルを上側に、TRAINING/SYSTEMをさらに下側に置き、投影した3Dモデルを遮る領域から避ける。CUSTOMIZEも画面下部へ移動。
- 既存の戦闘・操作・セラモデル、起動2択、モーション、音源、マテリアル別MultiMeshと基地内UIの非操作仕様は維持。`README_v123_ja.md`と`tools/v123_nexus_terraced_depth_self_check.py`を追加し、v120〜v122の既存検査期待値も更新。
- 静的幾何/投影検査はGodot実行やXperia 1 Vでの描画実測を代替しません。Android実機は未確認。

## v124（2026-11-08） — ゲートの向きと奥からの漏光、前景コンソールの手前移動
- 基準：GitHub main v123。スマートフォン実機画像でゲートが正面向きのままになっており、奥から光が漏れる表現がない点、前景コンソールをもっとカメラへ近づけたい点を確認。
- DEPLOYMENTゲートを(4.00,0.02,-10.48)へ微調整し、ローカル+Z方向の開口が中央セラ(0,0,-4.75)を向く角度をatan2で計算（約-34.9°）。ゲート形状・高さ・Blockbench資産は維持。
- ゲートと同一座標・回転の新規軽量VFX：Unshaded+Emissionの青白いQuadMesh4枚（内部2・床2）、影なしOmniLight3D1基。ボリュームライト・フォグ・パーティクルなし。
- 手前TRAINING/SYSTEMコンソールをx=±1.95,z=1.30へ移動、角度を±34°→±36°に更新。
- 720×1280前提の投影範囲、既存メニューとの非重複を静的に確認。`tools/v124_gate_lightspill_self_check.py`と`README_v124_ja.md`を追加し、v121〜123既存回帰テストも現在の値に更新。
- 既存の戦闘/操作/起動2択/モデル・アニメーション原本/Blockbench原本/音声、他設備の配置、描画レンダラーは変更しない。Godot/Android実機の描画と性能は未検証。

## v125（2026-11-08） — 拠点メニューの文字廃止と高速カメラフォーカス
- 基準：GitHub main v124（47b140b164c98576e6c6ab9efae0f6df2d880daf）。拠点全景の5つの固定タグ／サブ説明を撤去し、施設やセラ本体の輪郭をカメラ投影に沿って暗く明滅するCanvasItemの選択枠へ変更。壁面の「S E R A」は3D環境装飾として維持。
- TRAINING/SYSTEM/CUSTOMIZE/DATA ARCHIVE/DEPLOYMENTの各設備に独立した目標カメラ位置・角度・FOVを設定。ワンタップで選択時、0.18秒 Cubic Ease Out で高速に接近し、選択枠を明るく固定。他対象の選択枠は非表示。フラッシュ、残像、パーティクルなし。
- 選択後は対象名＋機能を示す最小パネルと左上戻るUIを表示。戻る操作/Android戻る/Escでは0.18秒で全景に復帰。トレーニングは既存訓練シーンへのアクションを維持。他4項目は専用画面未実装を明示する仮パネル。
- Androidの画面タップをraw InputEventScreenTouchで処理し、戦闘操作の設定Input.emulate_mouse_from_touch=falseは変更しない。PCクリックにも対応。
- 変更：scripts/command_nexus.gd、project.godot、既存静的テストv120/v121/v123/v124。追加：scripts/nexus_selection_outline.gd、tools/v125_nexus_focus_self_check.py、README_v125_ja.md。モデル・演出光源・戦闘シーン・既存アニメーション・ブロックベンチ資産・音声等は変更なし。
- Godot CLI、Android実機での動作確認は行えていないため、拠点の投影タッチ領域・各寄り構図・戻る操作は実機で追加検証が必要。

## v126（2026-11-08） — モデル形状に沿った選択枠・明滅・右下戻るUI
- 基準：GitHub main v125。手動で指定していた5つの6点ハルを廃止。Blockbench端末・ゲートの実モデル部品とセラ展示用Rigの表示メッシュを投影し、2D形状の結合によって選択用外周を生成する。3D複製モデルは描画せず、CanvasItem輪郭線のみ追加（余分なドローコールなし）。
- 各輪郭は通常画面でキャッシュし、カメラの0.18秒Tween中と画面サイズ変更時にだけ再計算。ベースの簡易ポリゴンオフセット2pxと境界結合で部品の隙間・内側線を軽減。凸包近似のため厳密なピクセルシルエットではない。
- 暗い枠の点滅を透明度15〜62%、角速度3.6rad/秒に強化。選択対象のみ透明度98%・線幅3px固定表示。
- 接近画面の「戻る」UIを左上から画面右下に移し、接近メニューパネルを必要に応じて上方へ配置して重なりを防ぐ。通常の戻る操作とトレーニングへの遷移も継続。
- 変更：scripts/command_nexus.gd、scripts/nexus_selection_outline.gd、project.godot、v121/123/125静的検査、DEVELOPMENT.md。追加：README_v126_ja.md、tools/v126_nexus_model_outline_self_check.py。v125からの既存機能・v124ゲート演出、セラのモデルとBash/Guard_REACTIONモーション、他ブロックベンチ資産には変更なし。
- 静的な形状・コード検証のみ。GodotパーサーとAndroid実機での枠表示・タップ判定・パフォーマンスは未検証。

## v127（2026-11-08） — 手前コンソール割当の左右反転・ゲート外周のセラ遮蔽・線幅増加
- 基準：GitHub main v126（65a497bfff1219f4852af6c54148a58f9415151b）。手前の左端末をSYSTEM、右端末をTRAININGとし、選択領域の割当と接近カメラ位置を交換。端末の3D座標・Blockbench原本は変更なし。トレーニングの既存シーン遷移は右側端末から可能。
- 2D選択枠で遠景ゲートのラインがセラの手前に出ていたため、ゲートの閉じた外周線をセラの実モデルに基づく投影輪郭で折れ線クリッピング（Geometry2D.clip_polyline_with_polygon）。セラ部分のゲート枠だけを不可視化し、セラ形状に沿った余計なクリップ端辺を描かない。元の閉じたポリゴンは選択判定用に維持。
- 輪郭の線幅を通常時2.5→4.5px、選択時3→5px。点滅の透明度・周期、0.18秒カメラ移動、右下戻る、システム設定・デプロイメント・カスタマイズの仮メニューは維持。
- 変更：scripts/command_nexus.gd、scripts/nexus_selection_outline.gd、project.godot、旧静的テストv125/v126、DEVELOPMENT.md。追加：tools/v127_nexus_gate_occlusion_self_check.py、README_v127_ja.md。
- Bash/Guard_REACTIONを含むセラ本体、Blockbench元モデル、戦闘処理、効果音/BGM等には変更なし。静的ソース検査のみ。Godot/Android実機でのクリップ外周、選択判定、見え方は未検証。

## v128（2026-11-08） — 片側構図の専用カメラと半透明メニューパネル
- 基準：GitHub main v127（c5e1f5f1a4da7154bfbb392760675bf699c10326）。SYSTEMとDATA ARCHIVEはモデルを画面左、TRAININGは右、DEPLOYMENTは右斜めから小さめに見せる。CUSTOMIZEはセラの左前方から斜めに映し、全身・剣・台座が画面右に入るFOV67°のアングルへ変更。モデルの位置やサイズは不変更。
- 各接近画面の空間側に、ボーダー・角丸なし単色半透明サイバー青（α=0.52）で大きな四角い仮メニューパネルを追加。上部帯のみ不透明青（α=1.0）にして英語のメニュー名を表示。空欄が基本、TRAININGのみ既存シーンに入るボタンを維持。
- SYSTEM／DATA ARCHIVE右パネル、TRAINING／DEPLOYMENT／CUSTOMIZE左パネル。設備とパネルは画面投影上2～6%程度重ねるが、CUSTOMIZEのセラだけは実モデル由来輪郭（剣を含む）の最左端から16pxの隙間を確保し、パネル幅を動的制限。
- 全景からの0.18秒Cubic Ease Out、右下戻る、ゲート枠のセラ遮蔽、既存明滅輪郭、ブロックベンチ設備原本、Bash／Guard_REACTION、戦闘、BGM/SEに変更なし。
- 変更：scripts/command_nexus.gd、project.godot、既存v125/v126/v127静的検査、DEVELOPMENT.md。追加：README_v128_ja.md、tools/v128_nexus_focus_panel_self_check.py。
- 720×1280の静的投影計算とソース確認を実施。Godotでの実行・Android実機表示は未実施。

## v129（2026-11-08） — カメラ平行のセラ浮遊プレビュー・左右ドラッグ回転
- 基準：GitHub main v128（0651db6a79f770689e0cb912dea3705dd1c39dee）。既存のCUSTOMIZE背景、台座、建造物、カメラ構図、左半透明メニューをそのまま使用。接近後は展示用SeraRig本体だけをカメラに対して正面・平行な手前の位置へ移動して少し拡大表示する。モデルは複製せず、保存した元のローカル変換を戻る時に復元。
- SeraRigの残像ノード解放を誘発するreparentを避け、常に元のスタンドの子として維持したままcamera.global_transformを基準にワールド変換を再設定する。カメラ・背景・ステージには変更なし。
- モデルの全身・剣・盾の投影を360°/16サンプルで一度確認し、パネル右端+18pxから画面右97%、縦28〜76.5%の範囲内へ自動フィット。左右ドラッグ中もメニューと重なりにくい全周エンベロープを確保。
- CUSTOMIZE右側領域のAndroidタッチドラッグ／PC左ボタンドラッグでモデルのY軸回転のみ変更。カメラ固定、パネル・右下戻るUIのドラッグ誤作動なし。指離しで回転停止、再選択時は正面向きへ復帰。元の選択輪郭も追従。
- 変更：scripts/command_nexus.gd、project.godot、既存の静的検査v125〜v128、DEVELOPMENT.md。追加：README_v129_ja.md、tools/v129_customize_floating_preview_self_check.py。Bash／Guard_REACTION、Blockbench原本、戦闘シーンとBGM/SEは不変更。
- 静的ソース確認のみ。Godotのパーサー検証・Android端末実機のドラッグ判定やプレビュー見え方の確認は未実施。

## v130（2026-11-08） — カスタマイズ拡大の上限緩和とNEXUSpose読込
- 基準：GitHub main v129（d9572ec82c90f6d82a55f8101f6436d47fca683b）。背景・5機能のカメラ・半透明パネル・タッチ回転・右下戻るを維持し、CUSTOMIZEでセラのサイズのみ調整。
- v129のプレビュースケール倍率上限1.55/1.05が実サイズを抑制していたため撤去。プレビュー距離4.60→3.25、初期スケール0.80→1.40、縦フィット範囲画面15%〜86%に拡大。モデルの剣・盾を含む16方向で計算した全周外形を、左パネル右端+18px〜画面右97%の安全領域内にフィットするよう更新。
- NEXUSposeがユーザーのモデルに存在する場合、同期済みBlockbenchモデルJSONを探して展示用SeraRigの既存ZYX回転・アニメーションサンプラーで最初のポーズを適用。戦闘モーションへの変更なし。GitHub mainのモデルには現時点でNEXUSposeが見つからないため、未同期の場合は従来の中立展示姿勢を維持し、同期された後の次回起動時に自動検出。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、v125-v129の静的検査。新規：tools/v130_nexus_pose_enlarge_self_check.py、README_v130_ja.md。Bash／Guard_REACTION、Blockbench元モデル、既存背景・入力・BGM/SEなど変更なし。
- 静的なコード/資産整合性検査のみ。Godotでの構文解析・Android実機の拡大／姿勢適用確認は未実施。APKでのbbmodel同梱にも別途確認が必要。

## v131（2026-11-08） — Blockbenchのポーズ実名NEXUS_poseに対応
- ユーザー提供のBlockbench画面に表示されているポーズ名は「NEXUS_pose」（アンダースコアあり）。従来v130では「NEXUSpose」（アンダースコアなし）を完全一致検索していたため、この命名差が原因でポーズ適用できなかった。
- scripts/command_nexus.gd の検索対象を「NEXUS_pose、NEXUSpose」に変更し、検出した実名のままSeraRigのアニメーション登録・0秒サンプル・展示用適用を行う。後方互換のため旧名も受理。戦闘用SeraRigやBlockbenchモデルは変更しない。
- モデルの同期は別件。ユーザー端末の GAME/Git/models/SERA_BOOSTER_allテスト.bbmodel は2026-11-08 15:32更新・約334KB、GitHubのmain上の同ファイルは13:22最終更新・約328KB。端末側でポーズを確認できてもmain上のモデルには未反映。以前のgrep NEXUSposeは検索文字列が誤っていたため「なし」と判定されていた。
- 既存のカスタマイズ拡大、左右スワイプ回転、背景、パネル、戻る操作およびBash・Guard_REACTION等の戦闘資産は維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、v125〜v130ソース検査。新規：tools/v131_nexus_pose_name_self_check.py。ソース検査のみ。Godot構文/Android実機の検証は未実施。

## Termux auto-upload safe v2（2026-11-08） — GitHub先行時に安全な自動push
- ユーザー環境で従来の ~/sera_push.sh が「CONFLICT: upload cancelled」となり、NEXUS_pose入りの端末上のmodelがGitHubへ送信されなかったことへの再発防止。スクリプトは端末上に存在しGitHubへは保存されていなかったため、tools/termux/ に安全なv2の正式ソースとインストーラを追加。
- 共有ディレクトリGAME/Gitの前回成功時のファイルSHA256＋メタデータをTermuxに保存し、それ以降に実際に追加・更新したファイルのみを列挙。GitHubの最新mainをクローンして該当ファイルだけを反映し、他の変更を上書きしない。削除自動化は引き続き対象外。
- 同一ファイルが端末とGitHubの両方で編集され内容が異なる場合は安全停止。それ以外のGitHub先行は最新main上に変更を適用。push中の他者更新は3回まで再取得し、force pushは使用しない。
- 新しいTermuxコミットは固定の安全なauthor識別子を使用し、以前起きたAuthor identity unknownを回避。inotify監視がAndroidで保存イベントを取り逃しても最大120秒ごとに内容変化を確認（無変更時は通信しない）。
- fl​​ockによる多重起動防止・端末への上書きインストール前の時刻付きバックアップ・アップロード失敗状態表示を追加。初回は安全のため既存ファイルを送らずハッシュ基準点のみ作成する。
- 追加：tools/termux/sera_push_safe.py、sera_push_launcher.sh、sera_watch_safe.sh、install_safe_sync.sh、test_safe_sync.py、docs/TERMUX_SAFE_AUTO_UPLOAD_JA.md。既存のGodotコード・Blockbench素材・プロジェクト名・戦闘モーションは変更しない。
- 本環境からAndroid端末の ~/sera_push.sh / ~/sera_watch.sh を直接編集できない。Termuxにインストールコマンドを手動で実行する必要があり、それまでは従来の監視設定のまま。Python構文やAndroid/Termux実機の動作は未検証。オフライン疑似Gitリポジトリ検査を同梱。

## Termux private repo installer fix（2026-11-08） — raw URL 404対応
- 16:35ごろ端末の導入時にcurl HTTP 404と「install_sera_safe_sync.sh: No such file or directory」が発生。GitHub shejklgaia-png/- はPrivateであり、未認証のraw.githubusercontent.comへ直接アクセスするとファイルが存在しても404となる。以前の導入コマンドが誤っていた。既存のTermux監視は旧版のままで、モデル・プロジェクトデータの破損は確認されていない。
- tools/termux/install_safe_sync.shは公開raw URLを使わず、認証済みgit cloneで取得したtools/termuxディレクトリ内のスクリプトを直接インストールする方式に修正。対象ファイル不在では旧設定を触らず停止し、従来どおり時刻付きバックアップ・構文検査・監視再起動を行う。
- docs/TERMUX_SAFE_AUTO_UPLOAD_JA.md をgit clone（Private認証対応）→ローカルインストールに修正。tools/termux/test_safe_sync.pyで未認証rawへの依存再混入を検出する検査を追加。
- GitHub側の修正のみ。端末は修正後にユーザーのTermuxで実行する必要がある。Android実機でのインストール検証は未実施。

## v132（2026-11-08） — CUSTOMIZE表示の正面拡大とDEPLOYMENTゲート遮蔽解消
- 基準：GitHub main 8a3c0e55e1e8c0d17ca715fd8355b0ebae65e682（v131表示＋NEXUS_pose同期＋Termux安全同期）。ユーザー実機画像でCUSTOMIZEのセラが小さく、DEPLOYMENTは輪郭しか表示されない症状を確認。
- DEPLOYMENT旧カメラx=8.00mは、格納庫の右壁（x=7.15〜7.75m）の外側にあり、壁がゲート本体を遮っていた。カメラを右壁・外周リブ内側のx=6.20mへ移動し、視線x=1.80m／FOV76°でゲートを左メニューの右側に映す。壁・ゲート本体・材質・ギミックは変更しない。
- CUSTOMIZEの従来の360°最大シルエットでの初期フィットを、正面姿勢の外形基準に変更。画面幅の39%を目標にし、既存の左メニュー幅に近づける。左右ドラッグでは元の拡大倍率を維持しつつ、盾や剣が左右に広がり安全領域を超える角度だけ一時的に縮小・再センタリングする。左メニューパネルとの18pxの余白、右端97%以内、縦15〜86%以内を目標とする。
- NEXUS_pose読込、同一展示Rigの再利用、元の背景／展示台、5機能選択、左右ドラッグ、右下戻る、訓練シーン遷移、戦闘シーン、Blockbench元データ、BGM／SEは維持。
- 変更：scripts/command_nexus.gd、project.godot、旧検査v125〜v131、DEVELOPMENT.md。追加：README_v132_ja.md、tools/v132_nexus_visibility_self_check.py。
- コード・ジオメトリの静的確認のみ。Godotの実行／パーサー、Xperia 1 Vでの表示・タッチ挙動は未検証。実機ではセラ正面サイズ、左右90°回転時の盾／剣クリップ、ゲートの3D表示およびメニュー重複を確認すること。

## v133（2026-11-08） — 施設選択枠のタップ即時点灯・戻る時の即時解除
- 基準：GitHub main `29ab854b2ec8f28fd9ee49b2f4e8291de72edf0e`（端末側の最新自動同期を含む）。対象：Command Nexusの選択輪郭の表示タイミング。
- 設備タップ／PCクリックを受けた `_select_target` の中で、カメラの0.18秒Tweenを開始する前に `active_target` を設定し、選択対象だけの輪郭再投影・`queue_redraw` を即時に行う。選択枠はカメラ到着を待たない。
- 右下の戻るUI、Android戻る、Escの `_return_to_overview` では、全景への移動を開始する前に `active_target` を空にして `queue_redraw` する。0.18秒後の全景到着時に解除する旧処理を廃止。
- 5種類の選択対象、v132の拡大／カメラ構図、NEXUS_pose、カメラ移動時間とイージング、通常の明滅枠、タッチ操作、Blockbenchモデル、戦闘や音声などは維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、関連検査v125〜v132。追加：README_v133_ja.md、tools/v133_nexus_selection_timing_self_check.py。
- 入力ハンドラ内の処理順序と既存参照の静的検証のみ。Godot／Android実機の描画タイミングは未検証。

## v134（2026-11-08） — 拡大セラの輪郭線を放射状シアングラデーションに置換
- 基準：GitHub main `019ec1ebc54162437a921f29f1767d544d4a9a9c`（v133＋端末自動同期）。CUSTOMIZEの拡大プレビュー中だけ、2Dの強調輪郭を非表示にする。通常のガレージ一覧にあるセラ選択枠と、他4設備の輪郭は維持する。
- カメラ子ノードの単一QuadMeshに、既存輪郭線のRGB(0.35, 0.85, 0.98)を用いたunshaded・alpha透明Spatial Shaderを適用し、セラの背後1.80mに放射状の淡い発光グラデーションを表示。画面幅60%、高さ56%程度を中心へフェードさせ、3D背景を隠さない。GPUパーティクルや外部画像は使用しない。
- セラ拡大が完了したタイミングでグラデーションの表示・輪郭非表示に切り替える。ドラッグ回転と画面サイズ変更でセラ実投影の中心を再計算して追随。戻る入力ではグラデーションを即非表示、全景到着後に通常輪郭描画を復元。v133の選択／戻る即時反応と0.18秒Tweenを保持。
- 変更：scripts/command_nexus.gd、scripts/nexus_selection_outline.gd、project.godot、DEVELOPMENT.md、旧静的検査v125〜v133。追加：shaders/nexus_customize_radial_glow.gdshader、tools/v134_customize_radial_glow_self_check.py、README_v134_ja.md。
- Godot 4.7.2安定版のQuadMesh・Spatial Shader文法を参照。コード・ファイル・状態遷移の静的確認のみで、Godotパーサ／Android描画・透過ソート・負荷測定は未実施。

## v135（2026-11-08） — CUSTOMIZE背景グラデーションの胴体中心を高濃度単色化
- 基準：GitHub main `b35780a31358d507e4c23079f247e0668e18d6fa`（v134）。ユーザー実機画像でセラ背後の放射グラデーションが薄く見えるため、中心を約胴体幅の均一なシアン色に強化し、外周の滑らかなフェードを維持する。
- 既存`shaders/nexus_customize_radial_glow.gdshader`の1枚のQuadMesh／GL Compatibility用Spatial Shaderのみを変更。中心`core_radius=0.24`、不透明度`core_opacity=0.72`、境界±0.03にし、`outer_radius=0.95`へ`outer_opacity=0.30`を滑らかに減衰させる。色RGB(0.35,0.85,0.98)とセラ背後表示位置、発光板のサイズはそのまま。
- CUSTOMIZE拡大中の輪郭非表示・回転追従、戻る時の切り替え、他の端末・戦闘・NEXUS_pose・カメラ・モデル・入力・BGM／SEには変更なし。
- 変更：シェーダー、版名、v125〜v134検査の版名とv134のシェーダー検査、DEVELOPMENT.md。追加：tools/v135_customize_glow_core_self_check.py、README_v135_ja.md。
- シェーダーの不透明度プロファイルと変更範囲を静的検証。Godotパーサ／Android端末の実描画は未検証。

## v136（2026-11-08） — CUSTOMIZEグラデーションの広域化・段差解消・胴体基準化
- 基準：GitHub main `f448aa980c8945b689cb53b76203aa36678d48b4`（v135）。端末スクリーンショットでは発光円が小さく、中心と外周の2系統の不透明度カーブをmaxで合成する設計が境界の段差を生んでいた。加えて剣を含むモデル外接矩形の中央を光の中心としていたため、胴体から左右へずれていた。
- 新シェーダーは中心半径0.34まで不透明度0.91で均一、そこから外周半径1.0まで1-smoothstepにより連続減衰（指数1.15）。従来の2曲線maxを廃止。
- QuadMeshの投影幅を画面の70%、高さ46%（720x1280では約504x589px）に設定。Chest/Torso/Waistのボーン投影平均を光の中心とし、剣・盾の向きによる偏心を解消する。背後1.80m、メニュー・カメラ・回転追従、CUSTOMIZE拡大中の輪郭非表示は維持。
- 独立した画像シミュレーションで、セラを表示しない720x1280の光分布4案を比較した後、元のスクリーンショットにセラの概略マスクを残した参考合成3案を確認。選択案の滑らかさ・広がりを目視および数値で確認した。**Godotの実描画やAndroid実機確認ではない**。
- 修正：scripts/command_nexus.gd、shaders/nexus_customize_radial_glow.gdshader、project.godot、DEVELOPMENT.md、旧検査v125〜v135。追加：README_v136_ja.md、tools/v136_customize_glow_visual_self_check.py。戦闘・モデル・音声・既存4施設は変更なし。

## v137（2026-11-08） — CUSTOMIZE静止グリッド背景・定点回転・広域ドラッグ
- 基準：GitHub main `1ddf7e99d3629479b6794474bf9c2ee280bfd585`（v136）。セラ拡大時に初期の拡大位置・倍率を確定し、ドラッグ中はY軸姿勢だけを変更。従来の回転方向ごとのスケール制限／位置補正、およびグラデーション再計算をドラッグ経路から外した。剣が横方向に広がると画面外へ一部出る可能性はあるが、定位置回転を優先。
- グラデーションは拡大時の胸・胴・腰ボーン平均位置に1度だけ固定し、回転中は背景Quadの位置・サイズ・UVやグリッドピッチを再設定しない。端末画面のサイズ変更時は確定済み正規化位置を用いた再描画のみ。背景自体はカメラの子として固定。
- shaderに暗いサイバー青（RGB 0.025,0.083,0.160）と細い青系グリッドを追加。中心へ柔らかいシアンの照りを混合し、線はfwidthでアンチエイリアス。背景と線に同一のsmoothstep放射アルファを適用し、縁ではどちらも透明。画像・Particle追加なし。
- グリッド1マスはプレビュー確定時のHead_Meshの投影幅の1/2を目安として算出し、シェーダーのgrid_cellsパラメータに設定。head_mesh未検出時のみビューポート高さ3%にフォールバック。回転時はグリッド固定。
- 操作開始／移動中の有効範囲は画面全体から左メニューパネルと右下戻るボタンだけを除外（従来の20〜80%縦制限や左側以外の余白制限を廃止）。戻るはクリック／タップ直後に従来どおり処理。
- 変更：scripts/command_nexus.gd、shaders/nexus_customize_radial_glow.gdshader、project.godot、DEVELOPMENT.md、既存静的検査の版名および旧操作仕様チェック。追加：README_v137_ja.md、tools/v137_customize_fixed_grid_self_check.py。ほかの施設・モデル・NEXUS_pose・戦闘・SE/BGMは変更なし。Godot/Android描画・入力は未検証。

## v138（2026-11-08） — CUSTOMIZEの3区画レイアウト
- 基準：GitHub main `48c3e428300c0ea0f2c33d1b5e0ca443813d91d2`（v137）。CUSTOMIZE拡大画面だけを、左上のセラ表示、左下の正方形メニュー、右端の縦長メニューの3区画へ変更。他4施設は従来のレイアウトを維持。
- HUD基準720×1280では、左下メニューをx=25〜338、y≈794〜1107pxの313px四方とし、右縦長メニューをx≈378〜695、y≈173〜1107px（約317×934px）とする。右下戻るボタンは右メニューの下に独立。左上セラ表示領域はx≈25〜338、y≈128〜691px。実際の寸法は画面比率に応じて相対計算。
- 既存のCUSTOMIZE用`focus_panel`を左下へ移し、右端に新たな`CustomizeTallRightMenu`と装飾用ヘッダーを追加。新たな設定項目は未定のため、右メニューは空のプレースホルダーとする。既存CUSTOMIZEの見出しは左下で維持。
- セラの正面初期フィットおよび固定回転の領域を左上に移し、胴体ボーン基準のグラデーション位置をその範囲内に修正。発光板は左上の表示領域に収まるよう画面幅46%×高さ42%へ変更。暗いサイバー青、頭部幅の半分程度のグリッド、回転に追従しない背景の仕様は維持。
- ドラッグ操作は両メニューと戻るボタン上を無効とし、残りの領域ではv137と同様に回転可能。戻るで右メニューを即時非表示にする。v137の0.18秒カメラ移動、NEXUS_pose、既存操作・戦闘・音声・モデルを変更しない。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、関連静的検査のバージョンおよび旧配置期待値。追加：README_v138_ja.md、tools/v138_customization_layout_self_check.py。静的・座標検査のみ、Godot/Androidの実描画は未検証。

## v139（2026-11-08） — 展示用セラの滑らかな拡大・左上への移動と下寄せ
- 基準：GitHub main `ac736335fc7a0f743ea25016cf96e6bd796a0d44`（v138）。CAMERA焦点移動0.18秒の終了後、展示台にいる同一SeraRigを左上の拡大プレビュー位置まで0.46秒のCubic EASE_IN_OUT Tweenで補間。原始展示世界変換から最終のカメラ相対世界変換へTransform3D.interpolate_withを使い、複製モデルや新シーンは生成しない。
- 初期フレームでは目的地姿勢でフィットおよび固定背景グリッド位置を計算したのち、モデルだけ展示位置に戻してTween開始。途中は再フィット・再中心合わせ・再描画用幾何計算を行わず、終了時に目標姿勢を確定してシルエットを再取得。拡大中はin_transitionで入力を一時停止し、戻る際はTweenをkill可能。
- 左上のセラ初期表示幅の目標を画面幅39.0%→43.5%、左上区画の上限を左右のメニューに干渉しない範囲で横幅97%まで使う。表示領域の下端を画面高54%→61.5%（左下正方形メニュー上端から15px程度上）へ延ばし、描画外形の最下点が追加で約10px上になるようフィットと安全領域調整を下端揃えに変更。720×1280換算で左下メニューとの距離は約25px。
- 回転中の展示モデルの固定位置・倍率、背景の非追従、グリッドの色と大きさ、左下正方形メニュー、右縦長メニュー、戻る、ほか4設備、NEXUS_pose、戦闘と音声は維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧ソース検査の版名と領域期待値。追加：README_v139_ja.md、tools/v139_customize_entrance_self_check.py。ソース順序・座標計算・補間数学のみ静的検証。Godot／Android実機によるTweenの描画確認は未検証。

## v140（2026-11-08） — 展示セラの高速移動と戻るボタンでの滑らかな格納
- 基準：GitHub main `1de7c4a09ce807e4c62bc587b82393512257f8e2`（v139）。CUSTOMIZEへの移動・拡大Tweenを0.46秒から0.28秒へ高速化。Cubic Ease In Outを維持し、急なスケール変化・瞬間移動を防ぐ。カメラの0.18秒遷移は従来どおり。
- 右下UI戻る（Android戻る／Escも同一経路）では、現在のセラの全世界Transformから展示台上の正規ローカルTransform（`sera_display_stand.global_transform * sera_original_transform`）まで0.28秒の逆補間Tweenで収納。セラが格納された後、既存の0.18秒カメラ帰還を開始する。これにより戻る入力時の即時座標リセットを廃止。
- 同一SeraRig・既存Transform3D.interpolate_with・既存Tween変数を再利用。戻る入力直後に選択枠を解除、メニューパネル/戻るボタンを非表示、`in_transition`中は別操作を受け付けない。固定のグラデーション／グリッドは移動中も追従せず、格納完了後に非表示となる。Tween終了時に`_restore_customization_preview`で表示元へ正規復帰。
- 他4設備は従来どおりカメラ帰還のみ。v139の左上レイアウト、メニュー、回転、NEXUS_pose、Blockbenchデータ、戦闘・BGM/SEは変更なし。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、既存v125〜v139静的検査のバージョンおよび所要時間期待値。追加：README_v140_ja.md、tools/v140_customize_retraction_self_check.py。
- ソース順序・関数連結・移動時間の静的確認のみ。Godot起動／Android実機でのアニメーション品質・操作・描画は未検証。

## v141（2026-11-08） — CUSTOMIZE選択直後と戻る時のセラ／カメラ同時移動
- 基準：GitHub main `a119aa7339c9125823d1b084f28e4f8838f6281d`（v140）。CUSTOMIZEをタップした瞬間、カメラの最終姿勢を一時適用してセラの拡大位置と固定背景の初期位置を計算。実カメラ姿勢とセラ展示姿勢を元に戻してから、元のSeraRigの0.28秒Tweenとカメラ0.18秒Tweenを同じタップ入力処理内で開始。旧仕様の「0.18秒のカメラ移動完了後にセラの移動を開始する」遅延を撤廃。
- `_focus_arrived`ではCUSTOMIZE用セラTweenを重複開始せず、カメラが先に着いた場合はメニューを表示するが回転や戻るの入力ロックを保持し、モデルの0.28秒Tweenが終わってから解除する。ほか4設備は従来の動作。
- CUSTOMIZEのUI戻る・Android戻る・Escでは、元展示台への格納Tween0.28秒とカメラ帰還Tween0.18秒を同一イベントで開始。カメラが先に着いた時は復帰確定を待ち、モデル格納が終わったら背景を消して全景状態を確定する。選択枠と両メニューの即時解除は維持。
- レイアウト（左上セラ・左下四角メニュー・右縦メニュー）、表示倍率、固定サイバー青グリッド・放射グラデーション、初期NEXUS_pose、ドラッグ回転、戦闘・BGM・SEは変更なし。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧テストv125〜v140の版名と旧シーケンス期待値。追加：README_v141_ja.md、tools/v141_concurrent_nexus_motion_self_check.py。ソース構造・Tweenとカメラの開始順序など静的検証のみで、Godot/Android実行テストは未実施。

## v142（2026-11-08） — カメラ後退時にセラが画面外から展示台へ出現する現象を修正
- 基準：GitHub main `ba18f3c44c28d86c2990eabc782edad18e54e830`（v141）。カメラ帰還0.18秒、セラ格納0.28秒を同時開始した状態で、セラのワールド直線補間経路と移動カメラの視野が一致せず、セラが画面外から展示スペースへ再出現していた。
- 既存`Transform3D.interpolate_with`を世界座標間の補間ではなく、遷移開始時のカメラ座標と到達先カメラ座標の間の補間に変更。開始時と終了時に`Camera3D.global_transform.affine_inverse() * rig.global_transform`からカメラ相対Transformを求め、Tween各フレームでそのカメラ相対姿勢を補間し、動いている`cam.global_transform`に掛け戻す。投影位置が開始画面と終了画面の間を推移するようにし、移動中のカメラがセラを置き去りにする経路を解消。
- CUSTOMIZE選択時は全景カメラのglobal_transformを記録し、目的カメラでのフィット計算と併せて両端のカメラ相対Transformを確定。戻る時は現在のカメラ姿勢と元展示台の世界Transform、および全景カメラ姿勢から両端を計算。場面切替・モデル複製・新規素材なし。
- セラ0.28秒、カメラ0.18秒の同時開始、格納完了時のみ全景への状態確定、既存の右下戻る操作・選択枠即時解除・3区画メニュー・固定サイバー青グリッド・NEXUS_pose・戦闘・音声は維持する。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、関連テストv125〜v141の版名と旧世界座標補間期待値。追加：README_v142_ja.md、tools/v142_camera_relative_transfer_self_check.py。
- Godot 4.7公式Transform3D.affine_inverseおよびinterpolate_withを参照。コード構造・カメラ空間での補間投影の幾何検証を実施。Godot/Android端末での実描画と壁遮蔽は未検証。

## v143（2026-11-08） — 戻る操作時の背景即時消去と画面内直線移動
- 基準：GitHub main `e7a1018005bc88508f5b36ef17599ff4fd849686`（v142）。CUSTOMIZEの戻るボタン・Android戻る・Escを受けた同じイベント処理内で、放射グラデーションとグリッドの共通MeshInstance3D `customize_glow_quad.visible=false` を設定する。従来のセラ格納Tween完了時まで背景が残る仕様を廃止。選択線解除と両メニュー非表示は維持する。
- 入場と格納の経路を画面投影座標で直線化。ワールド／カメラローカル3D点の線形補間では遠近法によって表示上の経路が曲がるため、開始時と最終のカメラFOVで各モデル原点を正規化画面（NDC）へ投影し、その2点間をVector2.lerpで直線補間する。補間した奥行きと実際の移動中カメラFOVからカメラ空間のモデル位置を復元し、cam.global_transformでワールドへ変換する。回転とモデル倍率は従来のTransform3D.interpolate_withによる補間を維持する。
- 入場は従来のカメラ開始FOVと到達FOVを使用。戻るは現在のFOVと全景FOVを使用。セラ0.28秒、カメラ0.18秒のタップ同時開始、両完了後に状態確定、通常の展示状態、左上セラと3区画メニュー、固定サイバー青背景、NEXUS_pose、戦闘・音声は維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧テストの版名と相対補間式期待値。追加：README_v143_ja.md、tools/v143_straight_motion_self_check.py。
- 静的な関数順序／投影算術検証は実施。Godot実行・Androidでの実描画・3D遮蔽の検証は未実施。直線性はモデル原点の画面上経路を指し、剣先や四肢が全区間で画面内に収まることまでは保証しない。

## v144（2026-11-08） — 添付動画を踏まえた胴体基準の直線補間
- 基準：main `8485901bc0fb4c0219da1d0e7fae32160941423f`（v143）。添付MP4（1096×2560、約6.83秒）の拡大／格納動作を確認。足元のSeraRig原点が直線移動しても、回転・倍率変化により画面上の胸／胴体が弧を描く問題を修正。
- Chest/Torso/Waistボーンのモデルローカル位置の平均を一度保存。始終点のカメラ相対TransformとFOVでその胴体点を投影し、2D座標を直線補間。奥行きと実カメラFOVから復元した胴体座標から、補間Basis×ローカル胴体位置を差し引き、SeraRig原点を補正。回転・倍率補間はそのまま維持。
- カメラとモデルは別Tweenで更新順による視覚ズレが起こり得るため、モデルの進行率／端点を保持し、カメラ更新直後にモデル位置を再計算。戻る操作時の背景即時非表示、カメラ0.18秒／セラ0.28秒同時開始、3区画メニュー、NEXUS_pose、戦闘・音声は維持。
- README_v144_ja.md・tools/v144_torso_linear_transfer_self_check.py追加、従来ソース検査の版名更新。数値的な仮想アンカー投影検証のみ、Godot／Android実機実行は未検証。

## v145（2026-11-08） — 見た目の中心を一定速度で直線移動／グラデーションは拡大完了後に表示
- 基準：GitHub main `6198ae093f7e617aea31f119d1931af58af55e9a`（v144）。動画`1000034283.mp4`（約8.14秒）をコマ分解して比較。足元原点→胸・胴体中心に変更しても、ヨー回転と倍率補間でロボットの実際の画面外接形状が変化し、見た目の中心は曲線状に移動し得る。v144では`Tween.TRANS_CUBIC`によりスクリーン座標の進行率も加減速していた。
- Head/Neck/Chest/Torso/Waist/両肩/両上腕/両前腕/両手/両腿/両脛/両足の元モデルローカルボーン位置（最大19点）を開始時に保存。剣・盾は外して、投影された胴体＋四肢の画面外接範囲の中心を算出。開始と終了の見た目の中心をスクリーン（NDC）座標で直線補間する。
- 拡大・格納の位置進行率は`Tween.TRANS_LINEAR`による一定速度、モデルの向きと倍率の補間だけは別のsmoothstep進行率を使用。投影中心の位置合わせに4回の軽い透視補正を入れ、回転中の体形変化によるセンターの横振れを取り除く。移動中のカメラ更新後も同じ補正を実行。
- 共有の背景Quad（シアン放射グラデーション＋サイバー青グリッド）はプレビュー開始時・移動中は`visible=false`。0.28秒セラ移動Tweenの終了ハンドラで最終モデル位置確定後に`visible=true`。帰還操作時はこれまでどおりボタン押下直後に`visible=false`。
- セラ移動0.28秒・カメラ移動0.18秒の同時開始、3区画レイアウト、モデルの最終位置・倍率・NEXUS_pose・既存ゲーム機能は維持。
- 変更：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、既存静的検査v125〜v144。追加：README_v145_ja.md、tools/v145_visual_center_glow_delay_self_check.py。ソース順序・モデル点集合による数値投影検証のみ。Godot/Android実機の再生は未実施。

## v146（2026-11-08） — 動画による膨張を抑止する投影サイズ上限制御
- 基準：main `aee51b16a78e42525d27ebb62e2d1fee39f6ed8a`（v145）。ユーザー提供動画`1000034285.mp4`（1096×2560、約5.4秒）で、展示⇄CUSTOMIZEの途中にセラが一時的に大きく膨らむように見える問題を確認。v145は19個のモデル骨位置の画面外接矩形中心を直線で移すが、カメラFOV・モデル倍率・奥行きが別の曲線で変わるため、矩形の幅・高さの変化を拘束していなかった。
- v146ではモデル本体の投影外接矩形`_customize_body_bounds_ndc`を開始・終了カメラFOVで求める。画面上の中心に加え、見かけの幅・高さも進行率に対して始終点の値を直線補間する。中間姿勢の投影矩形を再計測し、縦横の許容比の小さい方の倍率をSeraRigのBasisへ一様に適用することで**どちらの方向も指定した補間サイズを超えない**ように制限。重複する位置だけの4回補正を廃止し、サイズ制御→中心合わせを2回だけ実施。
- セラの画面上移動は一定速度の直線を維持。回転補間のみsmoothstepを維持し、カメラの別Tween更新後にも同じモデル調整を再実行。開始と最終モデルTransformの決定、バック時の瞬時エフェクト非表示、拡大Tween到着後のエフェクト表示を変更しない。
- セラ移動0.28秒、カメラ0.18秒の同時開始、左上モデル・3区画メニュー・固定グリッド・NEXUS_pose・ほか4施設・音声と戦闘は変更なし。
- 対象：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、旧テストの版名／補間期待値。追加：README_v146_ja.md、tools/v146_bounded_body_motion_self_check.py。
- 静的確認と19点の代表的な骨位置による独立投影シミュレーションで、往復の中間時刻の表示幅・高さが始点／終点間の補間包絡を上回らないことを確認。**実際のGodot/Android映像・高負荷動作は未検証**。

## 表示用プロジェクト名の統一（2026-11-08、v146維持）
- 基準：GitHub `main` `9f32c84ee90679d323522f74e850155b614dd4c7`。Godotのプロジェクト名の長さが毎回変わり、Androidエディターの実行ボタンの表示位置が動く問題への対処。
- `project.godot` の `[application]` `config/name` を `SERA v146 - Bounded visual transfer` から **`SERA v146`** に短縮。
- 今後は **`SERA v<連番>` のみ**とし、英語の変更内容や任意の副題は付けない。変更内容は各バージョンREADME、DEVELOPMENT.md、PRに記録。ルールを`AGENTS.md`へ明文化。
- 既存の名前文字列を検証するソース回帰テスト（v125〜v146）も新表示名へ更新し、将来の命名規則を検査する`tools/project_name_self_check.py`を追加。ゲーム画面・アセット・ゲームロジック・モデル・カメラ・アニメーションは無変更。**ゲームバージョンはv146のまま**。
- ソース文字列・変更範囲の確認のみ。AndroidでのGodotエディター表示位置は未検証。

## v147（2026-11-08） — セラの拡大・格納アニメーションを2倍速に変更
- 基準：GitHub `main` `11c788003c99401abfe91e42f7f4cdcb26bd6959`（v146）。ユーザー指示により、展示セラからCUSTOMIZE左上プレビューへの移動・拡大、戻る時の展示台格納・縮小のTween時間を**それぞれ0.28秒から0.14秒へ短縮**。速度を2倍にし、位置・スケール・角度の従来の補間方式／軌道／到達時の倍率は変更しない。
- カメラTween0.18秒は据え置き。新たにセラ移動がカメラより先に完了するため、移動Tweenの終了時に世界位置を早期確定すると画面上で跳ぶ問題を防止する。セラは0.14秒以降もカメラ相対の到着座標をカメラ更新時に維持し、カメラ0.18秒完了後に最終世界Transformを確定。拡大エフェクトも両動作完了後に表示する。
- 戻る側も同じく0.14秒で格納目標の画面座標へ到達させ、カメラ帰還0.18秒が終わるまでモデルのカメラ相対位置を保つ。最終的に元展示Transformへ戻して全景操作を解除する。戻る操作時のエフェクト即時消去は維持。
- `config/name`は命名規則どおり**`SERA v147`のみ**とし副題なし。README_v147_ja.md追加、DEVELOPMENT.mdと静的回帰テスト・命名規則テストの整合性を更新。
- 変更対象：scripts/command_nexus.gd、project.godot、DEVELOPMENT.md、関連テストの旧版名／旧秒数期待値。追加：README_v147_ja.md、tools/v147_customize_double_speed_self_check.py。Godot／Androidの実機タイミングと映像は未検証。

## v148（2026-11-08） — RUN・BOOSTの地上移動速度を1.25倍
- 基準：GitHub `main` `97a9cc63d232b215bcd88dad529af0b67b08b5cd`（v147）。ユーザー指示により通常歩行（RUN）とBOOSTの実際の地上移動速度をそれぞれ1.25倍へ増加。
- `scripts/main.gd` の基準 `MOVE_SPEED=3.25m/s` とBOOST相対倍率`1.5`を維持し、地上RUN/BOOSTの物理速度式に `GROUND_MOVE_SPEED_SCALE=1.25` を追加。RUN最大速度は3.25→4.0625m/s、BOOST最大速度は4.875→6.09375m/s。入力アナログ強度に応じた増減も同倍率。
- BOOST開始125%／解除110%・0.10秒保持・0.15秒加減速、STEP／BACKSTEP、格闘接近、カメラ、ガード、走行・BOOSTモーションの再生速度、デバッグジャンプの空中ステアリング速度は変更しない。状態表示のx1.0／x1.5は新しいRUN基準との相対倍率を示すため据え置き。
- `config/name`は命名規則どおり`SERA v148`。`README_v148_ja.md`・`tools/v148_ground_movement_speed_self_check.py`を追加。従来のCUSTOMIZE系静的検査が最新プロジェクト名を認識できるよう期待タイトルのみ追従。
- 変更は速度係数と地上移動式の限定的差分。ソース上の数値・操作条件・対象範囲の確認は可能ですが、Godot/Android端末での実走行速度・衝突時挙動は未検証。

## v149（2026-11-09） — 360°フリースワイプ移動と進行方向ロングドラッグBOOST
- 基準：GitHub main `1d217ce94687fa7743f94c01e3403b952b026dc4`（v148）。従来の固定起点アナログ式（タッチ起点との差分／168px円盤／125% BOOST境界／0.10秒確定／0.15秒加速）を廃止し、直近の指の移動差分を約6px単位でサンプリングして、360度の移動方向を即時指定。指を止めた場合は最後の方向を維持、離した時に停止。移動速度はRUN 4.0625m/s・BOOST 6.09375m/sの二段固定（v148速度設定）で、指の移動量には比例させない。
- 同じ方向へ約140pxの実ドラッグ距離が蓄積するとBOOSTに切り替え、大きく方向転換（内積<0.65、約49.5°以上）するとRUNへ戻す。新しい方向で再び約140pxドラッグするとBOOST再起動。長時間保持だけではBOOSTしない。ダメージ・ガード・空中はBOOST無効、反応終了後は新しい長ドラッグで再有効。ブースト済みジェスチャーのリリースは従来どおり回避／格闘誤爆を防止する。
- モデルの方向転換の見かけの遅延対策としてRUN方向補間0.12→0.035秒、RUN退避モード0.18→0.075秒、上体追従0.10→0.05秒、ルート回転450→1440deg/s、BOOST方向補間0.06→0.025秒に短縮。移動方向の実速度ベクトルは既存どおり即時反映、モーションのみキビキビ表示。
- `touch_overlay.gd`の168px円盤・固定矢印・ノブ・外周の125%境界を廃止し、指の少し上に追従する小型のシアン方向矢印、ブーストまでの進行円弧、BOOST時の二重シェブロンとラベルを描画。ロックオンのターゲットリング・下部操作領域のグラデーションは維持。追加画像や外部依存なし。
- タップ格闘、長押しガード、リリース時の左右／後方ステップ、空中デバッグ、トレーニング敵、BGM、カメラレイアウト、NEXUS画面、元モデル・音声は維持。プロジェクト名は命名規則に従い `SERA v149` のみ。
- 変更：scripts/main.gd、scripts/touch_overlay.gd、scripts/sera_rig.gd、project.godot、DEVELOPMENT.md、関連既存テスト。追加：README_v149_ja.md、tools/v149_free_swipe_control_self_check.py。Godot/Androidの実機入力と表示、リグとカメラの追従については未検証。

## v150（2026-11-09） — フリースワイプコントローラ表示の滑らかな追従
- 基準：GitHub main `293c9aa6e7e4e3811248512bcba1763d1a344adf`（v149）。矢印の座標・向き・BOOSTチャージ表示をタッチイベントが届くたびに直接更新していたため、イベント間隔・6px方向サンプリングによってカクカク動く問題を修正。
- コントローラの表示専用データ（指位置・矢印角度・蓄積円弧）を追加。タッチイベントでは入力目標のみ更新し、`touch_overlay.gd`の`_process(delta)`でフレームレート非依存の指数補間を使用。表示追従時定数は位置0.040秒、矢印角度0.052秒、BOOST円弧0.070秒。角度は`lerp_angle`で0°/360°を跨ぐ場合も最短方向に回す。最初の方向は即座に表示し、それ以後の変化を補間。
- コントローラを三角ポリゴンから、アンチエイリアス付きストロークと丸い端点で描く細身の方向矢印に変更。固定168px円形スティックは復活させない。指の少し上に追従する小型の円・BOOST円弧・2連シェブロン・RUN/BOOST表記・下部操作領域・ロックオン表示は維持。
- 描画ループはドラッグ中またはロックオンリングの0.20秒回転アニメーション中のみ有効にして省電力を保つ。ロックオンリングのアニメーション進行は従来どおり。
- **セラ本体の移動方向／RUN固定速度／進行方向140pxドラッグBOOST／約50°方向変更で解除／攻撃・ガード・ステップの実入力は変更しない。** 滑らかにするのは表示だけで、操作応答はv149どおり。
- 変更：scripts/touch_overlay.gd、project.godot、DEVELOPMENT.md、旧テストのタイトル検査と描画方式の期待値。追加：README_v150_ja.md、tools/v150_smooth_swipe_hud_self_check.py。Godot/Androidの実画面・実機での60fps描画は未検証。

## v151（2026-11-09） — セラ本体の方向転換を連続角度で補間しRUNモーションを同期
- 基準：GitHub `main` `f67087330220583c2f2cfe33d856af2560e0a0fb`（v150）。指の約6pxごとの指示・RUN/BOOST固定速度を維持しながら、見た目の回転・RUN/後退姿勢・上半身追従が一致せずカクつく問題を修正する。
- RUNベクトル補間`Vector2.lerp`を廃止。180°の方向転換で中間ベクトルがゼロになり、正規化時に急反転する問題を避けるため、`atan2`・`wrapf`・指数補間を使う角度ベースの連続回転に変更。方向は単位円上`Vector2(sin, cos)`で常に正規化。反対方向±180°近傍（12°幅）は過去の回転方向の符号を保持し、指の微細なゆれで回転向きが交互反転するのを抑制。見た目のみ3°デッドバンドを採用。
- RUN姿勢の補間時定数0.035→0.055秒、BOOST0.025→0.045秒、前進／後退モードのクロスフェード0.075→0.085秒。実際の移動ベクトルは`main.gd`の即時更新のまま、コントローラUIもv150の0.052秒表示補間を維持。モデルの動作と表示を近い応答時間にする。
- RUN/後退のしきい値判定を生の入力方向から**補間後の方向**に移し、前進/後退モード・クリップ混合・Waist向きの目標が単一の視覚方向に従うよう変更。RUNルート回転では退避フラグの0/1の瞬時180°切替を廃止し、連続する`run_retreat_blend`で目標角度を補間する。既存の左右利き偏り（100°/120°）、±5°ヒステリシス、1440°/秒上限、腰のバンク、顔と上半身の視線追従、4方向の著作モーションを維持。
- BOOST姿勢にも同じ最短角補間を適用する。RUN→BOOST・BOOST→RUN 0.08秒ブレンド、RUN→Wait 0.16秒、攻撃・ステップ・ジャンプ・ガード・ダメージ中のモーション禁止は変更しない。
- 変更：`scripts/sera_rig.gd`、`project.godot`、`DEVELOPMENT.md`と静的検査。追加：`README_v151_ja.md`、`tools/v151_turn_smoothing_self_check.py`。動作の視覚検証・Godot/Androidエンジン実行は未実施。

## v152（2026-11-09） — 指の生理的な揺れを想定したフリースワイプ感度の調整
- 基準：GitHub main `c6666532c09aa718eef97c414d5d57003429aacf`（v151）。v149以降の入力が各約6pxの直近の接触差分を進行方向に直接使うため、自然な指の細かな往復や斜めのぶれを瞬間的な方向転換・BOOST解除として扱っていた。
- タッチ方向は最新の単一イベントではなく**直近80msの指位置差分**を計測。通常12px以上の実移動と12°以上の角度差で方向候補を更新。40°を超える急旋回は意図確認のため20px以上の正味移動を必要とする。小さな指の揺れ（数px程度）では進行方向を更新しない。
- 入力方向のターゲットだけをイベントから更新し、物理更新中に方向角をフレームレート非依存で補間。通常の追従時定数0.055秒、65°以上の大きな方向変化には0.020秒、140°以上の明確な反転は同物理フレームで即時反映。RUN／BOOSTは固定速度のまま、方向を変えるために元の指位置まで戻す必要はない。コントローラはこの実際に反映した方向を表示し、v150の独立した滑らかな描画は維持。
- BOOSTの140px条件は維持するが、旧方式のイベントごとの移動距離の単純加算を廃止し、進行方向の開始地点からの**正味前進距離**で判定。小さな往復やノイズだけではBOOSTが溜まらない。約50°以上の明確な方向変更、被ダメージ、ガード、空中では従来どおりBOOSTを解除して基準点をリセット。
- タップ攻撃と18px判定、0.32秒ガード、リリース時のフリック回避、BOOST終了後の誤爆防止、セラ本体v151モーション、RUN/BOOST速度・視覚エフェクト、NEXUS画面は変更しない。
- 変更：`scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`、関連静的検査。追加：`README_v152_ja.md`、`tools/v152_thumb_steering_self_check.py`。コード差分と方向フィルター／BOOSTの独立計算のみ。実際のGodotエディター・Xperiaタッチ感度は未検証。

## v153（2026-11-09） — コントローラ操作をv148の固定式アナログスティックへ復元
- 基準：GitHub main `4542e2956abc7d604459835d2952fa7218bf5677`（v152）。ユーザーの指定によりv149〜v152のフリースワイプ操作、ロングドラッグBOOST、指の軌跡フィルター、および専用HUDを取り消す。
- `scripts/main.gd`と`scripts/touch_overlay.gd`のみv148 main `1d217ce94687fa7743f94c01e3403b952b026dc4`の内容へ復元。指を置いた地点を中心にした半径168pxのアナログスティックを使用。移動方向・入力強度は起点から指へのベクトル、100%半径でRUN最大速度、125%以上を0.10秒維持してBOOST開始、110%未満で即解除。BOOST速度は0.15秒で補間。ブースト時ノブ表示148%。
- v148で適用済みの地上RUN・BOOST移動速度1.25倍（RUN最大4.0625m/s、BOOST最大6.09375m/s）は維持。セラ本体のv151滑らかな角度補間は`scripts/sera_rig.gd`を変更せず保持。NEXUSメニュー、カメラ、モーションデータ、BGM、攻撃・ガード・フリック回避・デバッグジャンプは変更しない。
- プロジェクト名は`SERA v153`に更新。v149〜v152のスワイプ専用静的検査は過去バージョン向け資料として残すが、v153の受け入れ検査対象から除外。
- 確認：v148と同一の操作コード／表示コードへの復元、GitHubの変更ファイル検査、および`tools/v153_restore_analog_controller_self_check.py`の静的期待値。Godotエンジン・Android実機検証は未実施。

## v154（2026-11-09） — アナログスティックの高速反転入力
- 基準：GitHub main `e236c05b5473dfe26946f9ec1b95e8bed8ac5547`（v153）。通常の固定起点アナログスティックに、素早い反転のみ相対ストロークからの入力を追加する。
- 半径25%以上倒した状態で、現在の方向から約143°以上反対へ120ms以内・32px以上・平均520px/秒以上動かした場合、逆方向ストローク開始位置へスティック中心を付け替える。元の中心を指が跨ぐ前に即時方向反転。複数タッチイベントを積算して微小なノイズやゆっくりした指戻しは無視する。
- 反転時はスティックの表示中心・入力方向・BOOST境界を同時に更新。BOOST距離の判定は従来どおり125%で0.10秒、110%未満で解除、速度補間0.15秒。RUN入力強度・地上速度1.25倍は変更しない。
- タップ・ガード・リリース回避は初回のタッチ位置で判定し、反転済みジェスチャーのリリースをSTEPに誤判定しない。v151のセラ本体モーションと円形UIは変更しない。
- 修正：`scripts/main.gd`、`project.godot`、`DEVELOPMENT.md`、v153回帰検査のタイトル。追加：`README_v154_ja.md`、`tools/v154_fast_reverse_self_check.py`。Godot実行およびAndroid実機の操作感は未検証。

## v155（2026-11-09） — 高速反転の速度しきい値引き上げ
- 基準：GitHub main `2201e80f7d5fa6a84e5e3bee397370e48fd7a5da`（v154）。ユーザーの指示どおり高速反転の速度判定のみ厳格化し、`FAST_REVERSE_MIN_SPEED_PIXELS_PER_SEC` を520.0→800.0 px/秒に変更。
- 反転角度の内積 `FAST_REVERSE_OPPOSITE_DOT=-0.80`（約143°以上）は変更しない。判定時間120ms、移動距離32px、スティック半径25%条件もすべて維持。v153のアナログスティック、BOOST判定・ガード・STEP・格闘とv151の本体モーションも変更しない。
- 既存のv154回帰テストの期待バージョン・速度定数・独立計算条件をv155へ更新し、`tools/v155_reverse_speed_self_check.py`で520〜799px/秒相当の移動を拒否、800px/秒以上を許可する数値シナリオと反転角度固定を検査する。Android実機とGodotエンジンでの動作は未検証。

## v156（2026-11-09） — 高速反転後もBOOST判定領域を元の範囲へ固定
- 基準：main `49db990fc9fd3eb778ae2d9a90440efb2858bd40`（v155）。反転時に方向指定スティックの起点を移動しても、BOOSTの判定用起点`boost_pointer_origin`は初回タッチ位置を保持する。
- BOOSTは元の円の125%（210px）で0.10秒確定、110%（184.8px）未満で解除。反転時にBOOSTを解除し確認時間をリセット、元の110%内に戻るまでBOOST再発動を禁止する。誤って反転直後にBOOSTへ移行しない。
- 描画も方向指定円盤は反転後の起点、BOOST開始ガイド弧は元の起点へ分離する。角度約143°・反転速度800px/秒・32px/120msは維持し、攻撃、ガード、回避、セラ本体モーション、RUN・BOOST速度と0.15秒加減速は変更しない。
- `scripts/main.gd`、`scripts/touch_overlay.gd`、`project.godot`、履歴、回帰テストの期待バージョンを更新し、v156シナリオ検査を追加。Godot/Android実機は未検証。
