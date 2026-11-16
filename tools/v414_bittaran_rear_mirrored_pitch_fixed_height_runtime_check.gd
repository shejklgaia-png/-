extends SceneTree
## v414: Rear STOMP/KICK/SWEEP must pitch from the Wait backward
## lean to the SAME magnitude forward, with no change to visual-root Y.
## v418 adds *measured* BODY pitch for the rear joint's FOOT-CONTACT
## height: subtract that per-frame pitch before checking the old
## mirrored-angle invariant. The rear BODY CORNER may change height
## while the rig/root does not. The live battle loop is exercised.
const DT: float = 1.0 / 60.0
const KINDS: Array[String] = ["stomp", "kick", "sweep"]
const REAR_LEGS: Array[String] = ["leg_rl", "leg_rr"]
const MAX_PITCH_ERROR: float = deg_to_rad(3.0)
const MAX_HEIGHT_CHANGE: float = 0.002


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V414_BITTARAN_REAR_MIRRORED_PITCH_FAIL: " + message)
    quit(1)


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
    if boss == null or player == null or rig == null or ik == null             or brain == null:
        _fail("missing real Bittaran battle")
        return
    var neutral_pitch: float = (
        ik.get("rest_chassis_rotation") as Quaternion).get_euler().x
    if absf(neutral_pitch) < deg_to_rad(10.0):
        _fail("no authored backward lean to mirror")
        return
    var completed: int = 0
    for id in REAR_LEGS:
        for kind in KINDS:
            battle.call("_reset_target_after_respawn")
            battle.set("target_move_enabled", true)
            battle.set("player_hp", 9999.0)
            player.global_position = boss.global_position + (
                Vector3(-5.0 if id == "leg_rl" else 5.0, 0.0, 5.0))
            if not bool(brain.call("force_start_with_stance", id, kind)):
                _fail("cannot start " + id + "/" + kind)
                return
            var phase_seen: Dictionary = {}
            var before_y: float = rig.position.y
            var attack_y: float = NAN
            var max_pitch_error: float = 0.0
            var strike_pitch_checked: bool = false
            var done: bool = false
            for tick in range(850):
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                if frame.is_empty():
                    if not brain.call("is_active") and not phase_seen.is_empty():
                        done = true
                        break
                    continue
                var phase: String = str(frame.get("phase", ""))
                if phase == "stance":
                    continue
                phase_seen[phase] = true
                if not is_finite(attack_y):
                    attack_y = rig.position.y
                if absf(attack_y - before_y) > MAX_HEIGHT_CHANGE or (
                        absf(rig.position.y - attack_y)
                        > MAX_HEIGHT_CHANGE):
                    _fail(id + "/" + kind + " moved chassis height by "
                        + str(rig.position.y - before_y)
                        + " at phase " + phase)
                    return
                var pitch: float = (
                    ik.get("chassis_bone") as Node3D
                    ).quaternion.get_euler().x
                var t: float = float(frame.get("time", 0.0))
                var windup: float = maxf(
                    float(frame.get("windup", 0.7)), 0.001)
                var strike: float = float(frame.get("strike", 1.0))
                var hold: float = float(frame.get("hold", 0.0))
                var recovery: float = maxf(
                    float(frame.get("recovery", 0.6)), 0.001)
                var advance: float = _smooth01(t / windup)
                var retreat: float = 1.0 - _smooth01(
                    (t - windup - strike - hold) / recovery)
                var expect: float = lerpf(neutral_pitch, -neutral_pitch,
                    advance * retreat)
                var contact_pitch: float = float(
                    ik.get("rear_corner_pitch_delta"))
                if absf(contact_pitch) > 0.60:
                    _fail(id + "/" + kind
                        + " contact-derived extra pitch unbounded")
                    return
                var source_pitch: float = pitch - contact_pitch
                var error: float = absf(source_pitch - expect)
                max_pitch_error = maxf(max_pitch_error, error)
                if error > MAX_PITCH_ERROR:
                    _fail(id + "/" + kind + " expected pitch "
                        + str(rad_to_deg(expect)) + "deg, got "
                        + str(rad_to_deg(pitch)) + "deg at t=" + str(t))
                    return
                if phase == "strike" and t > windup + 0.08:
                    strike_pitch_checked = true
                    if absf(source_pitch + neutral_pitch) > MAX_PITCH_ERROR:
                        _fail(id + "/" + kind
                            + " did not reach the full opposite lean")
                        return
                if phase == "recovery" and t > (
                        windup + strike + hold + recovery * 0.90):
                    if absf(source_pitch - neutral_pitch) > deg_to_rad(4.0):
                        _fail(id + "/" + kind
                            + " failed to restore neutral pitch")
                        return
            if not done or not strike_pitch_checked or (
                    not phase_seen.has("windup")
                    or not phase_seen.has("strike")
                    or not phase_seen.has("recovery")):
                _fail(id + "/" + kind + " missed a live attack phase")
                return
            completed += 1
    if completed != 6:
        _fail("expected 6 rear attacks")
        return
    print("GODOT_V414_BITTARAN_REAR_MIRRORED_PITCH_PASS: "
        + "6 attacks, source Wait pitch plus v418 foot-contact "
        + "corner height calibration; fixed model/root Y")
    quit(0)


func _smooth01(v: float) -> float:
    var t: float = clampf(v, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
