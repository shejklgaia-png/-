extends SceneTree
## v310: reproduce right-flick visually becoming Frontstep when actor looks sideways.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V310_RIGHT_STEP_FAILED: " + message)
    quit(1)

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
        _fail("game actors or source clip missing")
        return
    game.set("target_move_enabled", false)
    game.set("target_hp", 500)
    game.set("auto_lock_enabled", false)
    game.set("manual_part_lock_active", true)
    game.set("locked_target_part_id", "head")
    game.set("camera_yaw", 0.0)
    var consts: Dictionary = rig.get_script().get_script_constant_map()
    var waist_uid: String = str(consts["RUN_ROOT_BONE_UUID"])
    var authored: Dictionary = rig.call("_sample_step_clip_pose", "Step_R", waist_uid, 0.0)
    var raw_q: Quaternion = authored["rotation"]
    var raw_front: Vector3 = raw_q * Vector3.FORWARD
    if absf(rad_to_deg(atan2(-raw_front.x, -raw_front.z))) < 35.0:
        _fail("9.2.2 sideways Waist authored yaw is missing")
        return

    var version: int = int(str(ProjectSettings.get_setting(
        "application/config/name")).trim_prefix("SERA v"))
    var probes: Array[Vector3] = [
        Vector3(0,0,9), Vector3(6,0,9), Vector3(-6,0,9), Vector3(6,0,3)
    ]
    for i in range(probes.size()):
        player.position = probes[i]
        player.rotation.y = PI * 0.72
        game.set("combat_state", 0)
        game.set("energy", 100.0)
        game.set("energy_exhausted", false)
        game.call("_place_camera")
        var travel: Vector3 = game.call("_screen_drag_to_ground", Vector2.RIGHT)
        if travel.length_squared() < 0.01:
            _fail("invalid camera world-right at probe " + str(i))
            return
        if not bool(game.call("_start_omni_step", Vector2.RIGHT)):
            _fail("right flick refused at probe " + str(i))
            return
        if str(rig.get("current_clip")) != "Step_R":
            _fail("RIGHT screen flick selected a different clip")
            return
        var direction: Vector2 = rig.get("directional_step_vector")
        var expected_pose: Vector2 = Vector2.RIGHT if version == 310 else (
            game.call("_step_motion_direction",travel,Vector2.RIGHT))
        if direction.distance_to(expected_pose) > 0.001:
            _fail("RIGHT flick selected wrong pose at probe " + str(i)
                + " got " + str(direction) + " expected " + str(expected_pose))
            return
        var planned: Vector2 = game.get("step_linear_offset")
        var expected: Vector2 = Vector2(travel.x,travel.z).normalized() * 3.0
        if planned.distance_to(expected) > 0.001:
            _fail("STEP world travel changed: " + str(planned) + ", expected " + str(expected))
            return
        rig.set("blending_for",0.12)
        rig.call("_apply_animation",0.0)
        var bones: Dictionary=rig.get("bones")
        var displayed: Node3D=bones[waist_uid]
        if direction.distance_to(Vector2.RIGHT)<0.001                 and displayed.quaternion.angle_to(raw_q)>0.001:
            _fail("RIGHT clip's sideways Waist yaw was canceled at probe " + str(i))
            return
        # A physics tick must not convert screen-right back into actor-front.
        game.call("_physics_process",0.016)
        direction=rig.get("directional_step_vector")
        var post_pose: Vector2 = Vector2.RIGHT if version == 310 else (
            game.call("_step_motion_direction",Vector3(planned.x,0.0,planned.y),
                Vector2.RIGHT))
        if direction.dot(post_pose)<0.995:
            _fail("STEP pose no longer tracks selected basis " + str(i))
            return
        rig.set("blending_for",0.12)
        rig.call("_apply_animation",0.0)
        if direction.distance_to(Vector2.RIGHT)<0.001                 and displayed.quaternion.angle_to(raw_q)>0.001:
            _fail("RIGHT pose lost authored Waist rotation after physics tick " + str(i))
            return
        var actor_forward: Vector3 = -player.global_transform.basis.z
        actor_forward.y=0.0
        var desired: Vector3=game.call("_locked_target_facing_direction")
        desired.y=0.0
        if actor_forward.normalized().dot(desired.normalized())<0.99:
            _fail("physical lock facing was changed by the pose fix " + str(i))
            return
        if (game.get("step_linear_offset") as Vector2).distance_to(planned)>0.00001:
            _fail("committed 3m travel changed while turning " + str(i))
            return
        game.call("_finish_side_step",false)

    # Opposite cardinals keep their own pose; only right uses authored yaw.
    for direction in [Vector2.UP,Vector2.LEFT,Vector2.DOWN]:
        rig.call("start_omni_step", direction)
        rig.set("blending_for",0.12)
        rig.call("_apply_animation",0.0)
        var root_bone: Node3D=(rig.get("bones") as Dictionary)[waist_uid]
        var front: Vector3=root_bone.quaternion*Vector3.FORWARD
        var flat: Vector2=Vector2(front.x,front.z)
        if flat.length_squared()<0.01 or flat.normalized().dot(Vector2.UP)<0.998:
            _fail("other cardinal STEP lost previous boss-facing waist correction: "
                + str(direction))
            return
        rig.call("finish_side_step", false, false)
    # Right/front and right/back halfway angles should preserve 50% right yaw;
    # no hard switch at 45 degrees or near the cardinal endpoints.
    rig.call("start_omni_step", Vector2.RIGHT)
    for item in [
        [Vector2.RIGHT,1.0],[Vector2.UP,0.0],[Vector2.LEFT,0.0],
        [Vector2.DOWN,0.0],[Vector2(1,-1).normalized(),0.5],
        [Vector2(1,1).normalized(),0.5]
    ]:
        rig.set("directional_step_vector",item[0])
        var result: float=rig.call("_step_right_authored_yaw_weight")
        if absf(result-float(item[1]))>0.0001:
            _fail("diagonal right-yaw continuity weight incorrect: " + str(item))
            return
    print("GODOT_V310_SCREEN_RIGHT_AND_AUTHORED_WAIST_PASS")
    quit(0)
