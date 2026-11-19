extends SceneTree
## Regression: chassis rotation must not add/subtract turret world yaw.
## The original connector follows the chassis; the two barrels do not
## inherit its rotation between physics updates while tracking/returning.
const GUN = preload("res://scripts/bittaran_railgun.gd")
const DT: float = 1.0 / 60.0


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_WORLD_YAW_FAIL: " + message)
    quit(1)


func _world_yaw(node: Node3D) -> float:
    var forward: Vector3 = -node.global_basis.z.normalized()
    return atan2(-forward.x, -forward.z)


func _same_heading(a: float, b: float, tolerance: float = 0.0007) -> bool:
    return absf(angle_difference(a, b)) <= tolerance


func _run() -> void:
    var scene: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var gun: Node3D = scene.get("bittaran_railgun")
    if rig == null or gun == null:
        _fail("missing live Bittaran gun/rig")
        return
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    if body == null or gun.get_parent() != body or (
            not gun.is_set_as_top_level()):
        _fail("gun must stay logically under Body but rotate in world space")
        return

    # Initial Wait-pose floor alignment occurs after the gun's setup.
    # Its top-level transform must be re-synced BEFORE the first physics
    # frame, otherwise an early beam target or camera probe is displaced.
    if gun.global_position.distance_to(
            body.to_global(GUN.MOUNT_LOCAL_OFFSET)) > 0.0005:
        _fail("initial world mount was left at the pre-calibration position")
        return

    # Both the free charge acquisition and the speed-limited live laser
    # must remain world-locked at the instant the chassis rotates. Old
    # parent-relative mounting fails this check BEFORE advance() is called.
    var target: Vector3 = gun.global_position + Vector3(14.0, 0.0, -17.0)
    for start_time in [GUN.FLASH_START + 0.8, GUN.BEAM_START + 0.6]:
        gun.call("reset")
        gun.set("elapsed", start_time)
        gun.call("advance", DT, target, true)
        var before: float = _world_yaw(gun)
        rig.rotation.y += 0.65
        if not _same_heading(before, _world_yaw(gun)):
            _fail("chassis added yaw before the turret's independent update")
            return
        var before_tracked: float = float(gun.get("tracked_world_yaw"))
        gun.call("advance", DT, target, true)
        if start_time >= GUN.BEAM_START:
            var rate: float = float(gun.get(
                "beam_turn_rate_deg_per_sec"))
            var changed: float = absf(rad_to_deg(angle_difference(
                before_tracked, _world_yaw(gun))))
            if changed > rate * DT + 0.08:
                _fail("laser inherited chassis turn on top of its slew cap")
                return
        if gun.global_position.distance_to(
                body.to_global(GUN.MOUNT_LOCAL_OFFSET)) > 0.0005:
            _fail("world-level turret pivot did not follow the Body mount")
            return

    # Regression: on a real moving chassis the mount POSITION changes
    # before the aiming tick. If the target is directly along the current
    # world-space barrel ray from the NEW mount position, the barrel must
    # not turn at all. Using the PREVIOUS physics frame's mount produces a
    # phantom yaw correction that looks like added chassis angular speed.
    var saved_rig_yaw: float = rig.rotation.y
    var saved_body_pose: Quaternion = body.quaternion
    rig.rotation.y = 0.0
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START + 0.4)
    var initial_heading: float = float(gun.call("_neutral_world_yaw"))
    var initial_target: Vector3 = (
        gun.global_position + Basis(Quaternion(Vector3.UP,
        initial_heading)) * Vector3(0.0, 0.0, -12.0)
        - Vector3.UP * 0.92)
    gun.call("advance", DT, initial_target, true)
    var held_world_yaw: float = float(gun.get("tracked_world_yaw"))
    var rail_meshes: Dictionary = rig.get("mesh_nodes_by_uuid")
    var first_barrel: MeshInstance3D = rail_meshes.get(
        GUN.RAIL_MESH_UUIDS[0]) as MeshInstance3D
    if first_barrel == null:
        _fail("source barrel mesh missing for world-space regression")
        return
    var held_mesh_forward: Vector3 = (
        -first_barrel.global_basis.z.normalized())
    for turn in [0.65, -0.90, 1.15, -1.25, 0.35]:
        rig.rotation.y += turn
        # The animated Body moves the mount even if the player stays
        # directly along the held world heading from the current pivot.
        var actual_mount: Vector3 = body.to_global(GUN.MOUNT_LOCAL_OFFSET)
        var aligned_target: Vector3 = (
            actual_mount + Basis(Quaternion(Vector3.UP,
            held_world_yaw)) * Vector3(0.0, 0.0, -12.0)
            - Vector3.UP * 0.92)
        gun.call("advance", DT, aligned_target, true)
        if gun.global_position.distance_to(actual_mount) > 0.0005:
            _fail("chassis rotation did not update the live turret mount")
            return
        if not _same_heading(
                float(gun.get("tracked_world_yaw")), held_world_yaw, 0.0002):
            _fail("stale mount position added a phantom tracking yaw")
            return
        if not _same_heading(_world_yaw(gun), held_world_yaw, 0.0002):
            _fail("rendered turret yaw inherited the chassis rotation")
            return
        var barrel_forward: Vector3 = (
            -first_barrel.global_basis.z.normalized())
        if barrel_forward.distance_to(held_mesh_forward) > 0.0005:
            _fail("actual barrel mesh followed chassis yaw during BEAM")
            return
    # Authored BODY bone rotations must also not inject a tracking delta.
    for turn in [0.8, -1.4, 0.6]:
        body.rotation.y += turn
        var current_mount: Vector3 = body.to_global(GUN.MOUNT_LOCAL_OFFSET)
        var aligned_target: Vector3 = (
            current_mount + Basis(Quaternion(Vector3.UP,
            held_world_yaw)) * Vector3(0.0, 0.0, -12.0)
            - Vector3.UP * 0.92)
        gun.call("advance", DT, aligned_target, true)
        if not _same_heading(
                float(gun.get("tracked_world_yaw")), held_world_yaw, 0.0002):
            _fail("animated BODY pivot movement altered world aim")
            return
        if not _same_heading(_world_yaw(gun), held_world_yaw, 0.0002):
            _fail("animated BODY turn added to the visible barrel rotation")
            return
    body.quaternion = saved_body_pose
    rig.rotation.y = saved_rig_yaw
    gun.call("reset")

    # The post-beam return must use a frozen world-space start/neutral
    # heading: blending a relative yaw to 0 adds the chassis turn rate.
    gun.call("reset")
    gun.set("elapsed", GUN.BEAM_START + 0.6)
    gun.call("advance", DT, target, true)
    gun.set("elapsed", GUN.BEAM_END - DT * 0.5)
    gun.call("advance", DT, target, true)
    var from_yaw: float = float(gun.get("return_world_yaw_origin"))
    var home_yaw: float = float(gun.get("return_neutral_world_yaw"))
    gun.call("advance", 0.35, target, true)
    var halfway: float = _world_yaw(gun)
    if not _same_heading(halfway,
            lerp_angle(from_yaw, home_yaw, 0.5), 0.002):
        _fail("return midpoint must interpolate in WORLD yaw")
        return
    rig.rotation.y -= 0.9
    if not _same_heading(halfway, _world_yaw(gun)):
        _fail("return inherited an immediate chassis yaw change")
        return
    gun.call("advance", 0.1, target, true)
    var ratio: float = clampf((
        float(gun.get("elapsed")) - GUN.BEAM_END)
        / GUN.RETURN_SECONDS, 0.0, 1.0)
    var smooth: float = ratio * ratio * (3.0 - 2.0 * ratio)
    if not _same_heading(_world_yaw(gun),
            lerp_angle(from_yaw, home_yaw, smooth), 0.002):
        _fail("return speed summed with chassis rotation")
        return

    # WAIT is now allowed to inherit the animated Body's entire attitude.
    # Preserve the 180-deg/s cap for its WORLD-space motor, then verify
    # that posture rejoining uses a bounded blend instead of a snap.
    gun.call("advance", 0.20, target, true)
    var end_return_tracked: float = float(gun.get("tracked_world_yaw"))
    var pre_blend: float = float(gun.get("idle_pose_blend"))
    gun.call("advance", 0.07, target, true)
    var tracked_delta: float = absf(rad_to_deg(angle_difference(
        end_return_tracked, float(gun.get("tracked_world_yaw")))))
    if tracked_delta > GUN.PARK_REACQUIRE_DEG_PER_SECOND * 0.07 + 0.08:
        _fail("idle world motor exceeded its post-beam rejoin rate")
        return
    var blend: float = float(gun.get("idle_pose_blend"))
    if blend < pre_blend - 0.0001 or blend > (
            pre_blend + 0.07 / GUN.IDLE_POSE_REJOIN_SECONDS + 0.0001):
        _fail("idle Body pose blend advanced too quickly")
        return
    var base_yaw: float = (
        float(gun.get("tracked_world_yaw")) if bool(
            gun.get("tracking_world_initialized"))
        else float(gun.call("_neutral_world_yaw")))
    var leveled: Quaternion = Quaternion(Vector3.UP, base_yaw)
    var body_pose: Quaternion = (
        body.global_basis.orthonormalized().get_rotation_quaternion())
    var expected: Quaternion = leveled.slerp(body_pose, blend)
    var actual: Quaternion = (
        gun.global_basis.orthonormalized().get_rotation_quaternion())
    if actual.angle_to(expected) > 0.003:
        _fail("return-to-WAIT did not smoothly interpolate to current Body")
        return
    print("GODOT_BITTARAN_WORLD_YAW_PASS ",
        "tracking_isolated=true return_world_locked=true ",
        "mount_follows_body=true wait_body_rejoin_smooth=true")
    quit(0)
