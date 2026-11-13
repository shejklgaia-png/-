## 2026-11-14 — v318リポジトリ配置の整理・不要な履歴重複の除去

- **現行の入口:** `README_ja.md`、`README_v318_ja.md`、`AGENTS.md`、`models/manifest.json`。
- **旧版ノート:** 288件の `README_vNNN_ja.md` は `docs/history/release_notes/` に保存。旧版の数値・パスはゲームの現行仕様ではありません。
- **不要な実ファイル:** 完了したGitSyncの一時プローブ3件と、同じGit blobを持つモデルの `.trashed` コピー1件を除去。モデル正本6件、歴史的な別内容モデル、`*.import` のUIDとCI履歴は保存。
- **今後の配置と削除:** `docs/SERA_REPOSITORY_LAYOUT_ja.md` にファイル別の正本、参照調査、削除判断と新規追加の置き場所を記載。
- **監査:** `tools/sera_repository_layout_self_check.py` を全件CIマニフェストに登録。既存モジュールと原本の再利用を先に検討し、原因を調べない一括削除や `main.gd`への重複実装を避けます。
- **作業順:** `sera_workplan.py` で変更候補の参照・テストを絞り、局所テストから全件CIへ進みます。Godot CIとAndroid実機の検証は別に記録します。

## v317 main.gd 第16回分割：コンパクトHUDの生成・配置（2026-11-14）
- `scripts/sera_hud_layout.gd`を追加し、上部コンパクトパネル（枠・アクセント・タイトル）、戦闘状態・敵HPバー・プレイヤーHP/ENゲージ、右側のSTEP速度・詳細・入力ヒントのノード生成、アンカー・文字サイズ・色・描画順・マウスフィルタを分離しました。
- `main.gd`の`_build_overlay`は従来の生成順に、パネル→左右持ち替え/拠点ボタン→ステータス/HP/EN→既存のその他HUD→STEP速度欄を呼び出します。戻り値の辞書は起動時のみ生成して、従来の各UI変数にノード参照を格納します。ゲーム状態の更新、ボタンイベント、ロックUIやタッチ除外範囲は従来どおり`main.gd`が所有します。
- Python静的チェックとGodot実シーンのノード階層、アンカー座標、描画順、ボタンコールバック、タッチの除外領域のテストを2件追加し、総210件をCIで検証します。SERA v317据置です。

## v317 main.gd 第15回分割：数値HUDとSTEP履歴表示（2026-11-14）
- `scripts/sera_numeric_hud.gd` を追加しました。プレイヤーHP/ENメーターの入力値、敵HPバー幅と40%配色、DEF/SHの四捨五入と切り上げ、ロック部位HP/スタン表示、STEP速度/残距離/蹴りのデバッグ/実走距離と時間の文字列と表示状態を切り出しました。
- `main.gd` は `_tick_resources` のEN/SH回復・解禁、対象パーツの名称/HP取得、`_refresh_numeric_status_hud` の更新順序、戦闘状態やUI参照を管理します。STEP中はそのSTEP開始時の速度を、非STEP時は装備補正後の基本速度を表示し、障害物に当たった場合は実走距離を表示します。敵HP 40%色の厳密な`>`と表示文言は据置です。
- 旧v250 HP・v268格闘デバッグ・第6段階EN/SHテストを移設先へ追従。新規Python/Godot実シーン各1件、総208件のCIで検証します。v317据置です。

## v317 main.gd 第14回分割：戦闘状態表示とHUD更新（2026-11-14）
- `scripts/sera_combat_hud_text.gd` にガード反応、サマーソルト・着地、ジャンプ、360° STEP方向、蹴り、通常攻撃/キック予約、DASH速度、追尾/予備動作、RUN/BOOST姿勢のHUDテキスト生成を分離しました。元の文字列・桁数・方向閾値・優先順位を維持します。
- `main.gd` は`_refresh_combat_state_hud`で状態表示の優先順位と実シーン状態、アニメ名取得、状態ラベルノードを所有し、毎物理フレーム末尾の床追従後に呼びます。実リグのクリップ名取得は選ばれた表示状態でのみ行い、不要な呼出しは増やしません。元の状態表示HUD以外、モデル・モーション・操作・数値は変えません。
- 新規Python静的／Godot実シーン各1件で優先順位・ステップ・通常格闘/刀/予約・ジャンプ・BOOSTを検証し、全206件のCI成功をマージ条件にします。ゲームv317据置。

