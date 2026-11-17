extends SceneTree
## v434: independently compare the original Blockbench JSON's keyed
## Euler/position channels (including deliberately UNSORTED keys) against
## the live Godot 13-bone source replay. IK must never alter source poses.
const BATTLE = preload("res://scripts/bittaran_battle.gd")
const SOURCE_PATH: String = "res://models/storage/ビットタラン (1).bbmodel"
const UNIT: float = 0.145
const ROTATION_TOLERANCE_RAD: float = 0.0003
const POSITION_TOLERANCE_METERS: float = 0.00005
const ATTACKS: Dictionary = {
    "なぎ払い": ["leg_fl", "sweep"],
    "弾き": ["leg_fl", "kick"],
    "踏みつけ_L": ["leg_fl", "stomp"],
    "なぎ払い_R": ["leg_fr", "sweep"],
    "弾き_R": ["leg_fr", "kick"],
    "踏みつけ_R": ["leg_fr", "stomp"],
}

func _initialize() -> void:
    call_deferred("_run")

func _die(why: String) -> void:
    push_error("V434_BLOCKBENCH_REPLAY_FAILED: " + why)
    quit(1)

func _at(k: Dictionary) -> float:
    return float(k.get("time", 0.0))

func _component(k: Dictionary) -> Vector3:
    var data: Array = k.get("data_points", [])
    if data.is_empty():
        return Vector3.ZERO
    var p: Dictionary = data[0]
    return Vector3(float(p.get("x", 0.0)),
        float(p.get("y", 0.0)), float(p.get("z", 0.0)))

func _keys(animator: Dictionary, channel: String) -> Array:
    var result: Array = []
    for k in animator.get("keyframes", []):
        if str(k.get("channel", "rotation")) == channel:
            result.append(k)
    # Independent insertion sort (not the rig's sort_custom).
    for i in range(1, result.size()):
        var j: int = i
        while j > 0 and _at(result[j]) < _at(result[j - 1]):
            var prev: Variant = result[j - 1]
            result[j - 1] = result[j]
            result[j] = prev
            j -= 1
    return result

func _source_vector(animator: Dictionary, channel: String, t: float) -> Vector3:
    var ks: Array = _keys(animator, channel)
    if ks.is_empty():
        return Vector3.ZERO
    if t <= _at(ks[0]):
        return _component(ks[0])
    for i in range(1, ks.size()):
        if t <= _at(ks[i]):
            var amount: float = clampf(
                (t - _at(ks[i - 1])) / maxf(
                    _at(ks[i]) - _at(ks[i - 1]), 0.000001),
                0.0, 1.0)
            return _component(ks[i - 1]).lerp(_component(ks[i]),
                amount)
    return _component(ks[ks.size() - 1])

func _raw_rotation_xyz(degrees: Vector3) -> Quaternion:
    var x: Quaternion = Quaternion(Vector3.RIGHT,
        deg_to_rad(degrees.x))
    var y: Quaternion = Quaternion(Vector3.UP,
        deg_to_rad(degrees.y))
    var z: Quaternion = Quaternion(Vector3.BACK,
        deg_to_rad(degrees.z))
    return (z * y * x).normalized()

func _is_mesh_static(rig: Node3D, label: String) -> bool:
    var meshes: Dictionary = rig.get("mesh_nodes_by_uuid")
    var bind: Dictionary = rig.get("mesh_base_positions_by_uuid")
    if meshes.size() != 18:
        _die("18 mesh elements expected, got " + str(meshes.size()))
        return false
    for uid in meshes.keys():
        var piece: MeshInstance3D = meshes[uid]
        if piece.position.distance_to(bind[uid]) > POSITION_TOLERANCE_METERS:
            _die("mesh-local offset not in source: " + str([label, uid]))
            return false
    return true

func _compare_clip(rig: Node3D, source_clip: Dictionary,
        t: float, label: String) -> bool:
    var clip_name: String = str(source_clip["name"])
    rig.call("apply_source_clip_exact", clip_name, t)
    var bone_names: Dictionary = rig.get("bone_uuid_by_name")
    var bones: Dictionary = rig.get("bones")
    var bind_positions: Dictionary = rig.get("bind_positions")
    var bind_rotations: Dictionary = rig.get("bind_rotations")
    var groups: Dictionary = rig.get("animations")
    if not groups.has(clip_name):
        _die("No runtime clip " + clip_name)
        return false
    var author_animators: Dictionary = source_clip.get("animators", {})
    var count: int = 0
    for name in [
            "Body", "FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R",
            "FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L",
            "RearLeg_R", "RearLowerLeg_R", "RearFoot_R",
            "RearLeg_L", "RearLowerLeg_L", "RearFoot_L"]:
        var uid: String = str(bone_names.get(name, ""))
        if uid.is_empty() or not bones.has(uid):
            _die("Missing source bone " + name)
            return false
        var animator: Dictionary = author_animators.get(uid, {})
        var expected_position: Vector3 = (
            bind_positions[uid] + UNIT * _source_vector(
                animator, "position", t))
        var expected_rotation: Quaternion = (
            bind_rotations[uid] * _raw_rotation_xyz(
                _source_vector(animator, "rotation", t))).normalized()
        var bone: Node3D = bones[uid]
        if bone.position.distance_to(
                expected_position) > POSITION_TOLERANCE_METERS:
            _die("wrong source position " + str([
                label, clip_name, name, t, bone.position, expected_position]))
            return false
        if bone.quaternion.angle_to(
                expected_rotation) > ROTATION_TOLERANCE_RAD:
            _die("wrong source EULER rotation " + str([
                label, clip_name, name, t, bone.quaternion,
                expected_rotation]))
            return false
        count += 1
    if count != 13 or not _is_mesh_static(rig, label):
        return false
    return true

