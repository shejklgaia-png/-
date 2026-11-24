extends Node3D
const StaticBake = preload("res://scripts/sera_static_bake.gd")
## Outdoor portrait base hub; CRATE wanders independently and NEXUS is a tappable building.
const Modules = preload("res://assets/base_command_modules.gd")
const WorldMonitors = preload("res://scripts/sera_world_monitor_textures.gd")
const SERA_RIG_PATH: String = "res://scripts/sera_rig.gd"
const VersionIndicator = preload("res://scripts/version_indicator.gd")
const LoadingConsole = preload("res://scripts/sera_loading_console.gd")
const StartupBudget = preload("res://scripts/sera_startup_budget.gd")
const BaseFacilities = preload("res://scripts/base_facility_system.gd")
const PlacementStore = preload("res://scripts/sera_placement_store.gd")
const SharedMaterialShading = preload("res://scripts/sera_fullbody_material_preview.gd")
const SeraViewEdges = preload("res://scripts/sera_view_edges.gd")
const PowerBoard = preload("res://scripts/sera_base_power_board.gd")
const BasePowerDistribution = preload(
    "res://scripts/sera_base_power_distribution.gd")
const GridUi = preload("res://scripts/sera_base_grid_ui.gd")
const BaseFrameBudget = preload("res://scripts/sera_base_frame_budget.gd")
const DisplayProfile = preload("res://scripts/sera_display_profile.gd")
const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")
const BaseFacilityInk = preload("res://scripts/sera_base_facility_outlines.gd")
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const BaseClutter = preload("res://scripts/sera_base_clutter.gd")
const BaseLayoutPreview = preload("res://scripts/sera_base_layout_preview.gd")
const CanonicalProps = preload("res://scripts/sera_base_prop_canonical.gd")
const JunkGeometry = preload("res://scripts/sera_base_junk_geometry.gd")
const BaseFloorDetail = preload("res://scripts/sera_base_floor_detail.gd")
const BaseFloorLighting = preload("res://scripts/sera_base_floor_lighting.gd")
const BaseDeckLayout = preload("res://scripts/sera_base_deck_layout.gd")
const BASE_LOGISTICS_PATH: String = "res://scripts/sera_base_logistics.gd"
const BasePolygon = preload("res://scripts/sera_base_polygon_meshes.gd")
const WEATHERED_STEEL_PATH: String = "res://assets/base/industrial_steel_grunge.svg"
const WEATHERED_DECK_PATH: String = "res://assets/base/industrial_deck_wear.svg"
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const CrateModel = preload("res://scripts/sera_crate_model.gd")
const NexusEntryTransition = preload("res://scripts/sera_nexus_entry_transition.gd")
const NEXUS_SCENE: String = "res://scenes/command_nexus.tscn"
const BASE_BGM_PATH: String = "res://BGM/scrap_sanctuary_seamless.ogg"
# The 174 BPM track has a one-bar crossfade from 141.200 s into
# 30.855 s. Intro plays once; the decoder loops from the crossfade target.
const BASE_BGM_LOOP_OFFSET: float = 32.2343125
const BASE_BGM_VOLUME_DB: float = -9.0
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
# Camera elevation is ~26.9 degrees (from 33.8), bringing the front
# facades, canopies and service doors closer to a human-height view.
# Keep orthographic projection and the established horizontal bearing.
# The five vertical yard tiers are placed in the world, not faked by moving
# the facility meshes away from their bases, signs, touch areas or steel pads.
# Translate both eye and target +2.1m vertically: facilities appear lower
# without changing their camera-facing angles, world locations, or slab links.
const BASE_ORTHO_SIZE: float = 38.0
# All BASE/GRID view transitions are one uninterrupted camera move.
const BASE_GRID_TRAVEL_SECONDS: float = 0.48
const GRID_EDIT_ZOOM_SECONDS: float = 0.46
const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 19.5, 25.0)
const BASE_CAMERA_TARGET: Vector3 = Vector3(0.0, 2.1, -2.2)
const NEXUS_BUILDING_ORIGIN: Vector3 = Vector3(-13.44, 0.0, -19.91)
const CRATE_SPEED: float = 0.95
# CRATE wanders the irregular middle service lanes rather than revolving
# around a square formal plaza or crossing the relocated LABO foundation.
# Keep the existing stable nine-point path and camera-facing starting lane.
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
var facility_name_button: Button
var facility_names_enabled: bool = true
const FACILITY_NAME_CONFIG: String = "user://base_facility_names.cfg"
var nexus_touch_id: int = -1
var nexus_touch_start: Vector2 = Vector2.ZERO
var crate_waypoint: int = 0
var crate_wait: float = 0.0
var touch_id: int = -1
var joystick: Vector2 = Vector2.ZERO
var mouse_steering: bool = false
var scene_changing: bool = false
var base_bgm_player: AudioStreamPlayer
var _nexus_shutter_clip: AudioStreamMP3
var elapsed: float = 0.0
var crate: Node3D
var batches: Dictionary = {}
var facility_system: Node3D
var facility_touch_id: int = -1
var facility_touch_key: String = ""
var facility_touch_start: Vector2 = Vector2.ZERO
var startup_layer: CanvasLayer
var console_screen: Control
var layout_tools: VBoxContainer
var outline_probe_button: Button
var outline_probe_mode: int = 0
var nexus_material_probe_button: Button
var nexus_material_probe_mode: int = 0
var layout_status: Label
var facility_placement_active: bool = false
var facility_placement_dirty: bool = false
var facility_placement_key: String = ""
var facility_placement_panel: PanelContainer
var facility_placement_status: Label
var facility_placement_actions: Array[Button] = []
var facility_poses: Dictionary = {}
var power_zone: Node3D
var power_distribution: Node3D
var logistics: Node3D
var logistics_creation_status: String = "NOT STARTED"
var logistics_status: Label
var logistics_diagnostic_elapsed: float = 0.0
var power_back_button: Button
var power_view_active: bool = false
var power_camera_tween: Tween
var grid_ui: Control
var grid_placement_active: bool = false
var power_transition_busy: bool = false
var grid_iso_rotation: Vector3 = Vector3.ZERO
var grid_selected_cell: Vector2i = Vector2i(-1, -1)
var grid_selection_mesh: MeshInstance3D
var grid_touch_id: int = -1
var grid_touch_start: Vector2 = Vector2.ZERO
var _frame_budget: RefCounted
var _startup_budget: Variant
var _boot_render_suspended: bool = false
var _boot_previous_disable_3d: bool = false
var _boot_complete: bool = false
var _boot_previous_process_mode: ProcessMode = Node.PROCESS_MODE_INHERIT
var _boot_panels: Array[Dictionary] = []

