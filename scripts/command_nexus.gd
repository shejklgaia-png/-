extends Node3D
# v136: continuous broad radial backdrop centered on SERA torso.
# Preserve v127 kiosk/occlusion, v125 touch navigation and v124 Blockbench geometry.
const Modules = preload("res://assets/base_command_modules.gd")
const SeraRig = preload("res://scripts/sera_rig.gd")
const NexusSelectionOutline = preload("res://scripts/nexus_selection_outline.gd")
const CUSTOMIZE_GLOW_SHADER = preload("res://shaders/nexus_customize_radial_glow.gdshader")

const GATE_ORIGIN: Vector3 = Vector3(4.00, 0.02, -10.48)
const SERA_STAGE_ORIGIN: Vector3 = Vector3(0.0, 0.0, -4.75)

var batch_data: Dictionary = {}
var hud: Control
var cam: Camera3D
var outline: Control
var overview_pose: Transform3D
var overview_fov: float = 63.0
var focus_tween: Tween
var focused_target: String = ""
var in_transition: bool = false
var back_panel: Panel
var back_arrow: Label
var focus_panel: Panel
var focus_header: Panel
var focus_title: Label
var action_panel: Panel
var action_label: Label
# Reuse the same display rig, without reparenting it: SeraRig has external
# afterimage nodes whose lifetime is tied to _exit_tree. Set its world transform
# from camera space instead; no duplicate model, SubViewport or draw batch.
var sera_display_stand: Node3D
var sera_display_rig: Node3D
var sera_original_transform: Transform3D
var customize_glow_quad: MeshInstance3D
var customize_preview_active: bool = false
var customize_preview_position: Vector3 = Vector3.ZERO
var customize_preview_scale: float = 0.80
var customize_preview_fitted_scale: float = 1.40
var customize_preview_yaw: float = PI
var customize_touch_id: int = -1
var customize_touch_last_x: float = 0.0
var customize_mouse_drag: bool = false
var customize_mouse_last_x: float = 0.0

const CUSTOMIZE_PREVIEW_DISTANCE: float = 3.25
const CUSTOMIZE_GLOW_DEPTH_OFFSET: float = 1.80
const CUSTOMIZE_GLOW_SCREEN_WIDTH: float = 0.70
const CUSTOMIZE_GLOW_SCREEN_HEIGHT: float = 0.46
const CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.390
const CUSTOMIZE_PREVIEW_ROTATION_SAMPLES: int = 16
const NEXUS_POSE_NAMES: Array[String] = ["NEXUS_pose", "NEXUSpose"]
# Authoritative synchronized Blockbench file first; canonical source fallback.
# Both are JSON text readable by the Android Godot editor after GitSync.
const NEXUS_POSE_SOURCES: Array[String] = [
    "res://models/SERA_BOOSTER_allテスト.bbmodel",
    "res://models/SERA_BOOSTER_all.bbmodel",
    "res://assets/sera_source.json"
]
const CUSTOMIZE_DRAG_FULL_TURN: float = TAU

const CAMERA_TRANSITION_SECONDS: float = 0.18
const TRAINING_SCENE: String = "res://scenes/main.tscn"

# Project the same Blockbench cuboids/SERA display geometry already present in the
# scene into a silhouette; no duplicated render meshes or additional 3D draw calls.
# Each entry holds world-space 3D vertex clusters, grouped by model component.
var target_parts: Dictionary = {}

# The object occupies one side of the portrait frame. The other side is
# reserved for a menu panel. Camera transforms/FOV only: no moving 3D assets.
# TRAINING/GATE/CUSTOMIZE on the right; SYSTEM/ARCHIVE on the left.
var focus_views: Dictionary = {
    "TRAINING": {"eye": Vector3(1.95, 3.15, 7.70),
        "look": Vector3(0.45, 1.35, 1.25), "fov": 68.0},
    "SYSTEM": {"eye": Vector3(-1.95, 3.15, 7.70),
        "look": Vector3(-0.45, 1.35, 1.25), "fov": 68.0},
    "CUSTOMIZE": {"eye": Vector3(-4.50, 3.80, 5.00),
        "look": Vector3(-1.70, 2.00, -4.75), "fov": 67.0},
    "DATA ARCHIVE": {"eye": Vector3(-3.90, 4.50, 2.50),
        "look": Vector3(-1.70, 3.55, -8.80), "fov": 64.0},
    "DEPLOYMENT": {"eye": Vector3(6.20, 5.30, 5.00),
        "look": Vector3(1.80, 3.40, -10.48), "fov": 76.0}
}

# (left fraction, width fraction) of focus menu. Opposite each 3D object;
# overlap 2-5% of the device width for context, never overlap SERA/weapon.
const PANEL_LAYOUTS: Dictionary = {
    "TRAINING": Vector2(0.045, 0.585),
    "SYSTEM": Vector2(0.365, 0.590),
    "DATA ARCHIVE": Vector2(0.365, 0.590),
    "DEPLOYMENT": Vector2(0.045, 0.465),
    "CUSTOMIZE": Vector2(0.045, 0.390)
}

