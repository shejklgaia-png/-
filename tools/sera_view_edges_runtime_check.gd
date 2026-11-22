extends SceneTree
## Runtime: per-mesh screen-pixel inverted-hull outline, no face crease ribbons.
const OUTLINE = preload("res://scripts/sera_view_edges.gd")
const SHADER = preload("res://shaders/sera_view_edges.gdshader")
const FX_SHADER = preload("res://shaders/back_thruster.gdshader")

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

func _run() -> void:
    # View-space silhouette overlays contain whole triangle geometry, not
    # conditional edge ribbons. Changing the angle does not add/remove lines.
    for angle: float in [0.0, 30.0, 79.0, 81.0, 90.0, 120.0]:
        var overlay: ArrayMesh = OUTLINE._build_overlay(_hinge(angle))
        if overlay == null or overlay.get_surface_count() != 1:
            _fail("silhouette geometry missing for angle " + str(angle))
            return
        var arrays: Array = overlay.surface_get_arrays(0)
        var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        if verts.size() != 6 or normals.size() != 6:
            _fail("inverted hull must use the original 2 triangle faces, not 6-vertex edge ribbons")
            return
        for normal in normals:
            if not normal.is_finite() or normal.length() < 0.9:
                _fail("smoothing normals are invalid")
                return
    var cube: ArrayMesh = OUTLINE._build_overlay(BoxMesh.new())
    if cube == null:
        _fail("cube silhouette mesh is missing")
        return
    var cube_arrays: Array = cube.surface_get_arrays(0)
    if (cube_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() != 36:
        _fail("cube faces must remain twelve triangles and no polygon edge ribbons")
        return
    # The shader rasterizes only enlarged rear faces; front-facing surfaces
    # occlude internal convex/concave mesh polygon joins in the depth buffer.
    var shader_code: String = SHADER.code
    if not shader_code.contains("cull_front") or shader_code.contains("a_facing") or (
            not shader_code.contains("POSITION = clip;")):
        _fail("view-dependent silhouette shader was not installed")
        return
    if shader_code.contains("depth_test_disabled") or not shader_code.contains("ALPHA = 1.0;"):
        _fail("silhouette must be depth-tested in the post-opaque pass")
        return
    var source := MeshInstance3D.new()
    source.mesh = BoxMesh.new()
    var actor := Node3D.new()
    actor.name = "Actor"
    actor.add_child(source)
    root.add_child(actor)
    # A sword's visible geometry should receive ink, but the 3D slash
    # nested under a Swordeffect bone must never receive it.
    var sword := MeshInstance3D.new()
    sword.name = "PhysicalSwordBlade"
    sword.mesh = BoxMesh.new()
    actor.add_child(sword)

    var fx_root := Node3D.new()
    fx_root.name = "V85_3DSlash_AuthoredBoard_3Stage"
    actor.add_child(fx_root)
    var arc := MeshInstance3D.new()
    arc.name = "AlphaClippedMainArc" # contains no "effect"/"slash"
    arc.mesh = BoxMesh.new()
    fx_root.add_child(arc)
    var volume := MeshInstance3D.new()
    volume.name = "ConvexTwoSided3DArc" # same bug as the live effect
    volume.mesh = BoxMesh.new()
    fx_root.add_child(volume)

    var tagged_root := Node3D.new()
    tagged_root.name = "MiscContainer"
    tagged_root.set_meta("sera_no_view_edges", true)
    actor.add_child(tagged_root)
    var tagged_fx := MeshInstance3D.new()
    tagged_fx.name = "OpaqueArbitraryName"
    tagged_fx.mesh = BoxMesh.new()
    tagged_root.add_child(tagged_fx)

    # Detect an effect even when the name is neutral: transparent Standard
    # material or a shader writing ALPHA must never receive character ink.
    var transparent_fx := MeshInstance3D.new()
    transparent_fx.name = "Visual01"
    transparent_fx.mesh = BoxMesh.new()
    var transparent_mat := StandardMaterial3D.new()
    transparent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    transparent_fx.material_override = transparent_mat
    actor.add_child(transparent_fx)
    var shader_fx := MeshInstance3D.new()
    shader_fx.name = "Visual02"
    shader_fx.mesh = BoxMesh.new()
    var fx_material := ShaderMaterial.new()
    fx_material.shader = FX_SHADER
    shader_fx.material_override = fx_material
    actor.add_child(shader_fx)

    var outlines := OUTLINE.new()
    outlines.name = "ViewEdges"
    actor.add_child(outlines)
    await process_frame
    if source.get_node_or_null("SeraEdgeInk") == null or (
            sword.get_node_or_null("SeraEdgeInk") == null):
        _fail("solid body and physical weapon must receive outlines")
        return
    for fx in [arc, volume, tagged_fx, transparent_fx, shader_fx]:
        if fx.get_node_or_null("SeraEdgeInk") != null:
            _fail("VFX incorrectly received outline: " + str(fx.name))
            return
    # When a mesh switches into FX/opt-out after an earlier scan, clear the
    # stale ink child rather than simply declining to create new outlines.
    var stale_ink := MeshInstance3D.new()
    stale_ink.name = "SeraEdgeInk"
    tagged_fx.add_child(stale_ink)
    outlines.call("_sync_meshes")
    if tagged_fx.get_node_or_null("SeraEdgeInk") != null:
        _fail("stale FX outline child was not removed")
        return
    var material: ShaderMaterial = (source.get_node("SeraEdgeInk") as MeshInstance3D).material_override
    if material == null or material.shader != SHADER:
        _fail("outline shader was not assigned")
        return
    if not is_equal_approx(float(material.get_shader_parameter("stroke_px")), 3.0):
        _fail("outline stroke must be 3.0 pixels")
        return
    actor.queue_free()
    await process_frame
    print("SERA_VIEW_EDGES_RUNTIME_PASS")
    quit(0)
