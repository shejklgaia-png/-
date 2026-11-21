extends SceneTree
## End-to-end BASE night lighting and authored large detail, no screenshot assumptions.
const Arch = preload("res://scripts/sera_base_architecture.gd")
const FEATURES = {
    "NEXUS": "NexusServiceFan",
    "LABO": "LabCanopyCrest",
    "SCRAP_COLLECTOR": "CollectorWeatherHood",
    "SMELTER": "SmelterTallExhaust",
    "RECYCLER": "RecyclerRoofCowl",
    "GENERATOR": "GeneratorRoofShield",
    "STORAGE": "StorageFabricCanopy",
    "BUILD_TERMINAL": "TerminalServiceRoof",
}
const LIGHTS = {
    "NEXUS": "NexusAmberGateLight",
    "LABO": "LabTaskLighting",
    "SCRAP_COLLECTOR": "CollectorTaskLight",
    "SMELTER": "FurnaceHeatLight",
    "RECYCLER": "RecyclerWorkLight",
    "GENERATOR": "GeneratorCoreLight",
    "STORAGE": "StorageLoadingLight",
    "BUILD_TERMINAL": "TerminalWorkLight",
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_BASE_NIGHT_FACILITY_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(25):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/LABO/IndustrialModel") != null:
            break
    var env_node: WorldEnvironment = hub.get_node_or_null("WorldEnvironment") as WorldEnvironment
    var sun: DirectionalLight3D = hub.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
    if env_node == null or sun == null or env_node.environment == null:
        _fail("night environment not constructed")
        return
    if env_node.environment.ambient_light_energy > 0.45 or sun.light_energy > 0.45:
        _fail("yard is still daylight-bright")
        return
    var lights: int = 0
    for key in FEATURES:
        var path: String = "NEXUSBuilding/NexusArchitecture" if key == "NEXUS" else (
            "BaseFacilities/" + key + "/IndustrialModel")
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null:
            _fail("missing model: " + key)
            return
        var scale: float = float(model.get_meta("visual_model_scale", 0.0))
        if key == "NEXUS":
            if absf(scale - 1.14) > 0.001:
                _fail("NEXUS unexpectedly enlarged")
                return
        elif not is_equal_approx(scale, 1.45 if key == "LABO" else 1.55):
            _fail("station not enlarged to current approved size: " + key)
            return
        var features: Array = model.get_meta("unique_model_features", [])
        if not features.has(FEATURES[key]):
            _fail("large authored silhouette not batched: " + key)
            return
        var light: OmniLight3D = model.get_node_or_null(LIGHTS[key]) as OmniLight3D
        if light == null or light.shadow_enabled or light.omni_range < 2.5:
            _fail("physical efficient night lamp missing: " + key)
            return
        lights += 1
    if lights != 8:
        _fail("not all eight facilities have local lamps")
        return
    print("SERA_BASE_NIGHT_FACILITY_RUNTIME_PASS: facilities=8 lights=8")
    quit(0)