func _ready() -> void:
    _environment()
    _module("hangar_shell", Vector3.ZERO)
    _module("maintenance_pad", Vector3(0.0, 0.0, -4.75))
    _module("maintenance_canopy", Vector3(0.0, 8.0, -8.95))
    _module("deployment_gate", GATE_ORIGIN, _gate_facing_yaw(), 1.20, 1.25)
    _module("archive_mezzanine", Vector3(-4.00, 0.0, -6.55))
    _module("data_bank", Vector3(-4.00, 2.19, -8.95))
    _module("kiosk", Vector3(-1.95, 0.0, 1.30), deg_to_rad(36.0))
    _module("kiosk", Vector3(1.95, 0.0, 1.30), deg_to_rad(-36.0))
    _render_batches()
    _deployment_gate_lightspill()
    _pad_center()
    _sera_display()
    _camera()
    _create_customization_glow()
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

func _module(name: String, at: Vector3, yaw: float = 0.0, scale_factor: float = 1.0, height_factor: float = 1.0) -> void:
    if not Modules.MODULES.has(name):
        push_error("Missing Blockbench module: " + name)
        return
    var parent_basis := Basis(Vector3.UP, yaw)
    var selected_shape := ""
    match name:
        "kiosk":
            selected_shape = "SYSTEM" if at.x < 0.0 else "TRAINING"
        "data_bank":
            selected_shape = "DATA ARCHIVE"
        "deployment_gate":
            selected_shape = "DEPLOYMENT"
    var silhouette_parts: Array = target_parts.get(selected_shape, [])
    for part in Modules.MODULES[name]:
        var stretch := Vector3(1.0, height_factor, 1.0)
        var lo: Vector3 = _vec(part[1]) * Modules.UNIT * scale_factor * stretch
        var hi: Vector3 = _vec(part[2]) * Modules.UNIT * scale_factor * stretch
        var rot: Vector3 = _vec(part[4]) * (PI / 180.0)
        var basis: Basis = (parent_basis * Basis.from_euler(rot)).scaled_local(hi - lo)
        var transform := Transform3D(basis, at + parent_basis * ((lo + hi) * 0.5))
        if not selected_shape.is_empty():
            var corners := PackedVector3Array()
            for ix in [-0.5, 0.5]:
                for iy in [-0.5, 0.5]:
                    for iz in [-0.5, 0.5]:
                        corners.append(transform * Vector3(ix, iy, iz))
            silhouette_parts.append(corners)
        var index: int = int(part[3])
        var instances: Array = batch_data.get(index, [])
        instances.append(transform)
        batch_data[index] = instances
    if not selected_shape.is_empty():
        target_parts[selected_shape] = silhouette_parts


func _gate_facing_yaw() -> float:
    # The Blockbench gate faces along local +Z. Point that normal at SERA's stage,
    # not away from the camera (positive yaw would point to the right).
    var toward_sera: Vector3 = SERA_STAGE_ORIGIN - GATE_ORIGIN
    return atan2(toward_sera.x, toward_sera.z)

func _gate_light_quad(parent: Node3D, label: String, local_pos: Vector3,
        dimensions: Vector2, tint: Color, emission_strength: float,
        horizontal: bool = false) -> void:
    var surface := MeshInstance3D.new()
    surface.name = label
    var shape := QuadMesh.new()
    shape.size = dimensions
    surface.mesh = shape
    surface.position = local_pos
    if horizontal:
        surface.rotation.x = -PI * 0.5
    surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var light_material := StandardMaterial3D.new()
    light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    light_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    light_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    light_material.albedo_color = tint
    light_material.emission_enabled = true
    light_material.emission = Color(tint.r, tint.g, tint.b)
    light_material.emission_energy_multiplier = emission_strength
    surface.material_override = light_material
    parent.add_child(surface)

func _deployment_gate_lightspill() -> void:
    # Reuse exactly the same position and rotation as the authored gate.
    # The visible opening faces the central maintenance stage.
    var portal := Node3D.new()
    portal.name = "DeploymentGateLightspill"
    portal.position = GATE_ORIGIN
    portal.rotation.y = _gate_facing_yaw()
    add_child(portal)

    # Two static emissive planes simulate depth behind the open gate.
    # Deliberately no bloom, fog, volumetrics, particles or extra shadows.
    _gate_light_quad(portal, "DeepBlueBacklight",
        Vector3(0.0, 3.00, -2.25), Vector2(2.25, 3.95),
        Color(0.30, 0.75, 1.00, 0.66), 2.10)
    _gate_light_quad(portal, "DiffusedAperture",
        Vector3(0.0, 3.00, -0.70), Vector2(2.65, 4.45),
        Color(0.20, 0.65, 1.00, 0.18), 1.25)

    # Narrow light pools extend from the doorway into the hangar floor.
    _gate_light_quad(portal, "ThresholdGlow",
        Vector3(0.0, 0.20, 0.72), Vector2(1.70, 1.70),
        Color(0.36, 0.83, 1.00, 0.31), 1.35, true)
    _gate_light_quad(portal, "SpillOnFloor",
        Vector3(0.0, 0.055, 2.04), Vector2(1.18, 1.95),
        Color(0.24, 0.68, 1.00, 0.15), 0.90, true)

    # One unshadowed light adds a little spill onto the surrounding frame.
    var lamp := OmniLight3D.new()
    lamp.name = "GateInteriorFill"
    lamp.position = Vector3(0.0, 3.0, -0.75)
    lamp.light_color = Color(0.40, 0.81, 1.00)
    lamp.light_energy = 1.25
    lamp.omni_range = 5.5
    lamp.shadow_enabled = false
    portal.add_child(lamp)

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
    surface.position = Vector3(0.0, 0.33, -4.75)
    surface.material_override = _mat(2)
    add_child(surface)

