extends Node3D
## Outdoor portrait base hub; CRATE wanders independently and NEXUS is a tappable building.
const Modules = preload("res://assets/base_command_modules.gd")
const SERA_RIG_PATH: String = "res://scripts/sera_rig.gd"
const VersionIndicator = preload("res://scripts/version_indicator.gd")
const BaseFacilities = preload("res://scripts/base_facility_system.gd")
const PowerBoard = preload("res://scripts/sera_base_power_board.gd")
const GridUi = preload("res://scripts/sera_base_grid_ui.gd")
const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")
const BaseClutter = preload("res://scripts/sera_base_clutter.gd")
const BaseLayoutPreview = preload("res://scripts/sera_base_layout_preview.gd")
const JunkGeometry = preload("res://scripts/sera_base_junk_geometry.gd")
const BaseFloorDetail = preload("res://scripts/sera_base_floor_detail.gd")
const BaseDeckLayout = preload("res://scripts/sera_base_deck_layout.gd")
const BasePolygon = preload("res://scripts/sera_base_polygon_meshes.gd")
const WEATHERED_STEEL_PATH: String = "res://assets/base/industrial_steel_grunge.svg"
const WEATHERED_DECK_PATH: String = "res://assets/base/industrial_deck_wear.svg"
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
# Camera elevation is now ~33.8 degrees (was 41.1), revealing building facades
# and side panels while preserving the 720x1280 orthographic composition.
const BASE_ORTHO_SIZE: float = 38.0
# All BASE/GRID view transitions are one uninterrupted camera move.
const BASE_GRID_TRAVEL_SECONDS: float = 0.48
const GRID_EDIT_ZOOM_SECONDS: float = 0.46
const BASE_CAMERA_POSITION: Vector3 = Vector3(21.0, 23.0, 25.0)
const BASE_CAMERA_TARGET: Vector3 = Vector3(0.0, 0.0, -2.2)
const NEXUS_BUILDING_ORIGIN: Vector3 = Vector3(-9.30, 0.0, -14.55)
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
var startup_layer: CanvasLayer
var startup_label: Label
var layout_tools: VBoxContainer
var layout_shuffle_button: Button
var layout_copy_button: Button
var layout_status: Label
var layout_seed: int = 0
var layout_rerolls: int = 0
var power_zone: Node3D
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

func _ready() -> void:
    BaseClutter.clear_preview()
    # The old synchronous boot left Android showing only Godot's gray clear
    # color until the entire large BASE world and all of its dependencies
    # finished. Draw an engine-native first frame before heavy construction.
    get_window().go_back_requested.connect(_on_android_back)
    _setup_world()
    _create_camera()
    _create_startup_overlay()
    print("SERA_BASE_BOOT: initial frame ready")
    # A process_frame signal fires BEFORE drawing; wait across two signals
    # so a complete frame can actually be painted between them.
    await get_tree().process_frame
    await get_tree().process_frame
    _startup_step("FLOOR")
    _build_hangar()
    _startup_step("NEXUS")
    _build_nexus_building()
    _startup_step("FACILITIES")
    _build_field_facilities()
    _build_power_board()
    _create_grid_selection()
    _startup_step("SALVAGE")
    _create_salvage()
    _startup_step("CRATE")
    _create_player()
    _create_crate()
    _startup_step("UI")
    _create_hud()
    SeraSave.mark_location("BASE")
    startup_layer.queue_free()
    startup_layer = null
    startup_label = null
    print("SERA_BASE_BOOT: COMPLETE")


func _create_startup_overlay() -> void:
    # No bundled fonts, imported textures, or material shaders in the loader.
    # It must remain visible even if an optional resource fails to import.
    startup_layer = CanvasLayer.new()
    startup_layer.name = "BaseStartupOverlay"
    startup_layer.layer = 100
    add_child(startup_layer)
    var cover := ColorRect.new()
    cover.name = "Background"
    cover.color = Color("#0b111b")
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
    startup_layer.add_child(cover)
    startup_label = Label.new()
    startup_label.name = "StartupMessage"
    startup_label.text = "SERA / INITIALIZING"
    startup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    startup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    startup_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    startup_label.add_theme_font_size_override("font_size", 26)
    startup_label.add_theme_color_override("font_color", Color("#dcebf3"))
    startup_layer.add_child(startup_label)