func _run() -> void:
    if not BATTLE.BLOCKBENCH_SOURCE_REPLAY_ONLY:
        _die("Source replay must bypass IK/head correction")
        return
    var txt: String = FileAccess.get_file_as_string(SOURCE_PATH)
    var value: Variant = JSON.parse_string(txt)
    if not value is Dictionary:
        _die("Cannot read original 17:21 Blockbench model")
        return
    var src: Dictionary = value
    var clips: Array = src.get("animations", [])
    if clips.size() != 7:
        _die("Expected the original Wait + six attacks")
        return
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _die("Cannot load Bittaran battle")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    var director: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if rig == null or director == null or ik == null or (
            not bool(rig.get("loading_ok"))):
        _die("Boss dependencies not ready")
        return
    var initial_root_y: float = rig.position.y
    var original_head: Node3D = rig.find_child("Head", true, false) as Node3D
    var head_pose: Quaternion = original_head.quaternion
    var total: int = 0
    var disorder_count: int = 0
    var all_clips: Dictionary = {}
    for clip in clips:
        var name: String = str(clip.get("name", ""))
        all_clips[name] = clip
        var length: float = float(clip.get("length", 0.0))
        var key_times: Array[float] = [0.0, length]
        for animator in (clip.get("animators", {}) as Dictionary).values():
            var previous: float = -INF
            for k in animator.get("keyframes", []):
                var t: float = _at(k)
                key_times.append(t)
                if t < previous:
                    disorder_count += 1
                previous = t
        key_times.sort()
        var sampled: Array[float] = key_times.duplicate()
        for i in range(1, key_times.size()):
            var a: float = key_times[i - 1]
            var b: float = key_times[i]
            if b - a > 0.0001:
                sampled.append(lerpf(a, b, 0.25))
                sampled.append(lerpf(a, b, 0.50))
                sampled.append(lerpf(a, b, 0.75))
        for i in range(0, ceili(length * 60.0)):
            sampled.append(minf(float(i) / 60.0, length))
        for t in sampled:
            if not _compare_clip(rig, clip, t, "all-samples"):
                return
            if absf(rig.position.y - initial_root_y) > 0.00001:
                _die("Source clip changed root height " + name)
                return
            if original_head.quaternion.angle_to(head_pose) > 0.0001:
                _die("Source playback overwrote neutral Head")
                return
            total += 1
    if disorder_count < 6 or total < 450:
        _die("Did not cover the unsorted Blockbench keys " +
            str([disorder_count, total]))
        return
    # Integration test: actual battle source-only path must not run IK
    # after the original pose, and must not re-aim the head.
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    player.global_position = target.global_position + Vector3(0.0, 0.0, 7.0)
    for name in ATTACKS.keys():
        var info: Array = ATTACKS[name]
        if not bool(director.call("force_start", info[0], info[1])):
            _die("Cannot start " + name)
            return
        for step in range(4):
            battle.call("_advance_target_motion", 0.10)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty() or not bool(frame.get("original_attack_only", false)):
                _die("Source-only attack not routed " + name)
                return
            battle.call("_finalize_target_pose", 0.10)
            var t: float = float(frame.get("authored_time", 0.0))
            # Capture the battle result BEFORE sampling independently.
            var observed: Dictionary = {}
            var bones: Dictionary = rig.get("bones")
            for uid in bones.keys():
                var bone: Node3D = bones[uid]
                observed[uid] = [bone.position, bone.quaternion]
            if not _compare_clip(rig, all_clips[name], t, "battle"):
                return
            for uid in bones.keys():
                var bone: Node3D = bones[uid]
                if bone.position.distance_to(observed[uid][0]) > 0.0001 or (
                        bone.quaternion.angle_to(observed[uid][1]) > 0.0003):
                    _die("Battle rewrote source pose via IK: " +
                        str([name, uid, t]))
                    return
            if absf(rig.position.y - initial_root_y) > 0.0001:
                _die("Live battle changed Blockbench root height " + name)
                return
            total += 1
    print("GODOT_V434_BLOCKBENCH_EXACT_REPLAY_PASS ",
        "original_clips=7 bones=13 unsorted_traversals=", disorder_count,
        " sampled=", total, " IK=OFF head_track=OFF")
    quit(0)