func _ready() -> void:
    set_meta("sera_graphics_outline_category", "base")
    # Keep the legacy physical corner-ink material disabled; only the
    # same depth-resolved visible mesh-ID compositor as Bittaran may draw ink.
    BaseFacilityInk.set_outlines_enabled(false)
    DisplayProfile.apply(get_window())
    _frame_budget = BaseFrameBudget.new()
    _frame_budget.start(get_viewport())
    BaseClutter.set_preview_layouts(CanonicalProps.site_layouts())
    _load_facility_poses()
    # Show the terminal before the expensive outdoor scene is constructed.
    get_window().go_back_requested.connect(_on_android_back)
    _setup_world()
    _create_camera()
    var returning_from_nexus := get_tree().root.get_node_or_null("NexusExitTransition") != null
    if not returning_from_nexus:
        _create_startup_overlay()
    print("SERA_BASE_BOOT: initial frame ready")
    # Keep the live 2D terminal, but do not draw an incomplete 3D world.
    _startup_budget = StartupBudget.new(get_tree())
    _boot_previous_disable_3d = get_viewport().disable_3d
    get_viewport().disable_3d = true
    _boot_render_suspended = true
    _boot_previous_process_mode = process_mode
    if is_instance_valid(startup_layer):
        startup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    process_mode = Node.PROCESS_MODE_DISABLED
    await _startup_budget.yield_frame()
    await _startup_budget.yield_frame()
    if console_screen != null:
        console_screen.set_cyber_font(LaboSkin.display_font())
    # Decode independent imported resources while the terminal can animate.
    # Keep strong references through construction; get only after LOADED.
    var requests: Array[String] = []
    for path in [WEATHERED_STEEL_PATH, WEATHERED_DECK_PATH, BASE_LOGISTICS_PATH]:
        if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
            requests.append(path)
    var boot_resources: Dictionary = {}
    for path in requests:
        while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            await _startup_budget.yield_frame()
        if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
            boot_resources[path] = ResourceLoader.load_threaded_get(path)
    await _startup_budget.checkpoint("resources")
    await _build_hangar()
    _startup_step("WORLD / FLOOR MATRIX ONLINE", 18)
    await _startup_budget.checkpoint("floor")
    # Electricity is the fixed first occupant; logistics may cross its cords.
    _build_power_board()
    await _startup_budget.checkpoint("power board")
    await _build_power_distribution_startup()
    _startup_step("GRID / POWER ROUTING ONLINE", 21)
    await _startup_budget.checkpoint("power distribution")
    await _build_logistics(boot_resources.get(BASE_LOGISTICS_PATH))
    await BasePowerDistribution.install_protectors_budgeted(power_distribution, logistics, _startup_budget)
    _boot_panels.clear()
    await _build_nexus_building()
    _startup_step("NEXUS / COMMAND LINK ONLINE", 33)
    await _startup_budget.checkpoint("nexus")
    await _build_field_facilities()
    _restore_facility_poses()
    if is_instance_valid(logistics) and logistics.has_method("bind_facility_motion"):
        for key in ["LABO", "SMELTER", "RECYCLER", "STORAGE"]:
            var station: Node3D = _facility_placement_root(key)
            if is_instance_valid(station):
                logistics.call("bind_facility_motion", key, station.get_node_or_null("IndustrialModel/FacilityMotion"))
    _startup_step("SHELL / FACILITY ARRAY ONLINE", 49)
    await _startup_budget.checkpoint("facilities")
    await _create_salvage(CanonicalProps.scrap_layout(), _startup_budget)
    _startup_step("BASE / LOGISTICS AND CABLE PROTECTION ONLINE", 61)
    await _startup_budget.checkpoint("salvage")
    _create_grid_selection()
    _startup_step("GRID / ADDRESS MAP VERIFIED", 67)
    _startup_step("ARCHIVE / SALVAGE INDEXED", 79)
    _create_player()
    _startup_step("SHELL / RIG STANDBY", 86)
    await _startup_budget.checkpoint("player")
    _create_crate()
    await _startup_budget.checkpoint("crate")
    await SharedMaterialShading.apply_to_subtree_budgeted(self, false, _startup_budget)
    var id_outline := SeraViewEdges.new()
    id_outline.name = "ViewEdges"
    add_child(id_outline)
    _startup_step("CRATE / SIGNAL CONFIRMED", 92)
    await _startup_budget.checkpoint("outline registration")
    var name_config := ConfigFile.new()
    if name_config.load(FACILITY_NAME_CONFIG) == OK:
        facility_names_enabled = bool(name_config.get_value("base", "names", true))
    _nexus_shutter_clip = NexusEntryTransition.load_shutter_clip()
    await _startup_budget.checkpoint("shutter audio")
    _create_hud()
    await _startup_budget.checkpoint("HUD")
    # All three worksite rooms are resident before the BASE completion flag.
    # The loading overlay/entry cover stays opaque and normal input disabled.
    await facility_system.call("prewarm_hero_startup", _startup_budget)
    _startup_step("OS / INTERFACE ONLINE", 99)
    SeraSave.mark_location("BASE")
    _restore_boot_rendering()
    # Give the real world and ID compositor a chance to initialize under
    # the terminal before announcing complete; no simulated progress.
    await _startup_budget.yield_frame()
    await _startup_budget.yield_frame()
    _startup_budget.report()
    _startup_step("SYSTEM / BOOT COMPLETE", 100)
    if console_screen != null:
        await Signal(console_screen, &"completion_cut_finished")
    if is_instance_valid(startup_layer):
        startup_layer.queue_free()
    startup_layer = null
    console_screen = null
    _boot_complete = true
    process_mode = _boot_previous_process_mode
    if is_instance_valid(facility_system):
        facility_system.set_process(true)
    _startup_budget = null
    set_meta("sera_base_boot_complete", true)
    print("SERA_BASE_BOOT: COMPLETE")
    if not returning_from_nexus:
        call_deferred("_start_base_bgm")


func _start_base_bgm(fade_in: bool = false) -> void:
    if scene_changing or is_instance_valid(base_bgm_player):
        return
    var music: AudioStreamOggVorbis
    # Raw GitSync asset is playable before the Android editor reimports it.
    if FileAccess.file_exists(BASE_BGM_PATH):
        music = AudioStreamOggVorbis.load_from_file(BASE_BGM_PATH)
    # Exported APKs may contain only the imported resource.
    if music == null and ResourceLoader.exists(BASE_BGM_PATH):
        music = ResourceLoader.load(BASE_BGM_PATH) as AudioStreamOggVorbis
        if music != null:
            music = music.duplicate() as AudioStreamOggVorbis
    if music == null:
        push_warning("SERA BASE BGM: add BGM/scrap_sanctuary_seamless.ogg")
        return
    if music.get_length() <= BASE_BGM_LOOP_OFFSET:
        push_warning("SERA BASE BGM: invalid loop asset duration")
        return
    music.loop = true
    music.loop_offset = BASE_BGM_LOOP_OFFSET
    base_bgm_player = AudioStreamPlayer.new()
    base_bgm_player.name = "BaseBGMScrapSanctuary"
    base_bgm_player.stream = music
    base_bgm_player.volume_db = -60.0 if fade_in else BASE_BGM_VOLUME_DB
    # One persistent player for this BASE scene, including LABO and GRID.
    # Leaving for NEXUS frees the scene/player automatically.
    add_child(base_bgm_player)
    base_bgm_player.play()
    if fade_in:
        var fade := create_tween()
        fade.tween_property(base_bgm_player, "volume_db", BASE_BGM_VOLUME_DB, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _create_startup_overlay() -> void:
    startup_layer = CanvasLayer.new()
    startup_layer.name = "BaseStartupOverlay"
    startup_layer.layer = 100
    add_child(startup_layer)
    var screen := LoadingConsole.new() as Control
    screen.name = "SeraLoadingConsole"
    screen.mouse_filter = Control.MOUSE_FILTER_STOP
    startup_layer.add_child(screen)
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    console_screen = screen


func _startup_step(message: String, completed_percent: int) -> void:
    # Real progress advances ONLY after its work has actually completed.
    print("SERA_BASE_BOOT: %s / %d%%" % [message, completed_percent])
    if console_screen != null:
        console_screen.set_stage(message, completed_percent)


func _setup_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    # Keep BASE muted, but the former nearly-black sky swallowed #17212F ink.
    # Blue-grey sky stays darker than NEXUS and makes silhouette edges visible.
    env.background_color = Color("#607d8f")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#8da6c2")
    env.ambient_light_energy = 0.38
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-56.0, -25.0, 0.0)
    sun.light_energy = 0.36
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
        if WorldMonitors.replaces_screen_marks(str(item[0])):
            continue
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
    WorldMonitors.attach_blockbench(self,name,at,yaw,factor,height_factor,"BASE")

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