func _sera_display() -> void:
    # Do not alter the authored combat animations. The base uses a neutral
    # exhibition pose rather than Wait_motion's crouched combat stance.
    var stand := Node3D.new()
    stand.name = "DisplayStand"
    stand.position = Vector3(0.0, 0.40, -4.75)
    add_child(stand)
    var rig: Node3D = SeraRig.new()
    rig.name = "SeraDisplay"
    rig.scale = Vector3.ONE * 1.35
    rig.rotation.y = PI
    stand.add_child(rig)
    sera_display_stand = stand
    sera_display_rig = rig
    sera_original_transform = rig.transform
    rig.set_process(false)
    rig.set_physics_process(false)
    if not bool(rig.get("loading_ok")):
        push_warning("SERA display model failed to initialize")
        return
    var bones: Dictionary = rig.get("bones")
    var bind_positions: Dictionary = rig.get("bind_positions")
    var bind_rotations: Dictionary = rig.get("bind_rotations")
    if not _apply_nexus_pose(rig):
        # The user-authored NEXUS_pose has not reached the repo yet. Preserve the
        # existing neutral display until that named pose is available.
        var arm_angles := {"UpperArm_R": -38.0, "UpperArm_L": 38.0,
            "Forearm_R": -8.0, "Forearm_L": 8.0,
            "Shoulder_R": -5.0, "Shoulder_L": 5.0}
        for uid in bones.keys():
            var bone: Node3D = bones[uid]
            bone.position = bind_positions[uid]
            bone.quaternion = bind_rotations[uid]
            bone.scale = Vector3.ONE
            if arm_angles.has(bone.name):
                bone.quaternion = bone.quaternion * Quaternion(
                    Vector3.BACK, deg_to_rad(float(arm_angles[bone.name])))
    _capture_sera_silhouette(rig)

func _apply_nexus_pose(rig: Node3D) -> bool:
    # Blockbench animation tracks are decoded by SeraRig's own production
    # ZYX quaternion converter; combat animation data is never overwritten.
    # Only the independent exhibition rig receives this one named pose.
    for source_path in NEXUS_POSE_SOURCES:
        if not FileAccess.file_exists(source_path):
            continue
        var json_data: Variant = JSON.parse_string(
            FileAccess.get_file_as_string(source_path))
        if not json_data is Dictionary:
            continue
        var clips: Array = json_data.get("animations", [])
        for raw_clip in clips:
            if not raw_clip is Dictionary:
                continue
            var pose_name: String = str(raw_clip.get("name", ""))
            if not NEXUS_POSE_NAMES.has(pose_name):
                continue
            if raw_clip.get("animators", {}).is_empty():
                continue
            rig.call("_build_animations", {"animations": [raw_clip]})
            var available: Dictionary = rig.get("animations")
            if not available.has(pose_name):
                continue
            rig.set("current_clip", pose_name)
            rig.set("clip_time", 0.0)
            rig.set("blending_for", 1.0)
            rig.set("blend_duration", 0.0)
            rig.call("_apply_animation", 0.0)
            return true
    return false

func _capture_sera_silhouette(rig: Node3D) -> void:
    # Group per original Blockbench bone, not per small mesh face. The result
    # follows SERA's actual arm/leg proportions without allocating another rig.
    var grouped: Dictionary = {}
    _collect_sera_geometry(rig, grouped)
    target_parts["CUSTOMIZE"] = grouped.values()

func _collect_sera_geometry(node: Node, grouped: Dictionary) -> void:
    if node is MeshInstance3D:
        var piece: MeshInstance3D = node as MeshInstance3D
        if piece.mesh != null and piece.is_visible_in_tree():
            var aabb: AABB = piece.mesh.get_aabb()
            var parent_id: int = piece.get_parent().get_instance_id()
            var corners: PackedVector3Array = grouped.get(parent_id, PackedVector3Array())
            for ix in [0.0, 1.0]:
                for iy in [0.0, 1.0]:
                    for iz in [0.0, 1.0]:
                        var local := aabb.position + aabb.size * Vector3(ix, iy, iz)
                        corners.append(piece.global_transform * local)
            grouped[parent_id] = corners
    for child in node.get_children():
        _collect_sera_geometry(child, grouped)

func _camera() -> void:
    cam = Camera3D.new()
    cam.name = "NexusPortraitCamera"
    cam.position = Vector3(0.0, 4.10, 10.20)
    cam.near = 0.05
    cam.fov = 63.0
    add_child(cam)
    cam.look_at(Vector3(0.0, 3.00, -5.50), Vector3.UP)
    cam.current = true
    overview_pose = cam.transform
    overview_fov = cam.fov

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

