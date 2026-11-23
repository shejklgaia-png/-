extends Node3D
const DISPLAY_SHADER = preload("res://assets/monitors/labo_display.gdshader")
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
var crate_head: Node3D
var crate_arm: Node3D
var crate_left_arm: Node3D
var hero_camera: Camera3D
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
    var panel := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = size
    var material := ShaderMaterial.new()
    material.shader = DISPLAY_SHADER
    material.set_shader_parameter("mode", mode)
    panel.name = label
    panel.position.z = front_z
    panel.mesh = quad
    panel.material_override = material
    panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    panel.set_meta("FX_NO_OUTLINE", true)
    panel.set_meta("sera_preserve_authored_material", true)
    parent.add_child(panel)


func _build_crate() -> void:
    # Exact same factory and mesh as the roaming robot in the base.
    crate = CrateModel.create_model()
    add_child(crate)
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
            # Scene A: low camera from front RIGHT (24 degree yaw) makes the
            # oversized left printer gantry visibly three-dimensional,
            # while preserving CRATE and terminal on the right.
            crate.position = Vector3(1.96, 0.0, 0.55)
            crate.rotation.y = 2.26
            work_state = "print_to_terminal"
            hero_camera.position = Vector3(2.65, 1.45, 4.40)
            hero_camera.fov = 54.0
            hero_camera.look_at(Vector3(0.15, 1.80, -0.70), Vector3.UP)
        "SMELTER", "RECYCLER":
            # Scene B: front LEFT 21 degree viewpoint and raised camera.
            # Orange vessel appears nearer than cyan and violet; four
            # front bins remain visible and CRATE stays to the right.
            crate.position = Vector3(3.00, 0.0, 0.45)
            crate.rotation.y = 2.34
            work_state = "refinery_audit"
            hero_camera.position = Vector3(-3.40, 2.90, 5.55)
            hero_camera.fov = 55.0
            hero_camera.look_at(Vector3(-0.10, 1.65, -1.00), Vector3.UP)
        "STORAGE":
            # Scene C: from front RIGHT, moderately elevated (23 degree yaw).
            # The near right shelf shows its depth while both label banks
            # and the central monitoring terminal remain in frame.
            crate.position = Vector3(0.05, 0.0, 0.85)
            crate.rotation.y = -2.87
            work_state = "storage_scan"
            hero_camera.position = Vector3(3.35, 2.45, 5.35)
            hero_camera.fov = 55.0
            hero_camera.look_at(Vector3(0.00, 1.75, -1.00), Vector3.UP)

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
            if _move_to(Vector3(2.60, 0, 0.24), delta):
                _enter("print_inspect_terminal")
        "print_inspect_terminal":
            crate.rotation.y = lerp_angle(crate.rotation.y, 2.10, minf(delta*2.0, 1.0))
            crate_head.rotation.x = lerpf(crate_head.rotation.x, 0.17, minf(delta*3.0, 1.0))
            crate_arm.rotation.x = -0.30 + 0.06*sin(clock*2.2)
            if state_time > 3.1:
                _enter("print_to_machine")
        "print_to_machine":
            if _move_to(Vector3(1.32, 0, 0.42), delta):
                _enter("print_inspect_shell")
        "print_inspect_shell":
            crate.rotation.y = lerp_angle(crate.rotation.y, 2.65, minf(delta*2.5, 1.0))
            crate_head.rotation.x = lerpf(crate_head.rotation.x, -0.13, minf(delta*3.0, 1.0))
            crate_left_arm.rotation.x = 0.12*sin(clock*1.8)
            if state_time > 2.6:
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
    warehouse_scanner.position.x = 1.53 + 0.12*sin(clock*1.5)
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