func _create_grid_plates(floor: Node3D, budget: Variant = null) -> Array[Dictionary]:
    # An actual nonoverlapping patchwork: long, wide, square and small plates.
    # Six color-batched MultiMeshes still draw the full 255m deck efficiently.
    var tints := [
        Color("#1e2326"), Color("#252729"), Color("#292b2a"),
        Color("#27292c"), Color("#21262a"), Color("#302c29")
    ]
    var sites: Array[Dictionary] = BaseDeckLayout.facility_sites(
        _infrastructure_nexus_origin(), _infrastructure_facility_specs())
    # Preserve the full physical footprint even after an authored yaw change.
    for site in sites:
        var key: String = str(site["id"])
        var yaw: float = BaseArchitecture.facility_yaw_radians(key)+float(facility_poses.get(key,{}).get("yaw",0.0))
        var body: Vector2 = site["physical"]
        var rotated := Vector2(absf(cos(yaw))*body.x+absf(sin(yaw))*body.y,absf(sin(yaw))*body.x+absf(cos(yaw))*body.y)
        var minimum: Vector2 = site["minimum"]
        site["minimum"] = Vector2(maxf(minimum.x,rotated.x+0.8),maxf(minimum.y,rotated.y+0.8))
    # Only pure value data crosses the worker boundary. Capture an
    # independent site array and constants, never a Node or render resource.
    var panels: Array[Dictionary] = []
    var radius: int = PLATE_GRID_RADIUS_CELLS
    var step: float = PLATE_GRID_STEP
    var worker_sites: Array[Dictionary] = sites.duplicate(true)
    if budget != null:
        var worker := Thread.new()
        var task := func(): return BaseDeckLayout.generate_aligned(radius, step, worker_sites)
        if worker.start(task) == OK:
            while worker.is_alive():
                await budget.yield_frame()
            panels = worker.wait_to_finish()
        else:
            panels = BaseDeckLayout.generate_aligned(radius, step, sites)
        await budget.checkpoint("deck partition")
    else:
        panels = BaseDeckLayout.generate_aligned(radius, step, sites)
    # Physically chamfered eight-sided polygonal unit slab, sharing one
    # CPU-side mesh across all existing six floor MultiMesh draw batches.
    var plate_mesh: ArrayMesh = BasePolygon.make("deck")
    var grid_extent: float = float(PLATE_GRID_RADIUS_CELLS) * PLATE_GRID_STEP + 1.50
    var grouped: Array = []
    # One additional batch for the existing atomic facility site slabs.
    # Leave all ordinary patchwork plates and their palette untouched.
    var site_palette: int = tints.size()
    for index in range(tints.size()+1):
        grouped.append([])
    for panel in panels:
        if budget != null:
            await budget.checkpoint("deck groups")
        var center: Vector2 = panel["center"]
        var size: Vector2 = panel["size"]
        var palette_index: int = site_palette if not str(panel["site"]).is_empty() else int(panel["tint"])
        (grouped[palette_index] as Array).append(Transform3D(
            Basis.IDENTITY.scaled_local(Vector3(size.x, 0.30, size.y)),
            Vector3(center.x, -0.18, center.y)))
    # Raw-font boot must work before the SVG importer has generated cache.
    var steel_texture: Texture2D = null
    if ResourceLoader.exists(WEATHERED_STEEL_PATH):
        steel_texture = load(WEATHERED_STEEL_PATH) as Texture2D
    var deck_texture: Texture2D = null
    if ResourceLoader.exists(WEATHERED_DECK_PATH):
        deck_texture = load(WEATHERED_DECK_PATH) as Texture2D
    for palette_index in range(grouped.size()):
        var poses: Array = grouped[palette_index]
        if poses.is_empty():
            continue
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = plate_mesh
        # Explicit culling box: dummy headless renderers cannot read back
        # per-instance transforms. The entire floor remains in the viewport.
        multi.custom_aabb = AABB(
            Vector3(-grid_extent, -0.40, -grid_extent),
            Vector3(grid_extent * 2.0, 0.80, grid_extent * 2.0))
        multi.instance_count = poses.size()
        StaticBake.fill_static_transforms(multi, poses)
        var draw := MultiMeshInstance3D.new()
        draw.name = "GridPlateBatch_%02d" % palette_index
        draw.multimesh = multi
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color.WHITE if palette_index==site_palette else tints[palette_index]
        # Inexpensive precomputed bevel contrast on one shared steel mesh.
        mat.vertex_color_use_as_albedo = true
        mat.metallic = 0.12
        mat.roughness = 0.94
        mat.albedo_texture = steel_texture
        if deck_texture != null:
            mat.albedo_texture = deck_texture
            # Six existing color batches get different crop/scale combinations,
            # reducing the visible repetition of scratches across adjacent slabs.
            mat.uv1_offset = Vector3(
                0.17 * float(palette_index % 3),
                0.21 * float(palette_index / 3), 0.0)
            mat.uv1_scale = Vector3(
                0.93 + 0.07 * float(palette_index % 3),
                0.96 + 0.06 * float(palette_index / 3), 1.0)
        # Keep the six original draw batches and authored SVG/bevels, but
        # apply broad world-space illumination only to their floor surfaces.
        draw.material_override = BaseFloorLighting.worksite_material(false,true) if palette_index==site_palette else BaseFloorLighting.deck_material(mat)
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        floor.add_child(draw)
    return panels

func _build_hangar() -> void:
    # Exterior base: the enclosed Blockbench hangar remains inside the NEXUS menu.
    var bake_path := StaticBake.cache_path("basedeck", [
        "res://scripts/base_exploration.gd", "res://scripts/sera_base_deck_layout.gd",
        "res://scripts/sera_base_floor_detail.gd", "res://scripts/sera_base_polygon_meshes.gd",
        "res://scripts/sera_base_floor_lighting.gd", "res://scripts/sera_base_architecture.gd",
        "res://shaders/sera_base_deck_lighting.gdshader", WEATHERED_STEEL_PATH, WEATHERED_DECK_PATH],
        [facility_poses, _infrastructure_nexus_origin(), _infrastructure_facility_specs()])
    # Do not persist fallback textures before editor import finishes.
    if not ResourceLoader.exists(WEATHERED_STEEL_PATH) or not ResourceLoader.exists(WEATHERED_DECK_PATH):
        bake_path = ""
    var floor: Node3D = await StaticBake.load_scene_budgeted(bake_path, "PatchworkSteelFloor", _startup_budget)
    if floor != null:
        add_child(floor)
    else:
        floor = Node3D.new()
        floor.name = "PatchworkSteelFloor"
        add_child(floor)
        # The dark one-piece ground remains visible only in the 0.06 m seams.
        _box(floor, "ContinuousGround", Vector3(0.0, -0.21, 0.0),
            Vector3(256.0, 0.30, 256.0), Color("#12171b"))
        var panels: Array[Dictionary] = await _create_grid_plates(floor,_startup_budget)
        _boot_panels = panels
        await BaseFloorDetail.decorate(floor, panels, _startup_budget)
        StaticBake.save_scene(bake_path, floor)
    # Two small instanced batches: facility contact shade and floor bounce.
    # They are separate FX and never enter the visible-mesh-ID outline pass.
    BaseFloorLighting.add_floor_accents(
        floor, _infrastructure_nexus_origin(), _infrastructure_facility_specs(), facility_poses)
    # Keep legacy decorative models away from interactive equipment footprints.
    # Decorative Blockbench props occupy the frame edges, never machinery
    # foundations or raw touch pick volumes in the orthographic composition.
    _add_module("maintenance_canopy", Vector3(-20.2, 0.0, -13.6), deg_to_rad(19.0), 0.62)
    _add_module("kiosk", Vector3(-4.0, 0.0, -22.5), deg_to_rad(-15.0), 0.85)
    _add_module("data_bank", Vector3(22.0, 0.0, -9.0), deg_to_rad(24.0), 0.52)
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    for palette_index in batches.keys():
        var poses: Array = batches[palette_index]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = cube
        multi.instance_count = poses.size()
        for index in range(poses.size()):
            await _startup_budget.checkpoint("floor instances")
            multi.set_instance_transform(index, poses[index])
        var draw := MultiMeshInstance3D.new()
        draw.name = "BaseBlockbenchBatch_%02d" % int(palette_index)
        draw.set_meta("sera_outline_role", "clutter")
        draw.multimesh = multi
        draw.material_override = _material(int(palette_index))
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(draw)


func _build_nexus_building() -> void:
    # Rebuilt physical architecture retains the exact 3D screen-picking extents.
    nexus_building = Node3D.new()
    nexus_building.name = "NEXUSBuilding"
    nexus_building.set_meta("sera_outline_role", "facility")
    nexus_building.position = NEXUS_BUILDING_ORIGIN
    add_child(nexus_building)
    var foundation: MeshInstance3D = _box(nexus_building, "Foundation", Vector3(0, 0.23, 0),
        Vector3(6.4, 0.46, 5.4), Color("#46535c"))
    foundation.rotation.y = BaseArchitecture.facility_yaw_radians("NEXUS")
    await BaseArchitecture.build_nexus(nexus_building, _startup_budget)
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
    facility_system.set("defer_startup_build", true)
    add_child(facility_system)
    facility_system.set_process(false)
    await facility_system.call("build_startup", _startup_budget)
    facility_system.connect("power_board_requested", Callable(self, "_enter_power_board"))

func _build_power_board() -> void:
    # 8×8 stage is a connected physical extension of the existing BASE.
    power_zone = PowerBoard.build(self)


# Use the same saved facility positions as the models, before they are built.
func _infrastructure_nexus_origin() -> Vector3:
    return facility_poses.get("NEXUS", {}).get("position", NEXUS_BUILDING_ORIGIN)

func _infrastructure_facility_specs() -> Array:
    var specs: Array = BaseFacilities.FACILITY_SPECS.duplicate(true)
    for spec in specs:
        var key: String = str(spec["id"])
        if facility_poses.has(key):
            spec["at"] = facility_poses[key]["position"]
    return specs

func _build_power_distribution_startup() -> void:
    if is_instance_valid(power_distribution):
        power_distribution.free()
    power_distribution = await BasePowerDistribution.build_budgeted(
        self, _infrastructure_nexus_origin(), _infrastructure_facility_specs(), cam, null, _startup_budget)


func _build_logistics(cached_script: Variant = null) -> void:
    if is_instance_valid(logistics):
        logistics.free()
    logistics_creation_status = "SCRIPT LOAD"
    # Optional logistics must not be a compile-time dependency of the BASE.
    # Call Script resource methods on the resource, not on its class symbol.
    var logistics_script: Variant = cached_script
    if logistics_script == null:
        logistics_script = ResourceLoader.load(BASE_LOGISTICS_PATH, "GDScript")
    if not (logistics_script is GDScript):
        logistics_creation_status = "SCRIPT LOAD FAILED"
        push_error("SERA_BASE_LOGISTICS: script load failed")
        return
    logistics_creation_status = "SCRIPT CHECK"
    if not logistics_script.can_instantiate():
        logistics_creation_status = "SCRIPT INVALID"
        push_error("SERA_BASE_LOGISTICS: script cannot instantiate")
        return
    logistics_creation_status = "NEW"
    var instance: Variant = logistics_script.new()
    logistics = instance as Node3D
    if not is_instance_valid(logistics):
        logistics_creation_status = "NEW FAILED"
        push_error("SERA_BASE_LOGISTICS: script new returned no node")
        return
    logistics_creation_status = "NODE CREATED"
    logistics.name = "BaseLogistics"
    logistics.set_meta("sera_outline_role", "clutter")
    add_child(logistics)
    await logistics.call("setup", self, _infrastructure_nexus_origin(),
        _infrastructure_facility_specs(), power_distribution, CRATE_WAYPOINTS, cam, _startup_budget)
    _startup_step("BASE / LOGISTICS MODELS", 26)
    await _startup_budget.checkpoint("logistics routes")
    # Independent calls keep the carrier rendering available if route or
    # dock construction aborts. The on-screen report identifies that stage.
    await logistics.call("ensure_parked_fleet", BaseFacilities.FACILITY_SPECS, _startup_budget)
    await logistics.call("build_carriers", _startup_budget)
    await _startup_budget.checkpoint("carriers")
    await logistics.call("build_docks_and_motion", _startup_budget)
    logistics_creation_status = "NODE ATTACHED"


