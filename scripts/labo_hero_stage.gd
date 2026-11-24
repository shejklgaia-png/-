extends Node3D

const PlacementStore = preload("res://scripts/sera_placement_store.gd")
const LaboMonitor = preload("res://scripts/sera_labo_monitor_24fps.gd")
enum Display { PRINT, FLOW, PURITY, RECYCLE, INVENTORY, SCANNER }
const RebuiltScenes = preload("res://scripts/labo_rebuilt_scenes.gd")
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const CrateModel = preload("res://scripts/sera_crate_model.gd")
const SharedMaterialShading = preload("res://scripts/sera_fullbody_material_preview.gd")
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
## Three independently built portrait-game LABO preview stages. Geometry and
## camera placement follow the three panoramic Scene A / B / C user references.
## Only the CRATE model is shared with the outdoor base; no generic room reuse.
## Retain tiny SubViewport and instanced static cargo for Android performance.
var crate: Node3D
var crate_route: Node3D
var crate_route_poses: Dictionary = {}
var crate_head: Node3D
var crate_arm: Node3D
var crate_left_arm: Node3D
var hero_camera: Camera3D
var camera_look: Vector3 = Vector3.ZERO
var camera_previews: Dictionary = {}
var warehouse_scanner: Node3D
var printer_nozzle: Node3D
var printed_part: Node3D
var work_state: String = "walk_to_terminal"
var state_time: float = 0.0
var clock: float = 0.0
var current_section: String = "LABO"
var printer_group: Node3D
var converter_group: Node3D
var warehouse_group: Node3D
var converter_crystals: Array[Node3D] = []
var rebuilt_scenes: RefCounted


# Room architecture and machinery live in labo_rebuilt_scenes.gd.
func _sign(parent: Node3D, caption: String, at: Vector3,
        size: int = 42) -> Label3D:
    var label := Label3D.new()
    label.name = "IndustrialSign_" + caption.replace(" ", "_")
    label.text = caption
    # A bundled Latin display face avoids tiny Japanese-font fallback strokes
    # on distant 3D signs. Higher glyph resolution retains world-space scale.
    label.font = LaboSkin.display_font()
    label.font_size = int(round(float(size) * 1.25))
    label.pixel_size = 0.0028
    label.outline_size = 2
    label.outline_modulate = Color("#102633")
    label.modulate = Color("#e3f3f7")
    label.position = at
    parent.add_child(label)
    return label

# SCENE A: the reference is a near-horizontal industrial workshop,
# with a large 3D printer on the LEFT and open service area on the RIGHT.

func _live_display(parent: Node3D, label: String, front_z: float, size: Vector2, mode: int) -> void:
    # LABO monitors need an active 24Hz image even on GL Compatibility.
    # A native ImageTexture quad does not depend on custom spatial GLSL.
    var panel := LaboMonitor.new()
    panel.name = label
    panel.position.z = front_z
    panel.configure(size, mode)
    parent.add_child(panel)


func _build_crate() -> void:
    # Exact same factory and mesh as the roaming robot in the base.
    crate = CrateModel.create_model()
    crate_route = Node3D.new()
    crate_route.name = "CrateRoute"
    add_child(crate_route)
    crate_route.add_child(crate)
    crate_head = crate.get_node("HeadPivot") as Node3D
    crate_arm = crate.get_node("RightArmPivot") as Node3D
    crate_left_arm = crate.get_node("LeftArmPivot") as Node3D


