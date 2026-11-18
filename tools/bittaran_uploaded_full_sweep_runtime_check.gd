extends SceneTree
## Real Godot regression for the user's revised Blockbench sweep source.
## Assert left clip exact keys, right clip geometric reflection,
## original-duration source clock, and a return handoff only AFTER
## the authored windup + strike + foot return has fully played.
const RIG = preload("res://scripts/bittaran_rig.gd")
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const EMBEDDED = preload("res://assets/bittaran_data.gd")
const USER_MODEL: String = "res://models/storage/ビットタラン_20261118_新なぎ払い.bbmodel"
const CLIPS: Array = [
    ["なぎ払い_L", "なぎ払い", "なぎ払い_R",
        "leg_fl", "leg_fr", 2.625, 73],
    ["後足なぎ払い_L", "後足なぎ払い_L", "後足なぎ払い_R",
        "leg_rl", "leg_rr", 1.54167, 36]
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("AUTHORED_FULL_SWEEP_FAIL " + message)
    quit(1)

func _clip(data: Dictionary, name: String) -> Dictionary:
    for clip in data.get("animations", []):
        if str(clip.get("name", "")) == name:
            return clip
    return {}

func _mirrored(name: String) -> String:
    if name.ends_with("_L"):
        return name.substr(0, name.length() - 2) + "_R"
    if name.ends_with("_R"):
        return name.substr(0, name.length() - 2) + "_L"
    return name

func _same_scalar(a: float, b: float) -> bool:
    return absf(a - b) < 0.00012

func _run() -> void:
    var raw: Variant = JSON.parse_string(
        FileAccess.get_file_as_string(USER_MODEL))
    var embedded: Variant = JSON.parse_string(EMBEDDED.get_json())
    if not raw is Dictionary or not embedded is Dictionary:
        _fail("uploaded original or Android fallback missing")
        return
    var authored: Dictionary = raw
    var fallback: Dictionary = embedded
    var rig: Node3D = RIG.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _fail("new four-sweep rig would not load")
        return
    var uuid_to_name: Dictionary = {}
    var name_to_uuid: Dictionary = rig.get("bone_uuid_by_name")
    for name in name_to_uuid:
        uuid_to_name[name_to_uuid[name]] = name
    var keys_verified: int = 0
    var sampled: int = 0
    for spec in CLIPS:
        var source: Dictionary = _clip(authored, str(spec[0]))
        if source.is_empty():
            _fail("missing uploaded clip " + str(spec[0]))
            return
        for mode in range(2):
            var dst_name: String = str(spec[1 + mode])
            var id: String = str(spec[3 + mode])
            var target: Dictionary = _clip(fallback, dst_name)
            if target.is_empty():
                _fail("Android model missing " + dst_name)
                return
            if not _same_scalar(float(target.get("length", -1)),
                    float(spec[5])):
                _fail("new duration missing " + dst_name)
                return
            if not rig.get("animations").has(dst_name):
                _fail("runtime clip missing " + dst_name)
                return
            var source_anim: Dictionary = source["animators"]
            var mirror: bool = mode == 1
            var key_count: int = 0
            for uid in source_anim:
                if not uuid_to_name.has(uid):
                    continue
                var bone_name: String = uuid_to_name[uid]
                var target_name: String = (
                    _mirrored(bone_name) if mirror else bone_name)
                var target_uid: String = name_to_uuid[target_name]
                var original_keys: Array = source_anim[uid].get(
                    "keyframes", [])
                var reflected_keys: Array = target["animators"][
                    target_uid].get("keyframes", [])
                if original_keys.size() != reflected_keys.size():
                    _fail("missing mirrored keys " + str([
                        dst_name, target_name]))
                    return
                for i in range(original_keys.size()):
                    var before: Dictionary = original_keys[i]
                    var after: Dictionary = reflected_keys[i]
                    if str(before.get("channel", "")) != str(
                            after.get("channel", "")) or not _same_scalar(
                            float(before["time"]), float(after["time"])):
                        _fail("source channel/time altered " + str([
                            dst_name, target_name, i]))
                        return
                    var src_values: Dictionary = before["data_points"][0]
                    var dst_values: Dictionary = after["data_points"][0]
                    var channel: String = str(before["channel"])
                    for axis in ["x", "y", "z"]:
                        var value: float = float(src_values.get(axis, 0))
                        if mirror:
                            if channel == "rotation" and axis != "x":
                                value = -value
                            elif channel == "position" and axis == "x":
                                value = -value
                        if not _same_scalar(
                                value, float(dst_values.get(axis, 0))):
                            _fail("mirrored Euler/translation wrong " + str([
                                dst_name, target_name, i, axis]))
                            return
                    key_count += 1
            if key_count != int(spec[6]):
                _fail("authored key count changed " + str([
                    dst_name, key_count, spec[6]]))
                return
            keys_verified += key_count
            var director: RefCounted = ATTACKS.new()
            if not bool(director.call("force_start", id, "sweep")):
                _fail("cannot start revised " + id)
                return
            var previous: float = -0.001
            var seen_strike: bool = false
            var seen_recovery: bool = false
            var total: float = ATTACKS.source_total_seconds(
                "sweep", id)
            for step in range(240):
                var frame: Dictionary = director.call(
                    "advance", 0.025, Vector3(6.0, 0.0, 0.0),
                    {}, true)
                if frame.is_empty():
                    break
                if not bool(frame.get("authored_full_sweep", false)):
                    _fail("authored source route lost " + id)
                    return
                var phase: String = str(frame.get("phase", ""))
                var t: float = float(frame["authored_time"])
                if t < previous - 0.00001 or (
                        t > float(spec[5]) + 0.0001):
                    _fail("source clock discontinuity " + str([
                        id, phase, t, previous]))
                    return
                if phase == "strike":
                    seen_strike = true
                    if not _same_scalar(float(
                            frame["authored_playback_speed"]), 1.0):
                        _fail("new keyframes are time-warped " + id)
                        return
                    if not _same_scalar(t, float(frame["phase_elapsed"])):
                        _fail("source is not replayed 1:1 " + id)
                        return
                if phase == "recovery":
                    seen_recovery = true
                    if not _same_scalar(t, float(spec[5])):
                        _fail("recovery started before authored clip ended")
                        return
                    if float(frame.get("recovery", INF)) > 0.21:
                        _fail("old artificial return is still active " + id)
                        return
                rig.call("apply_original_attack_only", frame)
                previous = t
                sampled += 1
                if float(frame["time"]) >= total - 0.0001:
                    break
            if not seen_strike or not seen_recovery or not (
                    _same_scalar(previous, float(spec[5]))):
                _fail("full windup/strike/foot-return did not play " + id)
                return
    if sampled < 180 or keys_verified != 218:
        _fail("insufficient four-leg samples or source keys")
        return
    print("GODOT_AUTHORED_FULL_SWEEP_PASS ",
        "front_LR=2.625s rear_LR=1.54167s ",
        "original_keys_verified=", keys_verified,
        " source_playback=1x separate_foot_return=off ",
        "Android_fallback_synced=true samples=", sampled)
    quit(0)