# Outline geometry is derived from the actual visible 3D display/model meshes,
# not approximate hand-authored screen-space hexagons or extra GPU geometry.
func _hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "NexusInteractiveHUD"
    add_child(canvas)
    hud = Control.new()
    hud.name = "NexusOverlay"
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(hud)
    hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    outline = NexusSelectionOutline.new()
    outline.name = "SelectableSilhouettes"
    outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(outline)
    outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    back_panel = Panel.new()
    back_panel.name = "BackToOverview"
    back_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    back_panel.add_theme_stylebox_override("panel", _menu_style())
    back_panel.visible = false
    hud.add_child(back_panel)
    back_arrow = Label.new()
    back_arrow.text = "<"
    back_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    back_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    back_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    back_arrow.add_theme_font_size_override("font_size", 32)
    back_arrow.add_theme_color_override("font_color", Color("#a6f0ff"))
    back_panel.add_child(back_arrow)

    focus_panel = Panel.new()
    focus_panel.name = "FocusedMenu"
    focus_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_panel.add_theme_stylebox_override("panel", _menu_body_style())
    focus_panel.visible = false
    hud.add_child(focus_panel)
    focus_header = Panel.new()
    focus_header.name = "OpaqueMenuHeader"
    focus_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_header.add_theme_stylebox_override("panel", _menu_header_style())
    focus_panel.add_child(focus_header)
    focus_title = Label.new()
    focus_title.name = "DestinationTitle"
    focus_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    focus_title.add_theme_font_size_override("font_size", 21)
    focus_title.add_theme_color_override("font_color", Color("#e1f3fd"))
    focus_header.add_child(focus_title)
    action_panel = Panel.new()
    action_panel.name = "DestinationAction"
    action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    action_panel.add_theme_stylebox_override("panel", _action_style())
    focus_panel.add_child(action_panel)
    action_label = Label.new()
    action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    action_label.add_theme_font_size_override("font_size", 17)
    action_label.add_theme_color_override("font_color", Color("#bcecff"))
    action_panel.add_child(action_label)
    hud.resized.connect(_layout_hud)
    _layout_hud()
    _update_projected_silhouettes()

func _menu_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.035, 0.060, 0.92)
    style.border_color = Color(0.22, 0.72, 0.87, 0.85)
    style.set_border_width_all(2)
    style.set_corner_radius_all(6)
    return style

func _menu_body_style() -> StyleBoxFlat:
    # Cyber-blue translucent rectangle. No border or decoration.
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.155, 0.260, 0.52)
    return style

func _menu_header_style() -> StyleBoxFlat:
    # Only the menu-name header is fully opaque.
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.190, 0.315, 1.00)
    return style

func _action_style() -> StyleBoxFlat:
    # Retain the existing TRAINING navigation within its empty placeholder;
    # no border or false actions on the other four panels.
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.045, 0.220, 0.340, 0.84)
    return style

func _layout_hud() -> void:
    if hud == null or back_panel == null or focus_panel == null:
        return
    var view := hud.size
    var margin := maxf(16.0, view.x * 0.04)
    # Bottom right, outside the destination action menu even on shorter screens.
    back_panel.position = Vector2(view.x - margin - 62.0, view.y - margin - 62.0)
    back_panel.size = Vector2(62.0, 62.0)
    back_arrow.position = Vector2.ZERO
    back_arrow.size = back_panel.size
    var panel_placement: Vector2 = PANEL_LAYOUTS.get(focused_target,
        Vector2(0.045, 0.390))
    focus_panel.position = Vector2(view.x * panel_placement.x, view.y * 0.225)
    focus_panel.size = Vector2(view.x * panel_placement.y, view.y * 0.535)
    if focused_target == "CUSTOMIZE":
        _keep_customization_clear()
    # The opaque top stripe belongs to the focus panel; rest stays blue/clear.
    focus_header.position = Vector2.ZERO
    focus_header.size = Vector2(focus_panel.size.x, minf(60.0, view.y * 0.068))
    focus_title.position = Vector2(16.0, 0.0)
    focus_title.size = Vector2(focus_header.size.x - 32.0, focus_header.size.y)
    action_panel.position = Vector2(16.0, focus_panel.size.y - 84.0)
    action_panel.size = Vector2(focus_panel.size.x - 32.0, 60.0)
    action_label.position = Vector2.ZERO
    action_label.size = action_panel.size
    _update_projected_silhouettes()
    if customize_preview_active:
        _update_customization_glow()

func _keep_customization_clear() -> void:
    # Guarantee real model silhouette (including held sword and limbs) is never
    # covered by the left menu. This runs only at the end of the camera focus
    # or when the viewport resizes, NOT every rendered frame.
    if cam == null or not target_parts.has("CUSTOMIZE"):
        return
    var leftmost := INF
    for contour in _project_model_contour("CUSTOMIZE"):
        for point in contour:
            leftmost = minf(leftmost, point.x)
    if leftmost < INF:
        # Leave 16 logical pixels between the entire mesh and the menu body.
        focus_panel.size.x = minf(focus_panel.size.x,
            maxf(0.0, leftmost - focus_panel.position.x - 16.0))

# A single camera-facing translucent 3D quad sits behind the floating SERA.
# It is not a screen overlay: depth testing keeps the character in front and
# preserves the existing 3D hangar visible through the radial falloff.
func _create_customization_glow() -> void:
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    var material := ShaderMaterial.new()
    material.shader = CUSTOMIZE_GLOW_SHADER
    # Same cyan RGB as nexus_selection_outline.gd's active stroke.
    material.set_shader_parameter("glow_color", Color(0.35, 0.85, 0.98, 1.0))
    var backdrop := MeshInstance3D.new()
    backdrop.name = "CustomizePortraitRadialBackdrop"
    backdrop.mesh = quad
    backdrop.material_override = material
    backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    backdrop.visible = false
    cam.add_child(backdrop)
    customize_glow_quad = backdrop