## v317 main.gd 第13回分割：BOOST噴射保持とエフェクト更新（2026-11-13）
- `scripts/sera_thruster_presentation.gd` に最後に命令された噴射方向、後退補正係数、画面左方向の扇形を保持する3変数と、噴射エフェクト更新への最終呼び出しを移動しました。メインシーンごとに1つの`RefCounted`を常駐させ、毎フレームのDictionary/配列生成はありません。
- BOOST姿勢が表示中で指が動いている場合は3値を更新、ニュートラルなら方向・下向き補正・左扇形を保持します。実BOOSTと表示BOOSTの両方が終了した場合のみ3値をクリアします。噴射OFFでもリグへ毎フレーム更新を渡します。
- `main.gd` はカメラ・入力→地面方向、EN、実移動/衝突、格闘・追尾の噴射可否、加速バースト、ノズル実物モデルと可動範囲の責務を維持。新規Python/Godot実シーンを含む204件のCIで検証します。v317据置。

## v317 main.gd 第12回分割：背泳ぎ補正・左斜め後退ノズル演算（2026-11-13）
- `scripts/sera_nozzle_steering.gd` に、STEPの実世界移動方向優先／専用Backstep／Kick_bの下向き補正、BOOSTの入力方向・キャッシュを使う後退重み、左方向入力の強度、画面下→画面右の補間と後退割合による世界下向き復帰を純粋関数として移しました。
- `main.gd` に入力のカメラ→世界方向変換、保持ノズル方位・下向き重み・画面左扇形のキャッシュ、リグへの送信、実際のノズル角度制限・回転を維持します。左斜め後退で後退成分が優先される球面補間の順序を変更していません。
- 202件のCI（新規Python静的1件・Godot実シーン1件）で検証。ゲームv317据置です。

## v317 main.gd 第11回分割：RUNモーション方向・スラスター噴射方位（2026-11-13）
- `scripts/sera_motion_direction.gd` を追加。操作移動ベクトルをロック先の正面を基準にしたRUNモーション方向へ変換し、スラスターの基本噴射方位（実移動の逆、BOOST入力優先、ニュートラル時の保持方向、サマーソルト時の逆方向、格闘停止時の安定した後方、壁で止まった際の代替方向）を純粋関数にしました。
- `main.gd` はスクリーン→地面方向変換・実移動/衝突・ロック状態/モーション・噴射方向の保持キャッシュ・斜め後退および画面左方向のノズル補正・描画を維持します。姿勢/入力/ENや具体的な係数・しきい値は変更しません。
- 200件のCI（新規静的1件、Godot実シーン1件）で確認します。v317据置です。

## v317 main.gd 第10回分割：物理フレームの純粋判定（2026-11-13）
- `scripts/sera_physics_frame_rules.gd` に、ブースト姿勢保持0.50秒の期限と中断、ジャンプ／着地／サマーソルトの移動権、実衝突後変位からの速度計算、スラスター噴射可否と加速バーストの発火判定を分離しました。
- `main.gd` は実際のCharacterBody3D衝突、move_and_slide、step移動、カメラ・パーツロック、入力・EN、リグのモーション、エフェクト描画・描画順、残像とスラスター向きの制御を維持します。新モジュールは状態を保持せず、毎フレームのDictionary割当も行いません。
- v220通常格闘中の継続噴射を守る検査を新モジュールにも追従させ、計198件のCI（新規PythonとGodot実シーン各1件）で検証します。v317据置です。

