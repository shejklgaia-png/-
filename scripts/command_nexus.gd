extends Node3D
# v147: move exhibition SERA twice as fast (0.14 s) and finalize only after concurrent camera arrival.
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
var customize_right_panel: Panel
var customize_right_header: Panel
var customize_equipment_header: Label
var customize_equipment_rows: Dictionary = {}
const CUSTOMIZE_SLOTS = ["head", "torso", "legs", "arms", "weapon_r", "weapon_l"]
const CUSTOMIZE_SLOT_LABELS = {
    "head": "HEAD", "torso": "TORSO", "legs": "LOWER BODY",
    "arms": "ARMS", "weapon_r": "RIGHT WEAPON", "weapon_l": "LEFT WEAPON"
}
var action_panel: Panel
var action_label: Label
# SYSTEM edits save files; the DATA ARCHIVE tabs never mutate profiles.
const ARCHIVE_TABS = ["SUMMARY", "COMBAT", "PROGRESS", "PROFILE"]
var archive_record_tabs: Array[Dictionary] = []
var archive_record_body: Label
var archive_record_tab: int = 0
var archive_refresh_elapsed: float = 0.0
const SYSTEM_ACTIONS = ["SAVE", "LOAD", "NEW", "DELETE"]
var system_slot_rows: Array[Dictionary] = []
var system_action_rows: Array[Dictionary] = []
var system_status: Label
var system_selected_slot: int = 1
var system_pending_action: String = ""
var system_pending_slot: int = 0
var system_message: String = ""
# Blink only the selected slot border while a destructive action awaits CONFIRM.
const SYSTEM_CONFIRM_BLINK_HALF_SECONDS: float = 0.38
var system_confirm_blink_elapsed: float = 0.0
var system_confirm_blink_bright: bool = true
# Reuse the same display rig, without reparenting it: SeraRig has external
# afterimage nodes whose lifetime is tied to _exit_tree. Set its world transform
# from camera space instead; no duplicate model, SubViewport or draw batch.
var sera_display_stand: Node3D
var sera_display_rig: Node3D
var sera_original_transform: Transform3D
var customize_glow_quad: MeshInstance3D
var customize_entrance_tween: Tween # Shared by forward and reverse exhibit motions.
var customize_transition_start_camera_pose: Transform3D = Transform3D.IDENTITY
var customize_transition_start_camera_fov: float = 63.0
var customize_motion_torso_local: Vector3 = Vector3.ZERO
# Body-only bone pivots (no sword or shield) approximate the visible model
# bounds; using only the torso pivot made the *silhouette* appear to arc.
var customize_motion_body_markers: PackedVector3Array = PackedVector3Array()
var customize_motion_start_local: Transform3D = Transform3D.IDENTITY
var customize_motion_end_local: Transform3D = Transform3D.IDENTITY
var customize_motion_start_fov: float = 63.0
var customize_motion_end_fov: float = 63.0
var customize_motion_progress: float = 0.0
var customize_motion_active: bool = false
var customize_preview_final_world: Transform3D = Transform3D.IDENTITY
# Normalized backdrop anchor and head-relative grid spacing are captured once
# before preview rotation, never recomputed on yaw input.
var customize_glow_center_ratio: Vector2 = Vector2(0.73, 0.50)
var customize_glow_grid_spacing_ratio: float = 0.030
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
const CUSTOMIZE_GLOW_SCREEN_WIDTH: float = 0.46
const CUSTOMIZE_GLOW_SCREEN_HEIGHT: float = 0.42
const CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.435
const CUSTOMIZE_ENTRANCE_SECONDS: float = 0.14
const CUSTOMIZE_RETRACTION_SECONDS: float = 0.14
const CUSTOMIZE_BOTTOM_GAP_PIXELS: float = 10.0
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
# Each entry holds world-space 3D vertex clusters, one per visible mesh.
var target_parts: Dictionary = {}
# Reuse each mesh's actual authored vertices when reprojecting a changed outfit.
var customize_silhouette_vertex_cache: Dictionary = {}

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
    "CUSTOMIZE": Vector2(0.035, 0.435)
}

func _ready() -> void:
    _environment()
    _module("hangar_shell", Vector3.ZERO)
    _module("maintenance_pad", Vector3(0.0, 0.0, -4.75))
    _module("maintenance_canopy", Vector3(0.0, 8.0, -8.95))
    _module("deployment_gate", GATE_ORIGIN, _gate_facing_yaw(), 1.20, 1.25)
    _module("system_mezzanine", Vector3(-4.00, 0.0, -6.55))
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
    SeraSave.mark_location("NEXUS")

func _process(delta: float) -> void:
    SeraSave.record_game_time(delta)
    _update_system_confirmation_blink(delta)
    if focused_target == "DATA ARCHIVE" and not in_transition:
        archive_refresh_elapsed += delta
        if archive_refresh_elapsed >= 1.0:
            archive_refresh_elapsed = 0.0
            _refresh_archive_records()

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
    # Capture only the meshes currently visible after A/B/C part selection.
    # Keep each mesh separate: a bone-level AABB connects unrelated armor
    # pieces and cannot trace B's round head or future custom equipment.
    var visible_parts: Array = []
    _collect_sera_geometry(rig, visible_parts)
    target_parts["CUSTOMIZE"] = visible_parts

func _mesh_outline_local_vertices(mesh: Mesh) -> PackedVector3Array:
    # SurfaceTool emits duplicate triangle vertices. Cache their unique local
    # positions once per mesh, then transform the current pose at each capture.
    var mesh_id: int = mesh.get_instance_id()
    if customize_silhouette_vertex_cache.has(mesh_id):
        return customize_silhouette_vertex_cache[mesh_id]
    var local_vertices := PackedVector3Array()
    if mesh is ArrayMesh:
        var array_mesh: ArrayMesh = mesh as ArrayMesh
        var seen: Dictionary = {}
        for surface_index in range(array_mesh.get_surface_count()):
            var arrays: Array = array_mesh.surface_get_arrays(surface_index)
            if arrays.size() <= Mesh.ARRAY_VERTEX:
                continue
            var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            for vertex in points:
                if seen.has(vertex):
                    continue
                seen[vertex] = true
                local_vertices.append(vertex)
    # PrimitiveMesh or unavailable CPU surfaces: retain the old safe fallback.
    if local_vertices.is_empty():
        var aabb: AABB = mesh.get_aabb()
        for ix in [0.0, 1.0]:
            for iy in [0.0, 1.0]:
                for iz in [0.0, 1.0]:
                    local_vertices.append(
                        aabb.position + aabb.size * Vector3(ix, iy, iz))
    customize_silhouette_vertex_cache[mesh_id] = local_vertices
    return local_vertices

