extends SceneTree
## v384/v392: STOMP raises the originally animated sole ABOVE
## SERA's head, follow the moving head until swing, then hit the ground.
## Other two authored attacks are deliberately not modified.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V384_STOMP_OVERHEAD_FAIL: " + message)
    quit(1)

func _run_case(battle: Node3D, id: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var player: CharacterBody3D = battle.get("player")
    var index: int = IK.LEG_PART_IDS.find(id)
    var leg: Dictionary = ik.get("legs")[index]
    var standing: Vector3 = leg["anchor"]
    var head_height: float = BRAIN.STOMP_PLAYER_HEAD_HEIGHT_METERS
    if not bool(brain.call("force_start", id, "stomp")):
        _fail(id + ": unable to start stomp")
        return false
    var raised_y: float = -INF
    var previous_aim: Vector3 = Vector3.INF
    var aim_moved: bool = false
    var saw_track: bool = false
    var locked_aim: Vector3 = Vector3.INF
    var impact_count: int = 0
    var lifted_near_end: float = 0.0
    var early_lift: float = -INF
    var at_impact: float = INF
    var recovered: bool = false
    var start_supports: Dictionary = {}
    for tick in range(260):
        # Move laterally twice during the windup, then cross to the
        # opposite side once the strike has begun. STOMP must not chase.
        var lateral: float = 0.0
        if tick >= 15 and tick < 40:
            lateral = 0.40
        elif tick >= 40 and tick < 60:
            lateral = -0.35
        elif tick >= 60:
            lateral = 1.80
        if tick >= 76:
            # The swing has already frozen its target. Dodge out of the
            # shockwave so this tracking regression cannot trigger a
            # player KO/respawn in an earlier leg case and clear the IK
            # attack pose before the impact-contact assertion.
            lateral = 14.0
        player.global_position = Vector3(
            standing.x + lateral, 0.0, standing.z)
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            recovered = true
            break
        var t: float = float(frame.get("time", 0.0))
        var aim: Vector3 = frame.get("stomp_aim", Vector3.INF)
        if aim == Vector3.INF or absf(aim.y - head_height) > 0.001:
            _fail(id + ": not tracking SERA head height " + str(aim))
            return false
        if bool(frame.get("tracking", false)):
            saw_track = true
            if previous_aim != Vector3.INF and absf(
                    aim.x - previous_aim.x) > 0.01:
                aim_moved = true
            previous_aim = aim
        elif locked_aim == Vector3.INF:
            locked_aim = aim
        elif aim.distance_to(locked_aim) > 0.0001:
            _fail(id + ": STOMP re-aimed after swing began")
            return false
        battle.call("_finalize_target_pose", DT)
        var foot: Node3D = leg["foot"]
        var actual: Vector3 = foot.to_global(
            leg["sole_local"] as Vector3)
        # v400: the model's long toe runs along the foot joint's +/-X,
        # not -Y as this check originally assumed. Measure the toe
        # itself from the real mesh: the direction from the joint to
        # its mesh centre. At impact it must align with the ground
        # normal (point straight down).
        var up_axis: Vector3 = Vector3.ZERO
        for child in foot.get_children():
            if child is MeshInstance3D:
                var piece: MeshInstance3D = child as MeshInstance3D
                if piece.mesh != null:
                    up_axis = (piece.to_global(
                        piece.mesh.get_aabb().get_center())
                        - foot.global_position).normalized()
                    break
        if t > 0.32 and t < BRAIN.STOMP_WINDUP_SECONDS - 0.03:
            # The original authored foot angle must survive anticipation.
            var authored: Quaternion = rig.call(
                "_authored_rotation_for_leg", "stomp", id, 2, t)
            if foot.quaternion.angle_to(authored) > 0.03:
                _fail(id + ": stomp windup foot key was overridden")
                return false
        if t <= BRAIN.STOMP_WINDUP_SECONDS:
            raised_y = maxf(raised_y, actual.y)
            if t >= 0.40 and t <= 0.47:
                early_lift = actual.y
            if t >= 0.95:
                lifted_near_end = actual.y
        if start_supports.is_empty():
            for j in range(IK.LEG_PART_IDS.size()):
                if j != index:
                    var support: Dictionary = ik.get("legs")[j]
                    start_supports[IK.LEG_PART_IDS[j]] = support["anchor"]
        for support_id in start_supports:
            var support_index: int = IK.LEG_PART_IDS.find(support_id)
            var support: Dictionary = ik.get("legs")[support_index]
            var goal: Vector3 = support["last_goal"]
            var planted: Vector3 = start_supports[support_id]
            if Vector2(goal.x - planted.x,
                    goal.z - planted.z).length() > 0.0001:
                _fail(id + ": support foot slid during stomp " + support_id)
                return false
        if bool(frame.get("impact", false)):
            impact_count += 1
            # The visible short tip's bottom is the REAL impact point;
            # the old Wait-pose sole marker sits along its long side.
            var foot_box: AABB = ik.call("attack_foot_aabb")
            at_impact = foot_box.position.y
            if up_axis.dot(Vector3.DOWN) < 0.998:
                _fail(id + ": long edge tilted away from ground-normal at impact")
                return false
            var fx_center: Vector3 = ik.call("attack_contact_world")
            var expected: Vector3 = Vector3(foot_box.get_center().x,
                foot_box.position.y, foot_box.get_center().z)
            if fx_center.distance_to(expected) > 0.0002:
                _fail(id + ": impact FX point did not use real toe tip "
                    + str([fx_center, expected, ik.get("attack_pose")]))
                return false
    if not recovered or not saw_track or not aim_moved             or locked_aim == Vector3.INF:
        _fail(id + ": incomplete moving-head track / recovery")
        return false
    if lifted_near_end <= early_lift + 0.25:
        _fail(id + ": stopped lifting before final windup frame " +
            str([early_lift, lifted_near_end]))
        return false
    if raised_y < head_height + 0.10:
        _fail(id + ": foot never rose above SERA head " + str(raised_y))
        return false
    if impact_count != 1 or at_impact > 0.22:
        _fail(id + ": stomp did not hit ground exactly once " +
            str([impact_count, at_impact]))
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    if ik == null or rig == null or not bool(ik.get("ready"))             or not bool(rig.get("loading_ok")):
        _fail("live Bittaran rig unavailable")
        return
    for id in BRAIN.LEG_IDS:
        if not _run_case(battle, id):
            return
    print("GODOT_V384_STOMP_OVERHEAD_PASS: four STOMP legs preserve authored "
        + "toe angles while raising above SERA head, lock on "
        + "strike, impact only once using real sole; supports stay fixed")
    quit(0)
