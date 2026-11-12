extends SceneTree
## v295: use the ACTUAL reconstructed Blockbench rig and locomotion API.

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V295_RUN_RECOVERY_FAILED: " + reason)
    quit(1)


func _flat_yaw(q: Quaternion) -> float:
    var forward: Vector3 = q * Vector3.FORWARD
    return atan2(-forward.x, -forward.z)


func _check_run(rig: Node3D, waist: Node3D, direction: Vector2,
        expected_degrees: float, label: String, expect_retreat: bool) -> bool:
    rig.call("set_moving", false, false)
    rig.call("_process", 0.025)
    rig.call("set_moving", true, false, direction, false)
    rig.call("_process", 0.24)
    if str(rig.get("current_clip")) != "run_front_original":
        _fail(label + ": normal RUN clip not selected")
        return false
    if bool(rig.get("run_retreat_mode")) != expect_retreat:
        _fail(label + ": wrong forward/backpedal gait")
        return false
    var angle: float = rad_to_deg(_flat_yaw(waist.quaternion))
    var difference: float = absf(wrapf(angle - expected_degrees, -180.0, 180.0))
    if difference > 35.0:
        _fail("%s: visual Waist yaw %.1f, expected travel yaw %.1f" % [
            label, angle, expected_degrees])
        return false
    return true


func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    if scene == null:
        _fail("main combat scene missing")
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    var rig: Node3D = game.get("rig")
    var player: CharacterBody3D = game.get("player")
    var target: Node3D = game.get("target")
    if rig == null or player == null or target == null or not bool(rig.get("loading_ok")):
        _fail("game, player, target or rig initialization failed")
        return
    var bones: Dictionary = rig.get("bones")
    var waist_id: String = "67435cb7-b6af-23e4-10f1-3cd13d8429fa"
    if not bones.has(waist_id):
        _fail("authored Waist pivot missing")
        return
    var waist: Node3D = bones[waist_id]

    for sample in [
        {"label": "forward", "dir": Vector2.UP * -1.0, "yaw": 0.0, "back": false},
        {"label": "screen/local right", "dir": Vector2.RIGHT, "yaw": -90.0, "back": false},
        {"label": "screen/local left", "dir": Vector2.LEFT, "yaw": 90.0, "back": false},
        {"label": "rearward", "dir": Vector2.DOWN * -1.0, "yaw": 0.0, "back": true},
        {"label": "front-right diagonal", "dir": Vector2(1.0, 1.0), "yaw": -45.0, "back": false},
        {"label": "rear-right diagonal", "dir": Vector2(1.0, -1.0), "yaw": 45.0, "back": true},
        {"label": "rear-left diagonal", "dir": Vector2(-1.0, -1.0), "yaw": -45.0, "back": true},
    ]:
        var direction: Vector2 = sample["dir"]
        if not _check_run(rig, waist, direction, sample["yaw"], sample["label"], sample["back"]):
            return

    # Critically, a move -> melee -> move transition may happen without a
    # rendered non-RUN frame. The old cached RUN heading must be invalidated
    # at clip switch, not at the next _process() callback.
    rig.call("set_moving", true, false, Vector2.RIGHT, false)
    rig.call("_process", 0.20)
    rig.call("start_melee_approach")
    if bool(rig.get("run_motion_initialized")):
        _fail("melee entry retained stale RUN heading")
        return
    rig.call("start_strike", "melee1")
    rig.call("_process", 0.12)
    rig.call("finish_attack", true, false)
    rig.call("set_moving", true, false, Vector2.LEFT, false)
    rig.call("_process", 0.24)
    var fresh_yaw: float = rad_to_deg(_flat_yaw(waist.quaternion))
    if absf(wrapf(fresh_yaw - 90.0, -180.0, 180.0)) > 35.0:
        _fail("leftward run still uses pre-melee rightward pose: " + str(fresh_yaw))
        return
    if not bool(rig.get("run_motion_initialized")):
        _fail("RUN cache was not reacquired after melee")
        return

    # Katana's newly authored two strikes and the ordinary three-hit chain
    # share this restoration path. Existing original clips must remain playable.
    for clip_name in ["Melee2", "Melee3", "Melee_katana", "Melee_katana2", "Bash"]:
        if clip_name == "Bash":
            rig.call("start_bash")
        else:
            rig.call("start_strike", clip_name)
        rig.call("_process", 0.10)
        if bool(rig.get("run_motion_initialized")):
            _fail(clip_name + " did not clear previous RUN direction")
            return
        rig.call("finish_attack", true, false)
        rig.call("set_moving", true, false, Vector2.RIGHT, false)
        rig.call("_process", 0.24)
        var heading: float = rad_to_deg(_flat_yaw(waist.quaternion))
        if absf(wrapf(heading + 90.0, -180.0, 180.0)) > 35.0:
            _fail(clip_name + " left RUN yaw broken: " + str(heading))
            return

    # Character collision stays target-facing, even when the visible RUN
    # Waist/legs take a 90 degree right or left sidestep.
    player.position = Vector3(3.0, 0.0, 0.0)
    target.position = Vector3(0.0, 1.53, -8.0)
    game.set("direction_input", Vector2.ZERO)
    game.set("gesture_active", false)
    game.call("_physics_process", 0.016)
    var actual: Vector3 = -player.global_transform.basis.z
    actual.y = 0.0
    var wanted: Vector3 = target.global_position - player.global_position
    wanted.y = 0.0
    if actual.normalized().dot(wanted.normalized()) < 0.999:
        _fail("target-facing collision root changed with visual RUN yaw")
        return

    # v292 STEP/BOOST still retain their earlier boss lock correction.
    var step_pose: Dictionary = rig.call("_sample_step_clip_pose",
        "Step_R", waist_id, 0.0)
    var corrected: Quaternion = rig.call("_face_locked_boss_with_waist",
        step_pose["rotation"], 1.0)
    if absf(_flat_yaw(corrected)) > deg_to_rad(0.2):
        _fail("STEP boss-facing correction regressed")
        return

    print("GODOT_V295_RUN_RECOVERY_PASS: 7 directions, melee and Katana/Bash recovery, boss lock and STEP")
    quit(0)
