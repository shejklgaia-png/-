extends SceneTree
## v431: The 17:21 Blockbench file owns the Body and attacking limb.
## Only the other three independent limbs may be IK-grounded.
const DIRECTOR = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 0.05
const GROUND_TOLERANCE: float = 0.08
const SOURCE_PATH: String = "res://models/storage/ビットタラン (1).bbmodel"
const ATTACK_BONES: Dictionary = {
    "leg_fl": ["FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L"],
    "leg_fr": ["FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R"]
}
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V431_THREE_SUPPORT_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("battle scene unavailable")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if rig == null or ik == null or director == null or target == null or player == null:
        _fail("live battle dependencies unavailable")
        return
    if not bool(rig.get("loading_ok")) or not DIRECTOR.ORIGINAL_ATTACK_ONLY:
        _fail("direct authored attack mode unavailable")
        return
    var source_variant: Variant = JSON.parse_string(
        FileAccess.get_file_as_string(SOURCE_PATH))
    if not source_variant is Dictionary:
        _fail("17:21 Blockbench source unavailable")
        return
    var source: Dictionary = source_variant
    var clips: Dictionary = {}
    for clip in source.get("animations", []):
        clips[str(clip.get("name", ""))] = clip
    var bone_names: Dictionary = rig.get("bone_uuid_by_name")
    var bones: Dictionary = rig.get("bones")
    var loaded_clips: Dictionary = rig.get("animations")
    var support_legs: Array = ik.get("legs")
    if support_legs.size() != 4:
        _fail("expected four IK limbs")
        return
    var cases: int = 0
    for repeat in range(2):
        for id in ["leg_fl", "leg_fr"]:
            for kind in ["sweep", "kick", "stomp"]:
                var clip_name: String = (
                    "なぎ払い" if kind == "sweep" else (
                    "弾き" if kind == "kick" else "踏みつけ_L"))
                if id == "leg_fr":
                    clip_name = ("踏みつけ_R" if kind == "stomp"
                        else clip_name + "_R")
                if not clips.has(clip_name) or not loaded_clips.has(clip_name):
                    _fail("missing source clip: " + clip_name)
                    return
                var author: Dictionary = clips[clip_name]
                var loaded: Dictionary = loaded_clips[clip_name]
                var duration: float = float(author.get("length", -1.0))
                if absf(duration - float(loaded.get("length", -2.0))) > 0.00001:
                    _fail("wrong source duration: " + clip_name)
                    return
                var authored_bones: Array[String] = ["Body"]
                authored_bones.append_array(ATTACK_BONES[id])
                for bone_name in authored_bones:
                    var uid: String = str(bone_names.get(bone_name, ""))
                    if uid.is_empty() or not (
                            author["animators"].has(uid) and loaded["animators"].has(uid)):
                        _fail("missing authored animator " + clip_name + "/" + bone_name)
                        return
                    var source_keys: Variant = author["animators"][uid]["keyframes"]
                    var game_keys: Variant = loaded["animators"][uid]["keyframes"]
                    if JSON.stringify(source_keys) != JSON.stringify(game_keys):
                        _fail("clip differs from 17:21 file: " + clip_name + "/" + bone_name)
                        return
                if not bool(director.call("force_start", id, kind)):
                    _fail("force_start failed: " + clip_name)
                    return
                player.global_position = target.global_position + Vector3(0.0, 0.0, 7.0)
                var last_t: float = 0.0
                var frames: int = 0
                for tick in range(80):
                    battle.call("_advance_target_motion", DT)
                    var frame: Dictionary = battle.get("bittaran_attack_frame")
                    if frame.is_empty():
                        break
                    battle.call("_finalize_target_pose", DT)
                    if not bool(frame.get("original_attack_only", false)):
                        _fail("procedural attack mode leaked")
                        return
                    var t: float = float(frame.get("authored_time", -1.0))
                    if absf(t - minf(last_t + DT, duration)) > 0.0001:
                        _fail("source attack clock changed: " + clip_name)
                        return
                    last_t = t
                    for bone_name in authored_bones:
                        var uid: String = str(bone_names[bone_name])
                        var joint: Node3D = bones[uid]
                        var expected: Quaternion = rig.call(
                            "_authored_key_rotation", clip_name, bone_name, t)
                        if joint.quaternion.angle_to(expected) > 0.002:
                            _fail("attacking limb or Body was corrected: "
                                + str([clip_name, bone_name, t]))
                            return
                        var authored_position: Vector3 = rig.call(
                            "_authored_key_position", clip_name, bone_name, t)
                        if joint.position.distance_to(authored_position) > 0.0001:
                            _fail("authored position or pivot overwritten: "
                                + str([clip_name, bone_name, t]))
                            return
                    var grounded: int = 0
                    for index in range(support_legs.size()):
                        if LEG_IDS[index] == id:
                            continue
                        var limb: Dictionary = support_legs[index]
                        var foot: Node3D = limb["foot"]
                        var sole: Vector3 = foot.to_global(
                            limb["sole_local"] as Vector3)
                        if absf(sole.y) > GROUND_TOLERANCE:
                            _fail("support sole not planted: "
                                + str([clip_name, LEG_IDS[index], t, sole.y]))
                            return
                        grounded += 1
                    if grounded != 3:
                        _fail("not exactly three support feet")
                        return
                    if bool(ik.get("front_return_active")):
                        _fail("legacy attack return active")
                        return
                    frames += 1
                    if t >= duration - 0.00001:
                        break
                if frames < 12 or absf(last_t - duration) > 0.00001:
                    _fail("source clip did not finish: " + clip_name)
                    return
                cases += 1
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
    if cases != 12:
        _fail("not all 6 x 2 source clips tested")
        return
    print("GODOT_V431_THREE_SUPPORT_PASS: 6 clips x 2, source striker unchanged, three grounded feet")
    quit(0)