func _collect_sera_geometry(node: Node, visible_parts: Array) -> void:
    if node is MeshInstance3D:
        var piece: MeshInstance3D = node as MeshInstance3D
        # Ignore hidden variants and the separate sword slash effect.
        if piece.mesh != null and piece.is_visible_in_tree() and piece.name != "Swordeffect":
            var local_vertices: PackedVector3Array = _mesh_outline_local_vertices(piece.mesh)
            if local_vertices.size() >= 3:
                var world_vertices := PackedVector3Array()
                for vertex in local_vertices:
                    world_vertices.append(piece.global_transform * vertex)
                visible_parts.append(world_vertices)
    for child in node.get_children():
        _collect_sera_geometry(child, visible_parts)

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
    # CUSTOMIZE's second, tall right-side menu scaffold. No fabricated
    # actions: both menus remain placeholders until their contents are defined.
    customize_right_panel = Panel.new()
    customize_right_panel.name = "CustomizeTallRightMenu"
    customize_right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_right_panel.add_theme_stylebox_override("panel", _menu_body_style())
    customize_right_panel.visible = false
    hud.add_child(customize_right_panel)
    customize_right_header = Panel.new()
    customize_right_header.name = "CustomizeTallRightHeader"
    customize_right_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_right_header.add_theme_stylebox_override("panel", _menu_header_style())
    customize_right_panel.add_child(customize_right_header)
    _create_equipment_controls()
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
    _create_system_controls()
    _create_archive_records()
    hud.resized.connect(_layout_hud)
    _layout_hud()
    _update_projected_silhouettes()

## Hit zones are handled by _input, matching the existing Android raw-touch UI.
## These labels are not Control buttons and therefore never steal preview drags.
func _create_equipment_controls() -> void:
    customize_equipment_header = Label.new()
    customize_equipment_header.text = "PARTS / SETS"
    customize_equipment_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_equipment_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    customize_equipment_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    customize_equipment_header.add_theme_font_size_override("font_size", 19)
    customize_equipment_header.add_theme_color_override("font_color", Color("#d1efff"))
    customize_right_header.add_child(customize_equipment_header)
    for slot in CUSTOMIZE_SLOTS:
        var row := Panel.new()
        row.name = "Equipment_" + slot
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_stylebox_override("panel", _menu_style())
        customize_right_panel.add_child(row)
        var name_label := Label.new()
        name_label.text = str(CUSTOMIZE_SLOT_LABELS[slot])
        name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        name_label.add_theme_font_size_override("font_size", 17)
        name_label.add_theme_color_override("font_color", Color("#a6cfdf"))
        row.add_child(name_label)
        var set_label := Label.new()
        set_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        set_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        set_label.add_theme_font_size_override("font_size", 23)
        set_label.add_theme_color_override("font_color", Color("#dcfaff"))
        row.add_child(set_label)
        customize_equipment_rows[slot] = {
            "panel": row, "name": name_label, "value": set_label
        }
    _refresh_equipment_controls()

func _layout_equipment_controls() -> void:
    if customize_equipment_header == null or customize_right_panel == null:
        return
    customize_equipment_header.position = Vector2.ZERO
    customize_equipment_header.size = customize_right_header.size
    var top: float = customize_right_header.size.y + 9.0
    var height_per_row: float = maxf(36.0,
        (customize_right_panel.size.y - top - 10.0) / float(CUSTOMIZE_SLOTS.size()))
    for i in range(CUSTOMIZE_SLOTS.size()):
        var row_data: Dictionary = customize_equipment_rows[CUSTOMIZE_SLOTS[i]]
        var row: Panel = row_data["panel"]
        row.position = Vector2(10.0, top + float(i) * height_per_row)
        row.size = Vector2(maxf(50.0, customize_right_panel.size.x - 20.0),
            maxf(30.0, height_per_row - 7.0))
        var name_label: Label = row_data["name"]
        name_label.position = Vector2(12.0, 4.0)
        name_label.size = Vector2(row.size.x - 24.0, row.size.y * 0.40)
        var value_label: Label = row_data["value"]
        value_label.position = Vector2(8.0, row.size.y * 0.40)
        value_label.size = Vector2(row.size.x - 16.0, row.size.y * 0.56)

func _refresh_equipment_controls() -> void:
    for slot in CUSTOMIZE_SLOTS:
        if not customize_equipment_rows.has(slot):
            continue
        var options: Array = ["A"]
        var current_set: String = "A"
        if sera_display_rig != null and bool(sera_display_rig.get("loading_ok")):
            options = sera_display_rig.call("get_equipment_options", slot)
            current_set = str(sera_display_rig.call("get_equipment_selection", slot))
        var label: Label = customize_equipment_rows[slot]["value"]
        label.text = "<   %s   >" % current_set if options.size() > 1 else current_set

func _tap_equipment_control(point: Vector2) -> bool:
    if sera_display_rig == null or not Rect2(
            customize_right_panel.position, customize_right_panel.size).has_point(point):
        return false
    var local: Vector2 = point - customize_right_panel.position
    for slot in CUSTOMIZE_SLOTS:
        var row: Panel = customize_equipment_rows[slot]["panel"]
        if not Rect2(row.position, row.size).has_point(local):
            continue
        var choices: Array = sera_display_rig.call("get_equipment_options", slot)
        if choices.size() < 2:
            return true
        var current_set: String = str(sera_display_rig.call("get_equipment_selection", slot))
        var index: int = maxi(0, choices.find(current_set))
        var direction: int = -1 if local.x < row.position.x + row.size.x * 0.45 else 1
        var next_index: int = posmod(index + direction, choices.size())
        if bool(sera_display_rig.call("set_equipment_selection", slot, choices[next_index])):
            _refresh_equipment_controls()
            _capture_sera_silhouette(sera_display_rig)
            _update_projected_silhouettes()
            outline.queue_redraw()
        return true
    return true


## v171 DATA ARCHIVE: reusable focus-panel elements. Text-only slot rows keep
## the 3D data bank visible and avoid a second full-screen UI layer.
func _create_system_controls() -> void:
    system_selected_slot = SeraSave.active_slot if SeraSave.active_slot > 0 else 1
    for index in range(SeraSave.SLOT_COUNT):
        var row := Panel.new()
        row.name = "ArchiveSlot%02d" % (index + 1)
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.visible = false
        focus_panel.add_child(row)
        var title_label := Label.new()
        title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        title_label.add_theme_font_size_override("font_size", 15)
        title_label.add_theme_color_override("font_color", Color("#dcf4ff"))
        row.add_child(title_label)
        system_slot_rows.append({"panel": row, "label": title_label})
    for action in SYSTEM_ACTIONS:
        var button := Panel.new()
        button.name = "Archive" + action
        button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_theme_stylebox_override("panel", _menu_style())
        button.visible = false
        focus_panel.add_child(button)
        var action_text := Label.new()
        action_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
        action_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        action_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        action_text.add_theme_font_size_override("font_size", 16)
        action_text.add_theme_color_override("font_color", Color("#c8f1ff"))
        button.add_child(action_text)
        system_action_rows.append({"panel": button, "label": action_text, "action": action})
    system_status = Label.new()
    system_status.name = "ArchiveStatus"
    system_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    system_status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    system_status.add_theme_font_size_override("font_size", 14)
    system_status.add_theme_color_override("font_color", Color("#a5e4ff"))
    system_status.visible = false
    focus_panel.add_child(system_status)
    _refresh_system_controls()