func _create_grid_selection() -> void:
    # One transparent border-like marker; no permanent machines are spawned.
    grid_selection_mesh = MeshInstance3D.new()
    grid_selection_mesh.name = "SelectedGridCellPreview"
    var marker := BoxMesh.new()
    marker.size = Vector3(1.18, 0.016, 1.18)
    grid_selection_mesh.mesh = marker
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.51, 0.83, 0.91, 0.26)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    grid_selection_mesh.material_override = material
    grid_selection_mesh.visible = false
    power_zone.add_child(grid_selection_mesh)

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

func _create_salvage(replacement: Array[Dictionary] = [], budget: Variant = null) -> void:
    # Loose salvage is not a set of box-shaped machines. Keep the 16 stable
    # world anchors for layout/navigation tests, and draw all geometry through
    # ONE shared material-batched procedural model (low-cost on Android).
    var lots := [
        Vector3(-9.83, 0.0, 0.28), Vector3(6.80, 0.0, 19.56),
        Vector3(-1.60, 0.0, 0.60), Vector3(14.96, 0.0, 14.72),
        Vector3(4.80, 0.0, -11.02), Vector3(20.54, 0.0, 10.41),
        Vector3(-5.42, 0.0, -8.18), Vector3(5.71, 0.0, -7.88),
        Vector3(-7.21, 0.0, 6.65), Vector3(3.00, 0.0, -0.80),
        Vector3(-13.41, 0.0, -11.38), Vector3(4.90, 0.0, -17.16),
        Vector3(-13.50, 0.0, 3.82), Vector3(12.87, 0.0, 0.48),
        Vector3(5.21, 0.0, 10.48), Vector3(-3.20, 0.0, -18.15)
    ]
    var salvage := Node3D.new()
    salvage.name = "SalvageMeshes"
    salvage.set_meta("sera_outline_role", "clutter")
    add_child(salvage)
    var g := BaseArchitecture.Batch.new(salvage)
    var occupied: Array[Vector2] = []
    for i in range(lots.size()):
        if budget != null:
            await budget.checkpoint("scrap heap")
        var pile := Node3D.new()
        pile.name = "ScrapPile_%02d" % i
        var center: Vector3 = lots[i]
        var heading: float = float(-26 + posmod(i * 23 + 7, 55))
        var scale_factor: float = 1.26
        var stack_count: int = 1 + posmod(i, 8)
        var pile_pattern: int = posmod(i * 3 + 1, 4)
        if replacement.size() == lots.size():
            var sample: Dictionary = replacement[i]
            center = Vector3(float(sample["x"]), 0.0, float(sample["z"]))
            heading = float(sample["yaw_deg"])
            scale_factor = float(sample["scale"])
            stack_count = clampi(int(sample.get("stack", stack_count)), 1, 8)
            pile_pattern = posmod(int(sample.get("pattern", pile_pattern)), 4)
        else:
            # Preserve the existing authored first-boot anchors unchanged.
            var nearest: float = center.distance_to(nexus_building.position)
            for station in facility_system.get_children():
                if station is Node3D:
                    nearest = minf(nearest,
                        center.distance_to((station as Node3D).position))
            if nearest < 4.0:
                scale_factor = 1.12
            elif nearest < 7.0:
                scale_factor = 1.20
        if replacement.size() != lots.size() and (is_instance_valid(logistics) or not facility_poses.is_empty()):
            var safe: Vector2
            if budget != null:
                safe = await BaseLayoutPreview.reserve_salvage_budgeted(
                    Vector2(center.x, center.z), 1.15 * scale_factor,
                    NEXUS_BUILDING_ORIGIN, BaseFacilities.FACILITY_SPECS, logistics, occupied, budget, facility_poses)
            else:
                safe = BaseLayoutPreview.reserve_salvage(
                    Vector2(center.x, center.z), 1.15 * scale_factor,
                    NEXUS_BUILDING_ORIGIN, BaseFacilities.FACILITY_SPECS, logistics, occupied, facility_poses)
            if not safe.is_finite():
                pile.free()
                continue
            center = Vector3(safe.x, 0.0, safe.y)
        occupied.append(Vector2(center.x, center.z))
        pile.position = center
        pile.rotation.y = deg_to_rad(heading)
        pile.set_meta("scrap_profile", posmod(i, JunkGeometry.SCRAP_PROFILES))
        pile.set_meta("visual_scale", scale_factor)
        pile.set_meta("stack", stack_count)
        pile.set_meta("pattern", pile_pattern)
        add_child(pile)
        # Scale about the deck surface, never world Y=0. This keeps the
        # underside of every independent heap in contact with the plate.
        g.pivot = Vector3(center.x, JunkGeometry.BASE_DECK_SURFACE_Y, center.z)
        g.yaw = pile.rotation.y
        g.detail_scale = scale_factor
        JunkGeometry.scrap_heap(g, center, i, stack_count, pile_pattern)
    # One shared opaque MultiMesh per actual geometry/material type, not
    # hundreds of MeshInstance3D nodes or per-frame random CPU rebuilds.
    if budget != null:
        await g.flush(budget)
    else:
        g.flush()

func _create_player() -> void:
    player = Node3D.new()
    player.name = "SERA"
    player.set_meta("sera_graphics_outline_category", "character")
    player.position = Vector3(0.0, PLAYER_Y, 5.6)
    add_child(player)
    player.visible = HUB_SERA_CONTROLS_ENABLED
    if not HUB_SERA_CONTROLS_ENABLED:
        # Preserve the invisible anchor for the camera but avoid loading the
        # expensive character rig into this menu scene.
        return
    # Avoid loading the full combat rig and its script graph for a disabled
    # outdoor player. This was an unnecessary startup-time preload.
    var rig_script: Script = load(SERA_RIG_PATH) as Script
    if rig_script == null:
        push_error("SERA base: character script could not load")
        return
    rig = rig_script.new() as Node3D
    if rig == null:
        push_error("SERA base: character rig could not instantiate")
        return
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
    crate.set_meta("sera_graphics_outline_category", "character")
    crate.position = Vector3(3.30, 0.06, 2.40)
    crate.rotation.y = -0.5
    add_child(crate)
    # CRATE is a character: universal visible-ID 4/0/2, no convex ink.
    var ink := SeraViewEdges.new()
    ink.name = "ViewEdges"
    crate.add_child(ink)

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
    var turn := Basis(Vector3.UP, BaseArchitecture.facility_yaw_radians("NEXUS"))
    for x in [-3.25, 3.25]:
        for y in [0.0, 4.9]:
            for z in [-2.8, 2.8]:
                var vertex: Vector3 = nexus_building.to_global(turn * Vector3(x, y, z))
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
    # Preserve the 9:16 horizontal footprint and add world above/below.
    cam.size = BASE_ORTHO_SIZE * DisplayProfile.height_factor(
        get_viewport().get_visible_rect().size)
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
    layer.layer = 2 # Shared mesh-ID contour at layer 1, HUD above it.
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
    _create_layout_tools()
    _create_facility_placement_panel()
    _create_power_controls()
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
    if layout_tools != null:
        layout_tools.position = Vector2(view.x - 168.0, 14.0)
        layout_tools.size = Vector2(156.0, 440.0)
    if grid_ui != null:
        grid_ui.call("reflow", view)
    if power_back_button != null:
        power_back_button.position = Vector2(
            minf(284.0, maxf(224.0, view.x * 0.66)) + 18.0, 25.0)
        power_back_button.size = Vector2(46.0, 56.0)
    stick_outer.position = Vector2(view.x - 180, view.y - 194)
    stick_outer.size = Vector2(164, 164)
    stick_knob.size = Vector2(72, 72)
    _update_stick_visual()
    _refresh_facility_names()

# Project actual solid model geometry rather than the smaller tap-picking volume.
# Called only for layout/viewport changes, not every idle BASE frame.
func _name_project_box(bounds: AABB, pose: Transform3D, points: Array[Vector2]) -> void:
    for i in range(8):
        var vertex: Vector3 = pose * bounds.get_endpoint(i)
        if not cam.is_position_behind(vertex):
            points.append(cam.unproject_position(vertex))

