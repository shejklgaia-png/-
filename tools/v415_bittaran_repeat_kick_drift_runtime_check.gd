extends SceneTree
## v415: repeated real attacks at a fixed player bearing may not
## accumulate any local twist in the active limb, for ANY of four legs.
const DT: float = 1.0 / 60.0
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const REPEAT: int = 6
const MAX_REPEAT_LOCAL_ANGLE_DEGREES: float = 3.0
const MAX_REPEAT_FOOT_ANGLE_DEGREES: float = 4.0
const CLIP_SAMPLES: Array[float] = [0.12, 0.40, 0.75]


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V415_BITTARAN_KICK_REPEAT_FAIL: " + reason)
    quit(1)


func _tick(battle: Node3D) -> void:
    battle.set("player_hp", 9999.0)
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    if rig == null or brain == null or ik == null or boss == null             or player == null:
        _fail("missing real battle components")
        return
    for id in LEG_IDS:
        battle.call("_reset_target_after_respawn")
        battle.set("target_move_enabled", true)
        var side: float = -1.0 if id.ends_with("l") else 1.0
        var z: float = 6.0 if id.begins_with("leg_r") else -6.0
        player.global_position = boss.global_position + Vector3(
            1.5 * side, 0.0, z)
        var names: Array = rig.ATTACK_LEG_BONES[id]
        var chain: Array[Node3D] = []
        for name in names:
            var node: Node3D = rig.find_child(str(name), true, false)
            if node == null:
                _fail(id + " missing joint " + str(name))
                return
            chain.append(node)
        var baseline: Dictionary = {}
        var baseline_sole: Vector3 = Vector3.INF
        var ix: int = ik.LEG_PART_IDS.find(id)
        for rep in range(REPEAT):
            if not bool(brain.call("force_start_with_stance", id, "kick")):
                _fail(id + " unable to start repeat " + str(rep))
                return
            var seen: Dictionary = {}
            var ended: bool = false
            var active_seen: bool = false
            for tick in range(440):
                _tick(battle)
                var frame: Dictionary = battle.get(
                    "bittaran_attack_frame")
                if frame.is_empty():
                    if active_seen and not bool(brain.call("is_active")):
                        ended = true
                        break
                    continue
                var phase: String = str(frame.get("phase", ""))
                if phase == "stance":
                    continue
                active_seen = true
                var t: float = float(frame.get("authored_time", -100.0))
                if phase != "strike" and phase != "hold":
                    continue
                for clip_t in CLIP_SAMPLES:
                    var key: String = str(clip_t)
                    if seen.has(key) or absf(t - clip_t) > DT * 0.55:
                        continue
                    seen[key] = true
                    var value: Array = []
                    for joint in chain:
                        value.append(joint.quaternion)
                    value.append(chain[2].global_basis
                        .get_rotation_quaternion())
                    value.append(chain[1].global_position
                        - chain[0].global_position)
                    if rep == 0:
                        baseline[key] = value
                    else:
                        var reference: Array = baseline.get(key, [])
                        if reference.is_empty():
                            _fail(id + " no first sample at " + key)
                            return
                        for i in range(4):
                            var err: float = rad_to_deg((
                                value[i] as Quaternion).angle_to(
                                reference[i] as Quaternion))
                            var limit: float = (
                                MAX_REPEAT_FOOT_ANGLE_DEGREES
                                if i == 3 else MAX_REPEAT_LOCAL_ANGLE_DEGREES)
                            if err > limit:
                                _fail(id + " repeat=" + str(rep)
                                    + " source_t=" + key
                                    + " bone=" + str(i)
                                    + " drift=" + str(err) + " degrees")
                                return
            if not ended or seen.size() != CLIP_SAMPLES.size():
                _fail(id + " repeat=" + str(rep)
                    + " incomplete kick / source samples=" + str(seen))
                return
            var state: Dictionary = ik.get("legs")[ix]
            if state.has("sole_local_saved") or state.has(
                    "sole_local_traj") or state.has("authored_pole_point"):
                _fail(id + " stale sole/pole state at repeat "
                    + str(rep))
                return
            if baseline_sole == Vector3.INF:
                baseline_sole = state["sole_local"]
            elif (state["sole_local"] as Vector3).distance_to(
                    baseline_sole) > 0.0001:
                _fail(id + " contact sample drifted at repeat "
                    + str(rep))
                return
    print("GODOT_V415_BITTARAN_KICK_REPEAT_PASS: "
        + "4 legs x 6 consecutive real kick attacks")
    quit(0)
