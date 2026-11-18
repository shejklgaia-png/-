extends SceneTree
## v419: legacy v418 tests updated for the user's new request.
## All KICKs still use full original reach at near/far distances,
## but there is NO rear-only BODY corner pitch or fixed rear root
## constraint. Contact correction is owned by shared four-leg IK.
const DT: float = 1.0 / 60.0
const REAR_IDS: Array[String] = ["leg_rl", "leg_rr"]
# Rear KICK was deliberately removed from the authored clip catalog.
const KINDS: Array[String] = ["sweep", "stomp"]
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
    for id in ["leg_fl", "leg_fr"]:
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
                # v419: actor/root Y may use a shared, measured
                # authored-source floor-contact correction. Never
                # require the former rear-only fixed root height.
                if not is_finite(rig.position.y):
                    _fail(id + " non-finite shared floor height")
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
                # v419: both the added rear-corner BODY pitch
                # and its separate contact-height socket have
                # been removed. Every quadrant is a pure source
                # mirror; the shared IK handles floor contact.
                var delta_pitch: float = absf(float(
                    ik.get("rear_corner_pitch_delta")))
                max_delta = maxf(max_delta, delta_pitch)
                if delta_pitch > 0.0001 or active_leg.has(
                        "rear_corner_socket_target_y"):
                    _fail(id + "/" + kind
                        + " retained special rear-corner pitch")
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
            if not is_finite(max_root_drift) or (
                    max_root_drift > 4.0):
                _fail(id + "/" + kind
                    + " invalid common floor-contact displacement")
                return
            if max_delta > 0.0001:
                _fail(id + "/" + kind
                    + " procedural rear pitch was not removed")
                return
            completed += 1
    print("GODOT_V418_REAR_CORNER_REPORT: "
        + " | ".join(corner_report))
    if completed != 8:
        _fail("not all near/far KICKs and rear kinds checked")
        return
    print("GODOT_V418_FULL_KICK_REAR_CORNER_PASS")
    quit(0)
