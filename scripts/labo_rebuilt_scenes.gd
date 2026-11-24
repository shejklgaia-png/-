extends RefCounted
## Fresh close-up sets built directly from the active BASE authored geometry.
## Local +Z is the operating front. Uniform world-scale expansion preserves
## every machine datum, moving pivot, inlet, rack and workpiece relationship.
## The open work apron is full scale; CRATE remains the canonical 1:1 robot.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const Fresh = preload("res://scripts/sera_base_fresh_design.gd")
const Motion = preload("res://scripts/sera_base_facility_motion.gd")
const FacilityVFX = preload("res://scripts/sera_base_facility_vfx.gd")
const Monitor = preload("res://scripts/sera_labo_monitor_24fps.gd")
const KEYS = ["LABO", "SMELTER", "RECYCLER", "STORAGE"]
const WORLD_SCALE = {"LABO":2.0, "SMELTER":2.1, "RECYCLER":2.1, "STORAGE":2.2}
const TERMINAL_XZ = {"LABO":Vector2(1.55,2.65), "SMELTER":Vector2(-1.85,2.10),
    "RECYCLER":Vector2(1.72,2.0), "STORAGE":Vector2(0.88,1.92)}
const INSPECT_XZ = {"LABO":Vector2(-1.15,2.95), "SMELTER":Vector2(0.72,2.32),
    "RECYCLER":Vector2(-0.55,2.20), "STORAGE":Vector2(-1.55,2.05)}
const INSPECT_FOCUS = {"LABO":Vector3(0.10,1.30,1.13),
    "SMELTER":Vector3(0.0,1.45,1.05), "RECYCLER":Vector3(0,1.37,0.22),
    "STORAGE":Vector3(-1.20,1.27,1.18)}
var host: Node3D
var rooms: Dictionary = {}
var machines: Dictionary = {}
var motions: Dictionary = {}
var screens: Dictionary = {}
var furnace_vfx: Node
var active_key: String = ""
var cycle_clock: float = 0.0
var cycle_running: bool = false
var tick_accumulator: float = 0.0

func build(stage: Node3D) -> void:
    host = stage
    for key in KEYS:
        _build_set(key)

func _node(parent: Node3D, label: String) -> Node3D:
    var n := Node3D.new()
    n.name = label
    parent.add_child(n)
    return n

func _build_set(key: String) -> void:
    var room := _node(host, key + "_FullScaleWorksite")
    rooms[key] = room
    _build_deck(room, key)
    var machine := _node(room, "IndustrialModel")
    machines[key] = machine
    var k: float = float(WORLD_SCALE[key])
    machine.scale = Vector3.ONE * k
    # Foundation top approximately coincides with the work deck, while the
    # machine's original pedestal, stock shelf and intake remain unaltered.
    machine.position.y = -0.42 * k
    machine.set_meta("visual_model_scale", 1.0)
    machine.set_meta("body_yaw", 0.0)
    machine.set_meta("base_design", Architecture.ACTIVE_BASE_MODEL)
    var batch := Architecture.Batch.new(machine)
    batch.hard_edges = false
    batch.outline_enabled = true
    batch.motion_names = Motion.animated_features_for(key)
    Fresh.add_details(batch, key)
    _build_operator_station(batch, key, k)
    batch.flush()
    var motion := Motion.new()
    motion.bind_to(machine, key)
    motion.set_process(false)
    motions[key] = motion
    _add_displays(machine, key, k)
    if key == "SMELTER":
        Architecture._add_facility_lights(machine, key)
        furnace_vfx = FacilityVFX.new()
        furnace_vfx.setup(machine, key)
        furnace_vfx.set_process(false)
    room.visible = false

func _build_deck(room: Node3D, key: String) -> void:
    var deck := _node(room, "OpenIndustrialApron")
    var b := Architecture.Batch.new(deck)
    # Generously spaced 3m structural plates: seams are genuine geometry.
    for row in range(-3, 4):
        for col in range(-4, 5):
            b.poly("ApronSteelPlate", "deck", Vector3(col*3.0,-0.16,row*3.0),
                Vector3(2.985,0.30,2.985), "slate" if posmod(row+col,4) != 0 else "armor")
    # Keep all front work aisles clear; lighting and utilities sit well aft.
    for side in [-1.0,1.0]:
        b.box("ApronSafetyStripe", Vector3(side*8.8,0.012,0),
            Vector3(0.09,0.022,16.0),"caution")
        b.poly("RearServicePost", "octagonal_slew", Vector3(side*8.8,1.8,-7.8),
            Vector3(0.55,3.6,0.55),"trim")
        b.poly("RearServiceLamp", "hood", Vector3(side*8.8,3.65,-7.55),
            Vector3(1.10,0.24,0.65),"armor_light")
        b.box("RearServiceLampCore", Vector3(side*8.8,3.51,-7.44),
            Vector3(0.78,0.06,0.38),"blue_light")
    # Low rear utility barrier, not an invented enclosed room or false roof.
    for x in [-7.5,-4.5,-1.5,1.5,4.5,7.5]:
        b.poly("RearApronBarrier", "deck", Vector3(x,0.73,-8.6),
            Vector3(2.94,1.46,0.36),"trim")
        b.box("RearApronBarrierRim",Vector3(x,1.50,-8.6),
            Vector3(2.94,0.09,0.40),"edge")
    # Distinct worksite markings, separated from the machine footprint.
    var z: float = 6.25 if key == "LABO" else 5.25
    for x in [-5.4,5.4]:
        b.box("ApproachLaneMark",Vector3(x,0.013,z),Vector3(0.10,0.022,2.3),"caution")
    b.flush()
    for child in deck.get_children():
        if child is GeometryInstance3D:
            child.set_meta("sera_outline_occluder_only", true)
            child.set_meta("sera_preserve_authored_material", true)