func _set_system_visible(show: bool) -> void:
    for entry in system_slot_rows:
        (entry["panel"] as Panel).visible = show
    for entry in system_action_rows:
        (entry["panel"] as Panel).visible = show
    system_status.visible = show

func _layout_system_controls() -> void:
    if system_status == null:
        return
    var width: float = focus_panel.size.x
    var margin: float = 12.0
    var gap: float = 8.0
    var row_height: float = minf(84.0, maxf(62.0,
        (focus_panel.size.y - focus_header.size.y - 224.0) / 3.0))
    var top: float = focus_header.size.y + 12.0
    for i in range(system_slot_rows.size()):
        var panel: Panel = system_slot_rows[i]["panel"]
        panel.position = Vector2(margin, top + i * (row_height + gap))
        panel.size = Vector2(width - margin * 2.0, row_height)
        var label: Label = system_slot_rows[i]["label"]
        label.position = Vector2(12.0, 0.0)
        label.size = panel.size - Vector2(24.0, 0.0)
    var actions_top: float = top + system_slot_rows.size() * (row_height + gap) + 9.0
    var action_width: float = (width - margin * 2.0 - gap) * 0.5
    for i in range(system_action_rows.size()):
        var button: Panel = system_action_rows[i]["panel"]
        button.position = Vector2(margin + (i % 2) * (action_width + gap),
            actions_top + (i / 2) * 58.0)
        button.size = Vector2(action_width, 50.0)
        var label: Label = system_action_rows[i]["label"]
        label.position = Vector2.ZERO
        label.size = button.size
    system_status.position = Vector2(margin, actions_top + 126.0)
    system_status.size = Vector2(width - margin * 2.0,
        maxf(34.0, focus_panel.size.y - system_status.position.y - 10.0))

func _refresh_system_controls() -> void:
    if system_status == null:
        return
    for index in range(system_slot_rows.size()):
        var slot: int = index + 1
        var data: Dictionary = SeraSave.get_slot(slot)
        var active: String = "  [ACTIVE]" if SeraSave.active_slot == slot else ""
        var label: Label = system_slot_rows[index]["label"]
        if data.is_empty():
            label.text = "SLOT %02d%s  /  EMPTY\nCREATE NEW DATA OR SAVE" % [slot, active]
        else:
            var seconds: int = int(float(data.get("training_seconds", 0.0)))
            var clock: String = "%02d:%02d" % [seconds / 3600, (seconds / 60) % 60]
            label.text = "SLOT %02d%s  /  %s\nPLAY %s   ·   %s" % [
                slot, active, str(data.get("last_location", "NEXUS")), clock,
                str(data.get("updated_at", "-"))]
        var panel: Panel = system_slot_rows[index]["panel"]
        var style: StyleBoxFlat = _menu_style()
        if system_selected_slot == slot:
            style.bg_color = Color(0.052, 0.190, 0.280, 0.95)
            if not system_pending_action.is_empty() and system_pending_slot == slot:
                style.set_border_width_all(3)
                style.border_color = (Color("#e2f8ff") if system_confirm_blink_bright
                    else Color(0.0, 0.0, 0.0, 0.0))
            else:
                style.border_color = Color("#b0edff")
        panel.add_theme_stylebox_override("panel", style)
    for entry in system_action_rows:
        var action: String = entry["action"]
        var label: Label = entry["label"]
        if system_pending_action == action and system_pending_slot == system_selected_slot:
            label.text = "CONFIRM " + action
        else:
            label.text = "NEW DATA" if action == "NEW" else action
    system_status.text = system_message if not system_message.is_empty() else (
        "SELECT A SLOT  /  SAVE, LOAD, NEW OR DELETE\n"
        + "Saves are stored locally on this device.")

func _reset_system_confirmation_blink() -> void:
    system_confirm_blink_elapsed = 0.0
    system_confirm_blink_bright = true

func _update_system_confirmation_blink(delta: float) -> void:
    if (focused_target != "SYSTEM" or in_transition
            or system_pending_action.is_empty()
            or system_pending_slot != system_selected_slot):
        return
    system_confirm_blink_elapsed += delta
    var bright: bool = (int(system_confirm_blink_elapsed /
        SYSTEM_CONFIRM_BLINK_HALF_SECONDS) % 2) == 0
    if bright == system_confirm_blink_bright:
        return
    system_confirm_blink_bright = bright
    if system_pending_slot < 1 or system_pending_slot > system_slot_rows.size():
        return
    var panel: Panel = system_slot_rows[system_pending_slot - 1]["panel"]
    # Each row owns its own StyleBoxFlat. Change only that row's border;
    # keep its text/background readable and avoid allocating styles each frame.
    var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
    if style != null:
        style.border_color = (Color("#e2f8ff") if bright
            else Color(0.0, 0.0, 0.0, 0.0))

func _cancel_system_confirmation() -> bool:
    if system_pending_action.is_empty():
        return false
    system_pending_action = ""
    system_pending_slot = 0
    _reset_system_confirmation_blink()
    system_message = "OPERATION CANCELLED"
    _refresh_system_controls()
    return true

func _tap_system_control(point: Vector2) -> void:
    var local: Vector2 = point - focus_panel.position
    for i in range(system_slot_rows.size()):
        var panel: Panel = system_slot_rows[i]["panel"]
        if Rect2(panel.position, panel.size).has_point(local):
            system_selected_slot = i + 1
            system_pending_action = ""
            system_pending_slot = 0
            _reset_system_confirmation_blink()
            system_message = ""
            _refresh_system_controls()
            return
    for entry in system_action_rows:
        var panel: Panel = entry["panel"]
        if not Rect2(panel.position, panel.size).has_point(local):
            continue
        var action: String = entry["action"]
        var slot: int = system_selected_slot
        var exists: bool = not SeraSave.get_slot(slot).is_empty()
        if action == "LOAD" and not exists:
            system_message = "SLOT %02d IS EMPTY" % slot
            _refresh_system_controls()
            return
        if action == "DELETE" and not exists:
            system_message = "NOTHING TO DELETE"
            _refresh_system_controls()
            return
        var destructive: bool = (action == "DELETE" or
            (exists and (action == "SAVE" or action == "NEW")))
        if destructive and (system_pending_action != action or system_pending_slot != slot):
            system_pending_action = action
            system_pending_slot = slot
            _reset_system_confirmation_blink()
            system_message = "PRESS CONFIRM %s TO MODIFY SLOT %02d" % [action, slot]
            _refresh_system_controls()
            return
        system_pending_action = ""
        system_pending_slot = 0
        _reset_system_confirmation_blink()
        var success: bool = false
        match action:
            "SAVE":
                success = SeraSave.save_data(slot, _current_system_equipment())
            "LOAD":
                success = SeraSave.load_data(slot)
                if success:
                    _apply_system_equipment()
            "NEW":
                success = SeraSave.create_data(slot)
                if success:
                    _apply_system_equipment()
            "DELETE":
                success = SeraSave.delete_data(slot)
                if success and SeraSave.active_slot == 0:
                    _apply_system_equipment()
        system_message = ("%s / SLOT %02d COMPLETE" if success else
            "%s / SLOT %02d FAILED") % [action, slot]
        _refresh_system_controls()
        return