func _update_customization_glow() -> void:
    if not customize_preview_active or customize_glow_quad == null or cam == null or hud == null:
        return
    var viewport_size := hud.size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    # Measure the fitted character instead of a fixed world-space target: the
    # halo remains behind SERA when yaw rotates or the phone aspect changes.
    var rect := _customization_screen_bounds()
    if rect.size.x <= 1.0 or rect.size.y <= 1.0:
        return
    var placement: Vector2 = PANEL_LAYOUTS["CUSTOMIZE"]
    var safe_left: float = viewport_size.x * (placement.x + placement.y) + 18.0
    var safe_right: float = viewport_size.x * 0.970
    var center: Vector2 = rect.position + rect.size * 0.5
    # Center on the actual torso joints, not the sword-inclusive silhouette.
    # The sword can extend far to the side in authored poses.
    var body_bones: Dictionary = sera_display_rig.get("bones")
    var body_pixels := Vector2.ZERO
    var body_count := 0
    for bone_value in body_bones.values():
        var bone: Node3D = bone_value
        if bone.name in ["Chest", "Torso", "Waist"]:
            if not cam.is_position_behind(bone.global_position):
                body_pixels += cam.unproject_position(bone.global_position)
                body_count += 1
    if body_count > 0:
        center = body_pixels / float(body_count)
    center.x = clampf(center.x, safe_left + 20.0, safe_right - 20.0)
    var depth: float = -customize_preview_position.z + CUSTOMIZE_GLOW_DEPTH_OFFSET
    var half_height: float = depth * tan(deg_to_rad(cam.fov) * 0.5)
    var half_width: float = half_height * viewport_size.x / viewport_size.y
    customize_glow_quad.position = Vector3(
        (center.x / viewport_size.x - 0.5) * 2.0 * half_width,
        (0.5 - center.y / viewport_size.y) * 2.0 * half_height,
        -depth)
    var quad := customize_glow_quad.mesh as QuadMesh
    quad.size = Vector2(
        2.0 * half_width * CUSTOMIZE_GLOW_SCREEN_WIDTH,
        2.0 * half_height * CUSTOMIZE_GLOW_SCREEN_HEIGHT)

# The SAME exhibition rig stays parented to its original display stand.
# A camera-relative transform presents it as a flat-to-screen foreground
# object while retaining the entire unchanged hangar and stage underneath.
func _apply_customization_preview_transform() -> void:
    if sera_display_rig == null or cam == null:
        return
    var basis := Basis(Vector3.UP, customize_preview_yaw)
    basis = basis.scaled(Vector3.ONE * customize_preview_scale)
    sera_display_rig.global_transform = cam.global_transform * Transform3D(
        basis, customize_preview_position)

func _show_customization_preview() -> void:
    if customize_preview_active or cam == null or sera_display_rig == null:
        return
    if not bool(sera_display_rig.get("loading_ok")):
        return
    customize_preview_position = Vector3(0.75, -0.20, -CUSTOMIZE_PREVIEW_DISTANCE)
    customize_preview_scale = 1.40
    customize_preview_fitted_scale = 1.40
    customize_preview_yaw = PI
    customize_preview_active = true
    _apply_customization_preview_transform()
    _capture_sera_silhouette(sera_display_rig)
    _fit_customization_preview()
    _capture_sera_silhouette(sera_display_rig)
    _update_customization_glow()
    customize_glow_quad.visible = true
    # Hide only the selected CUSTOMIZE contour in portrait mode. The normal
    # overview's selectable outline and all other terminals are unchanged.
    outline.set("hide_customize_preview_outline", true)
    _update_projected_silhouettes()
    outline.queue_redraw()

func _restore_customization_preview() -> void:
    customize_touch_id = -1
    customize_mouse_drag = false
    if not customize_preview_active or sera_display_rig == null:
        return
    if customize_glow_quad != null:
        customize_glow_quad.visible = false
    # Keep the portrait outline hidden until the return camera finishes.
    sera_display_rig.transform = sera_original_transform
    customize_preview_active = false
    _capture_sera_silhouette(sera_display_rig)
    _update_projected_silhouettes()

func _customization_screen_bounds() -> Rect2:
    # Project the original visible mesh boxes, including the complete sword.
    # No expensive polygon merges are needed to determine safe UI clearance.
    if cam == null or not target_parts.has("CUSTOMIZE"):
        return Rect2()
    var found := false
    var minimum := Vector2(INF, INF)
    var maximum := Vector2(-INF, -INF)
    var groups: Array = target_parts["CUSTOMIZE"]
    for group in groups:
        for point in group:
            if cam.is_position_behind(point):
                continue
            var pixel := cam.unproject_position(point)
            minimum = minimum.min(pixel)
            maximum = maximum.max(pixel)
            found = true
    if not found:
        return Rect2()
    return Rect2(minimum, maximum - minimum)

func _customization_all_yaw_bounds() -> Rect2:
    # Fit the full 360-degree spin envelope once, before showing the menu.
    # This prevents the shield or sword from sweeping through the blue panel.
    var combined := Rect2()
    var found := false
    for i in range(CUSTOMIZE_PREVIEW_ROTATION_SAMPLES):
        customize_preview_yaw = PI + TAU * float(i) / float(CUSTOMIZE_PREVIEW_ROTATION_SAMPLES)
        _apply_customization_preview_transform()
        _capture_sera_silhouette(sera_display_rig)
        var projected := _customization_screen_bounds()
        if projected.size.x <= 0.0 or projected.size.y <= 0.0:
            continue
        if not found:
            combined = projected
            found = true
        else:
            combined = combined.merge(projected)
    customize_preview_yaw = PI
    _apply_customization_preview_transform()
    _capture_sera_silhouette(sera_display_rig)
    return combined

