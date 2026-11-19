# SERA v498 — 砲台半球底面を下肢に固定、最寄り1基のみ追尾

## 仕様
- 4本の下肢の外側面（左右 ±X）の実メッシュAABBに基づき、砲台の取付点を**装甲外面のすぐ内側（最大3.5cm埋込）**へ配置。取付点は半球の**中心でなく平らな底面**。
- Godot `SphereMesh`の正半球（`is_hemisphere=true`、`height=radius`）を使用。実メッシュAABBの下端をローカル Y=0 に合わせ、底面を外側装甲に密着させる。取付ローカル+Y軸を下肢の**外向き法線**に揃える。
- **半球は下肢に固定**し、砲身・銃口部分のみ`TurretAim`ピボットで旋回。下肢IKの最終姿勢へ、攻撃・ダウン中も半球と砲塔全体の取付位置が追従する。攻撃アニメーションとIKが測定する原本メッシュは変更しない。
- 毎フレーム、セラに最も近い**1基の砲身だけ**がセラへ向く（距離の順位が入れ替われば追尾担当も即座に切替）。残る3基は下肢に固定された通常の向きに戻し、プレイヤーを追尾しない。
- ダウン予備動作から復帰完了まで、全砲台の**追尾と射撃を停止**し、砲身は下肢に沿う通常姿勢へ戻す。背部レーザーも従来通りダウン中停止。

## 射撃の維持仕様
- 4基の射撃順序「近い脚から順番」、共通の1.2秒間隔、17m/s光弾、攻撃中の射撃停止は変更しない。
- 発射方向を銃口の**実際の向き**と一致させる。追尾担当以外の砲身は通常向きのまま順次射撃するため、意図的に銃口をずらしてプレイヤーへ誘導する弾は出さない。
- 機体原本`models/bosses/Bittaran.bbmodel`、脚骨Pivot・キーフレーム、接地IK、ダメージは変更なし。

## CI先行更新
- `AGENTS.md`、`docs/SERA_ACTIVE_CI_POLICY_ja.md`、`tools/sera_ci_manifest.txt`、`.github/workflows/sera-model-policy.yml`、`docs/MODEL_PART_WORKFLOW_ja.md`、`docs/RENDER_PIPELINE_POLICY_ja.md`、`scripts/bittaran_battle.gd`および登録済み`tools/bittaran_leg_turrets_runtime_check.gd`を確認。
- 本体編集**前**に既存CIを更新。半球底面の位置・外向き法線、正半球寸法、装甲外側への浅い埋込、砲身専用ピボット、最寄り1基への追尾／切替、3基の通常姿勢、ダウン中の追尾停止、砲口と弾方向の一致を追加した。既存の4基近距離順射撃・1.2秒間隔・ダウン時レーザー停止のテストは維持。
- GitHub Actionsが`main`へマージ後に全Python/Godot CIを起動する。**Godot/Androidでの最終目視確認は別途必要**。

前バージョン：[v497](docs/history/release_notes/README_v497_ja.md)