func _ready() -> void:
    var world := WorldEnvironment.new()
    world.name = "Environment"
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#101e2b")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#b9cbd3")
    environment.ambient_light_energy = 0.72
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.name = "SofterIndustrialKeyLight"
    sun.rotation_degrees = Vector3(-43.0, 28.0, -8.0)
    sun.light_energy = 1.23
    sun.shadow_enabled = false
    add_child(sun)
    # Build each entirely independent room. Large photographic obstructions
    # from the previous close-up experiment are intentionally NOT instantiated.
    rebuilt_scenes = RebuiltScenes.new()
    rebuilt_scenes.build(self)
    _build_crate()
    # LAB manufacturing / recycling / storage use independent 3D scenes.
    # Retain emitted lights and no separate surface pass for solid shading.
    SharedMaterialShading.apply_to_subtree(self)
    var ink := SeraViewEdges.new()
    ink.name = "ViewEdges"
    add_child(ink)
    hero_camera = Camera3D.new()
    hero_camera.name = "HeroCamera"
    add_child(hero_camera)
    hero_camera.current = true
    hero_camera.near = 0.10
    hero_camera.far = 75.0
    set_section(current_section)

func set_section(section: String) -> void:
    current_section = section if section in ["LABO", "SMELTER", "RECYCLER", "STORAGE"] else "LABO"
    printer_group.visible = current_section == "LABO"
    converter_group.visible = current_section in ["SMELTER", "RECYCLER"]
    warehouse_group.visible = current_section == "STORAGE"
    clock = 0.0
    state_time = 0.0
    crate_head.rotation = Vector3.ZERO
    crate_arm.rotation = Vector3.ZERO
    crate_left_arm.rotation = Vector3.ZERO
    crate.scale = Vector3.ONE
    match current_section:
        "LABO":
            # Left printer opens to +X; the large right display looks back
            # across the central inspection aisle. CRATE travels between the
            # two functional areas, with both in the hero camera composition.
            # Wide-angle low viewpoint frames the full-height industrial
            # printer as the hero while keeping the operator display visible.
            # CRATE stays clear of the larger right-facing printer outfeed.
            crate.position = Vector3(-0.10, 0.0, -1.10)
            crate.rotation.y = 1.28
            work_state = "print_to_terminal"
            hero_camera.keep_aspect = Camera3D.KEEP_HEIGHT
            hero_camera.position = Vector3(2.45, 1.28, 5.10)
            hero_camera.fov = 62.0
            camera_look = Vector3(0.05, 2.05, -1.15)
            hero_camera.look_at(camera_look, Vector3.UP)
        "SMELTER", "RECYCLER":
            # Scene B: front LEFT 21 degree viewpoint and raised camera.
            # Orange vessel appears nearer than cyan and violet; four
            # front bins remain visible and CRATE stays to the right.
            crate.position = Vector3(3.00, 0.0, 0.45)
            crate.rotation.y = 2.34
            work_state = "refinery_audit"
            hero_camera.position = Vector3(-3.40, 2.90, 5.55)
            hero_camera.fov = 55.0
            camera_look = Vector3(-0.10, 1.65, -1.00)
            hero_camera.look_at(camera_look, Vector3.UP)
        "STORAGE":
            # Frame the freight from INSIDE the front of the enclosed hall,
            # not from outside its open set. The wider racks fill the hero
            # viewport without showing the room's exposed roof or floor edges.
            # Keep all inventory UI and CRATE movement targets unchanged.
            crate.position = Vector3(0.05, 0.0, 0.85)
            crate.rotation.y = -2.87
            work_state = "storage_scan"
            hero_camera.keep_aspect = Camera3D.KEEP_HEIGHT
            hero_camera.position = Vector3(0.70, 2.65, 4.65)
            hero_camera.fov = 56.0
            camera_look = Vector3(0.00, 1.95, -2.65)
            hero_camera.look_at(camera_look, Vector3.UP)

    var key: String = camera_section_id()
    crate_route.transform = crate_route_poses.get(key, Transform3D.IDENTITY)
    for target in placement_models():
        var model_saved: Dictionary = PlacementStore.read(_model_placement_key(target))
        if model_saved.get("space") == "parent_local" and model_saved.has("position") and model_saved.has("rotation_degrees"):
            target.position = PlacementStore.vec(model_saved["position"])
            target.rotation_degrees = PlacementStore.vec(model_saved["rotation_degrees"])
    if camera_previews.has(key):
        var pose: Dictionary = camera_previews[key]
        apply_camera_preview(pose["eye"], pose["look"], float(pose["fov"]))
    else:
        var saved: Dictionary = PlacementStore.read("labo/camera/" + key)
        if saved.has("eye") and saved.has("look") and saved.has("fov"):
            apply_camera_preview(PlacementStore.vec(saved["eye"]),
                PlacementStore.vec(saved["look"]), float(saved["fov"]))


