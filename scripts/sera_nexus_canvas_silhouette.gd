extends Control
## NEXUS full-body only: robust same-viewport, same-frame 2D silhouette.
## No shaders, stencil, GPU-readback, extra camera or SubViewport.
## Project the eight corners of each VISIBLE original mesh AABB through the
## ACTUAL NEXUS camera, union their projected footprints and stroke only
## the exterior boundaries. This is deliberately an approximate silhouette:
## robustness and zero view-frame lag matter more than exact geometry.
const GraphicsSettings = preload("res://scripts/sera_graphics_settings.gd")
const RESCAN_SECONDS: float = 0.35
const STROKE_PX: float = 3.0
const OUTLINE_INK: Color = Color("#0b1118")
const INSPECT_INK: Color = Color("#29f4f7")

var _rig: Node3D
var _camera: Camera3D
var _nexus: Node
var _sources: Array[MeshInstance3D] = []
var _elapsed: float = 0.0
var _mode: int = 0
var _last_merged_count: int = 0
var _last_candidate_count: int = 0

func configure(rig: Node3D, camera: Camera3D, nexus: Node) -> void:
    _rig = rig
    _camera = camera
    _nexus = nexus

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    clip_contents = true
    process_priority = 100
    _scan_sources()
    set_process(true)

func _enabled() -> bool:
    if not is_instance_valid(_rig) or not is_instance_valid(_camera):
        return false
    if not is_instance_valid(_nexus):
        return false
    if not GraphicsSettings.get_enabled("character_outline"):
        return false
    # Only NEXUS' full-body customization display. No foreign UI/scene.
    if str(_nexus.get("focused_target")) != "CUSTOMIZE":
        return false
    if not bool(_nexus.get("customize_preview_active")):
        return false
    return _mode == 0 or _mode == 1 or _mode == 9

func set_diagnostic_mode(mode: int) -> void:
    _mode = clampi(mode, 0, 18)
    queue_redraw()

func _source_allowed(node: Node) -> bool:
    if bool(node.get_meta("sera_generated_live_edge", false)):
        return false
    if bool(node.get_meta("FX_NO_OUTLINE", false)) or (
            bool(node.get_meta("sera_no_view_edges", false))):
        return false
    var label: String = str(node.name).to_lower()
    for excluded in ["swordeffect", "afterimage", "ghost", "beam",
            "trail", "particle", "smoke", "glow", "fx_"]:
        if label.contains(excluded):
            return false
    return true

func _scan_sources() -> void:
    _sources.clear()
    if not is_instance_valid(_rig):
        return
    var pending: Array[Node] = [_rig]
    while not pending.is_empty():
        var node: Node = pending.pop_back()
        if not _source_allowed(node):
            continue
        if node is MeshInstance3D:
            var part: MeshInstance3D = node as MeshInstance3D
            if part.mesh != null and not (part.mesh is QuadMesh) and (
                    not (part.mesh is PlaneMesh)):
                _sources.append(part)
        for child in node.get_children():
            if child is Node3D:
                pending.append(child)
    _last_candidate_count = _sources.size()

func _process(delta: float) -> void:
    _elapsed -= delta
    if _elapsed <= 0.0:
        _elapsed = RESCAN_SECONDS
        _scan_sources()
    if _enabled():
        # Draw after scene _process updates have settled, using the same
        # camera and source transforms that the 3D frame will render.
        queue_redraw()
    elif _last_merged_count != 0:
        _last_merged_count = 0
        queue_redraw()

func _polygon_bounds(poly: PackedVector2Array) -> Rect2:
    var rect: Rect2 = Rect2(poly[0], Vector2.ZERO)
    for i in range(1, poly.size()):
        rect = rect.expand(poly[i])
    return rect

