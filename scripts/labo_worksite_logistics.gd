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
var storage_boxes: Array[Node3D] = []
var active_box: Node3D
var inbound_operation := false
var box_serial: int = 0
var storage_cycle_seconds: float = 46.0
const STORAGE_BOX_HEIGHT := 1.76
const STORAGE_TRIP := 64.0
const REFINERY_SECONDS := 104.0
const INGOT_COUNT := 12
const INGOT_HEIGHT := 0.64
const INGOT_WIDTH := 1.10
const INGOT_DEPTH := 0.96
var refinery_gate: Node3D
var refinery_cradle: Node3D
var refinery_chunks: Array[Node3D] = []
var refinery_falling: Array[Node3D] = []
var refinery_ingots: Array[Node3D] = []
var refinery_extract: Dictionary
var refinery_hatch: Node3D
var refinery_drawer: Node3D
var refinery_pick := Vector3(9.6,1.25,1.8)
var refinery_inside := Vector3(9.6,1.25,-0.8)
var refinery_lip := Vector3.ZERO
var refinery_tilt := 0.0
var occupied: Array[bool] = []
var store_index: int = -1
var take_index: int = -1
var shelf_mast: Node3D
var shelf_carriage: Node3D
var shelf_fork: Node3D
var shelf_beam: Node3D
var rng := RandomNumberGenerator.new()
var storage_committed := false
var storage_removed := false
var storage_delivered := false
var input_finished := false
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
func _container(parent: Node3D,label: String,closed: bool,pour_gate: bool = false) -> Node3D:
    var n := _node(parent,label)
    var b = _batch(n)
    _box(b,Vector3(0,0.07,0),Vector3(BOX_SIZE.x,0.14,BOX_SIZE.z),"slate")
    for side in [-1.0,1.0]:
        _box(b,Vector3(side*1.34,0.80,0),Vector3(0.10,1.46,3.50),"armor")
        if not pour_gate or side>0.0:
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
    if pour_gate:
        refinery_gate = _node(n,"HingedPourGate",Vector3(0,0.14,-1.70))
        b = _batch(refinery_gate)
        _box(b,Vector3(0,0.66,0),Vector3(2.58,1.32,0.10),"armor")
        _box(b,Vector3(0,1.28,0),Vector3(2.60,0.12,0.15),"gold")
        _rod(b,Vector3(-1.30,0,0),Vector3(1.30,0,0),0.15,"edge")
        _finish(b)
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

func _gantry(label: String,a: Vector3,z: Vector3,height: float,build_structure: bool = true,wide_travel: bool = false) -> Dictionary:
    var n := _node(root,label)
    var direction := Vector3(z.x-a.x,0,z.z-a.z)
    var length: float = maxf(0.1,direction.length())
    var axis: Vector3 = direction/length
    var side := Vector3(axis.z,0,-axis.x)
    var b = _batch(n)
    if build_structure:
        # Two braced portals support a continuous twin-rail bridge. Keep the
        # second portal short of the machine opening so no column blocks loading.
        var rail_y: float = height+0.55
        var portal_span: float = 2.18
        var inner: Vector3 = a+axis*minf(length*0.58,maxf(0.0,length-2.5))
        var end_margin: float = 1.65 if wide_travel else 0.65
        var start := Vector3(a.x,rail_y,a.z)-axis*end_margin
        var end := Vector3(z.x,rail_y,z.z)+axis*end_margin
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
        var portals: Array[Vector3] = [a,inner]
        if wide_travel:
            portals.append(z-axis*2.0)
        for portal in portals:
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
    return {"trolley":trolley,"stem":stem,"grip":grip,"height":height,"jaws":jaws,"crossbar":crossbar,"sleeve":sleeve}

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
            in_dock = Vector3(inlet.x,-0.03,17.0)
            out_dock = Vector3(outlet.x,-0.03,18.0)
        "RECYCLER":
            in_dock = Vector3(inlet.x,ground,-23.0)
            out_dock = Vector3(outlet.x,ground,14.0)
        "STORAGE":
            ground = -0.35
            inlet = storage_pack_point
            outlet = storage_out_point
            in_dock = Vector3(inlet.x,ground,18.0)
            out_dock = Vector3(outlet.x,ground,18.0)
            _build_storage()
    in_far = in_dock+Vector3(0,0,-7.0 if key=="RECYCLER" else (STORAGE_TRIP if key in ["STORAGE","SMELTER"] else 7.0))
    out_far = out_dock+Vector3(0,0,STORAGE_TRIP if key in ["STORAGE","SMELTER"] else 7.0)
    _lane(in_dock,in_far)
    _lane(out_dock,out_far)
    if key=="STORAGE":
        _storage_road()
    truck_in = _carrier("InboundCarrier")
    truck_out = _carrier("OutboundCarrier")
    if key!="STORAGE":
        in_box = _container(truck_in,"TransportContainer",false,key=="SMELTER")
        out_box = _container(truck_out,"TransportContainer",false)
        in_box.position.y = DECK_Y
        out_box.position.y = DECK_Y
    raw = _material(root,"InboundRawMaterial")
    var h_in: float = maxf(8.5,inlet.y+(5.2 if key=="SMELTER" else 4.0))
    var h_out: float = maxf(8.5,outlet.y+4.0)
    in_arm = _gantry("InboundTransferArm",in_dock,inlet,h_in)
    if key=="SMELTER":
        # Two independently driven trolleys share one supported rail, so the
        # packing ram never has to pass through an extraction rail below it.
        out_arm = _gantry("OutboundTransferArm",out_dock,refinery_pick,h_out,true,true)
    else:
        out_arm = _gantry("OutboundTransferArm",out_dock,outlet,h_out)
    _arm_pose(in_arm,Vector3(in_dock.x,h_in-0.55,in_dock.z))
    _arm_pose(out_arm,Vector3(outlet.x,h_out-0.55,outlet.z))
    _truck_pose(truck_in,in_far,in_dock,0.0)
    _truck_pose(truck_out,out_far,out_dock,0.0)
    truck_in.visible = false
    truck_out.visible = false
    raw.visible = false
    if key=="SMELTER":
        _build_refinery()
        _reset_refinery()