func _current_system_equipment() -> Dictionary:
    var gear: Dictionary = {}
    for part in CUSTOMIZE_SLOTS:
        var selected: String = "A"
        if sera_display_rig != null:
            selected = str(sera_display_rig.call("get_equipment_selection", part))
        gear[part] = selected
    return gear

func _apply_system_equipment() -> void:
    if sera_display_rig == null:
        return
    var saved: Dictionary = SeraSave.get_working_equipment()
    for part in CUSTOMIZE_SLOTS:
        var selected: String = str(saved.get(part, "A"))
        var options: Array = sera_display_rig.call("get_equipment_options", part)
        if not options.has(selected):
            selected = "A"
        sera_display_rig.call("set_equipment_selection", part, selected)
    _refresh_equipment_controls()
    _capture_sera_silhouette(sera_display_rig)
    _update_projected_silhouettes()
    outline.queue_redraw()


## DATA ARCHIVE is strictly read-only. The records use the currently loaded
## session, not another slot or saved values that may be older than gameplay.
func _create_archive_records() -> void:
    for tab in ARCHIVE_TABS:
        var panel := Panel.new()
        panel.name = "ArchiveTab" + str(tab)
        panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.visible = false
        focus_panel.add_child(panel)
        var label := Label.new()
        label.text = str(tab)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 12)
        label.add_theme_color_override("font_color", Color("#d1f2ff"))
        panel.add_child(label)
        archive_record_tabs.append({"panel": panel, "label": label})
    archive_record_body = Label.new()
    archive_record_body.name = "ArchiveRecordReadOnly"
    archive_record_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    archive_record_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    archive_record_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    archive_record_body.add_theme_font_size_override("font_size", 17)
    archive_record_body.add_theme_color_override("font_color", Color("#e1f3fd"))
    archive_record_body.visible = false
    archive_record_body.clip_contents = true
    focus_panel.add_child(archive_record_body)
    _refresh_archive_records()

func _set_archive_records_visible(show: bool) -> void:
    for entry in archive_record_tabs:
        (entry["panel"] as Panel).visible = show
    archive_record_body.visible = show

func _layout_archive_records() -> void:
    if archive_record_body == null:
        return
    var width: float = focus_panel.size.x
    var margin: float = 12.0
    var gap: float = 5.0
    var item_width: float = (width - margin * 2.0 -
        gap * float(ARCHIVE_TABS.size() - 1)) / float(ARCHIVE_TABS.size())
    var tab_top: float = focus_header.size.y + 14.0
    for i in range(archive_record_tabs.size()):
        var panel: Panel = archive_record_tabs[i]["panel"]
        panel.position = Vector2(margin + i * (item_width + gap), tab_top)
        panel.size = Vector2(item_width, 46.0)
        var label: Label = archive_record_tabs[i]["label"]
        label.position = Vector2.ZERO
        label.size = panel.size
    archive_record_body.position = Vector2(margin + 4.0, tab_top + 65.0)
    archive_record_body.size = Vector2(width - margin * 2.0 - 8.0,
        maxf(20.0, focus_panel.size.y - archive_record_body.position.y - 10.0))

func _archive_duration(raw_seconds: float) -> String:
    var seconds: int = maxi(0, int(raw_seconds))
    return "%02d:%02d:%02d" % [
        int(seconds / 3600.0), int(seconds / 60.0) % 60, seconds % 60]

func _refresh_archive_records() -> void:
    if archive_record_body == null:
        return
    for i in range(archive_record_tabs.size()):
        var style: StyleBoxFlat = _menu_style()
        if i == archive_record_tab:
            style.bg_color = Color(0.055, 0.200, 0.300, 0.96)
            style.border_color = Color("#b9f2ff")
        (archive_record_tabs[i]["panel"] as Panel).add_theme_stylebox_override(
            "panel", style)
    if SeraSave.active_slot == 0:
        archive_record_body.text = (
            "NO ACTIVE DATA\n\nCreate or load a save in SYSTEM to record "
            + "training and combat statistics.\n\n"
            + "Story and mission progression is not available yet.")
        return
    var data: Dictionary = SeraSave.get_active_data()
    var stats: Dictionary = SeraSave.get_active_stats()
    var active: String = "SLOT %02d" % SeraSave.active_slot
    match ARCHIVE_TABS[archive_record_tab]:
        "SUMMARY":
            archive_record_body.text = (
                "SESSION OVERVIEW  /  " + active + "\n\n"
                + "TOTAL PLAY TIME\n" + _archive_duration(
                    float(data.get("play_seconds", 0.0))) + "\n\n"
                + "TRAINING TIME\n" + _archive_duration(
                    float(data.get("training_seconds", 0.0))) + "\n\n"
                + "TRAINING TARGETS DEFEATED  /  %d\n" % int(
                    stats.get("target_destroys", 0))
                + "LAST AREA  /  " + str(data.get("last_location", "NEXUS"))
                + "\n\nRecords are saved via SYSTEM > SAVE.")
        "COMBAT":
            archive_record_body.text = (
                "TRAINING COMBAT  /  " + active + "\n\n"
                + "TARGET DESTROYS  /  %d\n" % int(stats.get("target_destroys", 0))
                + "MELEE HITS  /  %d\n" % int(stats.get("melee_hits", 0))
                + "BASH HITS  /  %d\n" % int(stats.get("bash_hits", 0))
                + "DAMAGE DEALT  /  %d\n" % int(stats.get("damage_dealt", 0))
                + "GUARDED IMPACTS  /  %d\n" % int(stats.get("guarded_hits", 0))
                + "UNGUARDED HITS  /  %d\n\n" % int(stats.get("received_hits", 0))
                + "Target destroys are training dummies, not enemy kills.")
        "PROGRESS":
            var visited: String = "VISITED" if bool(
                data.get("training_visited", false)) else "NOT VISITED"
            archive_record_body.text = (
                "GAME PROGRESS  /  " + active + "\n\n"
                + "TRAINING ROOM  /  " + visited + "\n\n"
                + "STORY CHAPTERS  /  NOT IMPLEMENTED\n\n"
                + "MISSIONS CLEARED  /  NOT IMPLEMENTED\n\n"
                + "TUTORIAL  /  NOT IMPLEMENTED\n\n"
                + "Additional progress will appear when those systems exist.")
        "PROFILE":
            var gear: Dictionary = SeraSave.get_working_equipment()
            archive_record_body.text = (
                "PROFILE  /  " + active + "\n\n"
                + "CREATED  /  " + str(data.get("created_at", "-")) + "\n"
                + "LAST SAVED  /  " + str(data.get("updated_at", "-")) + "\n\n"
                + "EQUIPMENT SETS (CURRENT)\n"
                + "HEAD %s   TORSO %s   LEGS %s\n" % [
                    str(gear.get("head", "A")), str(gear.get("torso", "A")),
                    str(gear.get("legs", "A"))]
                + "ARMS %s   R-WPN %s   L-WPN %s\n\n" % [
                    str(gear.get("arms", "A")), str(gear.get("weapon_r", "A")),
                    str(gear.get("weapon_l", "A"))]
                + "Save changes through SYSTEM.")

