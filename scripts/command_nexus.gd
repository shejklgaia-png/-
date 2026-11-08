extends Node3D
# v120: base equipment is authored in blockbench/base/SERA_*.bbmodel.
# This read-only display renders their embedded geometry in material batches.
const Modules = preload("res://assets/base_command_modules.gd")
const SeraRig = preload("res://scripts/sera_rig.gd")
const TagIcon = preload("res://scripts/nexus_tag_icon.gd")

var batch_data: Dictionary = {}
var hud: Control
var tags: Array[Dictionary] = []

func _ready() -> void:
    _environment()
    _module("hangar_shell", Vector3.ZERO)
    _module("maintenance_pad", Vector3(0.0, 0.0, -4.05))
    _module("maintenance_canopy", Vector3(0.0, 8.0, -8.95))
    _module("deployment_gate", Vector3(2.40, 0.02, -7.58), 0.0, 0.74)
    _module("data_bank", Vector3(-2.60, 0.0, -7.25))
    _module("kiosk", Vector3(-1.90, 0.0, -1.55), deg_to_rad(12.0))
    _module("kiosk", Vector3(1.90, 0.0, -1.55), deg_to_rad(-12.0))
    _render_batches()
    _pad_center()
    _sera_display()
    _camera()
    _wall_mark()
    _hud()

func _environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#0a0e18")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#8190b2")
    env.ambient_light_energy = 0.85
    world.environment = env
    add_child(world)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
    key.light_energy = 1.25
    add_child(key)

func _vec(a: Array) -> Vector3:
    return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _module(name: String, at: Vector3, yaw: float = 0.0, scale_factor: float = 1.0) -> void:
    if not Modules.MODULES.has(name):
        push_error("Missing Blockbench module: " + name)
        return
    var parent_basis := Basis(Vector3.UP, yaw)
    for part in Modules.MODULES[name]:
        var lo: Vector3 = _vec(part[1]) * Modules.UNIT * scale_factor
        var hi: Vector3 = _vec(part[2]) * Modules.UNIT * scale_factor
        var rot: Vector3 = _vec(part[4]) * (PI / 180.0)
        var basis: Basis = (parent_basis * Basis.from_euler(rot)).scaled_local(hi - lo)
        var transform := Transform3D(basis, at + parent_basis * ((lo + hi) * 0.5))
        var index: int = int(part[3])
        var instances: Array = batch_data.get(index, [])
        instances.append(transform)
        batch_data[index] = instances

func _mat(index: int) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    var tint := Color(Modules.PALETTE[index])
    mat.albedo_color = tint
    mat.metallic = 0.16
    mat.roughness = 0.70
    if index in [5, 6, 7]:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 1.05 if index == 7 else 1.75
    return mat

func _render_batches() -> void:
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    for index_value in batch_data.keys():
        var index: int = int(index_value)
        var transforms: Array = batch_data[index]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = cube
        multi.instance_count = transforms.size()
        for i in range(transforms.size()):
            multi.set_instance_transform(i, transforms[i])
        var draw := MultiMeshInstance3D.new()
        draw.name = "BlockbenchBatch_%02d" % index
        draw.multimesh = multi
        draw.material_override = _mat(index)
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(draw)

func _pad_center() -> void:
    var surface := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 1.29
    cylinder.bottom_radius = 1.37
    cylinder.height = 0.16
    cylinder.radial_segments = 12
    surface.mesh = cylinder
    surface.position = Vector3(0.0, 0.33, -4.05)
    surface.material_override = _mat(2)
    add_child(surface)

func _sera_display() -> void:
    # Do not alter the authored combat animations. The base uses a neutral
    # exhibition pose rather than Wait_motion's crouched combat stance.
    var stand := Node3D.new()
    stand.name = "DisplayStand"
    stand.position = Vector3(0.0, 0.40, -4.05)
    add_child(stand)
    var rig: Node3D = SeraRig.new()
    rig.name = "SeraDisplay"
    rig.scale = Vector3.ONE * 1.35
    rig.rotation.y = PI
    stand.add_child(rig)
    rig.set_process(false)
    rig.set_physics_process(false)
    if not bool(rig.get("loading_ok")):
        push_warning("SERA display model failed to initialize")
        return
    var bones: Dictionary = rig.get("bones")
    var bind_positions: Dictionary = rig.get("bind_positions")
    var bind_rotations: Dictionary = rig.get("bind_rotations")
    var arm_angles := {"UpperArm_R": -38.0, "UpperArm_L": 38.0,
        "Forearm_R": -8.0, "Forearm_L": 8.0,
        "Shoulder_R": -5.0, "Shoulder_L": 5.0}
    for uid in bones.keys():
        var bone: Node3D = bones[uid]
        bone.position = bind_positions[uid]
        bone.quaternion = bind_rotations[uid]
        bone.scale = Vector3.ONE
        if arm_angles.has(bone.name):
            bone.quaternion = bone.quaternion * Quaternion(Vector3.FORWARD, deg_to_rad(float(arm_angles[bone.name])))

