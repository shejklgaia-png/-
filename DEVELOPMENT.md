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
