extends Node3D
## Explorable portrait base. The established Command Nexus continues to own
## equipment, save data, deployment, training and archive menus.
const Modules = preload("res://assets/base_command_modules.gd")
const SeraRig = preload("res://scripts/sera_rig.gd")
const NEXUS_SCENE: String = "res://scenes/command_nexus.tscn"
const WALK_SPEED: float = 3.2
const PLAYER_Y: float = 0.08
const JOYSTICK_RADIUS: float = 76.0
const INTERACT_RADIUS: float = 1.8
const STATIONS = [
    {"name": "CRATE / WORKSHOP", "focus": "CUSTOMIZE", "at": Vector2(-2.55, -4.65)},
    {"name": "TRAINING ROOM", "focus": "TRAINING", "at": Vector2(2.10, 2.80)},
    {"name": "SYSTEM", "focus": "SYSTEM", "at": Vector2(-2.10, 2.80)},
    {"name": "DATA ARCHIVE", "focus": "DATA ARCHIVE", "at": Vector2(-4.40, -7.50)},
    {"name": "DEPLOYMENT", "focus": "DEPLOYMENT", "at": Vector2(4.35, -8.60)}
]

var player: Node3D
var rig: Node3D
var cam: Camera3D
var hud: Control
var hud_title: Label
var hint: Label
var stick_outer: Panel
var stick_knob: Panel
var interact_panel: Panel
var interact_label: Label
var nexus_panel: Panel
var nexus_label: Label
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
    _create_salvage()
    _create_player()
    _create_crate()
    _create_camera()
    _create_hud()
    SeraSave.mark_location("NEXUS")

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

func _add_module(name: String, at: Vector3, yaw: float = 0.0, factor: float = 1.0) -> void:
    if not Modules.MODULES.has(name):
        push_error("Missing base Blockbench module: " + name)
        return
    var facing := Basis(Vector3.UP, yaw)
    for item in Modules.MODULES[name]:
        var low: Vector3 = _vec(item[1]) * Modules.UNIT * factor
        var high: Vector3 = _vec(item[2]) * Modules.UNIT * factor
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

func _build_hangar() -> void:
    # Preserve the actual authored Blockbench dimensions and placement used by NEXUS.
    _add_module("hangar_shell", Vector3.ZERO)
    _add_module("maintenance_pad", Vector3(0.0, 0.0, -4.75))
    _add_module("maintenance_canopy", Vector3(0.0, 8.0, -8.95))
    _add_module("deployment_gate", Vector3(4.00, 0.02, -10.48), PI, 1.20)
    _add_module("system_mezzanine", Vector3(-4.00, 0.0, -6.55))
    _add_module("data_bank", Vector3(-4.00, 2.19, -8.95))
    _add_module("kiosk", Vector3(-1.95, 0.0, 1.30), deg_to_rad(36.0))
    _add_module("kiosk", Vector3(1.95, 0.0, 1.30), deg_to_rad(-36.0))
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
    hint = _label(hud, "設備に近づくと操作できます", 19)
    stick_outer = _panel(hud, "MoveStickOuter")
    stick_knob = _panel(hud, "MoveStickKnob")
    interact_panel = _panel(hud, "Interact")
    interact_label = _label(interact_panel, "開く", 24)
    nexus_panel = _panel(hud, "OpenNexus")
    nexus_label = _label(nexus_panel, "NEXUS", 19)
    hud.resized.connect(_layout_hud)
    _layout_hud()

func _layout_hud() -> void:
    if hud == null or stick_outer == null:
        return
    var view: Vector2 = hud.size
    hud_title.position = Vector2(18, 18)
    hud_title.size = Vector2(view.x * 0.55, 42)
    nexus_panel.position = Vector2(view.x - 136, 18)
    nexus_panel.size = Vector2(120, 54)
    nexus_label.position = Vector2.ZERO
    nexus_label.size = nexus_panel.size
    nexus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    nexus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hint.position = Vector2(18, 78)
    hint.size = Vector2(view.x - 36, 38)
    hint.add_theme_font_size_override("font_size", 17 if view.x < 600.0 else 19)
    stick_outer.position = Vector2(view.x - 180, view.y - 194)
    stick_outer.size = Vector2(164, 164)
    stick_outer.get_theme_stylebox("panel").set_corner_radius_all(90)
    stick_knob.size = Vector2(72, 72)
    stick_knob.get_theme_stylebox("panel").set_corner_radius_all(40)
    _update_stick_visual()
    interact_panel.position = Vector2(18, view.y - 122)
    interact_panel.size = Vector2(142, 76)
    interact_label.position = Vector2.ZERO
    interact_label.size = interact_panel.size
    interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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
            if _hit(nexus_panel, event.position):
                _open_nexus("")
            elif interact_panel.visible and _hit(interact_panel, event.position):
                _interact()
            elif _hit(stick_outer, event.position) and touch_id == -1:
                touch_id = event.index
                _set_stick(event.position)
            else:
                return
        elif event.index == touch_id:
            touch_id = -1
            joystick = Vector2.ZERO
            _update_stick_visual()
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == touch_id:
        _set_stick(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if _hit(nexus_panel, event.position):
                _open_nexus("")
            elif interact_panel.visible and _hit(interact_panel, event.position):
                _interact()
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
    elif event.is_action_pressed("ui_accept"):
        _interact()
    elif event.is_action_pressed("ui_cancel"):
        _open_nexus("")

func _nearest_station() -> Dictionary:
    if player == null:
        return {}
    var here := Vector2(player.position.x, player.position.z)
    var found: Dictionary = {}
    var shortest: float = INTERACT_RADIUS
    for station in STATIONS:
        var distance: float = here.distance_to(station["at"])
        if distance <= shortest:
            found = station
            shortest = distance
    return found

func _walkable(pos: Vector3) -> bool:
    # Outer walls and the solid central service plinth must not be crossed.
    if absf(pos.x) > 6.0 or pos.z < -10.0 or pos.z > 10.0:
        return false
    return Vector2(pos.x, pos.z + 4.75).length() >= 1.75

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
    if crate != null:
        crate.position.y = 0.06 + sin(elapsed * 1.6) * 0.012
    if cam != null:
        var offset := Vector3(player.position.x * 0.18, 19.6, 13.3 + player.position.z * 0.12)
        cam.position = cam.position.lerp(offset, minf(1.0, delta * 2.5))
        cam.look_at(Vector3(player.position.x * 0.18, 0.0,
            -2.2 + player.position.z * 0.12), Vector3.UP)
    var station: Dictionary = _nearest_station()
    interact_panel.visible = not station.is_empty()
    if station.is_empty():
        hint.text = "設備に近づくと操作できます"
    else:
        hint.text = str(station["name"]) + "  /  操作可能"

func _interact() -> void:
    var station: Dictionary = _nearest_station()
    if station.is_empty():
        return
    _open_nexus(str(station["focus"]))

func _open_nexus(focus: String) -> void:
    if scene_changing:
        return
    scene_changing = true
    SeraSave.requested_nexus_target = focus
    var error: Error = get_tree().change_scene_to_file(NEXUS_SCENE)
    if error != OK:
        scene_changing = false
        SeraSave.requested_nexus_target = ""
        push_error("SERA base -> NEXUS scene load failed (%d)" % error)