func _tap_archive_record(point: Vector2) -> void:
    var local: Vector2 = point - focus_panel.position
    for i in range(archive_record_tabs.size()):
        var panel: Panel = archive_record_tabs[i]["panel"]
        if Rect2(panel.position, panel.size).has_point(local):
            archive_record_tab = i
            _refresh_archive_records()
            return

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

# Three-zone CUSTOMIZE portrait: upper-left model, lower-left square,
# right-side tall menu. All rectangles are in HUD viewport coordinates.
func _customize_square_menu_rect(view: Vector2) -> Rect2:
    var placement: Vector2 = PANEL_LAYOUTS["CUSTOMIZE"]
    var square_side: float = minf(view.x * placement.y, view.y * 0.28)
    return Rect2(
        Vector2(view.x * placement.x, view.y * 0.865 - square_side),
        Vector2(square_side, square_side))

func _customize_tall_menu_rect(view: Vector2) -> Rect2:
    return Rect2(
        Vector2(view.x * 0.525, view.y * 0.135),
        Vector2(view.x * 0.440, view.y * 0.730))

func _customize_model_area(view: Vector2) -> Rect2:
    var square: Rect2 = _customize_square_menu_rect(view)
    var top: float = view.y * 0.10
    var bottom: float = minf(view.y * 0.615,
        square.position.y - maxf(12.0, view.y * 0.012))
    return Rect2(
        Vector2(square.position.x, top),
        Vector2(square.size.x, maxf(1.0, bottom - top)))

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
    focus_panel.size = Vector2(view.x * panel_placement.y,
        view.y * (0.61 if focused_target == "DATA ARCHIVE" else 0.535))
    if focused_target == "DATA ARCHIVE":
        focus_panel.position.y = view.y * 0.17
    if focused_target == "CUSTOMIZE":
        var square: Rect2 = _customize_square_menu_rect(view)
        var tall: Rect2 = _customize_tall_menu_rect(view)
        focus_panel.position = square.position
        focus_panel.size = square.size
        customize_right_panel.position = tall.position
        customize_right_panel.size = tall.size
        customize_right_header.position = Vector2.ZERO
        customize_right_header.size = Vector2(
            tall.size.x, minf(60.0, view.y * 0.068))
        _layout_equipment_controls()
    # The opaque top stripe belongs to the focus panel; rest stays blue/clear.
    focus_header.position = Vector2.ZERO
    focus_header.size = Vector2(focus_panel.size.x, minf(60.0, view.y * 0.068))
    focus_title.position = Vector2(16.0, 0.0)
    focus_title.size = Vector2(focus_header.size.x - 32.0, focus_header.size.y)
    action_panel.position = Vector2(16.0, focus_panel.size.y - 84.0)
    action_panel.size = Vector2(focus_panel.size.x - 32.0, 60.0)
    action_label.position = Vector2.ZERO
    action_label.size = action_panel.size
    _layout_system_controls()
    _layout_archive_records()
    _update_projected_silhouettes()
    if customize_preview_active:
        _update_customization_glow()

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

# Snapshot the default front pose only once, before the first preview frame.
# Neither the backdrop anchor nor grid pitch changes when SERA turns.
func _capture_customization_glow_layout() -> void:
    if not customize_preview_active or sera_display_rig == null or cam == null or hud == null:
        return
    var viewport_size := hud.size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    var rect := _customization_screen_bounds()
    if rect.size.x <= 1.0 or rect.size.y <= 1.0:
        return
    var center: Vector2 = rect.position + rect.size * 0.5
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
    var model_area: Rect2 = _customize_model_area(viewport_size)
    center.x = clampf(center.x,
        model_area.position.x + 20.0, model_area.end.x - 20.0)
    center.y = clampf(center.y,
        model_area.position.y + 20.0, model_area.end.y - 20.0)
    customize_glow_center_ratio = Vector2(
        center.x / viewport_size.x, center.y / viewport_size.y)

    # Half the projected head width is the width/height of one grid cell.
    # This is measured on the original NEXUS pose at its fitted scale.
    var head_half_pixels: float = viewport_size.y * 0.030
    var head_node: Node = sera_display_rig.find_child("Head_Mesh", true, false)
    if head_node is MeshInstance3D:
        var head_mesh: MeshInstance3D = head_node as MeshInstance3D
        if head_mesh.mesh != null:
            var box: AABB = head_mesh.mesh.get_aabb()
            var left: float = INF
            var right: float = -INF
            for ix in [0.0, 1.0]:
                for iy in [0.0, 1.0]:
                    for iz in [0.0, 1.0]:
                        var local := box.position + box.size * Vector3(ix, iy, iz)
                        var world: Vector3 = head_mesh.global_transform * local
                        if cam.is_position_behind(world):
                            continue
                        var pixel: Vector2 = cam.unproject_position(world)
                        left = minf(left, pixel.x)
                        right = maxf(right, pixel.x)
            if right > left:
                head_half_pixels = (right - left) * 0.5
    customize_glow_grid_spacing_ratio = clampf(
        head_half_pixels / viewport_size.y, 0.014, 0.090)

# Draw using only the frozen preview anchor. Viewport resize can rescale the
# quad but cannot make it follow SERA's rotation or change its UV grid phase.
func _update_customization_glow() -> void:
    if not customize_preview_active or customize_glow_quad == null or cam == null or hud == null:
        return
    var viewport_size := hud.size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    var center := Vector2(
        viewport_size.x * customize_glow_center_ratio.x,
        viewport_size.y * customize_glow_center_ratio.y)
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
    var spacing: float = maxf(12.0,
        viewport_size.y * customize_glow_grid_spacing_ratio)
    var material := customize_glow_quad.material_override as ShaderMaterial
    if material != null:
        material.set_shader_parameter("grid_cells", Vector2(
            viewport_size.x * CUSTOMIZE_GLOW_SCREEN_WIDTH / spacing,
            viewport_size.y * CUSTOMIZE_GLOW_SCREEN_HEIGHT / spacing))

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

