extends SceneTree
## Independent attack director timing + all thirteen articulated source
## joint poses at entry, exact authored strike, hold, and smooth recovery.
## This test must catch incorrectly slerped source keys, wrong slowdown
## endpoints, unsorted keys, phase jumps, and unexpected Body Y snaps.
const DIRECTOR = preload("res://scripts/bittaran_attacks.gd")
const RIG = preload("res://scripts/bittaran_rig.gd")
const ENTRY: float = 0.32
const LEG_RETURN: float = 1.20
const BODY_RETURN: float = 0.62
const JOINTS: Array[String] = [
    "Body",
    "FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R",
    "FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L",
    "RearLeg_R", "RearLowerLeg_R", "RearFoot_R",
    "RearLeg_L", "RearLowerLeg_L", "RearFoot_L"
]
const CLIPS: Dictionary = {
    "なぎ払い": ["leg_fl", "sweep"],
    "弾き": ["leg_fl", "kick"],
    "踏みつけ_L": ["leg_fl", "stomp"],
    "なぎ払い_R": ["leg_fr", "sweep"],
    "弾き_R": ["leg_fr", "kick"],
    "踏みつけ_R": ["leg_fr", "stomp"]
}

func _initialize() -> void:
    call_deferred("_run")

func _die(why: String) -> void:
    push_error("V436_ATTACK_TIMING_FAIL " + why)
    quit(1)

func _same(a: float, b: float, tol: float = 0.00005) -> bool:
    return absf(a - b) <= tol