## v317 main.gd 第9回分割：敵のライフサイクル・再出現の整理（2026-11-13）
- `scripts/sera_target_lifecycle.gd` へ、敵の移動停止条件（予兆・スタン・部位ブレイク・ダウン・KO等）、射撃許可条件、HPゼロ後の再出現待機／コンボ保持による延期／リセット判定を分離しました。状態は持たず、結果のみ返します。
- `main.gd` に`_tick_target_respawn`・`_reset_target_after_respawn`・`_update_enemy_fire_eligibility`を置き、元の物理・描画フレームで呼びます。敵の部位・頭破壊フラグ・ロック・HUD初期化を通常再出現とプレイヤーKO復旧で共用し、破壊部位のコンボ中保持・再判定0.01秒を維持します。
- 196件のCI（新規Python静的1件・Godot実シーン1件を含む）で、状態遷移順序と戦闘後の復元を検証します。モデル・操作・数値・ゲームバージョンv317は変更しません。

## v317 main.gd 第8回分割：ヒットエフェクトの寿命・表示の分離（2026-11-13）
- `scripts/sera_hit_fx_presentation.gd` に弾着時の画面フラッシュ、BODYのマテリアル発光/色、攻撃ダメージ表示のカメラ投影・浮き上がり・フェード、被弾ラベルの消去を分離しました。対象ノードを明示的に渡し、シーン探索・新規ノード生成・状態の保持はしません。
- エフェクト残時間は前段階で切り出した `sera_combat_timers.gd` の純粋減算を共用。表示順は元の`_advance_hit_fx`に保持し、BODY以外の部位演出、親メッシュ静止、コンボ中のBOSS再出現延期（0.01秒）を保護します。
- PythonとGodotの新規2テストを登録して、全194件をCIで検証します。ゲームv317据置です。

## v317 main.gd 第7回分割：戦闘タイマーの更新（2026-11-13）
- `scripts/sera_combat_timers.gd` に戦闘ウィンドウ、スタン・部位ブレイク、ダウン・ガードブレイクの残時間計算と、スタン終了後のゲージ自然減衰を分離しました。毎フレームのDictionary割当を避け、floatで計算します。
- `main.gd` に`_tick_combo_window_timers`と`_tick_target_recovery_timers`を設け、元の`_physics_process`の位置から呼びます。KO早期return、EN/SH更新→スタン更新→敵攻撃許可、デバッグ表示期限、ダウン解除時の復旧を維持します。
- v317据置、CI登録192件（新規静的1件・Godot実シーン1件）。Android実機の見た目は未確認です。

## v317 main.gd 第6回分割：EN・シールドの純粋な状態計算（2026-11-13）
- `scripts/sera_resource_rules.gd` にEN消費の可否と残量計算、回復待ちタイマー減算、ENとSHの回復演算、60％のEN再使用解禁条件を分離しました。
- `main.gd` に現在値、EN枯渇時の点滅・演出、BOOST枯渇寸前の特殊処理、ガードブレイク/ダウン等の時間順序、HUD更新を保持します。24EN/s、16SH/s、0.25秒待機、0.0001の判定幅と60％解禁を変えずに渡します。
- 登録CIテスト190件（新規静的1件・Godot実シーン1件を含む）で検証します。v317据置です。

## v317 main.gd 第5回分割：RUN/BOOST状態遷移の純粋計算（2026-11-13）
- `scripts/sera_boost_state.gd` にBOOST開始の確認時間とヒステリシス、0.20秒のRUN/BOOST速度補間と途中反転・リセットを分離しました。
- `main.gd` は入力資格とEN消耗・回復、実際の変数、Touch UI表示、アニメーション、移動速度と既存関数を保持します。BOOST倍率は装備から現行の計算で渡します。
- 実シーンでBOOSTの確認・保持・離脱、ENによる停止、速度補間途中反転を確認するGodotテストと静的テストを追加し、登録188件の全件CIで検証します。v317据置です。

