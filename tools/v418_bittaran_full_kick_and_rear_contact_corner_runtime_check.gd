extends SceneTree
## v418: all KICKs use full authored reach regardless of player's
## distance; rear KICK / SWEEP / STOMP invert floor contact to
## rear BODY socket height, keeping front edge/root Y stable.
const DT: float = 1.0 / 60.0
const REAR_IDS: Array[String] = ["leg_rl", "leg_rr"]
const KINDS: Array[String] = ["kick", "sweep", "stomp"]
const MAX_ROOT_HEIGHT_DELTA: float = 0.002
const MAX_FRONT_SOCKET_DELTA: float = 0.04
const MIN_CORNER_CORRECTION: float = deg_to_rad(0.20)


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V418_REAR_CORNER_DISTANCE_FAIL: " + message)
    quit(1)


func _tick(battle: Node3D) -> void:
    battle.set("player_hp", 9999.0)
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    if rig == null or ik == null or brain == null or boss == null             or player == null:
        _fail("missing live model/attack/IK")
        return
    var completed: int = 0
    var corner_report: Array[String] = []
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        for distance in [2.5, 7.8]:
            battle.call("_reset_target_after_respawn")
            battle.set("target_move_enabled", true)
            var side: float = -1.0 if id.ends_with("l") else 1.0
            var rear: bool = id.begins_with("leg_r")
            player.global_position = boss.global_position                 + Vector3(distance * side * 0.30, 0.0,
                    distance * (1.0 if rear else -1.0))
            if not bool(brain.call(
                    "force_start_with_stance", id, "kick")):
                _fail("cannot start " + id)
                return
            var root_y: float = rig.position.y
            var checked: int = 0
            var started: bool = false
            var finished: bool = false
            for tick in range(570):
                _tick(battle)
                var frame: Dictionary = battle.get(
                    "bittaran_attack_frame")
                if frame.is_empty():
                    if started and not bool(
                            brain.call("is_active")):
                        finished = true
                        break
                    continue
                if str(frame.get("phase", "")) == "stance":
                    continue
                started = true
                if absf(float(rig.get("kick_reach_factor")) - 1.0)                         > 0.00001:
                    _fail(id + " distance=" + str(distance)
                        + " illegally shortened authored KICK to "
                        + str(rig.get("kick_reach_factor")))
                    return
                if rear and absf(rig.position.y - root_y) > MAX_ROOT_HEIGHT_DELTA:
                    _fail(id + " rear KICK changed the root height")
                    return
                checked += 1
            if not finished or checked < 60:
                _fail(id + " KICK missing complete timeline")
                return
            completed += 1

    for id in REAR_IDS:
        for kind in KINDS:
            battle.call("_reset_target_after_respawn")
            battle.set("target_move_enabled", true)
            var side: float = -1.0 if id.ends_with("l") else 1.0
            player.global_position = boss.global_position + Vector3(
                3.7 * side, 0.0, 6.0)
            if not bool(brain.call(
                    "force_start_with_stance", id, kind)):
                _fail(id + "/" + kind + " could not start")
                return
            var start_root_y: float = rig.position.y
            var started: bool = false
            var ended: bool = false
            var max_delta: float = 0.0
            var changed_frames: int = 0
            var max_root_drift: float = 0.0
            var worst_front_step: float = 0.0
            var last_front_y: float = NAN
            var front_samples: Array[Node3D] = [
                ik.get("legs")[ik.LEG_PART_IDS.find(
                    "leg_fl")]["upper"],
                ik.get("legs")[ik.LEG_PART_IDS.find(
                    "leg_fr")]["upper"]]
            var active_leg: Dictionary = ik.get("legs")[
                ik.LEG_PART_IDS.find(id)]
            var checked_socket: int = 0
            for tick in range(900):
                _tick(battle)
                var frame: Dictionary = battle.get(
                    "bittaran_attack_frame")
                if frame.is_empty():
                    if started and not bool(
                            brain.call("is_active")):
                        ended = true
                        break
                    continue
                if str(frame.get("phase", "")) == "stance":
                    continue
                started = true
                max_root_drift = maxf(max_root_drift,
                    absf(rig.position.y - start_root_y))
                var delta_pitch: float = absf(float(
                    ik.get("rear_corner_pitch_delta")))
                max_delta = maxf(max_delta, delta_pitch)
                if delta_pitch > 0.0005:
                    changed_frames += 1
                    if active_leg.has("rear_corner_socket_target_y"):
                        checked_socket += 1
                        var y: float = float(
                            active_leg["rear_corner_socket_target_y"])
                        if not is_finite(y):
                            _fail(id + "/" + kind
                                + " nonfinite solved rear corner")
                            return
                var front_y: float = (
                    front_samples[0].global_position.y
                    + front_samples[1].global_position.y) * 0.5
                if is_finite(last_front_y):
                    worst_front_step = maxf(worst_front_step,
                        absf(front_y - last_front_y))
                last_front_y = front_y
            corner_report.append(id + "/" + kind
                + " corner pitch=" + str(rad_to_deg(max_delta))
                + "deg frames=" + str(changed_frames)
                + " root=" + str(max_root_drift)
                + " front step=" + str(worst_front_step))
            if not ended:
                _fail(id + "/" + kind + " did not finish")
                return
            if max_root_drift > MAX_ROOT_HEIGHT_DELTA:
                _fail(id + "/" + kind + " moved entire rig root")
                return
            # This fixture deliberately places the KICK/STOMP
            # contact beyond the default rear socket's unpitched
            # floor-reachable Y. A legitimate reverse-foot solve
            # MUST change the rear BODY corner, not just move a toe
            # or silently leave the default pitch unchanged.
            if (kind == "kick" or kind == "stomp") and (
                    max_delta < MIN_CORNER_CORRECTION):
                _fail(id + "/" + kind + " never adjusted its "
                    + "rear attachment corner from foot contact")
                return
            if max_delta > 0.01 and checked_socket <= 0:
                _fail(id + "/" + kind
                    + " pitched BODY without a rear contact socket")
                return
            completed += 1
    print("GODOT_V418_REAR_CORNER_REPORT: "
        + " | ".join(corner_report))
    if completed != 14:
        _fail("not all near/far KICKs and rear kinds checked")
        return
    print("GODOT_V418_FULL_KICK_REAR_CORNER_PASS")
    quit(0)
