extends Node3D
# v147: move exhibition SERA twice as fast (0.14 s) and finalize only after concurrent camera arrival.
# Preserve v127 kiosk/occlusion, v125 touch navigation and v124 Blockbench geometry.
const Modules = preload("res://assets/base_command_modules.gd")
const SeraRig = preload("res://scripts/sera_rig.gd")
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
const LiveMeshEdges = preload("res://scripts/sera_nexus_live_mesh_edges.gd")
const DepthHullOutline = preload(
    "res://scripts/sera_nexus_depth_hull_outline.gd")
const StencilHull = preload("res://scripts/sera_nexus_stencil_hull.gd")
const SharedMaterialShading = preload("res://scripts/sera_fullbody_material_preview.gd")
const VersionIndicator = preload("res://scripts/version_indicator.gd")
const TrainingDefaults = preload("res://scripts/training_defaults.gd")
const IconAtlas = preload("res://scripts/sera_item_icons.gd")
const PrototypeCatalog = preload("res://scripts/sera_prototype_catalog.gd")
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const EquipmentStatRows = preload("res://scripts/sera_nexus_stat_rows.gd")
const LaboStats = preload("res://scripts/sera_labo_stats.gd")
const StatUI = preload("res://scripts/sera_status_column_ui.gd")
const PreviewRim = preload("res://scripts/sera_tech_preview_frame.gd")
const CraftAffixes = preload("res://scripts/sera_craft_affixes.gd")
const PartViewer = preload("res://scripts/sera_part_preview_widget.gd")
const RotateMark = preload("res://scripts/sera_rotatable_mark.gd")
const CONTROL_SETTINGS_FILE: String = "user://sera_settings.cfg"
const FrameRateSettings = preload("res://scripts/sera_frame_rate_settings.gd")
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const DisplayProfile = preload("res://scripts/sera_display_profile.gd")
const NexusSelectionOutline = preload("res://scripts/nexus_selection_outline.gd")
const CUSTOMIZE_BACKDROP_SHADER = preload("res://shaders/nexus_customize_radial_glow.gdshader")
const NEXUS_EDGE_SHADER = preload("res://shaders/nexus_polygon_edges.gdshader")
const NEXUS_EDGE_WIDTH_PIXELS: float = 2.0
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")

const GATE_ORIGIN: Vector3 = Vector3(4.00, 0.02, -10.48)
const SERA_STAGE_ORIGIN: Vector3 = Vector3(0.0, 0.0, -4.75)

var batch_data: Dictionary = {}
var hud: Control
var cam: Camera3D
var outline: Control
var overview_pose: Transform3D
var overview_fov: float = 63.0
var _display_height_factor: float = 1.0
var focus_tween: Tween
var focused_target: String = ""
var in_transition: bool = false
var back_panel: Panel
var back_arrow: Label
var explore_panel: Panel
var explore_label: Label
var focus_panel: Panel
var focus_header: Panel
var focus_title: Label
var customize_right_panel: Panel
var customize_right_header: Panel
var customize_equipment_header: Label
var customize_equipment_rows: Dictionary = {}
var customize_stats_panel: Panel
var customize_total_title: Label
var customize_stats_scroll: ScrollContainer
var customize_stats_grid: GridContainer
var customize_weapon_divider: ColorRect
var customize_weapon_first_index: int = -1
var customize_part_stats_panel: Panel
var customize_part_stats_header: Label
var customize_part_stats_name: Label
var customize_part_stats_scroll: ScrollContainer
var customize_part_stats_list: GridContainer
var customize_part_stat_cells: Array[Dictionary] = []
var customize_stat_cells: Array[Dictionary] = []
var customize_total_column_rules: Array[ColorRect] = []
var customize_part_column_rules: Array[ColorRect] = []
var customize_total_accents: Array[ColorRect] = []
var customize_part_accents: Array[ColorRect] = []
var customize_part_preview_frame: Control
var customize_single_part_preview: Control
var customize_part_preview_fullscreen_layer: Panel
var customize_part_preview_fullscreen_active: bool = false
var customize_body_rotate_cue: Control
# NEXUS-only, opt-in diagnostic for the active same-frame GPU contours.
# Unlike the removed ID-mask probe, this operates on the actual SERA mesh.
const OUTLINE_DIAGNOSTIC_MODES: Array[String] = [
    "通常 (深度ハル)", "深度ハル外周", "全エッジ", "開放境界", "接合線", "深度無視",
    "対象メッシュ", "マスク表示", "ハル単独", "深度ハル強調",
    "立方体＝", "立方体≠", "全身＝", "面反転",
    "法線＋8px", "法線－8px", "深度なし全エッジ",
    "17一致", "書込停止≠17"
]
const OUTLINE_DIAGNOSTIC_EXPLAINS: Array[String] = [
    "平滑化ハルをGPU深度テストで描画。ステンシルなし、外周3px。",
    "青緑: 本番の深度テスト付き反転ハルの外周を強調表示。",
    "黄: 生成済みの全エッジ。視点による非表示を解除。",
    "橙: 開放境界のみ。閉じた装甲には通常ありません。",
    "紫: メッシュ同士の交差から生成した接合線のみ。",
    "青緑/橙/紫: 深度判定を外し、遮蔽を切り分けます。",
    "緑: 輪郭へ登録した表示中のメッシュを着色。",
    "橙: ステンシル書込みパスを着色。描画確認用。",
    "紫: マスクなしの反転ハル。面の破綻を確認。",
    "青緑: 平滑化反転ハル＋GPU深度遮蔽の合成を確認。",
    "立方体: 書込29に一致する部分が緑なら成功候補。",
    "立方体: 29と異なる外周が紫、中心は抜けるはず。",
    "全身: ステンシル17と一致する領域を緑で表示。",
    "橙: カリングを逆転。紫のハル単独と比較。",
    "桃: 法線＋8px。青緑の元輪郭より外に出るか確認。",
    "黄: 法線－8px。青緑の元輪郭より外に出るか確認。",
    "青緑: 診断用の全エッジを表示。深度・面向き判定なし。",
    "緑: 旧ステンシル診断。書込みONで参照17一致画素を表示。",
    "紫: 旧ステンシル診断。書込みOFFで参照17不一致画素を表示。"
]
var outline_debug_button: Panel
var outline_debug_button_text: Label
var outline_debug_panel: Panel
var outline_debug_mode_buttons: Array[Panel] = []
var outline_debug_mode_labels: Array[Label] = []
var outline_debug_mode: int = 0
var outline_debug_stats: Label
var outline_debug_hint: Label
var outline_debug_enabled: bool = false
var outline_debug_elapsed: float = 0.0
var customize_part_preview_slot: String = "head"
# One shared, depth-tested glow for only the visible mesh of the inspected slot.
# Never modify the source mesh/material or the training SeraRig.
var customize_selection_material: StandardMaterial3D
var customize_highlighted_meshes: Array[MeshInstance3D] = []
const CUSTOMIZE_SELECTION_BLINK_PERIOD_SECONDS: float = 1.0
const CUSTOMIZE_SELECTION_BLINK_ON_RATIO: float = 0.60
var customize_selection_blink_elapsed: float = 0.0
var customize_selection_blink_on: bool = true
var customize_part_picker: Control
var customize_part_picker_window: Panel
var customize_part_picker_title: Label
var customize_part_picker_scroll: ScrollContainer
var customize_part_grid: GridContainer
var customize_part_picker_cells: Array[Dictionary] = []
var customize_picker_touch_id: int = -1
var customize_picker_start: Vector2 = Vector2.ZERO
var customize_picker_last: Vector2 = Vector2.ZERO
var customize_picker_mouse: bool = false
var customize_part_touch_id: int = -1
var customize_part_mouse_drag: bool = false
const CUSTOMIZE_SLOTS = ["head", "torso", "legs", "arms", "booster", "weapon_r", "weapon_l"]
const CUSTOMIZE_SLOT_LABELS = {
    "head": "HEAD", "torso": "TORSO", "legs": "LOWER BODY",
    "arms": "ARMS", "booster": "BOOSTER", "weapon_r": "RIGHT WEAPON", "weapon_l": "LEFT WEAPON"
}
var action_panel: Panel
var action_label: Label
var training_heading: Label
var training_footer: Label
var training_option_rows: Array[Dictionary] = []
var training_settings: Dictionary = {}
var deployment_heading: Label
var deployment_rows: Array[Dictionary] = []
var training_start_style: StyleBoxFlat
var training_start_pulse: float = 0.0
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
var system_lock_mode_row: Panel
var system_lock_mode_label: Label
var system_auto_lock_enabled: bool = true
var system_left_handed: bool = false
var system_handedness_row: Panel
var system_handedness_label: Label
var system_fps_options_open: bool = false
var system_fps_button: Panel
var system_fps_button_label: Label
var system_fps_rows: Array[Dictionary] = []
var system_fps_back_button: Panel
var system_fps_back_label: Label
var system_fps_note: Label
var system_selected_slot: int = 1
var system_pending_action: String = ""
var system_pending_slot: int = 0
var system_message: String = ""
# Blink only the CONFIRM action button, never the selected save-slot border.
const SYSTEM_CONFIRM_BLINK_HALF_SECONDS: float = 0.38
# Both blinking states stay brighter than the normal dark _menu_style().
# Returning to the normal style on cancellation is therefore unmistakable.
const SYSTEM_CONFIRM_BG_BRIGHT: Color = Color(0.14, 0.39, 0.50, 0.98)
const SYSTEM_CONFIRM_BG_DIM: Color = Color(0.075, 0.21, 0.30, 0.98)
const SYSTEM_CONFIRM_BORDER_BRIGHT: Color = Color("#e5fbff")
const SYSTEM_CONFIRM_BORDER_DIM: Color = Color("#7cd6f0")
var system_confirm_blink_elapsed: float = 0.0
var system_confirm_blink_bright: bool = true
# Reuse the same display rig, without reparenting it: SeraRig has external
# afterimage nodes whose lifetime is tied to _exit_tree. Set its world transform
# from camera space instead; no duplicate model, SubViewport or draw batch.
var sera_display_stand: Node3D
var sera_display_rig: Node3D
var sera_original_transform: Transform3D
# Exhibition-only NEXUSpose correction, not a modification to authored clips.
var nexus_arm_bones: Dictionary = {}
var nexus_arm_rest_rotations: Dictionary = {}
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
var customize_preview_active: bool = false
var customize_preview_position: Vector3 = Vector3.ZERO
var customize_preview_scale: float = 0.80
var customize_preview_fitted_scale: float = 1.40
var customize_preview_yaw: float = PI
var customize_preview_pitch: float = 0.0
var customize_touch_id: int = -1
var customize_touch_last_x: float = 0.0
var customize_touch_last_y: float = 0.0
var customize_touch_last: Vector2 = Vector2.ZERO
var customize_mouse_drag: bool = false
var customize_mouse_last_x: float = 0.0
var customize_mouse_last_y: float = 0.0
var customize_mouse_last: Vector2 = Vector2.ZERO

const CUSTOMIZE_PREVIEW_DISTANCE: float = 3.25
const CUSTOMIZE_GLOW_DEPTH_OFFSET: float = 1.80
const CUSTOMIZE_GLOW_SCREEN_WIDTH: float = 1.0
const CUSTOMIZE_GLOW_SCREEN_HEIGHT: float = 1.0
const CUSTOMIZE_GRID_SPACING_PIXELS: float = 42.0
const CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO: float = 0.435
const CUSTOMIZE_ENTRANCE_SECONDS: float = 0.14
const CUSTOMIZE_RETRACTION_SECONDS: float = 0.14
const CUSTOMIZE_BOTTOM_GAP_PIXELS: float = 10.0
const CUSTOMIZE_PREVIEW_ROTATION_SAMPLES: int = 16
const NexusArmClearance = preload("res://scripts/sera_nexus_arm_clearance.gd")
const NEXUS_POSE_NAMES: Array[String] = ["NEXUS_pose", "NEXUSpose"]
# Search outward/upward in small discrete increments, stopping at the first
# actual visible-mesh clearance. Shoulder motion is deliberately much smaller.
const NEXUS_ARM_STEP_DEGREES: float = 1.5
const NEXUS_SHOULDER_STEP_DEGREES: float = 0.2
const NEXUS_SHOULDER_MAX_DEGREES: float = 3.2
const NEXUS_ARM_MAX_STEPS: int = 16 # max upper-arm lift is 24 degrees
const NEXUS_ARM_CLEARANCE: float = 0.018
# NEXUSpose lives inside the already-loaded canonical SERA rig.
# No independent file search is necessary; exported builds use its embedded snapshot.
const CUSTOMIZE_DRAG_FULL_TURN: float = TAU

const CAMERA_TRANSITION_SECONDS: float = 0.18
const BASE_SCENE: String = "res://scenes/base_exploration.tscn"
const TRAINING_SCENE: String = "res://scenes/main.tscn"
const BITTARAN_SCENE: String = "res://scenes/bittaran_battle.tscn"
const BOSS_ENTRIES = [{"name": "ビットタラン  /  BITTARAN", "scene": BITTARAN_SCENE}]

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
    set_meta("sera_graphics_outline_category", "base")
    DisplayProfile.apply(get_window())
    FrameRateSettings.apply("base_nexus")
    # Godot 4 Android Back is a Window go-back request when auto-quit is off.
    get_window().go_back_requested.connect(_on_android_back)
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
    # Preserve the NEXUS architecture's authored 2px corners and light
    # silhouette passes while shading the actual opaque mesh surfaces.
    SharedMaterialShading.apply_to_subtree(self)
    _sera_display()
    _camera()
    # The shared depth-resolved ID viewport draws only the visible outer
    # silhouette and inter-mesh contacts. No convex edge ribbons are created.
    var id_outline := SeraViewEdges.new()
    id_outline.name = "ViewEdges"
    id_outline.set_nexus_sera_contact_mode(true)
    id_outline.set_stroke_px(2.0)
    add_child(id_outline)
    _create_customization_glow()
    _wall_mark()
    _hud()
    # The rejected 2D bounding-box contour is not created in NEXUS.
    # The new depth hull shares the real 3D scene and its current camera.
    SeraSave.mark_location("NEXUS")
    var route: String = SeraSave.requested_nexus_target
    SeraSave.requested_nexus_target = ""
    if focus_views.has(route):
        call_deferred("_select_target", route)

func _process(delta: float) -> void:
    SeraSave.record_game_time(delta)
    _refresh_outline_debug(delta)
    _update_system_confirmation_blink(delta)
    _update_training_start_pulse(delta)
    _update_customization_part_blink(delta)
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
    surface.set_meta("FX_NO_OUTLINE", true)
    var light_material := StandardMaterial3D.new()
    light_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    light_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    # The gate lightspill must blend AFTER the NEXUS's dedicated ID ink.
    light_material.render_priority = RENDER_ORDER.FACILITY_VFX_FOREGROUND
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
    # The opaque structural plates catch a tighter highlight; luminous accents stay unchanged.
    mat.metallic = 0.28 if index in [1, 2, 3] else 0.16
    mat.roughness = 0.52 if index in [1, 2, 3] else 0.70
    # Keep structural highlights restrained on mobile GL; retain original accents.
    mat.metallic_specular = 0.42 if index in [1, 2, 3] else 0.5
    if index in [5, 6, 7]:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 1.05 if index == 7 else 1.75
    return mat

# The 2px gray edges belong to static NEXUS architecture only.
# A depth-tested next pass is composited BEFORE CanvasLayer selection glows.
# No SeraRig material, mesh or animation is ever passed to this helper.
func _nexus_edge_material(geometry_mode: int = 0) -> ShaderMaterial:
    var edge := ShaderMaterial.new()
    edge.shader = NEXUS_EDGE_SHADER
    edge.render_priority = RENDER_ORDER.NEXUS_SURFACE_EDGES
    edge.set_shader_parameter("edge_tint", Color("#7e858e"))
    edge.set_shader_parameter("width_px", NEXUS_EDGE_WIDTH_PIXELS)
    edge.set_shader_parameter("geometry_mode", geometry_mode)
    return edge

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
        var material: StandardMaterial3D = _mat(index)
        # Scene-wide visible-mesh-ID contours now own ALL opaque module
        # boundaries. Do not draw the old polygon-edge next_pass on top.
        # Cyan/amber/blue emissive accents remain untouched.
        draw.material_override = material
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(draw)

