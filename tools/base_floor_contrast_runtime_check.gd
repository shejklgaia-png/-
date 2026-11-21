extends SceneTree
## Checks deck brightness and materials in the real hub independently of code text.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_FLOOR_CONTRAST_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    var floor: Node3D = hub.get_node_or_null("PatchworkSteelFloor") as Node3D
    var facilities: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if floor == null or facilities == null:
        _fail("BASE floor or facilities missing")
        return
    var total: float = 0.0
    var brightest: float = 0.0
    var count: int = 0
    for child in floor.get_children():
        if not child.name.begins_with("GridPlateBatch_"):
            continue
        var batch: MultiMeshInstance3D = child as MultiMeshInstance3D
        var material: StandardMaterial3D = batch.material_override as StandardMaterial3D
        if material == null:
            _fail("deck metal batch missing material")
            return
        var color: Color = material.albedo_color
        # Godot's Color values are linear float components for this simple check.
        var luminance: float = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
        brightest = maxf(brightest, luminance)
        total += luminance
        count += 1
        if color.r > 0.22 or color.g > 0.22 or color.b > 0.23:
            _fail("metal deck is still too bright: " + str(color))
            return
        if material.roughness < 0.92 or material.metallic > 0.15:
            _fail("metal deck roughness/specular contrast not updated")
            return
    if count != 6:
        _fail("six original deck MultiMesh batches not preserved")
        return
    var smelter: Node3D = facilities.get_node_or_null("SMELTER") as Node3D
    var platform: MeshInstance3D = smelter.get_node_or_null("Foundation") as MeshInstance3D
    if platform == null:
        _fail("smelter platform absent")
        return
    var mat: StandardMaterial3D = platform.material_override as StandardMaterial3D
    if mat == null:
        _fail("smelter platform material absent")
        return
    var c: Color = mat.albedo_color
    var foundation_luminance: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    if foundation_luminance < brightest * 1.6:
        _fail("equipment platform does not contrast against floor")
        return
    var nexus: Node3D = hub.get_node_or_null("NEXUSBuilding") as Node3D
    if nexus == null or nexus.get_node_or_null("NexusArchitecture") == null:
        _fail("NEXUS must retain its own actual 3D model")
        return
    print("SERA_BASE_FLOOR_CONTRAST_RUNTIME_PASS avg=", total / 6.0)
    quit(0)