func _startup_step(step: String) -> void:
    print("SERA_BASE_BOOT: " + step)
    if startup_label != null:
        startup_label.text = "SERA / INITIALIZING " + step


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

func _create_grid_plates(floor: Node3D) -> Array[Dictionary]:
    # An actual nonoverlapping patchwork: long, wide, square and small plates.
    # Six color-batched MultiMeshes still draw the full 255m deck efficiently.
    var tints := [
        Color("#1e2326"), Color("#252729"), Color("#292b2a"),
        Color("#27292c"), Color("#21262a"), Color("#302c29")
    ]
    var sites: Array[Dictionary] = BaseDeckLayout.facility_sites(
        NEXUS_BUILDING_ORIGIN, BaseFacilities.FACILITY_SPECS)
    var panels: Array[Dictionary] = BaseDeckLayout.generate(
        PLATE_GRID_RADIUS_CELLS, PLATE_GRID_STEP, sites)
    # Physically chamfered eight-sided polygonal unit slab, sharing one
    # CPU-side mesh across all existing six floor MultiMesh draw batches.
    var plate_mesh: ArrayMesh = BasePolygon.make("deck")
    var grid_extent: float = float(PLATE_GRID_RADIUS_CELLS) * PLATE_GRID_STEP + 1.50
    var grouped: Array = []
    for index in range(tints.size()):
        grouped.append([])
    for panel in panels:
        var center: Vector2 = panel["center"]
        var size: Vector2 = panel["size"]
        var palette_index: int = int(panel["tint"])
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
    for palette_index in range(tints.size()):
        var poses: Array = grouped[palette_index]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = plate_mesh
        # Explicit culling box: dummy headless renderers cannot read back
        # per-instance transforms. The entire floor remains in the viewport.
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
        draw.material_override = mat
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        floor.add_child(draw)
    return panels

func _build_hangar() -> void:
    # Exterior base: the enclosed Blockbench hangar remains inside the NEXUS menu.
    var floor := Node3D.new()
    floor.name = "PatchworkSteelFloor"
    add_child(floor)
    # The dark one-piece ground remains visible only in the 0.06 m seams.
    _box(floor, "ContinuousGround", Vector3(0.0, -0.21, 0.0),
        Vector3(256.0, 0.30, 256.0), Color("#12171b"))
    var panels: Array[Dictionary] = _create_grid_plates(floor)
    BaseFloorDetail.decorate(floor, panels)
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
    var foundation: MeshInstance3D = _box(nexus_building, "Foundation", Vector3(0, 0.23, 0),
        Vector3(6.4, 0.46, 5.4), Color("#46535c"))
    foundation.rotation.y = BaseArchitecture.facility_yaw_radians("NEXUS")
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
    facility_system.connect("power_board_requested", Callable(self, "_enter_power_board"))

func _build_power_board() -> void:
    # 8×8 stage is a connected physical extension of the existing BASE.
    power_zone = PowerBoard.build(self)


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

func _create_salvage(replacement: Array[Dictionary] = []) -> void:
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
    add_child(salvage)
    var g := BaseArchitecture.Batch.new(salvage)
    for i in range(lots.size()):
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
    g.flush()

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
    _create_layout_tools()
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
        layout_tools.size = Vector2(156.0, 122.0)
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

func _create_layout_tools() -> void:
    layout_tools = VBoxContainer.new()
    layout_tools.name = "LayoutTools"
    layout_tools.mouse_filter = Control.MOUSE_FILTER_PASS
    layout_tools.add_theme_constant_override("separation", 5)
    hud.add_child(layout_tools)
    layout_shuffle_button = _layout_tool_button(
        "小物を再配置", "LayoutShuffleButton", _shuffle_layout)
    layout_copy_button = _layout_tool_button(
        "配置データコピー", "LayoutCopyButton", _copy_layout_data)
    layout_status = Label.new()
    layout_status.name = "LayoutStatus"
    layout_status.text = "PREVIEW / 未確定"
    layout_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    layout_status.add_theme_font_override("font", LaboSkin.ui_font())
    layout_status.add_theme_font_size_override("font_size", 11)
    layout_status.add_theme_color_override("font_color", Color("#a7c4d3"))
    layout_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layout_tools.add_child(layout_status)


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


