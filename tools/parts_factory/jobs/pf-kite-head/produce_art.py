"""Bind the actual visually reviewed concept candidates to the factory gate.
The assessments below are authored in the active ChatGPT conversation after
looking at the recovered draft and rebuilt PNGs; this is not automatic scoring.
"""
import json, shutil, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
PF=ROOT/"tools/parts_factory"
sys.path.insert(0,str(PF))
import factory as f
import quality_gates as q
import review_roles as rr
OUT=ROOT/"pf_kite_output"
WORK=OUT/"work"
AUTHOR={"actor":"ChatGPT","context_id":"conversation-runtime:114d115ee7974f58a47bfee86a2c3f50","kind":"ai"}
TASK="87ea2426-ccf3-45db-9e17-eb2cb6603687"
EXPECTED={
"A":"a6c585d7df0b9d0ba30ed2ce9f1cacf9cab75905b5e487b9d7b2f866e4df8b88",
"B":"8e835aa88cabb1071f6b1fd1adf12ea49c0fd5ff1b3ae5c03d3bf7a4b03fc6ad",
"C":"2ccdeb68ac6772da25b44e5bbab69431fbbca22776ccfa4e86d7b7dff0ece3d1",
"A2":"7bb8fb6f4dc60770bc74827e0774fca5c68653e5de78ea1bf0025e227ee8b22a",
"B2":"bf9ded6b33e89031e959671b0a28be8e72661c6d8b2c9a9c494e0fe530fe6483",
"C2":"1edd0ebaaf23348c2e65e5a2c58242e86661a60430d302779ccb114b2359e102"}
# Six candidate-level reasons in q.ART order: appeal, identity, silhouette,
# mechanism, cohesion, readability. A2 is the selected concept only.
ROWS={
"A":("細長い前傾シルエットと突出した顎を持つ探索型",[(3,"顎の縦方向の突出が機敏な印象を弱める。"),(4,"左右独立の青い光学窓と白い庇は識別できる。"),(3,"前に長い庇と下に長い顎が主張しすぎる。"),(3,"側面の支持機構が太く顎の支持用途が曖昧。"),(4,"白装甲と暗色フレームに統一感がある。"),(3,"細長い顔の先端に複数の線が集中する。")]),
"B":("厚い側面装甲と大型の頬パネルを備えた保護型",[(3,"重い頬装甲が頭部全体の軽さを阻害する。"),(3,"平たい大面積頬パネルで顔の特徴が弱い。"),(3,"側頭から顎への装甲が厚く張り出す。"),(3,"頬の大型化が首周辺の余裕を狭めそうに見える。"),(4,"配色と光学ユニットは共通の設計言語。"),(3,"厚い頬が暗色機構の輪郭を隠している。")]),
"C":("後部の大型放熱カセットを強調する冷却重視型",[(3,"後部が前頭部と同等に強く重心が後方に見える。"),(4,"後面の放熱部が明快な識別特徴になる。"),(3,"大きな後部カセットが頭の輪郭を圧迫する。"),(3,"冷却部の固定構造は読めるが占有が過大。"),(3,"後部の厚い暗色塊と前部白装甲が拮抗する。"),(4,"後側のフィンと光学部の機能は区別できる。")]),
"A2":("短いV字庇と薄い頬装甲の軽量型",[(4,"白い主面と暗色レールの余白が明確で過密でない。"),(4,"V字庇と独立二眼、後部橙色ラッチで識別できる。"),(4,"下顎を細い支持レールに置き換え頬の下端を短縮。"),(4,"光学窓の凹部、装甲固定点、側面支持、放熱グリルを分離。"),(4,"白い装甲、暗色機構、青い光学部が同じ機械言語。"),(4,"主面を大きく残し機構と留め具を縁に集約した。")]),
"B2":("中央稜線と幅広い頬装甲を強調する保護型",[(4,"中央の分割線と庇が工業機械らしい形状を作る。"),(3,"中央稜線の意匠が二眼より強く見える。"),(3,"頬の大面積板が選定案より重く見える。"),(4,"フィン、光学開口、頬の固定点が読める。"),(4,"配色は他の再構築候補と整合する。"),(3,"頭頂中央と頬の線が顔より目立ちやすい。")]),
"C2":("低い前傾シェルと後方へ流れる側面稜線の高速型",[(4,"低い屋根と流れる側面の稜線が鋭い印象。"),(4,"二眼と放熱ラッチで同系統の識別性を維持。"),(3,"庇と側面後端が長くなりコンセプトの短さから外れる。"),(4,"側面レールと冷却部は視覚的に区分される。"),(4,"主面と暗色フレームの色構成が統一されている。"),(4,"少数の締結点と大きな主面で読みやすい。")])}
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
def prepare(src,quarantine,selected):
    shutil.copytree(quarantine,src)
    m=q.load(src/"manifest.json")
    items=[]
    content={}
    for row in m["candidates"]:
        cid=row["id"]; path=row["path"]
        q.need(q.sha(src/path)==row["sha256"]==EXPECTED[cid],"reviewed candidate hash differs: "+cid)
        direction,scores=ROWS[cid]
        items.append({"id":cid,"file":path,"sha256":EXPECTED[cid],"design_direction":direction,
                      "rubric":{k:{"score":s,"reason":r} for k,(s,r) in zip(q.ART,scores)}})
        content[cid]={"sha256":EXPECTED[cid],"claims_absent":True,
                      "notes":"実候補PNGを目視。機械頭部と暗色背景のみで、完成、登録、承認、測定の虚偽表示や文字は見られない。"}
    shutil.copy2(src/next(r["file"] for r in items if r["id"]==selected),src/"selected.png")
    write(src/"author.json",{"format":rr.FORMAT,"stage":"art","role":"designer",**AUTHOR})
    write(src/"art_review.json",{"image_task_id":TASK,"reviewer":"ChatGPT / single AI, not independent",
         "selected":selected,"selection_reason":("初稿Aは二眼と白い装甲の方向性を残す候補。ただし前後と顎の突出があり棄却する。" if selected=="A" else "A2はB2の大きな頬板やC2の長い庇を避け、短い顎と露出支持レールを備える。側背面・首接続の寸法検証は設計図以降で行う。"),
         "candidates":items})
    write(src/"image_content_review.json",{"format":"SERA_PF_IMAGE_CONTENT_V1","reviewer":"ChatGPT","images":content})
