# SERA：硬質SF書体の導入（2026-11-24）

## 採用書体と用途

| UIロール | 書体 | ローカルパス |
| --- | --- | --- |
| 日本語本文・素材名 | マキナス 4 Flat | `assets/fonts/Makinas4Flat.otf` |
| 日本語見出し・装備名・操作 | マキナス 4 Square | `assets/fonts/Makinas4Square.otf` |
| 英語ナビゲーション | Chakra Petch SemiBold | `assets/fonts/ChakraPetch-SemiBold.ttf` |
| 数字・型番・ステータス | Chakra Petch Medium | `assets/fonts/ChakraPetch-Medium.ttf` |

Chakra Petchには日本語がないため、数値と日本語が混ざるフォントロールにはマキナス Flat をフォールバック指定します。全画面の共通ロールは `scripts/sera_labo_round_skin.gd` に集約し、重複ロードを防止します。

## ローカル導入

プロジェクトのルートで一度だけ実行：

```sh
python3 tools/install_sera_angular_fonts.py
```

Android / Termux では Python を導入済みの状態で同じコマンドを実行します。導入後に Godot のリソースを再読み込みします。通常のゲーム実行中にはネットワークに接続しません。APKへの .otf / .ttf 同梱設定は `export_presets.cfg` に含まれます。

導入スクリプトは [もじワク研究の公式配布](https://moji-waku.com/makinas/) と [Google FontsのChakra Petch](https://github.com/google/fonts/tree/main/ofl/chakrapetch) から原本を取得します。元のファイルは改変しません。公式サイトの配布形式が変更された場合は、公式ZIPから手動で2つのOTFを同名で配置できます。

## ライセンスと公開GitHubの重要事項

- マキナス：作者の [使用許諾](https://moji-waku.com/mj_work_license/) はゲーム内文字表示とフォント組込みを許可しますが、**無断の二次配布は禁止**です。SERAのGitHubは公開リポジトリなので、マキナスのOTFをpush、PR添付、配布物ソースへ同梱しないでください。ゲームに埋め込む用途に限定します。
- Chakra Petch：SIL Open Font License 1.1。インストール時に公式ライセンス文 `OFL-ChakraPetch.txt` を取得します。ゲームへの埋込み・再配布には当該ライセンスの保持が必要です。
- 対象の原本フォントとGodotの `.import` の一部は `.gitignore` により公開Gitへの混入を防ぎます。端末へのローカル導入を済ませていない状態では従来のUDEV Gothic／Moralerspace Neonが自動的に表示され、UIが文字欠けしない構成です。**したがって、mainの更新だけでは新書体の見た目にはなりません。**
- FontFileはRAW_BYTESを優先し、Godotインポート済みリソースも扱います。正規原本以外のフォントは導入せず、フォント生成・改変は行いません。

## 反映範囲と留意点

共通テーマからのタイトル、本文、ボタン、装備名、素材名、数値、英語ナビゲーションと戦闘HUDの既存共通フォント経路に適用します。個別に固定フォントが指定された別UIがあれば、別途確認して統合します。書体幅・日本語の行高さによる画面の折返し・見切れはAndroid実機で確認が必要です。

運用上、CI項目の変更・CI実行やテストは行いません。
