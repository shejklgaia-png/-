extends SceneTree
## Real GL Compatibility pixels. Prevent SERA/IRIS closed armor from being
## covered by dark fast-outline triangles after a culling policy change.
## Run with a graphical viewport (xvfb); this is not a headless-only test.
const SERA_RIG = preload("res://scripts/sera_rig.gd")
const EDGES = preload("res://scripts/sera_view_edges.gd")
const UNIT: float = 0.065
const DIM: int = 512

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_ARMOUR_VISIBLE_INK_FAIL: " + reason)
    quit(1)

func _point(value: Variant) -> Vector3:
    return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _capture(viewport: SubViewport) -> Image:
    for n in range(12):
        await process_frame
    await RenderingServer.frame_post_draw
    return viewport.get_texture().get_image()

func _run() -> void:
    var path: String = "res://models/storage/カメラアイ頭部.bbmodel"
    var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not payload is Dictionary:
        _fail("authored IRIS model unavailable")
        return

    var viewport := SubViewport.new()
    viewport.size = Vector2i(DIM, DIM)
    viewport.transparent_bg = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var actor := Node3D.new()
    viewport.add_child(actor)
    var rig: Node3D = SERA_RIG.new()
    # SeraRig's real source-to-triangle converter; no schematic substitute.
    var solid_count: int = 0
    var double_count: int = 0
    var pieces: Array[MeshInstance3D] = []
    for element_value in payload.get("elements", []):
        var element: Dictionary = element_value
        var piece: MeshInstance3D = rig.call("_make_mesh", element)
        if piece == null:
            _fail("IRIS mesh creation failed")
            return
        piece.name = "IRIS_%d" % pieces.size()
        piece.position = _point(element.get("origin", [0, 0, 0])) * UNIT
        piece.quaternion = rig.call("_blockbench_rotation",
            _point(element.get("rotation", [0, 0, 0])))
        # Neutral authored-geometry probe: only cull order and ink vary.
        var original: StandardMaterial3D = piece.material_override as StandardMaterial3D
        var neutral := original.duplicate() as StandardMaterial3D
        neutral.albedo_texture = null
        neutral.albedo_color = Color(0.82, 0.85, 0.90)
        neutral.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        piece.material_override = neutral
        actor.add_child(piece)
        pieces.append(piece)
        if bool(piece.get_meta("sera_single_sided", false)):
            solid_count += 1
        else:
            double_count += 1
    if solid_count != 4 or double_count != 2:
        _fail("IRIS test did not load 4 solid + 2 open meshes")
        return

    var lower := Vector3(INF, INF, INF)
    var upper := Vector3(-INF, -INF, -INF)
    for piece in pieces:
        var aabb: AABB = piece.mesh.get_aabb()
        for i in range(8):
            var p: Vector3 = piece.to_global(aabb.get_endpoint(i))
            lower = lower.min(p)
            upper = upper.max(p)
    var center: Vector3 = (lower + upper) * 0.5
    var diameter: float = maxf((upper - lower).length(), 0.4)
    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = diameter * 1.5
    viewport.add_child(camera)
    camera.position = center + Vector3(0.4, 0.25, 1.0).normalized() * diameter * 2.5
    camera.look_at(center)
    camera.current = true

    var controller := EDGES.new()
    controller.name = "IRIS_Silhouettes"
    actor.add_child(controller)
    await process_frame
    var ink_pieces: Array[MeshInstance3D] = []
    for piece in pieces:
        var ink: MeshInstance3D = piece.get_node_or_null("SeraEdgeInk") as MeshInstance3D
        if ink == null:
            _fail("IRIS real mesh missing ink instance")
            return
        ink_pieces.append(ink)
        ink.visible = false

    var base: Image = await _capture(viewport)
    for ink in ink_pieces:
        ink.visible = true
    var outlined: Image = await _capture(viewport)
    var output: String = OS.get_environment("SERA_ARMOUR_CAPTURE_DIR")
    if output.is_empty():
        output = "/tmp/sera-armour-culling"
    DirAccess.make_dir_recursive_absolute(output)
    if base.save_png(output.path_join("IRIS_no_ink.png")) != OK or (
            outlined.save_png(output.path_join("IRIS_with_ink.png")) != OK):
        _fail("failed to save actual Godot screenshots")
        return

    var base_covered: int = 0
    var black_fill: int = 0
    for y in range(DIM):
        for x in range(DIM):
            var a: Color = base.get_pixel(x, y)
            var b: Color = outlined.get_pixel(x, y)
            if a.a < 0.9:
                continue
            base_covered += 1
            var initial_light: float = (a.r + a.g + a.b) / 3.0
            var ink_light: float = (b.r + b.g + b.b) / 3.0
            if initial_light > 0.5 and ink_light < 0.25:
                black_fill += 1
    if base_covered < 900:
        _fail("no visible original armour in baseline; invalid test")
        return
    var ratio: float = float(black_fill) / float(base_covered)
    print("SERA_ARMOUR_REAL_PIXEL_METRICS " + JSON.stringify({
        "model": "HEAD D / IRIS", "source_pixels": base_covered,
        "blackened_interior_pixels": black_fill,
        "blackened_ratio": ratio, "render_method": ProjectSettings.get_setting(
            "rendering/renderer/rendering_method")}))
    if ratio > 0.16:
        _fail("ink covered more than 16% of originally visible armour: " + str(ratio))
        return
    print("SERA_ARMOUR_VISIBLE_INK_PASS")
    quit(0)
