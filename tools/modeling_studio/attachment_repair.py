"""CRATE V15 full-body supervised repair: actual supports, not geometric surface decoration."""
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
    # V9 actual GLB sampled skid-to-chassis gap: 2.4966 mm.
    for t in ("L","R"):
        # V10 raised the plate entirely into the chassis. Seat across the actual
        # lower surface (z=.04937), leaving the lower half visibly outside.
        p["TrackSkidPlate"+t]["location"][2]=.045
        pair("TrackSkidPlate"+t,"Chassis")
        for i in range(2):
            pair("TrackMountBridge"+t+str(i),"Chassis")
            pair("TrackMountBridge"+t+str(i),"TrackSupportFrame"+t)
    # Preserve the visor front face at y=-.236 and emitter positions.
    # Extend the rear mounting face into the closed head recess.
    p["Visor"]["location"][1]+=.002
    p["Visor"]["size"][1]+=.004
    pair("Visor","Head")
    pair("LightBar","Visor")
    # AI visual review: make the chest a sculpted shell instead of a broad box.
    # Retain its lower mounting rings and upper neck seat; widen the side chamfers.
    rings=p["Chest"]["rings"]
    for idx,front_x,side_shift in ((2,.105,.018),(3,.095,.012)):
        ring=rings[idx]
        ring[0][0]=-front_x
        ring[1][0]=front_x
        ring[2][1]+=side_shift
        ring[7][1]+=side_shift
    # Add a primary angled transition rather than a separate decorative panel.
    mid=[[(a+b)/2 for a,b in zip(v,w)] for v,w in zip(rings[2],rings[3])]
    for i in (0,1):mid[i][1]-=.009
    for i in (2,7):mid[i][1]-=.004
    rings.insert(3,mid)
    pair("Chest","Chassis")
    d["research_adaptations"].extend([
        {"recipe":"supervised_skid_seat","url":"https://parts.cat.com/en/catcorp/product/199-5421","adaptation":"Distinct bottom guard seated across lower chassis surface."},
        {"recipe":"supervised_optical_mount","url":"https://support.zivid.com/en/latest/camera/reference-articles/mechanical-considerations-for-robot-mounting.html","adaptation":"Protected optical assembly mounted to enclosure, preserve visible face."}
    ])
    d["design_notes"].append("V11 supervised chest primary shape refinement. Source evidence: V10 run 45717641835, artifact 15069919165. New visual approval pending.")
    d["attachment_graph"]={"roots":["Chassis"],"max_gap_m":.001}
    d["attachment_checks"]=checks
    d["research_adaptations"].append({"recipe":"attachment_repair","url":"https://parts.cat.com/en/catcorp/product/654-4447","adaptation":"Connect side covers and roller shafts to a fixed roller support frame; fictional dimensions."})
    d.setdefault("design_notes",[]).append("V9 targeted floating part repair; texture-only detailing separated. No game asset replacement.")
    # V13: actual V12 diagnostics, not a blanket collision exemption.
    # Keep joint pivots, sweep limits, tread envelope and the face geometry.
    # Taper the fixed neck near the pitching head; the axle stays unchanged.
    for idx,sy,dz in ((1,.79,.004),(2,.65,.006)):
        for v in p["Neck"]["rings"][idx]:
            v[1]=.008+(v[1]-.008)*sy
            v[2]-=dz
    for t in ("L","R"):
        # Coaxial output collar: rear axial face is separated from fixed bearing.
        # Bore seats on the existing rotating axle; distal flange stays intact.
        hand=p["HandBase"+t]
        hand["profile"][0]=[.0215,.0015]
        hand["profile"][1]=[.031,.0015]
        hand["profile"][2]=[.047,.011]
        hand["profile"][5][0]=.0215
        pair("HandBase"+t,"WristAxle"+t)
        # Relieve the proximal forearm core and retain its distal support.
        core=p["ForearmCore"+t]
        start,end=core["path"]
        core["path"][0]=[a+(b-a)*.12 for a,b in zip(start,end)]
        core["sections"][0]=[.018,.019]
        # Structural gusset broadens toward the chest and tapers at housing.
        gusset=p["ShoulderLowerGusset"+t]
        gusset["sections"]=[[.038,.020],[.033,.024],[.022,.013]]
    # Sculpt side facets into primary chest shell (no decorative panel meshes).
    # Preserve front accent seat, mounting rings and outer shoulder envelope.
    for idx in (2,3,4):
        ring=p["Chest"]["rings"][idx]
        for j in (2,7):
            ring[j][0]*=.96
        for j in (3,6):
            ring[j][0]*=.97
    d["design_notes"].append("V13 supervised proposal from V12 artifact 15072179850: fixed neck relief, coaxial wrist collar separation, forearm root taper, structural shoulder gusset and chest side facets. New renders and motion/attachment audits required before approval.")
    d["research_adaptations"].append({"recipe":"coaxial_joint_relief","url":"https://legacy.harmonicdrive.net/reference/applicationhandbook/display.php?id=ir_6apa","adaptation":"Separate fixed bearing housing and rotating output flange; retain fictional scale and pivots."})
    # V14 full-body shell design: all principal assemblies receive new shapes.
    # Keep interface rings, existing pivots, lower skid seats and optical aperture.
    for v in p["Head"]["vertices"]:
        if v[2] > .64 and abs(v[0]) > .12:
            v[0] *= .94
        if .485 < v[2] < .615 and abs(v[0]) > .175:
            v[0] *= .985
    for idx,ring in enumerate(p["Chest"]["rings"]):
        if idx in (2,3,4):
            for j in (2,3,6,7):
                ring[j][0] *= .94 if idx==3 else .97
            for j in (3,4,5,6):
                ring[j][1] *= .96
    # Circular fixed yaw seat stays separate from the rotating pitch support.
    for idx,ring in enumerate(p["Neck"]["rings"]):
        if idx==2:
            for v in ring:
                v[0]*=.81
                v[1]=.016+(v[1]-.016)*.83
    for idx,ring in enumerate(p["Pack"]["rings"]):
        if idx in (1,2):
            for j in (2,3,6,7):
                ring[j][0]*=.97
    for t in ("L","R"):
        for name in ("UpperArm","Forearm"):
            arm=p[name+t]
            # Taper hard-shell ends around the existing load-bearing core.
            for idx,section in enumerate(arm["sections"]):
                if idx in (1,2):
                    section[0]*=1.035 if name=="UpperArm" else .95
                    section[1]*=.94
        for ring in p["Antenna"+t]["rings"][1:-1]:
            for v in ring:
                v[0]*=.9
        for name in ("ClawTop","ClawLowerA","ClawLowerB"):
            claw=p[name+t]
            for section in claw["sections"][1:-1]:
                section[0]*=.94
                section[1]*=.93
        # Keep wheel shafts, treads, and attachment plane; sculpt the outer cover.
        hub=p["TrackHub"+t]
        for idx,ring in enumerate(hub["rings"]):
            if idx in (1,2):
                for v in ring:
                    v[1]*=.96
        # A more compact shoulder housing without touching the coaxial mount.
        for row in p["Shoulder"+t]["profile"][2:4]:
            row[0]*=.96
    d["design_notes"].append("V14 full-body candidate: head crown, neck, chest, pack, arms, antennae, claws, shoulder and track covers reconstructed; existing mechanical interfaces, tread and pivots retained. Texture Studio paint separate, visual approval pending.")
    # V15: functional recesses in the actual enclosure, not floating trim meshes.
    pack=p["Pack"]
    pack.setdefault("cuts",[]).append({"shape":"box","location":[0,.075,0],
        "size":[.077,.022,.105],"bevel":0})
    for s in (-1,1):
        # shallow lateral service socket below the shoulder, preserve load path
        p["Chest"].setdefault("cuts",[]).append({"shape":"box",
            "location":[s*.137,-.036,.259],"size":[.025,.083,.065],"bevel":0})
    # Relieve the upper fixed neck at the yaw support without moving the joints.
    for v in p["Neck"]["rings"][2]:
        v[0]*=.90
        v[1]=.010+(v[1]-.010)*.88
    d["design_notes"].append("V15: genuine rear service pocket and bilateral chest sockets; V14 interface and tread retained. Flat surface color, recessed detail only, independent game lighting.")
    d["research_adaptations"].append({"recipe":"service_recess","url":"https://www.rittal.com/us-en_US/Solutions/Rittal-Product-Solutions/Industrial-enclosure-solutions","adaptation":"Service-access panels and protected cooling recesses in robot enclosure."})
    write(Path(dest),d)
if __name__=="__main__":prepare(sys.argv[1],sys.argv[2])
