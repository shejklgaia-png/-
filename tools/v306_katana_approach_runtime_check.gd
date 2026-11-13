extends SceneTree
## v306: actual Katana frame-zero crossfade, delayed homing and normal Sword fallback.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V306_KATANA_APPROACH_RUNTIME_FAILED: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("missing training scene")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    if rig == null or player == null or target == null or not bool(rig.get("loading_ok")):
        _fail("player / target / rig not initialized")
        return
    game.set("target_move_enabled", false)
    if not bool(rig.call("set_equipment_selection", "weapon_r", "K")):
        _fail("could not equip Katana")
        return
    player.position = target.position + Vector3(0.0, -1.53, 8.0)
    game.set("combat_state", 0)
    if not bool(game.call("_start_attack")):
        _fail("tap not accepted")
        return
    if int(game.get("combat_state")) != 1:
        _fail("tap did not enter ready phase")
        return
    if str(rig.get("current_clip")) != "Melee_katana":
        _fail("ready phase does not use authored Katana1")
        return
    if not bool(rig.get("freeze_attack_pose")) or absf(float(rig.get("clip_time"))) > 0.00001:
        _fail("Katana frame zero is not held")
        return
    var before: Vector3 = player.position
    var animations: Dictionary = rig.get("animations")
    var tracks: Dictionary = (animations["Melee_katana"] as Dictionary)["tracks"]
    var bones: Dictionary = rig.get("bones")
    var keyed_bone: String = ""
    for uid in tracks.keys():
        var record: Dictionary = tracks[uid]
        if bones.has(uid) and not (record.get("rotation", []) as Array).is_empty():
            keyed_bone = str(uid)
            break
    if keyed_bone.is_empty():
        _fail("no keyed Katana1 pose bones")
        return
    var authored_rotation: Quaternion = rig.call("_rotation_at",
        (tracks[keyed_bone] as Dictionary)["rotation"], 0.0)
    rig.call("_process", 0.10)
    game.call("_advance_attack", 0.0)
    if int(game.get("combat_state")) != 1 or player.position.distance_to(before) > 0.0001:
        _fail("homing started before 0.2s")
        return
    if absf(float(rig.get("blending_for")) - 0.10) > 0.0001:
        _fail("ready blend did not advance halfway")
        return
    if absf(float(rig.get("clip_time"))) > 0.00001:
        _fail("Katana attack started during ready blend")
        return
    rig.call("_process", 0.10)
    if not bool(rig.call("melee_approach_last_key_reached")):
        _fail("ready blend did not complete at 0.2s")
        return
    var rendered_rotation: Quaternion = (bones[keyed_bone] as Node3D).quaternion
    if rendered_rotation.angle_to(authored_rotation) > 0.005:
        _fail("the finished ready pose differs from Katana1 keyframe zero")
        return
    game.call("_advance_attack", 0.0)
    if int(game.get("combat_state")) != 2 or player.position.distance_to(before) > 0.0001:
        _fail("ready phase did not transition to DASH without early movement")
        return
    if str(rig.get("current_clip")) != "Melee_katana" or absf(float(rig.get("clip_time"))) > 0.00001:
        _fail("approach changed or advanced the Katana1 ready pose")
        return
    game.call("_advance_attack", 0.016)
    if player.position.distance_to(before) < 0.001:
        _fail("DASH did not begin moving after 0.2s")
        return
    game.call("_start_strike", 0)
    if str(rig.get("current_clip")) != "Melee_katana" or bool(rig.get("freeze_attack_pose")):
        _fail("Katana1 strike did not unfreeze the same clip")
        return
    rig.call("_process", 0.02)
    if float(rig.get("clip_time")) < 0.019:
        _fail("Katana1 did not resume at time zero")
        return
    rig.call("finish_attack", false)
    game.set("combat_state", 0)
    rig.call("set_equipment_selection", "weapon_r", "A")
    if not bool(game.call("_start_attack")):
        _fail("normal sword tap not accepted")
        return
    if str(rig.get("current_clip")) != "meleeboost" or bool(rig.get("freeze_attack_pose")):
        _fail("normal sword's original approach changed")
        return
    print("GODOT_V306_KATANA_READY_APPROACH_PASS")
    quit(0)
