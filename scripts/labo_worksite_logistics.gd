extends RefCounted
## Room-local industrial logistics. All visible handoffs use one payload node.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const BOX_SIZE := Vector3(2.70,1.55,3.50)
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
    _finish(b)
    return n

# The same shell is used on every carrier, at packing, and in every shelf bay.
func _container(parent: Node3D,label: String,closed: bool) -> Node3D:
    var n := _node(parent,label)
    var b = _batch(n)
    _box(b,Vector3(0,0.07,0),Vector3(BOX_SIZE.x,0.14,BOX_SIZE.z),"slate")
    for side in [-1.0,1.0]:
        _box(b,Vector3(side*1.30,0.80,0),Vector3(0.10,1.46,3.50),"armor")
        _box(b,Vector3(0,0.80,side*1.70),Vector3(2.50,1.46,0.10),"armor")
        for z in [-1.55,1.55]:
            _box(b,Vector3(side*1.31,0.78,z),Vector3(0.14,1.55,0.14),"edge")
        _box(b,Vector3(side*1.31,1.49,0),Vector3(0.15,0.12,3.50),"gold")
    _box(b,Vector3(0,0.83,1.76),Vector3(0.65,0.24,0.08),"lab_cyan")
    _finish(b)
    var lid := _node(n,"Lid")
    b = _batch(lid)
    _poly(b,"deck",Vector3(0,0.08,0),Vector3(2.70,0.16,3.50),"armor_light")
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

func _gantry(label: String,a: Vector3,z: Vector3,height: float) -> Dictionary:
    var n := _node(root,label)
    var direction := Vector3(z.x-a.x,0,z.z-a.z)
    var length: float = maxf(0.1,direction.length())
    var axis: Vector3 = direction/length
    var side := Vector3(axis.z,0,-axis.x)
    var b = _batch(n)
    # Cantilever supports are beside the vehicle, never in its travel lane.
    for sign_value in [-1.0,1.0]:
        var foot: Vector3 = a+side*float(sign_value)*2.35
        foot.y = 0.0
        _poly(b,"bevel",foot+Vector3.UP*0.20,Vector3(0.85,0.40,0.85),"slate")
        _box(b,foot+Vector3.UP*(height*0.5),Vector3(0.44,height,0.44),"slate")
        _rod(b,foot+Vector3.UP*height,Vector3(a.x,height,a.z),0.36,"edge")
        reserves.append(AABB(foot-Vector3(0.46,0,0.46),Vector3(0.92,2.4,0.92)))
    _rod(b,Vector3(a.x,height,a.z)-axis*0.55,Vector3(z.x,height,z.z)+axis*0.55,0.40,"gold")
    _finish(b)
    var trolley := _node(n,"LinearTrolley")
    b = _batch(trolley)
    _poly(b,"bevel",Vector3.ZERO,Vector3(0.84,0.56,0.80),"armor_light")
    _finish(b)
    var stem := _node(trolley,"TelescopingVerticalArm")
    b = _batch(stem)
    _box(b,Vector3(0,-0.5,0),Vector3(0.22,1.0,0.22),"edge")
    _finish(b)
    var grip := _node(trolley,"Gripper")
    b = _batch(grip)
    _box(b,Vector3(0,0.12,0),Vector3(0.95,0.20,0.48),"gold")
    for side_value in [-1.0,1.0]:
        _box(b,Vector3(float(side_value)*0.40,-0.12,0),Vector3(0.12,0.48,0.45),"edge")
    _finish(b)
    return {"trolley":trolley,"stem":stem,"grip":grip,"height":height}

func _arm_pose(arm: Dictionary,p: Vector3) -> void:
    var trolley: Node3D = arm["trolley"]
    var stem: Node3D = arm["stem"]
    var grip: Node3D = arm["grip"]
    var h: float = float(arm["height"])
    trolley.position = Vector3(p.x,h,p.z)
    var d: float = maxf(0.20,h-p.y)
    stem.scale.y = d
    grip.position.y = -d

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
            inlet = storage_pack_point
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
    var h_in: float = maxf(7.8,inlet.y+3.6)
    var h_out: float = maxf(7.8,outlet.y+3.6)
    in_arm = _gantry("InboundTransferArm",in_dock,inlet,h_in)
    out_arm = _gantry("OutboundTransferArm",out_dock,outlet,h_out)
    _arm_pose(in_arm,Vector3(in_dock.x,h_in-0.55,in_dock.z))
    _arm_pose(out_arm,Vector3(out_dock.x,h_out-0.55,out_dock.z))
    _truck_pose(truck_in,in_far,in_dock,0.0)
    _truck_pose(truck_out,out_far,out_dock,0.0)
    truck_in.visible = false
    truck_out.visible = false
    raw.visible = false

