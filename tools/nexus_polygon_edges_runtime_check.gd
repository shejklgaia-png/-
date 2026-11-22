extends SceneTree
## Inspect live NEXUS batch materials, pad and independent SERA rig.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const EDGES = preload("res://shaders/nexus_polygon_edges.gdshader")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("NEXUS_POLYGON_EDGES_FAIL: " + message)
    quit(1)

func _run() -> void:
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    var hud: CanvasLayer = nexus.get_node_or_null("NexusInteractiveHUD") as CanvasLayer
    var outline: Control = nexus.get("outline") as Control
    if hud == null or outline == null or not hud.is_ancestor_of(outline):
        _fail("existing glowing selection silhouettes must stay on the foreground CanvasLayer")
        return
    var batches := 0
    var edged := 0
    var luminous := 0
    for child in nexus.get_children():
        if not (child is MultiMeshInstance3D) or not str(child.name).begins_with("BlockbenchBatch_"):
            continue
        var batch := child as MultiMeshInstance3D
        var index := int(str(child.name).trim_prefix("BlockbenchBatch_"))
        var material := batch.material_override as StandardMaterial3D
        if material == null or batch.multimesh == null:
            _fail("live Blockbench batch has no material or geometry")
            return
        batches += 1
        if index in [5, 6, 7]:
            luminous += 1
            if material.next_pass != null or not material.emission_enabled:
                _fail("original luminous accent must remain unmodified")
                return
            continue
        edged += 1
        var edge := material.next_pass as ShaderMaterial
        if edge == null or edge.shader != EDGES:
            _fail("a structural batch is missing the edge-only second pass")
            return
        if edge.render_priority != RENDER_ORDER.NEXUS_SURFACE_EDGES:
            _fail("grey edge pass has an incorrect draw order")
            return
        if absf(float(edge.get_shader_parameter("width_px")) - 2.0) > 0.0001:
            _fail("screen-space edge width is not two pixels")
            return
        if int(edge.get_shader_parameter("geometry_mode")) != 0:
            _fail("box batches must use cube geometry edges")
            return
    if batches < 8 or edged < 5 or luminous < 3:
        _fail("expected full structural and luminous NEXUS batch coverage")
        return
    var pad := nexus.get_node_or_null("NexusMaintenancePadCenter") as MeshInstance3D
    if pad == null:
        _fail("NEXUS maintenance platform missing")
        return
    var pad_material := pad.material_override as StandardMaterial3D
    var pad_edge := pad_material.next_pass as ShaderMaterial if pad_material != null else null
    if pad_edge == null or pad_edge.shader != EDGES or int(pad_edge.get_shader_parameter("geometry_mode")) != 1:
        _fail("12-sided maintenance pad must receive its geometry-specific outline")
        return
    var rig := nexus.get("sera_display_rig") as Node3D
    if rig == null or not bool(rig.get("loading_ok")):
        _fail("SERA display rig failed to initialize")
        return
    var inspected := 0
    for slot in ["head", "torso", "legs", "arms"]:
        for piece_ref in rig.call("get_equipment_visible_meshes", slot):
            var piece := piece_ref as MeshInstance3D
            if piece == null:
                continue
            inspected += 1
            for material in [piece.material_override, piece.material_overlay]:
                if material == null:
                    continue
                var overlay := (material as Material).next_pass as ShaderMaterial
                if overlay != null and overlay.shader == EDGES:
                    _fail("SERA must never use the interior polygon-edge shader")
                    return
    if inspected == 0:
        _fail("could not inspect SERA's live equipment meshes")
        return
    nexus.queue_free()
    await process_frame
    print("NEXUS_POLYGON_EDGES_RUNTIME_PASS")
    quit(0)