func _fit_customization_preview() -> void:
    if not customize_preview_active or hud == null:
        return
    var size := hud.size
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var placement: Vector2 = PANEL_LAYOUTS["CUSTOMIZE"]
    var left_limit: float = size.x * (placement.x + placement.y) + 18.0
    var right_limit: float = size.x * 0.970
    var top_limit: float = size.y * 0.150
    var bottom_limit: float = size.y * 0.860
    var allowed_width: float = maxf(1.0, right_limit - left_limit)
    var allowed_height: float = maxf(1.0, bottom_limit - top_limit)
    var center_target := Vector2((left_limit + right_limit) * 0.5,
        (top_limit + bottom_limit) * 0.5)
    # Enlarge the *visible front pose* to nearly the width of its left menu.
    # The old 16-angle union contained sideways weapons and made the actual
    # front-facing character substantially smaller than the available area.
    var target_width: float = minf(size.x * CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO,
        allowed_width * 0.94)

    for pass_index in range(2):
        var rect := _customization_screen_bounds()
        if rect.size.x <= 1.0 or rect.size.y <= 1.0:
            return
        var fit: float = minf(target_width / rect.size.x,
            allowed_height / rect.size.y)
        fit = clampf(fit, 0.15, 3.25)
        customize_preview_scale *= fit
        _apply_customization_preview_transform()
        _capture_sera_silhouette(sera_display_rig)
        rect = _customization_screen_bounds()
        if rect.size.x <= 1.0 or rect.size.y <= 1.0:
            return
        var depth: float = -customize_preview_position.z
        var half_height := depth * tan(deg_to_rad(cam.fov) * 0.5)
        var px_per_world := size.y / maxf(0.001, 2.0 * half_height)
        var error: Vector2 = center_target - (rect.position + rect.size * 0.5)
        customize_preview_position.x += error.x / px_per_world
        customize_preview_position.y -= error.y / px_per_world
        _apply_customization_preview_transform()
        _capture_sera_silhouette(sera_display_rig)

    # Keep the enlarged front scale as the reference for subsequent yaw input.
    customize_preview_fitted_scale = customize_preview_scale
    _constrain_customization_preview_to_safe_area()

func _constrain_customization_preview_to_safe_area() -> void:
    if not customize_preview_active or hud == null or cam == null:
        return
    var size := hud.size
    if size.x <= 1.0 or size.y <= 1.0:
        return
    var placement: Vector2 = PANEL_LAYOUTS["CUSTOMIZE"]
    var left_limit: float = size.x * (placement.x + placement.y) + 18.0
    var right_limit: float = size.x * 0.970
    var top_limit: float = size.y * 0.150
    var bottom_limit: float = size.y * 0.860
    var allowed_width: float = maxf(1.0, right_limit - left_limit)
    var allowed_height: float = maxf(1.0, bottom_limit - top_limit)
    var center_target := Vector2((left_limit + right_limit) * 0.5,
        (top_limit + bottom_limit) * 0.5)

    # Return to the original enlarged scale after every drag update.
    # Only a sideways weapon/pose wider than the safe area is reduced,
    # temporarily, rather than reducing the default front view forever.
    customize_preview_scale = customize_preview_fitted_scale
    _apply_customization_preview_transform()
    for pass_index in range(2):
        _capture_sera_silhouette(sera_display_rig)
        var rect := _customization_screen_bounds()
        if rect.size.x <= 1.0 or rect.size.y <= 1.0:
            return
        var fit: float = minf(1.0, minf(
            allowed_width / rect.size.x, allowed_height / rect.size.y))
        if fit < 0.999:
            customize_preview_scale *= maxf(0.1, fit * 0.99)
            _apply_customization_preview_transform()
            _capture_sera_silhouette(sera_display_rig)
            rect = _customization_screen_bounds()
        var depth: float = -customize_preview_position.z
        var half_height := depth * tan(deg_to_rad(cam.fov) * 0.5)
        var px_per_world := size.y / maxf(0.001, 2.0 * half_height)
        var error: Vector2 = center_target - (rect.position + rect.size * 0.5)
        customize_preview_position.x += error.x / px_per_world
        customize_preview_position.y -= error.y / px_per_world
        _apply_customization_preview_transform()
    _capture_sera_silhouette(sera_display_rig)

func _is_customization_drag_zone(pixel: Vector2) -> bool:
    if focused_target != "CUSTOMIZE" or not customize_preview_active:
        return false
    if focus_panel.visible and Rect2(focus_panel.position, focus_panel.size).has_point(pixel):
        return false
    if back_panel.visible and Rect2(back_panel.position, back_panel.size).has_point(pixel):
        return false
    # The complete right-side presentation region, not just opaque mesh pixels.
    return (
        pixel.x > focus_panel.position.x + focus_panel.size.x + 8.0
        and pixel.x < hud.size.x
        and pixel.y >= hud.size.y * 0.20
        and pixel.y <= hud.size.y * 0.80
    )

func _rotate_customization_preview(delta_x: float) -> void:
    if not customize_preview_active or sera_display_rig == null:
        return
    if absf(delta_x) < 0.001:
        return
    var yaw_delta := delta_x / maxf(hud.size.x, 1.0) * CUSTOMIZE_DRAG_FULL_TURN
    customize_preview_yaw = wrapf(customize_preview_yaw - yaw_delta, -PI, PI)
    _apply_customization_preview_transform()
    _constrain_customization_preview_to_safe_area()
    _update_customization_glow()
    _update_projected_silhouettes()