# The root is at the feet; the visible torso must serve as the path anchor.
# Cache its local offset before any preview transform is applied.
func _customize_torso_anchor_local() -> Vector3:
    if sera_display_rig == null:
        return Vector3.ZERO
    var bones: Dictionary = sera_display_rig.get("bones")
    var summed := Vector3.ZERO
    var count := 0
    for raw_bone in bones.values():
        var bone: Node3D = raw_bone
        if bone.name in ["Chest", "Torso", "Waist"]:
            summed += sera_display_rig.to_local(bone.global_position)
            count += 1
    if count > 0:
        return summed / float(count)
    return Vector3.ZERO

# Record a small, fixed set of body landmarks. This is cheap enough for an
# Android device: ~19 pivots, not every Blockbench polygon or effect mesh.
func _capture_customize_body_markers() -> void:
    customize_motion_body_markers.clear()
    if sera_display_rig == null:
        return
    var bones: Dictionary = sera_display_rig.get("bones")
    var body_names: Array[String] = [
        "Head", "Neck", "Chest", "Torso", "Waist",
        "Shoulder_L", "Shoulder_R", "UpperArm_L", "UpperArm_R",
        "Forearm_L", "Forearm_R", "Hand_L", "Hand_R",
        "Thigh_L", "Thigh_R", "LowerLeg_L", "LowerLeg_R",
        "Foot_L", "Foot_R"
    ]
    for raw_bone in bones.values():
        var bone: Node3D = raw_bone
        if body_names.has(bone.name):
            customize_motion_body_markers.append(
                sera_display_rig.to_local(bone.global_position))
    if customize_motion_body_markers.is_empty():
        customize_motion_body_markers.append(customize_motion_torso_local)

func _show_customization_preview() -> void:
    if customize_preview_active or cam == null or sera_display_rig == null:
        return
    if not bool(sera_display_rig.get("loading_ok")):
        return
    # The same rig starts on its original exhibit stand. Calculate the fitted
    # destination on this frame, then restore its start transform before draw.
    var initial_world: Transform3D = sera_display_rig.global_transform
    customize_motion_torso_local = _customize_torso_anchor_local()
    _capture_customize_body_markers()
    customize_preview_position = Vector3(0.75, -0.20, -CUSTOMIZE_PREVIEW_DISTANCE)
    customize_preview_scale = 1.40
    customize_preview_fitted_scale = 1.40
    customize_preview_yaw = PI
    customize_preview_active = true
    _apply_customization_preview_transform()
    _capture_sera_silhouette(sera_display_rig)
    _fit_customization_preview()
    _capture_sera_silhouette(sera_display_rig)
    var final_world: Transform3D = sera_display_rig.global_transform
    customize_preview_final_world = final_world
    # Both endpoints use their own camera frames. A simple WORLD-space
    # straight line is not a visible screen-space path while the camera
    # retreats; it made SERA exit the view and reappear near the stand.
    var start_camera_local: Transform3D = (
        customize_transition_start_camera_pose.affine_inverse() * initial_world)
    var end_camera_local: Transform3D = (
        cam.global_transform.affine_inverse() * final_world)
    # Capture the stationary grid/gradient from the final default pose once,
    # not from the moving/rotating character during the tween.
    _capture_customization_glow_layout()
    _update_customization_glow()
    # The backdrop must NOT appear until the model actually reaches the
    # designated enlarged position. It is revealed in the Tween completion.
    customize_glow_quad.visible = false
    outline.set("hide_customize_preview_outline", true)
    sera_display_rig.global_transform = initial_world
    _capture_sera_silhouette(sera_display_rig)
    _update_projected_silhouettes()
    outline.queue_redraw()
    # Start this SERA Tween in the same tap callback as the camera Tween:
    # the target camera pose was temporarily applied for final-pose fitting.
    if customize_entrance_tween != null and customize_entrance_tween.is_running():
        customize_entrance_tween.kill()
    _prepare_customization_motion(start_camera_local, end_camera_local,
        customize_transition_start_camera_fov, cam.fov)
    in_transition = true
    customize_entrance_tween = create_tween()
    # A linear time parameter makes the 2D position travel with constant
    # velocity on its straight line. Scale/yaw ease separately below.
    customize_entrance_tween.set_trans(Tween.TRANS_LINEAR)
    customize_entrance_tween.tween_method(_apply_customization_entrance.bind(
        start_camera_local, end_camera_local,
        customize_transition_start_camera_fov, cam.fov), 0.0, 1.0,
        CUSTOMIZE_ENTRANCE_SECONDS)
    customize_entrance_tween.finished.connect(
        _customization_entrance_arrived.bind(final_world))

# Model and camera Tweens can advance in either frame order. Cache model
# progress and both endpoints so camera updates can correct the model pose.
func _prepare_customization_motion(start_local: Transform3D,
        end_local: Transform3D, from_fov: float, to_fov: float) -> void:
    customize_motion_start_local = start_local
    customize_motion_end_local = end_local
    customize_motion_start_fov = from_fov
    customize_motion_end_fov = to_fov
    customize_motion_progress = 0.0
    customize_motion_active = true

# Project the TORSO center, not the feet/root, then recover the root origin
# from the interpolated model basis so the visible torso follows one line.
func _customize_projected_ndc(point: Vector3, view_fov: float) -> Vector2:
    var depth: float = maxf(0.01, -point.z)
    var half_tan: float = tan(deg_to_rad(view_fov) * 0.5)
    var aspect: float = maxf(hud.size.x, 1.0) / maxf(hud.size.y, 1.0)
    return Vector2(
        point.x / (depth * half_tan * aspect),
        point.y / (depth * half_tan))

# Measure the projected body envelope, not just its center. The model's
# world scale and perspective depth may otherwise make it grow much larger
# mid-flight despite the center following a straight line.
func _customize_body_bounds_ndc(camera_local: Transform3D,
        view_fov: float) -> Rect2:
    var minimum := Vector2(INF, INF)
    var maximum := Vector2(-INF, -INF)
    var found := false
    for marker in customize_motion_body_markers:
        var camera_point: Vector3 = camera_local * marker
        if camera_point.z >= -0.05:
            continue
        var screen: Vector2 = _customize_projected_ndc(
            camera_point, view_fov)
        minimum = minimum.min(screen)
        maximum = maximum.max(screen)
        found = true
    if not found:
        var center := _customize_projected_ndc(
            camera_local * customize_motion_torso_local, view_fov)
        return Rect2(center - Vector2(0.005, 0.005), Vector2(0.01, 0.01))
    return Rect2(minimum, maximum - minimum)

func _customize_body_center_ndc(camera_local: Transform3D,
        view_fov: float) -> Vector2:
    return _customize_body_bounds_ndc(camera_local, view_fov).get_center()

