extends SceneTree
## v307: 4 authored cardinal STEP poses and rightward input with stale player yaw.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V307_STEP_POSE_FAILED: " + message)
    quit(1)

func _check_vec(actual: Vector2, expected: Vector2, tag: String) -> bool:
    if actual.distance_to(expected) > 0.001:
        _fail(tag + ": actual " + str(actual) + " expected " + str(expected))
        return false
    return true

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("training scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    if rig == null or player == null or target == null or not bool(rig.get("loading_ok")):
        _fail("combat actors or animation data unavailable")
        return
    game.set("target_move_enabled", false)
    game.set("target_hp", 500)
    game.set("manual_part_lock_active", true)
    game.set("auto_lock_enabled", false)
    game.set("locked_target_part_id", "head")
    game.set("camera_yaw", 0.0)
    game.call("_place_camera")
    var axes: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
        Vector2(1,-1).normalized(),Vector2(-1,-1).normalized(),
        Vector2(1,1).normalized(),Vector2(-1,1).normalized()]
    var clips: Array[String] = ["Step_R", "Step_L", "Frontstep", "Backstep"]
    var cards: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
    var animations: Dictionary = rig.get("animations")
    var bones: Dictionary = rig.get("bones")
    for clip_name in clips:
        if not animations.has(clip_name):
            _fail("missing authored motion " + clip_name)
            return
        var tracks: Dictionary = (animations[clip_name] as Dictionary)["tracks"]
        var count: int = 0
        for id in tracks.keys():
            if bones.has(id) and not (tracks[id].get("rotation", []) as Array).is_empty():
                count += 1
        if count < 12:
            _fail("incomplete source clip " + clip_name)
            return
    for i in range(axes.size()):
        # Reproduce a touch arriving immediately after lock acquisition but
        # BEFORE the player yaw has caught up. Previously screen RIGHT selected
        # the LEFT pose because it sampled the stale collision-root rotation.
        player.position = Vector3(0.0,0.0,9.0)
        player.rotation.y = PI
        game.set("energy", 100.0)
        game.set("energy_exhausted", false)
        game.set("combat_state", 0)
        var target_face: Vector3 = game.call("_locked_target_facing_direction")
        target_face = target_face.normalized()
        var world: Vector3 = game.call("_screen_drag_to_ground", axes[i])
        if world.length_squared() < 0.000001:
            _fail("invalid screen STEP vector")
            return
        var expected: Vector2 = Vector2(
            world.normalized().dot(target_face.cross(Vector3.UP)),
            -world.normalized().dot(target_face)).normalized()
        if not bool(game.call("_start_omni_step", axes[i])):
            _fail("step refused at angle " + str(i))
            return
        var actual: Vector2 = rig.get("directional_step_vector")
        if not _check_vec(actual, expected, "lock-aligned start " + str(i)):
            return
        if i == 0 and actual.x < 0.99:
            _fail("RIGHT step did not use authored Step_R")
            return
        if i < 4:
            if not _check_vec(actual, cards[i], "cardinal input " + str(i)):
                return
            # Pure cardinal direction must sample its OWN real source clip,
            # not the Step_R clock or a mirrored/reconstructed pose.
            for raw_id in bones.keys():
                var uid: String = str(raw_id)
                var blend: Dictionary = rig.call("_blended_directional_step_pose", uid, 0.0)
                var source: Dictionary = rig.call("_sample_step_clip_pose", clips[i], uid, 0.0)
                if (blend["rotation"] as Quaternion).angle_to(source["rotation"]) > 0.001:
                    _fail(clips[i] + " rotation differs from source on " + uid)
                    return
                if (blend["position"] as Vector3).distance_to(source["position"]) > 0.00001:
                    _fail(clips[i] + " position differs from source on " + uid)
                    return
            rig.set("blending_for", 0.12)
            rig.call("_apply_animation", 0.0)
            # Source Waist pivot UUID shared by all locomotion clips.
            var waist_uid: String = "67435cb7-b6af-23e4-10f1-3cd13d8429fa"
            var root_bone: Node3D = bones[waist_uid]
            var front: Vector3 = root_bone.quaternion * Vector3.FORWARD
            var flat: Vector2 = Vector2(front.x,front.z)
            if flat.length_squared() < 0.5 or flat.normalized().dot(Vector2(0,-1)) < 0.998:
                _fail(clips[i] + " torso root is no longer boss-facing")
                return
        game.call("_finish_side_step", false)
    # Motion remains screen-directed even when SERA turns toward another
    # locked part after STEP starts; only the displayed local pose updates.
    player.position = Vector3(0.0,0.0,9.0)
    player.rotation.y = PI
    game.set("energy", 100.0)
    if not bool(game.call("_start_omni_step", Vector2.RIGHT)):
        _fail("right STEP restart refused")
        return
    var travel: Vector2 = game.get("step_linear_offset")
    player.position.x = 2.0
    game.call("_physics_process", 0.016)
    if (game.get("step_linear_offset") as Vector2).distance_to(travel) > 0.00001:
        _fail("lock-following changed committed screen STEP travel")
        return
    if (rig.get("directional_step_vector") as Vector2).x < 0.0:
        _fail("right step pose flipped to left during lock turn")
        return
    print("GODOT_V307_CARDINAL_AND_RIGHT_STEP_POSE_PASS")
    quit(0)
