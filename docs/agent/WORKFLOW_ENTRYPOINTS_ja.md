# SERA 開発作業の入口

## 着手から台帳への記録まで

1. [SERA 開発台帳](https://sera-dev-ledger.elegantplume8.chatgpt.site) で運用ポリシーと関連作業を確認する。ChatGPTでは `sera_work_policy` と `sera_work_list` を使い、既存作業の更新前には `sera_work_get` で最新のrevisionを取得する。
2. GitHubの [main](https://github.com/shejklgaia-png/-/tree/main) と対象PRで反映状況を確認する。コードを最新仕様として参照し、必要な関連文書を読む。PRが先に反映・置換されていた場合は後継PRとソースを照合する。
3. [AGENTS.md](../../AGENTS.md) に従って差分を確認し、明示的な保留指定がなければ `main` へ統合する。台帳には実際のステータス、変更ファイル、確認範囲、PR、実装・マージコミットを記録する。台帳やGitHubへ接続できない場合は、取得・記録できた範囲と残っている操作を記載する。

## 機能別の調査先

| 対象 | 入口 | 続けて確認する場所 |
| --- | --- | --- |
| 枠線／外周と分離メッシュ境界 | [全画面の枠線仕様](../SERA_GLOBAL_OUTLINE_STANDARD_20261124_ja.md)、[幅の設定](../../scripts/sera_outline_standard.gd) | [描画対象の登録](../../scripts/sera_view_edges.gd) → [可視ID・深度・表示px換算](../../scripts/sera_scene_id_outlines.gd) → [外周・境界の共通シェーダー](../../shaders/sera_visible_mesh_id_outline_core.gdshaderinc)。同じ機体の装甲境界と敵味方が接触したときの輪郭は別々に追う。 |
| 枠線／戦闘・トレーニング・凸角 | [ビットタラン戦](../../scenes/bittaran_battle.tscn)、[トレーニング側](../../scenes/main.tscn) | [ビットタランの登録](../../scripts/bittaran_battle.gd)と[トレーニングの登録](../../scripts/main.gd)を起点に、上記の可視ID処理へ進む。設備・小物・NEXUS建築の凸角は [補助描画](../../scripts/sera_scene_convex_ink.gd) と [稜線の生成](../../scripts/sera_base_facility_crease_geometry.gd) を参照する。 |
| NEXUS／全身・単体プレビュー | [NEXUSシーン](../../scenes/command_nexus.tscn)、[画面遷移と全身プレビュー](../../scripts/command_nexus.gd) | 全身・単体の切替と背景の表示状態は `command_nexus.gd`、単体は [共通パーツビューア](../../scripts/sera_part_preview_widget.gd)、全身の視野角は [表示プロファイル](../../scripts/sera_display_profile.gd) を確認する。枠線の消失は可視IDへの登録・背景の可視状態も確認する。 |
| BASE／施設の配置・造形・発光 | [BASEシーン](../../scenes/base_exploration.tscn)、[拠点の組み立て](../../scripts/base_exploration.gd) | [施設管理](../../scripts/base_facility_system.gd)、[造形の振り分け](../../scripts/sera_base_architecture.gd)、[施設VFX](../../scripts/sera_base_facility_vfx.gd)、[小物](../../scripts/sera_base_clutter.gd)、[電源・配線](../../scripts/sera_base_power_distribution.gd)。モニターは [共通の表示制御](../../scripts/sera_world_monitor_textures.gd)。 |
| NEXUS室内・LABO三景の3D | [NEXUSの生成メッシュ](../../scripts/nexus_generated_architecture.gd)、[床パネル](../../scripts/sera_nexus_floor_panels.gd)、[LABOの3Dシーン](../../scenes/labo_hero_stage.tscn) | LABO・素材精製・倉庫の構成は [ステージ](../../scripts/labo_hero_stage.gd) と [設備造形](../../scripts/labo_interior_fittings.gd) を起点にする。 |

## GitHub接続・操作の再確認

対象は `shejklgaia-png/-`、既定ブランチは `main`。

| 最初の結果 | 次に行う確認 |
| --- | --- |
| 名前での検索が空 | 完全名で直接参照する。候補が必要な場合は接続済みリポジトリ一覧を調べる。 |
| タイムアウト・5xx | 同じ操作を安全に再試行するか別の取得経路を使う。書き込みの結果が不明なら、再実行前に対象ブランチ・PR・コミットを取得する。 |
| 401・403・404 | 接続先アカウント、対象の完全名、操作権限、対象PRの有無を個別に確認する。検索結果が空という理由だけで権限不足と判断しない。 |
| 操作ツールが見つからない | ツール検索を操作名や別の検索経路でやり直す。読み取りと書き込みの可否を分けて判定する。 |
| PRの競合・HEADの更新・ブランチ保護 | 最新のPRと `main` を取得し、競合・差分の更新・リポジトリ側の制約を実際の応答から区別する。操作後はPRと反映コミットを再取得する。 |

詰まった経路と、成功した経路または残った障害を台帳の再試行記録に残す。