func _pad_center() -> void:
    var surface := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 1.29
    cylinder.bottom_radius = 1.37
    cylinder.height = 0.16
    cylinder.radial_segments = 12
    surface.name = "NexusMaintenancePadCenter"
    surface.mesh = cylinder
    surface.position = Vector3(0.0, 0.33, -4.75)
    var pad_material: StandardMaterial3D = _mat(2)
    # The shared ID pass draws the pad silhouette without a second edge pass.
    surface.material_override = pad_material
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
    rig.set_meta("sera_graphics_outline_category", "character")
    rig.scale = Vector3.ONE * 1.35
    rig.rotation.y = PI
    stand.add_child(rig)
    # Character contours now share the exact source render frame; the room
    # still uses its existing viewport-level ID outlines independently.
    rig.set_meta("sera_skip_common_id_outline", true)
    var rig_id_outline: Node = rig.get_node_or_null("ViewEdges")
    if is_instance_valid(rig_id_outline):
        rig_id_outline.call("set_contour_enabled", false)
    # v192: reset any profile-dependent training sole lift BEFORE capturing the
    # original exhibit pose. The camera fitter owns the preview transform.
    rig.call("set_exhibition_mode", true)
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
    _remember_nexus_arm_rest_pose(rig)
    _fit_nexus_arms_to_lower_body()
    _capture_sera_silhouette(rig)
    # Reuse the existing position-welded smooth hull baker. Unlike the
    # retired stencil masks, the production hull passes the GPU depth test.
    # No separate camera, mask texture, SubViewport or per-frame CPU edges.
    var depth_hull: Node3D = DepthHullOutline.new()
    depth_hull.call("configure", rig)
    rig.add_child(depth_hull)
    # Retain the previous edge/stencil implementations for diagnostics only.
    var live_edges: Node3D = LiveMeshEdges.new()
    live_edges.call("configure", rig)
    rig.add_child(live_edges)
    var stencil_hull: Node3D = StencilHull.new()
    stencil_hull.call("configure", rig)
    rig.add_child(stencil_hull)

func _remember_nexus_arm_rest_pose(rig: Node3D) -> void:
    # Called only once, immediately AFTER applying the authored NEXUSpose.
    # Its original rotations remain the reference for every equipment swap.
    nexus_arm_bones.clear()
    nexus_arm_rest_rotations.clear()
    var arm_names := ["Shoulder_L", "Shoulder_R", "UpperArm_L", "UpperArm_R"]
    var bones: Dictionary = rig.get("bones")
    for raw_bone in bones.values():
        var bone: Node3D = raw_bone
        if arm_names.has(str(bone.name)):
            nexus_arm_bones[str(bone.name)] = bone
            nexus_arm_rest_rotations[str(bone.name)] = bone.quaternion

func _fit_nexus_arms_to_lower_body() -> void:
    if sera_display_rig == null or nexus_arm_rest_rotations.size() != 4:
        return
    # Exactly the same solver as Equipment Intake's FULL BODY viewer.
    NexusArmClearance.new().fit(sera_display_rig, nexus_arm_rest_rotations)


func _apply_nexus_pose(rig: Node3D) -> bool:
    # Reuse the actual canonical animation dictionary loaded by SeraRig.
    # Bird-specific tracks have already been merged into NEXUS_pose.
    var available: Dictionary = rig.get("animations")
    for pose_name in NEXUS_POSE_NAMES:
        if not available.has(pose_name):
            continue
        var clip: Dictionary = available[pose_name]
        if (clip.get("tracks", {}) as Dictionary).is_empty():
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
    cam.keep_aspect = Camera3D.KEEP_HEIGHT
    cam.fov = DisplayProfile.vertical_fov(63.0,
        get_viewport().get_visible_rect().size)
    add_child(cam)
    cam.look_at(Vector3(0.0, 3.00, -5.50), Vector3.UP)
    cam.current = true
    overview_pose = cam.transform
    overview_fov = cam.fov
    _display_height_factor = DisplayProfile.height_factor(
        get_viewport().get_visible_rect().size)
    get_viewport().size_changed.connect(_on_display_size_changed)

# Restore reference horizontal framing during a live display-mode switch.
func _on_display_size_changed() -> void:
    var next_factor: float = DisplayProfile.height_factor(
        get_viewport().get_visible_rect().size)
    if cam != null and not is_equal_approx(next_factor, _display_height_factor):
        cam.fov = DisplayProfile.reframe_vertical_fov(
            cam.fov, _display_height_factor, next_factor)
        overview_fov = DisplayProfile.reframe_vertical_fov(
            overview_fov, _display_height_factor, next_factor)
        if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
            cam.size *= next_factor / _display_height_factor
        _display_height_factor = next_factor
    call_deferred("_layout_hud")

func _wall_mark() -> void:
    var logo := Label3D.new()
    logo.text = "///"
    logo.font = LaboSkin.display_font()
    logo.font_size = 120
    logo.pixel_size = 0.008
    logo.modulate = Color("#a4b5d1")
    logo.position = Vector3(0.0, 6.70, -9.05)
    add_child(logo)
    var name := Label3D.new()
    name.text = "S E R A"
    name.font = LaboSkin.display_font()
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
    # The viewport-wide visible-ID ink is layer 1; all NEXUS UI should
    # remain above the ink even when both scenes draw in the same viewport.
    canvas.layer = 2
    add_child(canvas)
    hud = Control.new()
    hud.name = "NexusOverlay"
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(hud)
    # Share LABO font roles/theme without adding per-card shaders or draw passes.
    hud.theme = LaboSkin.common_theme()
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
    _create_customization_stats()
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
    _create_single_part_preview()
    _create_customization_part_stats()
    _create_customization_part_picker()
    action_panel = Panel.new()
    action_panel.name = "DestinationAction"
    action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    training_start_style = _action_style()
    action_panel.add_theme_stylebox_override("panel", training_start_style)
    focus_panel.add_child(action_panel)
    action_label = Label.new()
    action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    action_label.add_theme_font_size_override("font_size", 21)
    action_label.add_theme_color_override("font_color", Color("#ffffff"))
    action_panel.add_child(action_label)
    _create_training_controls()
    _create_deployment_controls()
    _create_system_controls()
    _create_archive_records()
    explore_panel = Panel.new()
    explore_panel.name = "ExitToBase"
    explore_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    explore_panel.add_theme_stylebox_override("panel", _menu_style())
    hud.add_child(explore_panel)
    explore_label = Label.new()
    explore_label.text = "EXIT TO BASE"
    explore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    explore_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    explore_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    explore_label.add_theme_font_size_override("font_size", 19)
    explore_label.add_theme_color_override("font_color", Color("#ddfaff"))
    explore_panel.add_child(explore_label)
    _apply_labo_typography()
    _refresh_customization_stats()
    _create_outline_debug()
    VersionIndicator.attach(hud)
    hud.resized.connect(_layout_hud)
    _layout_hud()
    _update_projected_silhouettes()

# TRAINING target defaults are global preferences, not save-slot equipment data.
# The touch hit zones use the same raw screen input as the other NEXUS menus.
func _create_training_controls() -> void:
    training_settings = TrainingDefaults.load_defaults()
    training_heading = Label.new()
    training_heading.name = "TrainingDefaultsHeading"
    training_heading.text = "TARGET DEFAULTS  /  TAP TO CHANGE"
    training_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    training_heading.add_theme_font_size_override("font_size", 14)
    training_heading.add_theme_color_override("font_color", Color("#bdeaff"))
    training_heading.visible = false
    focus_panel.add_child(training_heading)
    for option_name in ["TARGET MOTION", "AUTO ATTACK", "ATTACK TYPE"]:
        var row := Panel.new()
        row.name = "Training" + option_name.replace(" ", "")
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_stylebox_override("panel", LaboSkin.card_style("normal"))
        row.visible = false
        focus_panel.add_child(row)
        var caption := Label.new()
        caption.text = option_name
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        caption.add_theme_font_size_override("font_size", 13)
        caption.add_theme_color_override("font_color", Color("#8fbbcf"))
        row.add_child(caption)
        var value := Label.new()
        value.mouse_filter = Control.MOUSE_FILTER_IGNORE
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        value.add_theme_font_size_override("font_size", 19)
        value.add_theme_color_override("font_color", Color("#e4faff"))
        row.add_child(value)
        training_option_rows.append({"panel": row, "label": caption, "value": value})
    training_footer = Label.new()
    training_footer.name = "TrainingDefaultsSaved"
    training_footer.text = "SAVED AUTOMATICALLY"
    training_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    training_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    training_footer.add_theme_font_size_override("font_size", 12)
    training_footer.add_theme_color_override("font_color", Color("#8bc9da"))
    training_footer.visible = false
    focus_panel.add_child(training_footer)
    _refresh_training_controls()

## Touch-only deployment catalog, isolated from TRAINING destination defaults.
func _create_deployment_controls() -> void:
    deployment_heading = Label.new()
    deployment_heading.name = "DeploymentSelectBoss"
    deployment_heading.text = "SELECT BOSS  /  TAP NAME TO SORTIE"
    deployment_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    deployment_heading.add_theme_font_size_override("font_size", 14)
    deployment_heading.add_theme_color_override("font_color", Color("#bdeaff"))
    deployment_heading.visible = false
    focus_panel.add_child(deployment_heading)
    for entry in BOSS_ENTRIES:
        var row := Panel.new()
        row.name = "BossEntry"
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_theme_stylebox_override("panel", LaboSkin.card_style("selected"))
        row.visible = false
        focus_panel.add_child(row)
        var name_label := Label.new()
        name_label.name = "BossName"
        name_label.text = str(entry["name"])
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        name_label.add_theme_font_size_override("font_size", 21)
        name_label.add_theme_color_override("font_color", Color("#e4faff"))
        row.add_child(name_label)
        deployment_rows.append({"row": row, "label": name_label,
            "scene": str(entry["scene"])})

func _set_deployment_visible(show: bool) -> void:
    if deployment_heading != null:
        deployment_heading.visible = show
    for entry in deployment_rows:
        (entry["row"] as Panel).visible = show

func _layout_deployment_controls() -> void:
    if deployment_heading == null:
        return
    var width: float = maxf(10.0, focus_panel.size.x - 32.0)
    deployment_heading.position = Vector2(16.0, focus_header.size.y + 18.0)
    deployment_heading.size = Vector2(width, 36.0)
    for i in range(deployment_rows.size()):
        var row: Panel = deployment_rows[i]["row"]
        row.position = Vector2(16.0, focus_header.size.y + 72.0 + float(i) * 90.0)
        row.size = Vector2(width, 72.0)
        var label: Label = deployment_rows[i]["label"]
        label.position = Vector2.ZERO
        label.size = row.size
        label.add_theme_font_size_override("font_size",
            17 if focus_panel.size.x < 280.0 else 21)

func _tap_deployment_boss(point: Vector2) -> void:
    var local: Vector2 = point - focus_panel.position
    for entry in deployment_rows:
        var row: Panel = entry["row"]
        if Rect2(row.position, row.size).has_point(local):
            _start_boss_scene(str(entry["scene"]))
            return

func _start_boss_scene(scene_path: String) -> void:
    if focused_target != "DEPLOYMENT" or in_transition:
        return
    var err: Error = get_tree().change_scene_to_file(scene_path)
    if err != OK:
        push_error("Bittaran battle scene load failed (%d)" % err)

func _set_training_visible(show: bool) -> void:
    training_heading.visible = show
    training_footer.visible = show
    for entry in training_option_rows:
        var panel: Panel = entry["panel"]
        panel.visible = show

func _layout_training_controls() -> void:
    if training_heading == null:
        return
    var margin: float = 16.0
    var content_width: float = maxf(10.0, focus_panel.size.x - margin * 2.0)
    training_heading.position = Vector2(margin, focus_header.size.y + 12.0)
    training_heading.size = Vector2(content_width, 23.0)
    var top: float = focus_header.size.y + 44.0
    var bottom: float = action_panel.position.y - 18.0
    var gap: float = 9.0
    var height: float = clampf((bottom - top - gap * 2.0) / 3.0, 35.0, 72.0)
    for i in range(training_option_rows.size()):
        var entry: Dictionary = training_option_rows[i]
        var row: Panel = entry["panel"]
        row.position = Vector2(margin, top + float(i) * (height + gap))
        row.size = Vector2(content_width, height)
        var caption: Label = entry["label"]
        caption.position = Vector2(12.0, 0.0)
        caption.size = Vector2(row.size.x - 24.0, row.size.y * 0.48)
        var value: Label = entry["value"]
        value.position = Vector2(12.0, row.size.y * 0.40)
        value.size = Vector2(row.size.x - 24.0, row.size.y * 0.56)
    training_footer.position = Vector2(margin, action_panel.position.y - 18.0)
    training_footer.size = Vector2(content_width, 15.0)

func _refresh_training_controls() -> void:
    if training_option_rows.size() != 3:
        return
    var motion: Label = training_option_rows[0]["value"]
    motion.text = "MOVE  >" if bool(training_settings.get("move_enabled", true)) else "HOLD  >"
    var auto_attack: Label = training_option_rows[1]["value"]
    auto_attack.text = "ON  >" if bool(training_settings.get("auto_fire_enabled", true)) else "OFF  >"
    var attack_type: int = clampi(int(training_settings.get("attack_type", 0)), 0, 3)
    var attack: Label = training_option_rows[2]["value"]
    attack.text = ["AIM", "LEAD", "SHOCK", "ARC"][attack_type] + "  >"

func _tap_training_control(point: Vector2) -> bool:
    var local: Vector2 = point - focus_panel.position
    for i in range(training_option_rows.size()):
        var row: Panel = training_option_rows[i]["panel"]
        if not Rect2(row.position, row.size).has_point(local):
            continue
        match i:
            0:
                training_settings["move_enabled"] = not bool(training_settings.get("move_enabled", true))
            1:
                training_settings["auto_fire_enabled"] = not bool(training_settings.get("auto_fire_enabled", true))
            2:
                training_settings["attack_type"] = (int(training_settings.get("attack_type", 0)) + 1) % 4
        var err: Error = TrainingDefaults.save_defaults(training_settings)
        if err != OK:
            push_error("Training defaults save failed (%d)" % err)
        _refresh_training_controls()
        return true
    return false

func _update_training_start_pulse(delta: float) -> void:
    if focused_target != "TRAINING" or in_transition or not action_panel.visible:
        return
    training_start_pulse = fposmod(training_start_pulse + delta, 1.8)
    var wave: float = 0.5 + 0.5 * sin(training_start_pulse * TAU / 1.8)
    training_start_style.bg_color = Color(0.12, 0.27 + wave * 0.025,
        0.31 + wave * 0.035, 1.0)
    training_start_style.border_color = Color(0.46 + wave * 0.13,
        0.76 + wave * 0.12, 0.82 + wave * 0.11, 1.0)

## Hit zones are handled by _input, matching the existing Android raw-touch UI.
## These labels are not Control buttons and therefore never steal preview drags.

# Read-only equipment statistics occupy the existing lower-left CUSTOMIZE
# square. Reusing twenty stat cells keeps selection changes allocation-free.
func _create_customization_stats() -> void:
    customize_stats_panel = Panel.new()
    customize_stats_panel.name = "CustomizeTotalStatsPanel"
    customize_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_stats_panel.add_theme_stylebox_override(
        "panel", StatUI.status_window_style())
    customize_total_accents = StatUI.attach_status_marks(customize_stats_panel)
    customize_weapon_divider = ColorRect.new()
    customize_weapon_divider.name = "CustomizeWeaponStatDivider"
    customize_weapon_divider.color = Color("#55798a")
    customize_weapon_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_weapon_divider.visible = false
    customize_stats_panel.add_child(customize_weapon_divider)
    customize_stats_panel.visible = false
    hud.add_child(customize_stats_panel)
    var total_bar := Panel.new()
    total_bar.name = "CustomizeTotalStatsHeader"
    total_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    total_bar.add_theme_stylebox_override("panel", _menu_header_style())
    customize_stats_panel.add_child(total_bar)
    customize_total_title = Label.new()
    customize_total_title.name = "CustomizeTotalStatsTitle"
    customize_total_title.text = ""
    customize_total_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    customize_total_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_total_title.add_theme_font_override("font", LaboSkin.tracked_display_font())
    customize_total_title.add_theme_font_size_override("font_size", 20)
    customize_total_title.add_theme_color_override("font_color", Color("#d7e6ed"))
    total_bar.add_child(customize_total_title)
    total_bar.visible = false
    for col in range(2):
        customize_total_column_rules.append(StatUI.new_column_rule(
            customize_stats_panel, "CustomizeTotalColumnDivider_%d" % col))
    customize_stats_scroll = ScrollContainer.new()
    customize_stats_scroll.name = "CustomizeEquipmentStatsScroll"
    customize_stats_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    customize_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    customize_stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    customize_stats_scroll.visible = false
    customize_stats_scroll.get_v_scroll_bar().value_changed.connect(
        _update_customization_weapon_divider)
    # Total combat stats belong ABOVE the SERA and the right-hand part menu.
    hud.add_child(customize_stats_scroll)
    customize_stats_grid = GridContainer.new()
    customize_stats_grid.name = "CustomizeEquipmentStatsGrid"
    customize_stats_grid.columns = 3
    customize_stats_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    customize_stats_grid.add_theme_constant_override("h_separation", 9)
    customize_stats_grid.add_theme_constant_override("v_separation", 1)
    customize_stats_scroll.add_child(customize_stats_grid)
    for i in range(24):
        var cell := Panel.new()
        cell.name = "EquipmentStat_" + str(i)
        cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
        style.set_corner_radius_all(0)
        cell.add_theme_stylebox_override("panel", style)
        StatUI.clear_cell_background(cell)
        cell.visible = false
        customize_stats_grid.add_child(cell)
        var name_label := Label.new()
        name_label.name = "StatName"
        name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        name_label.clip_text = true
        name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        cell.add_child(name_label)
        var value_label := Label.new()
        value_label.name = "StatValue"
        value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        value_label.clip_text = true
        value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        cell.add_child(value_label)
        var rule := ColorRect.new()
        rule.name = "StatColumnRule"
        rule.color = Color("#55798a")
        rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
        cell.add_child(rule)
        customize_stat_cells.append({
            "panel": cell, "name": name_label, "value": value_label,
            "rule": rule
        })