## v317 main.gd 第4回分割：カメラ射影・STEP旋回の純粋計算（2026-11-13）
- `scripts/sera_camera_framing.gd` に安全なカメラ半径の射影不等式とSTEP時の目標相対Yaw制限を分離しました。
- `main.gd` の元のメソッドを維持し、Camera3D.nearや現在Yaw・既存定数を渡します。カメラ状態、画面端補正、ズーム処理、衝突・描画は変更していません。
- v232/v285の旧テストを新モジュールでも同じ数式を検証するよう調整し、新規静的/Godot実シーン検査を追加。全件CI成功を統合条件とします。v317据置です。

## v317 main.gd 第3回分割：戦闘状態の判定（2026-11-13）
- `scripts/sera_combat_flow.gd` にガード開始判定、コンボ・Bashの追加入力ウィンドウ、部位ロック保持判定、カタナの2段／通常3段のクリップ選定・キャンセル時刻、各追尾状態のdeltaクランプを抽出しました。
- `main.gd` は入力順・state更新、combo_queued/strike_index等の実際の状態、EN消費・物理追尾・モーション・打撃判定を引き続き所有します。純粋ルールの一部を動かす安全な分割であり、戦闘状態の所有者を移した全面移行ではありません。
- 新規 `tools/v317_combat_flow_runtime_check.gd` と静的テスト、全件の既存回帰テストを通してから統合します。
- ゲームバージョンはv317のままです。

## v317 main.gd 第2回分割：ロック計算
- `scripts/sera_lock_management.gd` に、自動ロックのセラ起点・平行2線判定、手動ロックの画面X座標順と端での折り返し、部位への水平向き、画面端のレティクル位置計算を独立化しました。
- `main.gd` は従来の関数名を保持。攻撃・コンボ中のロック保持、AUTO/MANUAL切替、確定したロック状態、HUDへの表示指示は従来通りです。
- 新規の静的/Godot検査で、新モジュールと本体ラッパーの双方、BODY空文字・ヘッド/脚部・自動取得・手動切替・背面非表示を確認します。
- モデル、入力仕様、ロックの0秒取得、ゲーム版v317は変更しません。既存のユーザー実機確認結果を基準にします。

## v317 main.gd 第1回モジュール分割
- `scripts/sera_input_gestures.gd`: RUNアナログ入力、STEPの360°認識、左右STEP、コンボ蹴り方向、上フリック判定、画面内タッチ判定。main.gd側は設定値を渡す薄いラッパーに変更しました。
- `scripts/sera_movement_math.gd`: カメラ向きからXZ移動ベクトルへの変換、ロック対象正面に対するステップ姿勢方向の数学処理。カメラ・プレイヤーの取得自体はmain.gdが担当。
- 通常のRUN・BOOST・蹴り・ステップの入力優先順位、キャンセルや加速度、移動距離、各種Stateはmain.gd側に残しました。Godotランタイム検査で両モジュールを実行します。
- Godot既存テストの参照箇所が変わった場合は、旧仕様の検査を除去せず新ファイルの同じ演算を引き続き検査してください。ゲーム版はv317据置。

## Android実機の問題再現（v317）
`docs/SERA_ANDROID_DIAGNOSTICS_ja.md` を参照。トレーニング画面のDIAG: OFFをタップすると診断パネルが表示され、再現後にCOPY LOGでクリップボードへ最大500行をコピーできます。普段はOFF（採取も保存もしません）。CIテストの重複/未登録候補は `python3 tools/sera_ci_inventory.py --json` で確認できます。

## AI関数索引（v316開発基盤追加）
- `python3 tools/sera_function_index.py --query camera --json` は現行スクリプトから関数の開始行・終了行、静的な関数名候補、`call("...")` による動的呼び出し名、リソース参照を抽出します。動的参照の実体が一意に決まるとはみなしません。
- `sera_workplan.py` の関数結果にも `end_line` を付与し、GitHubの行範囲指定取得を容易にします。
- `scripts/sera_camera_math.gd` はカメラ追従位置・指数補間と最大追従誤差・肩越しYawだけの純粋数学です。`main.gd` は現在の補間済み位置・状態と各パラメータを渡すだけです。既存の物理・カメラ安全フレーム・UIの処理は移動しません。

