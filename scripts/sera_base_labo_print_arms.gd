extends RefCounted
## Compact version of LABO's full-size three articulated print robots.
## Coordinates are BASE local metres, before the existing yaw and scale.
## Geometry is submitted to the existing MultiMesh batches; no new render nodes.
const BED := Vector3(0.10,0,1.13)
const MOUNTS := [Vector3(-1.27,0,0.93),Vector3(1.43,0,0.42),Vector3(0.55,0,-0.18)]
const SHOULDER_Y: float = 1.24
const UPPER: float = 0.88
const FORE: float = 0.86
const TOOL: float = 0.22
const GROUPS := ["Yaw","Shoulder","Upper","Elbow","Fore","Wrist","Tool"]

static func feature(index: int, group: String) -> String:
    return "LabPrint%d_%s" % [index,group]

static func features() -> Array:
    var result: Array = []
    for i in range(3):
        for group in GROUPS:
            result.append(feature(i,group))
    return result

static func _joint(g: Variant, index: int, group: String, radius: float, width: float) -> void:
    var at: Vector3 = MOUNTS[index]
    var f: String = feature(index,group)
    g.poly_tilt(f,"drum",at,Vector3(radius*2.0,width,radius*2.0),"slate",Vector3(0,0,PI*0.5))
    for side in [-1.0,1.0]:
        g.poly_tilt(f,"octagonal_slew",at+Vector3(float(side)*(width*0.5+0.018),0,0),Vector3(radius*1.55,0.044,radius*1.55),"armor_light",Vector3(0,0,PI*0.5))
        g.poly_tilt(f,"drum",at+Vector3(float(side)*(width*0.5+0.043),0,0),Vector3(radius*0.68,0.032,radius*0.68),"gold",Vector3(0,0,PI*0.5))

static func _link(g: Variant, index: int, group: String, length: float, width: float) -> void:
    var at: Vector3 = MOUNTS[index]
    var f: String = feature(index,group)
    g.poly(f,"bevel",at+Vector3(0,length*0.5,0),Vector3(width,length-0.10,width*0.74),"armor")
    for side in [-1.0,1.0]:
        g.box(f,at+Vector3(float(side)*width*0.49,length*0.5,0),Vector3(0.032,length-0.16,width*0.60),"slate")
        g.rod(f,at+Vector3(float(side)*width*0.39,0.09,-width*0.42),at+Vector3(float(side)*width*0.39,length-0.09,-width*0.42),0.036,"edge")
    g.box(f,at+Vector3(0,length*0.5,width*0.39),Vector3(width*0.36,length*0.42,0.020),"lab_cyan")

static func build(g: Variant) -> void:
    for i in range(3):
        var at: Vector3 = MOUNTS[i]
        g.poly("LabPrintMount","bevel",at+Vector3(0,0.66,0),Vector3(0.46,0.14,0.46),"slate")
        g.poly("LabPrintBearing","drum",at+Vector3(0,0.79,0),Vector3(0.40,0.12,0.40),"edge")
        g.poly("LabPrintPedestal","octagonal_slew",at+Vector3(0,0.94,0),Vector3(0.34,0.20,0.34),"armor")
        for x in [-0.17,0.17]:
            for z in [-0.17,0.17]:
                g.poly("LabPrintMountBolt","drum",at+Vector3(x,0.745,z),Vector3(0.045,0.035,0.045),"gold")
        g.poly(feature(i,"Yaw"),"bevel",at+Vector3(0,-0.09,0),Vector3(0.26,0.22,0.26),"slate")
        _joint(g,i,"Shoulder",0.155,0.25)
        _link(g,i,"Upper",UPPER,0.22)
        _joint(g,i,"Elbow",0.13,0.22)
        _link(g,i,"Fore",FORE,0.17)
        _joint(g,i,"Wrist",0.085,0.15)
        var f: String = feature(i,"Tool")
        g.poly(f,"bevel",at+Vector3(0,0.055,0),Vector3(0.17,0.11,0.17),"slate")
        g.poly(f,"octagonal_slew",at+Vector3(0,0.13,0),Vector3(0.15,0.07,0.15),"gold")
        g.poly(f,"drum",at+Vector3(0,0.185,0),Vector3(0.07,0.045,0.07),"edge")
        g.poly(f,"drum",at+Vector3(0,0.215,0),Vector3(0.042,0.01,0.042),"lab_cyan")
        g.poly(f,"bevel",at+Vector3(0.10,0.075,0),Vector3(0.055,0.08,0.075),"gold")
        g.box(f,at+Vector3(0.132,0.075,0),Vector3(0.012,0.045,0.037),"lab_cyan")

