extends Node3D
## Outdoor portrait base hub; CRATE wanders independently and NEXUS is a tappable building.
const Modules = preload("res://assets/base_command_modules.gd")
const SeraRig = preload("res://scripts/sera_rig.gd")
const VersionIndicator = preload("res://scripts/version_indicator.gd")
const BaseFacilities = preload("res://scripts/base_facility_system.gd")
const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")
const BaseFloorDetail = preload("res://scripts/sera_base_floor_detail.gd")
const WEATHERED_STEEL_PATH: String = "res://assets/base/industrial_steel_grunge.svg"
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const CrateModel = preload("res://scripts/sera_crate_model.gd")
const NEXUS_SCENE: String = "res://scenes/command_nexus.tscn"
# Fill nearly the entire 256 m continuous ground with actual visible
# 3D grid plates, leaving no ungridded view at the extreme camera positions.
const PLATE_GRID_RADIUS_CELLS: int = 42
const PLATE_GRID_STEP: float = 3.0
# Re-enable this single flag when base SERA/joystick play is needed again.
# This only changes the outdoor base; NEXUS previews and combat are intact.
const HUB_SERA_CONTROLS_ENABLED: bool = false
const WALK_SPEED: float = 3.2
const PLAYER_Y: float = 0.08
const JOYSTICK_RADIUS: float = 76.0
# True FOV-zero appearance: parallel rays (orthographic, not invalid fov=0).
# Keep vertical span stable on every 720x1280 portrait screen.
const BASE_ORTHO_SIZE: float = 38.0
const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 30.0, 25.0)
const BASE_CAMERA_TARGET: Vector3 = Vector3(0.0, 0.0, -2.2)
const NEXUS_BUILDING_ORIGIN: Vector3 = Vector3(-9.53, 0.0, -14.55)
const CRATE_SPEED: float = 0.95
# CRATE orbits the central LABO instead of walking through its walls.
# Side lanes and the lower/upper arcs stay clear of every machine foundation.
# Identical patrol loop, rotated to start CRATE on the camera-facing lane.
const CRATE_WAYPOINTS = [
    Vector2(3.30, -1.20), Vector2(3.30, -5.40),
    Vector2(0.00, -6.10), Vector2(-3.30, -5.40),
    Vector2(-3.30, -1.20), Vector2(-3.30, 2.40),
    Vector2(-1.50, 4.00), Vector2(1.50, 4.00),
    Vector2(3.30, 2.40)
]

var player: Node3D
var rig: Node3D
var cam: Camera3D
var hud: Control
var hud_title: Label
var hint: Label
var stick_outer: Panel
var stick_knob: Panel
var nexus_building: Node3D
var nexus_tag: Label
var nexus_touch_id: int = -1
var nexus_touch_start: Vector2 = Vector2.ZERO
var crate_waypoint: int = 0
var crate_wait: float = 0.0
var touch_id: int = -1
var joystick: Vector2 = Vector2.ZERO
var mouse_steering: bool = false
var scene_changing: bool = false
var elapsed: float = 0.0
var crate: Node3D
var batches: Dictionary = {}
var facility_system: Node3D
var facility_touch_id: int = -1
var facility_touch_key: String = ""
var facility_touch_start: Vector2 = Vector2.ZERO

func _ready() -> void:
    # Android system gesture must navigate the open field menu, not quit.
    get_window().go_back_requested.connect(_on_android_back)
    _setup_world()
    _build_hangar()
    _build_nexus_building()
    _build_field_facilities()
    _create_salvage()
    _create_player()
    _create_crate()
    _create_camera()
    _create_hud()
    SeraSave.mark_location("BASE")

func _setup_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#0b111b")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#a2b5cc")
    env.ambient_light_energy = 0.85
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-56.0, -25.0, 0.0)
    sun.light_energy = 1.35
    add_child(sun)

func _vec(values: Array) -> Vector3:
    return Vector3(float(values[0]), float(values[1]), float(values[2]))

