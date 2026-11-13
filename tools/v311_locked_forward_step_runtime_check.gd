extends SceneTree
## v311: lock-forward cardinal STEP poses (screen-right input can be front/back).
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V311_LOCKED_STEP_FAILED: " + message)
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
    var camera: Camera3D = game.get("camera")
    if rig == null or player == null or target == null or camera == null             or not bool(rig.get("loading_ok")):
        _fail("actors or animations unavailable")
        return
    game.set("target_move_enabled",false)
    game.set("target_hp",500)
    game.set("auto_lock_enabled",false)
    game.set("manual_part_lock_active",true)
    game.set("locked_target_part_id","")
    game.set("auto_lock_initialized",false)
    var probes: Array[Vector3] = [
        Vector3(0.0,0.0,9.0),  # toward -Z; world right is local right
        Vector3(9.0,0.0,0.0),  # toward -X; world right is local back
        Vector3(-9.0,0.0,0.0), # toward +X; world right is local front
        Vector3(0.0,0.0,-9.0)  # toward +Z; world right is local left
    ]
    var expected_axes: Array[Vector2] = [
        Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT
    ]
    var expected_clips: Array[String] = [
        "Step_R","Backstep","Frontstep","Step_L"
    ]
    var consts: Dictionary=rig.get_script().get_script_constant_map()
    var waist_uid: String=str(consts["RUN_ROOT_BONE_UUID"])
    var bones: Dictionary=rig.get("bones")
    var source: Dictionary=rig.get("animations")
    for i in range(probes.size()):
        player.position=probes[i]
        player.rotation.y=PI*0.72 # stale yaw must not determine STEP pose
        game.set("energy",100.0)
        game.set("energy_exhausted",false)
        game.set("combat_state",0)
        game.call("_place_camera")
        # Fix camera yaw independently of player lock facing to reproduce
        # SCREEN right being FRONT/BACK in actor-relative coordinates.
        camera.global_rotation=Vector3.ZERO
        var world: Vector3=game.call("_screen_drag_to_ground",Vector2.RIGHT)
        if world.distance_to(Vector3.RIGHT)>0.001:
            _fail("camera screen-right is not world-right "+str(i))
            return
        if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
            _fail("right flick failed "+str(i))
            return
        var axis: Vector2=rig.get("directional_step_vector")
        if axis.distance_to(expected_axes[i])>0.025:
            _fail("wrong target-relative axis "+str(i)+": "+str(axis)
                +" expected "+str(expected_axes[i]))
            return
        # Step_R remains the shared timing clip; rendered pose must be the
        # cardinal clip dictated by actual SERA target-facing direction.
        for id in bones.keys():
            var pose: Dictionary=rig.call("_blended_directional_step_pose",str(id),0.0)
            var correct: Dictionary=rig.call(
                "_sample_step_clip_pose",expected_clips[i],str(id),0.0)
            if (pose["rotation"] as Quaternion).angle_to(correct["rotation"])>0.002:
                _fail("rendered pose not "+expected_clips[i]+" at "+str(i))
                return
        var linear: Vector2=game.get("step_linear_offset")
        if linear.distance_to(Vector2(3.0,0.0))>0.001:
            _fail("physical screen-right travel altered at "+str(i)+": "+str(linear))
            return
        game.call("_physics_process",0.016)
        var expected: Vector2=game.call("_step_motion_direction",
            Vector3.RIGHT,Vector2.RIGHT)
        var smoothed: Vector2=rig.get("directional_step_vector")
        if smoothed.dot(expected)<0.995:
            _fail("physics changed locked-facing STEP axis at "+str(i))
            return
        if (game.get("step_linear_offset") as Vector2).distance_to(linear)>0.00001:
            _fail("physics changed committed travel at "+str(i))
            return
        game.call("_finish_side_step",false)

    # Without lock, retain v310's screen cardinal selection even if SERA
    # is standing at the side of the boss.
    player.position=Vector3(9.0,0.0,0.0)
    game.set("manual_part_lock_active",false)
    game.set("auto_lock_enabled",false)
    game.set("auto_lock_initialized",false)
    game.set("locked_target_part_id","")
    game.set("energy",100.0)
    camera.global_rotation=Vector3.ZERO
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("unlocked STEP refused")
        return
    if (rig.get("directional_step_vector") as Vector2).distance_to(Vector2.RIGHT)>0.001:
        _fail("unlocked STEP did not retain screen-right pose")
        return
    game.call("_finish_side_step",false)

    # A selected limb changes the forward axis relative to body center.
    game.set("manual_part_lock_active",true)
    player.position=Vector3(4.0,0.0,5.0)
    game.set("locked_target_part_id","")
    var body_dir: Vector2=game.call("_step_motion_direction",
        Vector3.RIGHT,Vector2.RIGHT)
    game.set("locked_target_part_id","leg_fl")
    var limb_dir: Vector2=game.call("_step_motion_direction",
        Vector3.RIGHT,Vector2.RIGHT)
    var facing: Vector3=game.call("_locked_target_facing_direction")
    var normalized_facing: Vector3=facing.normalized()
    var expected_limb: Vector2=Vector2(
        Vector3.RIGHT.dot(normalized_facing.cross(Vector3.UP)),
        -Vector3.RIGHT.dot(normalized_facing)).normalized()
    if limb_dir.distance_to(expected_limb)>0.0001:
        _fail("selected limb did not define SERA's forward")
        return
    if limb_dir.distance_to(body_dir)<0.0001:
        _fail("part switch did not change pose basis")
        return
    print("GODOT_V311_LOCKED_FORWARD_STEP_PASS")
    quit(0)
