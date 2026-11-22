extends SceneTree
## Contract: consistent closed shells cull back; open/non-manifold remain 2-sided.
const FACE_CULLING = preload("res://scripts/sera_face_culling.gd")
const SERA_RIG = preload("res://scripts/sera_rig.gd")
const BOSS_RIG = preload("res://scripts/bittaran_rig.gd")
const EDGES = preload("res://scripts/sera_view_edges.gd")
const FAST_SHADER = preload("res://shaders/sera_view_edges_fast.gdshader")
const FALLBACK_SHADER = preload("res://shaders/sera_view_edges.gdshader")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_FACE_CULLING_RUNTIME_FAIL: " + reason)
    quit(1)

func _test_element(reverse_all: bool = false, flip_one: bool = false,
        make_open: bool = false) -> Dictionary:
    var verts := {
        "a": [0.0,0.0,0.0], "b": [1.0,0.0,0.0],
        "c": [0.0,1.0,0.0], "d": [0.0,0.0,1.0]
    }
    var polygons: Array = [
        ["a","c","b"], ["a","b","d"], ["a","d","c"], ["b","c","d"]
    ]
    if make_open:
        polygons.remove_at(0)
    if reverse_all:
        for f in polygons:
            f.reverse()
    if flip_one:
        (polygons[0] as Array).reverse()
    var faces := {}
    for i in range(polygons.size()):
        faces["f%d" % i] = {"vertices": polygons[i],
            "uv":{"a":[0,0],"b":[1,0],"c":[0,1],"d":[1,1]}}
    return {"name": "CullingFixture", "vertices": verts, "faces": faces, "color":2}

func _run() -> void:
    for description in ["normal", "reversed", "one_reversed", "open"]:
        var element := _test_element(
            description == "reversed", description == "one_reversed",
            description == "open")
        var audit: Dictionary = FACE_CULLING.inspect_element(element)
        if description == "open":
            if bool(audit["cull_back"]):
                _fail("open face must remain two-sided")
                return
        elif not bool(audit["cull_back"]):
            _fail(description + " closed tetrahedron must be single-sided")
            return
        if description == "normal" and not (audit["reverse_faces"] as Dictionary).is_empty():
            _fail("correct authored outward winding was changed")
            return
        if description == "reversed" and (audit["reverse_faces"] as Dictionary).size() != 4:
            _fail("inward shell was not fixed as a component")
            return
        if description == "one_reversed" and (audit["reverse_faces"] as Dictionary).size() != 1:
            _fail("locally reversed polygon was not corrected")
            return
        var rig: Node3D = SERA_RIG.new()
        var piece: MeshInstance3D = rig.call("_make_mesh", element)
        if piece == null:
            _fail(description + " could not be triangulated")
            return
        var material: StandardMaterial3D = piece.material_override as StandardMaterial3D
        if material == null:
            _fail("rig's original opaque material was lost")
            return
        var wanted := BaseMaterial3D.CULL_DISABLED if description == "open" else BaseMaterial3D.CULL_FRONT
        # Canonical positive signed volume means Godot front-face winding is
        # reversed relative to outward polygon normals.
        if material.cull_mode != wanted:
            _fail(description + " wrong GPU culling policy")
            return
        if bool(piece.get_meta("sera_single_sided", false)) == (description == "open"):
            _fail(description + " wrong fast-path metadata")
            return
        piece.free()
        rig.free()
    # Real canonical camera-eye has two open pieces. Preserve their material,
    # but allow its four closed pieces to use the zero-depth-tap shader.
    # The fast outline renders the opposite side of the solid surface,
    # rather than painting its outward-authored front polygons black.
    if FAST_SHADER.code.contains("cull_front") or (
            not FAST_SHADER.code.contains("cull_back")):
        _fail("fast ink must cull the opposite Godot winding from the source")
        return
    var text: String = FileAccess.get_file_as_string(
        "res://models/storage/カメラアイ頭部.bbmodel")
    var data: Variant = JSON.parse_string(text)
    if not (data is Dictionary):
        _fail("HEAD D source failed to load")
        return
    var closed_count := 0
    var fallback_count := 0
    for element in data.get("elements", []):
        var state: Dictionary = FACE_CULLING.inspect_element(element)
        if bool(state["cull_back"]):
            closed_count += 1
        else:
            fallback_count += 1
    if closed_count != 4 or fallback_count != 2:
        _fail("HEAD D must have four closed and two open mesh pieces")
        return
    # Check both source texture and fast-pathed material selection.
    var actor := Node3D.new()
    root.add_child(actor)
    var block := MeshInstance3D.new()
    block.mesh = BoxMesh.new()
    var opaque := StandardMaterial3D.new()
    opaque.cull_mode = BaseMaterial3D.CULL_FRONT
    block.material_override = opaque
    block.set_meta("sera_single_sided", true)
    actor.add_child(block)
    var overlay := EDGES.new()
    actor.add_child(overlay)
    await process_frame
    var outline: MeshInstance3D = block.get_node_or_null("SeraEdgeInk")
    if outline == null or (
            (outline.material_override as ShaderMaterial).shader != FAST_SHADER):
        _fail("verified closed material did not use fast zero-depth shader")
        return
    block.set_meta("sera_single_sided", false)
    overlay.call("_sync_meshes")
    await process_frame
    outline = block.get_node_or_null("SeraEdgeInk")
    if outline == null or (
            (outline.material_override as ShaderMaterial).shader != FALLBACK_SHADER):
        _fail("open/uncertain mesh did not use safe fallback shader")
        return
    actor.queue_free()
    await process_frame
    print("SERA_FACE_CULLING_RUNTIME_PASS")
    quit(0)