func _layout_customization_stats() -> void:
    if customize_stats_scroll == null or hud == null:
        return
    var show: bool = focused_target == "CUSTOMIZE"
    customize_stats_panel.visible = show
    customize_stats_scroll.visible = show
    var view: Vector2 = hud.size
    var width: float = maxf(180.0, view.x * 0.93)
    var left: float = (view.x - width) * 0.5
    var top: float = maxf(20.0, view.y * 0.025)
    var height: float = minf(view.y * 0.227, 290.0)
    customize_stats_panel.position = Vector2(left, top)
    customize_stats_panel.size = Vector2(width, height)
    StatUI.layout_status_marks(customize_total_accents, customize_stats_panel.size)
    var heading: Panel = customize_stats_panel.get_node(
        "CustomizeTotalStatsHeader") as Panel
    heading.position = Vector2.ZERO
    heading.size = Vector2(width, 0.0)
    heading.visible = false
    customize_total_title.position = Vector2.ZERO
    customize_total_title.size = Vector2.ZERO
    var inner_width: float = maxf(160.0, width - 20.0)
    var columns: int = 3 if inner_width >= 590.0 else (2 if inner_width >= 370.0 else 1)
    customize_stats_grid.columns = columns
    customize_stats_scroll.position = Vector2(left + 10.0, top + 8.0)
    customize_stats_scroll.size = Vector2(inner_width, height - 16.0)
    StatUI.layout_column_rules(customize_total_column_rules,
        Rect2(Vector2(10, 7), Vector2(inner_width, height - 14)), columns)
    var cell_width: float = floorf(
        (inner_width - 9.0 * float(columns - 1)) / float(columns))
    var cell_height: float = 44.0
    _update_customization_weapon_divider()
    for i in range(customize_stat_cells.size()):
        var entry: Dictionary = customize_stat_cells[i]
        var cell: Panel = entry["panel"]
        cell.custom_minimum_size = Vector2(cell_width, cell_height)
        var label: Label = entry["name"]
        var value: Label = entry["value"]
        StatUI.layout_metric_pair(label, value, cell_width, cell_height, 19, 25, 16, 20)
        (entry["rule"] as ColorRect).visible = false

func _update_customization_weapon_divider(_scroll_value: float = 0.0) -> void:
    if customize_weapon_divider == null or customize_stats_grid == null or (
            customize_stats_scroll == null or customize_stats_panel == null):
        return
    var weapon_first: int = customize_weapon_first_index
    var columns: int = maxi(1, customize_stats_grid.columns)
    var body_rows: int = ceili(float(maxi(0, weapon_first)) / float(columns))
    var line_y: float = 8.0 + float(body_rows) * 45.0 - 1.0 - (
        float(customize_stats_scroll.scroll_vertical))
    customize_weapon_divider.visible = (
        customize_stats_panel.visible and weapon_first >= 0 and
        line_y > 8.0 and line_y < customize_stats_panel.size.y - 8.0)
    customize_weapon_divider.position = Vector2(14.0, line_y)
    customize_weapon_divider.size = Vector2(
        maxf(30.0, customize_stats_panel.size.x - 28.0), 2.0)


func _refresh_customization_stats() -> void:
    if customize_stats_grid == null:
        return
    var selected: Dictionary = _current_system_equipment()
    var entries: Array[Dictionary] = EquipmentStatRows.from_selection(selected)
    customize_weapon_first_index = -1
    for row_index in range(entries.size()):
        if str(entries[row_index].get("group", "")) == "weapon":
            customize_weapon_first_index = row_index
            break
    var columns: int = maxi(1, customize_stats_grid.columns)
    for i in range(customize_stat_cells.size()):
        var cell: Dictionary = customize_stat_cells[i]
        var show: bool = i < entries.size()
        (cell["panel"] as Panel).visible = show
        (cell["rule"] as ColorRect).visible = false
        if show:
            (cell["name"] as Label).text = str(entries[i]["label"])
            (cell["value"] as Label).text = str(entries[i]["value"])
            var row: Panel = cell["panel"] as Panel
            StatUI.layout_metric_pair(
                cell["name"] as Label, cell["value"] as Label,
                row.custom_minimum_size.x, 44.0, 19, 25, 16, 20)
    _layout_customization_stats()


func _create_equipment_controls() -> void:
    customize_equipment_header = Label.new()
    customize_equipment_header.text = ""
    customize_equipment_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_equipment_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    customize_equipment_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    customize_right_header.add_child(customize_equipment_header)
    # Each row is ONLY the installed part's name, not a model-set selector.
    for slot in CUSTOMIZE_SLOTS:
        var button := Button.new()
        button.name = "Equipment_" + slot
        button.text = ""
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.clip_contents = true
        button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        # Reserve the full right-hand hit area for a distinct thumbnail control.
        # Duplication keeps the shared LABO StyleBox cache untouched.
        var row_normal: StyleBoxFlat = (
            LaboSkin.terminal_segment_style("normal").duplicate(true) as StyleBoxFlat)
        row_normal.content_margin_left = 17.0
        row_normal.content_margin_right = 64.0
        var row_active: StyleBoxFlat = (
            LaboSkin.terminal_segment_style("selected").duplicate(true) as StyleBoxFlat)
        row_active.content_margin_left = 17.0
        row_active.content_margin_right = 64.0
        row_active.bg_color = Color("#2b596b")
        row_active.border_color = Color("#adeeff")
        row_active.border_width_top = 2
        row_active.border_width_left = 2
        row_active.border_width_right = 2
        button.add_theme_stylebox_override("normal", row_normal)
        button.add_theme_stylebox_override("hover", row_active)
        button.add_theme_stylebox_override("pressed", row_active)
        button.add_theme_color_override("font_color", Color("#e2eef2"))
        customize_right_panel.add_child(button)
        var expand := Button.new()
        expand.name = "EquipmentThumbnailExpand"
        expand.text = ""
        expand.focus_mode = Control.FOCUS_NONE
        # NEXUS dispatches raw touch/mouse events; the visual Button must not
        # consume gestures before _tap_equipment_control receives coordinates.
        expand.mouse_filter = Control.MOUSE_FILTER_IGNORE
        expand.add_theme_stylebox_override(
            "normal", LaboSkin.terminal_segment_style("normal"))
        expand.add_theme_stylebox_override(
            "hover", LaboSkin.terminal_segment_style("selected"))
        expand.add_theme_stylebox_override(
            "pressed", LaboSkin.terminal_segment_style("selected"))
        button.add_child(expand)
        # Four matte vector tiles: a thumbnail-grid icon with no missing glyph,
        # texture allocation, glow, or extra SubViewport.
        for tile_index in range(4):
            var tile := ColorRect.new()
            tile.name = "ThumbnailTile_" + str(tile_index)
            tile.color = Color("#9fd7e6") if tile_index == 0 else Color("#55798a")
            tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
            expand.add_child(tile)
        var underline := ColorRect.new()
        underline.name = "EquipmentNameUnderline"
        underline.color = Color("#55798a")
        underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
        underline.size = Vector2(0.0, 1.0)
        button.add_child(underline)
        customize_equipment_rows[slot] = {
            "panel": button, "expand": expand, "underline": underline,
            "normal_style": row_normal, "selected_style": row_active
        }
    _refresh_equipment_controls()


func _layout_equipment_controls() -> void:
    if customize_equipment_header == null or customize_right_panel == null:
        return
    customize_equipment_header.position = Vector2.ZERO
    customize_equipment_header.size = customize_right_header.size
    var top: float = 9.0
    var available: float = customize_right_panel.size.y - top - 8.0
    var row_pitch: float = maxf(41.0, available / float(CUSTOMIZE_SLOTS.size()))
    for i in range(CUSTOMIZE_SLOTS.size()):
        var slot: String = CUSTOMIZE_SLOTS[i]
        var button: Button = customize_equipment_rows[slot]["panel"]
        button.position = Vector2(9.0, top + float(i) * row_pitch)
        button.size = Vector2(maxf(68.0, customize_right_panel.size.x - 18.0),
            maxf(37.0, row_pitch - 5.0))
        var expand: Button = customize_equipment_rows[slot]["expand"]
        var expand_side: float = clampf(button.size.y - 14.0, 32.0, 48.0)
        expand.size = Vector2(expand_side, expand_side)
        expand.position = Vector2(button.size.x - expand_side - 9.0,
            floorf((button.size.y - expand_side) * 0.5))
        var tile_side: float = clampf(floorf(expand_side * 0.18), 5.0, 8.0)
        var tile_gap: float = 4.0
        var grid_start: float = floorf(
            (expand_side - tile_side * 2.0 - tile_gap) * 0.5)
        for tile_index in range(4):
            var tile: ColorRect = expand.get_child(tile_index) as ColorRect
            tile.position = Vector2(
                grid_start + float(tile_index % 2) * (tile_side + tile_gap),
                grid_start + float(floori(float(tile_index) / 2.0)) * (
                    tile_side + tile_gap))
            tile.size = Vector2(tile_side, tile_side)
        _layout_equipment_name_underline(slot)


