extends SceneTree
## Verifies the reference geometry is rendered by every real facility, and
## the floor is still constructed with batched details.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_REFERENCE_POLISH_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    # BASE deliberately paints an initial frame before building the 3D yard.
    # Await the finished world, not that preliminary loading frame.
    for _boot_frame in range(12):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") != null:
            break
    var expected := {
        "NEXUSBuilding/NexusArchitecture": "SealedGate",
        "BaseFacilities/LABO/IndustrialModel": "FreshLabFabricationBed",
        "BaseFacilities/SCRAP_COLLECTOR/IndustrialModel": "FreshCollectorTallBoom",
        "BaseFacilities/SMELTER/IndustrialModel": "FreshSmelterHotThroat",
        "BaseFacilities/RECYCLER/IndustrialModel": "FreshRecyclerOpenVJaws",
        "BaseFacilities/GENERATOR/IndustrialModel": "FreshGeneratorFrontRotor",
        "BaseFacilities/STORAGE/IndustrialModel": "FreshStorageOffsetStacks",
        "BaseFacilities/BUILD_TERMINAL/IndustrialModel": "FreshTerminalWideScreen",
    }
    for path in expected:
        var group: Node3D = hub.get_node_or_null(path) as Node3D
        if group == null:
            _fail("facility missing: " + path)
            return
        var features: Array = group.get_meta("unique_model_features", [])
        if not features.has(expected[path]):
            _fail("physical detail was not attached: " + path)
            return
        var instances: int = 0
        for child in group.get_children():
            if child is MultiMeshInstance3D:
                instances += (child as MultiMeshInstance3D).multimesh.instance_count
        if instances < 50:
            _fail("facility detail mesh was unexpectedly sparse: " + path)
            return
    var deck: Node3D = hub.get_node_or_null(
        "PatchworkSteelFloor/DeckDetailGeometry") as Node3D
    if deck == null:
        _fail("floor details missing")
        return
    for feature in ["DeckPlateEdgeWelds", "DeckServiceScuffs", "DeckFastenerRows"]:
        var present: bool = false
        for child in deck.get_children():
            if str(child.name).begins_with(feature + "_"):
                present = true
                if not child is MultiMeshInstance3D:
                    _fail("non-instanced deck finish: " + feature)
                    return
        if not present:
            _fail("deck finish not rendered: " + feature)
            return
    print("SERA_BASE_REFERENCE_POLISH_RUNTIME_PASS")
    quit(0)