func _facility_projected_points(root_node: Node3D, key: String,
        include_motion_envelope: bool) -> Array[Vector2]:
    var points: Array[Vector2] = []
    # The architecture batches contain both structural geometry and peripheral
    # decorative props; retain the building and its emissive solid details.
    var architecture: Node = root_node.get_node_or_null(
        "NexusArchitecture" if key == "NEXUS" else "IndustrialModel")
    if architecture != null:
        for child in architecture.get_children():
            if child is MultiMeshInstance3D:
                var draw := child as MultiMeshInstance3D
                var multi: MultiMesh = draw.multimesh
                if multi == null or multi.mesh == null or not draw.visible:
                    continue
                var bounds: AABB = multi.mesh.get_aabb()
                for i in range(multi.instance_count):
                    if multi.use_custom_data and draw.has_meta("sera_outline_instanced_roles"):
                        if absf(multi.get_instance_custom_data(i).r - 0.375) < 0.04:
                            continue
                    _name_project_box(bounds,
                        draw.global_transform * multi.get_instance_transform(i), points)
                # LABO's authored culling envelope contains the moving SCARA arm
                # and transferred payload even at their extreme positions.
                if include_motion_envelope and key == "LABO" and multi.custom_aabb.size.length_squared() > 0.0:
                    _name_project_box(multi.custom_aabb, draw.global_transform, points)
            elif child is MeshInstance3D:
                var solid := child as MeshInstance3D
                if solid.visible and solid.mesh != null:
                    _name_project_box(solid.mesh.get_aabb(), solid.global_transform, points)
    var foundation := root_node.get_node_or_null("Foundation") as MeshInstance3D
    if foundation != null and foundation.mesh != null:
        _name_project_box(foundation.mesh.get_aabb(), foundation.global_transform, points)
    return points

func _name_model_bounds(root_node: Node3D, key: String) -> Rect2:
    var points: Array[Vector2] = _facility_projected_points(root_node, key, true)
    if points.is_empty():
        return Rect2()
    var result := Rect2(points[0], Vector2.ZERO)
    for point in points:
        result = result.expand(point)
    # Leave room for contours and the collector's sweeping articulated crane.
    return result.grow(28.0 if key == "SCRAP_COLLECTOR" else 8.0)

# The existing GPU visible-ID compositor reads this overview state.
func is_facility_selection_outline_visible() -> bool:
    return is_instance_valid(hud) and is_instance_valid(facility_system) and (
        not scene_changing and not power_view_active and not power_transition_busy
        and not bool(facility_system.call("is_menu_open")))

func _name_rect_free(candidate: Rect2, safe: Rect2, occupied: Array[Rect2]) -> bool:
    if not safe.encloses(candidate):
        return false
    for blocked in occupied:
        if candidate.intersects(blocked):
            return false
    return true

func _refresh_facility_names() -> void:
    if cam == null or hud == null or nexus_tag == null or facility_system == null:
        return
    var tags: Dictionary = facility_system.get("facility_tags")
    var nodes: Dictionary = facility_system.get("facility_nodes")
    var entries: Array[Dictionary] = [{"key": "NEXUS", "tag": nexus_tag,
        "root": nexus_building}]
    for spec in BaseFacilities.FACILITY_SPECS:
        var key: String = str(spec["id"])
        entries.append({"key": key, "tag": tags.get(key), "root": nodes.get(key)})
    var show_names: bool = facility_names_enabled and not power_view_active and (
        not power_transition_busy) and not bool(facility_system.call("is_menu_open"))
    for entry in entries:
        var tag: Label = entry["tag"] as Label
        if tag != null:
            tag.hide()
    if not show_names or hud.size.x < 40.0 or hud.size.y < 200.0:
        return
    var safe := Rect2(Vector2(8.0, 90.0),
        Vector2(hud.size.x - 16.0, hud.size.y - 200.0))
    var occupied: Array[Rect2] = []
    if layout_tools != null:
        occupied.append(Rect2(layout_tools.position, layout_tools.size).grow(5.0))
    var models: Dictionary = {}
    for entry in entries:
        var root_node: Node3D = entry["root"] as Node3D
        if root_node == null:
            continue
        var key: String = str(entry["key"])
        var bounds: Rect2 = _name_model_bounds(root_node, key)
        if bounds.has_area():
            models[key] = bounds
            occupied.append(bounds)
    for entry in entries:
        var key: String = str(entry["key"])
        var tag: Label = entry["tag"] as Label
        if tag == null or not models.has(key):
            continue
        var bounds: Rect2 = models[key]
        if not bounds.intersects(Rect2(Vector2.ZERO, hud.size)):
            continue
        var minimum: Vector2 = tag.get_combined_minimum_size()
        var extent := Vector2(maxf(minimum.x, clampf(
            30.0 + float(tag.text.length()) * 18.0, 96.0, 172.0)),
            maxf(28.0, minimum.y))
        if extent.x > safe.size.x or extent.y > safe.size.y:
            continue
        var center: Vector2 = bounds.get_center()
        var anchors: Array[Vector2] = [
            Vector2(center.x - extent.x * 0.5, bounds.position.y - extent.y - 6.0),
            Vector2(center.x - extent.x * 0.5, bounds.end.y + 6.0),
            Vector2(bounds.position.x - extent.x - 6.0, center.y - extent.y * 0.5),
            Vector2(bounds.end.x + 6.0, center.y - extent.y * 0.5)]
        var chosen := Rect2()
        # Prefer the space directly above. If blocked, try nearby gaps around
        # the other sides; never force a label over a neighboring 3D model.
        for radius in [0.0, 18.0, 36.0, 54.0, 72.0, 96.0, 120.0]:
            for anchor in anchors:
                for direction in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT,
                        Vector2.UP, Vector2.DOWN]:
                    var pos: Vector2 = anchor + direction * float(radius)
                    pos = pos.clamp(safe.position, safe.end - extent)
                    var candidate := Rect2(pos, extent)
                    if _name_rect_free(candidate, safe, occupied):
                        chosen = candidate
                        break
                if chosen.has_area():
                    break
            if chosen.has_area():
                break
        if chosen.has_area():
            tag.position = chosen.position
            tag.size = chosen.size
            tag.show()
            occupied.append(chosen.grow(4.0))

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

func _create_layout_tools() -> void:
    layout_tools = VBoxContainer.new()
    layout_tools.name = "LayoutTools"
    layout_tools.mouse_filter = Control.MOUSE_FILTER_PASS
    layout_tools.add_theme_constant_override("separation", 5)
    hud.add_child(layout_tools)
    facility_name_button = _layout_tool_button(
        "設備名称：ON" if facility_names_enabled else "設備名称：OFF",
        "FacilityNameToggle", _toggle_facility_names)
    _layout_tool_button("正規配置", "BaseFacilityPlacement", _open_facility_placement)
    outline_probe_button = _layout_tool_button(
        "輪郭ID：状態", "OutlineProbeButton", _cycle_outline_probe)
    nexus_material_probe_button = _layout_tool_button(
        "NEXUS材質：通常", "NexusMaterialProbeButton",
        _cycle_nexus_material_probe)
    layout_status = Label.new()
    layout_status.name = "LayoutStatus"
    layout_status.text = "VISIBLE-ID / ON"
    layout_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    layout_status.add_theme_font_override("font", LaboSkin.ui_font())
    layout_status.add_theme_font_size_override("font_size", 11)
    layout_status.add_theme_color_override("font_color", Color("#a7c4d3"))
    layout_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layout_tools.add_child(layout_status)
    logistics_status = Label.new()
    logistics_status.name = "LogisticsStatus"
    logistics_status.text = _base_diagnostic_text()
    logistics_status.add_theme_font_override("font", LaboSkin.ui_font())
    logistics_status.add_theme_font_size_override("font_size", 13)
    logistics_status.add_theme_color_override("font_color", Color("#b9dbe8"))
    logistics_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    logistics_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    layout_tools.add_child(logistics_status)


func _facility_placement_id(key: String) -> String:
    return "base/facility/" + key


func _load_facility_poses() -> void:
    facility_poses.clear()
    for key in BaseLayoutPreview.KEYS:
        var record: Dictionary = PlacementStore.read(_facility_placement_id(str(key)))
        if str(record.get("space", "")) != "base_local":
            continue
        var raw: Variant = record.get("position")
        if not (raw is Array) or raw.size() != 3:
            continue
        var p: Vector3 = PlacementStore.vec(raw)
        var yaw: float = float(record.get("yaw_rad", 0.0))
        if p.is_finite() and is_finite(yaw):
            p.y = 0.0
            facility_poses[key] = {"position": p, "yaw": yaw}


func _facility_placement_root(key: String) -> Node3D:
    if key == "NEXUS":
        return nexus_building
    if not is_instance_valid(facility_system):
        return null
    var nodes: Dictionary = facility_system.get("facility_nodes")
    return nodes.get(key) as Node3D


func _restore_facility_poses() -> void:
    for key in facility_poses:
        var root_node: Node3D = _facility_placement_root(str(key))
        if root_node == null:
            continue
        var pose: Dictionary = facility_poses[key]
        root_node.position = pose["position"]
        root_node.rotation.y = float(pose["yaw"])


