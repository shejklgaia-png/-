extends SceneTree
## Godot 4.7 live scene: original models remain archived, but none render.
## Enforces actual batch geometry, 8 independent identities, touch and camera.
const FEATURES = {
    "NEXUS": ["NexusCutCornerShell", "ArmoredRoof", "GatePortal", "SealedGate", "FrontEmblem"],
    "LABO": ["FreshLabOpenPrinterBridge", "FreshLabFabricationBed", "FreshLabPrinterHotHead"],
    "SCRAP_COLLECTOR": ["FreshCollectorTallBoom", "FreshCollectorOpenGrip", "FreshCollectorClawHead"],
    "SMELTER": ["FreshSmelterTwinStacks", "FreshSmelterHotThroat", "FreshSmelterFlameTongue"],
    "RECYCLER": ["FreshRecyclerOpenVJaws", "FreshRecyclerRoller", "FreshRecyclerTooth"],
    "GENERATOR": ["FreshGeneratorFrontRotor", "FreshGeneratorBlueCorona", "FreshGeneratorCoreRib"],
    "STORAGE": ["FreshStorageOffsetStacks", "FreshStorageLoadingLift", "FreshStorageCaseLid"],
    "BUILD_TERMINAL": ["FreshTerminalWideScreen", "FreshTerminalSignalMast", "FreshTerminalBlueprintRows"],
}
const OLD_ONLY = [
    "NexusRoofCommandStripe", "LabSingleSlopeCanopy",
    "CollectorOpenBoomCrossbar", "SmelterHeatShieldRib",
    "RecyclerSideRoofShutter", "GeneratorTurbineHoop",
    "StorageRoofRidge", "TerminalSlimDataVisor",
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_FRESH_REBUILD_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(100):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
            hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null):
            break
    var camera: Camera3D = hub.get("cam") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or (
        absf(camera.size - 38.0) > 0.001 or
        camera.position.distance_to(Vector3(21.0, 19.5, 25.0)) > 0.001):
        _fail("real BASE camera was altered to hide new geometry shortcomings")
        return
    var sites: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    if sites == null:
        _fail("facilities absent after actual BASE boot")
        return
    for key in FEATURES:
        var building: Node3D = (hub.get_node_or_null("NEXUSBuilding") as Node3D
            if key == "NEXUS" else sites.get_node_or_null(key) as Node3D)
        if building == null:
            _fail(key + " building node was lost")
            return
        var model: Node3D = building.get_node_or_null(
            "NexusArchitecture" if key == "NEXUS" else "IndustrialModel") as Node3D
        if model == null or str(model.get_meta("base_design", "")) != (
                "ARCHIVED_20261122" if key == "NEXUS" else "FRESH_20261122"):
            _fail(key + " was not rebuilt from independent fresh mesh source")
            return
        var scale: float = float(model.get_meta("visual_model_scale", 0.0))
        var target_scale: float = 1.14 if key == "NEXUS" else (
            1.45 if key == "LABO" else 1.55)
        if absf(scale - target_scale) > 0.001:
            _fail(key + " physical footprint changed")
            return
        var features: Array = model.get_meta("unique_model_features", [])
        for identity in FEATURES[key]:
            if not features.has(identity):
                _fail(key + " signature missing real batch geometry " + identity)
                return
        for invalid in OLD_ONLY:
            if key != "NEXUS" and features.has(invalid):
                _fail(key + " still draws legacy geometry " + invalid)
                return
        var batches: int = 0
        var vertices: int = 0
        for n in model.get_children():
            if n is MultiMeshInstance3D:
                batches += 1
                if (n as MultiMeshInstance3D).multimesh != null:
                    vertices += (n as MultiMeshInstance3D).multimesh.instance_count
        if batches < 3 or vertices < (50 if key == "NEXUS" else 25):
            _fail(key + " new physical 3D volume is absent / too sparse")
            return
        var tap: Vector2 = camera.unproject_position(
            building.global_position + Vector3(0.0, 1.0, 0.0))
        if key == "NEXUS":
            if not bool(hub.call("_nexus_hit", tap)):
                _fail("NEXUS hit zone was lost")
                return
        elif str(sites.call("key_at", camera, tap)) != key:
            _fail(key + " hit zone was lost")
            return
        var focus: Vector3 = building.global_position + Vector3(
            0.0, 3.0 if key == "NEXUS" else 1.5, 0.0)
        var onscreen: Vector2 = camera.unproject_position(focus)
        var size: Vector2 = camera.get_viewport().get_visible_rect().size
        if camera.is_position_behind(focus) or (
            onscreen.x < 5.0 or onscreen.x > size.x - 5.0 or
            onscreen.y < 90.0 or onscreen.y > size.y - 80.0):
            _fail(key + " 3D landmark is outside actual portrait gameplay area")
            return
    if hub.get_node_or_null("BaseFacilities/GENERATOR/EnergyRotor") == null:
        _fail("animated generator game mechanism disappeared")
        return
    print("SERA_BASE_FRESH_REBUILD_RUNTIME_PASS: 8 genuinely new models, legacy untouched, 8 taps, real camera")
    quit(0)