func _add_module(name: String, at: Vector3, yaw: float = 0.0,
        factor: float = 1.0, height_factor: float = 1.0) -> void:
    if not Modules.MODULES.has(name):
        push_error("Missing base Blockbench module: " + name)
        return
    var facing := Basis(Vector3.UP, yaw)
    for item in Modules.MODULES[name]:
        var stretch := Vector3(1.0, height_factor, 1.0)
        var low: Vector3 = _vec(item[1]) * Modules.UNIT * factor * stretch
        var high: Vector3 = _vec(item[2]) * Modules.UNIT * factor * stretch
        var rot: Vector3 = _vec(item[4]) * (PI / 180.0)
        var basis: Basis = (facing * Basis.from_euler(rot)).scaled_local(high - low)
        var pose := Transform3D(basis, at + facing * ((low + high) * 0.5))
        var material_index: int = int(item[3])
        if not batches.has(material_index):
            batches[material_index] = []
        (batches[material_index] as Array).append(pose)

func _material(index: int) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    var tint := Color(Modules.PALETTE[index])
    mat.albedo_color = tint
    mat.metallic = 0.16
    mat.roughness = 0.72
    if index in [5, 6, 7]:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 1.4
    return mat

func _gate_facing_yaw() -> float:
    var toward_stage: Vector3 = Vector3(0.0, 0.0, -4.75) - Vector3(4.0, 0.02, -10.48)
    return atan2(toward_stage.x, toward_stage.z)

func _create_grid_plates(floor: Node3D) -> void:
    # Six colored MultiMeshes preserve the old 2.94 m patchwork panels and
    # narrow exposed seams. Expanding 35 individual MeshInstances to 7,225
    # would create excessive Android scene nodes and draw calls.
    var tints := [
        # Low-luminance charcoal; slight neutral/warm variation, not blue machinery tones.
        Color("#1e2326"), Color("#252729"), Color("#292b2a"),
        Color("#27292c"), Color("#21262a"), Color("#302c29")
    ]
    var plate_mesh := BoxMesh.new()
    plate_mesh.size = Vector3(2.94, 0.30, 2.94)
    var grid_extent: float = float(PLATE_GRID_RADIUS_CELLS) * PLATE_GRID_STEP + 1.47
    var grouped: Array = []
    for index in range(tints.size()):
        grouped.append([])
    for x in range(-PLATE_GRID_RADIUS_CELLS, PLATE_GRID_RADIUS_CELLS + 1):
        for z in range(-PLATE_GRID_RADIUS_CELLS, PLATE_GRID_RADIUS_CELLS + 1):
            var palette_index: int = posmod(x * 11 + z * 7, tints.size())
            (grouped[palette_index] as Array).append(
                Transform3D(Basis.IDENTITY,
                    Vector3(float(x) * PLATE_GRID_STEP, -0.18,
                        float(z) * PLATE_GRID_STEP)))
    # The no-cache font test constructs this scene before SVG import is ready.
    var steel_texture: Texture2D = null
    if ResourceLoader.exists(WEATHERED_STEEL_PATH):
        steel_texture = load(WEATHERED_STEEL_PATH) as Texture2D
    for palette_index in range(tints.size()):
        var poses: Array = grouped[palette_index]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = plate_mesh
        # Under a headless dummy renderer the GPU transform buffer cannot be
        # read back. Explicit bounds also make wide instances safe to cull.
        multi.custom_aabb = AABB(
            Vector3(-grid_extent, -0.40, -grid_extent),
            Vector3(grid_extent * 2.0, 0.80, grid_extent * 2.0))
        multi.instance_count = poses.size()
        for index in range(poses.size()):
            multi.set_instance_transform(index, poses[index])
        var draw := MultiMeshInstance3D.new()
        draw.name = "GridPlateBatch_%02d" % palette_index
        draw.multimesh = multi
        var mat := StandardMaterial3D.new()
        mat.albedo_color = tints[palette_index]
        mat.metallic = 0.12
        mat.roughness = 0.94
        mat.albedo_texture = steel_texture
        draw.material_override = mat
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        floor.add_child(draw)

