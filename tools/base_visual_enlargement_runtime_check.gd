extends SceneTree
## Read real instantiated nodes; verify visual scale without altering touch
## bounds, dedicated single slabs, or the surrounding scatter props.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_VISUAL_ENLARGEMENT_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(22):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") != null:
            break
    var expected := {
        "NEXUSBuilding/NexusArchitecture": 1.14,
        "BaseFacilities/LABO/IndustrialModel": 1.45,
        "BaseFacilities/SCRAP_COLLECTOR/IndustrialModel": 1.55,
        "BaseFacilities/SMELTER/IndustrialModel": 1.55,
        "BaseFacilities/RECYCLER/IndustrialModel": 1.55,
        "BaseFacilities/GENERATOR/IndustrialModel": 1.55,
        "BaseFacilities/STORAGE/IndustrialModel": 1.55,
        "BaseFacilities/BUILD_TERMINAL/IndustrialModel": 1.55,
    }
    for path in expected:
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null or not model.has_meta("visual_model_scale"):
            _fail("missing 3D body or visual scale: " + path)
            return
        if not is_equal_approx(float(model.get_meta("visual_model_scale")),
                float(expected[path])):
            _fail("unexpected 3D body scale: " + path)
            return
        var draws: int = 0
        for child in model.get_children():
            if child is MultiMeshInstance3D and child.multimesh != null:
                draws += child.multimesh.instance_count
        if draws < 30:
            _fail("visual enlargement lost geometry: " + path)
            return
    var nexus: Node3D = hub.get_node("NEXUSBuilding/NexusArchitecture") as Node3D
    var features: Array = nexus.get_meta("unique_model_features", [])
    if not features.has("FreshNexusFrontButtress") or (
            not features.has("FreshNexusSideLoadingHood")):
        _fail("fresh asymmetric NEXUS command wings not drawn")
        return
    print("SERA_BASE_VISUAL_ENLARGEMENT_RUNTIME_PASS")
    quit(0)
