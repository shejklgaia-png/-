extends SceneTree
## Actual 720x1280 BASE play view, NOT a newly positioned preview camera.
## Physical equipment cues are measured in SCREEN pixels below UI labels.
const HERO_CUES = {
    "LABO": {
        "point": Vector3(0.18, 1.95, 1.37), "half_width": 0.55,
        "min_width_px": 24.0, "feature": "LabFocalPrintBed",
    },
    "SCRAP_COLLECTOR": {
        "point": Vector3(0.46, 1.28, 1.03), "half_width": 0.55,
        "min_width_px": 28.0, "feature": "CollectorClawSignalCheek",
    },
    "GENERATOR": {
        "point": Vector3(-0.08, 1.18, 1.29), "half_width": 0.63,
        "min_width_px": 32.0, "feature": "GeneratorCoreCorona",
    },
    "STORAGE": {
        "point": Vector3(0.14, 1.35, 0.43), "half_width": 0.69,
        "min_width_px": 32.0, "feature": "StorageVisibleCargoCase",
    },
}

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_BASE_GAMEPLAY_ANGLE_FAIL: " + why)
    quit(1)

func _to_world(building: Node3D, model: Node3D, local: Vector3) -> Vector3:
    var yaw: float = float(model.get_meta("body_yaw", 0.0))
    var factor: float = float(model.get_meta("visual_model_scale", 1.0))
    return building.global_position + Basis(Vector3.UP, yaw) * (local * factor)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    for _attempt in range(90):
        await process_frame
        if hub.get_node_or_null("BaseFacilities/BUILD_TERMINAL/IndustrialModel") != null and (
            hub.get_node_or_null("BaseStartupOverlay") == null):
            break
    var station: Node3D = hub.get_node_or_null("BaseFacilities") as Node3D
    var camera: Camera3D = hub.get("cam") as Camera3D
    if station == null or camera == null:
        _fail("live BASE scene failed to load")
        return
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL or (
        absf(camera.size - 38.0) > 0.005 or
        camera.position.distance_to(Vector3(21.0, 19.5, 25.0)) > 0.005):
        _fail("test must use current actual gameplay angle and unchanged size")
        return
    var expected_forward: Vector3 = (
        Vector3(0.0, 2.1, -2.2) - Vector3(21.0, 19.5, 25.0)).normalized()
    if (-camera.global_transform.basis.z).dot(expected_forward) < 0.999:
        _fail("gameplay camera bearing or elevation was modified")
        return
    if bool(hub.get("power_view_active")):
        _fail("GRID edit view is not the BASE gameplay view")
        return
    var view: Vector2 = camera.get_viewport().get_visible_rect().size
    var s: float = view.y / 1280.0
    var tags: Dictionary = station.get("facility_tags")
    for key in HERO_CUES.keys():
        var entry: Dictionary = HERO_CUES[key]
        var building: Node3D = station.get_node_or_null(key) as Node3D
        var model: Node3D = building.get_node_or_null("IndustrialModel") as Node3D
        if model == null:
            _fail("missing 3D facility: " + key)
            return
        var features: Array = model.get_meta("unique_model_features", [])
        if not features.has(entry["feature"]):
            _fail("real mesh has no front-visible focal feature: " + key)
            return
        var local: Vector3 = entry["point"]
        var world: Vector3 = _to_world(building, model, local)
        if camera.is_position_behind(world):
            _fail("hero feature is behind camera: " + key)
            return
        var middle: Vector2 = camera.unproject_position(world)
        var half: float = float(entry["half_width"])
        var left: Vector2 = camera.unproject_position(_to_world(
            building, model, local + Vector3(-half, 0, 0)))
        var right: Vector2 = camera.unproject_position(_to_world(
            building, model, local + Vector3(half, 0, 0)))
        if absf(right.x - left.x) < float(entry["min_width_px"]) * s:
            _fail(key + " hero is too small from the GAME camera")
            return
        if middle.x < 12.0 * s or middle.x > view.x - 12.0 * s or (
            middle.y < 115.0 * s or middle.y > view.y - 105.0 * s):
            _fail(key + " key equipment is outside usable gameplay viewport")
            return
        # The text label must not visually cover the machine's identity.
        var label: Label = tags.get(key) as Label
        if label != null and label.visible and (
            middle.y < label.get_global_rect().end.y + 6.0 * s):
            _fail(key + " visual hero is hidden behind the on-screen name label")
            return
        var tap: Vector2 = camera.unproject_position(
            building.global_position + Vector3(0, 1.0, 0))
        if str(station.call("key_at", camera, tap)) != key:
            _fail(key + " touch region changed during silhouette redesign")
            return
    # Cargo is BELOW the rear roof's screen projection, not occluded by it.
    var store: Node3D = station.get_node("STORAGE") as Node3D
    var store_model: Node3D = store.get_node("IndustrialModel") as Node3D
    var cover_edge: Vector2 = camera.unproject_position(_to_world(
        store, store_model, Vector3(0.0, 2.76, -0.47)))
    var exposed: Vector2 = camera.unproject_position(_to_world(
        store, store_model, Vector3(0.0, 1.35, 0.43)))
    if exposed.y <= cover_edge.y + 18.0 * s:
        _fail("cargo silhouette still sits behind the forward roof edge")
        return
    print("SERA_BASE_GAMEPLAY_ANGLE_PASS real orthographic play view / 4 identifiable machines / cargo opening")
    quit(0)