func _create_facility_placement_panel() -> void:
    facility_placement_panel = PanelContainer.new()
    facility_placement_panel.name = "BaseFacilityPlacementPanel"
    facility_placement_panel.theme = LaboSkin.common_theme()
    facility_placement_panel.add_theme_stylebox_override("panel", LaboSkin.panel_style())
    hud.add_child(facility_placement_panel)
    facility_placement_panel.anchor_left = 0.025
    facility_placement_panel.anchor_right = 0.975
    facility_placement_panel.anchor_top = 1.0
    facility_placement_panel.anchor_bottom = 1.0
    facility_placement_panel.offset_top = -245.0
    facility_placement_panel.offset_bottom = -8.0
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    facility_placement_panel.add_child(column)
    facility_placement_status = Label.new()
    facility_placement_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    facility_placement_status.add_theme_font_override("font", LaboSkin.ui_font())
    facility_placement_status.add_theme_font_size_override("font_size", 18)
    column.add_child(facility_placement_status)
    for row_data in [
        ["prev", "前の施設", "next", "次の施設"],
        ["zminus", "↑ Z−", "zplus", "↓ Z＋", "xminus", "← X−", "xplus", "→ X＋"],
        ["left", "↶ 回転", "right", "↷ 回転"],
        ["copy", "配置コピー", "exit", "編集終了"]]:
        var row := HBoxContainer.new()
        column.add_child(row)
        for i in range(0, row_data.size(), 2):
            var action: String = row_data[i]
            var button := Button.new()
            button.text = str(row_data[i + 1])
            button.focus_mode = Control.FOCUS_NONE
            button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            button.custom_minimum_size.y = 44.0
            button.add_theme_font_override("font", LaboSkin.ui_font())
            button.add_theme_font_size_override("font_size", 17)
            row.add_child(button)
            button.pressed.connect(_facility_placement_action.bind(action))
            if action in ["zminus", "zplus", "xminus", "xplus", "left", "right"]:
                facility_placement_actions.append(button)
    facility_placement_panel.hide()


func _open_facility_placement() -> void:
    if facility_placement_active or scene_changing or power_view_active or power_transition_busy:
        return
    if facility_system == null or bool(facility_system.call("is_menu_open")):
        return
    facility_placement_active = true
    facility_placement_dirty = false
    facility_placement_key = ""
    nexus_touch_id = -1
    facility_touch_id = -1
    facility_touch_key = ""
    touch_id = -1
    mouse_steering = false
    joystick = Vector2.ZERO
    layout_tools.hide()
    facility_placement_panel.show()
    _refresh_facility_placement()


func _refresh_facility_placement() -> void:
    var root_node: Node3D = _facility_placement_root(facility_placement_key)
    for button in facility_placement_actions:
        button.disabled = root_node == null
    if root_node == null:
        facility_placement_status.text = "施設をタップして選択 / XZ・回転のみ"
        return
    var p: Vector3 = root_node.position
    facility_placement_status.text = "%s  X %.2f / Z %.2f / 回転 %.1f°" % [
        facility_placement_key, p.x, p.z, root_node.rotation_degrees.y]


func _refresh_canonical_floor() -> void:
    var floor := get_node_or_null("PatchworkSteelFloor") as Node3D
    if not is_instance_valid(floor):
        return
    # No per-frame rebuild and no startup budget dependency at runtime.
    # Keep the dark continuous backing and replace only generated surfaces.
    for child in floor.get_children():
        if child.name!="ContinuousGround":
            child.free()
    var panels: Array[Dictionary] = await _create_grid_plates(floor)
    await BaseFloorDetail.decorate(floor,panels)
    BaseFloorLighting.add_floor_accents(floor,_infrastructure_nexus_origin(),_infrastructure_facility_specs(),facility_poses)
    SharedMaterialShading.apply_to_subtree(floor)

func _close_facility_placement() -> void:
    if not facility_placement_active:
        return
    facility_placement_active = false
    facility_placement_panel.hide()
    layout_tools.show()
    PlacementStore.flush()
    # Rebuild only the floor after an edit, never the approved facility,
    # props, power infrastructure or bound logistics animation nodes.
    if facility_placement_dirty:
        _refresh_canonical_floor()
    facility_placement_dirty = false
    facility_placement_key = ""
    _refresh_facility_names()


func _facility_placement_action(action: String) -> void:
    if not facility_placement_active:
        return
    if action == "exit":
        _close_facility_placement()
        return
    if action == "copy":
        var records: Dictionary = {}
        for key in facility_poses:
            records[_facility_placement_id(str(key))] = PlacementStore.read(_facility_placement_id(str(key)))
        DisplayServer.clipboard_set("BASE_FACILITY_CANONICAL_PLACEMENT\\n" + JSON.stringify(records, "  "))
        facility_placement_status.text = "配置コピー完了"
        return
    if action in ["prev", "next"]:
        var keys: Array = BaseLayoutPreview.KEYS
        var index: int = keys.find(facility_placement_key)
        if index < 0:
            index = 0 if action == "next" else keys.size() - 1
        else:
            index = posmod(index + (1 if action == "next" else -1), keys.size())
        facility_placement_key = str(keys[index])
        _refresh_facility_placement()
        return
    var root_node: Node3D = _facility_placement_root(facility_placement_key)
    if root_node == null:
        return
    match action:
        "xminus":
            root_node.position.x -= 0.25
        "xplus":
            root_node.position.x += 0.25
        "zminus":
            root_node.position.z -= 0.25
        "zplus":
            root_node.position.z += 0.25
        "left":
            root_node.rotation.y = wrapf(root_node.rotation.y - deg_to_rad(5.0), -PI, PI)
        "right":
            root_node.rotation.y = wrapf(root_node.rotation.y + deg_to_rad(5.0), -PI, PI)
        _:
            return
    facility_poses[facility_placement_key] = {"position": root_node.position, "yaw": root_node.rotation.y}
    PlacementStore.stage(_facility_placement_id(facility_placement_key), {
        "space": "base_local", "position": PlacementStore.array3(root_node.position),
        "yaw_rad": root_node.rotation.y})
    PlacementStore.flush()
    facility_placement_dirty = true
    _refresh_facility_placement()
    _refresh_facility_names()


func _facility_placement_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _close_facility_placement()
        get_viewport().set_input_as_handled()
        return
    var point: Vector2
    if event is InputEventScreenTouch and event.pressed:
        point = event.position
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        point = event.position
    else:
        return
    if facility_placement_panel.get_global_rect().has_point(point):
        return # Native GUI button input.
    facility_placement_key = "NEXUS" if _nexus_hit(point) else str(facility_system.call("key_at", cam, point))
    _refresh_facility_placement()
    get_viewport().set_input_as_handled()


func _base_diagnostic_text() -> String:
    var report: String = str(logistics.call("diagnostic_text")) if is_instance_valid(logistics) else "物流 " + logistics_creation_status
    var cable_status: String = str(power_distribution.get_meta("cable_status", "未生成")) if is_instance_valid(power_distribution) else "未生成"
    return report + "\n配線 " + cable_status


func _toggle_facility_names() -> void:
    facility_names_enabled = not facility_names_enabled
    facility_name_button.text = "設備名称：ON" if facility_names_enabled else "設備名称：OFF"
    var config := ConfigFile.new()
    config.set_value("base", "names", facility_names_enabled)
    if config.save(FACILITY_NAME_CONFIG) != OK:
        push_warning("BASE facility name preference could not be saved")
    _refresh_facility_names()


func _cycle_outline_probe() -> void:
    # The diagnostic uses the production ID compositor only. It MUST NOT
    # reactivate a different polygon-edge/crease shader.
    if scene_changing or power_view_active or (
            facility_system != null and bool(facility_system.call("is_menu_open"))):
        return
    outline_probe_mode = (outline_probe_mode + 1) % 3
    var compositor: Node = get_viewport().get_node_or_null(
        "SeraIDOutlineLayer/SeraIDOutlineControl")
    if not is_instance_valid(compositor):
        layout_status.text = "VISIBLE-ID / OFF"
        return
    var info: Dictionary = compositor.call("get_outline_metrics")
    var dims: Vector2i = info.get("id_target_size", Vector2i.ZERO)
    match outline_probe_mode:
        0:
            outline_probe_button.text = "輪郭ID：状態"
            layout_status.text = ("ID / ON" if bool(
                info.get("overlay_visible", false)) else "ID / OFF")
        1:
            outline_probe_button.text = "輪郭ID：解像度"
            layout_status.text = "%d×%d" % [dims.x, dims.y]
        2:
            outline_probe_button.text = "輪郭ID：複製"
            layout_status.text = "ID MESH %d" % int(info.get("id_copies", 0))