func _storage_road() -> void:
    # Paint only, just above the exterior BASE deck; no raised obstruction.
    var road := _node(root,"WarehouseTrafficMarkings")
    var b = _batch(road)
    for dock in [in_dock,out_dock]:
        var p: Vector3 = dock
        for side in [-1.0,1.0]:
            _box(b,Vector3(p.x+float(side)*1.95,p.y+0.009,p.z+STORAGE_TRIP*0.5),Vector3(0.09,0.012,STORAGE_TRIP),"trim")
        for j in range(10):
            _box(b,Vector3(p.x,p.y+0.009,p.z+5.0+float(j)*5.8),Vector3(0.12,0.012,2.3),"caution")
        for side in [-1.0,1.0]:
            for dz in [-1.5,1.5]:
                _box(b,Vector3(p.x+float(side)*1.65,p.y+0.011,p.z+float(dz)),Vector3(0.16,0.015,0.65),"gold")
    _finish(b)

func _room_position(n: Node3D) -> Vector3:
    return root.to_local(n.global_position)

func _place(n: Node3D,p: Vector3) -> void:
    n.global_position = root.to_global(p)

func _in_pick() -> Vector3:
    return in_dock+Vector3.UP*(DECK_Y+0.14)

func _out_drop() -> Vector3:
    return out_dock+Vector3.UP*(DECK_Y+(0.0 if key=="STORAGE" else 0.14))

func duration() -> float:
    if key=="SMELTER":
        return REFINERY_SECONDS
    return storage_cycle_seconds if key=="STORAGE" else 26.0

func begin() -> void:
    input_finished = false
    reset()
    if key!="STORAGE":
        return
    var empty: Array[int] = []
    var full: Array[int] = []
    for i in range(storage_slots.size()):
        var present: bool = is_instance_valid(storage_boxes[i])
        occupied[i] = present
        if present:
            full.append(i)
        else:
            empty.append(i)
    # The probability is proportional to free/occupied capacity. The boundary
    # conditions are absolute, and only the selected operation reserves a bay.
    var fill: float = float(full.size())/float(maxi(1,storage_slots.size()))
    inbound_operation = full.is_empty() or (not empty.is_empty() and rng.randf()<1.0-fill)
    store_index = empty[rng.randi_range(0,empty.size()-1)] if inbound_operation and not empty.is_empty() else -1
    take_index = full[rng.randi_range(0,full.size()-1)] if not inbound_operation and not full.is_empty() else -1
    storage_committed = false
    storage_removed = false
    storage_delivered = false
    storage_cycle_seconds = 50.0 if inbound_operation else 48.0
    stacker_start = Vector3(shelf_mast.position.x,shelf_carriage.position.y,aisle_z)
    if store_index>=0:
        active_box = _new_storage_box(truck_in)
        active_box.position = Vector3.UP*DECK_Y
        # Keep the box label facing the same world direction during every handoff.
        active_box.rotation.y = PI

func _new_storage_box(parent: Node3D) -> Node3D:
    box_serial += 1
    return _container(parent,"SealedCargo_%04d"%box_serial,true)

func _attach_box(box: Node3D,parent: Node3D,p: Vector3) -> void:
    if box.get_parent()!=parent:
        box.reparent(parent,false)
    box.position = p
    box.rotation = Vector3.ZERO