func _build_hangar() -> void:
    # Exterior base: the enclosed Blockbench hangar remains inside the NEXUS menu.
    var floor := Node3D.new()
    floor.name = "PatchworkSteelFloor"
    add_child(floor)
    # The dark one-piece ground remains visible only in the 0.06 m seams.
    _box(floor, "ContinuousGround", Vector3(0.0, -0.21, 0.0),
        Vector3(256.0, 0.30, 256.0), Color("#12171b"))
    _create_grid_plates(floor)
    BaseFloorDetail.decorate(floor)
    # Keep legacy decorative models away from interactive equipment footprints.
    # Decorative Blockbench props occupy the frame edges, never machinery
    # foundations or raw touch pick volumes in the orthographic composition.
    _add_module("maintenance_canopy", Vector3(-20.2, 0.0, -13.6), 0.0, 0.62)
    _add_module("kiosk", Vector3(-4.0, 0.0, -22.5), 0.0, 0.85)
    _add_module("data_bank", Vector3(22.0, 0.0, -9.0), 0.0, 0.52)
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    for palette_index in batches.keys():
        var poses: Array = batches[palette_index]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = cube
        multi.instance_count = poses.size()
        for index in range(poses.size()):
            multi.set_instance_transform(index, poses[index])
        var draw := MultiMeshInstance3D.new()
        draw.name = "BaseBlockbenchBatch_%02d" % int(palette_index)
        draw.multimesh = multi
        draw.material_override = _material(int(palette_index))
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(draw)

func _build_nexus_building() -> void:
    # Rebuilt physical architecture retains the exact 3D screen-picking extents.
    nexus_building = Node3D.new()
    nexus_building.name = "NEXUSBuilding"
    nexus_building.position = NEXUS_BUILDING_ORIGIN
    add_child(nexus_building)
    _box(nexus_building, "Foundation", Vector3(0, 0.23, 0),
        Vector3(6.4, 0.46, 5.4), Color("#46535c"))
    BaseArchitecture.build_nexus(nexus_building)
    var sign := Label3D.new()
    sign.name = "NEXUSBuildingSign"
    sign.text = "N E X U S"
    sign.font = LaboSkin.ui_font()
    sign.font_size = 104
    sign.pixel_size = 0.0062
    sign.modulate = Color("#bdeefa")
    sign.position = Vector3(0.0, 3.50, 2.69)
    sign.visible = false # One HUD label only, like the other seven facilities.
    nexus_building.add_child(sign)

func _build_field_facilities() -> void:
    facility_system = BaseFacilities.new()
    facility_system.name = "BaseFacilities"
    add_child(facility_system)

func _box(parent: Node3D, name: String, at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var body := MeshInstance3D.new()
    body.name = name
    body.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.25
    mat.roughness = 0.70
    body.material_override = mat
    body.position = at
    parent.add_child(body)
    return body

func _create_salvage() -> void:
    # Deliberate small props leave a clear central walkable lane.
    var lots := [
        Vector3(-9.83, 0.0, 0.28), Vector3(6.80, 0.0, 19.56),
        Vector3(4.65, 0.0, 6.62), Vector3(14.96, 0.0, 14.72),
        Vector3(4.80, 0.0, -11.02), Vector3(20.54, 0.0, 10.41),
        Vector3(-5.42, 0.0, -8.18), Vector3(5.71, 0.0, -7.88),
        Vector3(-7.21, 0.0, 6.65), Vector3(9.45, 0.0, 5.70),
        Vector3(-13.41, 0.0, -11.38), Vector3(4.90, 0.0, -17.16),
        Vector3(-13.50, 0.0, 3.82), Vector3(12.87, 0.0, 0.48),
        Vector3(5.21, 0.0, 10.48), Vector3(-3.20, 0.0, -18.15)
    ]
    for i in range(lots.size()):
        var pile := Node3D.new()
        pile.name = "ScrapPile_%02d" % i
        pile.position = lots[i]
        add_child(pile)
        _box(pile, "StackBase", Vector3(0, 0.20, 0),
            Vector3(0.90, 0.40, 0.76), Color("#46536a"))
        _box(pile, "RecoveredPanel", Vector3(0.10, 0.50, 0.06),
            Vector3(0.63, 0.18, 0.46), Color("#6c7886"))
        _box(pile, "Conduit", Vector3(-0.23, 0.71, 0),
            Vector3(0.13, 0.28, 0.50), Color("#bc9254"))

func _create_player() -> void:
    player = Node3D.new()
    player.name = "SERA"
    player.position = Vector3(0.0, PLAYER_Y, 5.6)
    add_child(player)
    player.visible = HUB_SERA_CONTROLS_ENABLED
    if not HUB_SERA_CONTROLS_ENABLED:
        # Preserve the invisible anchor for the camera but avoid loading the
        # expensive character rig into this menu scene.
        return
    rig = SeraRig.new()
    rig.name = "SeraRig"
    rig.scale = Vector3.ONE * 1.15
    player.add_child(rig)
    if not bool(rig.get("loading_ok")):
        push_warning("SERA base: character rig could not load")
    # Match the active NEXUS/Training equipment selections, not a fixed outfit.
    var gear: Dictionary = SeraSave.get_working_equipment()
    for part in gear.keys():
        if part in ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]:
            rig.call("set_equipment_selection", part, str(gear[part]))

