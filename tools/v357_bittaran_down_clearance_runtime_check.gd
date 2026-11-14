extends SceneTree
## v357: far-side player-center flick, downed torso evacuation, lateral
## foot-side clearance, aimed head that cannot intersect a visual leg, and
## no negative-Y SERA capsule during a collapsing boss's physics ticks.
const DT: float = 1.0 / 60.0
const CLEARANCE = preload("res://scripts/bittaran_down_clearance.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V357_BITTARAN_FAIL: " + message)
    quit(1)

func _head_clear(parts: Node3D, resting: Dictionary) -> bool:
    var tip: AABB = (parts.call("get_head_swing_aabb") as AABB).grow(0.05)
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        var leg: AABB = parts.call("get_leg_visual_aabb", id)
        var current: float = 0.0
        if leg.has_volume() and tip.intersects(leg):
            current = tip.intersection(leg).get_volume()
        if current > float(resting.get(id, 0.0)) + 0.03501:
            return false
    return true

func _run() -> void:
    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_physics_process(false)
    battle.set_process(false)
    battle.set("target_move_enabled", false)
    var target: Node3D = battle.get("target")
    var parts: Node3D = battle.get("target_parts")
    var player: CharacterBody3D = battle.get("player")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var view: Camera3D = battle.get("camera")
    var head: Node3D = battle.get("bittaran_head")
    if parts == null or player == null or head == null or rig == null:
        _fail("boss pose/parts/player missing")
        return

    battle.set("locked_target_part_id", "leg_fr")
    var aim: Vector3 = parts.call("get_part_aim_world", "leg_fr")
    var cam_forward: Vector3 = -view.global_transform.basis.z
    cam_forward.y = 0.0
    cam_forward = cam_forward.normalized()
    player.global_position = Vector3(aim.x, 0.0, aim.z) + cam_forward * 3.5
    var touch: Vector2 = Vector2(60.0, 990.0)
    var forward: Vector2 = battle.call("_touch_to_lock_forward", touch)
    var center: Vector3 = player.global_position + Vector3.UP * 0.925
    var expected: Vector2 = (view.unproject_position(aim)
        - view.unproject_position(center)).normalized()
    if not bool(battle.get("boss_far_side_screen_axis"))             or forward.distance_to(expected) > 0.001:
        _fail("far-side flick not along player capsule center -> lock target")
        return
    # The far-side axis must be player-based, not thumb-position dependent.
    var from_other_touch: Vector2 = battle.call(
        "_touch_to_lock_forward", Vector2(600.0, 470.0))
    if from_other_touch.distance_to(forward) > 0.001:
        _fail("far-side controller still uses finger origin instead of player")
        return

    # Turn the independently pivoted head after the usual clip and IK.
    var look_front: Vector3 = target.global_position + target.global_basis.z * 10.0
    player.global_position = look_front + target.global_basis.x * 4.0
    for n in range(16):
        rig.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        battle.call("_aim_bittaran_head", DT)
        if not _head_clear(parts, battle.get("head_neutral_overlap")):
            _fail("head swing worsened contact beyond authored leg clearance "
                + str(n) + " yaw=" + str(battle.get("boss_head_yaw")))
            return
    var left_yaw: float = float(battle.get("boss_head_yaw"))
    if absf(left_yaw) <= deg_to_rad(1.0)             or absf(left_yaw) > deg_to_rad(48.01):
        _fail("head did not follow player or exceeded articulation cap: "
            + str(rad_to_deg(left_yaw)))
        return
    player.global_position = look_front - target.global_basis.x * 4.0
    for n in range(35):
        rig.call("set_motion", "Idle", DT)
        ik.call("advance_ik", DT, "Idle")
        battle.call("_aim_bittaran_head", DT)
        if not _head_clear(parts, battle.get("head_neutral_overlap")):
            _fail("head crossed into a foot during reciprocal tracking")
            return
    if float(battle.get("boss_head_yaw")) * left_yaw >= 0.0:
        _fail("head failed to turn toward the opposite player side")
        return

    # Pure route regression: intersecting a shin blocks forward passage,
    # and starting against it forces a horizontal step out its SIDE.
    var body_box := AABB(Vector3(-1.5, 0.0, -1.5), Vector3(3.0, 2.0, 3.0))
    var foot_box := AABB(Vector3(0.9, 0.0, -0.7), Vector3(0.8, 2.0, 1.4))
    var feet: Array[AABB] = [foot_box]
    var around: Dictionary = CLEARANCE.escape_waypoint(
        Vector3(0.0, 0.0, 0.0), body_box, feet, 0.4, Vector3.RIGHT)
    var advanced: Vector3 = CLEARANCE.safe_advance(
        Vector3.ZERO, around["waypoint"], feet, 0.4)
    if not bool(around["active"]) or advanced.distance_to(Vector3.ZERO) < 0.001:
        _fail("blocked body exit had no available horizontal escape")
        return
    var at_foot: Dictionary = CLEARANCE.escape_waypoint(
        Vector3(1.1, 0.0, 0.0), body_box, feet, 0.4, Vector3.RIGHT)
    if not bool(at_foot["foot_detour"]):
        _fail("touching foot did not select lateral detour")
        return
    var beside: Vector3 = at_foot["waypoint"]
    if (beside - Vector3(1.1, 0.0, 0.0)).length_squared() < 0.01:
        _fail("foot contact tried to push vertically or remain embedded")
        return

    # Full scene physics while the chassis falls onto a capsule positioned
    # underneath it: move horizontally out, never below the visual floor.
    battle.set("locked_target_part_id", "leg_fl")
    var damage: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(damage.get("broken", false)):
        _fail("could not trigger actual boss down")
        return
    var body: AABB = parts.call("get_body_hit_aabb")
    player.global_position = Vector3(body.get_center().x, -0.12,
        body.get_center().z)
    var start: Vector3 = player.global_position
    var found_escape: bool = false
    for n in range(85):
        battle.call("_physics_process", DT)
        if player.global_position.y < -0.00001:
            _fail("downward collision recovery embedded player under floor at "
                + str(n) + " y=" + str(player.global_position.y))
            return
        # v358 replaces player-facing HEAD yaw with neutral rotation for
        # the full down; the falling chassis naturally moves the head near
        # its own shoulders. Do not apply the standing tracking overlap
        # baseline to this distinct authored down pose.
        if bool(ik.call("down_pose_active")):
            var neutral_head: Quaternion = battle.get(
                "boss_head_default_rotation")
            if head.quaternion.angle_to(neutral_head) > 0.003:
                _fail("downed head retained player-facing rotation")
                return
        elif not bool(ik.call("windup_active")) and not _head_clear(
                parts, battle.get("head_neutral_overlap")):
            _fail("standing head entered a leg while tracking")
            return
        if not bool(battle.get("boss_downed_escaping")):
            found_escape = true
            if n >= 5:
                break
    if not found_escape or player.global_position.distance_to(start) < 0.8:
        _fail("player remained beneath downed torso instead of being pushed out")
        return
    var current_feet: Array[AABB] = []
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        current_feet.append(parts.call("get_part_aabb", id))
    var route_after: Dictionary = CLEARANCE.escape_waypoint(
        player.global_position, parts.call("get_body_hit_aabb"),
        current_feet, 0.4, target.global_basis.z)
    if bool(route_after["active"]):
        _fail("player still overlaps body or foot after downed evacuation")
        return
    print("GODOT_V357_BITTARAN_PASS: player-center far-side sector, "
        + "leg-safe head yaw, downed horizontal body escape and floor Y>=0")
    quit(0)
