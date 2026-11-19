# SERA v499 — 脚外側の砲台を撤去し、腹側へ4基移設

## 変更内容
- 前後左右の**脚外側**に付いていた砲台4基を廃止。新しい`BellyCannon_belly_fl/fr/rl/rr`を、胴体の腹の下へ**前後左右2×2配置**する。
- 取付位置を従来の下肢4ボーンから**Bodyのみに変更**。原本`models/bosses/Bittaran.bbmodel`にある`Body/body_mesh`の実形状から胴体下面のAABBを算出し、半球の**平らな底面**を装甲下面へ最大1.8cm埋め込み、隙間なく接続する。
- ベースの外向き（ローカル+Y）は胴体の**下方向**。半球を半径0.24mに調整し、4基とも胴体のXZ外形に収める。従来の下肢半径0.29mからは小型化するが、半球＋砲身＋銃口の構成と形状種類は保持。
- 接続部は実際の`Body`のアニメーション・最終姿勢に追従。脚のIKや各脚攻撃・歩行による足先の動きからは独立させる。砲台を骨の子孫に入れないので、元のIK/接地に影響させない。
- 最も近い**砲塔1基のみ**プレイヤーへ追尾し、ほかの3基は腹の下で通常向きのまま。追尾担当は動的に再判定する。
- 4基の近い順射撃・共通1.2秒間隔・17m/s弾速・銃口方向への発射・攻撃/ダウン中の砲台射撃停止・ダウン中の追尾停止/背部レーザー停止は**変更なし**。

## CIの事前確認と先行更新
- `AGENTS.md`、`.github/workflows/sera-model-policy.yml`、`tools/sera_ci_manifest.txt`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/bittaran_leg_turrets_runtime_check.gd`、`docs/MODEL_PART_WORKFLOW_ja.md`、`docs/RENDER_PIPELINE_POLICY_ja.md`、原本Bittaranの`Body`階層と5メッシュを事前確認。
- **ゲーム本体の変更前**に登録済み実Godot CIを修正。旧仕様の「下肢外側への取付」期待値を廃止し、4基全ての`Body`接続・腹の下面への底面密着・下向き法線・胴体の輪郭内への配置・胴体の移動/回転への追従を追加。
- 追尾1基のみ・3基通常姿勢、近い順の4回射撃、発射間隔、砲口と弾方向、攻撃・ダウン・レールガン停止の既存検査は維持。
- GitHub Actionsの`main`へのpushでフルPython/Godot CIが起動する構成。**実機での見た目・腹部と床との干渉は別途確認が必要**。

前のリリース：[v498](docs/history/release_notes/README_v498_ja.md)