func _create_crate() -> void:
    # Canonical robot: same geometry, proportions and materials as the LABO
    # close-up. Keep the outdoor path-following motion independent.
    crate = CrateModel.create_model()
    crate.position = Vector3(3.30, 0.06, 2.40)
    crate.rotation.y = -0.5
    add_child(crate)

func _update_crate(delta: float) -> void:
    if crate == null or delta <= 0.0:
        return
    if crate_wait > 0.0:
        crate_wait = maxf(0.0, crate_wait - delta)
        return
    var goal: Vector2 = CRATE_WAYPOINTS[crate_waypoint]
    var current := Vector2(crate.position.x, crate.position.z)
    var offset: Vector2 = goal - current
    if offset.length() < 0.06:
        crate_waypoint = (crate_waypoint + 1) % CRATE_WAYPOINTS.size()
        crate_wait = 0.85
        return
    var direction: Vector2 = offset.normalized()
    var step: float = minf(CRATE_SPEED * delta, offset.length())
    crate.position = Vector3(current.x + direction.x * step, 0.06,
        current.y + direction.y * step)
    crate.rotation.y = lerp_angle(crate.rotation.y,
        atan2(-direction.x, -direction.y), minf(1.0, delta * 7.0))

func _nexus_screen_rect() -> Rect2:
    if cam == null or nexus_building == null:
        return Rect2()
    var low := Vector2(INF, INF)
    var high := Vector2(-INF, -INF)
    for x in [-3.25, 3.25]:
        for y in [0.0, 4.9]:
            for z in [-2.8, 2.8]:
                var vertex: Vector3 = nexus_building.to_global(Vector3(x, y, z))
                if cam.is_position_behind(vertex):
                    continue
                var pixel: Vector2 = cam.unproject_position(vertex)
                low = Vector2(minf(low.x, pixel.x), minf(low.y, pixel.y))
                high = Vector2(maxf(high.x, pixel.x), maxf(high.y, pixel.y))
    if not is_finite(low.x) or not is_finite(high.x):
        return Rect2()
    return Rect2(low, high - low).grow(12.0)

func _nexus_hit(point: Vector2) -> bool:
    return _nexus_screen_rect().has_point(point)

func _create_camera() -> void:
    cam = Camera3D.new()
    cam.name = "BaseOverheadCamera"
    # A perspective Camera3D cannot have FOV=0. The mathematically correct
    # zero-perspective equivalent is this orthographic oblique overhead view.
    cam.projection = Camera3D.PROJECTION_ORTHOGONAL
    cam.keep_aspect = Camera3D.KEEP_HEIGHT
    cam.size = BASE_ORTHO_SIZE
    cam.near = 0.1
    cam.position = BASE_CAMERA_POSITION
    add_child(cam)
    cam.look_at(BASE_CAMERA_TARGET, Vector3.UP)
    cam.current = true

func _label(parent: Node, title: String, size: int) -> Label:
    var node := Label.new()
    node.text = title
    node.add_theme_font_override("font", LaboSkin.ui_font())
    node.add_theme_font_size_override("font_size", size)
    node.add_theme_color_override("font_color", Color("#dcebf3"))
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(node)
    return node

func _panel(parent: Node, title: String) -> Panel:
    var node := Panel.new()
    node.name = title
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.070, 0.12, 0.86)
    style.border_color = Color("#5dbed5")
    style.set_border_width_all(2)
    style.set_corner_radius_all(14)
    node.add_theme_stylebox_override("panel", style)
    parent.add_child(node)
    return node