func _shuffle_layout() -> void:
    if scene_changing or facility_system == null or (
            bool(facility_system.call("is_menu_open"))):
        return
    layout_shuffle_button.disabled = true
    layout_copy_button.disabled = true
    layout_status.text = "再配置中..."
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var next: Dictionary = BaseLayoutPreview.generate(
        NEXUS_BUILDING_ORIGIN, BaseFacilities.FACILITY_SPECS, rng)
    if next.is_empty():
        layout_status.text = "再配置できませんでした"
    else:
        _apply_layout_preview(next)
        layout_status.text = "仮配置 #%d" % layout_rerolls
    layout_shuffle_button.disabled = false
    layout_copy_button.disabled = false


func _apply_layout_preview(selected: Dictionary) -> void:
    # Session preview only; no changes to the game's permanent saves.
    var layouts: Dictionary = selected["sites"]
    var scrap: Array[Dictionary] = selected["scrap"]
    BaseClutter.set_preview_layouts(layouts)
    var old_nexus: Node = nexus_building.get_node_or_null("NexusArchitecture")
    if old_nexus != null:
        old_nexus.free()
    BaseArchitecture.build_nexus(nexus_building)
    for spec in BaseFacilities.FACILITY_SPECS:
        var key: String = str(spec["id"])
        var station: Node3D = facility_system.get_node_or_null(key) as Node3D
        if station == null:
            continue
        var old: Node = station.get_node_or_null("IndustrialModel")
        if old != null:
            old.free()
        BaseArchitecture.build_facility(station, key)
    var previous: Node = get_node_or_null("SalvageMeshes")
    if previous != null:
        previous.free()
    for i in range(BaseLayoutPreview.SCRAP_COUNT):
        var pile: Node = get_node_or_null("ScrapPile_%02d" % i)
        if pile != null:
            pile.free()
    _create_salvage(scrap)
    layout_seed = int(selected["seed"])
    layout_rerolls += 1
    facility_system.call("update_tags", cam)


func _layout_export_text() -> String:
    # Full model parameters, not only the seed: repeatable across devices.
    var layouts: Dictionary = {}
    for key in BaseLayoutPreview.KEYS:
        layouts[key] = BaseClutter.props_for(key)
    var scrap: Array[Dictionary] = []
    for i in range(BaseLayoutPreview.SCRAP_COUNT):
        var pile: Node3D = get_node_or_null("ScrapPile_%02d" % i) as Node3D
        if pile == null:
            return ""
        scrap.append({
            "index": i, "x": pile.position.x, "z": pile.position.z,
            "yaw_deg": pile.rotation_degrees.y,
            "scale": float(pile.get_meta("visual_scale", 1.0)),
            "profile": int(pile.get_meta("scrap_profile", 0)),
            "stack": int(pile.get_meta("stack", 1)),
            "pattern": int(pile.get_meta("pattern", 0)),
        })
    return BaseLayoutPreview.export_text(
        layouts, scrap, layout_rerolls, layout_seed)


func _copy_layout_data() -> void:
    var data: String = _layout_export_text()
    if data.is_empty():
        layout_status.text = "コピー失敗"
        return
    DisplayServer.clipboard_set(data)
    layout_status.text = "コピー完了 / チャットに貼付"


func _exit_tree() -> void:
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
    facility_system.call("set_field_tags_visible", false)
    hud_title.visible = false
    nexus_tag.visible = false
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
        facility_system.call("set_field_tags_visible", true)


func _on_android_back() -> void:
    if power_view_active:
        _power_back_pressed()
        return
    if facility_system != null and bool(facility_system.call("is_menu_open")):
        facility_system.call("navigate_back")

func _input(event: InputEvent) -> void:
    if scene_changing or hud == null:
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
    if not power_view_active:
        _update_nexus_tag()
        facility_system.call("update_tags", cam)
    if layout_tools != null:
        layout_tools.visible = not power_view_active and not bool(
            facility_system.call("is_menu_open"))

func _enter_nexus() -> void:
    if scene_changing:
        return
    scene_changing = true
    SeraSave.requested_nexus_target = ""
    var error: Error = get_tree().change_scene_to_file(NEXUS_SCENE)
    if error != OK:
        scene_changing = false
        push_error("SERA BASE -> NEXUS scene load failed (%d)" % error)
