extends SceneTree
## Runtime inspection of actual BASE scene: separate 4px BASE silhouette and 1px ink.
const FACILITIES: Array[String] = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL"
]
const HULL_SHADER = preload("res://shaders/base_facility_silhouette_edges.gdshader")
const CREASE_SHADER = preload("res://shaders/base_facility_view_edges.gdshader")
const SERA_HULL = preload("res://scripts/sera_view_edges.gd")
const BASE_EDGES = preload("res://scripts/sera_base_facility_outlines.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_LATEST_HULL_1PX_CREASE_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _frame in range(150):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
                hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null):
            break
    var cam: Camera3D = hub.get("cam") as Camera3D
    if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("expected BASE camera not loaded")
        return
    if hub.get_node_or_null("BaseHUDLayer/BaseHUD/FacilityOutlines") != null:
        _fail("obsolete screen-space polygon cage returned")
        return
    var raw := BoxMesh.new()
    var hull: ArrayMesh = BASE_EDGES.overlay_for("test_unit_hull", raw)
    var crease: ArrayMesh = BASE_EDGES.crease_for("test_unit", raw)
    if hull == null or crease == null:
        _fail("BASE silhouette or 1px line geometry not generated")
        return
    var hull_arrays: Array = hull.surface_get_arrays(0)
    var hull_vertices: PackedVector3Array = hull_arrays[Mesh.ARRAY_VERTEX]
    var hull_tangents: PackedVector3Array = hull_arrays[Mesh.ARRAY_NORMAL]
    if hull_vertices.size() < 48 or hull_vertices.size() % 6 != 0 or (
            hull_tangents.size() != hull_vertices.size()) or (
            hull_arrays[Mesh.ARRAY_CUSTOM0] == null) or (
            crease.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0] == null):
        _fail("4px contour needs paired-face ribbons, not entire surface triangles")
        return

    for key in FACILITIES:
        var path: String = "NEXUSBuilding/NexusArchitecture" if key == "NEXUS" else (
            "BaseFacilities/" + key + "/IndustrialModel")
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null:
            _fail(key + " model missing")
            return
        var hull_parts: Dictionary = {}
        var crease_parts: Dictionary = {}
        for child in model.get_children():
            if not child is MultiMeshInstance3D:
                continue
            var node: MultiMeshInstance3D = child as MultiMeshInstance3D
            if node.multimesh == null:
                continue
            var title: String = str(node.name)
            if title.begins_with("ArchitecturalEdgeInk_"):
                hull_parts[title.substr("ArchitecturalEdgeInk_".length())] = node
                var mat: ShaderMaterial = node.material_override as ShaderMaterial
                if mat == null or mat.shader != HULL_SHADER or (
                        not is_equal_approx(float(
                        mat.get_shader_parameter("stroke_px")), 4.0)):
                    _fail(key + " not using screen-space silhouette ribbon at 4px")
                    return
                if mat.get_shader_parameter("ink_color") != Color("#000000"):
                    _fail(key + " 4px facility silhouette must be black")
                    return
            elif title.begins_with("ArchitecturalCreaseInk_"):
                crease_parts[title.substr("ArchitecturalCreaseInk_".length())] = node
                var mat2: ShaderMaterial = node.material_override as ShaderMaterial
                if mat2 == null or mat2.shader != CREASE_SHADER or (
                        not is_equal_approx(float(
                        mat2.get_shader_parameter("crease_px")), 1.0)):
                    _fail(key + " foreground crease not preserved at 1px")
                    return
                if mat2.get_shader_parameter("ink_color") != Color("#202020"):
                    _fail(key + " retained 1px polygon corners must be black")
                    return
        if hull_parts.is_empty() or crease_parts.is_empty() or (
                hull_parts.size() != crease_parts.size()):
            _fail(key + " missing separate silhouette / crease batches")
            return
        for label in hull_parts:
            if not crease_parts.has(label):
                _fail(key + " two edge passes have unmatched solid batches")
                return
            var hull_part: MultiMeshInstance3D = hull_parts[label]
            var crease_part: MultiMeshInstance3D = crease_parts[label]
            if hull_part.multimesh.instance_count != crease_part.multimesh.instance_count:
                _fail(key + " foreground creases have wrong instance counts")
                return
        var fx: Node3D = model.get_node_or_null("BaseFacilityVFX") as Node3D
        if fx == null:
            _fail(key + " facility effects removed")
            return
        for child in fx.get_children():
            if str(child.name).begins_with("ArchitecturalEdgeInk_") or (
                    str(child.name).begins_with("ArchitecturalCreaseInk_")):
                _fail(key + " VFX gained a forbidden outline")
                return

    var collector: Node3D = hub.get_node("BaseFacilities/SCRAP_COLLECTOR/IndustrialModel")
    var driver: Node = collector.get_node("FacilityMotion")
    var animated: Dictionary = collector.get_meta("motion_entries", {})
    var claw: Array = animated.get("FreshCollectorClawHead", [])
    if claw.is_empty():
        _fail("claw channel missing")
        return
    var slot: Dictionary = claw[0]
    if not slot.has("ink_mesh") or not slot.has("crease_mesh"):
        _fail("animated mesh not linked to both outlines")
        return
    driver.call("sample_at", 1.38)
    var actual: Transform3D = (slot["mesh"] as MultiMesh).get_instance_transform(
        int(slot["index"]))
    var out_hull: Transform3D = (slot["ink_mesh"] as MultiMesh).get_instance_transform(
        int(slot["ink_index"]))
    var out_crease: Transform3D = (slot["crease_mesh"] as MultiMesh).get_instance_transform(
        int(slot["crease_index"]))
    if actual.origin.distance_to(out_hull.origin) > 0.0001 or (
            actual.origin.distance_to(out_crease.origin) > 0.0001):
        _fail("animated silhouette / crease drifts from moving 3D part")
        return
    if str(hub.get_node("NEXUSBuilding/NexusArchitecture").get_meta(
            "base_design", "")) != "ARCHIVED_20261122":
        _fail("archived NEXUS model changed")
        return
    print("SERA_BASE_LATEST_HULL_6PX_PRESERVED_CREASE_1PX_RUNTIME_PASS")
    quit(0)
