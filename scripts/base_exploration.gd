extends Node3D
## Outdoor portrait base hub; CRATE wanders independently and NEXUS is a tappable building.
const Modules = preload("res://assets/base_command_modules.gd")
const SeraRig = preload("res://scripts/sera_rig.gd")
const VersionIndicator = preload("res://scripts/version_indicator.gd")
const NEXUS_SCENE: String = "res://scenes/command_nexus.tscn"
# Fill nearly the entire 256 m continuous ground with actual visible
# 3D grid plates, leaving no ungridded view at the extreme camera positions.
const PLATE_GRID_RADIUS_CELLS: int = 42
const PLATE_GRID_STEP: float = 3.0
const WALK_SPEED: float = 3.2
const PLAYER_Y: float = 0.08
const JOYSTICK_RADIUS: float = 76.0
const NEXUS_BUILDING_ORIGIN: Vector3 = Vector3(0.0, 0.0, -7.4)
const CRATE_SPEED: float = 0.95
const CRATE_WAYPOINTS = [
    Vector2(-3.8, 2.6), Vector2(-4.2, 0.6), Vector2(-2.8, 0.0),
    Vector2(1.6, 0.5), Vector2(3.7, 2.8), Vector2(1.6, 4.4),
    Vector2(-2.5, 4.2)
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

func _ready() -> void:
    _setup_world()
    _build_hangar()
    _build_nexus_building()
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
        Color("#3b4758"), Color("#4d5765"), Color("#323f50"),
        Color("#586171"), Color("#465162"), Color("#3f4a5d")
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
        mat.metallic = 0.25
        mat.roughness = 0.70
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
        Vector3(256.0, 0.30, 256.0), Color("#323f50"))
    _create_grid_plates(floor)
    _add_module("maintenance_pad", Vector3(-4.25, 0.0, -1.8), 0.0, 0.72)
    _add_module("kiosk", Vector3(4.25, 0.0, 1.2), 0.0, 0.85)
    _add_module("data_bank", Vector3(5.0, 0.0, -3.0), 0.0, 0.52)
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
    # Projection-based hit testing uses these real 3D extents.
    nexus_building = Node3D.new()
    nexus_building.name = "NEXUSBuilding"
    nexus_building.position = NEXUS_BUILDING_ORIGIN
    add_child(nexus_building)
    _box(nexus_building, "Foundation", Vector3(0, 0.23, 0),
        Vector3(6.4, 0.46, 5.4), Color("#293644"))
    _box(nexus_building, "Hall", Vector3(0, 2.30, -0.10),
        Vector3(5.80, 4.10, 4.95), Color("#596679"))
    _box(nexus_building, "ReinforcedRoof", Vector3(0, 4.48, -0.10),
        Vector3(6.25, 0.34, 5.25), Color("#253746"))
    _box(nexus_building, "EntryFrame", Vector3(0, 1.47, 2.44),
        Vector3(2.52, 2.92, 0.26), Color("#263748"))
    _box(nexus_building, "SealedGate", Vector3(0, 1.33, 2.61),
        Vector3(1.85, 2.48, 0.12), Color("#0c2230"))
    _box(nexus_building, "EntryLight", Vector3(0, 2.81, 2.64),
        Vector3(2.12, 0.13, 0.16), Color("#3cc9ea"))
    for side in [-1.0, 1.0]:
        _box(nexus_building, "SupportPillar", Vector3(side * 2.55, 2.25, 2.50),
            Vector3(0.40, 4.48, 0.38), Color("#29394b"))
        _box(nexus_building, "RoofVent", Vector3(side * 1.76, 4.76, -0.85),
            Vector3(0.94, 0.42, 1.12), Color("#384958"))
    var sign := Label3D.new()
    sign.name = "NEXUSBuildingSign"
    sign.text = "N E X U S"
    sign.font_size = 104
    sign.pixel_size = 0.0062
    sign.modulate = Color("#bdeefa")
    sign.position = Vector3(0.0, 3.50, 2.69)
    nexus_building.add_child(sign)

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
        Vector3(-5.85, 0.0, 5.3), Vector3(-5.70, 0.0, -0.7),
        Vector3(5.70, 0.0, 5.7), Vector3(5.85, 0.0, -1.5),
        Vector3(-5.75, 0.0, -10.5), Vector3(5.70, 0.0, -5.6)
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
    # Temporary low-poly CRATE: tracked chassis, visor and three-finger hands;
    # no human face/emoji. It will be replaced by its canonical Blockbench model.
    crate = Node3D.new()
    crate.name = "CRATE"
    crate.position = Vector3(-3.05, 0.06, -3.25)
    crate.rotation.y = -0.5
    add_child(crate)
    _box(crate, "Chassis", Vector3(0, 0.37, 0), Vector3(0.90, 0.50, 0.68), Color("#657487"))
    for side in [-1.0, 1.0]:
        _box(crate, "Track", Vector3(side * 0.48, 0.24, 0),
            Vector3(0.23, 0.32, 0.83), Color("#202a34"))
        _box(crate, "Manipulator", Vector3(side * 0.52, 0.62, -0.15),
            Vector3(0.15, 0.14, 0.50), Color("#a5afbd"))
        for finger in [-1.0, 0.0, 1.0]:
            _box(crate, "Finger", Vector3(side * 0.52 + finger * 0.10, 0.60, -0.47),
                Vector3(0.085, 0.09, 0.18), Color("#ccd3d9"))
    _box(crate, "VisorHousing", Vector3(0, 0.71, -0.25),
        Vector3(0.70, 0.28, 0.18), Color("#111b29"))
    _box(crate, "VisorGlass", Vector3(0, 0.71, -0.35),
        Vector3(0.59, 0.16, 0.035), Color("#4cc3db"))
    _box(crate, "RearToolBin", Vector3(0, 0.70, 0.34),
        Vector3(0.56, 0.25, 0.27), Color("#505e71"))

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
    cam.fov = 67.0
    cam.near = 0.1
    cam.position = Vector3(0.0, 19.6, 13.3)
    add_child(cam)
    cam.look_at(Vector3(0.0, 0.0, -2.2), Vector3.UP)
    cam.current = true