func _projected_bounds(part: MeshInstance3D,
        screen_to_local: Transform2D) -> PackedVector2Array:
    var aabb: AABB = part.mesh.get_aabb()
    if aabb.size.length_squared() < 0.000000001:
        return PackedVector2Array()
    var center: Vector3 = part.global_transform * (
        aabb.position + aabb.size * 0.5)
    if _camera.is_position_behind(center):
        return PackedVector2Array()
    var points := PackedVector2Array()
    var basis: Transform3D = part.global_transform
    for x in range(2):
        for y in range(2):
            for z in range(2):
                var local_point: Vector3 = aabb.position + Vector3(
                    aabb.size.x * float(x),
                    aabb.size.y * float(y),
                    aabb.size.z * float(z))
                var projected: Vector2 = _camera.unproject_position(
                    basis * local_point)
                if not is_finite(projected.x) or not is_finite(projected.y):
                    return PackedVector2Array()
                points.append(screen_to_local * projected)
    var hull: PackedVector2Array = Geometry2D.convex_hull(points)
    # Godot convex_hull returns the initial point again at the end.
    # Clipper expects an open list of polygon vertices.
    if hull.size() > 3 and hull[0].distance_squared_to(
            hull[hull.size() - 1]) < 0.001:
        hull.remove_at(hull.size() - 1)
    return hull

func _merge_footprints(polygons: Array[PackedVector2Array]
        ) -> Array[PackedVector2Array]:
    # Standard Godot Geometry2D union, with an AABB fast rejection.
    # If disjoint, keep two exterior shapes. If a mesh is hidden behind
    # another projected box, union absorbs its entire inner contour.
    var result: Array[PackedVector2Array] = []
    for polygon in polygons:
        if polygon.size() < 3:
            continue
        var current: PackedVector2Array = polygon
        var i: int = 0
        while i < result.size():
            var other: PackedVector2Array = result[i]
            if not _polygon_bounds(current).intersects(
                    _polygon_bounds(other)):
                i += 1
                continue
            var joined: Array[PackedVector2Array] = (
                Geometry2D.merge_polygons(current, other))
            if joined.size() == 1 and joined[0].size() >= 3:
                current = joined[0]
                result.remove_at(i)
                # Merging with a later shape can touch an earlier shape.
                i = 0
            else:
                # Disjoint or an ambiguous hole case: keep both instead of
                # risking a vanished contour. Only the visible box shapes
                # are projected; none of the original face/edge lines are.
                i += 1
        result.append(current)
    return result

func _draw() -> void:
    if not _enabled() or not _camera.is_current():
        _last_merged_count = 0
        return
    var footprints: Array[PackedVector2Array] = []
    var screen_to_local: Transform2D = (
        get_global_transform_with_canvas().affine_inverse())
    for source in _sources:
        if not is_instance_valid(source) or not source.is_visible_in_tree():
            continue
        var polygon: PackedVector2Array = _projected_bounds(
            source, screen_to_local)
        if polygon.size() >= 3:
            footprints.append(polygon)
    if footprints.is_empty():
        _last_merged_count = 0
        return
    var outlines: Array[PackedVector2Array] = _merge_footprints(
        footprints)
    _last_merged_count = outlines.size()
    var color: Color = INSPECT_INK if (_mode == 1 or _mode == 9) else (
        OUTLINE_INK)
    var exterior_count: int = 0
    for polygon in outlines:
        if polygon.size() < 3 or Geometry2D.is_polygon_clockwise(polygon):
            continue
        var closed := PackedVector2Array(polygon)
        closed.append(polygon[0])
        draw_polyline(closed, color, STROKE_PX, false)
        exterior_count += 1
    # Fail visible rather than rendering nothing if a particular Clipper
    # orientation convention changes between renderer/platform releases.
    if exterior_count == 0:
        for polygon in outlines:
            if polygon.size() < 3:
                continue
            var closed := PackedVector2Array(polygon)
            closed.append(polygon[0])
            draw_polyline(closed, color, STROKE_PX, false)

func get_outline_snapshot() -> Dictionary:
    return {
        "parts": _sources.size(),
        "candidates": _last_candidate_count,
        "contours": _last_merged_count,
        "active": _enabled(),
        "mode": _mode,
        "pipeline": "canvas_projected_mesh_box_union",
        "stencil_required": false,
        "viewport_copies": 0,
        "stroke_px": STROKE_PX
    }