func _layout_equipment_name_underline(slot: String) -> void:
    var button: Button = customize_equipment_rows[slot]["panel"]
    var expand: Button = customize_equipment_rows[slot]["expand"]
    var underline: ColorRect = customize_equipment_rows[slot]["underline"]
    var font: Font = button.get_theme_font("font")
    var font_size: int = button.get_theme_font_size("font_size")
    var left: float = 17.0
    var available: float = maxf(0.0, expand.position.x - left - 12.0)
    underline.visible = font != null and not button.text.is_empty() and (
        button.modulate == Color.WHITE) and available > 2.0
    if not underline.visible:
        return
    var text_width: float = font.get_string_size(
        button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
    underline.position = Vector2(left,
        floorf((button.size.y + font.get_height(font_size)) * 0.5) + 2.0)
    underline.size = Vector2(minf(text_width, available), 1.0)


func _refresh_equipment_controls() -> void:
    for slot in CUSTOMIZE_SLOTS:
        if not customize_equipment_rows.has(slot):
            continue
        var button: Button = customize_equipment_rows[slot]["panel"]
        var selected_model: String = "A"
        var blocker: Dictionary = {}
        if sera_display_rig != null and bool(sera_display_rig.get("loading_ok")):
            selected_model = str(sera_display_rig.call("get_equipment_selection", slot))
            blocker = sera_display_rig.call(
                "get_equipment_two_handed_blocker", slot)
        if not blocker.is_empty():
            button.text = str(blocker.get("name", "TWO-HANDED"))
            button.modulate = Color(0.52, 0.57, 0.61, 1.0)
            _layout_equipment_name_underline(slot)
            continue
        button.modulate = Color.WHITE
        var uid: String = SeraSave.get_equipped_prototype(slot)
        if not uid.is_empty():
            var blueprint: String = uid.get_slice("-", 0)
            button.text = str(PrototypeCatalog.spec(blueprint).get("name", blueprint))
        else:
            button.text = _default_part_name(slot, selected_model)
        _layout_equipment_name_underline(slot)
    _sync_customization_row_selection()
    _refresh_customization_stats()
    if focused_target == "CUSTOMIZE" and not in_transition:
        _refresh_single_part_preview(customize_part_preview_slot)
        _refresh_customization_part_stats(customize_part_preview_slot)

# Inspecting a name highlights only the current equipment row.
# This is separate from the thumbnail button's equipment selection.
func _sync_customization_row_selection() -> void:
    for slot in CUSTOMIZE_SLOTS:
        if not customize_equipment_rows.has(slot):
            continue
        var entry: Dictionary = customize_equipment_rows[slot]
        var button: Button = entry["panel"] as Button
        var selected: bool = (focused_target == "CUSTOMIZE" and
            slot == customize_part_preview_slot and button.modulate == Color.WHITE)
        button.add_theme_stylebox_override("normal",
            entry["selected_style"] if selected else entry["normal_style"])
        button.add_theme_color_override("font_color",
            Color("#f3fcff") if selected else Color("#e2eef2"))
        var expand: Button = entry["expand"] as Button
        expand.add_theme_stylebox_override("normal",
            LaboSkin.terminal_segment_style("selected" if selected else "normal"))
        (entry["underline"] as ColorRect).color = (
            Color("#adeeff") if selected else Color("#55798a"))


func _default_part_name(slot: String, model: String) -> String:
    for id in PrototypeCatalog.ORDER:
        var spec: Dictionary = PrototypeCatalog.spec(str(id))
        if str(spec.get("slot", "")) == slot and (
                str(spec.get("rig_set", "")) == model):
            return str(spec.get("name", id))
    return str(CUSTOMIZE_SLOT_LABELS.get(slot, slot))


func _tap_equipment_control(point: Vector2) -> bool:
    if sera_display_rig == null or not Rect2(
            customize_right_panel.position, customize_right_panel.size).has_point(point):
        return false
    var local: Vector2 = point - customize_right_panel.position
    for slot in CUSTOMIZE_SLOTS:
        var row: Button = customize_equipment_rows[slot]["panel"]
        if Rect2(row.position, row.size).has_point(local):
            var blocker: Dictionary = sera_display_rig.call(
                "get_equipment_two_handed_blocker", slot)
            if not blocker.is_empty():
                return true
            var row_point: Vector2 = local - row.position
            var expand: Button = customize_equipment_rows[slot]["expand"]
            if Rect2(expand.position, expand.size).has_point(row_point):
                _show_customization_part_picker(slot)
            else:
                _inspect_customization_part(slot)
            return true
    return true


func _create_customization_part_picker() -> void:
    # SERA-wide matte/blue-grey picker; keep the existing raw-touch and
    # cached native part portraits, with no 3D renders per catalog cell.
    customize_part_picker = Control.new()
    customize_part_picker.name = "CustomizePartPickerOverlay"
    customize_part_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    customize_part_picker.visible = false
    customize_part_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(customize_part_picker)
    var shade := ColorRect.new()
    shade.name = "CustomizePartPickerShade"
    shade.color = Color(0.003, 0.010, 0.02, 0.87)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    customize_part_picker.add_child(shade)
    customize_part_picker_window = Panel.new()
    customize_part_picker_window.name = "CustomizePartPickerWindow"
    customize_part_picker_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_picker_window.add_theme_stylebox_override(
        "panel", LaboSkin.card_style("normal"))
    customize_part_picker.add_child(customize_part_picker_window)
    var header_plate := ColorRect.new()
    header_plate.name = "CustomizePartPickerHeaderPlate"
    header_plate.color = Color("#17313e")
    header_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_picker_window.add_child(header_plate)
    var header_rule := ColorRect.new()
    header_rule.name = "CustomizePartPickerHeaderRule"
    header_rule.color = Color("#55798a")
    header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_picker_window.add_child(header_rule)
    customize_part_picker_title = Label.new()
    customize_part_picker_title.name = "CustomizePartPickerTitle"
    customize_part_picker_title.add_theme_font_override(
        "font", LaboSkin.tracked_display_font())
    customize_part_picker_title.add_theme_font_size_override("font_size", 23)
    customize_part_picker_title.add_theme_color_override(
        "font_color", Color("#d7e6ed"))
    customize_part_picker_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    customize_part_picker_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_picker_window.add_child(customize_part_picker_title)
    var close := Label.new()
    close.name = "CustomizePartPickerClose"
    close.text = "×"
    close.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    close.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    close.add_theme_font_override("font", LaboSkin.tracked_display_font())
    close.add_theme_font_size_override("font_size", 28)
    close.add_theme_color_override("font_color", Color("#ccdce5"))
    close.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_picker_window.add_child(close)
    customize_part_picker_scroll = ScrollContainer.new()
    customize_part_picker_scroll.name = "CustomizePartPickerScroll"
    customize_part_picker_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    customize_part_picker_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    customize_part_picker_window.add_child(customize_part_picker_scroll)
    customize_part_grid = GridContainer.new()
    customize_part_grid.name = "CustomizePartPickerGrid"
    customize_part_grid.columns = 3
    customize_part_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    customize_part_grid.add_theme_constant_override("h_separation", 9)
    customize_part_grid.add_theme_constant_override("v_separation", 10)
    customize_part_picker_scroll.add_child(customize_part_grid)
    hud.resized.connect(_layout_customization_part_picker)

func _layout_customization_part_picker() -> void:
    if customize_part_picker == null:
        return
    var view: Vector2 = hud.size
    customize_part_picker_window.position = Vector2(view.x * 0.055,
        view.y * 0.218)
    customize_part_picker_window.size = Vector2(view.x * 0.890,
        view.y * 0.638)
    var window_width: float = customize_part_picker_window.size.x
    var window_height: float = customize_part_picker_window.size.y
    var plate: ColorRect = customize_part_picker_window.get_node(
        "CustomizePartPickerHeaderPlate") as ColorRect
    plate.position = Vector2(3.0, 3.0)
    plate.size = Vector2(window_width - 6.0, 54.0)
    var rule: ColorRect = customize_part_picker_window.get_node(
        "CustomizePartPickerHeaderRule") as ColorRect
    rule.position = Vector2(15.0, 57.0)
    rule.size = Vector2(window_width - 30.0, 2.0)
    customize_part_picker_title.position = Vector2(18.0, 7.0)
    customize_part_picker_title.size = Vector2(window_width - 94.0, 46.0)
    var close: Label = customize_part_picker_window.get_node(
        "CustomizePartPickerClose") as Label
    close.position = Vector2(window_width - 61.0, 7.0)
    close.size = Vector2(45.0, 46.0)
    customize_part_picker_scroll.position = Vector2(14.0, 70.0)
    customize_part_picker_scroll.size = Vector2(window_width - 28.0,
        maxf(100.0, window_height - 85.0))
    customize_part_grid.columns = 3
    # Reserve the actual 9px gaps and the scrollbar, so the last portrait
    # never clips behind the right edge or a vertical scroll thumb.
    var width: float = (customize_part_picker_scroll.size.x - 32.0) / 3.0
    for entry in customize_part_picker_cells:
        var card: Button = entry["button"]
        card.custom_minimum_size = Vector2(width, width + 53.0)
        var art: TextureRect = entry["art"]
        var side: float = maxf(60.0, width - 20.0)
        art.custom_minimum_size = Vector2(side, side)

func _show_customization_part_picker(slot: String) -> void:
    if customize_part_picker == null:
        return
    # Keep the inspected model and status in sync when the right-side button
    # opens selection; the name region itself never calls this function.
    _inspect_customization_part(slot)
    customize_part_picker_title.text = str(CUSTOMIZE_SLOT_LABELS.get(slot, slot)) + "   /   SELECT PART"
    for child in customize_part_grid.get_children():
        customize_part_grid.remove_child(child)
        child.queue_free()
    customize_part_picker_cells.clear()
    # Every installed mesh is selectable, plus each independently owned
    # crafted UID. Only owned copies carry their five randomized affixes.
    for id in PrototypeCatalog.ORDER:
        var spec: Dictionary = PrototypeCatalog.spec(str(id))
        if str(spec.get("slot", "")) != slot:
            continue
        _append_customization_choice("model:" + str(id),
            str(spec.get("name", "")), str(id), "")
    for item in SeraSave.get_owned_prototypes(slot):
        var uid: String = str(item.get("uid", ""))
        var blueprint: String = str(item.get("blueprint", ""))
        if PrototypeCatalog.spec(blueprint).is_empty():
            continue
        var part_name: String = str(PrototypeCatalog.spec(blueprint)["name"])
        _append_customization_choice("crafted:" + uid, part_name,
            blueprint, uid)
    _layout_customization_part_picker()
    customize_part_picker_scroll.scroll_vertical = 0
    customize_part_picker.visible = true
    customize_part_picker.move_to_front()

func _append_customization_choice(choice: String, name: String,
        blueprint: String, uid: String) -> void:
    var equipped_uid: String = SeraSave.get_equipped_prototype(customize_part_preview_slot)
    var selected_model: String = "A"
    if sera_display_rig != null:
        selected_model = str(sera_display_rig.call(
            "get_equipment_selection", customize_part_preview_slot))
    var spec: Dictionary = PrototypeCatalog.spec(blueprint)
    var selected: bool = (not uid.is_empty() and uid == equipped_uid) or (
        uid.is_empty() and equipped_uid.is_empty() and (
        str(spec.get("rig_set", "A")) == selected_model))
    # Do not mark two alternate blueprints as equipped when sharing a rig.
    if selected:
        for entry in customize_part_picker_cells:
            if bool(entry.get("selected", false)):
                selected = false
                break
    var card := Button.new()
    card.name = "PartChoice_" + choice.replace(":", "_")
    card.text = ""
    card.focus_mode = Control.FOCUS_NONE
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.clip_contents = true
    card.add_theme_stylebox_override(
        "normal", LaboSkin.card_style("selected" if selected else "normal"))
    card.add_theme_stylebox_override("hover", LaboSkin.card_style("hover"))
    card.add_theme_stylebox_override(
        "pressed", LaboSkin.card_style("selected"))
    customize_part_grid.add_child(card)
    var insets := MarginContainer.new()
    insets.name = "ChoiceInsets"
    insets.mouse_filter = Control.MOUSE_FILTER_IGNORE
    insets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for edge in ["left", "right", "top", "bottom"]:
        insets.add_theme_constant_override("margin_" + edge, 8)
    card.add_child(insets)
    var column := VBoxContainer.new()
    column.name = "ChoiceContents"
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_theme_constant_override("separation", 3)
    insets.add_child(column)
    var image := TextureRect.new()
    image.name = "ChoiceThumbnail"
    image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    image.texture = IconAtlas.equipment_icon(blueprint)
    image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_child(image)
    var caption := Label.new()
    caption.name = "ChoiceName"
    caption.text = name
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption.clip_text = true
    caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    caption.custom_minimum_size.y = 28.0
    caption.add_theme_font_override("font", LaboSkin.equipment_font())
    caption.add_theme_font_size_override("font_size", 17)
    caption.add_theme_color_override(
        "font_color", Color("#e2edf1") if selected else Color("#d1e0e7"))
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(caption)
    LaboSkin.attach_name_underline(caption)
    var ref := Label.new()
    ref.name = "ChoiceUID"
    ref.text = uid if not uid.is_empty() else " "
    ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ref.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ref.custom_minimum_size.y = 17.0
    ref.add_theme_font_override("font", LaboSkin.tracked_data_font())
    ref.add_theme_font_size_override("font_size", 12)
    ref.add_theme_color_override("font_color", Color("#a9c2cd"))
    ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(ref)
    # A thin active rail and LABO's selected chamfer indicate the installed
    # item; the original equipment PNG remains unmodified.
    var active_rail := ColorRect.new()
    active_rail.name = "ChoiceSelectedRail"
    active_rail.color = Color("#86d2dd")
    active_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    active_rail.visible = selected
    card.add_child(active_rail)
    active_rail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    active_rail.offset_left = 11.0
    active_rail.offset_right = -11.0
    active_rail.offset_top = -6.0
    active_rail.offset_bottom = -4.0
    customize_part_picker_cells.append({
        "button": card, "art": image, "choice": choice, "selected": selected
    })

func _choose_customization_part(choice: String) -> void:
    if sera_display_rig == null:
        return
    var slot: String = customize_part_preview_slot
    if not (sera_display_rig.call(
            "get_equipment_two_handed_blocker", slot) as Dictionary).is_empty():
        return
    var previous_set: String = str(sera_display_rig.call(
        "get_equipment_selection", slot))
    var selected_id: String = choice.trim_prefix("model:")
    var uid: String = ""
    if choice.begins_with("crafted:"):
        uid = choice.trim_prefix("crafted:")
        selected_id = uid.get_slice("-", 0)
    var spec: Dictionary = PrototypeCatalog.spec(selected_id)
    if str(spec.get("slot", "")) != slot:
        return
    var model: String = str(spec.get("rig_set", "A"))
    if not bool(sera_display_rig.call("set_equipment_selection", slot, model)):
        return
    var saved: bool = false
    if not uid.is_empty():
        saved = bool(SeraSave.equip_prototype(slot, uid))
    else:
        var current_uid: String = SeraSave.get_equipped_prototype(slot)
        saved = current_uid.is_empty() or bool(
            SeraSave.clear_equipped_prototype(slot))
    if not saved:
        sera_display_rig.call("set_equipment_selection", slot, previous_set)
        return
    _close_customization_part_picker()
    _refresh_equipment_controls()
    _refresh_single_part_preview(slot)
    _sync_customization_part_glow()
    if slot == "legs" or slot == "arms":
        _fit_nexus_arms_to_lower_body()
    _capture_sera_silhouette(sera_display_rig)
    _update_projected_silhouettes()
    outline.queue_redraw()

func _tap_customization_part_picker(point: Vector2) -> void:
    if customize_part_picker == null or not customize_part_picker.visible:
        return
    var window_rect := Rect2(customize_part_picker_window.position,
        customize_part_picker_window.size)
    if not window_rect.has_point(point):
        _close_customization_part_picker()
        return
    # Only the independent close glyph dismisses from inside the header.
    # The rest of the header is inert; outside-tap and Android Back remain.
    var close_rect := Rect2(customize_part_picker_window.position + Vector2(
        customize_part_picker_window.size.x - 67.0, 0.0), Vector2(67.0, 62.0))
    if close_rect.has_point(point):
        _close_customization_part_picker()
        return
    var clipping: Rect2 = customize_part_picker_scroll.get_global_rect()
    if not clipping.has_point(point):
        return
    for entry in customize_part_picker_cells:
        var card: Button = entry["button"]
        if card.get_global_rect().has_point(point):
            _choose_customization_part(str(entry["choice"]))
            return

func _close_customization_part_picker() -> void:
    if customize_part_picker != null:
        customize_part_picker.visible = false
    customize_picker_touch_id = -1
    customize_picker_mouse = false


func _create_single_part_preview() -> void:
    customize_single_part_preview = PartViewer.new()
    # Preview-only A/B prototype. Do NOT activate in 3D full-body SERA,
    # LABO, STORAGE, training mode, or Bittaran.
    customize_single_part_preview.enable_nexus_iris_id_contour = true
    customize_single_part_preview.name = "CustomizeSinglePartPreview"
    customize_single_part_preview.visible = false
    focus_panel.add_child(customize_single_part_preview)
    customize_single_part_preview.connect("preview_fullscreen_requested",
        _set_single_part_preview_fullscreen)
    customize_part_preview_fullscreen_layer = Panel.new()
    customize_part_preview_fullscreen_layer.name = "IrisPreviewFullscreenLayer"
    customize_part_preview_fullscreen_layer.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT)
    customize_part_preview_fullscreen_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    customize_part_preview_fullscreen_layer.z_index = 90
    var fullscreen_style := StyleBoxFlat.new()
    fullscreen_style.bg_color = Color("#263f4d")
    customize_part_preview_fullscreen_layer.add_theme_stylebox_override(
        "panel", fullscreen_style)
    customize_part_preview_fullscreen_layer.visible = false
    hud.add_child(customize_part_preview_fullscreen_layer)
    customize_part_preview_frame = PreviewRim.new()
    customize_part_preview_frame.name = "CustomizePartPreviewTechFrame"
    customize_part_preview_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    customize_part_preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_preview_frame.visible = false
    focus_panel.add_child(customize_part_preview_frame)
    customize_body_rotate_cue = RotateMark.new()
    customize_body_rotate_cue.name = "CustomizeBodyRotateCue"
    customize_body_rotate_cue.size = Vector2(28, 28)
    customize_body_rotate_cue.visible = false
    hud.add_child(customize_body_rotate_cue)


func _set_single_part_preview_fullscreen(enabled: bool) -> void:
    if customize_single_part_preview == null or (
            customize_part_preview_fullscreen_layer == null):
        return
    if enabled and (focused_target != "CUSTOMIZE" or
            not customize_single_part_preview.visible):
        return
    if enabled == customize_part_preview_fullscreen_active:
        return
    customize_part_preview_fullscreen_active = enabled
    customize_part_touch_id = -1
    customize_part_mouse_drag = false
    if enabled:
        customize_part_preview_fullscreen_layer.visible = true
        customize_single_part_preview.reparent(
            customize_part_preview_fullscreen_layer, false)
        customize_single_part_preview.set_anchors_and_offsets_preset(
            Control.PRESET_FULL_RECT)
        customize_single_part_preview.position = Vector2.ZERO
        customize_single_part_preview.size = customize_part_preview_fullscreen_layer.size
    else:
        customize_single_part_preview.reparent(focus_panel, false)
        customize_single_part_preview.set_anchors_and_offsets_preset(
            Control.PRESET_TOP_LEFT)
        customize_part_preview_fullscreen_layer.visible = false
    customize_single_part_preview.call("set_fullscreen_state", enabled)
    _layout_single_part_preview()


func _route_fullscreen_preview_input(event: InputEvent) -> bool:
    if not customize_part_preview_fullscreen_active:
        return false
    if event.is_action_pressed("ui_cancel") or (
            event is InputEventKey and event.pressed and not event.echo and
            event.keycode in [KEY_BACK, KEY_ESCAPE]):
        if bool(customize_single_part_preview.call("dismiss_iris_material_keyboard")):
            return true
        _set_single_part_preview_fullscreen(false)
        return true
    var part_rect: Rect2 = customize_single_part_preview.get_global_rect()
    if event is InputEventScreenTouch:
        if event.pressed and part_rect.has_point(event.position):
            customize_part_touch_id = event.index
            customize_single_part_preview.feed_touch(event.index, true,
                event.position - part_rect.position)
        elif not event.pressed and event.index == customize_part_touch_id:
            customize_single_part_preview.feed_touch(event.index, false,
                event.position - part_rect.position)
            customize_part_touch_id = -1
        return true
    if event is InputEventScreenDrag:
        if event.index == customize_part_touch_id:
            customize_single_part_preview.feed_drag(event.index,
                event.position - part_rect.position)
        return true
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed and part_rect.has_point(event.position):
                customize_part_mouse_drag = true
                customize_single_part_preview.feed_touch(-10, true,
                    event.position - part_rect.position)
            elif not event.pressed and customize_part_mouse_drag:
                customize_single_part_preview.feed_touch(-10, false,
                    event.position - part_rect.position)
                customize_part_mouse_drag = false
        return true
    if event is InputEventMouseMotion:
        if customize_part_mouse_drag:
            customize_single_part_preview.feed_drag(-10,
                event.position - part_rect.position)
        return true
    return false


func _layout_single_part_preview() -> void:
    if customize_single_part_preview == null:
        return
    var view: Vector2 = hud.size
    # The SubViewportContainer owns the rectangular frame; stretching it
    # across this window keeps the grid backdrop aligned to the chamfer rim.
    # Its native viewport receives the actual aspect ratio automatically.
    if customize_part_preview_fullscreen_active:
        customize_single_part_preview.position = Vector2.ZERO
        customize_single_part_preview.size = customize_part_preview_fullscreen_layer.size
        customize_body_rotate_cue.visible = false
        customize_part_preview_frame.visible = false
        return
    customize_single_part_preview.position = Vector2.ZERO
    customize_single_part_preview.size = focus_panel.size
    var area: Rect2 = _customize_model_area(view)
    customize_body_rotate_cue.position = area.position + Vector2(8, 8)
    customize_body_rotate_cue.visible = focused_target == "CUSTOMIZE"
    customize_part_preview_frame.visible = focused_target == "CUSTOMIZE"


func _refresh_single_part_preview(slot: String) -> void:
    if customize_single_part_preview == null or focused_target != "CUSTOMIZE":
        return
    var blueprint: String = _equipped_part_blueprint(slot)
    if not blueprint.is_empty():
        customize_part_preview_slot = slot
        customize_single_part_preview.show_part(blueprint)
        customize_single_part_preview.visible = true


