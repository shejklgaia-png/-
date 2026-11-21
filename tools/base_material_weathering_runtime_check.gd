extends SceneTree
## The floor and steel modules use one shared imported texture per material.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_BASE_MATERIAL_WEATHERING_FAIL: " + why)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    var tiled_floor: Node3D = hub.get_node_or_null("PatchworkSteelFloor") as Node3D
    if tiled_floor == null:
        _fail("floor missing")
        return
    var visited: int = 0
    for child in tiled_floor.get_children():
        if not child.name.begins_with("GridPlateBatch_"):
            continue
        var material: StandardMaterial3D = child.material_override as StandardMaterial3D
        if material == null or material.albedo_texture == null:
            _fail("steel plate lacks imported weathering texture")
            return
        visited += 1
    if visited != 6:
        _fail("original six shared floor batches changed")
        return
    var nexus: Node3D = hub.get_node_or_null("NEXUSBuilding/NexusArchitecture") as Node3D
    if nexus == null:
        _fail("NEXUS geometry missing")
        return
    var steel_found: bool = false
    for child in nexus.get_children():
        if child is MultiMeshInstance3D:
            var mat: StandardMaterial3D = child.material_override as StandardMaterial3D
            if mat != null and mat.albedo_texture != null:
                steel_found = true
                break
    if not steel_found:
        _fail("NEXUS steel geometry lacks weathered material")
        return
    print("SERA_BASE_MATERIAL_WEATHERING_RUNTIME_PASS")
    quit(0)
