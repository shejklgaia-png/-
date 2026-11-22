extends SceneTree
## Check actual visible industrial finish batches, not just the existence of source code.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_FUNCTIONAL_FINISH_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(24):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") != null:
            break
    var expected := {
        "NEXUSBuilding/NexusArchitecture": "FreshNexusGateLight",
        "BaseFacilities/LABO/IndustrialModel": "FreshLabPrinterHotHead",
        "BaseFacilities/SCRAP_COLLECTOR/IndustrialModel": "FreshCollectorOpenGrip",
        "BaseFacilities/SMELTER/IndustrialModel": "FreshSmelterHeatFin",
        "BaseFacilities/RECYCLER/IndustrialModel": "FreshRecyclerTooth",
        "BaseFacilities/GENERATOR/IndustrialModel": "FreshGeneratorRotorBlade",
        "BaseFacilities/STORAGE/IndustrialModel": "FreshStorageLoadingLift",
        "BaseFacilities/BUILD_TERMINAL/IndustrialModel": "FreshTerminalTactileKey",
    }
    for path in expected:
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null:
            _fail("missing 3D model: " + path)
            return
        if not (model.get_meta("unique_model_features", []) as Array).has(expected[path]):
            _fail("new industrial finish not in actual MultiMesh: " + path)
            return
        var count: int = 0
        for child in model.get_children():
            if child is MultiMeshInstance3D and (
                    child as MultiMeshInstance3D).multimesh != null:
                count += (child as MultiMeshInstance3D).multimesh.instance_count
        if count < 40:
            _fail("unexpectedly empty 3D machine finish: " + path)
            return
    var deck: Node3D = hub.get_node_or_null(
        "PatchworkSteelFloor/DeckDetailGeometry") as Node3D
    if deck == null:
        _fail("yard floor detail node missing")
        return
    var counts := {"DockEdgeDrain":0, "DockVentSlits":0, "DockAnchorShoes":0}
    for child in deck.get_children():
        if not child is MultiMeshInstance3D:
            continue
        for prefix in counts:
            if str(child.name).begins_with(prefix + "_"):
                counts[prefix] += (child as MultiMeshInstance3D).multimesh.instance_count
    if counts["DockEdgeDrain"] < 16 or counts["DockVentSlits"] < 48:
        _fail("facility docking perimeter floor details were not instanced")
        return
    if counts["DockAnchorShoes"] < 32:
        _fail("8 independent facility pad anchors were not rendered")
        return
    print("SERA_BASE_FUNCTIONAL_FINISH_RUNTIME_PASS")
    quit(0)