func _create_customization_part_stats() -> void:
    # Independent three-column, no-scroll PART STATUS; reuse 28 fixed cells.
    customize_part_stats_panel = Panel.new()
    customize_part_stats_panel.name = "CustomizePartStatsPanel"
    customize_part_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_stats_panel.add_theme_stylebox_override(
        "panel", StatUI.status_window_style())
    customize_part_accents = StatUI.attach_status_marks(customize_part_stats_panel)
    customize_part_stats_panel.visible = false
    hud.add_child(customize_part_stats_panel)
    var header := Panel.new()
    header.name = "CustomizePartStatsHeader"
    header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_theme_stylebox_override("panel", _menu_header_style())
    customize_part_stats_panel.add_child(header)
    customize_part_stats_header = Label.new()
    customize_part_stats_header.name = "CustomizePartStatsHeading"
    customize_part_stats_header.text = ""
    customize_part_stats_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_stats_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    customize_part_stats_header.add_theme_font_override(
        "font", LaboSkin.tracked_display_font())
    customize_part_stats_header.add_theme_font_size_override("font_size", 19)
    customize_part_stats_header.add_theme_color_override(
        "font_color", Color("#d7e6ed"))
    header.add_child(customize_part_stats_header)
    header.visible = false
    for col in range(2):
        customize_part_column_rules.append(StatUI.new_column_rule(
            customize_part_stats_panel, "CustomizePartColumnDivider_%d" % col))
    customize_part_stats_name = Label.new()
    customize_part_stats_name.name = "CustomizePartStatsName"
    customize_part_stats_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_stats_name.clip_text = true
    customize_part_stats_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    customize_part_stats_name.add_theme_font_override(
        "font", LaboSkin.equipment_font())
    customize_part_stats_name.add_theme_font_size_override("font_size", 19)
    customize_part_stats_name.add_theme_color_override(
        "font_color", Color("#d7e6ed"))
    customize_part_stats_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    customize_part_stats_panel.add_child(customize_part_stats_name)
    LaboSkin.attach_name_underline(customize_part_stats_name)
    customize_part_stats_scroll = ScrollContainer.new()
    customize_part_stats_scroll.name = "CustomizePartStatsScroll"
    customize_part_stats_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    customize_part_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    customize_part_stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    customize_part_stats_panel.add_child(customize_part_stats_scroll)
    customize_part_stats_list = GridContainer.new()
    customize_part_stats_list.columns = 3
    customize_part_stats_list.name = "CustomizePartStatsRows"
    customize_part_stats_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
    customize_part_stats_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    customize_part_stats_list.add_theme_constant_override("h_separation", 11)
    customize_part_stats_list.add_theme_constant_override("v_separation", 1)
    customize_part_stats_scroll.add_child(customize_part_stats_list)
    for i in range(28):
        var row := Panel.new()
        row.name = "SinglePartStat_" + str(i)
        row.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.custom_minimum_size = Vector2(100, 44)
        StatUI.clear_cell_background(row)
        row.visible = false
        customize_part_stats_list.add_child(row)
        var label := Label.new()
        label.name = "PartStatName"
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.clip_text = true
        label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        label.add_theme_font_override("font", LaboSkin.stats_font())
        label.add_theme_font_size_override("font_size", 19)
        label.add_theme_color_override("font_color", Color("#a9c2cd"))
        row.add_child(label)
        var value := Label.new()
        value.name = "PartStatValue"
        value.mouse_filter = Control.MOUSE_FILTER_IGNORE
        value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        value.clip_text = true
        value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        value.add_theme_font_override("font", LaboSkin.stats_font())
        value.add_theme_font_size_override("font_size", 24)
        value.add_theme_color_override("font_color", Color("#e4edf1"))
        StatUI.style_stat_labels(label, value, 19, 24)
        row.add_child(value)
        customize_part_stat_cells.append({
            "panel": row, "name": label, "value": value
        })


func _customize_part_stats_rect(view: Vector2) -> Rect2:
    # Connect the part-preview bottom to the single-part stat panel.
    # Keep the rect local: an undefined preview identifier fails scene parsing.
    var preview: Rect2 = _customize_square_menu_rect(view)
    var start: float = preview.end.y
    var bottom: float = view.y * 0.905
    return Rect2(Vector2(view.x * 0.040, start),
        Vector2(view.x * 0.920, maxf(120.0, bottom - start)))


func _layout_customization_part_stats() -> void:
    if customize_part_stats_panel == null:
        return
    customize_part_stats_panel.visible = focused_target == "CUSTOMIZE"
    var area: Rect2 = _customize_part_stats_rect(hud.size)
    customize_part_stats_panel.position = area.position
    customize_part_stats_panel.size = area.size
    StatUI.layout_status_marks(customize_part_accents, area.size)
    var bar: Panel = customize_part_stats_panel.get_node(
        "CustomizePartStatsHeader") as Panel
    bar.position = Vector2.ZERO
    bar.size = Vector2.ZERO
    bar.visible = false
    customize_part_stats_header.position = Vector2.ZERO
    customize_part_stats_header.size = Vector2.ZERO
    customize_part_stats_name.position = Vector2(14, 7)
    customize_part_stats_name.size = Vector2(area.size.x - 28, 29)
    LaboSkin.refresh_name_underline(customize_part_stats_name)
    customize_part_stats_scroll.position = Vector2(11, 41)
    customize_part_stats_scroll.size = Vector2(
        maxf(40.0, area.size.x - 22.0), maxf(40.0, area.size.y - 47.0))
    StatUI.layout_column_rules(customize_part_column_rules,
        Rect2(Vector2(11, 41), customize_part_stats_scroll.size), 3)
    var row_width: float = floorf(
        (customize_part_stats_scroll.size.x - 22.0) / 3.0)
    for entry in customize_part_stat_cells:
        var row: Panel = entry["panel"]
        row.custom_minimum_size = Vector2(row_width, 44)
        var label: Label = entry["name"]
        var value: Label = entry["value"]
        StatUI.layout_metric_pair(label, value, row_width, 44.0, 19, 24, 16, 20)


func _refresh_customization_part_stats(slot: String) -> void:
    if customize_part_stats_panel == null or focused_target != "CUSTOMIZE":
        return
    var blueprint: String = _equipped_part_blueprint(slot)
    var spec: Dictionary = PrototypeCatalog.spec(blueprint)
    customize_part_stats_name.text = str(spec.get(
        "name", _default_part_name(slot, "A")))
    LaboSkin.refresh_name_underline(customize_part_stats_name)
    var rows: Array[Dictionary] = []
    if not blueprint.is_empty():
        var profile_lines: PackedStringArray = LaboStats.complete_profile_text(
            blueprint).split("\n")
        for i in range(1, profile_lines.size()):
            var line: String = str(profile_lines[i])
            var pivot: int = line.find("  ")
            if pivot <= 0:
                continue
            rows.append({
                "label": line.substr(0, pivot),
                "value": line.substr(pivot + 2)
            })
        var uid: String = SeraSave.get_equipped_prototype(slot)
        if not uid.is_empty():
            # Individually crafted affixes belong only to their UID, not to
            # other items sharing a model; display is not combat integration.
            for item in SeraSave.get_owned_prototypes(slot):
                if str(item.get("uid", "")) != uid:
                    continue
                for effect in CraftAffixes.sanitize(item.get("affixes", [])):
                    var effect_id: String = str(effect.get("id", ""))
                    rows.append({
                        "label": "特性 " + str(CraftAffixes.EFFECT_NAMES.get(
                            effect_id, effect_id)),
                        "value": "+%d%%" % int(effect.get("value", 0))
                    })
                break
    for i in range(customize_part_stat_cells.size()):
        var cell: Dictionary = customize_part_stat_cells[i]
        var show: bool = i < rows.size()
        (cell["panel"] as Panel).visible = show
        if show:
            (cell["name"] as Label).text = str(rows[i]["label"])
            (cell["value"] as Label).text = str(rows[i]["value"])
            var row: Panel = cell["panel"] as Panel
            StatUI.layout_metric_pair(
                cell["name"] as Label, cell["value"] as Label,
                row.custom_minimum_size.x, 44.0, 19, 24, 16, 20)
    # Reflow only the two linked lower windows, after the real number of
    # equipped-part stats/UID affixes is known. No font-size change.
    if hud != null:
        _layout_hud()


func _equipped_part_blueprint(slot: String) -> String:
    var uid: String = SeraSave.get_equipped_prototype(slot)
    if not uid.is_empty():
        return uid.get_slice("-", 0)
    var model: String = "A"
    if sera_display_rig != null:
        model = str(sera_display_rig.call("get_equipment_selection", slot))
    for candidate in PrototypeCatalog.ORDER:
        var spec: Dictionary = PrototypeCatalog.spec(str(candidate))
        if str(spec.get("slot", "")) == slot and (
                str(spec.get("rig_set", "")) == model):
            return str(candidate)
    return ""


func _clear_customization_part_glow() -> void:
    for part in customize_highlighted_meshes:
        if is_instance_valid(part) and (
                part.material_overlay == customize_selection_material):
            part.material_overlay = null
    customize_highlighted_meshes.clear()


func _sync_customization_part_glow() -> void:
    _clear_customization_part_glow()
    customize_selection_blink_elapsed = 0.0
    customize_selection_blink_on = true
    if not customize_preview_active or focused_target != "CUSTOMIZE" or (
            sera_display_rig == null or not bool(sera_display_rig.get("loading_ok"))):
        return
    if customize_selection_material == null:
        var material := StandardMaterial3D.new()
        # NEXUS-only translucent emission: the authored base texture remains
        # opaque; no see-through equipment, additional meshes or glow viewport.
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        material.no_depth_test = false
        material.albedo_color = Color(0.18, 0.56, 0.69, 0.24)
        material.emission_enabled = true
        material.emission = Color("#89d9f5")
        material.emission_energy_multiplier = 0.82
        material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
        customize_selection_material = material
    for raw_part in sera_display_rig.call(
            "get_equipment_visible_meshes", customize_part_preview_slot):
        var part: MeshInstance3D = raw_part as MeshInstance3D
        if part == null or not part.visible or part.material_overlay != null:
            continue
        part.material_overlay = customize_selection_material
        customize_highlighted_meshes.append(part)


func _update_customization_part_blink(delta: float) -> void:
    if focused_target != "CUSTOMIZE" or in_transition or (
            not customize_preview_active or customize_highlighted_meshes.is_empty()):
        return
    customize_selection_blink_elapsed = fposmod(
        customize_selection_blink_elapsed + maxf(delta, 0.0),
        CUSTOMIZE_SELECTION_BLINK_PERIOD_SECONDS)
    var next_on: bool = (customize_selection_blink_elapsed <
        CUSTOMIZE_SELECTION_BLINK_PERIOD_SECONDS * CUSTOMIZE_SELECTION_BLINK_ON_RATIO)
    if next_on == customize_selection_blink_on:
        return
    customize_selection_blink_on = next_on
    # Hard ON/OFF: existing 3D material overlay only; untouched authored base.
    for part in customize_highlighted_meshes:
        if not is_instance_valid(part):
            continue
        if next_on and part.visible and part.material_overlay == null:
            part.material_overlay = customize_selection_material
        elif not next_on and part.material_overlay == customize_selection_material:
            part.material_overlay = null


func _inspect_customization_part(slot: String) -> void:
    if focused_target != "CUSTOMIZE":
        return
    customize_part_preview_slot = slot
    _refresh_single_part_preview(slot)
    _refresh_customization_part_stats(slot)
    _sync_customization_part_glow()
    _sync_customization_row_selection()


func _load_system_lock_preference() -> void:
    var settings := ConfigFile.new()
    if settings.load(CONTROL_SETTINGS_FILE) == OK:
        system_auto_lock_enabled = bool(settings.get_value(
            "controls", "auto_lock_enabled", true))
        system_left_handed = bool(settings.get_value(
            "controls", "left_handed", false))


func _set_system_auto_lock(enabled: bool) -> void:
    var settings := ConfigFile.new()
    settings.load(CONTROL_SETTINGS_FILE)
    settings.set_value("controls", "auto_lock_enabled", enabled)
    var result: Error = settings.save(CONTROL_SETTINGS_FILE)
    if result != OK:
        push_warning("Unable to save lock mode preference: %d" % result)
        return
    system_auto_lock_enabled = enabled


func _set_system_handedness(left: bool) -> void:
    var settings := ConfigFile.new()
    settings.load(CONTROL_SETTINGS_FILE)
    settings.set_value("controls", "left_handed", left)
    var result: Error = settings.save(CONTROL_SETTINGS_FILE)
    if result != OK:
        push_warning("Unable to save handedness preference: %d" % result)
        return
    system_left_handed = left
    if sera_display_rig != null:
        sera_display_rig.call("set_run_left_handed", left)


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
    system_lock_mode_row = Panel.new()
    system_lock_mode_row.name = "SystemLockMode"
    system_lock_mode_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_lock_mode_row.add_theme_stylebox_override("panel", LaboSkin.card_style("normal"))
    system_lock_mode_row.visible = false
    focus_panel.add_child(system_lock_mode_row)
    system_lock_mode_label = Label.new()
    system_lock_mode_label.name = "SystemLockModeValue"
    system_lock_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_lock_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    system_lock_mode_label.add_theme_font_size_override("font_size", 16)
    system_lock_mode_label.add_theme_color_override("font_color", Color("#ccf3ff"))
    system_lock_mode_row.add_child(system_lock_mode_label)
    system_handedness_row = Panel.new()
    system_handedness_row.name = "SystemHandedness"
    system_handedness_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_handedness_row.add_theme_stylebox_override("panel", LaboSkin.card_style("normal"))
    system_handedness_row.visible = false
    focus_panel.add_child(system_handedness_row)
    system_handedness_label = Label.new()
    system_handedness_label.name = "SystemHandednessValue"
    system_handedness_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_handedness_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    system_handedness_label.add_theme_font_size_override("font_size", 16)
    system_handedness_label.add_theme_color_override("font_color", Color("#ccf3ff"))
    system_handedness_row.add_child(system_handedness_label)
    _load_system_lock_preference()
    system_status = Label.new()
    system_status.name = "ArchiveStatus"
    system_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    system_status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    system_status.add_theme_font_size_override("font_size", 14)
    system_status.add_theme_color_override("font_color", Color("#a5e4ff"))
    system_status.visible = false
    focus_panel.add_child(system_status)
    _create_fps_option_controls()
    _refresh_system_controls()

func _create_fps_option_controls() -> void:
    # A separate SYSTEM subpage avoids shrinking SAVE/LOAD and touch targets.
    system_fps_button = Panel.new()
    system_fps_button.name = "SystemFPSSettings"
    system_fps_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_fps_button.add_theme_stylebox_override(
        "panel", LaboSkin.card_style("normal"))
    system_fps_button.visible = false
    focus_panel.add_child(system_fps_button)
    system_fps_button_label = Label.new()
    system_fps_button_label.name = "SystemFPSSettingsLabel"
    system_fps_button_label.text = "GRAPHICS SETTINGS   >"
    system_fps_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_fps_button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    system_fps_button.add_child(system_fps_button_label)

    for spec in [
        {"scope": "base_nexus", "title": "BASE / NEXUS"},
        {"scope": "grid", "title": "GRID 操作"},
        {"scope": "combat", "title": "戦闘中"},
        {"scope": "display", "title": "画面表示"},
        {"scope": "base_outline", "title": "拠点の枠線"},
        {"scope": "character_outline", "title": "全身キャラ枠線"},
        {"scope": "part_outline", "title": "単体パーツ枠線"},
        {"scope": "motion_blur", "title": "モーションブラー"},
    ]:
        var panel := Panel.new()
        panel.name = "FPSRow_" + str(spec["scope"])
        panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
        panel.add_theme_stylebox_override(
            "panel", LaboSkin.card_style("normal"))
        panel.visible = false
        focus_panel.add_child(panel)
        var label := Label.new()
        label.name = "FPSValue_" + str(spec["scope"])
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 14)
        panel.add_child(label)
        var value := Label.new()
        value.name = "FPSSelected_" + str(spec["scope"])
        value.mouse_filter = Control.MOUSE_FILTER_IGNORE
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        value.add_theme_font_size_override("font_size", 14)
        panel.add_child(value)
        system_fps_rows.append({
            "scope": str(spec["scope"]),
            "title": str(spec["title"]),
            "panel": panel, "label": label, "value": value,
        })
    system_fps_back_button = Panel.new()
    system_fps_back_button.name = "FPSOptionsBack"
    system_fps_back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_fps_back_button.add_theme_stylebox_override(
        "panel", LaboSkin.card_style("normal"))
    system_fps_back_button.visible = false
    focus_panel.add_child(system_fps_back_button)
    system_fps_back_label = Label.new()
    system_fps_back_label.name = "FPSOptionsBackLabel"
    system_fps_back_label.text = "‹  BACK TO SYSTEM"
    system_fps_back_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_fps_back_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    system_fps_back_button.add_child(system_fps_back_label)
    system_fps_note = Label.new()
    system_fps_note.name = "FPSOptionsNotice"
    system_fps_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
    system_fps_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    system_fps_note.add_theme_color_override(
        "font_color", Color("#a5e4ff"))
    system_fps_note.visible = false
    focus_panel.add_child(system_fps_note)
    _refresh_fps_option_controls()


func _layout_fps_option_controls() -> void:
    if system_fps_button == null:
        return
    var margin: float = 12.0
    var width: float = focus_panel.size.x - margin * 2.0
    var top: float = focus_header.size.y + 20.0
    var available: float = maxf(185.0, focus_panel.size.y - top - 143.0)
    var row_height: float = clampf(
        available / float(system_fps_rows.size()) - 8.0, 42.0, 70.0)
    var row_step: float = row_height + 8.0
    for i in range(system_fps_rows.size()):
        var row: Panel = system_fps_rows[i]["panel"]
        row.position = Vector2(margin, top + i * row_step)
        row.size = Vector2(width, row_height)
        var label: Label = system_fps_rows[i]["label"]
        label.position = Vector2(12.0, 0.0)
        label.size = Vector2(row.size.x * 0.60 - 12.0, row.size.y)
        var value: Label = system_fps_rows[i]["value"]
        value.position = Vector2(row.size.x * 0.60, 0.0)
        value.size = Vector2(row.size.x * 0.40 - 12.0, row.size.y)
    system_fps_note.position = Vector2(
        margin, top + system_fps_rows.size() * row_step + 7.0)
    system_fps_note.size = Vector2(width, maxf(40.0,
        focus_panel.size.y - system_fps_note.position.y - 79.0))
    system_fps_back_button.position = Vector2(
        margin, focus_panel.size.y - 69.0)
    system_fps_back_button.size = Vector2(width, 52.0)
    system_fps_back_label.position = Vector2(12.0, 0.0)
    system_fps_back_label.size = system_fps_back_button.size - Vector2(24.0, 0.0)


