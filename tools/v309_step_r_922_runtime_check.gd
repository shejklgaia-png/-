extends SceneTree
## v309: check the user's 9.2.2 Step_R inside real Godot animation playback.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V309_STEP_R_922_FAILED: " + reason)
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
        _fail("game actors or animation source missing")
        return
    var consts: Dictionary = rig.get_script().get_script_constant_map()
    var waist_id: String = str(consts["RUN_ROOT_BONE_UUID"])
    var head_id: String = str(consts["RUN_HEAD_BONE_UUID"])
    var animations: Dictionary = rig.get("animations")
    if not animations.has("Step_R"):
        _fail("Step_R is not present in runtime animation dictionary")
        return
    var tracks: Dictionary = animations["Step_R"]["tracks"]
    for id in [waist_id,head_id]:
        if not tracks.has(id) or (tracks[id]["rotation"] as Array).is_empty():
            _fail("Step_R is missing authored rotation for joint " + id)
            return
    var waist: Dictionary = rig.call("_sample_step_clip_pose","Step_R",waist_id,0.0)
    var head: Dictionary = rig.call("_sample_step_clip_pose","Step_R",head_id,0.0)
    var desired_waist: Quaternion = rig.call("_blockbench_rotation",
        Vector3(-42.5,-70.0,0.0))
    var desired_head: Quaternion = rig.call("_blockbench_rotation",
        Vector3(35.3614,71.1021,40.2028))
    if (waist["rotation"] as Quaternion).angle_to(desired_waist)>0.001:
        _fail("waist does not use 9.2.2 keyframe 0")
        return
    if (head["rotation"] as Quaternion).angle_to(desired_head)>0.001:
        _fail("head does not use 9.2.2 keyframe 0")
        return
    player.position=Vector3(0.0,0.0,9.0)
    game.set("target_move_enabled",false)
    game.set("target_hp",500)
    game.set("auto_lock_enabled",false)
    game.set("manual_part_lock_active",true)
    game.set("locked_target_part_id","head")
    game.set("camera_yaw",0.0)
    game.call("_place_camera")
    game.set("energy",100.0)
    if not bool(game.call("_start_omni_step",Vector2.RIGHT)):
        _fail("right flick did not start STEP")
        return
    if str(rig.get("current_clip"))!="Step_R":
        _fail("right flick selected a different clip")
        return
    if (rig.get("directional_step_vector") as Vector2).distance_to(Vector2.RIGHT)>0.001:
        _fail("right flick did not select the pure right pose")
        return
    var bones: Dictionary=rig.get("bones")
    for raw_id in bones.keys():
        var id: String=str(raw_id)
        var right_pose: Dictionary=rig.call("_blended_directional_step_pose",id,0.0)
        var authored_pose: Dictionary=rig.call("_sample_step_clip_pose","Step_R",id,0.0)
        if (right_pose["rotation"] as Quaternion).angle_to(authored_pose["rotation"])>0.001:
            _fail("right step blend changed authored joint " + id)
            return
        if (right_pose["position"] as Vector3).distance_to(authored_pose["position"])>0.00001:
            _fail("right step blend changed joint position " + id)
            return
    if absf(float(game.get("step_arc_length"))-3.0)>0.0001:
        _fail("right step distance no longer 3m")
        return
    rig.set("blending_for",0.12)
    rig.call("_apply_animation",0.0)
    var waist_bone: Node3D=bones[waist_id]
    var facing: Vector3=waist_bone.quaternion*Vector3.FORWARD
    if Vector2(facing.x,facing.z).normalized().dot(Vector2(0,-1))<0.995:
        _fail("right step runtime pose lost lock facing")
        return
    game.call("_finish_side_step",false)
    print("GODOT_V309_922_STEP_R_SOURCE_PLAYBACK_PASS")
    quit(0)
