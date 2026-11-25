"""CRATE V9 targeted repair: actual supports, not geometric surface decoration."""
import copy
import sys
from pathlib import Path
import budget_repair as v8
import reference_design_variants as rv
import industrial_design_variants as iv
from iterative_review import read,write

def prepare(src,dest):
    v8.prepare(src,dest)
    d=read(Path(dest))
    for k in ("tread_lite","guide_lite","wheel_lite","chassis_support","chest_armor","shoulder_rib","neck_clearance","wrist_clearance","claw_clearance"):
        d=v8.mutate(d,k)
    # Keep authored major shell and crown, remove shallow panel insets and cosmetic hardware.
    raw=rv.mutate_structural(read(Path(src)),"head_crown")
    shell={a["name"]:a for a in raw["parts"]}
    transfer={"HeadSidePanelL":"Head","HeadSidePanelR":"Head","ChestMainPanel":"Chest","ChestUpperPanel":"Chest"}
    for t in ("L","R"):
        for n in ("ChestSeam","ChestMark"):transfer[n+t]="Chest"
        for n in ("TrackHubInset","TrackHubBolt"+t+"F","TrackHubBolt"+t+"B"):
            transfer[n+t if n=="TrackHubInset" else n]="TrackHub"+t
    p={a["name"]:a for a in d["parts"]}
    # Roof service cover is retained as a physical raised cover, not a panel line.
    d["texture_handoff"]={"format":"SERA_SURFACE_DETAIL_HANDOFF_V1","status":"unpainted",
        "details":[{"former_mesh":name,"target":target,"material":p[name]["material"],
                    "source_geometry":copy.deepcopy(p[name]),"method":"face painting or texture bake; no runtime mesh"}
                   for name,target in transfer.items()],
        "notes":"Panel lines, small fasteners, surface markings and shallow recess shading belong in texture. Retain large physical covers, axle components, optical recess and tread geometry."}
    d["parts"]=[copy.deepcopy(shell[a["name"]]) if a["name"] in ("Head","Chest") else a for a in d["parts"] if a["name"] not in transfer]
    p={a["name"]:a for a in d["parts"]}
    p["ChestAccent"]["location"][1]=-.185 # on the restored chest slope
    checks=[]
    def pair(a,b,each=False,expected=None):
        row={"part":a,"support":b,"each_island":each,"max_gap_m":.001}
        if expected is not None:row["expected_islands"]=expected
        checks.append(row)
    for s,t in ((-1,"L"),(1,"R")):
        frame="TrackSupportFrame"+t;cover="TrackHub"+t
        # Two concealed mounting bosses bridge measured 47.22mm axial gap.
        for j,y in enumerate((-.050,.050)):
            name="TrackCoverSupport"+t+str(j)
            a=iv.append_part(d,name,"BodyRoot","frame","box",[s*.243,y,.136],size=[.060,.016,.019]);a["bevel"]=0
            pair(name,frame);pair(name,cover)
        for j,y in enumerate((-.118,0,.118)):
            k=t+str(j);wheel="TrackRoadRoller"+k;rim="TrackRoadRim"+k;hub="TrackRoadHub"+k
            # Seat rim and hub on wheel; the axle spans the frame and the bored wheel.
            p[rim]["location"][0]-=s*.002;p[hub]["location"][0]-=s*.002
            name="TrackRoadShaft"+k
            a=iv.append_part(d,name,"BodyRoot","steel","cylinder",[s*.219,y,.083],radius=.015,depth=.100,sides=12,rotation_deg=[0,90,0]);a["bevel"]=0
            pair(rim,wheel);pair(hub,rim);pair(name,frame);pair(name,wheel)
        for prefix in ("FrontWheel","RearWheel"):
            wheel=prefix+t;rim=prefix+"Rim"+t;hub=prefix+"Hub"+t
            y=p[wheel]["location"][1]
            p[hub]["location"][0]-=s*.002;p[prefix+"Axle"+t]["location"][0]-=s*.002
            name="Track"+prefix+"Shaft"+t
            a=iv.append_part(d,name,"BodyRoot","steel","cylinder",[s*.219,y,.114],radius=.015,depth=.108,sides=12,rotation_deg=[0,90,0]);a["bevel"]=0
            mount="Track"+prefix+"BearingMount"+t
            a=iv.append_part(d,mount,"BodyRoot","frame","box",[s*.192,y*.91,.114],size=[.042,.060,.042]);a["bevel"]=0
            pair(mount,frame);pair(name,mount);pair(name,wheel);pair(rim,wheel);pair(hub,rim);pair(prefix+"Axle"+t,hub)
        for prefix in ("TrackPads","TrackPadsOuter","TrackGuideRidge"):
            pair(prefix+t,"Track"+t,True,d["track_design"]["pads"])
    d["attachment_checks"]=checks
    d["research_adaptations"].append({"recipe":"attachment_repair","url":"https://parts.cat.com/en/catcorp/product/654-4447","adaptation":"Connect side covers and roller shafts to a fixed roller support frame; fictional dimensions."})
    d.setdefault("design_notes",[]).append("V9 targeted floating part repair; texture-only detailing separated. No game asset replacement.")
    write(Path(dest),d)
if __name__=="__main__":prepare(sys.argv[1],sys.argv[2])
