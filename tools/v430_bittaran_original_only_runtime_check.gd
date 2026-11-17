extends SceneTree
## v430: Six unmodified Blockbench front-attack clips at source speed.
## Compare ALL 13 authored joint tracks, no IK/contact/height/retargeting.
const RIG = preload("res://scripts/bittaran_rig.gd")
const DIRECTOR = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 0.05

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V430_ORIGINAL_ONLY_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("battle scene not loadable")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if rig == null or ik == null or director == null or player == null:
        _fail("live combat dependencies missing")
        return
    if not bool(rig.get("loading_ok")) or not DIRECTOR.ORIGINAL_ATTACK_ONLY:
        _fail("original-only game mode not active")
        return
    var model_source: String = FileAccess.get_file_as_string(
        "res://models/storage/ビットタラン.bbmodel")
    var source_variant: Variant = JSON.parse_string(model_source)
    if not source_variant is Dictionary:
        _fail("original editable Blockbench source unavailable")
        return
    var source: Dictionary = source_variant
    var author_lengths: Dictionary = {}
    for clip in source.get("animations", []):
        author_lengths[str(clip.get("name", ""))] = float(
            clip.get("length", 0.0))
    var names: Dictionary = rig.get("bone_uuid_by_name")
    var bones: Dictionary = rig.get("bones")
    var bind: Dictionary = rig.get("bind_positions")
    var animations: Dictionary = rig.get("animations")
    var tested: int = 0
    var sampled_by_clip: Dictionary = {}
    for repeat in range(2):
        for id in ["leg_fl", "leg_fr"]:
            for kind in ["sweep", "kick", "stomp"]:
                var clip_name: String = (
                    "なぎ払い" if kind == "sweep" else (
                    "弾き" if kind == "kick" else "踏みつけ_L"))
                if id == "leg_fr":
                    clip_name = ("踏みつけ_R" if kind == "stomp"
                        else clip_name + "_R")
                var duration: float = float(author_lengths.get(clip_name, -1))
                if duration < 0.1 or not animations.has(clip_name) or (
                        absf(duration - float(DIRECTOR.ORIGINAL_CLIP_LENGTHS.get(
                        kind, -1.0))) > 0.00001):
                    _fail("clip duration must match Blockbench: " + clip_name)
                    return
                if not bool(director.call("force_start", id, kind)):
                    _fail("could not start " + id + "/" + kind)
                    return
                player.global_position = target.global_position + Vector3(
                    0.0, 0.0, 7.0)
                var prior_time: float = 0.0
                var sampled: int = 0
                for tick in range(80):
                    battle.call("_advance_target_motion", DT)
                    var frame: Dictionary = battle.get("bittaran_attack_frame")
                    if frame.is_empty():
                        break
                    battle.call("_finalize_target_pose", DT)
                    if not bool(frame.get("original_attack_only", false)):
                        _fail("attack escaped original-only mode")
                        return
                    if bool(frame.get("stance_prepare", true)) or bool(
                            frame.get("hit_window", true)) or bool(
                            frame.get("impact", true)):
                        _fail("legacy stance/hitbox/shockwave played")
                        return
                    var t: float = float(frame.get("authored_time", -1.0))
                    if absf(t - (prior_time + DT)) > 0.0001 and (
                            absf(t - duration) > 0.0001):
                        _fail("clip clock was remapped: " +
                            str([clip_name, prior_time, t]))
                        return
                    if absf(float(frame.get("time", -1.0)) - t) > 0.00001:
                        _fail("real and author timeline differ: " + clip_name)
                        return
                    prior_time = t
                    for bone_name in names.keys():
                        if bone_name == "Head":
                            continue
                        var uid: String = str(names[bone_name])
                        var joint: Node3D = bones[uid]
                        var expected: Quaternion = rig.call(
                            "_authored_key_rotation", clip_name,
                            str(bone_name), t)
                        if joint.quaternion.angle_to(expected) > 0.002:
                            _fail("procedural rotation overwrote original " +
                                str([clip_name, t, bone_name]))
                            return
                        if joint.position.distance_to(bind[uid]) > 0.0001:
                            _fail("IK moved an original joint pivot " +
                                str([clip_name, bone_name]))
                            return
                    if absf(float(ik.get("front_attack_drop_world"))) > 0.00001:
                        _fail("old scripted BODY drop still active")
                        return
                    if bool(ik.get("front_return_active")):
                        _fail("old raised return still active")
                        return
                    sampled += 1
                    if t >= duration - 0.00001:
                        break
                if sampled < 12 or absf(prior_time - duration) > 0.00001:
                    _fail("source timeline did not complete: " + clip_name)
                    return
                if repeat == 0:
                    sampled_by_clip[clip_name] = sampled
                elif sampled_by_clip[clip_name] != sampled:
                    _fail("clip timing drifts on repeat: " + clip_name)
                    return
                print("V430_SOURCE_CASE ", clip_name, " repeat=", repeat,
                    " sec=", prior_time, " frames=", sampled)
                tested += 1
                # Release the last authored frame, then run one normal gait
                # update. No scripted return arc or floor capture is allowed.
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
                if bool(ik.get("front_return_active")):
                    _fail("legacy return started after " + clip_name)
                    return
    if tested != 12:
        _fail("not all six original clips repeated twice")
        return
    print("GODOT_V430_ORIGINAL_ONLY_PASS: 6 source clips x 2, full bones, 1x timeline, no IK/offsets/hits")
    quit(0)
