extends SceneTree
## The visible, grounded shins define the front/rear boundary, including
## the lag between chassis yaw and planted feet during a turn.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V354_BITTARAN_LIVE_BOUNDARY_FAIL: " + message)
    quit(1)

func _front(id: String) -> bool:
    return id == "leg_fl" or id == "leg_fr"

func _assert_visible_boundary(battle: Node3D, label: String) -> bool:
    var parts: Node3D = battle.get("target_parts")
    # Expectations come independently from the actual lock-only Areas used
    # by the visible legs, not the selector's own saved calibration.
    var areas: Dictionary = parts.get("camera_areas")
    var front: Vector3 = (areas["leg_fl"].global_position
        + areas["leg_fr"].global_position) * 0.5
    var rear: Vector3 = (areas["leg_rl"].global_position
        + areas["leg_rr"].global_position) * 0.5
    var middle: Vector3 = (front + rear) * 0.5
    var axis: Vector3 = front - rear
    axis.y = 0.0
    axis = axis.normalized()
    var lateral: Vector3 = Vector3(-axis.z, 0.0, axis.x)
    for side in [-1.0, 1.0]:
        # Sample both sides of the actual halfway plane, then traverse the
        # same positions in reverse. Exercise main's real acquisition path.
        var samples: Array[float] = [-0.3, -0.05, 0.05, 0.3, 0.05, -0.05, -0.3]
        for offset in samples:
            var actor: Node3D = battle.get("player")
            actor.global_position = middle + lateral * side * 10.0 + axis * offset
            actor.global_position.y = 0.0
            battle.call("_acquire_stable_camera_part", 1.0 / 60.0, false)
            var selected: String = battle.get("locked_target_part_id")
            if _front(selected) != (offset > 0.0):
                _fail(label + " side=" + str(side) + " offset=" + str(offset)
                    + " selected=" + selected)
                return false
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    var target: Node3D = battle.get("target")
    var model: Node3D = battle.get("bittaran_rig")
    var parts: Node3D = battle.get("target_parts")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if not _assert_visible_boundary(battle, "standing"):
        return
    # Both yaw directions and walking with root translation. Real IK keeps
    # planted feet in world space while the chassis turns above them.
    for direction in [1.0, -1.0]:
        for frame in range(120):
            var dt: float = 1.0 / 60.0
            target.rotation.y += deg_to_rad(30.0) * dt * direction
            if frame > 60:
                target.position += target.basis.z * 0.72 * dt
            var motion: String = "Turn" if frame <= 60 else "Approach"
            model.call("set_motion", motion, dt)
            ik.call("advance_ik", dt, motion)
            parts.call("sync_bittaran_parts")
            if frame % 5 == 0:
                if not _assert_visible_boundary(battle,
                        "yaw=" + str(direction) + " frame=" + str(frame)):
                    return
    # Now exercise complete scene physics: animation resets the leg bones
    # each frame. AUTO must run after the contact solver restores the pose.
    battle.set("auto_lock_enabled", true)
    battle.set("manual_part_lock_active", false)
    var player: Node3D = battle.get("player")
    for frame in range(180):
        var angle: float = deg_to_rad(35.0 + float(frame) * 0.8)
        player.global_position = target.global_position + Vector3(
            sin(angle), 0.0, cos(angle)) * 12.0
        player.global_position.y = 0.0
        battle.call("_physics_process", 1.0 / 60.0)
        var areas: Dictionary = parts.get("camera_areas")
        var front: Vector3 = (areas["leg_fl"].global_position
            + areas["leg_fr"].global_position) * 0.5
        var rear: Vector3 = (areas["leg_rl"].global_position
            + areas["leg_rr"].global_position) * 0.5
        var delta: Vector3 = player.global_position - (front + rear) * 0.5
        delta.y = 0.0
        var axis: Vector3 = front - rear
        axis.y = 0.0
        var selected: String = battle.get("locked_target_part_id")
        if _front(selected) != (delta.dot(axis) >= 0.0):
            _fail("full physics sampled pre-IK pose at frame " + str(frame))
            return
    print("GODOT_V354_BITTARAN_LIVE_BOUNDARY_PASS: main acquisition, actual "
        + "shin Areas, both sides/directions, grounded turning and walking")
    quit(0)