func reset() -> void:
    truck_in.visible = false
    truck_out.visible = false
    raw.visible = false
    raw.scale = Vector3.ONE
    _arm_pose(in_arm,Vector3(in_dock.x,float(in_arm["height"])-0.74,in_dock.z))
    _arm_pose(out_arm,Vector3(outlet.x,float(out_arm["height"])-0.74,outlet.z))
    if key=="SMELTER":
        _reset_refinery()
    if key=="STORAGE":
        # If a view is closed during a transfer, restore an undelivered
        # outgoing box to its reserved slot, or cancel an uncommitted arrival.
        if is_instance_valid(active_box):
            if storage_removed and not storage_delivered and take_index>=0:
                _attach_box(active_box,storage_slots[take_index],Vector3.ZERO)
                storage_boxes[take_index] = active_box
                occupied[take_index] = true
            elif not storage_committed:
                active_box.visible = false
                active_box.queue_free()
        active_box = null
        store_index = -1
        take_index = -1
        storage_removed = false
        storage_delivered = false
        storage_committed = false
        _stacker(Vector3(shelf_mast.position.x,shelf_carriage.position.y,aisle_z),0.0)


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
            _box(b,Vector3(x,6.25,z),Vector3(0.20,12.5,0.30),"slate")
            _box(b,Vector3(x,0.12,z),Vector3(0.34,0.24,0.45),"edge")
            for level in range(4):
                var y: float = 0.65+float(level)*2.85
                _box(b,Vector3(x,y,z),Vector3(0.23,0.26,0.34),"armor_light")
    # Rear-only cross bracing cannot enter the fork or cargo envelope.
    for col in range(6):
        var left: float = -9.3+float(col)*3.10
        for level in range(4):
            var base_y: float = 0.78+float(level)*2.85
            _rod(b,Vector3(left,base_y,-7.40),Vector3(left+3.10,base_y+2.45,-7.40),0.12,"trim")
    for level in range(4):
        var y: float = 0.65+float(level)*2.85
        # Two support rails per bay leave a real open channel for the forks.
        for col in range(6):
            var center_x: float = -7.75+float(col)*3.10
            for side in [-1.0,1.0]:
                _box(b,Vector3(center_x+float(side)*1.18,y,-5.4),Vector3(0.30,0.24,3.65),"armor")
                _box(b,Vector3(center_x+float(side)*1.18,y,-3.51),Vector3(0.31,0.19,0.15),"gold")
                _box(b,Vector3(center_x+float(side)*1.18,y-0.13,-3.52),Vector3(0.28,0.10,0.12),"edge")
            _box(b,Vector3(center_x,y-0.27,-3.49),Vector3(0.60,0.12,0.08),"lab_cyan")
    _box(b,Vector3(0,12.45,-5.4),Vector3(18.9,0.25,3.9),"armor")
    _finish(b)
    for level in range(4):
        for col in range(6):
            var slot := _node(rack,"Stock_%d_%d"%[level,col],Vector3(-7.75+float(col)*3.10,0.77+float(level)*2.85,-5.4))
            storage_slots.append(slot)
            var present: bool = posmod(level*3+col,4)!=0
            occupied.append(present)
            var box: Node3D = _new_storage_box(slot) if present else null
            storage_boxes.append(box)
    reserves.append(AABB(Vector3(-9.6,0,-7.5),Vector3(19.2,2.4,4.0)))
    # Rail-guided stacker: travel in X, lift in Y, only the fork extends in Z.
    var rail := _node(root,"WarehouseStackerRail")
    b = _batch(rail)
    for z in [aisle_z-0.62,aisle_z+0.62]:
        _box(b,Vector3(0,0.08,z),Vector3(25.0,0.16,0.14),"edge")
    _box(b,Vector3(0,12.8,aisle_z),Vector3(25.0,0.28,0.50),"gold")
    _box(b,Vector3(0,13.03,aisle_z),Vector3(25.0,0.20,0.72),"slate")
    for j in range(16):
        _box(b,Vector3(-11.7+float(j)*1.55,12.99,aisle_z+0.35),Vector3(0.12,0.24,0.09),"edge")
    for x in [-12.5,12.5]:
        _box(b,Vector3(x,6.4,aisle_z),Vector3(0.45,12.8,0.55),"slate")
    _finish(b)
    shelf_mast = _node(root,"StackerTravelMast")
    b = _batch(shelf_mast)
    for x in [-1.65,1.65]:
        _box(b,Vector3(x,6.1,0),Vector3(0.24,12.2,0.32),"slate")
        _box(b,Vector3(x,6.15,0.21),Vector3(0.12,11.9,0.09),"edge")
        _box(b,Vector3(x,12.47,0),Vector3(0.42,0.55,0.48),"armor")
    _box(b,Vector3(0,0.34,0),Vector3(3.65,0.45,1.35),"gold")
    _box(b,Vector3(0,12.35,0),Vector3(3.65,0.30,0.45),"slate")
    _box(b,Vector3(0,12.62,0),Vector3(0.55,0.38,0.58),"edge")
    for x in [-1.34,1.34]:
        _poly(b,"drum",Vector3(x,0.16,0.62),Vector3(0.30,0.32,0.30),"edge")
        _poly(b,"drum",Vector3(x,0.16,-0.62),Vector3(0.30,0.32,0.30),"edge")
    _finish(b)
    shelf_carriage = _node(shelf_mast,"VerticalCarriage")
    b = _batch(shelf_carriage)
    _box(b,Vector3(0,-0.16,0),Vector3(3.0,0.28,1.6),"armor")
    for x in [-1.70,1.70]:
        _poly(b,"bevel",Vector3(x,0.20,0),Vector3(0.24,0.62,0.58),"slate")
        _box(b,Vector3(x,0.28,0.31),Vector3(0.18,0.13,0.08),"lab_cyan")
    _finish(b)
    shelf_fork = _node(shelf_carriage,"TelescopingFork")
    b = _batch(shelf_fork)
    for x in [-0.85,0.85]:
        _box(b,Vector3(x,-0.06,0),Vector3(0.24,0.12,3.60),"edge")
    _finish(b)
    reserves.append(AABB(Vector3(-10.8,0,aisle_z-2.2),Vector3(21.6,2.4,4.4)))
    var packing := _node(root,"InboundBoxTransferStation",storage_pack_point-Vector3.UP*1.10)
    var dispatch := _node(root,"DispatchStation",storage_out_point-Vector3.UP*1.10)
    for station in [packing,dispatch]:
        b = _batch(station)
        for side in [-1.0,1.0]:
            _poly(b,"bevel",Vector3(float(side)*1.25,0.48,0),Vector3(0.40,0.96,3.85),"slate")
            _box(b,Vector3(float(side)*1.18,1.02,0),Vector3(0.30,0.16,3.70),"armor_light")
        for side in [-1.0,1.0]:
            _box(b,Vector3(float(side)*1.43,0.54,1.70),Vector3(0.08,0.34,0.12),"gold")
            _box(b,Vector3(float(side)*1.43,0.84,1.70),Vector3(0.08,0.12,0.12),"lab_cyan")
        _finish(b)
        reserves.append(AABB(station.position-Vector3(1.6,0,2.0),Vector3(3.2,2.4,4.0)))
    _stacker(Vector3(storage_pack_point.x,storage_pack_point.y,aisle_z),0.0)

