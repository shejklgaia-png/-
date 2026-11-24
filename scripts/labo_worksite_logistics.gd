extends RefCounted
## Room-local industrial logistics. All visible handoffs use one payload node.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const BOX_SIZE := Vector3(2.78,1.55,3.50)
const DECK_Y := 1.17
const IN_END := 0.29
const OUT_START := 0.72
var room: Node3D
var root: Node3D
var key: String
var inlet: Vector3
var outlet: Vector3
var in_dock: Vector3
var out_dock: Vector3
var in_far: Vector3
var out_far: Vector3
var truck_in: Node3D
var truck_out: Node3D
var in_box: Node3D
var out_box: Node3D
var raw: Node3D
var finished: Node3D
var in_arm: Dictionary
var out_arm: Dictionary
var reserves: Array[AABB] = []
var storage_slots: Array[Node3D] = []
var occupied: Array[bool] = []
var store_index: int = -1
var take_index: int = -1
var pack: Node3D
var pack_lid: Node3D
var pack_raw: Node3D
var shelf_box: Node3D
var shelf_mast: Node3D
var shelf_carriage: Node3D
var shelf_fork: Node3D
var shelf_beam: Node3D
var rng := RandomNumberGenerator.new()
var storage_committed := false
var storage_removed := false
var storage_delivered := false
var input_finished := false
var retrieve_only := false
var stacker_start := Vector3.ZERO
var storage_pack_point := Vector3(-9.0,1.10,7.7)
var storage_out_point := Vector3(8.8,1.10,7.7)
var aisle_z: float = 0.8

func _node(parent: Node3D, label: String, p: Vector3 = Vector3.ZERO) -> Node3D:
    var n := Node3D.new()
    n.name = label
    parent.add_child(n)
    n.position = p
    return n

func _batch(parent: Node3D):
    var b := Architecture.Batch.new(parent)
    b.outline_enabled = true
    return b

func _box(b,p: Vector3,s: Vector3,c: String = "slate") -> void:
    b.box("LogisticsPanel",p,s,c)

func _poly(b,k: String,p: Vector3,s: Vector3,c: String = "armor") -> void:
    b.poly("LogisticsPart",k,p,s,c)

func _rod(b,a: Vector3,z: Vector3,d: float,c: String = "edge") -> void:
    b.rod("LogisticsRail",a,z,d,c)

func _finish(b) -> void:
    b.flush()

func _carrier(label: String) -> Node3D:
    var n := _node(root,label)
    var chassis := _node(n,"BaseCarrierChassis")
    chassis.scale = Vector3.ONE*3.0
    var b = _batch(chassis)
    _poly(b,"bevel",Vector3(0,0.32,0),Vector3(0.94,0.14,1.30),"slate")
    _box(b,Vector3(0,0.20,0),Vector3(0.53,0.18,1.02),"dark")
    for side in [-1.0,1.0]:
        var x: float = side*0.34
        _poly(b,"bevel",Vector3(x,0.13,0),Vector3(0.24,0.32,1.17),"rubber")
        for z in [-0.40,-0.13,0.13,0.40]:
            b.poly_tilt("CarrierRoller","drum",Vector3(side*0.468,0.13,z),Vector3(0.22,0.055,0.22),"edge",Vector3(0,0,PI*0.5))
        _box(b,Vector3(side*0.47,0.29,0),Vector3(0.035,0.10,1.12),"trim")
        _box(b,Vector3(side*0.34,0.33,0.66),Vector3(0.16,0.055,0.035),"blue_light")
        _box(b,Vector3(side*0.35,0.30,-0.66),Vector3(0.13,0.055,0.035),"amber")
    _poly(b,"bevel",Vector3(0,0.23,0.67),Vector3(0.32,0.22,0.13),"slate")
    b.poly_tilt("CarrierSensorLens","drum",Vector3(0,0.23,0.75),Vector3(0.15,0.045,0.15),"blue_light",Vector3(PI*0.5,0,0))
    for side in [-1.0,1.0]:
        for z in [-0.48,0.48]:
            _box(b,Vector3(side*0.44,0.40,z),Vector3(0.07,0.065,0.11),"edge")
        for i in range(10):
            _box(b,Vector3(side*0.34,0.29,-0.52+float(i)*0.115),Vector3(0.22,0.028,0.045),"edge")
    _finish(b)
    return n