def assess(src,phase,selected):
    specs={
     "draft":{
      rr.ART:("reject",["Aの長い庇と顎、Bの厚い頬、Cの後部塊が軽量頭部の主形状を阻害。"],
       {"appeal":(3,"Aの前方と下方への張り出し、B/Cの重い外装が軽快さを損なう。"),
        "identity":(4,"独立二眼と橙色の整備部は設計意図を識別できる。"),
        "silhouette":(3,"三案とも庇、頬、後部のいずれかの突出が過大。"),
        "cohesion":(4,"白・暗色・青と橙の配色に一貫性がある。"),
        "readability":(3,"面の重なりが多く顔の縮小視認性に懸念。"),
        "visual_truthfulness":(5,"全候補に架空の承認、数値、完成画面などの記載はない。")},
       "庇と頬を短縮し、細い下部支持レールと小さな放熱部で外形を再構成する。"),
      rr.TECH:("reject",["厚い頬や長い顎と大きな後部装置が軽量設計の機構階層と両立しにくい。"],
       {"mechanism":(3,"二眼とフィンは存在するが大面積装甲が支持部を隠す。"),
        "feasibility":(3,"庇、頬、後部機構の過大な突出は首とのクリアランスに懸念。"),
        "reference_consistency":(3,"短い庇、下縁露出レール、小型放熱部という受理コンセプトから逸脱。"),
        "visual_truthfulness":(5,"実画像は設計候補であり虚偽の技術測定を描いていない。")},
       "光学凹部、装甲、レール、放熱カセットの役割を分け、後続で実寸法を検証する。")},
     "rebuilt":{
      rr.ART:("approve",[],
       {"appeal":(4,"A2は白い主面と暗色の下部に視覚的な余白があり初稿より軽快。"),
        "identity":(4,"中央の低いV字庇、左右独立青窓、橙ラッチでKITEを識別できる。"),
        "silhouette":(4,"初稿Aの下方の長い顎を短い白装甲と細い支持レールに変更。B2/C2より外形のバランスが良い。"),
        "cohesion":(4,"装甲の主従と白・暗色・青・橙の色面が整っている。"),
        "readability":(4,"大面を空け縁の締結点と光学窓を目立たせている。"),
        "visual_truthfulness":(5,"候補は単体のコンセプト画像で虚偽の完成・登録表示なし。")},
       "A2を設計方向として選定。正投影図で左右対称、後面と下部の支持レールを整理する。"),
      rr.TECH:("approve",[],
       {"mechanism":(4,"光学部に独立した外周と奥面が見え、頬板、暗色レール、放熱部の役割が分かれる。"),
        "feasibility":(4,"A2の板とレールは分離した立体部品として造形可能な概念。実接続・干渉は未検証で設計図以降の必須項目。"),
        "reference_consistency":(4,"V字庇、独立光学窓、下縁レール、小型放熱部という主要意図を維持。後面の取付高さは図面で確定する。"),
        "visual_truthfulness":(5,"実PNGに虚偽の計測・認証・完成記述はない。")},
       "コンセプト段階のみ承認。放熱部の背面高さ、首の開口、寸法、側面稜線は10方向図と実測で検証する。")}
    }[phase]
    for role,(verdict,issues,criteria,advice) in specs.items():
        packet=OUT/"art_packets"/phase/role
        rr.make_packet(WORK,"art",src,packet,role)
        response=q.load(packet/"response_template.json")
        paths=[p for p in response["packet_files"] if p.startswith(("candidate/candidate_","draft/candidate_","upstream/concept/"))]
        response.update(reviewer=AUTHOR,independent_context_attested=False,verdict=verdict,blocking_issues=issues,revision_advice=advice,
                        selected_candidate_sha256=EXPECTED[selected] if verdict=="approve" else None)
        response["criteria"]={key:{"score":score,"reason":reason,"evidence":paths} for key,(score,reason) in criteria.items()}
        write(src/"independent_reviews"/(role+".json"),response)