func _ease(progress: float) -> float:
    var t: float = clampf(progress, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


func _smoother(progress: float) -> float:
    var t: float = clampf(progress, 0.0, 1.0)
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

func _expected_phase_pose(rig: Node3D, name: String,
        frame: Dictionary) -> bool:
    var phase: String = str(frame["phase"])
    var source_t: float = float(frame["authored_time"])
    var phase_t: float = float(frame["phase_elapsed"])
    var kind: String = str(frame["kind"])
    var target_uid: Dictionary = rig.get("bone_uuid_by_name")
    var nodes: Dictionary = rig.get("bones")
    for bone_name in JOINTS:
        var uid: String = str(target_uid.get(bone_name, ""))
        if not nodes.has(uid):
            _die("missing source joint " + bone_name)
            return false
        var joint: Node3D = nodes[uid]
        var neutral_q: Quaternion = rig.call(
            "_authored_key_rotation", "Wait", bone_name, 0.0)
        var neutral_p: Vector3 = rig.call(
            "_authored_key_position", "Wait", bone_name, 0.0)
        var original_q: Quaternion = rig.call(
            "_authored_key_rotation", name, bone_name, source_t)
        var original_p: Vector3 = rig.call(
            "_authored_key_position", name, bone_name, source_t)
        var expected_q: Quaternion = original_q
        var expected_p: Vector3 = original_p
        if phase == "entry":
            var w: float = _ease(
                phase_t / float(frame["entry_seconds"]))
            expected_q = neutral_q.slerp(original_q, w)
            expected_p = neutral_p.lerp(original_p, w)
        elif phase == "recovery":
            var body_seconds: float = float(
                frame["body_return_seconds"])
            var leg_id: String = str(frame.get("id", ""))
            var suffix: String = "_R" if leg_id == "leg_fr" else "_L"
            var attacking_bones: Array[String] = [
                "FrontLeg" + suffix,
                "FrontLowerLeg" + suffix,
                "FrontFoot" + suffix
            ]
            if attacking_bones.has(bone_name):
                # The attacking joint stays at its source endpoint
                # while BODY returns; then goes directly to neutral.
                if phase_t <= body_seconds:
                    expected_q = original_q
                    expected_p = original_p
                else:
                    var weight: float = _smoother(
                        (phase_t - body_seconds) / LEG_RETURN)
                    expected_q = original_q.slerp(neutral_q, weight)
                    expected_p = original_p.lerp(neutral_p, weight)
            else:
                var weight: float = _ease(phase_t / body_seconds)
                expected_q = original_q.slerp(neutral_q, weight)
                expected_p = original_p.lerp(neutral_p, weight)
        if joint.quaternion.angle_to(expected_q) > 0.001 or (
                joint.position.distance_to(expected_p) > 0.0002):
            _die("incorrect pose " + str([
                name, phase, bone_name, frame["time"],
                joint.position, expected_p]))
            return false
    return true

func _run() -> void:
    if not _same(DIRECTOR.SOURCE_ENTRY_SECONDS, ENTRY) or not (
            _same(DIRECTOR.SOURCE_LEG_RETURN_SECONDS, LEG_RETURN)
            and _same(DIRECTOR.SOURCE_BODY_RETURN_SECONDS, BODY_RETURN)):
        _die("entry or limb-then-Body timing changed")
        return
    # v445: 1.00s entry, full outward sweep takes exactly 1.00s
    # at constant 0.50x; source turning key t=.50 at attack t=2.00.
    # Recovery leg three-joint chain uses quintic smootherstep.
    if not (_same(DIRECTOR.SWEEP_ENTRY_SECONDS, 1.0)
            and _same(DIRECTOR.source_entry_seconds("sweep"), 1.0)
            and _same(DIRECTOR.source_entry_seconds("kick"), ENTRY)
            and _same(DIRECTOR.source_entry_seconds("stomp"), ENTRY)
            and _same(DIRECTOR.SWEEP_OUTBOUND_REAL_SECONDS, 1.0)
            and _same(DIRECTOR.SWEEP_OUTBOUND_SPEED, 0.50)
            and _same(DIRECTOR.SWEEP_OUTBOUND_TARGET_TOTAL_SECONDS, 2.0)
            and _same(DIRECTOR.source_play_seconds("sweep"), 2.0)
            and _same(DIRECTOR.source_body_return_seconds("sweep"), 1.4)
            and _same(DIRECTOR.source_body_return_seconds("kick"), 0.62)
            and _same(DIRECTOR.source_body_return_seconds("stomp"), 0.62)
            and _same(DIRECTOR.source_total_seconds("sweep"), 5.6)
            and _same(DIRECTOR.SOURCE_LEG_RETURN_SECONDS, LEG_RETURN)):
        _die("v445 sweep 2s outward or eased leg return invalid")
        return
    for pair in [[0.0, 0.0], [0.25, 0.125], [0.50, 0.25],
            [0.75, 0.375], [1.0, 0.50], [1.25, 0.75],
            [1.75, 1.25], [2.0, 1.5]]:
        var time: float = float(pair[0])
        var expected_source: float = float(pair[1])
        if not (_same(DIRECTOR.sweep_clip_time_at(time),
                expected_source)
                and _same(DIRECTOR.source_clip_time("sweep", time),
                    expected_source)):
            _die("outbound 2.00s source clock incorrect " + str(pair))
            return
    for t in [0.0, 0.1, 0.5, 0.999, 1.0, 1.5, 2.0]:
        var expected_speed: float = (
            0.50 if t < 1.0 else 1.0)
        if not _same(DIRECTOR.source_playback_speed("sweep", t),
                expected_speed):
            _die("sweep outward/return rate incorrect " + str(t))
            return
    for kind in ["stomp", "kick", "sweep"]:
        if not _same(
                DIRECTOR.source_return_seconds(kind),
                DIRECTOR.source_body_return_seconds(kind)
                + LEG_RETURN):
            _die("body-first direct leg return invalid " + kind)
            return
    # 5th-order easing is monotonic and C2: both velocity and
    # acceleration smoothly approach zero at the two boundaries.
    var prior: float = -0.001
    for i in range(1001):
        var u: float = float(i) / 1000.0
        var ease: float = _smoother(u)
        if ease < prior - 0.000001 or ease < -0.000001 or (
                ease > 1.000001):
            _die("arm return easing non-monotonic at " + str(u))
            return
        prior = ease
    for u in [0.001, 0.002, 0.998, 0.999]:
        var slope: float = (
            _smoother(u + 0.0001) - _smoother(u - 0.0001)) / 0.0002
        if absf(slope) > 0.0002:
            _die("arm return endpoint velocity is not smooth " + str(u))
            return
    if not _same(DIRECTOR.source_hold_seconds("stomp"), 1.5) or not (
            _same(DIRECTOR.source_hold_seconds("kick"), 1.5)
            and _same(DIRECTOR.source_hold_seconds("sweep"), 0.0)):
        _die("wrong post-hit pause")
        return
    var rig: Node3D = RIG.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _die("Blockbench rig could not load")
        return
    var original_root: Vector3 = rig.position
    var checked: int = 0
    for name in CLIPS.keys():
        var info: Array = CLIPS[name]
        var kind: String = str(info[1])
        var director: RefCounted = DIRECTOR.new()
        if not bool(director.call("force_start", info[0], kind)):
            _die("cannot start " + name)
            return
        var source_len: float = float(
            DIRECTOR.ORIGINAL_CLIP_LENGTHS[kind])
        var attack_entry: float = float(
            DIRECTOR.source_entry_seconds(kind))
        var play_end: float = attack_entry + float(
            DIRECTOR.source_play_seconds(kind))
        var hold_end: float = play_end + float(
            DIRECTOR.source_hold_seconds(kind))
        var total: float = float(
            DIRECTOR.source_total_seconds(kind))
        var ret: float = float(
            DIRECTOR.source_return_seconds(kind))
        var body_seconds: float = float(
            DIRECTOR.source_body_return_seconds(kind))
        var samples: Array[float] = [
            0.0, attack_entry * 0.5, attack_entry,
            attack_entry + 0.12, play_end,
            hold_end, hold_end + ret * 0.25,
            hold_end + ret * 0.50, hold_end + ret * 0.75,
            total
        ]
        if kind == "sweep":
            samples.append(attack_entry + 0.25)
            samples.append(attack_entry + 0.50)
            samples.append(attack_entry + 0.75)
            samples.append(attack_entry + 1.00)
            samples.append(attack_entry + 1.50)
        else:
            samples.append(play_end + 0.75)
        # BODY first, then smooth directly to Wait with no intermediary.
        samples.append(hold_end + body_seconds * 0.5)
        samples.append(hold_end + body_seconds)
        samples.append(hold_end + body_seconds + LEG_RETURN * 0.25)
        samples.append(hold_end + body_seconds + LEG_RETURN * 0.5)
        samples.append(hold_end + body_seconds + LEG_RETURN * 0.75)
        samples.append(hold_end + body_seconds + LEG_RETURN)
        samples.sort()
        var last: float = 0.0
        for at in samples:
            var step: float = maxf(0.0, at - last)
            var frame: Dictionary = director.call("advance", step,
                Vector3.ZERO, {}, true)
            if frame.is_empty():
                _die("missing attack frame at " + str([name, at]))
                return
            if not _same(float(frame["time"]), at) or (
                    str(frame["id"]) != info[0]):
                _die("attack clock mismatch " + str([name, at, frame]))
                return
            if str(frame.get("phase", "")) == "recovery":
                var recovery_time: float = float(
                    frame["phase_elapsed"])
                var expected_stage: String = (
                    "body" if recovery_time <= body_seconds + 0.000001
                    else "leg")
                if str(frame.get("recovery_stage", "")) != expected_stage:
                    _die("recovery order must be Body -> direct Wait " +
                        str([name, recovery_time,
                        frame.get("recovery_stage"), expected_stage]))
                    return
            var clip_t: float = float(frame["authored_time"])
            var expected_t: float = (
                0.0 if at < attack_entry else (
                    DIRECTOR.source_clip_time(kind, at - attack_entry)
                    if at < play_end else source_len))
            if not _same(clip_t, expected_t):
                _die("authored source clock changed " +
                    str([name, at, clip_t, expected_t]))
                return
            if kind == "sweep" and at >= attack_entry and (
                    at < play_end):
                var t: float = at - attack_entry
                var expected_speed: float = (
                    0.50 if t < 1.0 else 1.0)
                if not _same(float(frame["authored_playback_speed"]),
                        expected_speed):
                    _die("sweep source clock speed drift " + str(at))
                    return
            if at >= play_end and not _same(
                    float(frame["authored_playback_speed"]), 0.0):
                _die("source clock must stop during hold/return")
                return
            rig.call("apply_original_attack_only", frame)
            if not _expected_phase_pose(rig, name, frame):
                return
            if rig.position.distance_to(original_root) > 0.00001:
                _die("root moved between poses " + str([name, at]))
                return
            checked += 1
            last = at
        if bool(director.call("is_active")):
            _die("attack did not end after full transition " + name)
            return
    if checked < 65:
        _die("not enough key boundary tests")
        return
    print("GODOT_V436_ATTACK_TIMING_PASS ",
        "six_clips=6 cases=", checked,
        " source_euler_keys=preserved",
        " sweep_entry=1.00sec",
        " sweep_outbound_end=2.00sec",
        " sweep_outbound_uniform_0.50x_no_mid_slow",
        " sweep_return_speed=1.0x",
        " kick_stomp_hold=1.5sec",
        " recovery_order=Body_then_direct_Wait",
        " body=sweep_1.40s_or_kick_stomp_0.62s",
        " leg_return=1.20s_quintic_smootherstep")
    quit(0)