func camera_section_id() -> String:
    return "REFINERY" if current_section in ["SMELTER", "RECYCLER"] else current_section


func apply_camera_preview(eye: Vector3, look: Vector3, fov: float) -> void:
    camera_look = look
    hero_camera.position = eye
    hero_camera.look_at(camera_look, Vector3.UP)
    hero_camera.fov = fov
    camera_previews[camera_section_id()] = {"eye": eye, "look": look, "fov": fov}


func placement_models() -> Array[Node3D]:
    var room: Node3D = printer_group
    var names: Array[String] = ["AtlasOpenFramePrinter", "TechnicalConsole"]
    match camera_section_id():
        "REFINERY":
            room = converter_group
            names = ["RefineryTower_00", "RefineryTower_01", "RefineryTower_02", "MaterialReceivingArray", "RefineryOperator_0", "RefineryOperator_1", "RecycleStatus"]
        "STORAGE":
            room = warehouse_group
            names = ["CargoRackPort", "CargoRackStarboard", "CargoRackPortRear", "CargoRackStarboardRear", "RearFreightBulkhead", "ElevatingCargoPallet", "InventoryMasterMonitor", "WarehouseScanningConsole", "TravelingInventoryScanner", "WallSideOverstockPallets", "BulkOutbound_-1", "BulkOutbound_1"]
    var targets: Array[Node3D] = []
    for target_name in names:
        var target := room.get_node_or_null(NodePath(target_name)) as Node3D
        if target != null:
            targets.append(target)
    targets.append(crate_route)
    return targets


func _model_placement_key(target: Node3D) -> String:
    return "labo/model/" + camera_section_id() + "/" + str(get_path_to(target))


func remember_model_placement(target: Node3D) -> void:
    if target == crate_route:
        crate_route_poses[camera_section_id()] = target.transform
    PlacementStore.stage(_model_placement_key(target), {
        "space": "parent_local", "position": PlacementStore.array3(target.position),
        "rotation_degrees": PlacementStore.array3(target.rotation_degrees)})


func flush_model_placement() -> void:
    PlacementStore.flush()


func _move_to(goal: Vector3, delta: float) -> bool:
    var planar := Vector3(goal.x, crate.position.y, goal.z)
    var diff: Vector3 = planar - crate.position
    if diff.length() <= 0.07:
        crate.position = planar
        return true
    crate.position = crate.position.move_toward(planar, minf(0.95*delta, 0.23))
    # CRATE's unified model faces -Z.
    var desired_yaw: float = atan2(-diff.x, -diff.z)
    crate.rotation.y = lerp_angle(crate.rotation.y, desired_yaw, minf(1.0, 2.8*delta))
    crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.0, minf(1.0, 3.5*delta))
    crate_arm.rotation.x = lerpf(crate_arm.rotation.x, 0.0, minf(1.0, 3.0*delta))
    crate_left_arm.rotation.x = lerpf(crate_left_arm.rotation.x, 0.0, minf(1.0, 3.0*delta))
    return false

func _enter(state: String) -> void:
    work_state = state
    state_time = 0.0

func _process(delta: float) -> void:
    clock += delta
    state_time += delta
    rebuilt_scenes.animate(clock, current_section)
    match current_section:
        "LABO":
            _animate_manufacturing(delta)
        "SMELTER", "RECYCLER":
            _animate_refinery(delta)
        "STORAGE":
            _animate_inventory(delta)