# The same shell is used on every carrier, at packing, and in every shelf bay.
func _container(parent: Node3D,label: String,closed: bool) -> Node3D:
    var n := _node(parent,label)
    var b = _batch(n)
    _box(b,Vector3(0,0.07,0),Vector3(BOX_SIZE.x,0.14,BOX_SIZE.z),"slate")
    for side in [-1.0,1.0]:
        _box(b,Vector3(side*1.34,0.80,0),Vector3(0.10,1.46,3.50),"armor")
        _box(b,Vector3(0,0.80,side*1.70),Vector3(2.58,1.46,0.10),"armor")
        for z in [-1.55,1.55]:
            _box(b,Vector3(side*1.35,0.78,z),Vector3(0.14,1.55,0.14),"edge")
        _box(b,Vector3(side*1.35,1.49,0),Vector3(0.15,0.12,3.50),"gold")
        for z in [-0.92,0.0,0.92]:
            _box(b,Vector3(side*1.40,0.78,z),Vector3(0.035,1.18,0.14),"slate")
        for z in [-1.42,1.42]:
            _box(b,Vector3(side*1.40,0.30,z),Vector3(0.035,0.18,0.22),"edge")
    _box(b,Vector3(0,0.83,1.76),Vector3(0.65,0.24,0.08),"lab_cyan")
    _finish(b)
    var lid := _node(n,"Lid")
    b = _batch(lid)
    _poly(b,"deck",Vector3(0,0.08,0),Vector3(2.78,0.16,3.50),"armor_light")
    _box(b,Vector3(0,0.18,0),Vector3(0.85,0.06,0.18),"gold")
    _finish(b)
    lid.position.y = 1.55
    lid.visible = closed
    return n

func _material(parent: Node3D,label: String) -> Node3D:
    var n := _node(parent,label)
    var b = _batch(n)
    _poly(b,"octagonal_slew",Vector3(-0.37,0.31,0.08),Vector3(0.66,0.62,0.72),"slate")
    _poly(b,"gear",Vector3(0.36,0.22,-0.22),Vector3(0.70,0.38,0.70),"rust")
    _box(b,Vector3(0.24,0.20,0.36),Vector3(0.55,0.34,0.46),"blue")
    _finish(b)
    return n

func _support_floor(p: Vector3) -> float:
    # Raised LABO/STORAGE platform top is y=0; surrounding deck is y=-0.32.
    if key=="LABO":
        return 0.0 if Rect2(-15.2,-10.9,29.0,24.0).has_point(Vector2(p.x,p.z)) else -0.35
    if key=="STORAGE":
        return 0.0 if Rect2(-15.4,-10.0,30.0,25.0).has_point(Vector2(p.x,p.z)) else -0.35
    return -0.03

