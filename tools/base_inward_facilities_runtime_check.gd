extends SceneTree
## Verify every local +Z entrance is visible from camera, tilted toward screen center.
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
    var camera_heading: Vector3 = camera.global_transform.basis.z
    var view_direction := Vector3(camera_heading.x, 0.0, camera_heading.z).normalized()
    var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
    for key in KEYS:
        var node: Node3D = nexus if key == "NEXUS" else (
            facilities.get_node(key) as Node3D)
        var yaw: float = Arch.facility_yaw_radians(key)
        var front: Vector3 = Basis(Vector3.UP, yaw) * Vector3.BACK
        var facing: float = front.dot(view_direction)
        if facing < 0.897:
            _fail(key + " entrance faces away from camera: " + str(facing))
            return
        var base_point: Vector3 = node.global_position + Vector3(0.0, 1.30, 0.0)
        var center_uv: Vector2 = camera.unproject_position(base_point) / viewport
        var entrance_uv: Vector2 = camera.unproject_position(
            base_point + front * 1.30) / viewport
        if entrance_uv.x < 0.045 or entrance_uv.x > 0.955 or (
                entrance_uv.y < 0.09 or entrance_uv.y > 0.89):
            _fail(key + " entrance is clipped from the portrait display")
            return
        var horizontal_shift: float = entrance_uv.x - center_uv.x
        if center_uv.x < 0.42 and horizontal_shift < 0.012:
            _fail(key + " left facade does not lean toward screen center")
            return
        elif center_uv.x > 0.60 and horizontal_shift > -0.012:
            _fail(key + " right facade does not lean toward screen center")
            return
        elif center_uv.x >= 0.42 and center_uv.x <= 0.60 and (
                absf(horizontal_shift) > 0.012):
            _fail(key + " center facade is too oblique to see entrance")
            return
        angles[roundi(rad_to_deg(yaw))] = true
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
    print("SERA_BASE_INWARD_FACILITIES_PASS: eight visible, camera-facing entrances leaned toward screen center")
    quit(0)