func _create_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "BaseHUDLayer"
    add_child(layer)
    hud = Control.new()
    hud.name = "BaseHUD"
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # PRESET_FULL_RECT follows viewport size; manual size conflicts with anchors.
    hud_title = _label(hud, "BASE / 拠点", 25)
    hint = _label(hud, "建物をタップして施設を開く", 19)
    nexus_tag = _label(hud, "NEXUS", 20)
    nexus_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nexus_tag.add_theme_color_override("font_color", Color("#e4ebf0"))
    LaboSkin.attach_name_underline(nexus_tag)
    stick_outer = _panel(hud, "MoveStickOuter")
    stick_knob = _panel(hud, "MoveStickKnob")
    stick_outer.visible = HUB_SERA_CONTROLS_ENABLED
    stick_knob.visible = HUB_SERA_CONTROLS_ENABLED
    VersionIndicator.attach(hud)
    facility_system.call("attach_hud", hud)
    hud.resized.connect(_layout_hud)
    _layout_hud()

func _layout_hud() -> void:
    if hud == null or stick_outer == null:
        return
    var view: Vector2 = hud.size
    hud_title.position = Vector2(18, 18)
    hud_title.size = Vector2(view.x * 0.52, 42)
    hint.position = Vector2(18, view.y - 102.0)
    hint.size = Vector2(view.x - 36, 38)
    hint.add_theme_font_size_override("font_size", 16 if view.x < 600.0 else 19)
    stick_outer.position = Vector2(view.x - 180, view.y - 194)
    stick_outer.size = Vector2(164, 164)
    stick_knob.size = Vector2(72, 72)
    _update_stick_visual()
    _update_nexus_tag()
    facility_system.call("update_tags", cam)

func _update_nexus_tag() -> void:
    if cam == null or nexus_building == null or nexus_tag == null:
        return
    var point: Vector3 = nexus_building.global_position + Vector3(0, 5.1, 0)
    nexus_tag.visible = not cam.is_position_behind(point)
    if not nexus_tag.visible:
        return
    var pixel: Vector2 = cam.unproject_position(point)
    nexus_tag.position = pixel - Vector2(105.0, 18.0)
    nexus_tag.size = Vector2(210.0, 38.0)

func _stick_center() -> Vector2:
    return stick_outer.position + stick_outer.size * 0.5

func _update_stick_visual() -> void:
    if stick_knob != null and stick_outer != null:
        stick_knob.position = _stick_center() - stick_knob.size * 0.5 + joystick * 45.0

func _set_stick(pixel: Vector2) -> void:
    joystick = ((pixel - _stick_center()) / JOYSTICK_RADIUS).limit_length(1.0)
    _update_stick_visual()

func _hit(panel: Panel, at: Vector2) -> bool:
    return panel != null and Rect2(panel.position, panel.size).has_point(at)

func _on_android_back() -> void:
    if facility_system != null and bool(facility_system.call("is_menu_open")):
        facility_system.call("navigate_back")

