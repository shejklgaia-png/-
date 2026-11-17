extends SceneTree
## v424: imported six L/R attack clips, direct sample, preserved gait, 90-degree head.
const RIG = preload("res://scripts/bittaran_rig.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V424_FRONT_ATTACK_FAIL: " + message)
    quit(1)

func _run() -> void:
    var rig: Node3D = RIG.new()
    root.add_child(rig)
    if not bool(rig.get("loading_ok")):
        _fail("Bittaran source / Android embed did not load")
        return
    if rig.call("bone_names").size() != 14:
        _fail("the established 14 gameplay bones were not retained")
        return
    var clips: Dictionary = rig.get("animations")
    for clip in ["Wait", "Idle", "Turn", "Approach",
            "なぎ払い", "なぎ払い_R", "弾き", "弾き_R",
            "踏みつけ_L", "踏みつけ_R"]:
        if not clips.has(clip):
            _fail("missing animation " + clip)
            return
    for id in ["leg_fl", "leg_fr"]:
        for kind in ["sweep", "kick", "stomp"]:
            var source: String = str(({"sweep": "なぎ払い",
                "kick": "弾き", "stomp": "踏みつけ_L"})[kind])
            if id == "leg_fr":
                source = "踏みつけ_R" if kind == "stomp" else source + "_R"
            var sample_time: float = 0.40
            var frame: Dictionary = {
                "id": id, "kind": kind, "direct_front_test": true,
                "authored_time": sample_time, "time": sample_time,
                "windup": 0.7, "strike": 1.0, "hold": 0.0,
                "recovery": 0.55
            }
            rig.call("apply_pose", "Wait", 0.0)
            rig.call("start_authored_attack", kind, id)
            rig.call("apply_authored_attack_pose", frame)
            for raw in RIG.ATTACK_LEG_BONES[id]:
                var bone_name: String = str(raw)
                var joint: Node3D = rig.find_child(bone_name, true, false)
                var expected: Quaternion = rig.call("_authored_key_rotation",
                    source, bone_name, sample_time)
                if joint == null or joint.quaternion.angle_to(expected) > 0.002:
                    _fail(id + " / " + kind + " missing " + bone_name)
                    return
            rig.call("end_authored_attack")
    rig.call("set_motion", "Turn", 0.25)
    rig.call("set_motion", "Approach", 0.25)
    if str(rig.get("current_clip")) != "Approach":
        _fail("walk and turn clips are not available")
        return
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("battle scene is missing")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var candidates: Dictionary = battle.call("_bittaran_attack_candidates")
    if candidates.has("leg_rl") or candidates.has("leg_rr"):
        _fail("rear-leg attack candidate leaked into test")
        return
    var boss_head: Node3D = battle.get("bittaran_head")
    var player: CharacterBody3D = battle.get("player")
    if boss_head == null or player == null:
        _fail("live player/head not initialized")
        return
    player.global_position = boss_head.global_position + Vector3(20.0, 0.0, 0.0)
    battle.call("_aim_bittaran_head", 1.0)
    var yaw: float = absf(float(battle.get("boss_head_yaw")))
    if yaw < deg_to_rad(80.0) or yaw > PI * 0.5 + 0.0001:
        _fail("90-degree head tracking failed: " + str(yaw))
        return
    # Verify the actual battle path, not just the standalone bone sampler.
    # This is a first-stage visual playback test; the original source
    # trajectory is NOT artificially adjusted to hit SERA or touch ground.
    var boss_rig: Node3D = battle.get("bittaran_rig")
    var brain: RefCounted = battle.get("bittaran_attacks")
    for id in ["leg_fl", "leg_fr"]:
        for kind in ["sweep", "kick", "stomp"]:
            battle.call("_reset_target_after_respawn")
            player.global_position = (battle.get("target") as Node3D).global_position + Vector3(0.0, 0.0, 6.0)
            if not bool(brain.call("force_start", id, kind)):
                _fail("unable to force front-leg attack: " + id + "/" + kind)
                return
            var frame_seen: bool = false
            for tick in range(22):
                battle.call("_advance_target_motion", 0.05)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                if frame.is_empty() or str(frame.get("id", "")) != id or (
                        str(frame.get("kind", "")) != kind) or not bool(
                        frame.get("direct_front_test", false)):
                    _fail("combat did not preserve L/R direct source: " + id + "/" + kind)
                    return
                battle.call("_finalize_target_pose", 0.05)
                if tick == 18:
                    var clip_name: String = (
                        "踏みつけ_L" if kind == "stomp" else (
                        "弾き" if kind == "kick" else "なぎ払い"))
                    if id == "leg_fr":
                        clip_name = ("踏みつけ_R" if kind == "stomp"
                            else clip_name + "_R")
                    var sample: float = float(frame.get("authored_time", 0.0))
                    for raw in RIG.ATTACK_LEG_BONES[id]:
                        var name: String = str(raw)
                        var joint: Node3D = boss_rig.find_child(name, true, false)
                        var expected: Quaternion = boss_rig.call(
                            "_authored_key_rotation", clip_name, name, sample)
                        if joint == null or joint.quaternion.angle_to(expected) > 0.005:
                            _fail("live combat IK overwrote the source: " + id
                                + "/" + kind + "/" + name)
                            return
                    frame_seen = true
            if not frame_seen:
                _fail("actual combat clip was not sampled: " + id + "/" + kind)
                return
    # Aim continuously through full elevation range, without collision braking.
    player.global_position = boss_head.global_position + Vector3(0.0, 20.0, -0.01)
    battle.call("_aim_bittaran_head", 1.0)
    var up: float = float(battle.get("boss_head_pitch"))
    if up < deg_to_rad(80.0) or up > PI * 0.5 + 0.0001:
        _fail("+90-degree vertical head aim failed: " + str(up))
        return
    player.global_position = boss_head.global_position + Vector3(0.0, -20.0, -0.01)
    battle.call("_aim_bittaran_head", 1.0)
    var down: float = float(battle.get("boss_head_pitch"))
    if down > -deg_to_rad(80.0) or down < -PI * 0.5 - 0.0001:
        _fail("-90-degree vertical head aim failed: " + str(down))
        return
    print("GODOT_V424_FRONT_ATTACK_PASS: 6 authored attacks / 14 bones / front only / 90deg")
    quit(0)
