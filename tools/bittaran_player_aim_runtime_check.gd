extends SceneTree
## Live battle verification of bounded BODY+SHOULDER player aiming.
## Force each authored STOMP/SWEEP/KICK, then abruptly move SERA
## after the downswing starts to verify the aim is truly frozen.
const DT: float = 1.0 / 60.0
const CASES: Array[Array] = [
    ["leg_fl", "stomp"], ["leg_fr", "stomp"],
    ["leg_rl", "stomp"], ["leg_rr", "stomp"],
    ["leg_fl", "sweep"], ["leg_fr", "sweep"],
    ["leg_rl", "sweep"], ["leg_rr", "sweep"],
    ["leg_fl", "kick"], ["leg_fr", "kick"]
]

func _initialize() -> void:
    call_deferred("_run")


func _fail(msg: String) -> void:
    push_error("BITTARAN_PLAYER_AIM_FAIL " + msg)
    quit(1)


func _run() -> void:
    # One arena instance for all techniques. Reset its real boss state
    # between cases; don't allocate ten entire battle/audio/FX scenes.
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    for item in CASES:
        battle.call("_reset_target_after_respawn")
        battle.set("player_hp", 100000.0)
        var id: String = str(item[0])
        var kind: String = str(item[1])
        var player: CharacterBody3D = battle.get("player")
        var boss: Node3D = battle.get("target")
        var rig: Node3D = battle.get("bittaran_rig")
        var director: RefCounted = battle.get("bittaran_attacks")
        var ik: Node3D = battle.get("bittaran_foot_ik")
        if player == null or boss == null or rig == null \
                or director == null or ik == null:
            _fail("missing scene nodes " + str(item))
            return
        var side: float = -1.0 if id.ends_with("r") else 1.0
        var z: float = -3.0 if id.begins_with("leg_r") else 3.0
        player.global_position = boss.global_position + Vector3(
            side * 2.3, 0.0, z)
        if not bool(director.call("force_start", id, kind)):
            _fail("force_start denied " + str(item))
            return
        var saw_track: bool = false
        var saw_lock: bool = false
        var saw_frozen: bool = false
        var saw_ik: bool = false
        var max_body_offset: float = 0.0
        var locked_body: float = 0.0
        var locked_shoulder: float = 0.0
        var locked_offset: Vector3 = Vector3.ZERO
        var locked_stomp_ik: Vector3 = Vector3.ZERO
        var moved_player: bool = false
        var lock_frame: int = -1
        for tick in range(270):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            battle.call("_finalize_target_pose", DT)
            var phase: String = str(frame.get("phase", ""))
            var source_t: float = float(frame.get("authored_time", 0.0))
            var body_yaw: float = float(rig.get("source_aim_body_yaw"))
            var shoulder_yaw: float = float(
                rig.get("source_aim_shoulder_yaw"))
            var body_offset: Vector3 = rig.get("source_aim_body_offset")
            max_body_offset = maxf(max_body_offset,
                body_offset.length())
            if absf(body_yaw) > deg_to_rad(30.01) \
                    or absf(shoulder_yaw) > deg_to_rad(30.01) \
                    or body_offset.length() > 1.001 \
                    or absf(body_offset.y) > 0.0001:
                _fail("body/shoulder limits exceeded " +
                    str([item, body_yaw, shoulder_yaw, body_offset]))
                return
            if phase == "strike" and source_t > 0.10:
                if absf(body_yaw) > 0.003 \
                        or absf(shoulder_yaw) > 0.003 \
                        or body_offset.length() > 0.01:
                    saw_track = true
                if kind == "stomp" and (
                        (ik.get("source_ik_stomp_target_offset")
                            as Vector3).length() > 0.03):
                    saw_ik = true
            var unlocked: bool = false
            if kind == "stomp":
                unlocked = bool(rig.get(
                    "source_aim_stomp_descent_started"))
            elif kind == "sweep":
                unlocked = phase == "strike" and source_t >= (
                    0.25 if id.begins_with("leg_r") else 0.75)
            elif kind == "kick":
                unlocked = phase == "strike" and source_t >= 0.25
            if unlocked and not saw_lock:
                saw_lock = true
                lock_frame = tick
                locked_body = body_yaw
                locked_shoulder = shoulder_yaw
                locked_offset = body_offset
                locked_stomp_ik = ik.get(
                    "source_ik_stomp_target_offset")
                # SERA crosses directly through the other half-plane.
                player.global_position = boss.global_position + Vector3(
                    -side * 6.5, 0.0, -z * 1.5)
                moved_player = true
            elif saw_lock and tick > lock_frame and (
                    phase == "strike" or phase == "hold"):
                if absf(body_yaw - locked_body) > 0.0001 \
                        or absf(shoulder_yaw - locked_shoulder) > 0.0001 \
                        or body_offset.distance_to(
                            locked_offset) > 0.0001:
                    _fail("aim changed after strike started " +
                        str([item, tick, body_yaw, shoulder_yaw]))
                    return
                if kind == "stomp" and (
                        (ik.get("source_ik_stomp_target_offset")
                            as Vector3).distance_to(locked_stomp_ik)
                                > 0.0001):
                    _fail("stomp IK chased after release " + id)
                    return
                saw_frozen = true
                # Only a few post-release frames are needed to prove
                # the director froze all steering axes. Avoid a long
                # full-body physics replay for each of the ten cases.
                if tick - lock_frame >= 6:
                    break
        var future: Vector3 = rig.get("source_aim_future_hip_local")
        if not saw_track or not saw_lock or not saw_frozen \
                or not moved_player or max_body_offset > 1.001 \
                or (kind == "stomp" and not saw_ik) \
                or (kind == "sweep" and future.length() < 0.1):
            _fail("incomplete tracked attack " +
                str([item, saw_track, saw_lock, saw_frozen,
                    saw_ik, future, max_body_offset]))
            return
        print("BITTARAN_PLAYER_AIM_CASE ", item,
            " max_body_shift=", max_body_offset,
            " frozen_tick=", lock_frame,
            " stomp_ik=", saw_ik)
    battle.free()
    print("BITTARAN_PLAYER_AIM_PASS all_10_attacks=true ",
        " body_shift_le_1m=true body_yaw_30deg=true ",
        " shoulder_yaw_30deg=true stomp_ik_frozen=true ",
        " sweep_midpoint_aim=true")
    quit(0)