func _apply_customization_entrance(progress: float,
        start_camera_local: Transform3D, end_camera_local: Transform3D,
        start_fov: float, end_fov: float) -> void:
    if not customize_preview_active or sera_display_rig == null or cam == null:
        return
    customize_motion_progress = progress
    # Linear screen-space center AND linear apparent width/height. A straight
    # center alone (v145) still let perspective/scaling balloon the body.
    var start_bounds: Rect2 = _customize_body_bounds_ndc(
        start_camera_local, start_fov)
    var end_bounds: Rect2 = _customize_body_bounds_ndc(
        end_camera_local, end_fov)
    var target_ndc: Vector2 = start_bounds.get_center().lerp(
        end_bounds.get_center(), progress)
    var target_size: Vector2 = start_bounds.size.lerp(
        end_bounds.size, progress)
    var start_torso: Vector3 = start_camera_local * customize_motion_torso_local
    var end_torso: Vector3 = end_camera_local * customize_motion_torso_local
    var depth: float = lerpf(-start_torso.z, -end_torso.z, progress)
    var half_tan: float = tan(deg_to_rad(cam.fov) * 0.5)
    var aspect: float = maxf(hud.size.x, 1.0) / maxf(hud.size.y, 1.0)
    # The pose still eases, but projected size follows a predictable envelope.
    var pose_progress: float = progress * progress * (3.0 - 2.0 * progress)
    var camera_relative: Transform3D = start_camera_local.interpolate_with(
        end_camera_local, pose_progress)
    camera_relative.origin = Vector3(
        target_ndc.x * depth * half_tan * aspect,
        target_ndc.y * depth * half_tan, -depth) - (
            camera_relative.basis * customize_motion_torso_local)
    # Bound the BODY's displayed width and height independently. The smaller
    # ratio prevents either projected dimension from exceeding the straight
    # interpolation of its start/end size. Two passes replace the former four
    # position-only passes, without an unbounded mid-flight scale surge.
    for fit_pass in range(2):
        var bounds: Rect2 = _customize_body_bounds_ndc(
            camera_relative, cam.fov)
        var fit_width: float = target_size.x / maxf(bounds.size.x, 0.001)
        var fit_height: float = target_size.y / maxf(bounds.size.y, 0.001)
        var uniform_fit: float = clampf(minf(fit_width, fit_height), 0.10, 3.0)
        camera_relative.basis = camera_relative.basis.scaled(
            Vector3.ONE * uniform_fit)
        bounds = _customize_body_bounds_ndc(camera_relative, cam.fov)
        var offset_ndc: Vector2 = target_ndc - bounds.get_center()
        camera_relative.origin.x += offset_ndc.x * depth * half_tan * aspect
        camera_relative.origin.y += offset_ndc.y * depth * half_tan
    sera_display_rig.global_transform = cam.global_transform * camera_relative

func _customization_entrance_arrived(final_world: Transform3D) -> void:
    if not customize_preview_active or focused_target != "CUSTOMIZE":
        return
    # The model is done at 0.14s, before the camera's 0.18s tween.
    # Keep its camera-relative endpoint tracking until the camera lands,
    # otherwise snapping to final_world mid-camera-move causes a visible jump.
    customize_motion_progress = 1.0
    if focus_tween != null and focus_tween.is_running():
        return
    customize_motion_active = false
    sera_display_rig.global_transform = final_world
    _capture_sera_silhouette(sera_display_rig)
    _update_projected_silhouettes()
    # Show the stationary effect only after SERA and the camera have reached
    # their final placement. Back still hides it in the press event.
    if customize_glow_quad != null:
        _update_customization_glow()
        customize_glow_quad.visible = true
    in_transition = false

# On Back, retract the *currently rotated* model while the camera is also
# returning to the overview. The grid does not follow the model and is hidden
# as soon as the rig is stowed.
func _begin_customization_retraction() -> void:
    if sera_display_rig == null or sera_display_stand == null:
        _restore_customization_preview()
        return
    if customize_entrance_tween != null and customize_entrance_tween.is_running():
        customize_entrance_tween.kill()
    var initial_world: Transform3D = sera_display_rig.global_transform
    var stowed_world: Transform3D = sera_display_stand.global_transform * sera_original_transform
    # The camera ends at the overview pose. Build both local endpoints
    # before either Tween advances, then keep the model visible as it shrinks.
    var start_camera_local: Transform3D = (
        cam.global_transform.affine_inverse() * initial_world)
    var overview_camera_world: Transform3D = global_transform * overview_pose
    var stowed_camera_local: Transform3D = (
        overview_camera_world.affine_inverse() * stowed_world)
    customize_touch_id = -1
    customize_mouse_drag = false
    _prepare_customization_motion(start_camera_local, stowed_camera_local,
        cam.fov, overview_fov)
    customize_entrance_tween = create_tween()
    customize_entrance_tween.set_trans(Tween.TRANS_LINEAR)
    customize_entrance_tween.tween_method(_apply_customization_entrance.bind(
        start_camera_local, stowed_camera_local,
        cam.fov, overview_fov), 0.0, 1.0,
        CUSTOMIZE_RETRACTION_SECONDS)
    customize_entrance_tween.finished.connect(_customization_retraction_arrived)

func _customization_retraction_arrived() -> void:
    if not customize_preview_active or focused_target != "CUSTOMIZE":
        return
    # Let the 0.14s retraction reach its camera-relative endpoint and track
    # the camera until 0.18s. Do not restore the world-space display rig early.
    customize_motion_progress = 1.0
    if focus_tween == null or not focus_tween.is_running():
        _restore_customization_preview()
        _overview_arrived()

func _restore_customization_preview() -> void:
    customize_motion_active = false
    customize_touch_id = -1
    customize_mouse_drag = false
    if customize_entrance_tween != null and customize_entrance_tween.is_running():
        customize_entrance_tween.kill()
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
    var frame: Rect2 = _customize_model_area(size)
    var left_limit: float = frame.position.x
    var right_limit: float = frame.end.x
    var top_limit: float = frame.position.y
    var bottom_limit: float = frame.end.y
    var allowed_width: float = maxf(1.0, right_limit - left_limit)
    var allowed_height: float = maxf(1.0, bottom_limit - top_limit)
    var center_target_x: float = (left_limit + right_limit) * 0.5
    # Fit the authored front-facing SERA into the upper-left viewing region.
    # Keep the initial full-body scale/pivot fixed during subsequent drag yaw.
    var target_width: float = minf(size.x * CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO,
        allowed_width * 0.97)

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
        var error := Vector2(
            center_target_x - (rect.position.x + rect.size.x * 0.5),
            bottom_limit - CUSTOMIZE_BOTTOM_GAP_PIXELS - rect.end.y)
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
    var frame: Rect2 = _customize_model_area(size)
    var left_limit: float = frame.position.x
    var right_limit: float = frame.end.x
    var top_limit: float = frame.position.y
    var bottom_limit: float = frame.end.y
    var allowed_width: float = maxf(1.0, right_limit - left_limit)
    var allowed_height: float = maxf(1.0, bottom_limit - top_limit)
    var center_target_x: float = (left_limit + right_limit) * 0.5

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
        var error := Vector2(
            center_target_x - (rect.position.x + rect.size.x * 0.5),
            bottom_limit - CUSTOMIZE_BOTTOM_GAP_PIXELS - rect.end.y)
        customize_preview_position.x += error.x / px_per_world
        customize_preview_position.y -= error.y / px_per_world
        _apply_customization_preview_transform()
    _capture_sera_silhouette(sera_display_rig)

