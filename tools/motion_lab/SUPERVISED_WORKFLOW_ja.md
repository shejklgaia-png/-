# AI監修型モーション制作 V31R
2026-11-26。MANDATORY_VISUAL_REVIEW_ja.md の条件を維持する。
## 役割と引き渡し
1. director: 現行mainのモデル・クリップ・実行条件を固定。ゲームでの目的、主要姿勢、時間、意図的な接地/空中区間、守る演技を定義。単なる数値最適化を目的としない。
2. author: 全身FKと演技の時系列を制作し、候補のfingerprint・原本との差・HTMLを提出。自身で採用を決定しない。
3. visual_reviewer: 同一実時間・視点・縮尺の現行/旧候補/新候補を実際に開いて比較。通常/半速全尺、5視点、補正比較、連続した遷移を視認。意図・輪郭・振幅・緩急・重量感・連動・接地・干渉・復帰・現行比較を時刻と根拠付きで判定。指摘には部位・区間・修正目標・保持すべき点を含める。
4. technical_reviewer: 実形状の床・支持・干渉・可動範囲・速度・時間差・既存回帰を検査。実測と代理指標を区別。未測定は合格にしない。視覚評価を上書きしない。
5. reviser: 指摘を元に局所修正し、変更範囲と保持条件を記録。大きな問題はdirectorへ差し戻してFK演技を再設計。修正後は両レビューを再実施。
6. judge: 役割別の同一候補fingerprint、現行比較、実描画、技術ゲート、修正後再検査を確認。未完了・不合格・現行以上未証明なら棄却。合格もゲーム採用承認ではない。
現在は一つのChatGPTによる順次役割分離であり、独立したAI群の実行ではない。将来別セッション/別モデルでも共通の引き渡し形式を使う。監修の思い込み対策に数値と描画を必ず併用し、出力数値を見ずに先に演技を評価する段階を設ける。
## 機械的な完了制御
supervised_review.py はJSON packetのsource/candidate/stages/unresolved_issuesを検査。各役割にrole, candidate_sha256, notes、視覚担当には5視点・通常半速の再生・連続視認・同条件・IK比較・criteria各項目の根拠、技術担当にはgates、修正担当にはrechecked、判定担当にはverdictを要求する。証拠の真偽を自動検証するAIではなく、申告の欠落・未完了・不合格をfail closedで止める独立ゲート。ゲームCI・既存生成フローへの強制組込は未実施。CLIは python tools/motion_lab/supervised_review.py packet.json。
## V31R 試行
最新main d1c65fe472ab9172405e2312dbb3daf2f737e641 の assets/sera_source.json blob 183f134326a972bd3b510b21846aba46e5984623、sera_rig.gd d66e82afb15763b59293c9757b0ff361893440d8、sera_equipment.gd 991cd079889b29ab24aed737b70c5f7e3c1de124、main.gd 24202c1f9b8b1470dfa6d1300b84508cf62980f2 が前回比較と一致。前進/左右走行方向転換を再試行。踏み込みは未再試行。
現行RUNの独立再構成FKから全身演技を保持し、最低足メッシュ頂点から床を参照、腰の高さをガウス平滑化し到達範囲内で二リンクIK。foot_lowを接地固定と混同しない。reference_pose_repair.py は実験的な提案関数、既存生成に未接続。前進/左右各3候補を比較。240Hz標本で床突出約4.24〜6.84mm、腰上下変位約34.65〜58.22cm。比較用中強度案は前進/左/右で床4.43/4.30/4.49mm、腰上下49.44/49.77/49.40cm、最大回転変更33.68/33.67/33.68度、非隣接OBB12.27cm（現行再構成と同等、厳密交差未測定）。全案不合格。独立プレビューの床基準は実機と同一と未検証、現行の最大床突出62cmをゲーム不具合と断定しない。
MotionLab_V31_Supervised_Review.html (SHA256 76836c0ac99fd932bff5a174bf40c76e49c12e2710f5eee7a4ee836047199b18)。5方向×5時刻×3動作の三者比較75組描画を3枚シートで視認。通常/半速6回全尺終端、JS例外0。連続再生映像の全区間視認は未証明。現行の構えと振幅の保持はV31より良いが、腰上下・膝形状・接地・厳密な現行品質比較が未合格。装備・Godot実行・実ゲームカメラ・補正切替・連続衝突・動力学未検証。次は実ゲーム再生の取得と、現行の位相を維持した接地/空中イベントを明示した全身FK設計。地面への常時固定はしない。ゲーム原本とCIは変更しない。
参考: https://proceedings.neurips.cc/paper_files/paper/2023/hash/91edff07232fb1b55a505a9e9f6c0ff3-Abstract-Conference.html ; https://doi.org/10.1162/tacl_a_00713 ; https://research.cs.wisc.edu/graphics/Gallery/kovar.vol/Cleanup/