func _animate_manufacturing(delta: float) -> void:
    # Printer nozzle moves in the local, scaled printer frame.
    printer_nozzle.position.x = 0.13 + 0.24*sin(clock*1.8)
    printer_nozzle.position.z = 0.24 + 0.13*cos(clock*1.2)
    printed_part.scale.y = 0.92 + 0.06*sin(clock*0.4)
    match work_state:
        "print_to_terminal":
            # Keep the central aisle clear: the terminal sits farther back
            # while the operator approaches its front-left work position.
            if _move_to(Vector3(1.87, 0, -0.68), delta):
                _enter("print_inspect_terminal")
        "print_inspect_terminal":
            crate.rotation.y = lerp_angle(crate.rotation.y, -0.33, minf(delta*2.0, 1.0))
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.17, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = -0.30 + 0.06*sin(clock*2.2)
            if state_time > 3.2:
                _enter("print_to_machine")
        "print_to_machine":
            # The printer has a right-facing opening. Stop to the right
            # of its output tray, never inside the print envelope.
            if _move_to(Vector3(-0.10, 0, -1.10), delta):
                _enter("print_inspect_shell")
        "print_inspect_shell":
            crate.rotation.y = lerp_angle(crate.rotation.y, 1.58, minf(delta*2.5, 1.0))
            crate_head.rotation.x = lerpf(crate_head.rotation.x, -0.13, minf(delta*3.0, 1.0))
            crate_left_arm.rotation.x = 0.12*sin(clock*1.8)
            if state_time > 2.8:
                _enter("print_to_terminal")

func _animate_refinery(delta: float) -> void:
    # Low amplitude rotation/pulsing inside chambers; caps and columns are fixed.
    for i in range(converter_crystals.size()):
        var rotor: Node3D = converter_crystals[i]
        rotor.rotation.y = clock*(0.16 + float(i)*0.10)
        rotor.position.y = 1.05 + 0.028*sin(clock*1.65 + float(i))
    match work_state:
        "refinery_audit":
            crate.rotation.y = lerp_angle(crate.rotation.y, 2.40, minf(delta*2.0, 1.0))
            crate_head.rotation.y = 0.13*sin(clock*0.8)
            crate_arm.rotation.x = -0.21 + 0.12*sin(clock*1.8)
            if state_time > 3.5:
                _enter("refinery_to_samples")
        "refinery_to_samples":
            if _move_to(Vector3(2.47, 0, 0.62), delta):
                _enter("refinery_sort")
        "refinery_sort":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.26, minf(delta*3.0, 1.0))
            crate_left_arm.rotation.x = -0.24 + 0.18*sin(clock*2.4)
            if state_time > 2.9:
                _enter("refinery_return")
        "refinery_return":
            if _move_to(Vector3(3.0, 0, 0.45), delta):
                _enter("refinery_audit")

func _animate_inventory(delta: float) -> void:
    # Warehouse robot remains at aisle center rather than driving into a rack.
    warehouse_scanner.position.x = 0.12*sin(clock*1.5)
    warehouse_scanner.rotation.y = 0.08*sin(clock*0.8)
    match work_state:
        "storage_scan":
            crate_head.rotation.y = 0.18*sin(clock*0.8)
            crate_arm.rotation.x = -0.12
            if state_time > 2.6:
                _enter("storage_go_left")
        "storage_go_left":
            if _move_to(Vector3(-0.68, 0, 0.72), delta):
                _enter("storage_get_bin")
        "storage_get_bin":
            crate_left_arm.rotation.x = -0.24 + 0.14*sin(clock*2.1)
            crate_head.rotation.x = lerpf(crate_head.rotation.x, -0.15, minf(delta*3.0, 1.0))
            if state_time > 2.2:
                _enter("storage_go_terminal")
        "storage_go_terminal":
            if _move_to(Vector3(0.47, 0, 0.58), delta):
                _enter("storage_log_stock")
        "storage_log_stock":
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.18, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = -0.16 + 0.05*sin(clock*2.5)
            if state_time > 2.5:
                _enter("storage_scan")
