extends SceneTree
## Current user-approved source attack timing regression.
## The v436 test previously assumed retired v445 0.5x sweeps, sequential
## BODY->leg recovery and 1.50s front sweep. Live v448 has two complete
## Blockbench sweeps, 1x source time and short parallel recovery.
## Probe all TEN physically authored attack/leg combinations in Godot.
const DIRECTOR = preload("res://scripts/bittaran_attacks.gd")
const RIG = preload("res://scripts/bittaran_rig.gd")
const FRAME_DT: float = 1.0 / 60.0
const MAX_TRANSLATION_ERROR: float = 0.0001
const MAX_ROTATION_CHORD: float = 0.0003
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _die(why: String) -> void:
    push_error("V436_ATTACK_TIMING_FAIL " + why)
    quit(1)

func _near(a: float, b: float, tol: float = 0.00012) -> bool:
    return absf(a - b) <= tol

func _quat_distance(a: Quaternion, b: Quaternion) -> float:
    var x: Quaternion = a.normalized()
    var y: Quaternion = b.normalized()
    return minf((x - y).length(), (x + y).length())

func _run() -> void:
    if not DIRECTOR.ORIGINAL_ATTACK_ONLY:
        _die("source attack timeline no longer active")
        return
    if not DIRECTOR.TEST_PARALLEL_BODY_LEG_RETURN:
        _die("current BODY/striker recovery must be concurrent")
        return
    var examined: int = 0
    var source_samples: int = 0
    var recovery_samples: int = 0
    var durations: Array[String] = []
    for leg_id in LEG_IDS:
        for kind in ["stomp", "kick", "sweep"]:
            if leg_id.begins_with("leg_r") and kind == "kick":
                # No such authoring clip in the imported source.
                continue
            var clips: Dictionary = RIG.SOURCE_ATTACK_CLIPS[leg_id]
            var name: String = str(clips.get(kind, ""))
            if name.is_empty():
                _die("a legal attack lacks a source clip " + str([
                    leg_id, kind]))
                return
            var source_length: float = DIRECTOR.source_clip_length(
                kind, leg_id)
            var expected_length: float = (
                2.625 if kind == "sweep" and leg_id.begins_with("leg_f")
                else 1.54167 if kind == "sweep"
                else 1.75 if kind == "stomp" and leg_id.begins_with("leg_f")
                else 1.0)
            if not _near(source_length, expected_length):
                _die("source duration mismatch " + str([
                    leg_id, kind, source_length, expected_length]))
                return
            var entry: float = DIRECTOR.source_entry_seconds(kind)
            var playback: float = DIRECTOR.source_play_seconds(kind, leg_id)
            var hold: float = DIRECTOR.source_hold_seconds(kind)
            var recovery: float = DIRECTOR.source_return_seconds(kind)
            var total: float = DIRECTOR.source_total_seconds(kind, leg_id)
            if not _near(total, entry + playback + hold + recovery):
                _die("timing phases have a gap " + str([leg_id, kind]))
                return
            if kind == "sweep":
                if not _near(playback, source_length) or (
                        recovery > 0.21) or hold > 0.0001:
                    _die("full sweep time-warped or old return retained")
                    return
            else:
                var wanted_return: float = maxf(
                    DIRECTOR.source_body_return_seconds(kind),
                    DIRECTOR.source_leg_return_seconds(kind))
                if not _near(recovery, wanted_return):
                    _die("simultaneous recovery changed " + str([leg_id, kind]))
                    return
            var director: RefCounted = DIRECTOR.new()
            if not bool(director.call("force_start", leg_id, kind)):
                _die("director refused legal authored " + str([leg_id,kind]))
                return
            var rig: Node3D = RIG.new()
            root.add_child(rig)
            if not bool(rig.get("loading_ok")):
                _die("Blockbench source missing")
                return
            var bones: Dictionary = rig.get("bones")
            var bone_map: Dictionary = rig.get("bone_uuid_by_name")
            var source_clock: float = -0.00001
            var previous: float = -0.00001
            var saw_entry: bool = false
            var saw_strike: bool = false
            var saw_recovery: bool = false
            var terminal: bool = false
            for step in range(600):
                var frame: Dictionary = director.call("advance",
                    FRAME_DT, Vector3.ZERO, {}, true)
                if frame.is_empty():
                    break
                var t: float = float(frame["time"])
                var authored_t: float = float(frame["authored_time"])
                var phase: String = str(frame["phase"])
                if t < previous - 0.000001 or (
                        t > total + 0.0001) or (
                        authored_t < source_clock - 0.000001) or (
                        authored_t > source_length + 0.0001):
                    _die("nonmonotonic authored timeline " + str([
                        leg_id, kind, phase, t, authored_t]))
                    return
                previous = t
                source_clock = authored_t
                if str(frame["id"]) != leg_id or (
                        str(frame["kind"]) != kind) or (
                        not bool(frame["original_attack_only"])):
                    _die("director switched leg or kind mid-clip")
                    return
                if phase == "entry":
                    saw_entry = true
                    if authored_t > 0.00001:
                        _die("authoring clip advanced during entry")
                        return
                elif phase == "strike":
                    saw_strike = true
                    var expected_t: float = DIRECTOR.source_clip_time(
                        kind, float(frame["phase_elapsed"]), leg_id)
                    if not _near(authored_t, expected_t):
                        _die("source key timestamp drifted " + str([
                            leg_id, kind, authored_t, expected_t]))
                        return
                    if kind == "sweep":
                        if not _near(float(frame[
                                "authored_playback_speed"]), 1.0):
                            _die("user-authored sweep no longer 1x")
                            return
                        if not _near(authored_t,
                                float(frame["phase_elapsed"])):
                            _die("sweep replay changed internal key timing")
                            return
                elif phase == "hold":
                    if not _near(authored_t, source_length):
                        _die("hold started before source clip ended")
                        return
                elif phase == "recovery":
                    saw_recovery = true
                    recovery_samples += 1
                    if not _near(authored_t, source_length) or (
                            str(frame["recovery_stage"]) != "parallel") or (
                            not bool(frame["parallel_recovery"])):
                        _die("old BODY->leg recovery resurfaced")
                        return
                else:
                    _die("unexpected source phase " + phase)
                    return
                if kind == "sweep" and not bool(
                        frame.get("authored_full_sweep", false)):
                    _die("new full-length sweep route not selected")
                    return
                rig.call("apply_original_attack_only", frame)
                if phase == "strike":
                    # During the actual strike there is NO playback
                    # retargeting or slerp; check thirteen skeletal joints
                    # against the exact authored sampled position/rotation.
                    for bone_name in [
                            "Body", "FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L",
                            "FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R",
                            "RearLeg_L", "RearLowerLeg_L", "RearFoot_L",
                            "RearLeg_R", "RearLowerLeg_R", "RearFoot_R"]:
                        var uid: String = str(bone_map.get(bone_name, ""))
                        var joint: Node3D = bones[uid]
                        var q: Quaternion = rig.call(
                            "_authored_key_rotation", name, bone_name, authored_t)
                        var p: Vector3 = rig.call(
                            "_authored_key_position", name, bone_name, authored_t)
                        if _quat_distance(joint.quaternion, q) > (
                                MAX_ROTATION_CHORD) or (
                                joint.position.distance_to(p) >
                                MAX_TRANSLATION_ERROR):
                            _die("authored joint altered " + str([
                                leg_id, kind, authored_t, bone_name]))
                            return
                    source_samples += 1
                if _near(t, total):
                    terminal = true
                    break
            if not saw_entry or not saw_strike or not saw_recovery or (
                    not terminal):
                _die("authored phase incomplete " + str([
                    leg_id, kind, saw_entry, saw_strike, saw_recovery,terminal]))
                return
            for bone_name in [
                    "Body", "FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L",
                    "FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R",
                    "RearLeg_L", "RearLowerLeg_L", "RearFoot_L",
                    "RearLeg_R", "RearLowerLeg_R", "RearFoot_R"]:
                var uid: String = str(bone_map[bone_name])
                var joint: Node3D = bones[uid]
                var neutral: Quaternion = rig.call(
                    "_authored_key_rotation", "Wait", bone_name, 0.0)
                var neutral_pos: Vector3 = rig.call(
                    "_authored_key_position", "Wait", bone_name, 0.0)
                if _quat_distance(joint.quaternion, neutral) > 0.001 or (
                        joint.position.distance_to(neutral_pos) > 0.0002):
                    _die("final source motion did not hand back to Wait " +
                        str([leg_id, kind, bone_name]))
                    return
            rig.queue_free()
            examined += 1
            durations.append(leg_id + "/" + kind + "=" +
                str(snappedf(total, 0.001)))
    if examined != 10 or source_samples < 850 or (
            recovery_samples < 75):
        _die("insufficient active timeline checks " + str([
            examined, source_samples, recovery_samples]))
        return
    print("GODOT_V436_ATTACK_TIMING_PASS legal_attacks=", examined,
        " source_joint_samples=", source_samples,
        " simultaneous_recovery_samples=", recovery_samples,
        " complete_user_authored_sweeps=4",
        " timeline=", ",".join(durations))
    quit(0)