func _room_position(n: Node3D) -> Vector3:
    return room.to_local(n.global_position)

func _place(n: Node3D,p: Vector3) -> void:
    n.global_position = room.to_global(p)

func _in_pick() -> Vector3:
    return in_dock+Vector3.UP*(DECK_Y+0.14)

func _out_drop() -> Vector3:
    return out_dock+Vector3.UP*(DECK_Y+0.14)

func duration() -> float:
    return 48.0 if key=="STORAGE" else 26.0

func begin() -> void:
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
    storage_committed = false
    storage_removed = false

func reset() -> void:
    truck_in.visible = false
    truck_out.visible = false
    raw.visible = false
    if key=="STORAGE":
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
    load.visible = t<IN_END
    if t<0.10:
        _place(load,_room_position(truck_in)+Vector3.UP*(DECK_Y+0.14))
    else:
        var u: float = smoothstep(0.12,0.23,t)
        var p: Vector3 = _transfer(_in_pick(),inlet,float(in_arm["height"])-2.2,u)
        _place(load,p)
        _arm_pose(in_arm,p+Vector3.UP*0.80)
    if t<0.12:
        var pick: Vector3 = _in_pick()+Vector3.UP*0.80
        _arm_pose(in_arm,Vector3(pick.x,lerpf(float(in_arm["height"])-0.5,pick.y,smoothstep(0.09,0.12,t)),pick.z))
    if t>=0.23:
        _arm_pose(in_arm,inlet+Vector3.UP*lerpf(0.8,float(in_arm["height"])-inlet.y-0.5,smoothstep(0.23,0.29,t)))

func sample_out(t: float,payload: Node3D) -> void:
    truck_out.visible = t>=0.72 and t<1.0
    _truck_pose(truck_out,out_far,out_dock,smoothstep(0.72,0.81,t))
    if t>=0.94:
        _truck_pose(truck_out,out_dock,out_far,smoothstep(0.94,1.0,t),true)
    if payload==null:
        return
    if t>=0.81:
        var p: Vector3 = _transfer(outlet,_out_drop(),float(out_arm["height"])-2.2,smoothstep(0.83,0.93,t))
        if t>=0.94:
            p = _room_position(truck_out)+Vector3.UP*(DECK_Y+0.14)
        _place(payload,p)
        payload.visible = t<1.0
        _arm_pose(out_arm,p+Vector3.UP*1.35)
    else:
        var h: float = lerpf(float(out_arm["height"])-0.5,outlet.y+1.35,smoothstep(0.72,0.81,t))
        _arm_pose(out_arm,Vector3(outlet.x,h,outlet.z))
    if t>=0.93:
        var drop := _out_drop()
        _arm_pose(out_arm,Vector3(drop.x,lerpf(drop.y+1.35,float(out_arm["height"])-0.5,smoothstep(0.93,0.94,t)),drop.z))

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
        _box(b,Vector3(0,y,-5.4),Vector3(18.6,0.24,3.65),"armor")
        _box(b,Vector3(0,y,-3.51),Vector3(18.6,0.19,0.15),"gold")
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
        _box(b,Vector3(0,0.08,z),Vector3(21.0,0.16,0.14),"edge")
    _box(b,Vector3(0,12.8,aisle_z),Vector3(21.0,0.28,0.50),"gold")
    for x in [-10.55,10.55]:
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
        _poly(b,"bevel",Vector3(0,0.48,0),Vector3(3.10,0.96,3.85),"slate")
        _box(b,Vector3(0,1.02,0),Vector3(2.90,0.16,3.70),"armor_light")
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
    shelf_fork.position.z = reach
    shelf_fork.scale.z = maxf(1.0,absf(reach)/1.8)

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
    sample_in(t*1.45)
    pack.visible = t>=0.07 and t<0.26
    pack_lid.visible = t>=0.21
    pack_raw.visible = t>=0.16 and t<0.21
    pack_raw.position = storage_pack_point+Vector3.UP*0.14
    raw.visible = t<0.16
    if t>=0.16:
        raw.visible = false
    var target: Vector3 = _room_position(storage_slots[store_index])
    var source: Vector3 = _room_position(storage_slots[take_index])
    shelf_box.visible = false
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
        var retract: Vector3 = target.lerp(Vector3(target.x,target.y,aisle_z),smoothstep(0.51,0.54,t))
        var move: Vector3 = retract.lerp(Vector3(source.x,source.y,aisle_z),smoothstep(0.54,0.57,t))
        _stacker(move,0.0)
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
        _stacker(Vector3(storage_out_point.x,storage_out_point.y,aisle_z),0.0)
        # Outbound carrier picks up the packed box itself; its shell is hidden.
        out_box.visible = false
        sample_out(0.72+0.28*smoothstep(0.82,1.0,t),shelf_box)