func _camera() -> void:
    var cam := Camera3D.new()
    cam.name = "NexusPortraitCamera"
    cam.position = Vector3(0.0, 4.0, 8.40)
    cam.near = 0.05
    cam.fov = 51.0
    add_child(cam)
    cam.look_at(Vector3(0.0, 2.88, -4.72), Vector3.UP)
    cam.current = true

func _wall_mark() -> void:
    var logo := Label3D.new()
    logo.text = "///"
    logo.font_size = 120
    logo.pixel_size = 0.008
    logo.modulate = Color("#a4b5d1")
    logo.position = Vector3(0.0, 6.70, -9.05)
    add_child(logo)
    var name := Label3D.new()
    name.text = "S E R A"
    name.font_size = 80
    name.pixel_size = 0.006
    name.modulate = Color("#b4c5dd")
    name.position = Vector3(0.0, 5.92, -9.03)
    add_child(name)

func _tag(title: String, sub: String, x: float, y: float, w: float) -> void:
    var panel := Panel.new()
    panel.name = title.replace(" ", "") + "Tag"
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.055, 0.10, 0.87)
    style.border_color = Color(0.35, 0.78, 0.93, 0.85)
    style.set_border_width_all(2)
    style.set_corner_radius_all(5)
    panel.add_theme_stylebox_override("panel", style)
    hud.add_child(panel)
    var caption := Label.new()
    caption.text = title
    caption.position = Vector2(54, 7)
    caption.add_theme_font_size_override("font_size", 19)
    caption.add_theme_color_override("font_color", Color("#e0edf9"))
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(caption)
    var detail := Label.new()
    detail.text = sub
    detail.position = Vector2(54, 38)
    detail.add_theme_font_size_override("font_size", 13)
    detail.add_theme_color_override("font_color", Color("#97b8ce"))
    detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(detail)
    var glyph := TagIcon.new()
    glyph.kind = title
    glyph.position = Vector2(11, 15)
    panel.add_child(glyph)
    tags.append({"panel": panel, "x": x, "y": y, "w": w})

func _hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "ReadOnlyBaseHUD"
    add_child(canvas)
    hud = Control.new()
    hud.name = "BaseOverlay"
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var title := Label.new()
    title.text = "SERA SYSTEM   /   COMMAND NEXUS"
    title.position = Vector2(18.0, 18.0)
    title.add_theme_font_size_override("font_size", 23)
    title.add_theme_color_override("font_color", Color("#e0edf9"))
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(title)
    var rule := ColorRect.new()
    rule.name = "HeaderDivider"
    rule.color = Color("#4cd2f6")
    rule.position = Vector2(0, 67)
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(rule)
    _tag("DATA ARCHIVE", "RECORDS / LOGS", 0.018, 0.272, 0.315)
    _tag("DEPLOYMENT", "MISSION GATE", 0.666, 0.272, 0.315)
    _tag("TRAINING", "SIMULATION", 0.018, 0.542, 0.315)
    _tag("SYSTEM", "SETTINGS", 0.666, 0.542, 0.315)
    _tag("CUSTOMIZE", "UNIT CONFIGURATION", 0.305, 0.805, 0.39)
    hud.resized.connect(_layout_hud)
    _layout_hud()

func _layout_hud() -> void:
    if hud == null:
        return
    var viewport_size := hud.size
    var rule: ColorRect = hud.get_node("HeaderDivider")
    rule.size = Vector2(viewport_size.x, 2.0)
    for entry in tags:
        var panel: Panel = entry["panel"]
        panel.size = Vector2(viewport_size.x * float(entry["w"]), 67.0)
        panel.position = Vector2(viewport_size.x * float(entry["x"]), viewport_size.y * float(entry["y"]))
