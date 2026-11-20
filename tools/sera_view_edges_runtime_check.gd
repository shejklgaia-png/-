extends SceneTree
## Validate geometric 80-degree creases, smooth joins and GL-compat shader construction.
const OUTLINE = preload("res://scripts/sera_view_edges.gd")
const SHADER = preload("res://shaders/sera_view_edges.gdshader")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_VIEW_EDGES_RUNTIME_FAIL: " + reason)
    quit(1)

func _hinge(degrees: float) -> ArrayMesh:
    var a := Vector3.ZERO
    var b := Vector3.RIGHT
    var c := Vector3.UP
    var rad: float = deg_to_rad(degrees)
    var d := Vector3(0.0, cos(rad), sin(rad))
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for p in [a, b, c, a, b, d]:
        st.add_vertex(p)
    return st.commit()

func _shared_edge(edges: Array) -> Dictionary:
    for raw in edges:
        var e: Dictionary = raw
        var a: Vector3 = e["a"]
        var b: Vector3 = e["b"]
        if (a.distance_to(Vector3.ZERO) < 0.001 and b.distance_to(Vector3.RIGHT) < 0.001) or (
                b.distance_to(Vector3.ZERO) < 0.001 and a.distance_to(Vector3.RIGHT) < 0.001):
            return e
    return {}

func _run() -> void:
    var low: Dictionary = _shared_edge(OUTLINE._extract_edges(_hinge(79.0)))
    var high: Dictionary = _shared_edge(OUTLINE._extract_edges(_hinge(81.0)))
    if low.is_empty() or high.is_empty():
        _fail("shared hinge not extracted")
        return
    if bool(low["crease"]) or not bool(high["crease"]):
        _fail("80-degree threshold is not exclusive for 79 and inclusive for 81")
        return
    for angle: float in [0.0, 30.0, 79.0, 81.0, 90.0]:
        var overlay: ArrayMesh = OUTLINE._build_overlay(_hinge(angle))
        if overlay == null or overlay.get_surface_count() != 1:
            _fail("overlay mesh missing for angle " + str(angle))
            return
        if (overlay.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() % 6 != 0:
            _fail("non-triangle edge ribbons")
            return
    var source := MeshInstance3D.new()
    source.mesh = BoxMesh.new()
    var actor := Node3D.new()
    actor.name = "Actor"
    actor.add_child(source)
    root.add_child(actor)
    var outlines := OUTLINE.new()
    outlines.name = "ViewEdges"
    actor.add_child(outlines)
    await process_frame
    if source.get_node_or_null("SeraEdgeInk") == null:
        _fail("visual mesh did not receive an edge overlay")
        return
    var material: ShaderMaterial = (source.get_node("SeraEdgeInk") as MeshInstance3D).material_override
    if material == null or material.shader != SHADER:
        _fail("outline shader was not assigned")
        return
    if not (material.get_shader_parameter("stroke_px") is float):
        _fail("stroke uniform missing")
        return
    actor.queue_free()
    await process_frame
    print("SERA_VIEW_EDGES_RUNTIME_PASS")
    quit(0)