def main():
    d=f.state(WORK);stages,rev=f.verify(WORK,d)
    q.need(stages==["concept"] and rev=="63b30ad424a382afae05b5dfdf721f7102306169f34b5d5e6ff9baad4c1646a3","unexpected concept revision")
    draft=OUT/"art_draft_review"; final=OUT/"art_final_review"
    prepare(draft,OUT/"art_draft_quarantine","A");assess(draft,"draft","A");rr.record_veto(WORK,"art",draft)
    prepare(final,OUT/"art_rebuilt_quarantine","A2")
    shutil.copytree(draft,final/"supervision"/"draft")
    rr.cycle_template(final,"art",d["id"],d["stages"],WORK)
    rec=q.load(final/"supervision"/"reconstruction.json")
    for role in (rr.ART,rr.TECH):
        row=rec["actions"][role]
        row.update(response="実画像を再生成して長い顎、厚い頬、過大な後部という初稿の問題に対処した。",
                   method="初稿のAの二眼と装甲言語を保持し、再構築3案を比較してA2の短い頬板と下部露出レールを選定。",
                   resolved_issues={k:"A2では短い頬下端と細いレール、分離した光学窓、小型の放熱グリルで機構の主従を整理。接続寸法は次段階で検証。" for k in row["resolved_issues"]},
                   evidence=["selected.png","candidates/A2.png","art_review.json"])
    write(final/"supervision"/"reconstruction.json",rec)
    assess(final,"rebuilt","A2")
    f.accept(WORK,"art",final,"ChatGPT single-AI authored visual supervision and reconstruction; exact PNG evidence from production runner")
    new=f.state(WORK);stages,rev=f.verify(WORK,new)
    write(OUT/"art_status.json",{"accepted_stages":stages,"revision":rev,"selected_art_sha256":q.sha(final/"selected.png"),"review_mode":new["review_mode"],"next":"blueprint","geometry_verified":False})
    print((OUT/"art_status.json").read_text())
if __name__=="__main__":
    main()