func _gantry(label: String,a: Vector3,z: Vector3,height: float) -> Dictionary:
    var n := _node(root,label)
    var direction := Vector3(z.x-a.x,0,z.z-a.z)
    var length: float = maxf(0.1,direction.length())
    var axis: Vector3 = direction/length
    var side := Vector3(axis.z,0,-axis.x)
    var b = _batch(n)
    # Two braced portals support a continuous twin-rail bridge. Keep the
    # second portal short of the machine opening so no column blocks loading.
    var rail_y: float = height+0.55
    var portal_span: float = 2.18
    var inner: Vector3 = a+axis*minf(length*0.58,maxf(0.0,length-2.5))
    var start := Vector3(a.x,rail_y,a.z)-axis*0.65
    var end := Vector3(z.x,rail_y,z.z)+axis*0.65
    for offset in [-0.43,0.43]:
        var lateral: Vector3 = side*float(offset)
        _rod(b,start+lateral,end+lateral,0.34,"slate")
        _rod(b,start+lateral+Vector3.UP*0.42,end+lateral+Vector3.UP*0.42,0.18,"edge")
        _rod(b,start+lateral-Vector3.UP*0.20,end+lateral-Vector3.UP*0.20,0.12,"gold")
    var ribs: int = maxi(2,ceili(length/1.15))
    for i in range(ribs+1):
        var p: Vector3 = start.lerp(end,float(i)/float(ribs))
        _rod(b,p-side*0.57+Vector3.UP*0.42,p+side*0.57+Vector3.UP*0.42,0.17,"armor_light")
        if i<ribs:
            var q: Vector3 = start.lerp(end,float(i+1)/float(ribs))
            for sign_value in [-1.0,1.0]:
                var lateral: Vector3 = side*float(sign_value)*0.43
                _rod(b,p+lateral,q+lateral+Vector3.UP*0.42,0.12,"trim")
    for portal in [a,inner]:
        var center: Vector3 = portal
        for sign_value in [-1.0,1.0]:
            var foot: Vector3 = center+side*float(sign_value)*portal_span
            foot.y = _support_floor(foot)
            var top := Vector3(foot.x,rail_y+0.42,foot.z)
            var post_height: float = top.y-foot.y
            _poly(b,"bevel",foot+Vector3.UP*0.18,Vector3(0.84,0.36,0.84),"armor")
            _box(b,foot+Vector3.UP*(post_height*0.5),Vector3(0.46,post_height,0.46),"slate")
            for side_sign in [-1.0,1.0]:
                _rod(b,foot+side*float(side_sign)*0.24+Vector3.UP*0.30,top+side*float(side_sign)*0.24,0.12,"armor_light")
            for sx in [-0.29,0.29]:
                for sz in [-0.29,0.29]:
                    _poly(b,"drum",foot+Vector3(sx,0.38,sz),Vector3(0.13,0.10,0.13),"edge")
            _box(b,foot+Vector3.UP*1.15,Vector3(0.50,0.18,0.50),"gold")
            var joint := Vector3(center.x,rail_y+0.42,center.z)
            _rod(b,top,joint,0.48,"armor")
            _rod(b,top-Vector3.UP*1.05,top.lerp(joint,0.63),0.22,"trim")
            reserves.append(AABB(foot-Vector3(0.46,0,0.46),Vector3(0.92,2.4,0.92)))
    # Drive station and hard end stops terminate the rails rather than floating.
    for at in [start,end]:
        var p: Vector3 = at
        _rod(b,p-side*0.65,p+side*0.65,0.30,"armor")
        _poly(b,"bevel",p+Vector3.UP*0.28,Vector3(0.75,0.50,0.75),"slate")
    _finish(b)
    var trolley := _node(n,"LinearTrolley")
    b = _batch(trolley)
    _poly(b,"bevel",Vector3(0,0.08,0),Vector3(0.92,0.56,0.92),"armor_light")
    # Wheel bogies straddle the two rails; hanger reaches their lower flanges.
    for lateral in [-0.43,0.43]:
        for longitudinal in [-0.30,0.30]:
            var p: Vector3 = side*float(lateral)+axis*float(longitudinal)+Vector3.UP*0.38
            _poly(b,"drum",p,Vector3(0.29,0.34,0.29),"edge")
            _rod(b,p,Vector3(p.x,0.12,p.z),0.18,"slate")
    _box(b,Vector3(0,0.08,0.47),Vector3(0.42,0.14,0.06),"lab_cyan")
    _finish(b)
    var stem := _node(trolley,"TelescopingVerticalArm")
    b = _batch(stem)
    _box(b,Vector3(0,-0.5,0),Vector3(0.30,1.0,0.30),"edge")
    # Outer sleeve and inner ram overlap at every extension; no free gripper.
    var sleeve := _node(trolley,"FixedRamSleeve")
    var sb = _batch(sleeve)
    _poly(sb,"bevel",Vector3(0,-0.28,0),Vector3(0.48,0.64,0.48),"slate")
    _poly(sb,"drum",Vector3(0,-0.58,0),Vector3(0.44,0.12,0.44),"gold")
    _finish(sb)
    _finish(b)
    var grip := _node(trolley,"Gripper")
    var crossbar := _node(grip,"AdjustableCrossbar")
    b = _batch(crossbar)
    _box(b,Vector3(0,0.15,0),Vector3(0.95,0.20,0.48),"gold")
    _box(b,Vector3(0,0.025,0),Vector3(0.65,0.05,0.38),"edge")
    for x in [-0.26,0.26]:
        _poly(b,"drum",Vector3(x,0.05,0),Vector3(0.19,0.10,0.22),"dark")
    _finish(b)
    var jaws: Array[Node3D] = []
    for side_value in [-1.0,1.0]:
        var jaw := _node(grip,"JawLeft" if float(side_value)<0 else "JawRight")
        b = _batch(jaw)
        # Magnetic face contacts the upper surface; guide jaws never sink into cargo.
        _box(b,Vector3(0,0.25,0),Vector3(0.12,0.46,0.45),"edge")
        _finish(b)
        jaws.append(jaw)
    return {"trolley":trolley,"stem":stem,"grip":grip,"height":height,"jaws":jaws,"crossbar":crossbar}

