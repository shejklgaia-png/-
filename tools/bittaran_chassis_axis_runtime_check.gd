extends SceneTree
## The authored upper railgun connector follows chassis yaw only.
## Barrel acquisition stays independently world-rate-limited.
const GUN = preload("res://scripts/bittaran_railgun.gd")
const DT: float = 1.0 / 60.0


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_CHASSIS_AXIS_FAIL: " + message)
    quit(1)


func _assert_chassis_heading(gun: Node3D, axis: Node3D,
        shaft: MeshInstance3D, body: Node3D) -> bool:
    var expected_yaw: float = float(gun.call("_neutral_world_yaw"))
    var horizontal_forward: Vector3 = -axis.global_basis.z.normalized()
    var actual_yaw: float = atan2(
        -horizontal_forward.x, -horizontal_forward.z)
    if absf(angle_difference(actual_yaw, expected_yaw)) > 0.0005:
        _fail("connector does not synchronise with the chassis' world yaw")
        return false
    if axis.global_basis.y.normalized().distance_to(Vector3.UP) > 0.0005:
        _fail("connector inherited animated Body pitch or roll")
        return false
    if shaft.global_basis.y.normalized().distance_to(Vector3.UP) > 0.0005:
        _fail("connector mesh tilted despite yaw-only pivot")
        return false
    if axis.global_position.distance_to(body.to_global(axis.position)) > 0.0005:
        _fail("connector lost its authored Body mount location")
        return false
    return true


func _run() -> void:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var gun: Node3D = scene.get("bittaran_railgun")
    if rig == null or gun == null or gun.get_script() != GUN:
        _fail("Bittaran railgun was not instantiated")
        return
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    var meshes: Dictionary = rig.get("mesh_nodes_by_uuid")
    var shaft: MeshInstance3D = meshes.get(GUN.CHASSIS_AXIS_MESH_UUID)
    var axis: Node3D = gun.get("chassis_axis")
    if body == null or shaft == null or axis == null or (
            axis.get_parent() != body) or (
            shaft.get_parent() != axis):
        _fail("original connector mesh is not bound to its yaw-only pivot")
        return
    if meshes.size() != 18 or (
            (rig.get("bones") as Dictionary).size() != 14):
        _fail("original Blockbench mesh or bone count changed")
        return
    if shaft.position.length() > 0.0005:
        _fail("connector mesh moved off its authored shaft pivot")
        return

    var initial_root_yaw: float = rig.rotation.y
    var initial_body_pose: Quaternion = body.quaternion
    # Chassis yaw must be identical even during authored Body pitch/roll.
    for angle in [0.0, 0.7, -1.2, PI * 0.75]:
        rig.rotation.y = initial_root_yaw + angle
        body.quaternion = (
            Quaternion(Vector3.RIGHT, deg_to_rad(17.0))
            * Quaternion(Vector3.FORWARD, deg_to_rad(-13.0))
            * initial_body_pose).normalized()
        gun.call("advance", DT, Vector3(12.0, 0.0, -8.0), true)
        if not _assert_chassis_heading(gun, axis, shaft, body):
            return

    # Railgun target acquisition is deliberately independent. Its yaw
    # must not rotate either the shaft or the chassis connector pivot.
    body.quaternion = initial_body_pose
    rig.rotation.y = initial_root_yaw + 0.3
    gun.call("reset")
    gun.set("elapsed", GUN.TRACK_START_SECONDS + 0.72)
    var target: Vector3 = gun.global_position + Vector3(12.0, 0.0, -7.0)
    gun.call("advance", 0.12, target, true)
    if absf(float(gun.get("aim_yaw"))) < deg_to_rad(3.0):
        _fail("independent railgun azimuth was lost")
        return
    if not _assert_chassis_heading(gun, axis, shaft, body):
        return
    rig.rotation.y = initial_root_yaw
    body.quaternion = initial_body_pose
    gun.call("reset")
    if not _assert_chassis_heading(gun, axis, shaft, body):
        return
    print("GODOT_BITTARAN_CHASSIS_AXIS_PASS yaw_synced=true ",
        "pitch_roll_isolated=true railgun_aim_independent=true")
    quit(0)
