extends SceneTree
## v370: after stand-up, REAL mesh components must block head penetration
## through Turn and Approach; 1.30x stride, unchanged 0.58s foot cycle.
const AI = preload("res://scripts/bittaran_ai.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
# v375: preserve tracking despite AABB flicker and modest overlap.
const MAX_EXTRA_COMPONENT_OVERLAP: float = 0.22

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V370_BITTARAN_TURN_HEAD_STRIDE_FAIL: " + message)
    quit(1)

func _speed_and_stride(battle: Node3D) -> bool:
    if absf(AI.APPROACH_SPEED_MPS - 0.936) > 0.000001 or absf(
            AI.ACCELERATION_MPS2 - 0.78) > 0.000001:
        _fail("Approach movement/acceleration is not exactly 1.30x")
        return false
    if absf(IK.STEP_DURATION_SECONDS - 0.58) > 0.000001 or absf(
            IK.STEP_COOLDOWN_SECONDS - 0.10) > 0.000001 or absf(
            IK.STEP_HEIGHT_METERS - 0.34) > 0.000001:
        _fail("gait timing or foot lift was changed")
        return false
    if absf(IK.STEP_FORWARD_LEAD_METERS - 0.364) > 0.000001 or absf(
            IK.STEP_APPROACH_TRIGGER_METERS - 0.988) > 0.000001 or absf(
            IK.STEP_TRIGGER_METERS - 0.76) > 0.000001:
        _fail("approach stride is not 1.30x or original turn gait changed")
        return false
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var first: Dictionary = ik.get("legs")[0]
    var resting: Vector3 = ik.call("_home", first, false)
    var walking: Vector3 = ik.call("_home", first, true)
    if absf(resting.distance_to(walking) - 0.364) > 0.0002:
        _fail("landing target does not really include 1.30x forward lead")
        return false
    var brain: RefCounted = AI.new()
    var state: Dictionary = {}
    for tick in range(140):
        state = brain.call("advance", DT,
            Vector3(0.0, 0.0, -50.0), 0.0,
            Vector3(0.0, 0.0, 50.0), false)
    if str(state["motion"]) != "Approach" or absf(
            float(brain.get("current_speed")) - 0.936) > 0.0001:
        _fail("actual approach velocity did not reach 1.30x")
        return false
    return true

func _check_head_clearance(battle: Node3D, label: String) -> bool:
    var parts: Node3D = battle.get("target_parts")
    var neutral: Dictionary = battle.get("head_neutral_component_overlap")
    if neutral.size() != IDS.size():
        _fail(label + ": missing standing component mesh collision baseline")
        return false
    var tip: AABB = (
        parts.call("get_head_swing_aabb") as AABB).grow(0.05)
    for id in IDS:
        var volume: float = 0.0
        for visual in parts.call("get_leg_visual_mesh_boxes", id):
            var piece: AABB = visual
            if piece.has_volume() and tip.intersects(piece):
                volume += tip.intersection(piece).get_volume()
        if volume > float(neutral.get(id, 0.0)) + MAX_EXTRA_COMPONENT_OVERLAP:
            _fail(label + ": head intersects arm " + id
                + " volume=" + str(volume)
                + " bind=" + str(neutral.get(id, 0.0)))
            return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    if not _speed_and_stride(battle):
        return
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    battle.set("locked_target_part_id", "leg_fl")
    var result: Dictionary = battle.call(
        "_apply_target_part_damage", "melee", 1, 240.0, 0.0, 0.0)
    if not bool(result.get("broken", false)):
        _fail("stand-up could not be triggered")
        return
    # Rise fully before testing the formerly unchecked NORMAL Turn gait.
    player.global_position = boss.global_position + Vector3(26.0, 0.0, 0.0)
    var upright: bool = false
    for frame in range(350):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        if bool(ik.call("locomotion_ready")):
            upright = true
            break
    if not upright:
        _fail("boss did not finish stand-up / post-down settle")
        return
    var turn_frames: int = 0
    var approach_frames: int = 0
    var most_yaw: float = 0.0
    for phase in range(2):
        for frame in range(210):
            # Keep Turn requested against the moving chassis, then
            # Approach requested in front without changing clip playback.
            player.global_position = (boss.global_position
                + boss.global_basis.x * 24.0 if phase == 0
                else boss.global_position + boss.global_basis.z * 24.0)
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
            var motion: String = str(battle.get("bittaran_motion"))
            if motion == "Turn":
                turn_frames += 1
            elif motion == "Approach":
                approach_frames += 1
            most_yaw = maxf(most_yaw,
                absf(float(battle.get("boss_head_yaw"))))
            if not _check_head_clearance(battle,
                    motion + " frame=" + str(frame)):
                return
    if turn_frames < 70 or approach_frames < 70:
        _fail("normal post-recovery Turn/Approach were not both exercised: "
            + str([turn_frames, approach_frames]))
        return
    print("GODOT_V370_BITTARAN_TURN_HEAD_STRIDE_PASS: head mesh-clear "
        + "after stand-up for " + str(turn_frames) + " Turn + "
        + str(approach_frames) + " Approach frames, max head yaw="
        + str(rad_to_deg(most_yaw)) + "deg, 1.30x stride at 0.58s swing")
    quit(0)
