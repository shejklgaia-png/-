extends SceneTree
## Validate true edge ribbon topology, both independent ink passes and all sites.
const BASE = preload("res://scripts/sera_base_facility_outlines.gd")
const SILHOUETTE = preload("res://shaders/base_facility_silhouette_edges.gdshader")
const CREASE = preload("res://shaders/base_facility_view_edges.gdshader")
const KEYS: Array[String] = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL"]
func _initialize() -> void:
    call_deferred("_run")
func _fail(message: String) -> void:
    push_error("BASE_VISIBLE_CONTOUR_RIBBON_FAIL: " + message)
    quit(1)
func _run() -> void:
    var shape: ArrayMesh = BASE.overlay_for("ribbon_box", BoxMesh.new())
    if shape == null:
        _fail("no 6px contour ribbon mesh")
        return
    var arrays: Array = shape.surface_get_arrays(0)
    var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    if verts.size() < 48 or verts.size() % 6 != 0 or (
            normals.size() != verts.size()) or arrays[Mesh.ARRAY_CUSTOM0] == null:
        _fail("opaque face triangles supplied instead of edge ribbons")
        return
    var corner_shape: ArrayMesh = BASE.crease_for("ribbon_box", BoxMesh.new())
    if corner_shape == null:
        _fail("preserved 2px crease geometry missing")
        return
    var black: ShaderMaterial = BASE.material()
    var gray: ShaderMaterial = BASE.crease_material()
    if black.shader != SILHOUETTE or gray.shader != CREASE or (
            black.get_shader_parameter("ink_color") != Color("#000000")) or (
            gray.get_shader_parameter("ink_color") != Color("#353535")) or (
            not is_equal_approx(float(black.get_shader_parameter("stroke_px")), 6.0)) or (
            not is_equal_approx(float(gray.get_shader_parameter("crease_px")), 2.0)):
        _fail("approved 6px black contour / 2px gray corner passes changed")
        return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for i in range(150):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
                hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null):
            break
    for key in KEYS:
        var path: String = "NEXUSBuilding/NexusArchitecture" if key == "NEXUS" else (
            "BaseFacilities/" + key + "/IndustrialModel")
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null:
            _fail("facility missing: " + key)
            return
        var ink_batches := 0
        var crease_batches := 0
        for item in model.get_children():
            if item is MultiMeshInstance3D:
                var batch: MultiMeshInstance3D = item as MultiMeshInstance3D
                if str(batch.name).begins_with("ArchitecturalEdgeInk_"):
                    if batch.material_override != black:
                        _fail("noncontour material on " + key)
                        return
                    ink_batches += 1
                elif str(batch.name).begins_with("ArchitecturalCreaseInk_"):
                    if batch.material_override != gray:
                        _fail("missing approved corner material on " + key)
                        return
                    crease_batches += 1
        if ink_batches == 0 or ink_batches != crease_batches:
            _fail("paired silhouette/corner batches missing on " + key)
            return
    print("BASE_VISIBLE_CONTOUR_RIBBON_RUNTIME_PASS all eight machines")
    quit(0)