func _arm_pose(arm: Dictionary,p: Vector3,span: float = 0.75) -> void:
    var trolley: Node3D = arm["trolley"]
    var stem: Node3D = arm["stem"]
    var grip: Node3D = arm["grip"]
    var h: float = float(arm["height"])
    trolley.position = Vector3(p.x,h,p.z)
    var d: float = maxf(0.74,h-p.y)
    stem.scale.y = d+0.05
    grip.position.y = -d
    span = minf(span,2.20)
    (arm["crossbar"] as Node3D).scale.x = maxf(1.0,(span+0.16)/0.95)
    var jaws: Array = arm["jaws"]
    (jaws[0] as Node3D).position.x = -span*0.5
    (jaws[1] as Node3D).position.x = span*0.5

func _transfer(a: Vector3,b: Vector3,h: float,u: float) -> Vector3:
    # Lift, horizontal transfer, then lower. No diagonal shortcuts through stock.
    var high_a := Vector3(a.x,h,a.z)
    var high_b := Vector3(b.x,h,b.z)
    if u<0.28:
        return a.lerp(high_a,smoothstep(0.0,0.28,u))
    if u<0.72:
        return high_a.lerp(high_b,smoothstep(0.28,0.72,u))
    return high_b.lerp(b,smoothstep(0.72,1.0,u))

func _truck_pose(n: Node3D,a: Vector3,b: Vector3,u: float,reverse: bool = false) -> void:
    n.position = a.lerp(b,smoothstep(0.0,1.0,u))
    var direction: Vector3 = b-a
    if reverse:
        direction = -direction
    if direction.length_squared()>0.001:
        n.rotation.y = atan2(direction.x,direction.z)

func _lane(a: Vector3,b: Vector3) -> void:
    var lo := Vector3(minf(a.x,b.x)-1.60,-0.5,minf(a.z,b.z)-2.15)
    var hi := Vector3(maxf(a.x,b.x)+1.60,2.5,maxf(a.z,b.z)+2.15)
    reserves.append(AABB(lo,hi-lo))

