extends SceneTree
## Real Godot BASE: current SERA inverted-hull material at 6px, independent
## 2px front-facing structural corners, one-to-one animated MultiMesh poses.
const KEYS: Array[String] = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL",
]
const SERA_SHADER = preload("res://shaders/sera_view_edges.gdshader")
const CORNER_SHADER = preload("res://shaders/base_facility_view_edges.gdshader")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_LATEST_SILHOUETTE_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _tick in range(150):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
                hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null):
            break
    if hub.get_node_or_null("BaseStartupOverlay") != null:
        _fail("BASE did not boot")
        return
    var camera: Camera3D = hub.get("cam") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("BASE camera is no longer orthographic")
        return
    for key in KEYS:
        var path: String = "NEXUSBuilding/NexusArchitecture" if (
            key == "NEXUS") else "BaseFacilities/" + key + "/IndustrialModel"
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null:
            _fail("missing BASE facility " + key)
            return
        var silhouette_count: int = 0
        var corner_count: int = 0
        for child in model.get_children():
            if not child is MultiMeshInstance3D:
                continue
            var draw: MultiMeshInstance3D = child as MultiMeshInstance3D
            if draw.multimesh == null:
                continue
            var shader_material: ShaderMaterial = (
                draw.material_override as ShaderMaterial)
            if str(draw.name).begins_with("ArchitecturalEdgeInk_"):
                silhouette_count += draw.multimesh.instance_count
                if shader_material == null or shader_material.shader != SERA_SHADER:
                    _fail(key + " silhouette not using latest SERA shader")
                    return
                if not is_equal_approx(
                        float(shader_material.get_shader_parameter("stroke_px")), 6.0):
                    _fail(key + " current SERA outline no longer 6px")
                    return
                if draw.multimesh.mesh == null or (
                        not draw.multimesh.mesh is ArrayMesh):
                    _fail(key + " lacks real inverted hull")
                    return
            elif str(draw.name).begins_with("ArchitecturalCreaseInk_"):
                corner_count += draw.multimesh.instance_count
                if shader_material == null or shader_material.shader != CORNER_SHADER:
                    _fail(key + " 2px crease renderer was replaced")
                    return
                if not is_equal_approx(
                        float(shader_material.get_shader_parameter("crease_px")), 2.0) or (
                        not bool(shader_material.get_shader_parameter("crease_only"))):
                    _fail(key + " 2px crease settings changed")
                    return
        if silhouette_count < 18 or corner_count < 18:
            _fail(key + " missing live silhouette/crease MultiMesh instances")
            return
        var fx: Node3D = model.get_node_or_null("BaseFacilityVFX") as Node3D
        if fx == null:
            _fail(key + " VFX lost")
            return
        for item in fx.get_children():
            if str(item.name).begins_with("ArchitecturalEdgeInk_") or (
                    str(item.name).begins_with("ArchitecturalCreaseInk_")):
                _fail(key + " smoke/light gained outlines")
                return
    var collector: Node3D = hub.get_node("BaseFacilities/SCRAP_COLLECTOR/IndustrialModel")
    var motion: Node = collector.get_node("FacilityMotion")
    var records: Dictionary = collector.get_meta("motion_entries", {})
    var claws: Array = records.get("FreshCollectorClawHead", [])
    if claws.is_empty():
        _fail("moving claw missing")
        return
    var claw: Dictionary = claws[0]
    if not claw.has("ink_mesh") or not claw.has("crease_mesh"):
        _fail("moving claw lost one of its outline layers")
        return
    motion.call("sample_at", 1.41)
    var original: Transform3D = (
        claw["mesh"] as MultiMesh).get_instance_transform(int(claw["index"]))
    var silhouette: Transform3D = (
        claw["ink_mesh"] as MultiMesh).get_instance_transform(int(claw["ink_index"]))
    var crease: Transform3D = (
        claw["crease_mesh"] as MultiMesh).get_instance_transform(int(claw["crease_index"]))
    if original.origin.distance_to(silhouette.origin) > 0.0001 or (
            original.origin.distance_to(crease.origin) > 0.0001):
        _fail("outline ink no longer follows the animated solid part")
        return
    if str(hub.get_node("NEXUSBuilding/NexusArchitecture").get_meta(
            "base_design", "")) != "ARCHIVED_20261122":
        _fail("older NEXUS geometry changed unexpectedly")
        return
    print("SERA_BASE_LATEST_SILHOUETTE_RUNTIME_PASS 8x latest 6px inverted hull plus 2px front creases")
    quit(0)
