extends SceneTree
## v292 - real rig orientation after authored RUN / STEP, plus stable auto lock.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V292_VISUAL_LOCK_FAILED: " + reason)
    quit(1)


func _flat_yaw(q: Quaternion) -> float:
    var f: Vector3 = q * Vector3.FORWARD
    return atan2(-f.x, -f.z)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main scene unavailable")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    var camera: Camera3D = game.get("camera")
    var parts: Node3D = game.get("target_parts")
    if rig == null or player == null or target == null or camera == null or parts == null:
        _fail("missing main combat nodes")
        return
    if not bool(rig.get("loading_ok")):
        _fail("rig has no authored animation")
        return
    var consts: Dictionary = rig.get_script().get_script_constant_map()
    var waist_id: String = str(consts["RUN_ROOT_BONE_UUID"])
    var bones: Dictionary = rig.get("bones")
    if not bones.has(waist_id):
        _fail("authoring Waist joint missing")
        return

    # Step_R authored Waist y=-70deg looks like a side-on body, even
    # though CharacterBody3D.look_at() was already facing the enemy.
    var step: Dictionary = rig.call("_sample_step_clip_pose","Step_R",waist_id,0.0)
    var raw_step: Quaternion = step["rotation"]
    if absf(_flat_yaw(raw_step)) < deg_to_rad(35.0):
        _fail("v292 regression setup lost the original sideways Step_R yaw")
        return
    var corrected: Quaternion = rig.call("_face_locked_boss_with_waist",raw_step,1.0)
    if absf(_flat_yaw(corrected)) > deg_to_rad(0.2):
        _fail("locomotion waist no longer aims the same forward as boss-facing player")
        return
    # Entry blend must preserve the prior pose to avoid snapping at STEP start.
    var entry: Quaternion = rig.call("_face_locked_boss_with_waist",raw_step,0.0)
    if entry.angle_to(raw_step)>0.0001:
        _fail("lock yaw was snapped before entry crossfade")
        return

    var run_pose: Dictionary = rig.call("_blended_run_pose",waist_id,0.0)
    corrected=rig.call("_face_locked_boss_with_waist",run_pose["rotation"],1.0)
    if absf(_flat_yaw(corrected))>deg_to_rad(0.2):
        _fail("RUN still twists player sideways after world target lock")
        return

    target.position = Vector3(0.0,1.53,-8.0)
    player.position = Vector3(3.0,0.0,0.0)
    game.set("direction_input",Vector2.ZERO)
    game.set("gesture_active",false)
    game.set("target_hp",500)
    game.set("combat_state",0)
    game.call("_physics_process",0.016)
    var actual_forward: Vector3 = -player.global_transform.basis.z
    actual_forward.y=0.0
    var expected: Vector3 = target.global_position-player.global_position
    expected.y=0.0
    if actual_forward.normalized().dot(expected.normalized()) < 0.999:
        _fail("SERA collision root no longer points toward whole boss")
        return

    # The camera still chooses healthy parts. An empty lock is obtained
    # immediately; a valid lock is not replaced by a one-frame change.
    camera.global_position = Vector3(2.0,4.5,13.0)
    var aim_head: Vector3 = parts.call("get_part_aim_world","head")
    camera.look_at(aim_head,Vector3.UP)
    var preferred: String = str(parts.call("select_camera_orbit_part",camera))
    if preferred.is_empty():
        _fail("camera cannot acquire a boss part")
        return
    game.set("locked_target_part_id","")
    game.call("_acquire_stable_camera_part",0.016,false)
    if str(game.get("locked_target_part_id")) != preferred:
        _fail("first AUTO lock unnecessarily waits for switch hysteresis")
        return
    var other: String = "leg_rr" if preferred != "leg_rr" else "leg_fl"
    game.set("locked_target_part_id",other)
    game.set("auto_lock_pending_part","")
    game.set("auto_lock_pending_elapsed",0.0)
    var current_preferred: String = str(parts.call("select_camera_orbit_part",camera))
    if current_preferred != other:
        game.call("_acquire_stable_camera_part",0.016,false)
        if str(game.get("locked_target_part_id")) != other:
            _fail("AUTO lock jumped to a limb in one physics frame")
            return
        game.call("_acquire_stable_camera_part",0.25,false)
        if str(game.get("locked_target_part_id")) != current_preferred:
            _fail("AUTO refused a sustained better camera-center part")
            return
    print("GODOT_V292_VISUAL_LOCK_PASS: fixed SERA yaw, stable part selection and unchanged authored attack clips")
    quit(0)