func build(parent: Node3D,section: String,source: Vector3,destination: Vector3) -> void:
    room = parent
    key = section
    root = _node(room,"WorksiteLogistics")
    rng.randomize()
    inlet = source
    outlet = destination
    var ground: float = -0.32 if key in ["LABO","STORAGE"] else 0.0
    match key:
        "LABO":
            in_dock = Vector3(inlet.x,ground,17.0)
            out_dock = Vector3(outlet.x,ground,17.0)
        "SMELTER":
            in_dock = Vector3(inlet.x,ground,14.3)
            out_dock = Vector3(outlet.x,ground,14.3)
        "RECYCLER":
            in_dock = Vector3(inlet.x,ground,-23.0)
            out_dock = Vector3(outlet.x,ground,14.0)
        "STORAGE":
            inlet = storage_pack_point+Vector3.UP*0.14
            outlet = storage_out_point
            in_dock = Vector3(inlet.x,ground,18.0)
            out_dock = Vector3(outlet.x,ground,18.0)
            _build_storage()
    in_far = in_dock+Vector3(0,0,-7.0 if key=="RECYCLER" else 7.0)
    out_far = out_dock+Vector3(0,0,7.0)
    _lane(in_dock,in_far)
    _lane(out_dock,out_far)
    truck_in = _carrier("InboundCarrier")
    truck_out = _carrier("OutboundCarrier")
    in_box = _container(truck_in,"TransportContainer",false)
    out_box = _container(truck_out,"TransportContainer",false)
    in_box.position.y = DECK_Y
    out_box.position.y = DECK_Y
    raw = _material(root,"InboundRawMaterial")
    var h_in: float = maxf(8.5,inlet.y+4.0)
    var h_out: float = maxf(8.5,outlet.y+4.0)
    in_arm = _gantry("InboundTransferArm",in_dock,inlet,h_in)
    out_arm = _gantry("OutboundTransferArm",out_dock,outlet,h_out)
    _arm_pose(in_arm,Vector3(in_dock.x,h_in-0.55,in_dock.z))
    _arm_pose(out_arm,Vector3(outlet.x,h_out-0.55,outlet.z))
    _truck_pose(truck_in,in_far,in_dock,0.0)
    _truck_pose(truck_out,out_far,out_dock,0.0)
    truck_in.visible = false
    truck_out.visible = false
    raw.visible = false

func _room_position(n: Node3D) -> Vector3:
    return root.to_local(n.global_position)

func _place(n: Node3D,p: Vector3) -> void:
    n.global_position = root.to_global(p)

func _in_pick() -> Vector3:
    return in_dock+Vector3.UP*(DECK_Y+0.14)

func _out_drop() -> Vector3:
    return out_dock+Vector3.UP*(DECK_Y+(0.0 if key=="STORAGE" else 0.14))

func duration() -> float:
    return 48.0 if key=="STORAGE" else 26.0

func begin() -> void:
    input_finished = false
    reset()
    if key!="STORAGE":
        return
    var empty: Array[int] = []
    var full: Array[int] = []
    for i in range(occupied.size()):
        if occupied[i]:
            full.append(i)
        else:
            empty.append(i)
    store_index = empty[rng.randi_range(0,empty.size()-1)] if not empty.is_empty() else -1
    take_index = full[rng.randi_range(0,full.size()-1)] if not full.is_empty() else store_index
    retrieve_only = empty.is_empty() and not full.is_empty()
    if retrieve_only:
        store_index = take_index
    storage_committed = retrieve_only
    storage_removed = false
    storage_delivered = false
    stacker_start = Vector3(shelf_mast.position.x,shelf_carriage.position.y,aisle_z)

func reset() -> void:
    truck_in.visible = false
    truck_out.visible = false
    raw.visible = false
    raw.scale = Vector3.ONE
    _arm_pose(in_arm,Vector3(in_dock.x,float(in_arm["height"])-0.55,in_dock.z))
    _arm_pose(out_arm,Vector3(outlet.x,float(out_arm["height"])-0.55,outlet.z))
    if key=="STORAGE":
        if storage_removed and not storage_delivered and take_index>=0:
            occupied[take_index] = true
        storage_removed = false
        pack.visible = false
        shelf_box.visible = false
        pack_raw.visible = false
        for i in range(storage_slots.size()):
            storage_slots[i].visible = occupied[i]

