"""Fail-closed Motion Lab review handoff. This validates records, not artistic truth.
Separate role records can be created by one sequential AI or independent reviewers.
"""
import json,re
from pathlib import Path

VIEWS={"front","side","back","quarter","game"}
CRITERIA={"intent","silhouette","amplitude","timing","weight","coordination","contact","interference","recovery","comparison"}
ROLES=("director","author","visual_reviewer","technical_reviewer","reviser","judge")

def decide(packet):
    problems=[]
    def check(ok,reason):
        if not ok:problems.append(reason)
    source=packet.get("source",{});candidate=packet.get("candidate",{});stages=packet.get("stages",{})
    check(bool(re.fullmatch("[0-9a-f]{40}",str(source.get("commit","")))),"missing immutable current-game commit")
    check(bool(source.get("asset") and source.get("clip") and source.get("runtime_scope")),"missing source provenance")
    check(source.get("directly_comparable") is True,"direct current-game comparison unavailable")
    check(source.get("engine_replay_verified") is True,"engine baseline not verified")
    digest=candidate.get("sha256","")
    check(bool(re.fullmatch("[0-9a-f]{64}",str(digest))),"missing candidate fingerprint")
    check(bool(candidate.get("viewer") and candidate.get("action")),"missing viewer/action")
    for role in ROLES:
        stage=stages.get(role,{})
        check(stage.get("role")==role and stage.get("candidate_sha256")==digest and bool(stage.get("notes")),"missing or stale "+role+" handoff")
    visual=stages.get("visual_reviewer",{})
    check(visual.get("rendered_viewer_opened") is True,"viewer not opened")
    check(set(visual.get("views",[]))>=VIEWS,"missing required viewpoints")
    check(set(visual.get("full_playback_rates",[]))>={1.,.5},"missing normal/slow playback")
    check(visual.get("continuous_visual_review") is True,"continuous visual evaluation incomplete")
    check(bool(visual.get("evidence")),"missing visual evidence")
    check(visual.get("same_scale_time_camera") is True,"inconsistent comparison conditions")
    check(visual.get("ik_comparison") in ("verified","not_applicable"),"IK comparison incomplete")
    findings=visual.get("criteria",{})
    check(CRITERIA<=set(findings),"missing evaluation criteria")
    check(all(isinstance(findings.get(k),dict) and findings[k].get("status") in ("equal","better") and findings[k].get("evidence") for k in CRITERIA),"visual regression or unverified criterion")
    tech=stages.get("technical_reviewer",{});gates=tech.get("gates",{})
    check(bool(gates) and all(v is True for v in gates.values()),"technical gates failed or missing")
    check(not packet.get("unresolved_issues"),"unresolved issues")
    revision=stages.get("reviser",{})
    check(revision.get("rechecked") is True,"revision not rechecked")
    check(stages.get("judge",{}).get("verdict")=="pass","judge did not approve")
    return {"decision":"review_pass_not_game_adoption" if not problems else "blocked","reasons":problems,
            "scope":"record validation only; AI artistic assessments and evidence authenticity require separate review"}

def main():
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("packet",type=Path);a=p.parse_args()
    result=decide(json.loads(a.packet.read_text()))
    print(json.dumps(result,ensure_ascii=False,indent=2))
    raise SystemExit(0 if result["decision"]!="blocked" else 2)
if __name__=="__main__":main()