func _build_operator_station(b, key: String, k: float) -> void:
    # Close-up-only remote station at robot height, outside the machine pad.
    # The original machine controls stay in their exact BASE locations.
    var p: Vector2 = TERMINAL_XZ[key]
    var base_y: float = 0.42
    b.poly("RemoteStationFoot", "bevel", Vector3(p.x,base_y+0.10/k,p.y),
        Vector3(0.72,0.20,0.66)/k,"trim")
    b.poly("RemoteStationColumn", "gusset", Vector3(p.x,base_y+0.64/k,p.y),
        Vector3(0.46,1.04,0.53)/k,"slate")
    b.poly("RemoteStationScreenHousing", "bevel", Vector3(p.x,base_y+1.19/k,p.y),
        Vector3(0.78,0.55,0.23)/k,"armor")
    b.box("RemoteStationControlStrip", Vector3(p.x,base_y+0.93/k,p.y+0.15/k),
        Vector3(0.70,0.09,0.12)/k,"edge")
    b.box("RemoteStationReadyLamp", Vector3(p.x-0.23/k,base_y+0.93/k,p.y+0.22/k),
        Vector3(0.10,0.05,0.035)/k,"lab_cyan")

func _screen(machine: Node3D, key: String, label: String, at: Vector3,
        span: Vector2, mode: int) -> void:
    var panel := Monitor.new()
    panel.name = label
    panel.position = at
    panel.configure(span, mode)
    machine.add_child(panel)
    panel.set_process(false)
    if not screens.has(key):
        screens[key] = []
    (screens[key] as Array).append(panel)

func _add_displays(machine: Node3D, key: String, k: float) -> void:
    var p: Vector2 = TERMINAL_XZ[key]
    var mode: int = int({"LABO":0,"SMELTER":2,"RECYCLER":3,"STORAGE":4}[key])
    _screen(machine,key,"RemoteWorkDisplay",
        Vector3(p.x,0.42+1.19/k,p.y+0.122/k),Vector2(0.64,0.42)/k,mode)
    match key:
        "LABO":
            _screen(machine,key,"OriginalPrinterDisplay",Vector3(1.46,1.37,1.665),
                Vector2(0.42,0.38),1)
        "STORAGE":
            _screen(machine,key,"LiftStatusDisplay",Vector3(-1.20,2.46,1.326),
                Vector2(0.28,0.15),5)

func select(key: String) -> void:
    active_key = key
    for id in KEYS:
        (rooms[id] as Node3D).visible = id == key
    cycle_running = false
    cycle_clock = 0.0
    tick_accumulator = 0.0
    var motion = motions[key]
    motion.prepare_material_intake()

func machine_for(key: String) -> Node3D:
    return machines[key] as Node3D

func work_point(key: String, inspect: bool) -> Vector3:
    var p: Vector2 = INSPECT_XZ[key] if inspect else TERMINAL_XZ[key]
    var model := machine_for(key)
    var world: Vector3 = model.to_global(Vector3(p.x,0.42,p.y+0.82/float(WORLD_SCALE[key])))
    return world

func focus_point(key: String, inspect: bool) -> Vector3:
    var model := machine_for(key)
    if inspect:
        return model.to_global(INSPECT_FOCUS[key])
    var p: Vector2 = TERMINAL_XZ[key]
    return model.to_global(Vector3(p.x,0.42+1.19/float(WORLD_SCALE[key]),p.y))

func start_cycle(key: String) -> void:
    if key != active_key:
        return
    var motion = motions[key]
    motion.receive_material_item()
    motion.receive_material_item()
    motion.begin_material_cycle()
    cycle_clock = 0.0
    tick_accumulator = 0.0
    cycle_running = true

func cycle_complete() -> bool:
    return not cycle_running

func animate(delta: float, time: float, key: String) -> void:
    if key != active_key:
        return
    for panel in screens.get(key, []):
        panel.call("_process",delta)
    if key == "SMELTER" and is_instance_valid(furnace_vfx):
        furnace_vfx.sample_fire(time)
    if not cycle_running:
        return
    cycle_clock += delta
    tick_accumulator += delta
    var duration: float = float(Motion.MATERIAL_SECONDS[key])
    if cycle_clock >= duration:
        motions[key].sample_at(duration-0.001)
        cycle_running = false
    elif tick_accumulator >= Motion.TICK_SECONDS:
        tick_accumulator = fmod(tick_accumulator,Motion.TICK_SECONDS)
        motions[key].sample_at(cycle_clock)
