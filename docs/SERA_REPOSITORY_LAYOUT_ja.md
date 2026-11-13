# SERA リポジトリの配置・整理規約（v318、2026-11-14）

## 基本原則

- **稼働中のファイルをファイル名だけで未使用と判定しない。** Godotの `res://`、`preload` / `load`、シーンの `ext_resource`、Androidで生成されるモデル、動的読込、CIのファイル参照を確認します。
- **唯一の編集元（正本）を維持する。** `models/manifest.json` の6ファイルが現行のBlockbench編集原本。似たモデル名、同じバイト列、履歴ファイルがあっても正本を勝手に差し替えません。
- **一時ファイルと履歴を分ける。** 完了済みの同期確認マーカーは削除可能。旧版のREADME、歴史的なモデル・キーフレーム、現行CIは検証資産なので、無断で削除しません。
- **新しいスクリプトを追加する前に既存機能を検索する。** `tools/sera_workplan.py` や `tools/sera_change_impact.py` で担当モジュールを確認し、`main.gd`への計算・表示ロジックの二重実装を防ぎます。

## 配置の正本

| 要素 | 配置先・扱い |
| --- | --- |
| エンジン設定・起動シーン | `project.godot` と `scenes/`。名称・scene pathを維持 |
| 戦闘、カメラ、入力、HUD、描画 | `scripts/`。副作用とゲーム状態は各既存モジュールの責務に従う |
| シェーダー | `shaders/`。既存の描画順・透明ルールを維持 |
| 画像・音声と生成済みGDScript | `assets/` と `BGM/`。実行時に使用するパスは不変 |
| Blockbenchの現行編集原本 | `models/core/` と `models/storage/` の `models/manifest.json` にある6ファイル |
| 旧モデル、作業用試作、旧モーション | `models/`、`blockbench/`、`bbmodel/` の既存参照を尊重。安全確認なしの一括削除・移動はしない |
| 自動検証と開発ツール | `tools/` と `.github/workflows/` |
| 現行版のREADME | ルート `README_v<現行版>_ja.md` と `README_ja.md` |
| 旧版のリリースノート | `docs/history/release_notes/README_vNNN_ja.md`。内容は変更せず保存 |
| 最新の作業手順・設計 | `AGENTS.md`、`docs/`、`DEVELOPMENT.md` |
| Godotインポートメタデータ | `*.import` はUIDや読み込みの互換性を確認するまでは保持。`.godot/`キャッシュとは別物 |

## 2026-11-14 実施した安全な整理

1. **過去のリリースノート288件**（v318以外の `README_vNNN_ja.md`）をルートから `docs/history/release_notes/` へ移動。旧 `README_ja.md` も `README_legacy_ja.md` として保存しました。移動した全ファイルのGit blobは不変です。
2. ルートの `README_ja.md` は最新開発ドキュメントへの案内に置き換えました。現行 `README_v318_ja.md` は移動していません。
3. 完了済みの一時確認ファイル `SERA_AUTOSYNC_TEST.txt`、`SERA_SAFE_SYNC_TEST.txt`、`SYNC_PROBE_20261107_STAMINA.txt` を削除しました。
4. `models/storage/.trashed-1796821878-頭C.bbmodel` を削除しました。内容は `models/storage/頭C (2)_20261109_222329_691.bbmodel` と完全一致し、いずれも6つの正本には含まれていません。**正本・登録済みモデル・生成データは削除していません。**

## 削除・配置変更の判定基準

1. 必ず最新 `main` と未統合PRを確認し、対象ファイルの利用・生成・テスト・GitSync利用関係を調査します。
2. 現行利用や歴史的なテスト参照が不明な場合、モデル、アニメーション、シーン、インポートメタデータは保持します。拡張子やファイル名の類似だけで削除しません。
3. 同じ内容でも、`assets/sera_source.json`（生成/実行用）と `models/core/Standard.bbmodel`（編集正本）のように役割が違えば両方保持します。
4. パス移動に伴うリンク・参照を一緒に更新し、登録済みのすべてのPython/Godot回帰テストとモデル・描画・開発基盤監査を実施します。
5. CI成功とAndroid実機の表示・読み込み・Blockbenchのモデル編集可能性は別に評価します。未検証のものを完了扱いしません。

## 新規ファイルの置き方

- 新機能：まず既存 `scripts/sera_*.gd` を再利用し、必要な場合だけ専用モジュールを追加。
- 新しいパーツやモーション：`models/manifest.json`、`docs/MODEL_PART_WORKFLOW_ja.md` と対応骨格の正本を確認してから実装。
- 新しい回帰テスト：`tools/` に追加し、`tools/sera_ci_manifest.txt` に登録。
- バージョン更新：新しい `README_vNNN_ja.md` をルートに作成し、旧版ノートはリリース履歴へ移動。現行 `README_ja.md` の案内を更新。
- 変更履歴：日付付きで `DEVELOPMENT.md` を更新。古い履歴の数値は現行仕様に昇格させない。

この規約はファイル名を機械的に統一することより、**実際の読み込み経路と編集原本を保護すること**を優先します。