func _label(parent: Node, title: String, size: int) -> Label:
    var node := Label.new()
    node.text = title
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
    hud_title = _label(hud, "SERA / BASE", 25)
    hint = _label(hud, "NEXUSの建物をタップして施設へ", 19)
    nexus_tag = _label(hud, "N E X U S  ▸", 20)
    nexus_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nexus_tag.add_theme_color_override("font_color", Color("#8be4ff"))
    stick_outer = _panel(hud, "MoveStickOuter")
    stick_knob = _panel(hud, "MoveStickKnob")
    VersionIndicator.attach(hud)
    hud.resized.connect(_layout_hud)
    _layout_hud()

func _layout_hud() -> void:
    if hud == null or stick_outer == null:
        return
    var view: Vector2 = hud.size
    hud_title.position = Vector2(18, 18)
    hud_title.size = Vector2(view.x * 0.52, 42)
    hint.position = Vector2(18, 72)
    hint.size = Vector2(view.x - 36, 38)
    hint.add_theme_font_size_override("font_size", 16 if view.x < 600.0 else 19)
    stick_outer.position = Vector2(view.x - 180, view.y - 194)
    stick_outer.size = Vector2(164, 164)
    stick_knob.size = Vector2(72, 72)
    _update_stick_visual()
    _update_nexus_tag()

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

func _input(event: InputEvent) -> void:
    if scene_changing or hud == null:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if _nexus_hit(event.position):
                nexus_touch_id = event.index
                nexus_touch_start = event.position
            elif _hit(stick_outer, event.position) and touch_id == -1:
                touch_id = event.index
                _set_stick(event.position)
            else:
                return
        elif event.index == nexus_touch_id:
            nexus_touch_id = -1
            if nexus_touch_start.distance_to(event.position) <= 22.0 and _nexus_hit(event.position):
                _enter_nexus()
        elif event.index == touch_id:
            touch_id = -1
            joystick = Vector2.ZERO
            _update_stick_visual()
        else:
            return
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == touch_id:
        _set_stick(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if _nexus_hit(event.position):
                _enter_nexus()
            elif _hit(stick_outer, event.position):
                mouse_steering = true
                _set_stick(event.position)
            else:
                return
        else:
            mouse_steering = false
            joystick = Vector2.ZERO
            _update_stick_visual()
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and mouse_steering:
        _set_stick(event.position)
        get_viewport().set_input_as_handled()

func _walkable(pos: Vector3) -> bool:
    if absf(pos.x) > 6.0 or pos.z < -10.0 or pos.z > 10.0:
        return false
    if absf(pos.x) < 3.45 and pos.z < -4.35:
        return false
    return Vector2(pos.x + 4.25, pos.z + 1.8).length() > 1.10

func _move_player(direction: Vector2, delta: float) -> void:
    if player == null or direction.length_squared() < 0.000001:
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
    if cam != null:
        var offset := Vector3(player.position.x * 0.18, 19.6,
            13.3 + player.position.z * 0.12)
        cam.position = cam.position.lerp(offset, minf(1.0, delta * 2.5))
        cam.look_at(Vector3(player.position.x * 0.18, 0.0,
            -2.2 + player.position.z * 0.12), Vector3.UP)
    _update_nexus_tag()

func _enter_nexus() -> void:
    if scene_changing:
        return
    scene_changing = true
    SeraSave.requested_nexus_target = ""
    var error: Error = get_tree().change_scene_to_file(NEXUS_SCENE)
    if error != OK:
        scene_changing = false
        push_error("SERA BASE -> NEXUS scene load failed (%d)" % error)
