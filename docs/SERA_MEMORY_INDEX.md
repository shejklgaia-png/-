# SERA — ChatGPT記憶からの引き継ぎ索引
作成: 2026-11-06 / 基準: セラ v102（GitHub `shejklgaia-png/-`）

## 目的と注意
ここに整理したのは、ChatGPTが参照できた**セラのゲーム開発に関する記憶・過去会話の決定**です。全チャットの逐語記録や失われた詳細まで含むとは限りません。ユーザーの私生活・他の関心事項は含めません。CodexはChatGPTの個人メモリを直接引き継ぐものではないため、このリポジトリ内の文書を明示的な共有情報とします。

## 状態ラベル
- **[実装]**: v102のコードと版別READMEによる裏付けがあるもの。必ず現行コードで再確認する。
- **[設計決定／未実装]**: ユーザーの設計方針は決まったが、現行コードへの統合は確認できないもの。勝手に実装しない。
- **[検討]**: 候補・アイデア、数値や採用の決定がないもの。
- **[履歴]**: 古いバージョン、以前の試み、旧数値。
- **[要確認]**: 実装反映の有無や現在値についてソースとの照合が必要なもの。

## 読む順番
1. `AGENTS.md` — 禁止事項、テスト、変更ルール
2. `project.godot` と関係する `scripts/`, `assets/`, `blockbench/` — 実際の実装
3. `docs/history/release_notes/README_v102_ja.md`、`README_v101_ja.md`、`DEVELOPMENT.md` — **v102当時の実装履歴**。現行版はルートの `README_vNNN_ja.md` を確認
4. `docs/SERA_CONCEPT_AND_ROADMAP.md` — 全体像、優先順位
5. `docs/SERA_INPUT_MOVEMENT_CAMERA.md` — 指操作、移動、カメラ、UI
6. `docs/SERA_COMBAT_DEFENSE_ENEMIES.md` — 格闘、ガード、敵攻撃、リソース
7. `docs/SERA_ASSETS_FX_AUDIO.md` — モデル、モーション、剣閃、残像、サウンド
8. `docs/SERA_TECH_AND_WORKFLOW.md` — スマホ開発、運用、検証
9. 変更機能に対応する `docs/history/release_notes/README_vNNN_ja.md` / `tools/*self_check*.py`。過去版の数値は現行仕様ではありません

## 矛盾時の優先順位
**最新の明示的ユーザー指示 > 実機で確認された挙動と現行コード > 最新版README/開発履歴 > 確定済み将来仕様 > 本要約 > 旧版や提案**。

記憶文書は「今すぐすべて実装せよ」という依頼ではありません。仕様変更時には状態ラベルを更新し、コード・検証・開発履歴と整合させてください。機械的な静的検査をAndroid実機検証と呼ばないでください。


## 2026-11-14 配置整理
過去バージョンのREADMEを `docs/history/release_notes/` に移しました。モデル原本や現行の開発運用は `models/manifest.json`、`AGENTS.md`、`docs/SERA_REPOSITORY_LAYOUT_ja.md` を確認してください。