func _refresh_fps_option_controls() -> void:
    for entry in system_fps_rows:
        var scope: String = str(entry["scope"])
        var label: Label = entry["label"]
        label.text = str(entry["title"])
        var value: Label = entry["value"]
        if scope == "display":
            value.text = ("上下拡張  >" if DisplayProfile.get_mode() ==
                DisplayProfile.MODE_EXPANDED else "従来 9:16  >")
        elif GraphicsSettings.OPTIONS.has(scope):
            value.text = "ON  >" if GraphicsSettings.get_enabled(scope) else "OFF  >"
        else:
            value.text = "%d FPS  >" % FrameRateSettings.get_limit(scope)
    if system_fps_note != null:
        system_fps_note.text = (
            "各行をタップして切り替えます。\n"
            + "グラフィック設定はこの端末に保存されます。")


func _open_fps_option_controls() -> void:
    if focused_target != "SYSTEM" or system_fps_options_open:
        return
    system_fps_options_open = true
    focus_title.text = "GRAPHICS"
    LaboSkin.refresh_name_underline(focus_title)
    _refresh_fps_option_controls()
    _set_system_visible(true)
    _layout_system_controls()


func _close_fps_option_controls() -> void:
    if not system_fps_options_open:
        return
    system_fps_options_open = false
    focus_title.text = "SYSTEM"
    LaboSkin.refresh_name_underline(focus_title)
    _set_system_visible(true)
    _refresh_system_controls()


func _tap_fps_option_control(point: Vector2) -> void:
    var local: Vector2 = point - focus_panel.position
    if Rect2(system_fps_back_button.position,
            system_fps_back_button.size).has_point(local):
        _close_fps_option_controls()
        return
    for entry in system_fps_rows:
        var panel: Panel = entry["panel"]
        if not Rect2(panel.position, panel.size).has_point(local):
            continue
        var scope: String = str(entry["scope"])
        if GraphicsSettings.OPTIONS.has(scope):
            var next_enabled: bool = not GraphicsSettings.get_enabled(scope)
            if GraphicsSettings.set_enabled(scope, next_enabled):
                # NEXUS can preview BASE and character ink changes immediately.
                var compositor: Node = get_viewport().get_node_or_null(
                    "SeraIDOutlineLayer/SeraIDOutlineControl")
                if is_instance_valid(compositor):
                    compositor.call("refresh_graphics_preferences")
                _refresh_fps_option_controls()
            else:
                system_fps_note.text = "グラフィック設定の保存に失敗しました。"
            return
        if scope == "display":
            var next_mode: String = (DisplayProfile.MODE_CLASSIC if
                DisplayProfile.get_mode() == DisplayProfile.MODE_EXPANDED
                else DisplayProfile.MODE_EXPANDED)
            if DisplayProfile.set_mode(next_mode):
                DisplayProfile.apply(get_window())
                _refresh_fps_option_controls()
                # Apply new viewport geometry after anchors have resized.
                call_deferred("_on_display_size_changed")
            else:
                system_fps_note.text = "画面表示設定の保存に失敗しました。"
            return
        var old_fps: int = FrameRateSettings.get_limit(scope)
        var next_fps: int = FrameRateSettings.next_limit(old_fps)
        if FrameRateSettings.set_limit(scope, next_fps):
            if scope == "base_nexus":
                # Apply immediately inside NEXUS; other scopes on entry.
                FrameRateSettings.apply("base_nexus")
            _refresh_fps_option_controls()
        else:
            system_fps_note.text = "FPS設定の保存に失敗しました。"
        return


func _set_system_visible(show: bool) -> void:
    var regular: bool = show and not system_fps_options_open
    for entry in system_slot_rows:
        (entry["panel"] as Panel).visible = regular
    for entry in system_action_rows:
        (entry["panel"] as Panel).visible = regular
    system_status.visible = regular
    system_lock_mode_row.visible = regular
    system_handedness_row.visible = regular
    system_fps_button.visible = regular
    for entry in system_fps_rows:
        (entry["panel"] as Panel).visible = show and system_fps_options_open
    system_fps_note.visible = show and system_fps_options_open
    system_fps_back_button.visible = show and system_fps_options_open

func _layout_system_controls() -> void:
    if system_status == null:
        return
    var width: float = focus_panel.size.x
    var margin: float = 12.0
    var compact: bool = focus_panel.size.y < 575.0
    var gap: float = 5.0 if compact else 8.0
    var row_height: float = clampf(
        (focus_panel.size.y - focus_header.size.y -
            (312.0 if compact else 365.0)) / 3.0,
        39.0 if compact else 50.0, 73.0)
    var top: float = focus_header.size.y + 12.0
    for i in range(system_slot_rows.size()):
        var panel: Panel = system_slot_rows[i]["panel"]
        panel.position = Vector2(margin, top + i * (row_height + gap))
        panel.size = Vector2(width - margin * 2.0, row_height)
        var label: Label = system_slot_rows[i]["label"]
        label.position = Vector2(12.0, 0.0)
        label.size = panel.size - Vector2(24.0, 0.0)
    var actions_top: float = top + system_slot_rows.size() * (row_height + gap) + (6.0 if compact else 9.0)
    var action_step: float = 46.0 if compact else 58.0
    var action_height: float = 42.0 if compact else 54.0
    var setting_height: float = 38.0 if compact else 44.0
    var action_width: float = (width - margin * 2.0 - gap) * 0.5
    for i in range(system_action_rows.size()):
        var button: Panel = system_action_rows[i]["panel"]
        button.position = Vector2(margin + (i % 2) * (action_width + gap),
            actions_top + (i / 2) * action_step)
        button.size = Vector2(action_width, action_height)
        var label: Label = system_action_rows[i]["label"]
        label.position = Vector2.ZERO
        label.size = button.size
    system_lock_mode_row.position = Vector2(margin,
        actions_top + (94.0 if compact else 123.0))
    system_lock_mode_row.size = Vector2(width - margin * 2.0, setting_height)
    system_lock_mode_label.position = Vector2(12.0, 0.0)
    system_lock_mode_label.size = system_lock_mode_row.size - Vector2(24.0, 0.0)
    system_handedness_row.position = Vector2(margin,
        actions_top + (136.0 if compact else 174.0))
    system_handedness_row.size = Vector2(width - margin * 2.0, setting_height)
    system_handedness_label.position = Vector2(12.0, 0.0)
    system_handedness_label.size = system_handedness_row.size - Vector2(24.0, 0.0)
    system_fps_button.position = Vector2(margin,
        actions_top + (178.0 if compact else 225.0))
    system_fps_button.size = Vector2(width - margin * 2.0, setting_height)
    system_fps_button_label.position = Vector2(12.0, 0.0)
    system_fps_button_label.size = system_fps_button.size - Vector2(24.0, 0.0)
    system_status.position = Vector2(margin,
        actions_top + (224.0 if compact else 276.0))
    system_status.size = Vector2(width - margin * 2.0,
        maxf(24.0, focus_panel.size.y - system_status.position.y - 10.0))
    _layout_fps_option_controls()

func _refresh_system_controls() -> void:
    if system_status == null:
        return
    if system_lock_mode_label != null:
        system_lock_mode_label.text = (
            "LOCK MODE  /  AUTO  >" if system_auto_lock_enabled
            else "LOCK MODE  /  MANUAL  >")
    if system_handedness_label != null:
        system_handedness_label.text = (
            "DOMINANT HAND  /  LEFT  >" if system_left_handed
            else "DOMINANT HAND  /  RIGHT  >")
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
        panel.add_theme_stylebox_override("panel",
            LaboSkin.card_style("selected" if system_selected_slot == slot else "normal"))
    for entry in system_action_rows:
        var action: String = entry["action"]
        var label: Label = entry["label"]
        var button: Panel = entry["panel"]
        var button_style: StyleBoxFlat = _menu_style()
        if system_pending_action == action and system_pending_slot == system_selected_slot:
            label.text = "CONFIRM " + action
            button_style.set_border_width_all(3)
            button_style.border_color = (SYSTEM_CONFIRM_BORDER_BRIGHT
                if system_confirm_blink_bright else SYSTEM_CONFIRM_BORDER_DIM)
            button_style.bg_color = (SYSTEM_CONFIRM_BG_BRIGHT
                if system_confirm_blink_bright else SYSTEM_CONFIRM_BG_DIM)
        else:
            label.text = "NEW DATA" if action == "NEW" else action
        button.add_theme_stylebox_override("panel", button_style)
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
    for entry in system_action_rows:
        if str(entry["action"]) != system_pending_action:
            continue
        var button: Panel = entry["panel"]
        # Alter only the button showing CONFIRM; save-slot frames stay static.
        # Reuse the existing StyleBoxFlat and redraw only on phase changes.
        var style: StyleBoxFlat = button.get_theme_stylebox("panel") as StyleBoxFlat
        if style != null:
            style.border_color = (SYSTEM_CONFIRM_BORDER_BRIGHT
                if bright else SYSTEM_CONFIRM_BORDER_DIM)
            style.bg_color = (SYSTEM_CONFIRM_BG_BRIGHT if bright
                else SYSTEM_CONFIRM_BG_DIM)
            button.queue_redraw()
        break

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
    if system_fps_options_open:
        _tap_fps_option_control(point)
        return
    var local: Vector2 = point - focus_panel.position
    # A pending CONFIRM accepts only a tap inside that exact action button.
    # A tap on any other button, slot, label or empty space cancels and is
    # consumed; it must not also select a slot or start another operation.
    if not system_pending_action.is_empty():
        var touched_confirm: bool = false
        for entry in system_action_rows:
            if str(entry["action"]) != system_pending_action:
                continue
            var confirm_panel: Panel = entry["panel"]
            touched_confirm = Rect2(confirm_panel.position, confirm_panel.size).has_point(local)
            break
        if not touched_confirm:
            _cancel_system_confirmation()
            return
    # Frame-rate settings have a separate page so SAVE/LOAD stays readable.
    if system_fps_button != null and Rect2(
            system_fps_button.position, system_fps_button.size).has_point(local):
        _open_fps_option_controls()
        return
    # Mode is a global control preference, independent of save slots.
    if system_lock_mode_row != null and Rect2(
            system_lock_mode_row.position, system_lock_mode_row.size).has_point(local):
        _set_system_auto_lock(not system_auto_lock_enabled)
        _refresh_system_controls()
        return
    if system_handedness_row != null and Rect2(
            system_handedness_row.position, system_handedness_row.size).has_point(local):
        _set_system_handedness(not system_left_handed)
        _refresh_system_controls()
        return
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
        # LOAD always needs confirmation when the selected slot exists.
        # SAVE/NEW only need confirmation when overwriting an existing slot.
        var needs_confirmation: bool = (action == "LOAD" or action == "DELETE"
            or (exists and (action == "SAVE" or action == "NEW")))
        if needs_confirmation and (system_pending_action != action or system_pending_slot != slot):
            system_pending_action = action
            system_pending_slot = slot
            _reset_system_confirmation_blink()
            system_message = "PRESS CONFIRM %s FOR SLOT %02d" % [action, slot]
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
    _fit_nexus_arms_to_lower_body()
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
        (archive_record_tabs[i]["panel"] as Panel).add_theme_stylebox_override(
            "panel", LaboSkin.terminal_segment_style(
                "selected" if i == archive_record_tab else "normal"))
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

# NEXUS reuses the exact LABO visual resources, but only dynamic save/confirm
# controls duplicate StyleBoxFlat before mutation. Shared caches remain immutable.
func _menu_style() -> StyleBoxFlat:
    return LaboSkin.terminal_segment_style("normal").duplicate(true) as StyleBoxFlat

func _menu_body_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = LaboSkin.style("card").duplicate(true) as StyleBoxFlat
    style.bg_color = Color("#101f2b")
    style.border_color = Color("#345767")
    style.set_corner_radius_all(4)
    style.set_border_width_all(1)
    return style

func _menu_header_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = LaboSkin.terminal_segment_style("selected").duplicate(true) as StyleBoxFlat
    style.bg_color = Color("#193744")
    style.border_color = Color("#6099a8")
    style.border_width_bottom = 2
    return style

func _action_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = LaboSkin.terminal_segment_style("selected").duplicate(true) as StyleBoxFlat
    style.bg_color = Color("#22515d")
    style.border_color = Color("#83d7dd")
    style.border_width_bottom = 3
    return style


func _skin_label(label: Label, font: Font, text_size: int, color: Color) -> void:
    label.add_theme_font_override("font", font)
    label.add_theme_font_size_override("font_size", text_size)
    label.add_theme_color_override("font_color", color)


## LABO typography is cached and bundled for Android; no SystemFont requests.
## All five NEXUS destinations share the same label hierarchy.
func _apply_labo_typography() -> void:
    var display: Font = LaboSkin.tracked_display_font()
    var stats: Font = LaboSkin.stats_font()
    var ui: Font = LaboSkin.ui_font()
    var equipment: Font = LaboSkin.equipment_font()
    var accent: Color = Color("#d7e6ed")
    var secondary: Color = Color("#b7cbd6")
    _skin_label(focus_title, display, 24, accent)
    LaboSkin.attach_name_underline(focus_title)
    _skin_label(customize_equipment_header, display, 21, accent)
    _skin_label(back_arrow, display, 32, accent)
    _skin_label(explore_label, display, 20, accent)
    _skin_label(action_label, display, 22, Color("#e1f1f2"))
    _skin_label(training_heading, display, 15, secondary)
    _skin_label(training_footer, stats, 13, secondary)
    _skin_label(deployment_heading, display, 16, secondary)
    for entry in training_option_rows:
        _skin_label(entry["label"] as Label, display, 16, secondary)
        _skin_label(entry["value"] as Label, stats, 20, accent)
    for entry in deployment_rows:
        _skin_label(entry["label"] as Label, LaboSkin.title_font(), 21, accent)
        LaboSkin.attach_name_underline(entry["label"] as Label)
    for slot in CUSTOMIZE_SLOTS:
        var button: Button = customize_equipment_rows[slot]["panel"]
        button.add_theme_font_override("font", equipment)
        button.add_theme_font_size_override("font_size", 22)
        button.add_theme_color_override("font_color", accent)
        _layout_equipment_name_underline(slot)
    for cell in customize_stat_cells:
        StatUI.style_stat_labels(
            cell["name"] as Label, cell["value"] as Label, 19, 25)
    for entry in system_slot_rows:
        _skin_label(entry["label"] as Label, stats, 16, accent)
    for entry in system_action_rows:
        _skin_label(entry["label"] as Label, display, 18, accent)
    _skin_label(system_lock_mode_label, stats, 17, accent)
    _skin_label(system_handedness_label, stats, 17, accent)
    _skin_label(system_status, ui, 15, secondary)
    _skin_label(system_fps_button_label, stats, 17, accent)
    for entry in system_fps_rows:
        _skin_label(entry["label"] as Label, stats, 16, accent)
        _skin_label(entry["value"] as Label, stats, 18, accent)
    _skin_label(system_fps_back_label, display, 18, accent)
    _skin_label(system_fps_note, ui, 15, secondary)
    for entry in archive_record_tabs:
        _skin_label(entry["label"] as Label, display, 14, accent)
    _skin_label(archive_record_body, stats, 17, accent)

# CUSTOMIZE: TOTAL above, model/PART VIEW and equipment side-by-side,
# non-scrolling PART STATUS across the bottom. Rects use HUD coordinates.
func _customize_part_vertical_shift(view: Vector2) -> float:
    # Reuse only the unused area UNDER the last visible single-part stat.
    # 10 stats -> 4 rows -> roughly 40px lower; 15 -> 5 rows -> unchanged.
    var visible_fields: int = 0
    for item in customize_part_stat_cells:
        if (item["panel"] as Panel).visible:
            visible_fields += 1
    var content_rows: int = mini(5, maxi(1, ceili(float(visible_fields) / 3.0)))
    var content_height: float = 41.0 + float(content_rows) * 44.0 + (
        float(content_rows - 1) * 1.0 + 6.0)
    var baseline_bottom: float = view.y * 0.905
    var baseline_status_top: float = view.y * (0.506 + 0.185)
    var available: float = baseline_bottom - baseline_status_top
    return clampf(available - content_height - 3.0, 0.0, view.y * 0.045)