func _input(event: InputEvent) -> void:
    if scene_changing or hud == null:
        return
    # An open field-device panel owns its own GUI input; do not route clicks
    # behind it to NEXUS, other machines, or the dormant joystick.
    if facility_system != null and bool(facility_system.call("is_menu_open")):
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if _nexus_hit(event.position):
                nexus_touch_id = event.index
                nexus_touch_start = event.position
            else:
                var key: String = str(facility_system.call("key_at", cam, event.position))
                if not key.is_empty():
                    facility_touch_id = event.index
                    facility_touch_key = key
                    facility_touch_start = event.position
                elif HUB_SERA_CONTROLS_ENABLED and _hit(stick_outer, event.position) and touch_id == -1:
                    touch_id = event.index
                    _set_stick(event.position)
                else:
                    return
        elif event.index == nexus_touch_id:
            nexus_touch_id = -1
            if nexus_touch_start.distance_to(event.position) <= 22.0 and _nexus_hit(event.position):
                _enter_nexus()
        elif event.index == facility_touch_id:
            facility_touch_id = -1
            var key: String = facility_touch_key
            facility_touch_key = ""
            if facility_touch_start.distance_to(event.position) <= 22.0 \
                    and str(facility_system.call("key_at", cam, event.position)) == key:
                facility_system.call("open_facility", key)
        elif event.index == touch_id:
            touch_id = -1
            joystick = Vector2.ZERO
            _update_stick_visual()
        else:
            return
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and HUB_SERA_CONTROLS_ENABLED and event.index == touch_id:
        _set_stick(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if _nexus_hit(event.position):
                _enter_nexus()
            else:
                var key: String = str(facility_system.call("key_at", cam, event.position))
                if not key.is_empty():
                    facility_system.call("open_facility", key)
                elif HUB_SERA_CONTROLS_ENABLED and _hit(stick_outer, event.position):
                    mouse_steering = true
                    _set_stick(event.position)
                else:
                    return
        else:
            mouse_steering = false
            joystick = Vector2.ZERO
            _update_stick_visual()
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and HUB_SERA_CONTROLS_ENABLED and mouse_steering:
        _set_stick(event.position)
        get_viewport().set_input_as_handled()

func _walkable(pos: Vector3) -> bool:
    if absf(pos.x) > 6.0 or pos.z < -10.0 or pos.z > 10.0:
        return false
    # Use each building's live footprint so the walkway stays accurate
    # when the layout is redistributed across the larger portrait field.
    if absf(pos.x - NEXUS_BUILDING_ORIGIN.x) < 3.45 and (
            absf(pos.z - NEXUS_BUILDING_ORIGIN.z) < 2.95):
        return false
    for spec in BaseFacilities.FACILITY_SPECS:
        var at: Vector3 = spec["at"]
        var size: Vector3 = spec["size"]
        if absf(pos.x - at.x) < size.x * 0.5 + 0.25 \
                and absf(pos.z - at.z) < size.z * 0.5 + 0.25:
            return false
    return true

func _move_player(direction: Vector2, delta: float) -> void:
    if not HUB_SERA_CONTROLS_ENABLED or player == null or direction.length_squared() < 0.000001:
        return
    var move: Vector2 = direction.limit_length(1.0) * WALK_SPEED * maxf(delta, 0.0)
    var pos: Vector3 = player.position
    var goal := Vector3(clampf(pos.x + move.x, -6.0, 6.0),
        PLAYER_Y, clampf(pos.z + move.y, -10.0, 10.0))
    if _walkable(goal):
        player.position = goal
    else:
        var slide_x := Vector3(goal.x, PLAYER_Y, pos.z)
        var slide_z := Vector3(pos.x, PLAYER_Y, goal.z)
        if _walkable(slide_x):
            player.position = slide_x
        elif _walkable(slide_z):
            player.position = slide_z

func _process(delta: float) -> void:
    if scene_changing or player == null:
        return
    elapsed += delta
    SeraSave.record_game_time(delta)
    if HUB_SERA_CONTROLS_ENABLED:
        var direction: Vector2 = joystick
        var keys := Vector2(
            Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
            Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
        if keys.length_squared() > 0.0001:
            direction = keys.limit_length(1.0)
        _move_player(direction, delta)
        var moving: bool = direction.length_squared() > 0.0001
        if moving:
            var yaw: float = atan2(-direction.x, -direction.y)
            player.rotation.y = lerp_angle(player.rotation.y, yaw, minf(1.0, delta * 11.0))
        if rig != null:
            rig.call("set_moving", moving, false, Vector2(0, 1), false)
    _update_crate(delta)
    # The outdoor BASE is a fixed isometric menu while SERA is disabled.
    # Preserve dormant player-follow logic only for a future controls re-enable.
    if cam != null and HUB_SERA_CONTROLS_ENABLED:
        var follow_shift := Vector3(player.position.x * 0.18, 0.0,
            player.position.z * 0.12)
        cam.position = cam.position.lerp(BASE_CAMERA_POSITION + follow_shift,
            minf(1.0, delta * 2.5))
        cam.look_at(BASE_CAMERA_TARGET + follow_shift, Vector3.UP)
    _update_nexus_tag()
    facility_system.call("update_tags", cam)

func _enter_nexus() -> void:
    if scene_changing:
        return
    scene_changing = true
    SeraSave.requested_nexus_target = ""
    var error: Error = get_tree().change_scene_to_file(NEXUS_SCENE)
    if error != OK:
        scene_changing = false
        push_error("SERA BASE -> NEXUS scene load failed (%d)" % error)
