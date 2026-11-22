extends SceneTree
## Live BASE regression: no projected convex-hull cages; each opaque MultiMesh
## gets a view/depth-tested shader-based true mesh edge companion.
const FACILITIES: Array[String] = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL",
]
const INK = preload("res://shaders/base_facility_silhouette_edges.gdshader")
const CREASE = preload("res://shaders/base_facility_view_edges.gdshader")
const EDGES = preload("res://scripts/sera_base_facility_outlines.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_MESH_EDGE_SHADER_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _frame in range(150):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
                hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null):
            break
    if hub.get_node_or_null("BaseStartupOverlay") != null:
        _fail("live BASE failed to boot")
        return
    var cam: Camera3D = hub.get("cam") as Camera3D
    if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("approved BASE ortho camera changed")
        return
    if hub.get_node_or_null("BaseHUDLayer/BaseHUD/FacilityOutlines") != null:
        _fail("obsolete wire-cage screen overlay is still running")
        return
    if EDGES.overlay_for("test_silhouette_cube", BoxMesh.new()) == null:
        _fail("SERA baseline edge topology builder unavailable")
        return
    for key in FACILITIES:
        var path: String = "NEXUSBuilding/NexusArchitecture" if (
            key == "NEXUS") else "BaseFacilities/" + key + "/IndustrialModel"
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null:
            _fail(key + " actual facility missing")
            return
        var ink_total: int = 0
        var crease_total: int = 0
        var base_total: int = 0
        for child in model.get_children():
            if not child is MultiMeshInstance3D:
                continue
            var inst: MultiMeshInstance3D = child as MultiMeshInstance3D
            if inst.multimesh == null:
                continue
            if str(inst.name).begins_with("ArchitecturalEdgeInk_"):
                ink_total += inst.multimesh.instance_count
                var ink_mat: ShaderMaterial = inst.material_override as ShaderMaterial
                if ink_mat == null or ink_mat.shader != INK:
                    _fail(key + " does not use real SERA-derived shader")
                    return
                if not is_equal_approx(
                        float(ink_mat.get_shader_parameter("stroke_px")), 4.0):
                    _fail(key + " 4px visible-contour ribbon no longer 4 screen pixels")
                    return

                if ink_mat.get_shader_parameter("ink_color") != Color("#000000"):
                    _fail(key + " 4px SERA hull must be pure black")
                    return
                if inst.has_meta("FX_NO_OUTLINE") == false:
                    _fail(key + " ink instance not marked as non-FX")
                    return
            elif str(inst.name).begins_with("ArchitecturalCreaseInk_"):
                crease_total += inst.multimesh.instance_count
                var crease_mat: ShaderMaterial = inst.material_override as ShaderMaterial
                if crease_mat == null or crease_mat.shader != CREASE or (
                        not is_equal_approx(float(
                        crease_mat.get_shader_parameter("crease_px")), 1.0)):
                    _fail(key + " foreground crease changed from approved 1px")
                    return

                if crease_mat.get_shader_parameter("ink_color") != Color("#202020"):
                    _fail(key + " 1px corner ink must be black")
                    return
            elif str(inst.name).begins_with("Architectural_"):
                base_total += inst.multimesh.instance_count
        if ink_total < 18 or ink_total > base_total or crease_total != ink_total:
            _fail(key + " wrong number of real mesh edges: " +
                str(ink_total) + "/" + str(base_total))
            return
        if not model.has_node("BaseFacilityVFX"):
            _fail(key + " entrance effect missing")
            return
        var fx: Node3D = model.get_node("BaseFacilityVFX") as Node3D
        for child in fx.get_children():
            if str(child.name).begins_with("ArchitecturalEdgeInk_") or (
                    str(child.name).begins_with("ArchitecturalCreaseInk_")):
                _fail(key + " effect incorrectly received facility outline")
                return
            if child is MeshInstance3D:
                var material: ShaderMaterial = (
                    child as MeshInstance3D).material_override as ShaderMaterial
                if material != null and material.shader in [INK, CREASE]:
                    _fail(key + " effect is using a solid-only outline shader")
                    return
    # Verify indexed animated part and its ink remain in the *same pose*.
    var collector: Node3D = hub.get_node(
        "BaseFacilities/SCRAP_COLLECTOR/IndustrialModel")
    var controller: Node = collector.get_node("FacilityMotion")
    var entries: Dictionary = collector.get_meta("motion_entries", {})
    var arms: Array = entries.get("FreshCollectorClawHead", [])
    if arms.is_empty() or not (arms[0] as Dictionary).has("ink_mesh") or (
            not (arms[0] as Dictionary).has("crease_mesh")):
        _fail("moving solid claw has no ink-following batch entry")
        return
    var slot: Dictionary = arms[0]
    controller.call("sample_at", 1.38)
    var visible_pose: Transform3D = (slot["mesh"] as MultiMesh).get_instance_transform(
        int(slot["index"]))
    var ink_pose: Transform3D = (slot["ink_mesh"] as MultiMesh).get_instance_transform(
        int(slot["ink_index"]))
    var crease_pose: Transform3D = (slot["crease_mesh"] as MultiMesh).get_instance_transform(
        int(slot["crease_index"]))
    if visible_pose.origin.distance_to(ink_pose.origin) > 0.0001 or (
            visible_pose.origin.distance_to(crease_pose.origin) > 0.0001):
        _fail("4px hull or preserved 1px corner fails to follow moving claw")
        return
    if str(hub.get_node("NEXUSBuilding/NexusArchitecture").get_meta(
            "base_design", "")) != "ARCHIVED_20261122":
        _fail("original NEXUS has been replaced")
        return
    print("SERA_BASE_MESH_EDGE_SHADER_RUNTIME_PASS all 8 real geometry/depth/FX, moving claw and old NEXUS")
    quit(0)