func sample_in(t: float,payload: Node3D = null) -> void:
    truck_in.visible = t<0.29
    _truck_pose(truck_in,in_far,in_dock,smoothstep(0.0,0.09,t))
    if t>=0.23:
        _truck_pose(truck_in,in_dock,in_far,smoothstep(0.23,0.29,t),true)
    var load: Node3D = payload if payload!=null else raw
    var grasp_height: float = 0.95 if key=="RECYCLER" else (0.78 if key=="SMELTER" else 0.62)
    load.visible = t<IN_END
    if t<0.10:
        _place(load,_room_position(truck_in)+Vector3.UP*(DECK_Y+0.14))
    else:
        var u: float = smoothstep(0.12,0.23,t)
        var p: Vector3 = _transfer(_in_pick(),inlet,float(in_arm["height"])-2.2,u)
        _place(load,p)
        _arm_pose(in_arm,p+Vector3.UP*grasp_height)
    if t<0.12:
        var pick: Vector3 = _in_pick()+Vector3.UP*grasp_height
        _arm_pose(in_arm,Vector3(pick.x,lerpf(float(in_arm["height"])-0.5,pick.y,smoothstep(0.09,0.12,t)),pick.z))
    if t>=0.23:
        _arm_pose(in_arm,inlet+Vector3.UP*lerpf(grasp_height,float(in_arm["height"])-inlet.y-0.5,smoothstep(0.23,0.29,t)))
        if key=="LABO":
            # Drop the raw batch through the genuine open hopper mouth.
            var fall: float = smoothstep(0.23,0.29,t)
            _place(load,inlet-Vector3.UP*0.68*fall)
            load.scale = Vector3.ONE*(1.0-0.82*smoothstep(0.25,0.29,t))
    if t>=0.29:
        input_finished = true

func sample_out(t: float,payload: Node3D,payload_height: float = 1.35,payload_width: float = 1.0) -> void:
    truck_out.visible = t>=0.72 and t<1.0
    _truck_pose(truck_out,out_far,out_dock,smoothstep(0.72,0.81,t))
    if t>=0.94:
        _truck_pose(truck_out,out_dock,out_far,smoothstep(0.94,1.0,t),true)
    if payload==null:
        return
    if t>=0.81:
        var p: Vector3 = _transfer(outlet,_out_drop(),float(out_arm["height"])-payload_height-0.75,smoothstep(0.82,0.92,t))
        if t>=0.94:
            p = _room_position(truck_out)+Vector3.UP*(DECK_Y+(0.0 if key=="STORAGE" else 0.14))
        _place(payload,p)
        payload.visible = t<1.0
        _arm_pose(out_arm,p+Vector3.UP*payload_height,payload_width)
    else:
        var h: float = lerpf(float(out_arm["height"])-0.5,outlet.y+payload_height,smoothstep(0.72,0.81,t))
        _arm_pose(out_arm,Vector3(outlet.x,h,outlet.z),payload_width)
    if t>=0.92:
        var drop := _out_drop()
        _arm_pose(out_arm,Vector3(drop.x,lerpf(drop.y+payload_height,float(out_arm["height"])-0.5,smoothstep(0.92,0.94,t)),drop.z),payload_width)