# SERA — 安全な高速開発ガイド（2026-11-11）

この文書は **開発エージェント・Codex・ChatGPT向け** の入口です。機能仕様そのものを変更する指示ではありません。現在値は必ず最新の GitHub `main` の実装から取得してください。

## v316 AI高速作業ルート（2026-11-13）
- 入口は短縮版 `AGENTS.md` と `python3 tools/sera_workplan.py --query <機能> --json` です。全文の旧AGENTS規則は `docs/history/AGENTS_THROUGH_V316.md` に保存し、必要な時だけ参照します。
- 変更ファイル名だけ分かる場合は `--changed scripts/sera_rig.gd`、機能が分かる場合は `--query katana` を併用し、全体が関係する巨大ファイルでも検査対象を絞って調査してください。
- 開発中の局所確認は `--execute` で登録済みPython回帰テストのみ選択実行できます。Godotは `--godot <binary>` も指定した時のみ局所実行。**PR上では必ず既存の全170件以上の共通CIを実行**します。
- 変更直後に古いCIが失敗した場合は `docs/SERA_ACTIVE_CI_POLICY_ja.md` に従い、意図して更新した仕様と実不具合を分けてください。

## 真実の参照先と優先順位
1. 最新の明示的ユーザー指示と、実機で確認された挙動
2. 現在の `project.godot`、関連する `scripts/`、`scenes/`、`assets/` とモデル原本
3. 現行バージョン `README_vNNN_ja.md`、`DEVELOPMENT.md`、機能別ドキュメント
4. 過去バージョンのREADME・記録（**履歴としてのみ**）

バージョンは `project.godot` 内の `config/name="SERA vNNN"` から自動取得します。READMEやコメントが将来バージョンに先行している場合、理由を確認してから変更します。**勝手にバージョンを進めて差を隠してはいけません。** なお、2026-11-11 の最終照合では `project.godot` と `README_v245_ja.md` の両方が v245 でした。これは当時の確認結果であり、今後の改修では必ず現行コミットを再確認してください。

## 2026-11-13: 現行仕様と履歴テストの分離（優先）
- `docs/SERA_ACTIVE_CI_POLICY_ja.md` と `docs/SERA_MODEL_SOURCES_ja.md` を参照。v316のモデル正本は `models/manifest.json` を参照し、旧ファイルは履歴検査用として扱います。
- `python3 tools/sera_dev_index.py <term> --json` で関連コード・モーション・リソース・テストを特定し、実装を確認する。
- STEP/蹴りの承認済み仕様を変更するPRでは `tools/sera_active_specs.json` を更新する。古いvNNNテストの数値期待値は現行仕様を参照する。不変条件は継続して保護する。
- テスト失敗を機械的に無視しない。共通CI全件成功をマージ条件とする。

## 作業の最短経路
1. 最新 `main` SHA、オープンPR、作業対象ファイルを確認します。同一ファイルへの並行編集・Android側の未push変更を推測で上書きしません。
2. `python3 tools/sera_code_map.py <検索語>` で関係する関数を絞ります。例: `camera`、`boost`、`lock`、`step`、`nozzle`。定数も必要なら `--include-constants`、AI処理用なら `--json`、巨大ファイルの優先調査は `--summary` を使います。これは**参照索引のみ**で、実装の構造は変えません。
3. 関連関数、呼び出し元、状態遷移、モデル/シェーダー契約を確認して、最小差分を実装します。先に関連テストを把握します。
4. `python3 tools/sera_quick_check.py` でベースの読み取り専用静的検査を実施。3D描画なら `--render` を追加します。続けて関連する `tools/vNNN_*self_check.py` を明示的に実行し、PR側の既存CIを確認します。
5. 差分に無関係な変更がないこととテスト結果を確認してからPRをマージします。失敗・衝突時は強制マージしません。端末側テストは **mainへのマージと同期後に別途実施** します。