func _stacker(p: Vector3,reach: float) -> void:
    shelf_mast.position = Vector3(p.x,0,aisle_z)
    shelf_carriage.position = Vector3(0,p.y,0)
    shelf_fork.position.z = reach*0.5
    shelf_fork.scale.z = maxf(0.94,(absf(reach)+3.40)/3.60)

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

func _storage_arm(arm: Dictionary,p: Vector3) -> void:
    _arm_pose(arm,p+Vector3.UP*STORAGE_BOX_HEIGHT,1.15)

func _storage_truck(n: Node3D,a: Vector3,b: Vector3,u: float,reverse: bool = false) -> void:
    # Slight acceleration at either end, near-constant cruise on the long road.
    var progress: float = clampf(u,0.0,1.0)
    # Integrated trapezoidal velocity profile, 12% acceleration and deceleration.
    var ramp: float = 0.12
    var travel: float
    if progress<ramp:
        travel = progress*progress/(2.0*ramp*(1.0-ramp))
    elif progress>1.0-ramp:
        travel = 1.0-pow(1.0-progress,2.0)/(2.0*ramp*(1.0-ramp))
    else:
        travel = (progress-ramp*0.5)/(1.0-ramp)
    n.position = a.lerp(b,travel)
    var heading: Vector3 = a-b if reverse else b-a
    if heading.length_squared()>0.001:
        n.rotation.y = atan2(heading.x,heading.z)

func sample_storage(t: float) -> void:
    if inbound_operation:
        _sample_storage_arrival(t)
    else:
        _sample_storage_departure(t)

func _sample_storage_arrival(t: float) -> void:
    if store_index<0 or not is_instance_valid(active_box):
        return
    var target: Vector3 = _room_position(storage_slots[store_index])
    var pick: Vector3 = in_dock+Vector3.UP*DECK_Y
    truck_in.visible = t<0.83
    if t<0.25:
        _storage_truck(truck_in,in_far,in_dock,t/0.25)
    elif t<0.47:
        _storage_truck(truck_in,in_far,in_dock,1.0)
    else:
        _storage_truck(truck_in,in_dock,in_far,(t-0.47)/0.36,true)
    var park := Vector3(in_dock.x,float(in_arm["height"])-0.74,in_dock.z)
    if t<0.30:
        _arm_pose(in_arm,park.lerp(pick+Vector3.UP*STORAGE_BOX_HEIGHT,smoothstep(0.25,0.30,t)),1.15)
    elif t<0.43:
        if active_box.get_parent()!=root:
            active_box.reparent(root,true)
            active_box.rotation = Vector3.ZERO
        var p: Vector3 = _transfer(pick,inlet,float(in_arm["height"])-STORAGE_BOX_HEIGHT-0.9,smoothstep(0.30,0.43,t))
        _place(active_box,p)
        _storage_arm(in_arm,p)
    else:
        if t<0.47:
            _place(active_box,inlet)
        _arm_pose(in_arm,Vector3(inlet.x,lerpf(inlet.y+STORAGE_BOX_HEIGHT,float(in_arm["height"])-0.74,smoothstep(0.43,0.47,t)),inlet.z),1.15)
    var approach := Vector3(inlet.x,inlet.y,aisle_z)
    if t<0.47:
        _stacker(stacker_start.lerp(approach,smoothstep(0.30,0.47,t)),0.0)
    elif t<0.53:
        _stacker(approach,(inlet.z-aisle_z)*smoothstep(0.47,0.53,t))
    elif t<0.91:
        var p: Vector3 = _shelf_transfer(inlet,target,smoothstep(0.53,0.91,t))
        _place(active_box,p)
        _stacker(p,p.z-aisle_z)
    elif not storage_committed:
        # Refuse to overwrite a shelf, even if its state changed unexpectedly.
        if is_instance_valid(storage_boxes[store_index]):
            active_box.visible = false
            active_box.queue_free()
            active_box = null
            return
        _attach_box(active_box,storage_slots[store_index],Vector3.ZERO)
        storage_boxes[store_index] = active_box
        occupied[store_index] = true
        storage_committed = true
    if t>=0.91:
        _stacker(Vector3(target.x,target.y,aisle_z),(target.z-aisle_z)*(1.0-smoothstep(0.91,1.0,t)))

