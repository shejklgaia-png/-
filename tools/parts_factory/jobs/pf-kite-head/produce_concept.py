"""Execute authored concept production only, not tests or automatic aesthetic review."""
import json, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
PF=ROOT/"tools/parts_factory"
SOURCE=Path(__file__).resolve().parent
OUT=ROOT/"pf_kite_output"
WORK=OUT/"work"
sys.path.insert(0,str(PF))
import quality_gates as q
import factory as f
import review_roles as rr
def run(*args):
    subprocess.run([sys.executable,*map(str,args)],check=True,cwd=ROOT)
def write(p,v):
    p.parent.mkdir(parents=True,exist_ok=True); p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
def load(p): return json.loads(p.read_text(encoding="utf-8"))
actor={"actor":"ChatGPT","context_id":"turn:12657614-8c69-469d-807d-3a6eea7c04f4","kind":"ai"}
review_specs=load(SOURCE/"authored_reviews.json")
def stage_candidate(which,src):
    src.mkdir(parents=True)
    shutil.copy2(SOURCE/(which+".json"),src/"concept.json")
    write(src/"author.json",{"format":rr.FORMAT,"stage":"concept","role":"designer",**actor})
    run(PF/"design_knowledge.py","brief","head","装甲 角張った バイザー センサー 関節 パネルライン UV",src/"design_brief.json")
def review(which,src):
    for role,spec in review_specs[which].items():
        packet=OUT/"packets"/which/role
        run(PF/"review_roles.py","packet",WORK,"concept",src,packet,"--role",role)
        response=load(packet/"response_template.json")
        # The substantive judgments are authored by ChatGPT before this run;
        # this script only attaches the actual packet hashes, no auto scoring.
        response.update(reviewer=actor,independent_context_attested=False,verdict=spec["verdict"],blocking_issues=spec["issues"],revision_advice=spec["advice"])
        response["criteria"]={key:{"score":row[0],"reason":row[1],"evidence":["candidate/concept.json","candidate/design_brief.json"]} for key,row in spec["criteria"].items()}
        write(src/"independent_reviews"/(role+".json"),response)
run(PF/"factory.py","init",WORK,"PF-KITE-HEAD","head","--review-mode","supervised_self_review")
draft=OUT/"draft"; final=OUT/"final"
stage_candidate("draft",draft); review("draft",draft)
run(PF/"review_roles.py","veto",WORK,"concept",draft)
stage_candidate("final",final)
shutil.copytree(draft,final/"supervision"/"draft")
run(PF/"review_roles.py","cycle-template",WORK,"concept",final)
rec=load(final/"supervision"/"reconstruction.json")
rec["actions"]["art_director"].update(response="識別性の弱い横長バイザーを廃止し、正面V字庇と後面台形の構成へ再設計した。",method="主稜線を三本へ制限し左右独立の凹状光学窓、可変断面の頬装甲に変更。",resolved_issues={review_specs["draft"]["art_director"]["issues"][0]:"正面V字庇、分割された左右窓、後面台形カセットを独立した外形特徴に変更。"},evidence=["concept.json"])
rec["actions"]["technical_auditor"].update(response="標準モデルから実測したHeadとNeckの座標及び包絡を採用し、着脱機構と首開口を具体化した。",method="頭部原点基準の中立包絡と暫定外装寸法を分離。光学窓の傾斜リム、放熱カセットの固定レールと脱着方向を指定。",resolved_issues={review_specs["draft"]["technical_auditor"]["issues"][0]:"Standard.bbmodelのHead/Neck回転原点とHead_Mesh/Neck_Mesh頂点から求めた中立包絡を明記。",review_specs["draft"]["technical_auditor"]["issues"][1]:"光学開口の壁とリム、後方レールの脱着経路、縁の締結具を分離。"},evidence=["concept.json"])
write(final/"supervision"/"reconstruction.json",rec)
review("final",final)
run(PF/"factory.py","accept",WORK,"concept",final,"--producer","ChatGPT authored concept review / V6.2 single-AI / real packet binding")
with (OUT/"status.json").open("w",encoding="utf-8") as fp:
    subprocess.run([sys.executable,str(PF/"factory.py"),"status",str(WORK)],check=True,cwd=ROOT,stdout=fp)
print((OUT/"status.json").read_text(encoding="utf-8"))