func _update_projected_silhouettes() -> void:
    if cam == null or outline == null:
        return
    # Cache the overview until the camera changes/viewport resizes. During a
    # fast focus only the selected target needs reprojection (~11 frames).
    var contours: Dictionary = {}
    if focused_target.is_empty():
        for target_name in target_parts.keys():
            contours[target_name] = _project_model_contour(target_name)
    elif target_parts.has(focused_target):
        contours[focused_target] = _project_model_contour(focused_target)
    outline.set("polygons", contours)
    # These outlines are drawn in 2D on top of the 3D view. Clip ONLY the
    # distant gate's visible stroke against the nearer SERA body so its border
    # cannot show through SERA. Clip POLYLINES rather than polygons: clipping
    # polygons would create an unwanted border along SERA's silhouette.
    var visible_strokes: Dictionary = {}
    if contours.has("DEPLOYMENT"):
        var sera_masks: Array = contours.get("CUSTOMIZE", [])
        if sera_masks.is_empty():
            sera_masks = _project_model_contour("CUSTOMIZE")
        visible_strokes["DEPLOYMENT"] = _clip_gate_strokes(
            contours["DEPLOYMENT"], sera_masks)
    outline.set("clipped_strokes", visible_strokes)

func _clip_gate_strokes(gate_shapes: Array, occluders: Array) -> Array[PackedVector2Array]:
    var visible: Array[PackedVector2Array] = []
    # Only run when the camera moved or the viewport changed; blinking merely
    # changes stroke alpha/width and never recomputes the clipping geometry.
    var masks: Array[PackedVector2Array] = []
    for shape in occluders:
        var expanded: Array[PackedVector2Array] = Geometry2D.offset_polygon(
            shape, 4.0, Geometry2D.JOIN_MITER)
        masks.append_array(expanded)
    for shape in gate_shapes:
        if shape.size() < 3:
            continue
        var closed := PackedVector2Array(shape)
        closed.append(shape[0])
        var remaining: Array[PackedVector2Array] = [closed]
        for mask in masks:
            if remaining.is_empty():
                break
            var next_segments: Array[PackedVector2Array] = []
            var mask_bounds := _polygon_bounds(mask)
            for segment in remaining:
                if not _polygon_bounds(segment).intersects(mask_bounds):
                    next_segments.append(segment)
                else:
                    next_segments.append_array(
                        Geometry2D.clip_polyline_with_polygon(segment, mask))
            remaining = next_segments
        visible.append_array(remaining)
    return visible

func _project_model_contour(target_name: String) -> Array[PackedVector2Array]:
    var result: Array[PackedVector2Array] = []
    var clusters: Array = target_parts.get(target_name, [])
    for cluster in clusters:
        var screen_points := PackedVector2Array()
        var clipped := false
        for world_point in cluster:
            if cam.is_position_behind(world_point):
                clipped = true
                break
            screen_points.append(cam.unproject_position(world_point))
        if clipped or screen_points.size() < 3:
            continue
        # The convex silhouette of each original mesh component encloses its
        # projected faces, retaining the outline of body limbs and device arms.
        var hull: PackedVector2Array = Geometry2D.convex_hull(screen_points)
        if hull.size() < 3:
            continue
        # Two pixels outside the mesh prevent coplanar joints from looking
        # broken and keep the contour distinct from the actual 3D silhouette.
        var expanded: Array[PackedVector2Array] = Geometry2D.offset_polygon(
            hull, 2.0, Geometry2D.JOIN_MITER)
        for poly in expanded:
            if poly.size() >= 3:
                _union_outer_contours(result, poly)
    return result

func _union_outer_contours(contours: Array[PackedVector2Array],
        fresh: PackedVector2Array) -> void:
    var candidate := fresh
    var i := 0
    while i < contours.size():
        if not _polygon_bounds(candidate).intersects(_polygon_bounds(contours[i])):
            i += 1
            continue
        var overlap: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
            candidate, contours[i])
        if overlap.is_empty():
            i += 1
            continue
        var united: Array[PackedVector2Array] = Geometry2D.merge_polygons(
            candidate, contours[i])
        if united.is_empty():
            i += 1
            continue
        # A union can include interior holes. Trace its outermost boundary;
        # never draw per-cuboid internal seams on the selectable outline.
        var best: PackedVector2Array = united[0]
        var best_area := absf(_polygon_area(best))
        for component in united:
            var area := absf(_polygon_area(component))
            if area > best_area:
                best = component
                best_area = area
        candidate = best
        contours.remove_at(i)
        i = 0
    contours.append(candidate)

func _polygon_area(poly: PackedVector2Array) -> float:
    var area := 0.0
    for i in range(poly.size()):
        var a: Vector2 = poly[i]
        var b: Vector2 = poly[(i + 1) % poly.size()]
        area += a.x * b.y - b.x * a.y
    return area * 0.5

