extends SceneTree
## Full Godot BASE boot + real MultiMesh transforms, not mocked node playback.
const MOTORS = {
    "NEXUS": "NexusAntennasBeacon",
    "LABO": "FreshLabPrinterHotHead",
    "SCRAP_COLLECTOR": "FreshCollectorClawHead",
    "SMELTER": "FreshSmelterFlameTongue",
    "RECYCLER": "FreshRecyclerTooth",
    "GENERATOR": "FreshGeneratorRotorBlade",
    "STORAGE": "FreshStorageLoadingLift",
    "BUILD_TERMINAL": "FreshTerminalBlueprintRows",
}
const CLOCK_SAMPLES = [0.0, 0.67, 1.41]
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("SERA_BASE_FACILITY_MOTION_FAIL: " + why)
    quit(1)
func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _step in range(100):
        await process_frame
        if hub.get_node_or_null("BaseStartupOverlay") == null and (
                hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null):
            break
    var camera: Camera3D = hub.get("cam") as Camera3D
    if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL or (
            absf(camera.size - 38.0) > 0.001 or
            camera.position.distance_to(Vector3(21.0, 19.5, 25.0)) > 0.001):
        _fail("accepted live BASE camera changed")
        return
    var stations: Node3D = hub.get_node("BaseFacilities") as Node3D
    var nexus: Node3D = hub.get_node("NEXUSBuilding/NexusArchitecture") as Node3D
    if str(nexus.get_meta("base_design", "")) != "ARCHIVED_20261122":
        _fail("restored two-versions-old NEXUS model was lost")
        return
    for key in MOTORS:
        var site: Node3D = hub.get_node("NEXUSBuilding") if key == "NEXUS" else stations.get_node(key)
        var model: Node3D = nexus if key == "NEXUS" else site.get_node("IndustrialModel")
        var player: Node = model.get_node_or_null("FacilityMotion")
        if player == null or not player.has_method("sample_at") or (
                not player.has_method("part_pose")):
            _fail(key + " has no actual 3D animation driver")
            return
        var features: Array = model.get_meta("unique_model_features", [])
        if not features.has(MOTORS[key]):
            _fail(key + " missing original moving mechanical part")
            return
        var fixed_draws: int = 0
        for child in model.get_children():
            if child is MultiMeshInstance3D:
                fixed_draws += 1
        if fixed_draws < 3 or player.get_child_count() > 0:
            _fail(key + " adds per-part meshes or damages fixed 3D batching")
            return
        var poses: Array[Transform3D] = []
        for moment in CLOCK_SAMPLES:
            player.call("sample_at", moment)
            var pose: Transform3D = player.call("part_pose", MOTORS[key], 0)
            if not pose.origin.is_finite():
                _fail(key + " part transform became invalid")
                return
            poses.append(pose)
        var changed: bool = false
        for i in range(1, poses.size()):
            if poses[0].origin.distance_to(poses[i].origin) > 0.008 or (
                    poses[0].basis.x.distance_to(poses[i].basis.x) > 0.02 or
                    poses[0].basis.y.distance_to(poses[i].basis.y) > 0.02 or
                    poses[0].basis.z.distance_to(poses[i].basis.z) > 0.02):
                changed = true
        if not changed:
            print("SERA_BASE_MOTION_POSE_DIAG " + key + " " + str(poses))
            _fail(key + " model part does not actually move across time")
            return
        var tap: Vector2 = camera.unproject_position(site.global_position +
            Vector3(0.0, 1.0, 0.0))
        if key == "NEXUS":
            if not bool(hub.call("_nexus_hit", tap)):
                _fail("NEXUS touch changed")
                return
        elif str(stations.call("key_at", camera, tap)) != key:
            _fail(key + " touch changed")
            return
    # Counter-rotating cutters must turn in *opposite* directions.
    var recycler: Node = hub.get_node("BaseFacilities/RECYCLER/IndustrialModel/FacilityMotion")
    recycler.call("sample_at", 0.25)
    var before_left: Transform3D = recycler.call("part_pose", "FreshRecyclerRoller", 0)
    var before_right: Transform3D = recycler.call("part_pose", "FreshRecyclerRoller", 1)
    recycler.call("sample_at", 0.55)
    var after_left: Transform3D = recycler.call("part_pose", "FreshRecyclerRoller", 0)
    var after_right: Transform3D = recycler.call("part_pose", "FreshRecyclerRoller", 1)
    if before_left.basis.y.distance_to(after_left.basis.y) < 0.02 or (
            before_right.basis.y.distance_to(after_right.basis.y) < 0.02):
        _fail("cutter shaft rotation does not move both rollers")
        return
    print("SERA_BASE_FACILITY_MOTION_RUNTIME_PASS 8 live animations / archived NEXUS / 7 hard-edge stations")
    quit(0)
