extends SceneTree
## v419 contract supersedes v414's artificial "rear goes from
## +25deg backward to -25deg forward" pose. The actual original
## Blockbench BODY keyframes, reflected X and/or Z by the same
## rule as its attacking leg, are the ONLY BODY animation for all
## four quadrants. No extra rear-corner pitch, ever. This is an
## independent FULL LIVE SCENE verification (not a rig-only test).
const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const KINDS: Array[String] = ["kick", "sweep", "stomp"]
const MAX_POSE_ERROR_RAD: float = 0.025


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V414_BITTARAN_MIRRORED_BODY_SOURCE_FAIL: " + why)
    quit(1)


func _cubic(x: float) -> float:
    var t: float = clampf(x, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var body: Node3D = rig.find_child("Body", true, false)
    if boss == null or player == null or rig == null or ik == null             or brain == null or body == null:
        _fail("missing complete real Bittaran battle")
        return
    var count: int = 0
    var frames_checked: int = 0
    for id in IDS:
        for kind in KINDS:
            battle.call("_reset_target_after_respawn")
            battle.set("target_move_enabled", true)
            battle.set("player_hp", 9999.0)
            player.global_position = boss.global_position                 + Vector3(-5.0 if id.ends_with("l") else 5.0,
                    0.0, 5.0 if id.begins_with("leg_r") else -5.0)
            if not bool(brain.call(
                    "force_start_with_stance", id, kind)):
                _fail(id + "/" + kind + " did not start")
                return
            var began: bool = false
            var finished: bool = false
            for tick in range(850):
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
                var frame: Dictionary = battle.get(
                    "bittaran_attack_frame")
                if frame.is_empty():
                    if began and not bool(brain.call("is_active")):
                        finished = true
                        break
                    continue
                if str(frame.get("phase", "")) == "stance":
                    continue
                began = true
                var t: float = float(frame.get("time", 0.0))
                var windup: float = float(frame.get("windup", 0.7))
                var strike: float = float(frame.get("strike", 1.0))
                var hold: float = float(frame.get("hold", 0.0))
                var recovery: float = maxf(float(
                    frame.get("recovery", 0.6)), 0.001)
                var clip_t: float = float(frame.get(
                    "authored_time", 0.0))
                if kind == "stomp":
                    clip_t = minf(clip_t, windup + strike)
                clip_t = clampf(clip_t, 0.0,
                    float(rig.call("authored_clip_length", kind)))
                var base: Quaternion = rig.call(
                    "_authored_body_rotation_for_attack",
                    kind, id, clip_t)
                var rest: Quaternion = rig.call(
                    "_authored_key_rotation", "Wait", "Body", 0.0)
                var release: float = _cubic(
                    (t - windup - strike - hold) / recovery)
                var authored: Quaternion = base.slerp(
                    rest, release).normalized()
                var yaw_release: float = 1.0 - release
                var body_yaw: float = float(
                    frame.get("body_yaw", 0.0))
                var expected: Quaternion = (
                    Quaternion(Vector3.UP, body_yaw * yaw_release)
                    * authored).normalized()
                var err: float = body.quaternion.angle_to(expected)
                if err > MAX_POSE_ERROR_RAD:
                    _fail(id + "/" + kind + " at t=" + str(t)
                        + " non-authored BODY pitch/yaw: "
                        + str(rad_to_deg(err)) + "deg")
                    return
                var corner_pitch: float = float(
                    ik.get("rear_corner_pitch_delta"))
                if absf(corner_pitch) > 0.0001:
                    _fail(id + "/" + kind
                        + " old rear-corner pitch still active")
                    return
                frames_checked += 1
            if not finished or not began:
                _fail(id + "/" + kind + " did not finish")
                return
            count += 1
    if count != 12 or frames_checked < 800:
        _fail("insufficient in-scene mirrored BODY frames: "
            + str([count, frames_checked]))
        return
    print("GODOT_V419_BODY_SOURCE_NO_EXTRA_LEAN_PASS: "
        + str(frames_checked) + " real frames; X/Z BODY mirror "
        + "for all 12 attacks, no synthetic front/back tilt")
    quit(0)
