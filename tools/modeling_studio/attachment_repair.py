"""CRATE V17 independent track wheels supervised repair: actual supports, not geometric surface decoration."""
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
    p["Chest"]["cleanup_distance"]=.000001
    # Relieve the upper fixed neck at the yaw support without moving the joints.
    for v in p["Neck"]["rings"][2]:
        v[0]*=.90
        v[1]=.010+(v[1]-.010)*.88
    d["design_notes"].append("V15: genuine rear service pocket and bilateral chest sockets; V14 interface and tread retained. Flat surface color, recessed detail only, independent game lighting.")
    d["research_adaptations"].append({"recipe":"service_recess","url":"https://www.rittal.com/us-en_US/Solutions/Rittal-Product-Solutions/Industrial-enclosure-solutions","adaptation":"Service-access panels and protected cooling recesses in robot enclosure."})
    # V16: explicit fixed housing / rotating output interfaces.
    # Preserve all existing pivot transforms and the exterior optical shell.
    # The fixed neck pedestal previously extended into the moving yaw bracket.
    for idx,z in ((1,.4285),(2,.434)):
        for v in p["Neck"]["rings"][idx]:v[2]=z
    b=p["NeckYawBearing"]
    b.pop("radius");b.pop("depth")
    b.update(shape="revolve",profile=[[.035,-.0175],[.061,-.0175],
        [.066,-.013],[.066,.013],[.061,.0175],[.035,.0175]],bevel=.0005)
    # Axial output sleeve seats into the fixed bearing and carries pitch support.
    a=iv.append_part(d,"NeckYawOutput","NeckYaw","steel","revolve",[0,0,.011],
        profile=[[.014,-.014],[.0348,-.014],[.0348,.016],[.014,.016]],
        sides=20,rotation_deg=[0,0,0])
    a["bevel"]=.0003
    for idx,z in ((0,-.010),(1,-.006)):
        for v in p["NeckPitchSupport"]["rings"][idx]:v[2]=z
    pair("NeckYawBearing","Neck")
    pair("NeckYawOutput","NeckYawBearing")
    pair("NeckPitchSupport","NeckYawOutput")
    for t in ("L","R"):
        # Seat coaxial shafts within the existing bored housings.
        p["ShoulderAxle"+t]["radius"]=.0287
        p["ElbowAxle"+t]["radius"]=.0193
        # Two load-bearing yoke branches join the upper-arm core, rather
        # than terminating as isolated ornamental rings at the hinge.
        for suffix,sign in (("A",1),("B",-1)):
            fork=p["ElbowFork"+t+suffix]
            fork["path"][0]=[sign*.022,.054,.012]
            fork["path"][1]=[sign*.010,.027,.008]
            fork["sections"]=[[.010,.021],[.009,.024],[.007,.026]]
        # Taper the proximal shell where it passes the fixed yoke.
        fore=p["Forearm"+t]
        fore["sections"][0]=[.022,.024]
        fore["sections"][1]=[.039,.035]
        # Wrist is an actual bored housing and a separate tool output shaft.
        # Shift the fixed front face behind the rotating claw hinge pins.
        wb=p["WristBearing"+t]
        wb["location"][1]+=.009
        wb.pop("radius");wb.pop("depth")
        wb.update(shape="revolve",profile=[[.0222,-.014],[.032,-.014],
            [.036,-.010],[.036,.010],[.032,.014],[.0222,.014]],bevel=.0005)
        wa=p["WristAxle"+t]
        wa["location"][1]=.0025;wa["depth"]=.055;wa["bevel"]=.0005
        pair("WristBearing"+t,"WristAxle"+t)
    d["design_notes"].append("V16: distinct yaw pedestal/bored bearing/output sleeve; seated shoulder and elbow axles, inward-rooted elbow forks, proximal forearm clearance, bored wrist housing and shortened output shaft. All pivot transforms and sweep limits unchanged. Fresh connection and interference audits required.")
    d["research_adaptations"].append({"recipe":"separate_rotor_stator","url":"https://www.harmonicdrive.net/_hd/content/applicationHandbooks/6AxisPrimaryAxes.pdf","adaptation":"Fixed housings, supported coaxial outputs and explicit shaft fits; fictional dimensions, not engineering load validation."})
    # V17: resolve buried track wheels, not a cosmetic axial offset alone.
    # Include supports appended during V11/V16 before looking them up.
    p={a["name"]:a for a in d["parts"]}
    # V16 actual source: end R77 / road R46, center distance 84.86mm,
    # 38.14mm radial overlap. Preserve the end wheel and track path.
    for s,t in ((-1,"L"),(1,"R")):
        for i,y in enumerate((-.084,0,.084)):
            k=t+str(i)
            roller=p["TrackRoadRoller"+k]
            roller["location"][1:]=[y,.072]
            roller["profile"]=[[.014,-.041],[.035,-.041],[.035,-.010],
                [.026,-.010],[.026,.010],[.035,.010],[.035,.05512],[.014,.05512]]
            # Both original wheel axes point +X; mirror axial profile on L.
            if s<0:
                for row in roller["profile"]:row[1]*=-1
            rim=p["TrackRoadRim"+k]
            rim["location"]=[s*.270,y,.072]
            rim["radius"]=.0255
            hub=p["TrackRoadHub"+k]
            hub["location"]=[s*.277,y,.072]
            shaft=p["TrackRoadShaft"+k]
            shaft["location"]=[s*.219,y,.072]
            shaft["depth"]=.116
            # New inboard bearing seat bridges the lowered axle to frame.
            # Axial envelope .145-.169, roller starts at .171.
            name="TrackRoadBearingMount"+k
            a=iv.append_part(d,name,"BodyRoot","frame","box",
                [s*.157,y,.089],size=[.024,.029,.042])
            a["bevel"]=0
            pair(name,"TrackSupportFrame"+t)
            pair(name,"TrackRoadShaft"+k)
            # The lowered axle now connects to the frame through its seat.
            # Replace (not merely ignore) the previous direct shaft-frame check.
            checks[:]=[c for c in checks if not(c["part"]=="TrackRoadShaft"+k and c["support"]=="TrackSupportFrame"+t)]
        for prefix in ("FrontWheel","RearWheel"):
            wheel=p[prefix+t]
            # Extend only the outer axial flange; keep tread guide groove centered.
            for row in wheel["profile"]:
                if row[1]*s>.04:row[1]=s*.055
            for suffix in ("Rim","Hub","Axle"):
                p[prefix+suffix+t]["location"][0]+=s*.004
            p["Track"+prefix+"Shaft"+t]["depth"]=.116
        # Bottom of frame clears the new roller envelope by 1mm.
        for idx,z in ((0,-.014),(1,-.012)):
            for v in p["TrackSupportFrame"+t]["rings"][idx]:v[2]=z
        cover=p["TrackHub"+t]
        cover["location"][2]+=.003
        for ring in cover["rings"]:
            for v in ring:v[2]*=.8
        for i in range(2):p["TrackCoverSupport"+t+str(i)]["location"][2]+=.003
    # Enforce the design-space projection gaps before Blender authoring.
    import math
    gap=math.hypot(.197-.084,.114-.072)-.077-.035
    assert gap>.008 and .084-2*.035>.01
    assert .139-.028*.8-(.072+.035)>.009
    d["track_design"]["road_roller_radius"]=.035
    d["track_design"]["road_roller_centers_y"]=[-.084,0,.084]
    d["track_design"]["road_roller_center_z"]=.072
    d["track_design"]["wheel_to_roller_nominal_gap_m"]=gap
    d["design_notes"].append("V17: independent road rollers R35 centered at +/-84mm and z72mm; end-wheel radius and track path unchanged. Outer wheel flange/rims exposed, inboard bearing seats and slim lifted side cover. Nominal radial end-wheel gap 8.55mm, center roller gap 14mm, cover gap 9.6mm. Actual rendered clearance and interference require review.")
    d["research_adaptations"].append({"recipe":"independent_track_roller_support","url":"https://parts.cat.com/en/catcorp/by-industry-building-construction","adaptation":"Distinct end wheel, road roller and shaft support; retain authored endless belt geometry."})
    # V17.2: preserve the optical opening and mounts while rebuilding
    # the head envelope as parallel-edge, planar octagonal sections.
    h=p["Head"]["vertices"]
    def section(r):
        a=h[r*8:r*8+8]
        return (max(v[0] for v in a),min(v[1] for v in a),
                max(v[1] for v in a),a[0][2])
    def octagon(x,f,b,z,c):
        assert 0<c<min(x,(b-f)/2)
        return [[-x+c,f,z],[x-c,f,z],[x,f+c,z],[x,b-c,z],
                [x-c,b,z],[-x+c,b,z],[-x,b-c,z],[-x,f+c,z]]
    # Match each octagonal corner direction at 45 degrees in XY.
    # Retain front/rear extrema and face recess vertices 48..59.
    for r,c in enumerate((.029,.023,.032,.037,.034,.023)):
        x,f,b,z=section(r)
        h[r*8:r*8+8]=octagon(x,f,b,z,c)
    # The optical aperture must remain inside its planar front frame.
    assert min(h[9][0],h[17][0])>.157
    # V17.1: avoid the bevel clamp collapsing the 2mm lower frame band.
    # The source audit found 16 zero-UV triangles in the two frames.
    for t in ("L","R"):
        frame=p["TrackSupportFrame"+t]
        frame["bevel"]=.00045
        frame["cleanup_distance"]=.000001
    # Verify authored diagonal quads (before bevel, independent of renderer).
    import math
    def sub(a,b):return [x-y for x,y in zip(a,b)]
    def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
    residual=[]
    for r in range(5):
        for j in range(8):
            k=(j+1)%8
            a,b,c,e=h[r*8+j],h[r*8+k],h[(r+1)*8+j],h[(r+1)*8+k]
            n=cross(sub(b,a),sub(c,a));length=math.sqrt(sum(v*v for v in n))
            assert length>1e-10
            residual.append(abs(sum(x*y for x,y in zip(n,sub(e,a))))/length)
    assert max(residual)<1e-8
    d["head_planarity_audit"]={"authored_quads":len(residual),"max_residual_m":max(residual),"chamfer_xy_degrees":45,"scope":"before bevel; actual rendered review required"}
    d["design_notes"].append("V17.2: planar head octagonal sections, matched diagonal orientation; optical opening and mounts retained; support frame bevel reduced and opt-in cleanup added after V17.1 UV degeneration.")
    write(Path(dest),d)
if __name__=="__main__":prepare(sys.argv[1],sys.argv[2])