func _sample_storage_departure(t: float) -> void:
    if take_index<0:
        return
    var source: Vector3 = _room_position(storage_slots[take_index])
    var approach := Vector3(source.x,source.y,aisle_z)
    var drop: Vector3 = out_dock+Vector3.UP*DECK_Y
    if t<0.12:
        _stacker(stacker_start.lerp(approach,smoothstep(0.0,0.12,t)),0.0)
    elif t<0.17:
        _stacker(approach,(source.z-aisle_z)*smoothstep(0.12,0.17,t))
    elif t<0.44:
        if not storage_removed:
            active_box = storage_boxes[take_index]
            if not is_instance_valid(active_box):
                return
            active_box.reparent(root,true)
            storage_boxes[take_index] = null
            occupied[take_index] = false
            storage_removed = true
        if not is_instance_valid(active_box):
            return
        var p: Vector3 = _shelf_transfer(source,outlet,smoothstep(0.17,0.44,t))
        _place(active_box,p)
        _stacker(p,p.z-aisle_z)
    else:
        if not is_instance_valid(active_box):
            return
        _stacker(Vector3(outlet.x,outlet.y,aisle_z),(outlet.z-aisle_z)*(1.0-smoothstep(0.44,0.49,t)))
        if t<0.49:
            _place(active_box,outlet)
    truck_out.visible = t>=0.16 and t<1.0
    if t<0.42:
        _storage_truck(truck_out,out_far,out_dock,(t-0.16)/0.26)
    elif t<0.64:
        _storage_truck(truck_out,out_far,out_dock,1.0)
    else:
        _storage_truck(truck_out,out_dock,out_far,(t-0.64)/0.36,true)
    if t<0.49 or not is_instance_valid(active_box):
        return
    if t<0.53:
        _arm_pose(out_arm,Vector3(outlet.x,lerpf(float(out_arm["height"])-0.74,outlet.y+STORAGE_BOX_HEIGHT,smoothstep(0.49,0.53,t)),outlet.z),1.15)
    elif t<0.61:
        var p: Vector3 = _transfer(outlet,drop,float(out_arm["height"])-STORAGE_BOX_HEIGHT-0.9,smoothstep(0.53,0.61,t))
        _place(active_box,p)
        _storage_arm(out_arm,p)
    else:
        if active_box.get_parent()!=truck_out:
            _attach_box(active_box,truck_out,Vector3.UP*DECK_Y)
            active_box.rotation.y = PI
        _arm_pose(out_arm,Vector3(drop.x,lerpf(drop.y+STORAGE_BOX_HEIGHT,float(out_arm["height"])-0.74,smoothstep(0.61,0.64,t)),drop.z),1.15)
        if t>=1.0 and not storage_delivered:
            storage_delivered = true
            active_box.visible = false
            active_box.queue_free()
            active_box = null

# Refinery: independent, time-addressed batch choreography. No stock nodes
# are allocated during playback, and each of the twelve bars is reused.
func _refinery_cross_slide(arm: Dictionary) -> void:
    var trolley: Node3D = arm["trolley"]
    var b = _batch(trolley)
    _box(b,Vector3(0,-0.20,0),Vector3(2.15,0.16,0.55),"slate")
    for x in [-0.95,0.95]:
        _box(b,Vector3(x,-0.22,0),Vector3(0.10,0.24,0.62),"gold")
    _finish(b)

func _refinery_arm(arm: Dictionary,p: Vector3,center_x: float,span: float = 0.8) -> void:
    _arm_pose(arm,Vector3(center_x,p.y,p.z),span)
    var x: float = clampf(p.x-center_x,-0.64,0.64)
    for name in ["stem","grip","sleeve"]:
        (arm[name] as Node3D).position.x = x