func _is_customization_drag_zone(pixel: Vector2) -> bool:
    if focused_target != "CUSTOMIZE" or not customize_preview_active or hud == null:
        return false
    if not Rect2(Vector2.ZERO, hud.size).has_point(pixel):
        return false
    # All of the gameplay viewport accepts rotation except the complete
    # left menu panel and the bottom-right Back button, at any vertical height.
    if focus_panel.visible and Rect2(focus_panel.position, focus_panel.size).has_point(pixel):
        return false
    if customize_right_panel.visible and Rect2(
            customize_right_panel.position, customize_right_panel.size).has_point(pixel):
        return false
    if back_panel.visible and Rect2(back_panel.position, back_panel.size).has_point(pixel):
        return false
    return true

func _rotate_customization_preview(delta_x: float) -> void:
    if not customize_preview_active or sera_display_rig == null:
        return
    if absf(delta_x) < 0.001:
        return
    var yaw_delta := delta_x / maxf(hud.size.x, 1.0) * CUSTOMIZE_DRAG_FULL_TURN
    customize_preview_yaw = wrapf(customize_preview_yaw - yaw_delta, -PI, PI)
    # Only rotate around the default fitted location, never scale/recenter.
    # The frozen radial backdrop and its grid must not move with SERA.
    _apply_customization_preview_transform()
    _capture_sera_silhouette(sera_display_rig)
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
        if focused_target != "SYSTEM" or not _cancel_system_confirmation():
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
            if _is_customization_drag_zone(event.position):
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
        if _is_customization_drag_zone(event.position):
            _rotate_customization_preview(event.position.x - customize_mouse_last_x)
        customize_mouse_last_x = event.position.x
        get_viewport().set_input_as_handled()

func _tap_at(point: Vector2) -> void:
    if not focused_target.is_empty():
        if Rect2(back_panel.position, back_panel.size).has_point(point):
            if focused_target != "SYSTEM" or not _cancel_system_confirmation():
                _return_to_overview()
        elif focused_target == "SYSTEM" and focus_panel.visible:
            _tap_system_control(point)
        elif focused_target == "DATA ARCHIVE" and focus_panel.visible:
            _tap_archive_record(point)
        elif focused_target == "CUSTOMIZE" and customize_right_panel.visible:
            _tap_equipment_control(point)
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
    if target_name == "CUSTOMIZE":
        # The model needs its fitted target in the *destination* camera frame.
        # Temporarily use that frame only for geometry calculations, then
        # restore the real camera before either Tween starts this same tap.
        var previous_camera_pose: Transform3D = cam.transform
        var previous_camera_fov: float = cam.fov
        customize_transition_start_camera_pose = cam.global_transform
        customize_transition_start_camera_fov = previous_camera_fov
        cam.transform = aim_pose
        cam.fov = float(view["fov"])
        _show_customization_preview()
        cam.transform = previous_camera_pose
        cam.fov = previous_camera_fov
        _update_projected_silhouettes()
    _move_camera(aim_pose, float(view["fov"]), _focus_arrived.bind(target_name))

func _focus_arrived(target_name: String) -> void:
    if focused_target != target_name:
        return
    # Either tween may finish first. Finalize the CUSTOMIZE model and reveal
    # the backdrop only after BOTH are finished, not at the early 0.14s mark.
    if target_name == "CUSTOMIZE" and customize_preview_active:
        if customize_entrance_tween == null or not customize_entrance_tween.is_running():
            _customization_entrance_arrived(customize_preview_final_world)
    else:
        in_transition = false
    back_panel.visible = true
    focus_title.text = target_name
    # SYSTEM edits save files; DATA ARCHIVE displays read-only records.
    _set_system_visible(target_name == "SYSTEM")
    _set_archive_records_visible(target_name == "DATA ARCHIVE")
    if target_name == "DATA ARCHIVE":
        archive_record_tab = 0
        _refresh_archive_records()
    if target_name == "SYSTEM":
        system_pending_action = ""
        system_pending_slot = 0
        _reset_system_confirmation_blink()
        system_message = ""
        _refresh_system_controls()
    action_label.text = "ENTER TRAINING" if target_name == "TRAINING" else ""
    action_panel.visible = target_name == "TRAINING"
    _layout_hud()
    focus_panel.visible = true
    customize_right_panel.visible = target_name == "CUSTOMIZE"
    if target_name == "CUSTOMIZE":
        _refresh_equipment_controls()

func _return_to_overview() -> void:
    if in_transition or focused_target.is_empty():
        return
    # Back immediately ends the bright selection, before camera return.
    outline.set("active_target", "")
    outline.queue_redraw()
    # Remove BOTH the cyan halo and its cyber grid on the Back press itself,
    # before either the model or camera Tween gets its first frame.
    if focused_target == "CUSTOMIZE" and customize_glow_quad != null:
        customize_glow_quad.visible = false
    in_transition = true
    focus_panel.visible = false
    customize_right_panel.visible = false
    _set_system_visible(false)
    _set_archive_records_visible(false)
    system_pending_action = ""
    system_pending_slot = 0
    _reset_system_confirmation_blink()
    back_panel.visible = false
    if focused_target == "CUSTOMIZE" and customize_preview_active:
        # Both movements begin on the same Back-button press.
        _begin_customization_retraction()
        _move_camera(overview_pose, overview_fov, _overview_arrived)
    else:
        _restore_customization_preview()
        _move_camera(overview_pose, overview_fov, _overview_arrived)

func _overview_arrived() -> void:
    # The SERA retraction now finishes at 0.14s; keep its model aligned to the
    # moving camera until 0.18s. Only then restore the exact stand transform.
    if focused_target == "CUSTOMIZE" and customize_preview_active:
        if customize_entrance_tween != null and customize_entrance_tween.is_running():
            return
        _restore_customization_preview()
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
    # Model Tween typically executes first. Reproject after camera movement
    # so the torso cannot lag one camera frame and bend the perceived path.
    if customize_motion_active and customize_preview_active:
        _apply_customization_entrance(customize_motion_progress,
            customize_motion_start_local, customize_motion_end_local,
            customize_motion_start_fov, customize_motion_end_fov)
    _update_projected_silhouettes()

func _start_training() -> void:
    if focused_target != "TRAINING" or in_transition:
        return
    var err: Error = get_tree().change_scene_to_file(TRAINING_SCENE)
    if err != OK:
        push_error("Nexus training scene load failed (%d)" % err)