static func _frame(a: Vector3,b: Vector3,hinge: Vector3) -> Transform3D:
    var y: Vector3 = (b-a).normalized()
    var z: Vector3 = hinge.cross(y).normalized()
    var x: Vector3 = y.cross(z).normalized()
    return Transform3D(Basis(x,y,z),a)

static func poses(index: int, t: float, active: bool) -> Dictionary:
    var root: Vector3 = MOUNTS[index]
    var radial: Vector3 = (root-BED).normalized()
    var tangent: Vector3 = Vector3.UP.cross(radial)
    # Distinct sectors keep the nozzle heads apart. The front remains open
    # for the existing independent SCARA and its continuous workpiece.
    var blend: float = 0.0
    if active:
        blend = smoothstep(0.04+float(index)*0.07,0.55,t)*(1.0-smoothstep(6.0,6.85-float(index)*0.12,t))
    var phase: float = t*TAU/1.15+float(index)*2.094
    var progress: float = clampf((t-0.35)/5.65,0.025,1.0)
    var work: Vector3 = BED+radial*(0.27+0.045*cos(phase))+tangent*(0.085*sin(phase))
    work.y = maxf(0.98,0.86+0.40*progress+0.065)
    var park: Vector3 = root-radial*0.28+Vector3.UP*2.23
    var tip: Vector3 = park.lerp(work,blend)
    var tool_axis: Vector3 = (Vector3.DOWN-radial*0.13*blend).normalized()
    var shoulder: Vector3 = root+Vector3.UP*SHOULDER_Y
    var wrist: Vector3 = tip-tool_axis*TOOL
    var reach: Vector3 = wrist-shoulder
    var d: float = clampf(reach.length(),0.12,UPPER+FORE-0.015)
    var along: Vector3 = reach.normalized()
    wrist = shoulder+along*d
    tip = wrist+tool_axis*TOOL
    var perpendicular: Vector3 = (Vector3.UP-along*along.dot(Vector3.UP)).normalized()
    var projected: float = (UPPER*UPPER-FORE*FORE+d*d)/(2.0*d)
    var rise: float = sqrt(maxf(0.0,UPPER*UPPER-projected*projected))
    var elbow: Vector3 = shoulder+along*projected+perpendicular*rise
    var hinge: Vector3 = along.cross(perpendicular).normalized()
    var a: Transform3D = _frame(shoulder,elbow,hinge)
    var b: Transform3D = _frame(elbow,wrist,hinge)
    var c: Transform3D = _frame(wrist,tip,hinge)
    return {"Yaw":Transform3D(Basis(Vector3.UP,atan2(-along.x,-along.z)),shoulder),
        "Shoulder":a,"Upper":a,"Elbow":b,"Fore":b,"Wrist":c,"Tool":c}

static func apply_pose(rest: Transform3D,index: int,group: Transform3D,body_yaw: float,model_scale: float) -> Transform3D:
    # All authored group offsets are measured relative to their mount. Apply
    # the rigid group transform once, including every bolt, rail and light.
    var body := Basis(Vector3.UP,body_yaw)
    var rotation: Basis = body*group.basis*body.inverse()
    var origin: Vector3 = body*(group.origin*model_scale)
    var mount: Vector3 = body*(MOUNTS[index]*model_scale)
    return Transform3D(rotation*rest.basis,origin+rotation*(rest.origin-mount))
