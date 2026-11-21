extends SceneTree
## Test real CPU multi-mesh transforms (including true pitch/roll), plus scene output.
const Architecture = preload("res://scripts/sera_base_architecture.gd")
const Junk = preload("res://scripts/sera_base_junk_geometry.gd")
const Props = preload("res://scripts/sera_base_clutter.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_JUNK_MODELS_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var shapes: Dictionary = {}
    var tilted: int = 0
    var total_plates: int = 0
    for variant in range(Junk.PANEL_SHAPES):
        var node := Node3D.new()
        var batch := Architecture.Batch.new(node)
        Junk.panel_stack(batch, Vector2.ZERO, 1.0, variant)
        var plates: int = 0
        for key in batch.entries:
            for pose_raw in batch.entries[key]:
                var pose: Transform3D = pose_raw
                var edge: Vector3 = pose.basis.x
                if edge.length() < 0.65 and edge.length() > 0.30 and (
                        absf(edge.y) > 0.02):
                    tilted += 1
                if str(key).begins_with("cube|") and (
                        pose.basis.y.length() < 0.08):
                    plates += 1
                    total_plates += 1
                    shapes[Vector2i(roundi(pose.basis.x.length() * 100.0),
                        roundi(pose.basis.z.length() * 100.0))] = true
        if plates < 5:
            _fail("panel variant has too few thin plates: " + str(variant))
            return
        node.free()
    if total_plates < 30 or shapes.size() < 8 or tilted < 10:
        _fail("plate model lacks size/form and real X/Z slope variety")
        return
    # The live storage/build-terminal clutter must still use those real sheets.
    for key in ["STORAGE", "BUILD_TERMINAL"]:
        var found: bool = false
        for p in Props.props_for(key):
            if str(p["kind"]) == "panel_stack":
                found = true
                break
        if not found:
            _fail(key + " lost panel stacks")
            return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    var salvage: Node3D = hub.get_node_or_null("SalvageMeshes") as Node3D
    if salvage == null:
        _fail("single shared salvage batch missing")
        return
    var profiles: Dictionary = {}
    for i in range(16):
        var pile: Node3D = hub.get_node_or_null("ScrapPile_%02d" % i) as Node3D
        if pile == null:
            _fail("missing existing salvage anchor: " + str(i))
            return
        profiles[int(pile.get_meta("scrap_profile", -1))] = true
    if profiles.size() != Junk.SCRAP_PROFILES:
        _fail("not enough distinct scrap designs")
        return
    var draws: int = 0
    var instances: int = 0
    var has_rods: bool = false
    var has_panels: bool = false
    for child in salvage.get_children():
        if not child is MultiMeshInstance3D:
            continue
        var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
        if mm == null:
            continue
        draws += 1
        instances += mm.instance_count
        has_rods = has_rods or str(child.name).contains("_tube_")
        has_panels = has_panels or str(child.name).contains("_cube_")
    if draws > 11 or draws < 4 or instances < 230 or (
            not has_rods or not has_panels):
        _fail("salvage must be richly shaped but batched: " +
            str(draws) + " draw groups, " + str(instances) + " fragments")
        return
    print("SERA_BASE_JUNK_MODELS_RUNTIME_PASS: 6 plate profiles, 5 salvage designs, " +
        str(instances) + " fragments in " + str(draws) + " material batches")
    quit(0)