func _build_storage() -> void:
    # Six independent bays, four levels. Front aisle is clear for the stacker.
    var rack := _node(root,"RandomAccessRack")
    var b = _batch(rack)
    for i in range(7):
        var x: float = -9.3+float(i)*3.10
        for z in [-7.2,-3.6]:
            _box(b,Vector3(x,6.25,z),Vector3(0.25,12.5,0.30),"slate")
    for level in range(4):
        var y: float = 0.65+float(level)*2.85
        # Two support rails per bay leave a real open channel for the forks.
        for col in range(6):
            var center_x: float = -7.75+float(col)*3.10
            for side in [-1.0,1.0]:
                _box(b,Vector3(center_x+float(side)*1.18,y,-5.4),Vector3(0.30,0.24,3.65),"armor")
                _box(b,Vector3(center_x+float(side)*1.18,y,-3.51),Vector3(0.31,0.19,0.15),"gold")
    _box(b,Vector3(0,12.45,-5.4),Vector3(18.9,0.25,3.9),"armor")
    _finish(b)
    for level in range(4):
        for col in range(6):
            var slot := _container(rack,"Stock_%d_%d"%[level,col],true)
            slot.position = Vector3(-7.75+float(col)*3.10,0.77+float(level)*2.85,-5.4)
            storage_slots.append(slot)
            var present: bool = posmod(level*3+col,4)!=0
            occupied.append(present)
            slot.visible = present
    reserves.append(AABB(Vector3(-9.6,0,-7.5),Vector3(19.2,2.4,4.0)))
    # Rail-guided stacker: travel in X, lift in Y, only the fork extends in Z.
    var rail := _node(root,"WarehouseStackerRail")
    b = _batch(rail)
    for z in [aisle_z-0.62,aisle_z+0.62]:
        _box(b,Vector3(0,0.08,z),Vector3(25.0,0.16,0.14),"edge")
    _box(b,Vector3(0,12.8,aisle_z),Vector3(25.0,0.28,0.50),"gold")
    for x in [-12.5,12.5]:
        _box(b,Vector3(x,6.4,aisle_z),Vector3(0.45,12.8,0.55),"slate")
    _finish(b)
    shelf_mast = _node(root,"StackerTravelMast")
    b = _batch(shelf_mast)
    for x in [-1.50,1.50]:
        _box(b,Vector3(x,6.1,0),Vector3(0.24,12.2,0.32),"slate")
    _box(b,Vector3(0,0.34,0),Vector3(3.25,0.45,1.35),"gold")
    _finish(b)
    shelf_carriage = _node(shelf_mast,"VerticalCarriage")
    b = _batch(shelf_carriage)
    _box(b,Vector3(0,-0.16,0),Vector3(3.0,0.28,1.6),"armor")
    _finish(b)
    shelf_fork = _node(shelf_carriage,"TelescopingFork")
    b = _batch(shelf_fork)
    for x in [-0.85,0.85]:
        _box(b,Vector3(x,-0.06,0),Vector3(0.24,0.12,3.60),"edge")
    _finish(b)
    shelf_box = _container(root,"StackerPayload",true)
    shelf_box.visible = false
    reserves.append(AABB(Vector3(-10.8,0,aisle_z-2.2),Vector3(21.6,2.4,4.4)))
    var packing := _node(root,"PackingStation",storage_pack_point-Vector3.UP*1.10)
    var dispatch := _node(root,"DispatchStation",storage_out_point-Vector3.UP*1.10)
    for station in [packing,dispatch]:
        b = _batch(station)
        for side in [-1.0,1.0]:
            _poly(b,"bevel",Vector3(float(side)*1.25,0.48,0),Vector3(0.40,0.96,3.85),"slate")
            _box(b,Vector3(float(side)*1.18,1.02,0),Vector3(0.30,0.16,3.70),"armor_light")
        _finish(b)
        reserves.append(AABB(station.position-Vector3(1.6,0,2.0),Vector3(3.2,2.4,4.0)))
    pack = _container(root,"PackingContainer",false)
    pack.position = storage_pack_point
    pack_lid = pack.get_node("Lid") as Node3D
    pack_raw = _material(root,"PackedMaterial")
    pack.visible = false
    pack_raw.visible = false
    _stacker(Vector3(storage_pack_point.x,storage_pack_point.y,aisle_z),0.0)

func _stacker(p: Vector3,reach: float) -> void:
    shelf_mast.position = Vector3(p.x,0,aisle_z)
    shelf_carriage.position = Vector3(0,p.y,0)
    shelf_fork.position.z = reach*0.5
    shelf_fork.scale.z = maxf(0.42,(absf(reach)+1.70)/3.60)