func _build_refinery() -> void:
    refinery_lip = inlet-Vector3(0,0,1.75)
    # Side-mounted hinge cradle: axis is aligned to the box's leading edge.
    var cradle_support := _node(root,"PourCradleSupports",refinery_lip)
    var b = _batch(cradle_support)
    for side in [-1.0,1.0]:
        var x: float = float(side)*2.12
        _box(b,Vector3(x,-0.65,0),Vector3(0.32,1.40,0.60),"slate")
        _rod(b,Vector3(x,-0.05,0),Vector3(float(side)*1.44,-0.05,0),0.28,"edge")
        _rod(b,Vector3(x,-1.15,0),Vector3(float(side)*1.55,-0.10,0),0.22,"gold")
    _finish(b)
    refinery_cradle = _node(root,"HingedBoxCradle",refinery_lip)
    b = _batch(refinery_cradle)
    for x in [-1.45,1.45]:
        _box(b,Vector3(x,-0.11,1.68),Vector3(0.18,0.22,3.42),"gold")
        _poly(b,"drum",Vector3(x,0,0),Vector3(0.35,0.33,0.35),"edge")
        _box(b,Vector3(x,0.18,3.30),Vector3(0.20,0.50,0.18),"slate")
    _rod(b,Vector3(-1.50,-0.14,3.16),Vector3(1.50,-0.14,3.16),0.16,"edge")
    _finish(b)
    for i in range(36):
        var chunk := _node(in_box,"ChargeFragment%02d"%i)
        var cb = _batch(chunk)
        _poly(cb,["bevel","gear","octagonal_slew"][i%3],Vector3.ZERO,Vector3(0.35,0.32,0.40),["slate","rust","edge"][i%3])
        _finish(cb)
        refinery_chunks.append(chunk)
    for i in range(28):
        var fragment := _node(root,"PourFragment%02d"%i)
        b = _batch(fragment)
        _poly(b,["bevel","gear","octagonal_slew"][i%3],Vector3.ZERO,Vector3(0.20,0.18,0.22),["slate","rust","edge"][i%3])
        _finish(b)
        fragment.visible = false
        refinery_falling.append(fragment)
    # Real open-front discharge chamber, mechanically linked to the furnace's
    # right-side outlet. No solid block occupies the moving drawer corridor.
    var discharge := _node(root,"RefractoryDischargeCell")
    b = _batch(discharge)
    _rod(b,Vector3(5.65,2.1,-1.4),Vector3(8.33,2.1,-1.4),1.15,"rust")
    _poly(b,"bevel",Vector3(8.24,2.1,-1.4),Vector3(0.20,1.38,1.38),"edge")
    for x in [8.54,10.66]:
        _poly(b,"bevel",Vector3(x,1.78,-1.05),Vector3(0.42,3.56,2.32),"armor")
        _box(b,Vector3(x,2.15,0.17),Vector3(0.25,1.85,0.12),"edge")
        _box(b,Vector3(x,0.33,0.17),Vector3(0.32,0.16,0.10),"gold")
    _box(b,Vector3(9.6,0.55,-1.05),Vector3(2.52,1.10,2.42),"slate")
    _box(b,Vector3(9.6,3.43,-1.05),Vector3(2.52,0.40,2.42),"armor_light")
    for x in [8.47,10.73]:
        _box(b,Vector3(x,3.74,-1.05),Vector3(0.22,0.24,2.25),"edge")
    for i in range(5):
        _box(b,Vector3(9.6,3.67,-1.90+float(i)*0.42),Vector3(1.85,0.12,0.10),"trim")
    _box(b,Vector3(9.6,2.14,-2.14),Vector3(1.78,1.87,0.16),"void")
    for x in [8.76,10.44]:
        _box(b,Vector3(x,1.10,0.85),Vector3(0.20,0.15,2.30),"edge")
        _poly(b,"gusset",Vector3(x,0.52,1.30),Vector3(0.25,1.0,0.58),"slate")
    for x in [8.43,10.77]:
        _rod(b,Vector3(x,1.0,0.31),Vector3(x,4.55,0.31),0.18,"trim")
    _finish(b)
    refinery_hatch = _node(discharge,"SlidingDischargeHatch",Vector3(9.6,2.23,0.27))
    b = _batch(refinery_hatch)
    _poly(b,"bevel",Vector3.ZERO,Vector3(1.96,1.94,0.22),"rust")
    for x in [-0.72,0.72]:
        _box(b,Vector3(x,0,0.14),Vector3(0.16,1.68,0.10),"edge")
    _box(b,Vector3(0,0.68,0.15),Vector3(0.80,0.14,0.08),"amber_light")
    _finish(b)
    refinery_drawer = _node(discharge,"CastingExtractionDrawer",refinery_inside)
    b = _batch(refinery_drawer)
    _box(b,Vector3(0,-0.12,0),Vector3(1.55,0.24,1.45),"armor_light")
    for x in [-0.70,0.70]:
        _box(b,Vector3(x,-0.12,-0.8),Vector3(0.12,0.13,1.55),"gold")
    _finish(b)
    # Cooling / stacking bed at the common point of two independent cranes.
    var bed := _node(root,"IngotCoolingStackBed",outlet)
    b = _batch(bed)
    _poly(b,"bevel",Vector3(0,-0.63,0),Vector3(3.15,1.22,3.85),"slate")
    _box(b,Vector3(0,-0.10,0),Vector3(2.90,0.20,3.55),"armor_light")
    for side in [-1.0,1.0]:
        for z in [-1.40,0.0,1.40]:
            _box(b,Vector3(side*1.57,-0.37,z),Vector3(0.08,0.22,0.16),"lab_cyan")
    for x in [-1.50,1.50]:
        _box(b,Vector3(x,-0.36,0),Vector3(0.12,0.18,3.65),"gold")
        _poly(b,"louver",Vector3(x,-0.67,0),Vector3(0.12,0.40,2.30),"edge")
    _finish(b)
    reserves.append(AABB(Vector3(7.9,0,-2.4),Vector3(3.4,2.4,5.0)))
    reserves.append(AABB(outlet-Vector3(1.65,1.25,2.0),Vector3(3.30,2.4,4.0)))
    refinery_extract = _gantry("CastingExtractionArm",outlet,refinery_pick,float(out_arm["height"]),false)
    _refinery_cross_slide(refinery_extract)
    _refinery_cross_slide(out_arm)
    for i in range(INGOT_COUNT):
        var ingot := _node(root,"RefinedIngot%02d"%i)
        b = _batch(ingot)
        _poly(b,"bevel",Vector3(0,INGOT_HEIGHT*0.5,0),Vector3(INGOT_WIDTH,INGOT_HEIGHT,INGOT_DEPTH),"armor_light")
        _box(b,Vector3(0,INGOT_HEIGHT-0.018,0),Vector3(0.46,0.035,0.26),"slate")
        _box(b,Vector3(0,INGOT_HEIGHT*0.48,0.486),Vector3(0.34,0.10,0.025),"edge")
        _finish(b)
        ingot.visible = false
        refinery_ingots.append(ingot)

func _reset_refinery() -> void:
    if not is_instance_valid(refinery_hatch):
        return
    _attach_box(in_box,truck_in,Vector3.UP*DECK_Y)
    in_box.rotation.y = PI
    in_box.visible = true
    refinery_gate.rotation.x = 0.0
    refinery_cradle.rotation.x = 0.0
    refinery_hatch.position.y = 2.23
    refinery_drawer.position = refinery_inside
    for i in range(refinery_chunks.size()):
        var chunk: Node3D = refinery_chunks[i]
        var col: int = i%6
        var row: int = int(i/6)%3
        var layer: int = int(i/18)
        chunk.position = Vector3(-1.0+float(col)*0.40,0.32+float(layer)*0.37,-1.06+float(row)*1.04)
        chunk.rotation = Vector3(0,float(i)*0.81,0.1*sin(float(i)))
        chunk.visible = true
    for fragment in refinery_falling:
        fragment.visible = false
    for ingot in refinery_ingots:
        if ingot.get_parent()!=root:
            ingot.reparent(root,false)
        ingot.visible = false
        ingot.rotation = Vector3.ZERO
    _refinery_arm(refinery_extract,Vector3(refinery_pick.x,5.95,refinery_pick.z),refinery_pick.x)
    _refinery_arm(out_arm,Vector3(out_dock.x,float(out_arm["height"])-0.75,out_dock.z),outlet.x)