## 機能 → 調査の入口（関数行番号は変動します）
| 対象 | 主な入口 | 追加確認 |
| --- | --- | --- |
| タッチ入力・RUN/BOOST・フリックステップ | `scripts/main.gd` の `_input`、`_begin_drag`、`_change_drag`、`_end_drag`、`_update_boost_gesture` | `scripts/touch_overlay.gd`、v243/v244テスト |
| コントローラーの表示 | `scripts/touch_overlay.gd` の `show_drag`、`_draw_analog_controller` | `scripts/main.gd` の入力半径・判定条件 |
| カメラ追従・近接・画面端の揺れ | `scripts/main.gd` の `_place_camera`、`_camera_radius_for_safe_point` | v229〜v234カメラテスト |
| ロックオン・部位破壊 | `scripts/main.gd` の `_switch_lock_screen_direction`、`_update_target_marker_projection` | `scripts/target_parts.gd`、v237/v242/v243テスト |
| 格闘・ガード・追尾 | `scripts/main.gd` と `scripts/sera_rig.gd` の `start_melee_approach` 等 | `docs/SERA_COMBAT_DEFENSE_ENEMIES.md` |
| スライド・IK・接地・装備 | `scripts/sera_rig.gd`、`scripts/sera_equipment.gd` | `docs/MODEL_PART_WORKFLOW_ja.md` |
| 背面スラスター・帯状軌跡 | `scripts/back_thruster_fx.gd` の `set_exhaust` | `docs/RENDER_PIPELINE_POLICY_ja.md` とv223〜v225テスト |
| NEXUSとカスタマイズ | `scripts/command_nexus.gd` | 保存設定・装備プレビュー・バージョン表記 |

補足: ChatGPT単独開発の追加監査は `docs/SERA_AGENT_MAINTENANCE_ja.md` を参照してください。

## 安全の境界
- **2026-11-11の開発ツール最適化では**ランタイムを変更しませんでした。v316のモデル/モーション読込変更は別案件であり、現行正本規約に従います。
- 静的検査はGDScriptの実行・描画・タッチ・パフォーマンスの証明ではありません。実機未検証を明示します。
- 既存の検査は削除・弱体化せず、既存CIのベース検査を共通ランナーへ統合しました。新規の自動ワークフローやジョブは作りません（既存CIに新ツールの自己検査は追加されます）。
- 今後の安全な段階的改修候補: コントローラー寸法の設定集約 → カメラと入力の責務分割 → 再現可能な実機デバッグ表示。**挙動変更の可能性があるため、このPRには含めません。**

## 2026-11-12 — 回帰検査の並列化（CI）

- GitHub Actionsの共通CI `.github/workflows/sera-model-policy.yml` は、既存の103件のPython静的検査と21件のGodot実行検査を `tools/sera_ci_suite.py` から実行します。各検査は**独立プロセス**で、テスト自体のコードや成功基準は変更していません。
- 検査一覧の正本は `tools/sera_ci_manifest.txt` です。新しい静的テストを追加した場合は `py tools/xxx_self_check.py`、Godot実行テストは `gd tools/xxx_runtime_check.gd` の形式で必ず追記してください。manifestに追加し忘れるとCIでは実行されません。
- 履歴テストを勝手に削除・スキップしないでください。全件を実行し、ひとつでも失敗・欠落・タイムアウトすればCI全体を失敗とします。各テストのログ・時間・失敗一覧はActionsログとStep Summaryから確認できます。
- Pythonは4並列、Godotは3並列を既定としています。Godotはアセットを一度インポートした後、**プロセスとuser://相当のデータ保存先を分離**して実行します。端末上の挙動がこの検査だけで保証されるわけではありません。
- ローカルからの静的検査例：`python3 tools/sera_ci_suite.py static --workers 4`。Godotはインポート済みなら、`SERA_GODOT_BIN=/path/to/godot python3 tools/sera_ci_suite.py godot --workers 3` で同一スイートを実行できます。
- 共通CIの実測（GitHub Actions、同日）：変更前66秒 → 変更後34秒（約48%短縮）。今後のGitHubランナー・テスト増加・キャッシュ状態によって変動します。