func _shelf_transfer(a: Vector3,b: Vector3,t: float) -> Vector3:
    # Retract to the clear aisle, then travel horizontally, raise and insert.
    var aa := Vector3(a.x,a.y,aisle_z)
    var bb := Vector3(b.x,b.y,aisle_z)
    if t<0.22:
        return a.lerp(aa,smoothstep(0.0,0.22,t))
    if t<0.50:
        return aa.lerp(Vector3(bb.x,aa.y,aisle_z),smoothstep(0.22,0.50,t))
    if t<0.75:
        return Vector3(bb.x,aa.y,aisle_z).lerp(bb,smoothstep(0.50,0.75,t))
    return bb.lerp(b,smoothstep(0.75,1.0,t))

func sample_storage(t: float) -> void:
    if store_index<0 or take_index<0:
        return
    if retrieve_only:
        # A full rack first frees a random occupied bay instead of stalling.
        t = lerpf(0.51,1.0,t)
    elif not input_finished:
        sample_in(t*1.45)
    pack.visible = not retrieve_only and t>=0.07 and t<0.26
    pack_lid.visible = t>=0.195
    pack_lid.position.y = lerpf(2.35,1.55,smoothstep(0.195,0.235,t))
    pack_raw.visible = not retrieve_only and t>=0.16 and t<0.235
    pack_raw.position = storage_pack_point+Vector3.UP*0.14
    raw.visible = not retrieve_only and t<0.16
    if t>=0.16:
        raw.visible = false
    var target: Vector3 = _room_position(storage_slots[store_index])
    var source: Vector3 = _room_position(storage_slots[take_index])
    shelf_box.visible = false
    if t<0.22:
        var approach := Vector3(storage_pack_point.x,storage_pack_point.y,aisle_z)
        _stacker(stacker_start.lerp(approach,smoothstep(0.0,0.20,t)),0.0)
    elif t<0.26:
        _stacker(Vector3(storage_pack_point.x,storage_pack_point.y,aisle_z),(storage_pack_point.z-aisle_z)*smoothstep(0.22,0.26,t))
    if t>=0.26 and t<0.51:
        var p: Vector3 = _shelf_transfer(storage_pack_point,target,smoothstep(0.26,0.51,t))
        shelf_box.position = p
        shelf_box.visible = true
        _stacker(p,p.z-aisle_z)
    elif t>=0.51 and not storage_committed:
        occupied[store_index] = true
        storage_slots[store_index].visible = true
        storage_committed = true
    if t>=0.51 and t<0.58:
        var retract: float = 1.0-smoothstep(0.51,0.54,t)
        var move := Vector3(target.x,target.y,aisle_z)
        if t>=0.54:
            move = move.lerp(Vector3(source.x,source.y,aisle_z),smoothstep(0.54,0.58,t))
        if retrieve_only:
            move = stacker_start.lerp(Vector3(source.x,source.y,aisle_z),smoothstep(0.51,0.58,t))
            retract = 0.0
        _stacker(move,(target.z-aisle_z)*retract)
    if t>=0.58 and t<0.63:
        _stacker(source,(source.z-aisle_z)*smoothstep(0.58,0.63,t))
    if t>=0.63 and t<0.82:
        if not storage_removed:
            occupied[take_index] = false
            storage_slots[take_index].visible = false
            storage_removed = true
        var p: Vector3 = _shelf_transfer(source,storage_out_point,smoothstep(0.63,0.82,t))
        shelf_box.position = p
        shelf_box.visible = true
        _stacker(p,p.z-aisle_z)
    if t>=0.82:
        shelf_box.position = storage_out_point
        shelf_box.visible = t<1.0
        _stacker(Vector3(storage_out_point.x,storage_out_point.y,aisle_z),(storage_out_point.z-aisle_z)*(1.0-smoothstep(0.82,0.86,t)))
        # Outbound carrier picks up the packed box itself; its shell is hidden.
        out_box.visible = false
        sample_out(0.72+0.28*smoothstep(0.82,1.0,t),shelf_box,1.82,0.92)
        if t>=1.0:
            storage_delivered = true