func _customize_square_menu_rect(view: Vector2) -> Rect2:
    # PART VIEW and its attached stat window shift together; fonts and the
    # absolute bottom edge stay fixed across selected equipment.
    var shift: float = _customize_part_vertical_shift(view)
    return Rect2(Vector2(view.x * 0.040, view.y * 0.506 + shift),
        Vector2(view.x * 0.435, view.y * 0.185))

func _customize_tall_menu_rect(view: Vector2) -> Rect2:
    return Rect2(
        Vector2(view.x * 0.510, view.y * 0.255),
        Vector2(view.x * 0.455, view.y * 0.431))

func _customize_model_area(view: Vector2) -> Rect2:
    # SERA's original fit remains unchanged as the PART VIEW moves down.
    var part_view: Rect2 = _customize_square_menu_rect(view)
    var baseline_preview_top: float = view.y * 0.506
    var top: float = view.y * 0.275
    var bottom: float = baseline_preview_top - maxf(12.0, view.y * 0.011)
    return Rect2(Vector2(part_view.position.x, top),
        Vector2(part_view.size.x, maxf(1.0, bottom - top)))


func _gpu_outline_diagnostics() -> Node:
    if not is_instance_valid(sera_display_rig):
        return null
    return sera_display_rig.get_node_or_null("SeraLiveMeshEdges")


func _outline_debug_style(selected: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#3c6779") if selected else Color("#173442")
    style.border_color = Color("#9ccbd9") if selected else Color("#55798a")
    style.set_border_width_all(1)
    style.set_corner_radius_all(3)
    return style


func _create_outline_debug() -> void:
    outline_debug_button = Panel.new()
    outline_debug_button.name = "SeraGPUOutlineDebugToggle"
    outline_debug_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    outline_debug_button.visible = false
    outline_debug_button.add_theme_stylebox_override(
        "panel", _outline_debug_style(false))
    hud.add_child(outline_debug_button)
    outline_debug_button_text = Label.new()
    outline_debug_button_text.text = "輪郭診断"
    outline_debug_button_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    outline_debug_button_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    outline_debug_button_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    outline_debug_button_text.add_theme_font_size_override("font_size", 15)
    outline_debug_button_text.add_theme_color_override(
        "font_color", Color("#c5e7f0"))
    outline_debug_button.add_child(outline_debug_button_text)

    outline_debug_panel = Panel.new()
    outline_debug_panel.name = "SeraGPUOutlineDiagnostics"
    outline_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    outline_debug_panel.visible = false
    outline_debug_panel.z_index = 90
    var background := StyleBoxFlat.new()
    background.bg_color = Color("#0d2330")
    background.border_color = Color("#55798a")
    background.set_border_width_all(2)
    outline_debug_panel.add_theme_stylebox_override("panel", background)
    hud.add_child(outline_debug_panel)

    var heading := Label.new()
    heading.name = "GPUEdgeDiagnosticsHeading"
    heading.text = "GPU 輪郭診断  |  NEXUS全身"
    heading.position = Vector2(10.0, 6.0)
    heading.size = Vector2(286.0, 26.0)
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heading.add_theme_font_size_override("font_size", 14)
    heading.add_theme_color_override("font_color", Color("#d8f2f9"))
    outline_debug_panel.add_child(heading)
    # Diagnostic modes are selected by a compact touch grid; no mouse emulation.
    # The cells never intercept drags outside the diagnostic panel.
    for i in range(OUTLINE_DIAGNOSTIC_MODES.size()):
        var item := Panel.new()
        item.name = "GPUEdgeMode%d" % i
        item.mouse_filter = Control.MOUSE_FILTER_IGNORE
        item.position = Vector2(8.0 + float(i % 3) * 98.0,
            37.0 + float(int(i / 3)) * 44.0)
        item.size = Vector2(93.0, 37.0)
        item.add_theme_stylebox_override(
            "panel", _outline_debug_style(i == 0))
        outline_debug_panel.add_child(item)
        outline_debug_mode_buttons.append(item)
        var text_label := Label.new()
        text_label.text = OUTLINE_DIAGNOSTIC_MODES[i]
        text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        text_label.size = item.size
        text_label.add_theme_font_size_override("font_size", 12)
        text_label.add_theme_color_override(
            "font_color", Color("#d6f3fb"))
        item.add_child(text_label)
        outline_debug_mode_labels.append(text_label)

    outline_debug_stats = Label.new()
    outline_debug_stats.name = "GPUEdgeGeometryCounts"
    outline_debug_stats.position = Vector2(10.0, 349.0)
    outline_debug_stats.size = Vector2(286.0, 137.0)
    outline_debug_stats.text = "GPU 輪郭メッシュの準備状態を確認中"
    outline_debug_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
    outline_debug_stats.add_theme_font_size_override("font_size", 13)
    outline_debug_stats.add_theme_color_override(
        "font_color", Color("#d6f3fb"))
    outline_debug_panel.add_child(outline_debug_stats)

    outline_debug_hint = Label.new()
    outline_debug_hint.name = "GPUEdgeDiagnosticsHelp"
    outline_debug_hint.position = Vector2(10.0, 493.0)
    outline_debug_hint.size = Vector2(286.0, 60.0)
    outline_debug_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    outline_debug_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    outline_debug_hint.add_theme_font_size_override("font_size", 11)
    outline_debug_hint.add_theme_color_override(
        "font_color", Color("#a4d5e4"))
    outline_debug_hint.text = OUTLINE_DIAGNOSTIC_EXPLAINS[0]
    outline_debug_panel.add_child(outline_debug_hint)


func _layout_outline_debug(view: Vector2) -> void:
    if outline_debug_button == null:
        return
    var x: float = 26.0
    var y: float = maxf(313.0, view.y * 0.208)
    outline_debug_button.position = Vector2(x, y)
    outline_debug_button.size = Vector2(100.0, 34.0)
    outline_debug_button_text.position = Vector2.ZERO
    outline_debug_button_text.size = outline_debug_button.size
    # Put the opaque diagnostics above the RIGHT equipment menu, not on
    # top of SERA at left. The model stays visible for rotation/screenshots.
    var panel_width: float = minf(307.0, view.x - 2.0 * x)
    var panel_x: float = view.x - x - panel_width
    var panel_y: float = minf(view.y - 565.0,
        maxf(190.0, view.y * 0.21))
    outline_debug_panel.position = Vector2(panel_x, panel_y)
    outline_debug_panel.size = Vector2(panel_width, 560.0)


func _set_gpu_outline_debug_mode(mode: int) -> void:
    outline_debug_mode = clampi(mode, 0,
        OUTLINE_DIAGNOSTIC_MODES.size() - 1)
    var live: Node = _gpu_outline_diagnostics()
    if live != null:
        live.call("set_diagnostic_mode", outline_debug_mode)
    if is_instance_valid(sera_display_rig):
        var stencil: Node = sera_display_rig.get_node_or_null(
            "SeraStencilHull")
        if stencil != null:
            stencil.call("set_diagnostic_mode", outline_debug_mode)
    if is_instance_valid(sera_display_rig):
        var depth_hull: Node = sera_display_rig.get_node_or_null(
            "SeraDepthHullOutline")
        if depth_hull != null:
            depth_hull.call("set_diagnostic_mode", outline_debug_mode)
    for i in range(outline_debug_mode_buttons.size()):
        var button: Panel = outline_debug_mode_buttons[i]
        button.add_theme_stylebox_override(
            "panel", _outline_debug_style(i == outline_debug_mode))
    if is_instance_valid(outline_debug_hint):
        outline_debug_hint.text = OUTLINE_DIAGNOSTIC_EXPLAINS[
            outline_debug_mode]
    outline_debug_elapsed = 0.0


func _hide_outline_debug() -> void:
    outline_debug_enabled = false
    _set_gpu_outline_debug_mode(0)
    if is_instance_valid(outline_debug_panel):
        outline_debug_panel.visible = false


func _handle_outline_debug_input(event: InputEvent) -> bool:
    if focused_target != "CUSTOMIZE" or outline_debug_button == null or (
            not outline_debug_button.visible):
        return false
    var at: Vector2 = Vector2.ZERO
    var released: bool = false
    if event is InputEventScreenTouch:
        at = event.position
        released = not event.pressed
    elif event is InputEventMouseButton and (
            event.button_index == MOUSE_BUTTON_LEFT):
        at = event.position
        released = not event.pressed
    else:
        return false
    if Rect2(outline_debug_button.position,
            outline_debug_button.size).has_point(at):
        if not released:
            outline_debug_enabled = not outline_debug_enabled
            outline_debug_panel.visible = outline_debug_enabled
            _set_gpu_outline_debug_mode(0)
            if outline_debug_enabled:
                _refresh_outline_debug(0.0)
        return true
    if outline_debug_enabled and Rect2(outline_debug_panel.position,
            outline_debug_panel.size).has_point(at):
        if not released:
            var local: Vector2 = at - outline_debug_panel.position
            for i in range(outline_debug_mode_buttons.size()):
                var button: Panel = outline_debug_mode_buttons[i]
                if Rect2(button.position, button.size).has_point(local):
                    _set_gpu_outline_debug_mode(i)
                    _refresh_outline_debug(0.0)
                    break
        return true
    return false


func _refresh_outline_debug(delta: float) -> void:
    if not outline_debug_enabled or not is_instance_valid(
            outline_debug_stats):
        return
    outline_debug_elapsed -= delta
    if outline_debug_elapsed > 0.0:
        return
    outline_debug_elapsed = 0.45
    var live: Node = _gpu_outline_diagnostics()
    if live == null:
        outline_debug_stats.text = (
            "GPU輪郭制御: 未生成\n"
            + "NEXUS全身SERAの表示状態を確認してください.")
        return
    var data: Dictionary = live.call("get_diagnostic_snapshot")
    var count: int = int(data.get("active_sources", 0))
    var draws: int = int(data.get("edge_draws", 0))
    var missing: int = int(data.get("missing_draws", 0))
    var stencil_data: Dictionary = {}
    var depth_data: Dictionary = {}
    if is_instance_valid(sera_display_rig):
        var stencil: Node = sera_display_rig.get_node_or_null("SeraStencilHull")
        if stencil != null:
            stencil_data = stencil.call("get_stencil_snapshot")
        var depth_hull: Node = sera_display_rig.get_node_or_null(
            "SeraDepthHullOutline")
        if depth_hull != null:
            depth_data = depth_hull.call("get_outline_snapshot")
    outline_debug_stats.text = (
        "深度ハル: %d / 候補: %d  非対応: %d\n"
        + "描画ハル: %d  ステンシル: %d  旧ハル: %d\n"
        + "旧エッジ(診断): %d / %d  欠落: %d\n"
        + "候補エッジ: %d  交差線: %d\n"
        + "カメラ: %s  枠線設定: %s\n"
        + "画素判定: %s  接合線キャッシュ: %s\n"
        + "立方体: 値%d / カメラ%s\n"
        + "法線比較: %s"
    ) % [
        int(depth_data.get("parts", 0)),
        int(depth_data.get("candidates", 0)),
        int(depth_data.get("unsupported", 0)),
        int(depth_data.get("hulls", 0)),
        0,
        int(stencil_data.get("hulls", 0)),
        count, draws, missing,
        int(data.get("edge_segments", 0)),
        int(data.get("contact_segments", 0)),
        "OK" if bool(data.get("camera_present", false)) else "なし",
        "ON" if bool(data.get("enabled", false)) else "OFF",
        "GPU深度ハル" if bool(depth_data.get("active", false)) else (
            "旧方式診断" if outline_debug_mode != 0
            else "枠線OFF"),
        "済" if bool(data.get("contacts_cached", false)) else "なし",
        int(stencil_data.get("probe_ref", 0)),
        "OK" if bool(stencil_data.get("probe_camera", false)) else "未確認",
        "+8px" if int(stencil_data.get("signed_offset_px", 0)) == 8 else (
            "-8px" if int(stencil_data.get("signed_offset_px", 0)) == -8
            else "OFF")
    ]

func _layout_hud() -> void:
    if hud == null or back_panel == null or focus_panel == null:
        return
    var view := hud.size
    var margin := maxf(16.0, view.x * 0.04)
    _layout_outline_debug(view)
    # Dedicated raw-touch hit area: GUI mouse emulation remains off.
    explore_panel.position = Vector2(margin, view.y - margin - 66.0)
    explore_panel.size = Vector2(minf(190.0, view.x * 0.43), 66.0)
    explore_label.position = Vector2.ZERO
    explore_label.size = explore_panel.size
    explore_panel.visible = true
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
    if focused_target == "SYSTEM":
        # Keep the FPS entry and save-slot controls visible on short phones.
        focus_panel.position.y = minf(focus_panel.position.y, view.y * 0.115)
        focus_panel.size.y = minf(view.y * 0.76,
            maxf(610.0, view.y * 0.535))
    if focused_target == "CUSTOMIZE":
        var square: Rect2 = _customize_square_menu_rect(view)
        var tall: Rect2 = _customize_tall_menu_rect(view)
        focus_panel.position = square.position
        focus_panel.size = square.size
        customize_right_panel.position = tall.position
        customize_right_panel.size = tall.size
        customize_right_header.position = Vector2.ZERO
        customize_right_header.size = Vector2.ZERO
        customize_right_header.visible = false
        _layout_equipment_controls()
        _layout_customization_part_picker()
    # The opaque top stripe belongs to the focus panel; rest stays blue/clear.
    focus_header.position = Vector2.ZERO
    focus_header.size = Vector2(focus_panel.size.x,
        0.0 if focused_target == "CUSTOMIZE" else
        minf(60.0, view.y * 0.068))
    focus_header.visible = focused_target != "CUSTOMIZE"
    focus_title.position = Vector2(16.0, 0.0)
    focus_title.size = Vector2(focus_header.size.x - 32.0, focus_header.size.y)
    _layout_customization_stats()
    _layout_customization_part_stats()
    _layout_single_part_preview()
    action_panel.position = Vector2(16.0, focus_panel.size.y - 84.0)
    action_panel.size = Vector2(focus_panel.size.x - 32.0, 60.0)
    action_label.position = Vector2.ZERO
    action_label.size = action_panel.size
    _layout_training_controls()
    _layout_deployment_controls()
    _layout_system_controls()
    _layout_archive_records()
    _update_projected_silhouettes()
    if customize_preview_active:
        _update_customization_glow()

# A single camera-facing semi-transparent 3D quad remains behind SERA.
# Depth testing preserves the visible character; the color and grid are uniform
# over the portrait screen, without a blue-white halo or character-dependent UVs.
func _create_customization_glow() -> void:
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    var material := ShaderMaterial.new()
    material.shader = CUSTOMIZE_BACKDROP_SHADER
    material.set_shader_parameter("base_tint", Color("#294755"))
    material.set_shader_parameter("grid_tint", Color("#193241"))
    material.set_shader_parameter("grid_strength", 0.77)
    material.set_shader_parameter("base_opacity", 0.96)
    var backdrop := MeshInstance3D.new()
    backdrop.name = "CustomizePortraitGridBackdrop"
    backdrop.mesh = quad
    backdrop.material_override = material
    backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    backdrop.visible = false
    cam.add_child(backdrop)
    customize_glow_quad = backdrop

# Preserve vertical framing while switching the shared 3D portrait camera.
func _set_customization_camera_projection(enabled: bool) -> void:
    if cam == null:
        return
    if enabled:
        var depth: float = maxf(0.1, -customize_preview_position.z)
        cam.size = 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5)
        cam.projection = Camera3D.PROJECTION_ORTHOGONAL
    else:
        cam.projection = Camera3D.PROJECTION_PERSPECTIVE


