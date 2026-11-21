extends SceneTree
## Eight independent silhouettes must be authored into real installed BASE meshes.
const Arch = preload("res://scripts/sera_base_architecture.gd")
const RoofIdentity = preload("res://scripts/sera_base_roof_identity.gd")
const FEATURES = {
    "NEXUS": ["NexusSteppedRoofCrown", "NexusRoofParapet"],
    "LABO": ["LabAsymmetricSailFlap", "LabTarpRidgeHoop"],
    "SCRAP_COLLECTOR": ["CollectorOpenGantryDeck", "CollectorGantryVoidRail"],
    "SMELTER": ["SmelterHeatDissipationFin", "SmelterStackCanopy"],
    "RECYCLER": ["RecyclerSplitJawRoof", "RecyclerRaisedGapTeeth"],
    "GENERATOR": ["GeneratorTurbineArchRib", "GeneratorSpineRail"],
    "STORAGE": ["StorageSteppedSteelLid", "StorageRaisedCargoHatch"],
    "BUILD_TERMINAL": ["TerminalCantileverRoofBlade", "TerminalSuspendedRoofBrace"],
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_ROOF_IDENTITY_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _frame in range(36):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null:
            break
    for key in FEATURES:
        var path: String = ("NEXUSBuilding/NexusArchitecture" if key == "NEXUS"
            else "BaseFacilities/" + key + "/IndustrialModel")
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null:
            _fail("missing model: " + key)
            return
        var features: Array = model.get_meta("unique_model_features", [])
        for feature in FEATURES[key]:
            if not features.has(feature):
                _fail(key + " missing real rendered feature " + feature)
                return
        var expected_scale: float = (1.14 if key == "NEXUS"
            else 1.45 if key == "LABO" else 1.55)
        if absf(float(model.get_meta("visual_model_scale", 0)) - expected_scale) > 0.001:
            _fail("facility scale changed: " + key)
            return
        var probe_host := Node3D.new()
        var probe := Arch.Batch.new(probe_host)
        RoofIdentity.add_details(probe, key)
        var count: int = 0
        var highest: float = -100.0
        var types: int = probe.entries.size()
        for rows in probe.entries.values():
            for raw in rows:
                var pose: Transform3D = raw
                count += 1
                highest = maxf(highest, pose.origin.y)
        probe_host.free()
        if count < 7 or types < 2:
            _fail(key + " roof lacks independent authored geometry")
            return
        if highest < (4.8 if key == "NEXUS" else 2.55):
            _fail(key + " roof silhouette is below the existing building")
            return
        var rendered: int = 0
        for node in model.get_children():
            if node is MultiMeshInstance3D:
                rendered += (node as MultiMeshInstance3D).multimesh.instance_count
        if rendered < count:
            _fail("roof not present in batched runtime geometry: " + key)
            return
    print("SERA_BASE_ROOF_IDENTITY_RUNTIME_PASS eight distinctive batched roofs")
    quit(0)
