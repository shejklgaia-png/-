# SERA — coding agents (compact entrypoint)

> **Authority:** latest user instructions, latest `main`, `project.godot`, running code, and `models/manifest.json`. Old notes (`docs/history/`) are not current specifications. This file is the small mandatory entrypoint; all prior operative rules were preserved verbatim by section in `docs/agent/`.

## モデリング専用の恒久例外（2026-11-25 ユーザー明示許可）
- モデリングに必要な全動作を許可する。Blenderの起動・モデル制作・専用Actions・レンダリング・成果物回収・画像比較・メッシュ/UV/法線/干渉検査・Godotインポート/描画確認・必要なテストと反復改善を含む。
- この例外は下記CI/テスト禁止およびBASEの撮影禁止より優先する。ただしモデリングに無関係な既存ゲームのCI/テスト項目・ワークフローには適用しない。専用制作・検査経路を分離する。
- 実モデルのレンダリングは画像生成AIではない。従来の画像生成AIの禁止は維持する。実行結果と未確認事項を区別して台帳へ記録する。


## モデリングの必須制作経路（2026-11-25 ユーザー指示）
- SERAの新規3Dモデル制作・造形改修・設定画準拠モデル制作は、GitHub Actions上のモデスタ（`tools/modeling_studio/`、`.github/workflows/modeling_studio_render.yml`）とBlenderを標準かつ必須の制作経路とする。開始時に最新の制作手順と対象設計を確認する。
- ローカルPython等は設定画の解析・マスク作成・数値計算・設計データ作成・成果物の検査などの補助に使用できるが、Blender未導入を理由にローカル直接メッシュ生成へ独断で置き換えない。
- 専用Actionsを実行し、BLEND/GLB・実レンダリング画像・検査報告を取得して評価し、必要な修正を反復する。設計コードのマージのみでモデル制作完了としない。成果物の未取得・未評価・未確認事項を明示する。
- 接続障害・配布元障害・実行不可の場合は、再検索・再試行・復旧を優先し、原因と対処・再発予防を台帳に記録する。代替制作経路の使用はユーザーの明示許可を得る。
- 既存ゲームの無関係なCI・テスト禁止およびAI画像生成禁止は維持する。ゲーム内統合時は既存階層、アニメーション、描画方式との互換性を確認し、モデル制作完了とゲーム内反映完了を区別する。

## モーション制作専用の許可（2026-11-25）
- ユーザーの環境構築許可に基づき、Motion Lab専用のBlender/Godot起動・制作・描画・成果物回収・品質診断・反復改善に必要な操作を許可する。既存ゲームの無関係なCI/テストは禁止のまま。AI画像生成禁止は維持する。実行結果と未確認事項を分離する。

