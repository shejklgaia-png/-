extends SceneTree
## Test the actual rendered front (+Z), non-outward heading and modest ring radius.
const Arch = preload("res://scripts/sera_base_architecture.gd")
const Center = Vector2(0.0, -2.2)
const KEYS = ["NEXUS", "LABO", "SMELTER", "RECYCLER",
    "STORAGE", "GENERATOR", "SCRAP_COLLECTOR", "BUILD_TERMINAL"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(detail: String) -> void:
    push_error("SERA_BASE_INWARD_FACILITIES_FAIL: " + detail)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var facilities: Node3D = hub.get_node("BaseFacilities") as Node3D
    var nexus: Node3D = hub.get_node("NEXUSBuilding") as Node3D
    var camera: Camera3D = hub.get("cam") as Camera3D
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("camera was changed")
        return
    var angles: Dictionary = {}
    var directions: Dictionary = {}
    for key in KEYS:
        var node: Node3D = nexus if key == "NEXUS" else (
            facilities.get_node(key) as Node3D)
        var yaw: float = Arch.facility_yaw_radians(key)
        var front: Vector3 = Basis(Vector3.UP, yaw) * Vector3.BACK
        var projected_front := Vector2(front.x, front.z).normalized()
        var toward_center: Vector2 = (Center - Vector2(
            node.global_position.x, node.global_position.z)).normalized()
        var dot: float = projected_front.dot(toward_center)
        if dot < 0.91:
            _fail(key + " is facing away from the base interior (" + str(dot) + ")")
            return
        var slant: float = rad_to_deg(acos(clampf(dot, -1.0, 1.0)))
        if slant < 6.0 or slant > 24.0:
            _fail(key + " must be inward but have its own angled facade")
            return
        angles[roundi(rad_to_deg(yaw))] = true
        directions[key] = projected_front
        var foundation: MeshInstance3D = node.get_node("Foundation") as MeshInstance3D
        if absf(foundation.rotation.y - yaw) > 0.00001:
            _fail(key + " actual foundation is not turned inward")
            return
        var visual: Node3D = node.get_node(
            "NexusArchitecture" if key == "NEXUS" else "IndustrialModel") as Node3D
        if absf(float(visual.get_meta("body_yaw", -99.0)) - yaw) > 0.00001:
            _fail(key + " rendered batched geometry did not turn with its front")
            return
        var pixel: Vector2 = camera.unproject_position(
            node.global_position + Vector3(0.0, 1.0, 0.0))
        if key == "NEXUS":
            if not bool(hub.call("_nexus_hit", pixel)):
                _fail("NEXUS hit-area no longer follows the body yaw")
                return
        elif str(facilities.call("key_at", camera, pixel)) != key:
            _fail(key + " lost its 3D touch area")
            return
    if angles.size() != 8:
        _fail("facilities were rotated to repeated parallel headings")
        return
    print("SERA_BASE_INWARD_FACILITIES_PASS: eight distinct inward-facing facades")
    quit(0)