func _pyramid_position(index: int) -> Vector3:
    # Two parallel 3/2/1 pyramids, arranged bottom-up (6 + 4 + 2).
    var tier: int = 0 if index<6 else (1 if index<10 else 2)
    var j: int = index if tier==0 else (index-6 if tier==1 else index-10)
    var count: int = 3-tier
    var column: int = j%2
    var row: int = int(j/2)
    return outlet+Vector3(-0.59+float(column)*1.18,float(tier)*INGOT_HEIGHT,(float(row)-float(count-1)*0.5)*1.02)

func _packed_position(index: int) -> Vector3:
    # Six bars per layer; two layers fill the usable 2.58 x 3.30 x 1.41 m cavity.
    var slot: int = index%6
    return Vector3(-0.59+float(slot%2)*1.18,0.14+float(int(index/6))*INGOT_HEIGHT,-1.06+float(int(slot/2))*1.06)

func _refinery_box_pose(p: Vector3,angle: float) -> void:
    if in_box.get_parent()!=root:
        in_box.reparent(root,true)
    in_box.rotation = Vector3(angle,0,0)
    _place(in_box,p)

func sample_refinery(t: float) -> void:
    var sec: float = t*REFINERY_SECONDS
    var pick: Vector3 = in_dock+Vector3.UP*DECK_Y
    var in_h: float = float(in_arm["height"])
    truck_in.visible = sec<36.0
    truck_out.visible = sec>=64.0 and sec<REFINERY_SECONDS
    if sec<8.0:
        _storage_truck(truck_in,in_far,in_dock,sec/8.0)
    elif sec<27.0:
        _storage_truck(truck_in,in_far,in_dock,1.0)
    else:
        _storage_truck(truck_in,in_dock,in_far,(sec-27.0)/9.0,true)
    if sec<8.0:
        _arm_pose(in_arm,Vector3(pick.x,in_h-0.75,pick.z))
    elif sec<10.0:
        _arm_pose(in_arm,Vector3(pick.x,lerpf(in_h-0.75,pick.y+1.55,smoothstep(8.0,10.0,sec)),pick.z),2.0)
    elif sec<14.0:
        var p: Vector3 = _transfer(pick,inlet,in_h-2.5,smoothstep(10.0,14.0,sec))
        _refinery_box_pose(p,0.0)
        _arm_pose(in_arm,p+Vector3.UP*1.55,2.0)
    elif sec<22.0:
        # Cradle tilts about the fixed leading lip; gate opens only over the hopper.
        var tilt: float = -1.00*smoothstep(15.0,17.0,sec)*(1.0-smoothstep(20.0,22.0,sec))
        var gate: float = -1.25*smoothstep(16.0,17.0,sec)*(1.0-smoothstep(20.0,21.0,sec))
        refinery_cradle.rotation.x = tilt
        refinery_gate.rotation.x = gate
        var basis := Basis(Vector3.RIGHT,tilt)
        _refinery_box_pose(refinery_lip+basis*Vector3(0,0,1.75),tilt)
        var retract: float = smoothstep(14.0,15.0,sec)*(1.0-smoothstep(21.0,22.0,sec))
        _arm_pose(in_arm,Vector3(inlet.x,lerpf(inlet.y+1.55,in_h-0.75,retract),inlet.z),2.0)
    elif sec<26.0:
        refinery_cradle.rotation.x = 0.0
        refinery_gate.rotation.x = 0.0
        var p: Vector3 = _transfer(inlet,pick,in_h-2.5,smoothstep(22.0,26.0,sec))
        _refinery_box_pose(p,0.0)
        _arm_pose(in_arm,p+Vector3.UP*1.55,2.0)
    else:
        if in_box.get_parent()!=truck_in:
            _attach_box(in_box,truck_in,Vector3.UP*DECK_Y)
            in_box.rotation.y = PI
        _arm_pose(in_arm,Vector3(pick.x,lerpf(pick.y+1.55,in_h-0.75,smoothstep(26.0,27.0,sec)),pick.z),2.0)
    var poured: float = smoothstep(17.0,20.0,sec)
    for i in range(refinery_chunks.size()):
        var chunk: Node3D = refinery_chunks[i]
        var col: int = i%6
        var row: int = int(i/6)%3
        var layer: int = int(i/18)
        chunk.position = Vector3(-1.0+float(col)*0.40,0.32+float(layer)*0.37,-1.06+float(row)*1.04)
        chunk.position.z = maxf(-1.45,chunk.position.z-0.62*smoothstep(16.0,19.5,sec))
        chunk.visible = float(i+1)/float(refinery_chunks.size())>poured
    for i in range(refinery_falling.size()):
        var f: Node3D = refinery_falling[i]
        var age: float = sec-(16.8+float(i)*0.105)
        f.visible = age>=0.0 and age<0.58
        if f.visible:
            var u: float = age/0.58
            f.position = refinery_lip+Vector3(sin(float(i)*2.41)*0.95,-1.40*u*u,-0.10-0.55*u)
            f.rotation = Vector3(age*5.0,float(i)*1.7,age*4.0)
    # Output hatch opens after the heating dwell. Drawer extends for each bar.
    refinery_hatch.position.y = 2.23+2.05*smoothstep(36.0,39.0,sec)*(1.0-smoothstep(76.0,78.0,sec))
    var extraction: float = clampf(sec-40.0,0.0,36.0)
    var extracted: int = mini(INGOT_COUNT,int(extraction/3.0))
    var et: float = fmod(extraction,3.0)/3.0
    if sec>=40.0 and sec<76.0:
        var target: Vector3 = _pyramid_position(extracted)
        var drawer_u: float = smoothstep(0.0,0.22,et)*(1.0-smoothstep(0.52,0.68,et))
        refinery_drawer.position = refinery_inside.lerp(refinery_pick,drawer_u)
        var p: Vector3 = refinery_drawer.position
        if et>=0.36:
            p = _transfer(refinery_pick,target,4.65,smoothstep(0.36,0.79,et))
        var aim: Vector3
        if et<0.22:
            var prev: Vector3 = _pyramid_position(extracted-1) if extracted>0 else refinery_pick
            aim = Vector3(prev.x,5.95,prev.z).lerp(Vector3(refinery_pick.x,5.95,refinery_pick.z),smoothstep(0.0,0.22,et))
        elif et<0.36:
            aim = Vector3(refinery_pick.x,lerpf(5.95,refinery_pick.y+INGOT_HEIGHT,smoothstep(0.22,0.36,et)),refinery_pick.z)
        elif et<0.79:
            aim = p+Vector3.UP*INGOT_HEIGHT
        else:
            aim = Vector3(target.x,lerpf(target.y+INGOT_HEIGHT,5.95,smoothstep(0.79,1.0,et)),target.z)
        _refinery_arm(refinery_extract,aim,refinery_pick.x)
        refinery_ingots[extracted].position = p
    else:
        refinery_drawer.position = refinery_inside
        var prev: Vector3 = _pyramid_position(INGOT_COUNT-1)
        var parked := Vector3(refinery_pick.x,5.95,refinery_pick.z)
        var aim: Vector3 = Vector3(prev.x,5.95,prev.z).lerp(parked,smoothstep(76.0,78.0,sec)) if sec>=76.0 else parked
        _refinery_arm(refinery_extract,aim,refinery_pick.x)
    if sec<73.0:
        _storage_truck(truck_out,out_far,out_dock,(sec-64.0)/9.0)
    elif sec<95.0:
        _storage_truck(truck_out,out_far,out_dock,1.0)
    else:
        _storage_truck(truck_out,out_dock,out_far,(sec-95.0)/9.0,true)
    # Packing begins only when the entire 12-bar pyramid has been completed.
    var packing: float = clampf(sec-78.0,0.0,16.8)
    var packed: int = mini(INGOT_COUNT,int(packing/1.4))
    var pt: float = fmod(packing,1.4)/1.4
    for i in range(INGOT_COUNT):
        var ingot: Node3D = refinery_ingots[i]
        var order: int = INGOT_COUNT-1-i
        if order<packed:
            # Actual same bar is attached to the outbound container, not copied.
            _attach_box(ingot,out_box,_packed_position(order))
            ingot.visible = sec<REFINERY_SECONDS
        elif i<extracted:
            if ingot.get_parent()!=root:
                ingot.reparent(root,false)
            ingot.position = _pyramid_position(i)
            ingot.visible = true
        else:
            ingot.visible = sec>=40.0 and sec<76.0 and i==extracted and et>0.01
    if sec>=78.0 and packed<INGOT_COUNT:
        var index: int = INGOT_COUNT-1-packed
        var ingot: Node3D = refinery_ingots[index]
        var start: Vector3 = _pyramid_position(index)
        var dest: Vector3 = root.to_local(out_box.to_global(_packed_position(packed)))
        var high: float = 5.65
        var p: Vector3 = start
        var aim: Vector3
        if pt<0.23:
            var prev: Vector3 = root.to_local(out_box.to_global(_packed_position(maxi(0,packed-1))))
            var previous_aim: Vector3 = Vector3(prev.x,high+INGOT_HEIGHT,prev.z) if packed>0 else Vector3(out_dock.x,high+INGOT_HEIGHT,out_dock.z)
            aim = previous_aim.lerp(Vector3(start.x,high+INGOT_HEIGHT,start.z),smoothstep(0.0,0.14,pt))
            if pt>=0.14:
                aim = Vector3(start.x,lerpf(high+INGOT_HEIGHT,start.y+INGOT_HEIGHT,smoothstep(0.14,0.23,pt)),start.z)
        elif pt<0.88:
            p = _transfer(start,dest,high,smoothstep(0.23,0.88,pt))
            aim = p+Vector3.UP*INGOT_HEIGHT
        else:
            p = dest
            aim = Vector3(dest.x,lerpf(dest.y+INGOT_HEIGHT,high+INGOT_HEIGHT,smoothstep(0.88,1.0,pt)),dest.z)
        _refinery_arm(out_arm,aim,outlet.x)
        _place(ingot,p)
    else:
        var parked := Vector3(out_dock.x,float(out_arm["height"])-0.75,out_dock.z)
        if sec>=76.0 and sec<78.0:
            parked.y = lerpf(parked.y,6.29,smoothstep(76.0,78.0,sec))
        if sec>=94.8:
            var last: Vector3 = root.to_local(out_box.to_global(_packed_position(INGOT_COUNT-1)))
            parked = Vector3(last.x,6.29,last.z).lerp(parked,smoothstep(94.8,95.0,sec))
        _refinery_arm(out_arm,parked,outlet.x)