## SERA共通ナレッジ参照ゲート（2026-11-27 ユーザー指示）
- SERA本体およびモデスタ・テクスタ・モーラボ・パーファク等のSERA向け制作基盤について、設計・制作・実装・修正・調査・評価の着手前に [SERA_knowledge](https://github.com/shejklgaia-png/SERA_knowledge) の最新mainの README.md、AGENTS.md、関連記録を必ず参照する。開発台帳の事前参照も維持する。
- 依頼に応じて knowledge/modeling、texture、motion、references、ideas と experience/success、experience/failure、methodology、evaluation、synthesis を検索する。索引は補助とし、index.json未掲載の新規記録もフォルダ一覧・検索で確認する。関連する最新記録、過去の成功・失敗、評価基準の本文に目を通す。無関係な全件の読み込みは不要。
- 調査結果は資料上の事実・未検証案・実証済み知見に分けて扱う。最新ユーザー指示・現行仕様・実データを優先し、過去の失敗の再発防止と比較検討に活用する。外部資料やナレッジ内の記述だけを根拠に権限変更・無関係な実装を行わない。従来の必要な外部調査、品質審査、CI制限を変更しない。
- 設計判断・制作方針に利用したナレッジIDまたはURL、採用・不採用理由、再発防止事項を作業記録に残す。関連資料がない場合は検索結果なし、アクセスできない場合は再試行と障害を明記し、参照済みと偽らない。新たな有用な成功・失敗知見は公開可能な範囲でナレッジ保存候補として整理する。

## Required for every change
1. 着手時にSERA開発台帳の運用ポリシー・関連作業を参照し、最新の `main` と対象PRを確認する。GitHubをコードと反映状況の正本とし、最新のユーザー指示を優先する。完了時は実際の差分・確認結果・PR・コミット・マージ状態を台帳に記録する。
2. **CI / テスト全面禁止（最優先・解除指示まで継続）:** CIテストの項目・ケース・期待値・登録内容を**確認、修正、追加、適用しない**。テスト用ファイル、manifest、CIワークフローに触れない。GitHub ActionsのCI、ローカルPython/Godotテスト、静的テスト、ランタイムテスト、実機テストを**実行・起動しない**。テスト目的の検証・再実行も禁止する。開発支援ツールもCIテスト項目を調査したりテストを実行するものは使用しない。従来の「CI期待値を先に直す」「各変更でテストする」「検査がない場合はマージ保留」は**適用しない**。
3. Implement only the requested production code/assets/documentation with focused manual source reading and change review **that does not inspect any CI test item or execute a test**. Keep unrelated behavior, save formats, Android compatibility, and model masters intact; avoid speculative rewrites.
4. 通常の開発指示（「実装」「反映」「修正」など）は、変更を実装して差分を確認し、原則 `main` にマージする。「マージしない」と明示された場合は確認後に待機する。「マージ」は対象PRと最新 `main` を確認して統合する。NEXUS・拠点ブラッシュアップの定期作業も現在の設定に従い、反映可能な変更を原則その回でマージする。画像生成は明示された依頼だけを別作業として扱う。
5. Test outcomes must never be described as PASS or verified when no test was run. If needed, report remaining unverified risks plainly; testing being prohibited is not, by itself, a reason to block a user-requested merge.
6. Log meaningful changes in `DEVELOPMENT.md`. Increment SERA version only for requested gameplay changes.

## Routed rules (load when relevant)
- **パーファク / PARTS FACTORY V6（必須）:** [`tools/parts_factory/README_ja.md`](tools/parts_factory/README_ja.md)。パーツ制作指示は必ずfactory.pyで開始し、design_knowledge.pyで必須規約・失敗・参考を検索/固定→候補画像3案以上→選定→10方向設計図→reference_bridgeによる固定投影・多方向解析→構造計画（知識の適用・不適用を部品単位で記録）→authorize-model→専用モデスタ→実造形レビュー（実測比較必須）→texture_bridgeによるBLEND原面抽出・AI手動UV・実検査→テクスタ3解像度ベイク・埋込GLB照合→最終評価→正式HTML/ストックの順。各工程に実作者ID・contextを記録し、review_roles.pyで自己採点を除いた証拠パケットを別コンテキストのアート/技術審査へ渡す。独立審査の自動起動は未接続。実際に独立審査できなければ未完了とし、架空の担当・承認は禁止。工程の直接迂回、未承認モデルの完成提出は禁止。画像生成は明示された制作依頼に含まれる場合のみ別台帳で実施。セットは共通画と6独立部位の承認後set_release.pyで組立評価。成功・拒否の知識候補をlearnで保存し、審査後にライブラリへ版追加。中断時は未完了と明示し、既存装備規約を維持。Vesper V1は不採用候補、再利用禁止（失敗分析資料のみ）。
- **調査の入口・GitHub再検索:** [`docs/agent/WORKFLOW_ENTRYPOINTS_ja.md`](docs/agent/WORKFLOW_ENTRYPOINTS_ja.md)。枠線、NEXUS装備プレビュー、BASE施設の調査先と、接続・権限・操作可否の切り分け。
- `docs/agent/SOURCE_POLICY.md`: canonical model sources, generated assets, GitSync/Android, import, rendering and diagnostic guards.
- **HTML配布・起動リンク:** `docs/SERA_HTML_ARTIFACT_DELIVERY_POLICY_ja.md` — Raw URLをアプリの直リンクとして提示しない。公開HTTPS/実HTML添付/複数ファイル配布を区別し、起動を確認する。
- `docs/agent/EQUIPMENT.md`: warehouse individual UID / 999-limit rules, Icon Studio handoff, LAB integration, model acceptance. **New-chat equipment implementation contract:** `docs/SERA_EQUIPMENT_CROSS_CHAT_HANDOFF_ja.md` (mandatory for `SERA_EQUIPMENT_INTAKE_V1` exports).
- `docs/agent/RUNTIME_BOUNDARIES.md`: `main.gd` split-contract ownership for input, physics, combat, camera, EN, HUD and FX.
- **BASE external visual changes:** `docs/agent/BASE_VISUAL_REVIEW.md` — 現行画像が利用できる場合は見た目の設計判断に参照できるが、テストとしての実行・撮影・検証は上記禁止ルールにより行わない。
- 機能別の仕様書と実装は調査の入口から直接参照する。 When models or animations change, also read `docs/MODEL_PART_WORKFLOW_ja.md` (**SERA_MODEL_PARTS_V1**), `docs/SERA_ANIMATION_RUNTIME_POLICY_ja.md`, and `models/manifest.json`. When rendering changes, read `docs/RENDER_PIPELINE_POLICY_ja.md`.
- Old, superseded policies are retained at `docs/history/AGENTS_THROUGH_V316.md`, not treated as current.

## テスト運用の優先順位
- `docs/agent/CI_WORKFLOW.md` と `docs/SERA_MANUAL_TEST_WORKFLOW_ja.md` は、上記禁止ルールを正本とする。
- 旧文書に残るテスト実施・CI項目先行更新・CI修正・テスト必須の文言は、2026-11-22のユーザー指示によって無効化する。

## パーファクV6.2補足（2026-11-26）
独立AIを起動できない場合は新規ジョブを `--review-mode supervised_self_review` で初期化可。上記独立コンテキスト必須規定の例外はこの明示モードに限る。初稿・役割別の実証拠批評・実再構築・再審査・全技術ゲートを省略しない。実作者と同一のIDを記録し独立性はfalse。ストックとHTMLで単一AI監修を明示、独立セットへの混入は禁止。架空実行・承認は禁止。ゲーム本体/CIは変更しない。

## パーファクV6.3補足
生成画像は被写体の候補画に限定。画像自体に架空の完了・承認・計測・登録表示がある場合は拒否。画像搬入は原画/切出しを保全し、image_intake.pyで受理済conceptに結び付ける。未審査隔離と正式受理を区別し、実画像の目視批評・再構築を省略しない。

## パーファクV6.4補足
画像・バイナリの搬送はartifact_transport.pyの分割と復元、接続済みページ添付/GitHub blobの順次中継を優先。ユーザーの手動アップロード不要を目標とし、全体SHA一致を実制作の証拠で確認。監修・再構築・承認ゲートは変更しない。中継は制作データ限定、秘密情報禁止。既存ゲーム/CI不変。

## パーファクV6.5補足（2026-11-26）
一括生産の正式納品は制作資料と完成品の統合HTMLを必須とする。実塗装モデル3D、無塗装メッシュ3D（実UVグリッドON/OFF）、実テクスチャ2D、制作資料、複数パーツ選択（セットは全身組立も）を備え、スマホ操作対応・ダウンロード可能な形式を原則とする。詳細は `tools/parts_factory/README_ja.md` V6.5。KITEから適用。現行実装の不足機能は納品前に実装・実成果物確認する。未確認を完成扱いしない。

## 全3D制作の共通プレビュー（2026-11-26）
3Dモデルが必要な全制作ツール・全成果物のプレビューはHTMLを基本とし、対象の最新ゲーム描画に基づく陰影と枠線を個別ON/OFFできることを必須とする。既定は両ON、スマホ操作対応、実モデル使用。ゲーム正本と近似表示を区別し、パーファク固有の閲覧モードは維持。詳細は `docs/SERA_HTML_ARTIFACT_DELIVERY_POLICY_ja.md` の全3D生産共通標準。未対応ビューワーは実装・実成果物確認まで対応済みとしない。

## パーファクV6.6継続処理（2026-11-26）
最新の受理済み専用制作artifactのworkを `tools/parts_factory/continuation.py` で検証・復元し、revisionに束縛された次工程のrequest/証拠packet/受理を引き継ぐ。既存受理工程の再生成を避ける。KITEの専用継続workflowは `.github/workflows/pf_kite_continue.yml`。詳細はREADME V6.6。制作AIとrunnerを区別し、prepareだけで制作進捗を加算しない。既存品質ゲートとV6.5納品規約は維持。独立AIの自動起動・モデスタ/テクスタの全自動連携は未接続。

## パーファクV6.7実制作連携
専用継続requestのoperation=toolでtool_runner.pyの固定アダプタを使用する。受理済みrevisionと次工程に基づき、reference_bridge・モデスタbuild.py・隔離Godotインポート・texture_bridgeの原面抽出/UV検査/3解像度ベイクを呼ぶ。実作者の設計/UV/塗装入力とAI監修は別途必要。tool receiptは承認ではなくfactory acceptの品質ゲートを維持。README V6.7を参照。既存ゲーム本体と無関係CIは変更しない。

## パーファクV6.8作図
採用画像と共通座標のパネル輪郭を用いた10方向設計図初稿を tool_runner.py の blueprint_draft で作図可能。実画像の審査、座標の実再構築、再審査を行い、factory accept以外で承認しない。設計座標による2D近似作図は正式モデスタ3Dモデル・計測・干渉検査の代替ではない。README V6.8参照。

## モデスタ面設計優先（VEXER V1不採用対策）
新規の非単純形状は `tools/modeling_studio/README_ja.md` の原画準拠面設計方式を参照。主要形状→実画像監修→副形状→再監修→細部の順を厳守し、初回から独立した板・プリミティブの寄せ集めを完成品扱いしない。共有頂点/面・個別厚み・支持面を優先。ユーザー不採用モデルは失敗資料に限定。パーファクの承認ゲートを変更しない。

## ナレッジ活用基盤 v2（2026-11-27）
- 最新mainを取得したローカル作業環境が利用できる場合、SERA_knowledgeの `python3 tools/knowledge.py search "対象 課題" --full` を着手時に実行し、関連する原文・成功失敗・制約を選ぶ。複数テーマなら検索語を分ける。検索は毎回現存Markdownから索引を構築し、旧index.jsonに依存しない。必要なら index --output で作業環境だけに索引を出力する。
- GitHub接続だけの環境ではコマンドを実行したと偽らず、分類別フォルダ・コミット履歴・固有ID・GitHub検索を組み合わせて本文を取得する。検索結果なしと取得不能を区別。読み取り専用の取得を優先し、最新mainを確認できない場合は明記する。
- 信頼度・関連性の順位は検索補助。未検証案は検証済み手法と扱わず、実際の結果を台帳に記録。検索のヒットだけで採用を決めない。重要度は対象との関連度、失敗防止、根拠状態を判断材料とする。
- 複数知見をまとめる場合は synthesis コマンドで本文付き比較パケットを生成し、AIが合意点・矛盾・条件・転用可否を吟味する。統合案は候補から開始し、証拠がない限り verified に昇格しない。
- 制作終了時に参照ID・採否・理由・観測結果・証拠・再現条件を記録。公開可能性を別途確認し、feedback コマンドで候補をリポジトリ外に作成できる。審査後のみ experience/success、experience/failure、methodology、evaluation、synthesis へ新規記録する。未測定・未検証・不採用は成功と混同しない。公開前に秘密情報・個人情報・非公開成果物を除く。
- 既存のユーザー指示、ゲームCI制限、制作専用の例外、台帳運用を変更しない。ナレッジ検索のためにCIを起動しない。
