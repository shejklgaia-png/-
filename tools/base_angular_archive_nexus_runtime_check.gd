extends SceneTree
## True live BASE nodes; archived command hall and seven sharp-edged facilities.
const STATIONS = ["LABO", "SCRAP_COLLECTOR", "SMELTER", "RECYCLER",
    "GENERATOR", "STORAGE", "BUILD_TERMINAL"]
const LEGACY = ["NexusCutCornerShell", "ArmoredRoof", "GatePortal",
    "SealedGate", "FrontEmblem", "NexusFacadeArmor", "NexusRoofServiceRack"]
const FRESH = ["FreshNexusCommandHull", "FreshNexusSplitCrown", "FreshNexusGateCore"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_ANGULAR_ARCHIVE_NEXUS_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _step in range(100):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
                hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null):
            break
    var cam: Camera3D = hub.get("cam") as Camera3D
    if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or (
            absf(cam.size - 38.0) > 0.001):
        _fail("approved BASE view was altered")
        return
    var nexus: Node3D = hub.get_node_or_null("NEXUSBuilding/NexusArchitecture") as Node3D
    if nexus == null or str(nexus.get_meta("base_design", "")) != "ARCHIVED_20261122":
        _fail("NEXUS did not restore its two-versions-old archived source")
        return
    var nexus_parts: Array = nexus.get_meta("unique_model_features", [])
    for key in LEGACY:
        if not nexus_parts.has(key):
            _fail("original NEXUS piece missing: " + key)
            return
    for key in FRESH:
        if nexus_parts.has(key):
            _fail("new-model NEXUS piece still visible: " + key)
            return
    if absf(float(nexus.get_meta("visual_model_scale", 0.0)) - 1.14) > 0.001:
        _fail("original NEXUS model scale changed")
        return
    if not bool(hub.call("_nexus_hit", cam.unproject_position(
            (hub.get_node("NEXUSBuilding") as Node3D).global_position +
            Vector3(0.0, 1.0, 0.0)))):
        _fail("original NEXUS tap no longer works")
        return
    var facilities: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    for key in STATIONS:
        var station: Node3D = facilities.get_node_or_null(key) as Node3D
        var model: Node3D = station.get_node_or_null("IndustrialModel") as Node3D
        if str(model.get_meta("base_design", "")) != "FRESH_20261122":
            _fail(key + " reference model was replaced inadvertently")
            return
        var found: bool = false
        for child in model.get_children():
            if not child is MultiMeshInstance3D:
                continue
            var group: MultiMeshInstance3D = child as MultiMeshInstance3D
            if group.multimesh == null:
                continue
            found = true
            for kind in ["bevel", "drum", "gear", "hopper", "canvas", "tube"]:
                if str(group.name).begins_with("Architectural_" + kind + "_"):
                    _fail(key + " retains rounded primitive " + str(group.name))
                    return
        if not found:
            _fail(key + " no real 3D meshes")
            return
        var tap: Vector2 = cam.unproject_position(station.global_position +
            Vector3(0.0, 1.0, 0.0))
        if str(facilities.call("key_at", cam, tap)) != key:
            _fail(key + " tap target moved")
            return
    print("SERA_BASE_ANGULAR_ARCHIVE_NEXUS_RUNTIME_PASS old NEXUS / seven angular facilities / unchanged taps")
    quit(0)
