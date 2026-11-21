extends SceneTree
## Real Godot scene: roof shapes must be concise and leave active faces exposed.
const Arch = preload("res://scripts/sera_base_architecture.gd")
const Roof = preload("res://scripts/sera_base_roof_identity.gd")
const FEATURES = {
    "NEXUS": ["NexusRoofCommandStripe", "NexusEntranceDirectionBand", "NexusDoorOuterFrame"],
    "LABO": ["LabSingleSlopeCanopy", "LabSideRoll", "LabPrinterToolhead"],
    "SCRAP_COLLECTOR": ["CollectorOpenBoomCrossbar", "CollectorCraneMarker", "CollectorOpenClawJaw", "CollectorRaisedJib"],
    "SMELTER": ["SmelterHeatShieldRib", "SmelterHeatVent", "SmelterStackHeatCollar"],
    "RECYCLER": ["RecyclerSideRoofShutter", "RecyclerOpenThroatRail", "RecyclerOpenVFeedRail", "RecyclerOpposedJawFace"],
    "GENERATOR": ["GeneratorTurbineHoop", "GeneratorPowerSpine", "GeneratorCoreCorona"],
    "STORAGE": ["StorageContainerRoof", "StorageRoofRidge", "StorageLoadingHeader"],
    "BUILD_TERMINAL": ["TerminalSlimDataVisor", "TerminalVisorBracket", "TerminalScanFrameSide"],
}
const TOP_MIN = {
    "NEXUS": 4.7, "LABO": 3.2, "SCRAP_COLLECTOR": 2.55,
    "SMELTER": 2.55, "RECYCLER": 2.10, "GENERATOR": 2.55,
    "STORAGE": 2.6, "BUILD_TERMINAL": 2.55,
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_ROOF_CLARITY_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(35):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null:
            break
    var station_root: Node3D = hub.get_node("BaseFacilities") as Node3D
    var camera: Camera3D = hub.get("cam") as Camera3D
    for key in FEATURES:
        var path: String = ("NEXUSBuilding/NexusArchitecture" if key == "NEXUS"
            else "BaseFacilities/" + key + "/IndustrialModel")
        var model: Node3D = hub.get_node_or_null(path) as Node3D
        if model == null:
            _fail("missing real facility: " + key)
            return
        var expected_scale: float = 1.14 if key == "NEXUS" else (1.45 if key == "LABO" else 1.55)
        if absf(float(model.get_meta("visual_model_scale", 0.0)) - expected_scale) > 0.001:
            _fail("facility scale has changed: " + key)
            return
        var features: Array = model.get_meta("unique_model_features", [])
        for feature in FEATURES[key]:
            if not features.has(feature):
                _fail("missing silhouette: " + key + "/" + feature)
                return
        var host := Node3D.new()
        var probe := Arch.Batch.new(host)
        Roof.add_details(probe, key)
        var n: int = 0
        var highest: float = -100.0
        var widest_upper_piece: float = 0.0
        for variant_key in probe.entries:
            var kind: String = str(variant_key).get_slice("|", 0)
            for raw in probe.entries[variant_key]:
                var pose: Transform3D = raw
                n += 1
                highest = maxf(highest, pose.origin.y)
                if pose.origin.y > 2.0 and kind in ["cube", "roof", "bevel", "canvas"]:
                    var size: Vector3 = pose.basis.get_scale()
                    widest_upper_piece = maxf(widest_upper_piece, maxf(size.x, size.z))
        host.free()
        if n < 3 or n > 27:
            _fail(key + " roof detail count is too dense/sparse: " + str(n))
            return
        if highest < float(TOP_MIN[key]):
            _fail(key + " signature below equipment silhouette")
            return
        if key not in ["NEXUS", "LABO", "STORAGE"] and widest_upper_piece > 2.60:
            _fail(key + " has an oversized opaque roof blocking the machine")
            return
        var building: Node3D = hub.get_node("NEXUSBuilding") as Node3D if key == "NEXUS" else (station_root.get_node(key) as Node3D)
        var tap: Vector2 = camera.unproject_position(building.global_position + Vector3(0, 1.0, 0))
        if key == "NEXUS":
            if not bool(hub.call("_nexus_hit", tap)):
                _fail("NEXUS touch area changed")
                return
        elif str(station_root.call("key_at", camera, tap)) != key:
            _fail(key + " touch area changed")
            return
    print("SERA_BASE_ROOF_CLARITY_RUNTIME_PASS exposed machines / 8 silhouettes")
    quit(0)