# Raw touch support intentionally does not change the training scene's global
# Input.emulate_mouse_from_touch=false setting. PC mouse taps also work.
func _input(event: InputEvent) -> void:
    if not focused_target.is_empty() and (
            event.is_action_pressed("ui_cancel")
            or (event is InputEventKey and event.pressed
                and event.keycode in [KEY_BACK, KEY_ESCAPE])):
        _return_to_overview()
        get_viewport().set_input_as_handled()
        return
    if in_transition:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if customize_touch_id == -1 and _is_customization_drag_zone(event.position):
                customize_touch_id = event.index
                customize_touch_last_x = event.position.x
            else:
                _tap_at(event.position)
            get_viewport().set_input_as_handled()
        elif event.index == customize_touch_id:
            customize_touch_id = -1
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if event.index == customize_touch_id:
            _rotate_customization_preview(event.position.x - customize_touch_last_x)
            customize_touch_last_x = event.position.x
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if _is_customization_drag_zone(event.position):
                customize_mouse_drag = true
                customize_mouse_last_x = event.position.x
            else:
                _tap_at(event.position)
        else:
            customize_mouse_drag = false
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and customize_mouse_drag:
        _rotate_customization_preview(event.position.x - customize_mouse_last_x)
        customize_mouse_last_x = event.position.x
        get_viewport().set_input_as_handled()

func _tap_at(point: Vector2) -> void:
    if not focused_target.is_empty():
        if Rect2(back_panel.position, back_panel.size).has_point(point):
            _return_to_overview()
        elif focused_target == "TRAINING" and focus_panel.visible:
            var action_rect := Rect2(focus_panel.position + action_panel.position,
                action_panel.size)
            if action_rect.has_point(point):
                _start_training()
        return
    var polys: Dictionary = outline.get("polygons")
    # Front terminals win if the projections overlap a distant module.
    for candidate in ["TRAINING", "SYSTEM", "CUSTOMIZE", "DATA ARCHIVE", "DEPLOYMENT"]:
        if not polys.has(candidate):
            continue
        # Each 3D object may have multiple disjoint contour islands.
        var contours: Array = polys[candidate]
        for poly in contours:
            if Geometry2D.is_point_in_polygon(point, poly):
                _select_target(candidate)
                return
            # Small reach tolerance for thumb input, without a huge bounding
            # box that could accidentally select the far gate instead.
            if _polygon_bounds(poly).grow(9.0).has_point(point):
                _select_target(candidate)
                return

func _polygon_bounds(poly: PackedVector2Array) -> Rect2:
    var left := poly[0].x
    var right := poly[0].x
    var top := poly[0].y
    var bottom := poly[0].y
    for p in poly:
        left = minf(left, p.x)
        right = maxf(right, p.x)
        top = minf(top, p.y)
        bottom = maxf(bottom, p.y)
    return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func _select_target(target_name: String) -> void:
    if in_transition or not focus_views.has(target_name):
        return
    focused_target = target_name
    # Show the bright contour in the initial press event, before camera tween.
    outline.set("active_target", target_name)
    _update_projected_silhouettes()
    outline.queue_redraw()
    in_transition = true
    var view: Dictionary = focus_views[target_name]
    var eye: Vector3 = view["eye"]
    var look: Vector3 = view["look"]
    var aim_pose := Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
    _move_camera(aim_pose, float(view["fov"]), _focus_arrived.bind(target_name))

func _focus_arrived(target_name: String) -> void:
    in_transition = false
    if focused_target != target_name:
        return
    if target_name == "CUSTOMIZE":
        _show_customization_preview()
    back_panel.visible = true
    focus_title.text = target_name
    # A blank placeholder menu except for the existing functional training
    # entrance; no 'NOT AVAILABLE YET' text in the other four menus.
    action_label.text = "ENTER TRAINING" if target_name == "TRAINING" else ""
    action_panel.visible = target_name == "TRAINING"
    _layout_hud()
    focus_panel.visible = true

func _return_to_overview() -> void:
    if in_transition or focused_target.is_empty():
        return
    # Back immediately ends the bright selection, before camera return.
    outline.set("active_target", "")
    outline.queue_redraw()
    in_transition = true
    focus_panel.visible = false
    back_panel.visible = false
    _restore_customization_preview()
    _move_camera(overview_pose, overview_fov, _overview_arrived)

func _overview_arrived() -> void:
    in_transition = false
    focused_target = ""
    outline.set("hide_customize_preview_outline", false)
    _update_projected_silhouettes()
    outline.queue_redraw()

func _move_camera(destination: Transform3D, next_fov: float, arrived: Callable) -> void:
    if focus_tween != null and focus_tween.is_running():
        focus_tween.kill()
    var start_pose := cam.transform
    var start_fov := cam.fov
    focus_tween = create_tween()
    focus_tween.set_trans(Tween.TRANS_CUBIC)
    focus_tween.set_ease(Tween.EASE_OUT)
    focus_tween.tween_method(_apply_camera_transition.bind(start_pose, destination,
        start_fov, next_fov), 0.0, 1.0, CAMERA_TRANSITION_SECONDS)
    focus_tween.finished.connect(arrived)

func _apply_camera_transition(progress: float, from_pose: Transform3D,
        to_pose: Transform3D, from_fov: float, to_fov: float) -> void:
    cam.transform = from_pose.interpolate_with(to_pose, progress)
    cam.fov = lerpf(from_fov, to_fov, progress)
    _update_projected_silhouettes()

func _start_training() -> void:
    if focused_target != "TRAINING" or in_transition:
        return
    var err: Error = get_tree().change_scene_to_file(TRAINING_SCENE)
    if err != OK:
        push_error("Nexus training scene load failed (%d)" % err)