func _cycle_nexus_material_probe() -> void:
    # Five *manual* visual views isolate where BASE NEXUS loses contrast.
    # Only authored NEXUS MultiMesh materials are affected. No GPU image
    # readback, CI, automated verification or additional render target.
    if scene_changing or power_view_active or (
            facility_system != null and bool(facility_system.call("is_menu_open"))):
        return
    var nexus_root: Node = (
        nexus_building.get_node_or_null("NexusArchitecture")
        if is_instance_valid(nexus_building) else null)
    if not is_instance_valid(nexus_root):
        return
    nexus_material_probe_mode = (nexus_material_probe_mode + 1) % 5
    var names: Array[String] = [
        "通常", "色のみ", "テクスチャ", "頂点色", "陰影なし"]
    var altered: int = 0
    var skipped_emissive: int = 0
    for node in nexus_root.get_children():
        var draw: MultiMeshInstance3D = node as MultiMeshInstance3D
        if not is_instance_valid(draw):
            continue
        var authored: StandardMaterial3D = draw.get_meta(
            "sera_base_authored_material", null) as StandardMaterial3D
        if authored == null:
            continue
        # Emissive screens/lights stay exactly as authored in every mode.
        if authored.emission_enabled:
            skipped_emissive += 1
            continue
        if nexus_material_probe_mode == 0:
            draw.material_override = authored
        else:
            var diagnostic: StandardMaterial3D = (
                authored.duplicate() as StandardMaterial3D)
            diagnostic.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            if nexus_material_probe_mode == 1:
                # Raw authored material tint; ignore weathered SVG and vertex.
                diagnostic.albedo_texture = null
                diagnostic.vertex_color_use_as_albedo = false
            elif nexus_material_probe_mode == 2:
                # Raw SVG/UV only, before tint, vertex and scene lighting.
                diagnostic.albedo_color = Color.WHITE
                diagnostic.vertex_color_use_as_albedo = false
            elif nexus_material_probe_mode == 3:
                # SurfaceTool polygons include vertex colors. BoxMesh and
                # CylinderMesh do not; forcing the channel on these rendered
                # most of NEXUS black, misleading the previous diagnosis.
                # A primitive instead appears neutral white here.
                diagnostic.albedo_color = Color.WHITE
                diagnostic.albedo_texture = null
                diagnostic.vertex_color_use_as_albedo = bool(
                    draw.get_meta("sera_base_has_vertex_color", false))
            # Mode 4 uses authored tint + SVG with lighting disabled;
            # NEXUS no longer multiplies by extra vertex paint.
            draw.material_override = diagnostic
        altered += 1
    nexus_material_probe_button.text = (
        "NEXUS材質：" + names[nexus_material_probe_mode])
    layout_status.text = "MAT %d/4 | %d batches" % [
        nexus_material_probe_mode, altered]
    print("SERA_NEXUS_MATERIAL_DIAG mode=%d label=%s batches=%d emissive=%d" %
        [nexus_material_probe_mode, names[nexus_material_probe_mode],
        altered, skipped_emissive])


func _layout_tool_button(caption: String, identifier: String,
        callback: Callable) -> Button:
    var button := Button.new()
    button.name = identifier
    button.text = caption
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.custom_minimum_size = Vector2(156.0, 44.0)
    button.add_theme_font_override("font", LaboSkin.ui_font())
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", Color("#e2edf2"))
    var flat := StyleBoxFlat.new()
    flat.bg_color = Color("#162b39")
    flat.border_color = Color("#55798a")
    flat.set_border_width_all(1)
    flat.set_corner_radius_all(0)
    button.add_theme_stylebox_override("normal", flat)
    var highlighted: StyleBoxFlat = flat.duplicate() as StyleBoxFlat
    highlighted.bg_color = Color("#31566b")
    button.add_theme_stylebox_override("pressed", highlighted)
    button.add_theme_stylebox_override("hover", highlighted)
    button.pressed.connect(callback)
    layout_tools.add_child(button)
    return button


func _layout_control_hit(at: Vector2) -> bool:
    return layout_tools != null and layout_tools.is_visible_in_tree() and (
        Rect2(layout_tools.position, layout_tools.size).has_point(at))


func _restore_boot_rendering() -> void:
    if _boot_render_suspended:
        get_viewport().disable_3d = _boot_previous_disable_3d
        _boot_render_suspended = false

func _exit_tree() -> void:
    PlacementStore.flush()
    _restore_boot_rendering()
    if _frame_budget != null:
        _frame_budget.stop()
    BaseClutter.clear_preview()


func _create_power_controls() -> void:
    # Big chamfered BASE/GRID plates are drawn in the shared SERA skin;
    # the changeover is animated separately from the 3D camera movement.
    hud_title.visible = false
    grid_ui = GridUi.new()
    hud.add_child(grid_ui)
    grid_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    grid_ui.connect("node_chosen", Callable(self, "_grid_node_chosen"))
    grid_ui.connect("operation_changed", Callable(self, "_grid_operation_changed"))
    # The BASE/GRID plate must not overdraw the LABO's own title tabs.
    # Observe the modal directly instead of polling its visibility every frame.
    var facility_modal: Control = facility_system.get("modal") as Control
    if facility_modal != null:
        facility_modal.visibility_changed.connect(_sync_base_grid_plate_visibility)
    _sync_base_grid_plate_visibility()
    power_back_button = Button.new()
    power_back_button.name = "PowerBoardBack"
    power_back_button.text = "‹"
    power_back_button.focus_mode = Control.FOCUS_NONE
    power_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
    power_back_button.add_theme_font_override("font", LaboSkin.title_font())
    power_back_button.add_theme_font_size_override("font_size", 35)
    power_back_button.add_theme_color_override("font_color", Color("#dceaf0"))
    # The only free icon on the heading sits beside the chamfered GRID plate.
    # No opaque giant Back button covering the title.
    var empty := StyleBoxEmpty.new()
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        power_back_button.add_theme_stylebox_override(state, empty)
    power_back_button.pressed.connect(_power_back_pressed)
    power_back_button.visible = false
    hud.add_child(power_back_button)


func _sync_base_grid_plate_visibility() -> void:
    if grid_ui == null or facility_system == null:
        return
    grid_ui.visible = not bool(facility_system.call("is_menu_open"))
    _refresh_facility_names()


func _power_back_pressed() -> void:
    if grid_placement_active:
        _leave_grid_placement()
    else:
        _leave_power_board()


func _grid_node_chosen(_code: String) -> void:
    # Palette selection only. Node placement and resource simulation are
    # deliberately unimplemented in this UI-shell milestone.
    pass


func _grid_operation_changed(_operation: String) -> void:
    # Cosmetic active operation icon: PLACE / MOVE / ROTATE.
    pass


func _grid_select_cell(cell: Vector2i) -> void:
    grid_selected_cell = cell
    if grid_selection_mesh == null:
        return
    grid_selection_mesh.position = PowerBoard.BOARD_CENTER + Vector3(
        (float(cell.x) - 3.5) * PowerBoard.CELL_PITCH, 0.463,
        (float(cell.y) - 3.5) * PowerBoard.CELL_PITCH)
    grid_selection_mesh.visible = true


func _grid_cell_from_pixel(pixel: Vector2) -> Vector2i:
    if cam == null:
        return Vector2i(-1, -1)
    var origin: Vector3 = cam.project_ray_origin(pixel)
    var normal: Vector3 = cam.project_ray_normal(pixel)
    if absf(normal.y) < 0.0001:
        return Vector2i(-1, -1)
    var distance: float = (0.4225 - origin.y) / normal.y
    if distance < 0.0:
        return Vector2i(-1, -1)
    var world_point: Vector3 = origin + normal * distance
    var grid_x: float = (world_point.x - PowerBoard.BOARD_CENTER.x) / (
        PowerBoard.CELL_PITCH) + 4.0
    var grid_y: float = (world_point.z - PowerBoard.BOARD_CENTER.z) / (
        PowerBoard.CELL_PITCH) + 4.0
    var x: int = floori(grid_x)
    var y: int = floori(grid_y)
    if x < 0 or y < 0 or x >= PowerBoard.GRID_SIDE or y >= PowerBoard.GRID_SIDE:
        return Vector2i(-1, -1)
    # Ignore the narrow gaps between actual square tile surfaces.
    var center_x: float = (float(x) - 3.5) * PowerBoard.CELL_PITCH
    var center_z: float = (float(y) - 3.5) * PowerBoard.CELL_PITCH
    if absf(world_point.x - PowerBoard.BOARD_CENTER.x - center_x) > 0.59 or (
            absf(world_point.z - PowerBoard.BOARD_CENTER.z - center_z) > 0.59):
        return Vector2i(-1, -1)
    return Vector2i(x, y)


func _grid_touch(pixel: Vector2) -> void:
    if not power_view_active or power_transition_busy:
        return
    if grid_ui != null and bool(grid_ui.call("is_interface_hit", pixel)):
        return
    if power_back_button != null and power_back_button.visible and (
            Rect2(power_back_button.position,
                power_back_button.size).has_point(pixel)):
        return
    var cell: Vector2i = _grid_cell_from_pixel(pixel)
    if cell.x < 0:
        return
    _grid_select_cell(cell)
    if not grid_placement_active:
        _enter_grid_placement()


