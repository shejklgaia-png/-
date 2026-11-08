extends Node3D
# v126: model-derived silhouettes, cached low-cost contour pulses and bottom-right back.
# Keep the v125 camera/touch logic and v124 Blockbench geometry and gate light spill.
const Modules = preload("res://assets/base_command_modules.gd")
const SeraRig = preload("res://scripts/sera_rig.gd")
const NexusSelectionOutline = preload("res://scripts/nexus_selection_outline.gd")

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
var focus_title: Label
var action_panel: Panel
var action_label: Label

const CAMERA_TRANSITION_SECONDS: float = 0.18
const TRAINING_SCENE: String = "res://scenes/main.tscn"

# Project the same Blockbench cuboids/SERA display geometry already present in the
# scene into a silhouette; no duplicated render meshes or additional 3D draw calls.
# Each entry holds world-space 3D vertex clusters, grouped by model component.
var target_parts: Dictionary = {}

# Authored close-up compositions; no camera shake, flash, zoom blur or particles.
var focus_views: Dictionary = {
    "TRAINING": {"eye": Vector3(-1.90, 2.35, 5.10),
        "look": Vector3(-1.95, 1.36, 1.25), "fov": 48.0},
    "SYSTEM": {"eye": Vector3(1.90, 2.35, 5.10),
        "look": Vector3(1.95, 1.36, 1.25), "fov": 48.0},
    "CUSTOMIZE": {"eye": Vector3(0.0, 2.90, 2.00),
        "look": Vector3(0.0, 2.00, -4.75), "fov": 43.0},
    "DATA ARCHIVE": {"eye": Vector3(-3.90, 4.20, -2.20),
        "look": Vector3(-4.00, 3.85, -8.80), "fov": 49.0},
    "DEPLOYMENT": {"eye": Vector3(2.60, 3.85, -1.50),
        "look": Vector3(4.00, 3.35, -10.48), "fov": 49.0}
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
            selected_shape = "TRAINING" if at.x < 0.0 else "SYSTEM"
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
            bone.quaternion = bone.quaternion * Quaternion(Vector3.BACK, deg_to_rad(float(arm_angles[bone.name])))
    _capture_sera_silhouette(rig)

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
    focus_panel.add_theme_stylebox_override("panel", _menu_style())
    focus_panel.visible = false
    hud.add_child(focus_panel)
    focus_title = Label.new()
    focus_title.name = "DestinationTitle"
    focus_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_title.add_theme_font_size_override("font_size", 21)
    focus_title.add_theme_color_override("font_color", Color("#e1f3fd"))
    focus_panel.add_child(focus_title)
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

func _action_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.115, 0.16, 0.90)
    style.border_color = Color(0.29, 0.80, 0.94, 0.88)
    style.set_border_width_all(1)
    style.set_corner_radius_all(4)
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
    focus_panel.size = Vector2(view.x * 0.84, minf(142.0, view.y * 0.15))
    focus_panel.position = Vector2(view.x * 0.08,
        minf(view.y * 0.74, back_panel.position.y - focus_panel.size.y - 12.0))
    focus_title.position = Vector2(20.0, 11.0)
    focus_title.size = Vector2(focus_panel.size.x - 40.0, 31.0)
    action_panel.position = Vector2(16.0, 50.0)
    action_panel.size = Vector2(focus_panel.size.x - 32.0, 60.0)
    action_label.position = Vector2.ZERO
    action_label.size = action_panel.size
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
    if event is InputEventScreenTouch and event.pressed:
        _tap_at(event.position)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _tap_at(event.position)
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
    outline.set("active_target", target_name)
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
    back_panel.visible = true
    focus_title.text = target_name
    action_label.text = "ENTER TRAINING" if target_name == "TRAINING" else "NOT AVAILABLE YET"
    action_panel.visible = true
    focus_panel.visible = true

func _return_to_overview() -> void:
    if in_transition or focused_target.is_empty():
        return
    in_transition = true
    focus_panel.visible = false
    back_panel.visible = false
    _move_camera(overview_pose, overview_fov, _overview_arrived)

func _overview_arrived() -> void:
    in_transition = false
    focused_target = ""
    outline.set("active_target", "")
    _update_projected_silhouettes()

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
