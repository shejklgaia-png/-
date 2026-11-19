extends SceneTree
## Regression: only the untracked railgun follows the authored Body attitude.
## Tracking and its capped world-space slew must not inherit new chassis turns.
const GUN = preload("res://scripts/bittaran_railgun.gd")
const DT: float = 1.0 / 60.0


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_IDLE_BODY_POSE_FAIL: " + message)
    quit(1)


func _pose_gap(a: Basis, b: Basis) -> float:
    return a.orthonormalized().get_rotation_quaternion().angle_to(
        b.orthonormalized().get_rotation_quaternion())


func _world_yaw(node: Node3D) -> float:
    var forward: Vector3 = -node.global_basis.z.normalized()
    return atan2(-forward.x, -forward.z)


func _run() -> void:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var gun: Node3D = scene.get("bittaran_railgun")
    if rig == null or gun == null or gun.get_script() != GUN:
        _fail("live railgun and authored rig must load")
        return
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    if body == null:
        _fail("Body bone not found")
        return
    var target: Vector3 = gun.global_position + Vector3(13.0, 2.0, -9.0)

    # WAIT: follow the complete animated Body basis, not just the root yaw.
    body.quaternion = (
        Quaternion(Vector3.RIGHT, deg_to_rad(14.0))
        * Quaternion(Vector3.FORWARD, deg_to_rad(-19.0))
        * body.quaternion).normalized()
    rig.rotation.y += 0.35
    gun.call("reset")
    if _pose_gap(gun.global_basis, body.global_basis) > 0.0005:
        _fail("idle cannon must match Body pitch, roll and heading")
        return
    rig.rotation.y += 0.18
    gun.call("advance", 0.1, target, true)
    if _pose_gap(gun.global_basis, body.global_basis) > 0.0005:
        _fail("waiting cannon did not follow a moving chassis"
            + " pose_gap=" + str(_pose_gap(gun.global_basis, body.global_basis))
            + " idle_blend=" + str(gun.get("idle_pose_blend"))
            + " tracked=" + str(gun.get("tracking_world_initialized"))
            + " gun_basis=" + str(gun.global_basis)
            + " body_basis=" + str(body.global_basis))
        return
    if gun.global_position.distance_to(
            body.to_global(GUN.MOUNT_LOCAL_OFFSET)) > 0.0005:
        _fail("cannon pivot stopped following animated Body position")
        return

    # Entering the 10-second sphere phase must not snap tilted barrels.
    gun.set("elapsed", GUN.FLASH_START - 0.01)
    var idle_pose: Basis = gun.global_basis
    gun.call("advance", 0.01, target, true)
    if _pose_gap(idle_pose, gun.global_basis) > deg_to_rad(2.0):
        _fail("idle-to-tracking pose snapped at sphere appearance")
        return
    gun.call("advance", GUN.TRACK_BLEND_SECONDS + 0.01, target, true)
    if gun.global_basis.y.normalized().distance_to(Vector3.UP) > 0.0005:
        _fail("targeting turret did not stabilize its roll and pitch")
        return
    var stable_heading: float = _world_yaw(gun)
    rig.rotation.y += 0.7
    if absf(angle_difference(stable_heading, _world_yaw(gun))) > 0.0005:
        _fail("tracked turret inherited chassis yaw before its own update")
        return

    # The live beam must retain its own 0.7x rate even as Body turns.
    gun.set("elapsed", GUN.BEAM_START + 0.2)
    gun.call("advance", DT, target, true)
    var before: float = _world_yaw(gun)
    rig.rotation.y += 0.35
    gun.call("advance", DT, target, true)
    var after: float = _world_yaw(gun)
    var rate: float = float(gun.get("beam_turn_rate_deg_per_sec"))
    if absf(rad_to_deg(angle_difference(before, after))) > rate * DT + 0.08:
        _fail("chassis rotation was added to capped laser guidance")
        return
    if gun.global_basis.y.normalized().distance_to(Vector3.UP) > 0.0005:
        _fail("beam phase inherited Body roll")
        return

    # The RETURN is world-locked; subsequent WAIT rejoins current Body pose
    # gradually rather than snapping to its nonzero animated lean.
    gun.set("elapsed", GUN.BEAM_END - 0.01)
    gun.call("advance", 0.01, target, true)
    gun.call("advance", GUN.RETURN_SECONDS - 0.02, target, true)
    var before_wait: Basis = gun.global_basis
    gun.call("advance", 0.04, target, true)
    if _pose_gap(before_wait, gun.global_basis) > deg_to_rad(15.0):
        _fail("return-to-WAIT abruptly snapped to Body attitude")
        return
    for i in range(100):
        gun.call("advance", DT, target, true)
    if _pose_gap(gun.global_basis, body.global_basis) > deg_to_rad(0.2):
        _fail("untracked WAIT cannon never fully rejoined Body posture")
        return
    print("GODOT_BITTARAN_IDLE_BODY_POSE_PASS ",
        "idle_full_pose=true entry_smooth=true guidance_world_isolated=true ",
        "wait_rejoin_smooth=true")
    quit(0)
