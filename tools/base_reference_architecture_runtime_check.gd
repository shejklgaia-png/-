extends SceneTree
## Checks actual mesh groups, independently of visual screenshot assessment.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_REFERENCE_ARCHITECTURE_FAIL: " + reason)
    quit(1)

func _mesh_count(group: Node3D) -> int:
    var total: int = 0
    for child in group.get_children():
        if child is MultiMeshInstance3D:
            var draw: MultiMeshInstance3D = child
            if draw.multimesh != null:
                total += draw.multimesh.instance_count
    return total

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    var floor: Node3D = hub.get_node_or_null("PatchworkSteelFloor/DeckDetailGeometry") as Node3D
    if floor == null or _mesh_count(floor) < 300:
        _fail("metal deck lacks batched seams, grates, fasteners or markings")
        return
    var nexus: Node3D = hub.get_node_or_null("NEXUSBuilding/NexusArchitecture") as Node3D
    if nexus == null or _mesh_count(nexus) < 75:
        _fail("NEXUS is still a coarse box primitive")
        return
    var machines: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if machines == null:
        _fail("facility host missing")
        return
    var design_counts: Dictionary = {}
    for key in ["LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER",
            "GENERATOR", "STORAGE", "BUILD_TERMINAL"]:
        var model: Node3D = machines.get_node_or_null(key + "/IndustrialModel") as Node3D
        if model == null:
            _fail("facility lacks distinct industrial model: " + key)
            return
        var count: int = _mesh_count(model)
        if count < 25:
            _fail("facility model lacks reference details: " + key)
            return
        design_counts[key] = count
    var camera: Camera3D = hub.get("cam") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("FOV-zero camera must remain orthogonal")
        return
    var crate: Node3D = hub.get_node_or_null("CRATE") as Node3D
    if crate == null:
        _fail("CRATE patrol lost during rebuild")
        return
    print("SERA_BASE_REFERENCE_ARCHITECTURE_RUNTIME_PASS ", design_counts)
    quit(0)