func _power_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            grid_touch_id = event.index
            grid_touch_start = event.position
        elif event.index == grid_touch_id:
            grid_touch_id = -1
            if grid_touch_start.distance_to(event.position) <= 22.0:
                _grid_touch(event.position)
    elif event is InputEventMouseButton and (
            event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
        _grid_touch(event.position)


func _grid_edit_ortho_size(for_view: Vector2 = Vector2.ZERO) -> float:
    var dims: Vector2 = for_view
    if dims.x < 1.0 or dims.y < 1.0:
        dims = get_viewport().get_visible_rect().size
    # Fit the 11.75 m board inside portrait screen width, with space for
    # the palette under it and bare operation icons on the right.
    return maxf(22.8, 14.6 * dims.y / maxf(dims.x, 1.0))


# Interpolate the entire camera as ONE tween track.
# Translation traces a straight world-space line, quaternion SLERP turns
# steadily without Euler angle wobble, orthographic zoom uses the same t.
# A single ease-in/out affects time only and never bends the travel path.
func _apply_grid_camera_blend(progress: float, start_position: Vector3,
        start_orientation: Quaternion, start_size: float,
        end_position: Vector3, end_orientation: Quaternion,
        end_size: float) -> void:
    if cam == null:
        return
    cam.position = start_position.lerp(end_position, progress)
    cam.quaternion = start_orientation.slerp(end_orientation, progress)
    cam.size = lerpf(start_size, end_size, progress)


func _travel_grid_camera(to_position: Vector3,
        to_orientation: Quaternion, to_size: float,
        seconds: float, done: Callable) -> void:
    if power_camera_tween != null and power_camera_tween.is_running():
        power_camera_tween.kill()
    var from_position: Vector3 = cam.position
    var from_orientation: Quaternion = cam.quaternion
    var from_size: float = cam.size
    power_camera_tween = create_tween()
    power_camera_tween.set_trans(Tween.TRANS_SINE)
    power_camera_tween.set_ease(Tween.EASE_IN_OUT)
    power_camera_tween.tween_method(
        _apply_grid_camera_blend.bind(from_position, from_orientation,
            from_size, to_position, to_orientation, to_size),
        0.0, 1.0, seconds)
    power_camera_tween.finished.connect(done)


func _enter_grid_placement() -> void:
    if not power_view_active or grid_placement_active or (
            power_transition_busy):
        return
    grid_placement_active = true
    # Switch to 60 FPS before the close-up camera begins its motion.
    _frame_budget.set_grid_zoomed(true)
    power_transition_busy = true
    hint.visible = false
    grid_ui.call("set_edit", true, true)
    # One direct, uninterrupted approach to the 90° overhead view.
    # The camera never pauses at a midpoint or turns in separate phases.
    var destination := PowerBoard.board_focus() + Vector3(0.0, 34.0, 0.01)
    var overhead := Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
    _travel_grid_camera(destination, overhead.get_rotation_quaternion(),
        _grid_edit_ortho_size(), GRID_EDIT_ZOOM_SECONDS,
        Callable(self, "_grid_camera_arrived"))

func _grid_camera_arrived() -> void:
    power_transition_busy = false
    # Keep 60 FPS throughout the zoom-out tween, then return to 30 FPS.
    _frame_budget.set_grid_zoomed(grid_placement_active)


func _leave_grid_placement() -> void:
    if not grid_placement_active:
        return
    grid_placement_active = false
    power_transition_busy = true
    grid_selection_mesh.visible = false
    grid_ui.call("set_edit", false, true)
    hint.visible = true
    _travel_grid_camera(BASE_CAMERA_POSITION + (
        PowerBoard.board_focus() - BASE_CAMERA_TARGET),
        Basis.from_euler(grid_iso_rotation).get_rotation_quaternion(),
        _power_view_ortho_size(), GRID_EDIT_ZOOM_SECONDS,
        Callable(self, "_grid_camera_arrived"))

# A portrait Xperia has substantially less visible horizontal world width
# than the 720x1280 CI target. Fit the projected diagonal of the 11.75m
# square board in both, rather than cropping its left/right edge.
func _power_view_ortho_size(for_view: Vector2 = Vector2.ZERO) -> float:
    var dims: Vector2 = for_view
    if dims.x < 1.0 or dims.y < 1.0:
        dims = get_viewport().get_visible_rect().size
    return maxf(PowerBoard.CAMERA_SIZE,
        19.2 * dims.y / maxf(dims.x, 1.0))


func _enter_power_board() -> void:
    if scene_changing or power_view_active or cam == null:
        return
    power_view_active = true
    power_transition_busy = true
    grid_iso_rotation = cam.rotation
    _refresh_facility_names()
    hud_title.visible = false
    grid_ui.call("set_grid", true, true)
    layout_tools.visible = false
    power_back_button.visible = true
    hint.text = "POWER GRID / 8×8  |  接続設計エリア"
    # BASE -> GRID: one brisk, uninterrupted movement to the cable's end.
    # The winding cable stays visible in the world but is not a camera
    # waypoint; there is no deceleration or second acceleration midway.
    _travel_grid_camera(BASE_CAMERA_POSITION + (
        PowerBoard.board_focus() - BASE_CAMERA_TARGET),
        Basis.from_euler(grid_iso_rotation).get_rotation_quaternion(),
        _power_view_ortho_size(), BASE_GRID_TRAVEL_SECONDS,
        Callable(self, "_grid_camera_arrived"))

func _leave_power_board() -> void:
    if not power_view_active:
        return
    power_view_active = false
    power_transition_busy = true
    grid_placement_active = false
    grid_selection_mesh.visible = false
    grid_ui.call("set_edit", false, false)
    grid_ui.call("set_grid", false, true)
    power_back_button.visible = false
    hud_title.visible = false
    hint.visible = true
    layout_tools.visible = true
    hint.text = "建物をタップして施設を開く"
    # GRID -> BASE uses the same fast direct path, including rotation/zoom.
    _travel_grid_camera(BASE_CAMERA_POSITION,
        Basis.from_euler(grid_iso_rotation).get_rotation_quaternion(),
        BASE_ORTHO_SIZE, BASE_GRID_TRAVEL_SECONDS,
        Callable(self, "_power_camera_return_finished"))

func _power_camera_return_finished() -> void:
    power_transition_busy = false
    if not power_view_active and is_instance_valid(facility_system):
        _refresh_facility_names()


func _on_android_back() -> void:
    if scene_changing or get_tree().root.get_node_or_null("NexusExitTransition") != null:
        return
    if facility_placement_active:
        _close_facility_placement()
        return
    if power_view_active:
        _power_back_pressed()
        return
    if facility_system != null and bool(facility_system.call("is_menu_open")):
        facility_system.call("navigate_back")

func _input(event: InputEvent) -> void:
    if not _boot_complete or scene_changing or hud == null or get_tree().root.get_node_or_null("NexusExitTransition") != null:
        return
    if facility_placement_active:
        _facility_placement_input(event)
        return
    if power_view_active:
        _power_input(event)
        return
    # An open field-device panel owns its own GUI input; do not route clicks
    # behind it to NEXUS, other machines, or the dormant joystick.
    if facility_system != null and bool(facility_system.call("is_menu_open")):
        return
    if event is InputEventScreenTouch and event.pressed and (
            _layout_control_hit(event.position)):
        return
    if event is InputEventMouseButton and event.pressed and (
            _layout_control_hit(event.position)):
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
    if not _boot_complete or scene_changing or player == null:
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
    if is_instance_valid(logistics) and not power_view_active:
        logistics.call("advance", delta)
        logistics_diagnostic_elapsed += delta
        if logistics_diagnostic_elapsed >= 1.0:
            logistics_diagnostic_elapsed = 0.0
            if is_instance_valid(logistics_status):
                logistics_status.text = _base_diagnostic_text()
    # The outdoor BASE is a fixed isometric menu while SERA is disabled.
    # Preserve dormant player-follow logic only for a future controls re-enable.
    if cam != null and HUB_SERA_CONTROLS_ENABLED:
        var follow_shift := Vector3(player.position.x * 0.18, 0.0,
            player.position.z * 0.12)
        cam.position = cam.position.lerp(BASE_CAMERA_POSITION + follow_shift,
            minf(1.0, delta * 2.5))
        cam.look_at(BASE_CAMERA_TARGET + follow_shift, Vector3.UP)
    if not power_view_active and HUB_SERA_CONTROLS_ENABLED:
        _refresh_facility_names()
    if layout_tools != null:
        layout_tools.visible = not facility_placement_active and not power_view_active and not bool(
            facility_system.call("is_menu_open"))

func _enter_nexus() -> void:
    if get_tree().root.get_node_or_null("NexusExitTransition") != null:
        return
    if scene_changing or power_transition_busy or not is_instance_valid(nexus_building):
        return
    var model := nexus_building.get_node_or_null("NexusArchitecture") as Node3D
    if model == null or not is_instance_valid(cam) or not is_instance_valid(hud):
        return
    scene_changing = true
    SeraSave.requested_nexus_target = ""
    var transition := NexusEntryTransition.new()
    transition.name = "NexusEntryTransition"
    get_tree().root.add_child(transition)
    transition.run(self, cam, model, hud, base_bgm_player, NEXUS_SCENE, _nexus_shutter_clip)