# Cover the portrait viewport with a dark, depth-tested blue-grey matte.
# Use orthographic dimensions only while the customized model is stationary.
func _update_customization_glow() -> void:
    if not customize_preview_active or customize_glow_quad == null or cam == null or hud == null:
        return
    var viewport_size := hud.size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    var depth: float = -customize_preview_position.z + CUSTOMIZE_GLOW_DEPTH_OFFSET
    var half_height: float = (cam.size * 0.5 if (
        cam.projection == Camera3D.PROJECTION_ORTHOGONAL) else
        depth * tan(deg_to_rad(cam.fov) * 0.5))
    var half_width: float = half_height * viewport_size.x / viewport_size.y
    customize_glow_quad.position = Vector3(0.0, 0.0, -depth)
    var quad := customize_glow_quad.mesh as QuadMesh
    quad.size = Vector2(
        2.0 * half_width * CUSTOMIZE_GLOW_SCREEN_WIDTH,
        2.0 * half_height * CUSTOMIZE_GLOW_SCREEN_HEIGHT)
    var spacing: float = maxf(12.0, CUSTOMIZE_GRID_SPACING_PIXELS)
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
    var basis := Basis(Vector3.UP, customize_preview_yaw) * (
        Basis(Vector3.RIGHT, customize_preview_pitch))
    basis = basis.scaled(Vector3.ONE * customize_preview_scale)
    # Hold Chest/Torso/Waist in a constant camera-local position while the
    # model rotates. The authored root sits at the feet, so its transform
    # origin MUST move around this pivot; this is not a screen-space correction.
    # In the neutral front pose, the pivot term cancels exactly, preserving
    # the initial fit/scale and entrance tween endpoint from earlier builds.
    var front_basis := Basis(Vector3.UP, PI).scaled(
        Vector3.ONE * customize_preview_scale)
    var pivot_camera: Vector3 = (
        customize_preview_position + front_basis * customize_motion_torso_local)
    var pivot_origin: Vector3 = pivot_camera - basis * customize_motion_torso_local
    sera_display_rig.global_transform = cam.global_transform * Transform3D(
        basis, pivot_origin)

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
    customize_preview_pitch = 0.0
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
    # Backdrop/grid stay camera-fixed and do not depend on model pose.
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
    _set_customization_camera_projection(true)
    _fit_customization_preview()
    _capture_sera_silhouette(sera_display_rig)
    _update_projected_silhouettes()
    # Show the stationary grid only after SERA and the camera have reached
    # their final placement. Back still hides it in the press event.
    if customize_glow_quad != null:
        _update_customization_glow()
        customize_glow_quad.visible = true
    in_transition = false
    _sync_customization_part_glow()

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
    _clear_customization_part_glow()
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
    var target_center_y: float = frame.get_center().y + 3.0
    # Fit the authored front-facing SERA into the upper-left viewing region.
    # Keep the initial full-body scale/pivot fixed during subsequent drag yaw.
    var target_width: float = minf(size.x * CUSTOMIZE_PREVIEW_TARGET_WIDTH_RATIO,
        allowed_width * 0.97)

    for pass_index in range(2):
        var rect := _customization_screen_bounds()
        if rect.size.x <= 1.0 or rect.size.y <= 1.0:
            return
        var fit: float = minf(target_width / rect.size.x,
            (allowed_height * 0.90) / rect.size.y)
        fit = clampf(fit, 0.15, 3.25)
        customize_preview_scale *= fit
        _apply_customization_preview_transform()
        _capture_sera_silhouette(sera_display_rig)
        rect = _customization_screen_bounds()
        if rect.size.x <= 1.0 or rect.size.y <= 1.0:
            return
        var depth: float = -customize_preview_position.z
        var half_height: float = (cam.size * 0.5 if (
            cam.projection == Camera3D.PROJECTION_ORTHOGONAL) else
            depth * tan(deg_to_rad(cam.fov) * 0.5))
        var px_per_world := size.y / maxf(0.001, 2.0 * half_height)
        var error := Vector2(
            center_target_x - (rect.position.x + rect.size.x * 0.5),
            target_center_y - (rect.position.y + rect.size.y * 0.5))
        customize_preview_position.x += error.x / px_per_world
        customize_preview_position.y -= error.y / px_per_world
        _apply_customization_preview_transform()
        _capture_sera_silhouette(sera_display_rig)

    # The initial one-time fitting is preserved; drag only changes rotation.
    customize_preview_fitted_scale = customize_preview_scale

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
    if customize_stats_panel != null and customize_stats_panel.visible and (
            customize_stats_panel.get_global_rect().has_point(pixel)):
        return false
    if customize_part_stats_panel != null and customize_part_stats_panel.visible and (
            customize_part_stats_panel.get_global_rect().has_point(pixel)):
        return false
    return true

func _rotate_customization_preview(delta: Vector2) -> void:
    if not customize_preview_active or sera_display_rig == null:
        return
    if delta.length_squared() < 0.000001:
        return
    var yaw_delta: float = delta.x / maxf(hud.size.x, 1.0) * CUSTOMIZE_DRAG_FULL_TURN
    var pitch_delta: float = -delta.y / maxf(hud.size.y, 1.0) * PI
    customize_preview_yaw = wrapf(customize_preview_yaw + yaw_delta, -PI, PI)
    customize_preview_pitch = clampf(customize_preview_pitch + pitch_delta,
        deg_to_rad(-55.0), deg_to_rad(55.0))
    # Rotation only: no translation, scale or center correction per gesture.
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
func _on_android_back() -> void:
    _navigate_back()

func _navigate_back() -> void:
    if customize_part_preview_fullscreen_active:
        _set_single_part_preview_fullscreen(false)
        return
    if customize_part_picker != null and customize_part_picker.visible:
        _close_customization_part_picker()
        return
    if focused_target == "SYSTEM" and system_fps_options_open:
        _close_fps_option_controls()
        return
    if in_transition:
        return
    if focused_target.is_empty():
        _enter_base()
    elif focused_target != "SYSTEM" or not _cancel_system_confirmation():
        _return_to_overview()

func _input(event: InputEvent) -> void:
    if _route_fullscreen_preview_input(event):
        get_viewport().set_input_as_handled()
        return
    if _handle_outline_debug_input(event):
        get_viewport().set_input_as_handled()
        return
    # Aggregate stats are read-only and can scroll without rotating the
    # character or treating the upper strip as a dismiss tap.
    if focused_target == "CUSTOMIZE" and (
            customize_part_picker == null or not customize_part_picker.visible):
        var is_pointer: bool = (event is InputEventScreenTouch or
            event is InputEventScreenDrag or event is InputEventMouseButton or
            event is InputEventMouseMotion)
        # Once a finger/mouse began on SERA, capture its full gesture until
        # release even when crossing total stats, part view or equipment rows.
        var is_customization_capture: bool = (
            (event is InputEventScreenDrag and event.index == customize_touch_id) or
            (event is InputEventScreenTouch and event.index == customize_touch_id) or
            (event is InputEventMouseMotion and customize_mouse_drag) or
            (event is InputEventMouseButton and customize_mouse_drag))
        if not is_customization_capture:
            if is_pointer and (
                    (customize_stats_panel != null and
                    customize_stats_panel.get_global_rect().has_point(event.position)) or
                    (customize_part_stats_panel != null and
                    customize_part_stats_panel.get_global_rect().has_point(event.position))):
                return
    # Picker taps occur on RELEASE so upward swipes cannot accidentally equip.
    # The scroll is manual because NEXUS uses raw Android touch navigation.
    if customize_part_picker != null and customize_part_picker.visible:
        if event is InputEventScreenTouch:
            if event.pressed:
                if customize_picker_touch_id == -1:
                    customize_picker_touch_id = event.index
                    customize_picker_start = event.position
                    customize_picker_last = event.position
            elif event.index == customize_picker_touch_id:
                if event.position.distance_to(customize_picker_start) < 14.0:
                    _tap_customization_part_picker(event.position)
                customize_picker_touch_id = -1
            get_viewport().set_input_as_handled()
            return
        elif event is InputEventScreenDrag:
            if event.index == customize_picker_touch_id:
                customize_part_picker_scroll.scroll_vertical -= roundi(event.relative.y)
                customize_picker_last = event.position
            get_viewport().set_input_as_handled()
            return
        elif event is InputEventMouseButton:
            if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
                customize_part_picker_scroll.scroll_vertical += (
                    -64 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 64)
            elif event.button_index == MOUSE_BUTTON_LEFT:
                if event.pressed:
                    customize_picker_mouse = true
                    customize_picker_start = event.position
                else:
                    if customize_picker_mouse and event.position.distance_to(
                            customize_picker_start) < 14.0:
                        _tap_customization_part_picker(event.position)
                    customize_picker_mouse = false
            get_viewport().set_input_as_handled()
            return
        elif event is InputEventMouseMotion and customize_picker_mouse:
            customize_part_picker_scroll.scroll_vertical -= roundi(event.relative.y)
            get_viewport().set_input_as_handled()
            return
    # Dedicated bottom-left part preview never rotates the full SERA body.
    if focused_target == "CUSTOMIZE" and customize_single_part_preview != null and (
            customize_single_part_preview.visible):
        var part_rect: Rect2 = customize_single_part_preview.get_global_rect()
        if event is InputEventScreenTouch:
            if event.pressed and part_rect.has_point(event.position):
                customize_part_touch_id = event.index
                customize_single_part_preview.feed_touch(event.index, true,
                    event.position - part_rect.position)
                get_viewport().set_input_as_handled()
                return
            if not event.pressed and event.index == customize_part_touch_id:
                customize_single_part_preview.feed_touch(event.index, false,
                    event.position - part_rect.position)
                customize_part_touch_id = -1
                get_viewport().set_input_as_handled()
                return
        elif event is InputEventScreenDrag and event.index == customize_part_touch_id:
            customize_single_part_preview.feed_drag(event.index,
                event.position - part_rect.position)
            get_viewport().set_input_as_handled()
            return
        elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed and part_rect.has_point(event.position):
                customize_part_mouse_drag = true
                customize_single_part_preview.feed_touch(-10, true,
                    event.position - part_rect.position)
                get_viewport().set_input_as_handled()
                return
            if not event.pressed and customize_part_mouse_drag:
                customize_single_part_preview.feed_touch(-10, false,
                    event.position - part_rect.position)
                customize_part_mouse_drag = false
                get_viewport().set_input_as_handled()
                return
        elif event is InputEventMouseMotion and customize_part_mouse_drag:
            customize_single_part_preview.feed_drag(-10,
                event.position - part_rect.position)
            get_viewport().set_input_as_handled()
            return
    if event.is_action_pressed("ui_cancel") or (
            event is InputEventKey and event.pressed and not event.echo
            and event.keycode in [KEY_BACK, KEY_ESCAPE]):
        _navigate_back()
        get_viewport().set_input_as_handled()
        return
    if in_transition:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if customize_touch_id == -1 and _is_customization_drag_zone(event.position):
                customize_touch_id = event.index
                customize_touch_last_x = event.position.x
                customize_touch_last_y = event.position.y
                customize_touch_last = event.position
            else:
                _tap_at(event.position)
            get_viewport().set_input_as_handled()
        elif event.index == customize_touch_id:
            customize_touch_id = -1
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if event.index == customize_touch_id:
            _rotate_customization_preview(event.position - customize_touch_last)
            customize_touch_last = event.position
            customize_touch_last_x = event.position.x
            customize_touch_last_y = event.position.y
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            if _is_customization_drag_zone(event.position):
                customize_mouse_drag = true
                customize_mouse_last_x = event.position.x
                customize_mouse_last_y = event.position.y
                customize_mouse_last = event.position
            else:
                _tap_at(event.position)
        else:
            customize_mouse_drag = false
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and customize_mouse_drag:
        _rotate_customization_preview(event.position - customize_mouse_last)
        customize_mouse_last = event.position
        customize_mouse_last_x = event.position.x
        customize_mouse_last_y = event.position.y
        get_viewport().set_input_as_handled()

func _tap_at(point: Vector2) -> void:
    # Exit is available from the NEXUS overview AND from any focused menu.
    if explore_panel.visible and Rect2(
            explore_panel.position, explore_panel.size).has_point(point):
        _enter_base()
        return
    if not focused_target.is_empty():
        # The back button on this 3D-focused screen is a visual cue; callers
        # can always use the actual device gesture or tap the space outside
        # the opened panel. Explicit back-area taps also remain accessible.
        if Rect2(back_panel.position, back_panel.size).has_point(point):
            _navigate_back()
            return
        var in_focused: bool = focus_panel.visible and Rect2(
            focus_panel.position, focus_panel.size).has_point(point)
        var in_customize: bool = focused_target == "CUSTOMIZE" and (
            customize_right_panel.visible and Rect2(
                customize_right_panel.position, customize_right_panel.size
            ).has_point(point))
        var in_part_stats: bool = focused_target == "CUSTOMIZE" and (
            customize_part_stats_panel != null and
            customize_part_stats_panel.get_global_rect().has_point(point))
        var in_total_stats: bool = focused_target == "CUSTOMIZE" and (
            customize_stats_panel != null and
            customize_stats_panel.get_global_rect().has_point(point))
        if not in_focused and not in_customize and (
                not in_part_stats and not in_total_stats):
            _navigate_back()
            return
        if focused_target == "SYSTEM" and focus_panel.visible:
            _tap_system_control(point)
        elif focused_target == "DATA ARCHIVE" and focus_panel.visible:
            _tap_archive_record(point)
        elif focused_target == "CUSTOMIZE" and customize_right_panel.visible:
            _tap_equipment_control(point)
        elif focused_target == "DEPLOYMENT" and focus_panel.visible:
            _tap_deployment_boss(point)
        elif focused_target == "TRAINING" and focus_panel.visible:
            var action_rect := Rect2(focus_panel.position + action_panel.position,
                action_panel.size)
            if action_rect.has_point(point):
                _start_training()
            else:
                _tap_training_control(point)
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
    # Overview has no nested menu. A tap on non-selectable surroundings
    # returns to the outdoor base, matching the Android Back hierarchy.
    _navigate_back()

func _enter_base() -> void:
    if in_transition:
        return
    # No walkable NEXUS scene; exit straight back to the exterior base hub.
    SeraSave.requested_nexus_target = ""
    var err: Error = get_tree().change_scene_to_file(BASE_SCENE)
    if err != OK:
        push_error("NEXUS base exploration scene load failed (%d)" % err)

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
        cam.fov = DisplayProfile.vertical_fov(float(view["fov"]),
            get_viewport().get_visible_rect().size)
        _show_customization_preview()
        cam.transform = previous_camera_pose
        cam.fov = previous_camera_fov
        _update_projected_silhouettes()
    _move_camera(aim_pose, DisplayProfile.vertical_fov(float(view["fov"]),
        get_viewport().get_visible_rect().size), _focus_arrived.bind(target_name))

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
    focus_title.text = "" if target_name == "CUSTOMIZE" else target_name
    LaboSkin.refresh_name_underline(focus_title)
    # SYSTEM edits save files; DATA ARCHIVE displays read-only records.
    system_fps_options_open = false
    _set_system_visible(target_name == "SYSTEM")
    _set_archive_records_visible(target_name == "DATA ARCHIVE")
    if target_name == "DATA ARCHIVE":
        archive_record_tab = 0
        _refresh_archive_records()
    if target_name == "SYSTEM":
        _load_system_lock_preference()
        system_pending_action = ""
        system_pending_slot = 0
        _reset_system_confirmation_blink()
        system_message = ""
        _refresh_system_controls()
    action_label.text = ">>  TRAINING START  <<" if target_name == "TRAINING" else ""
    action_panel.visible = target_name == "TRAINING"
    if target_name == "TRAINING":
        training_settings = TrainingDefaults.load_defaults()
        _refresh_training_controls()
        training_start_pulse = 0.0
    _set_training_visible(target_name == "TRAINING")
    _set_deployment_visible(target_name == "DEPLOYMENT")
    _layout_hud()
    focus_panel.visible = true
    customize_right_panel.visible = target_name == "CUSTOMIZE"
    if outline_debug_button != null:
        outline_debug_button.visible = target_name == "CUSTOMIZE"
    if target_name != "CUSTOMIZE":
        _hide_outline_debug()
    if target_name == "CUSTOMIZE":
        _refresh_equipment_controls()
        _inspect_customization_part(customize_part_preview_slot)
        _layout_single_part_preview()
    elif customize_single_part_preview != null:
        customize_single_part_preview.visible = false
        customize_body_rotate_cue.visible = false

func _return_to_overview() -> void:
    if in_transition or focused_target.is_empty():
        return
    _set_single_part_preview_fullscreen(false)
    _clear_customization_part_glow()
    # Back immediately ends the bright selection, before camera return.
    outline.set("active_target", "")
    outline.queue_redraw()
    # Hide the matte blue-grey grid on the Back press itself,
    # before either the model or camera Tween gets its first frame.
    if focused_target == "CUSTOMIZE":
        if customize_glow_quad != null:
            customize_glow_quad.visible = false
        _set_customization_camera_projection(false)
    in_transition = true
    _close_customization_part_picker()
    customize_part_touch_id = -1
    customize_part_mouse_drag = false
    if customize_single_part_preview != null:
        customize_single_part_preview.set_preview_active(false)
        customize_single_part_preview.visible = false
    if customize_body_rotate_cue != null:
        customize_body_rotate_cue.visible = false
    focus_panel.visible = false
    customize_right_panel.visible = false
    _hide_outline_debug()
    if outline_debug_button != null:
        outline_debug_button.visible = false
    if customize_stats_panel != null:
        customize_stats_panel.visible = false
    if customize_stats_scroll != null:
        customize_stats_scroll.visible = false
    if customize_part_stats_panel != null:
        customize_part_stats_panel.visible = false
    _set_training_visible(false)
    _set_deployment_visible(false)
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
    _set_customization_camera_projection(false)
    # The SERA retraction now finishes at 0.14s; keep its model aligned to the
    # moving camera until 0.18s. Only then restore the exact stand transform.
    if focused_target == "CUSTOMIZE" and customize_preview_active:
        if customize_entrance_tween != null and customize_entrance_tween.is_running():
            return
        _restore_customization_preview()
    in_transition = false
    explore_panel.visible = true
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
