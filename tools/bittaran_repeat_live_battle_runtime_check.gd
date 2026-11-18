extends SceneTree
## Actual autonomous Bittaran battle (not force_start): verify that
## source attack -> two diagonal replants -> three NEW walk steps ->
## different next attack -> subsequent attack runs indefinitely.
## Fixed SERA at 6.8m reproduces a sweep-only deadlock if the AI
## orbits forever without deliberately changing the attack radius.
const DT: float = 1.0 / 60.0
const FRAMES: int = 4500

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_REPEAT_LIVE_FAIL: " + message)
    quit(1)

func _run_scenario(start_distance: float, expected_first_kind: String) -> bool:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    battle.set("target_move_enabled", true)
    battle.set("player_hp", 99999.0)
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var director: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if boss == null or player == null or director == null or ik == null:
        _fail("battle dependencies not initialized")
        return false
    boss.rotation.y = 0.0
    player.global_position = boss.global_position + Vector3(0, 0, start_distance)
    var starts: Array[String] = []
    var first_attack_completed: bool = false
    var postattack_replant_seen: bool = false
    var minimum_three_steps_met: bool = false
    var previous_active: bool = false
    var previous_gait: int = 0
    var max_gait: int = 0
    for tick in range(FRAMES):
        battle.set("player_hp", 99999.0)
        var previous_step_gate: int = int(
            battle.get("bittaran_walk_attack_step_gate"))
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        var active: bool = not frame.is_empty()
        if active and not previous_active:
            var kind: String = str(frame.get("kind", ""))
            if starts.is_empty() and not expected_first_kind.is_empty() and (
                    kind != expected_first_kind):
                _fail("unexpected initial attack at " +
                    str(start_distance) + "m: " + kind)
                return false
            if not starts.is_empty() and starts[-1] == kind:
                _fail("repeated same attack kind " + str(starts))
                return false
            var completed: int = int(ik.call("source_completed_walk_steps"))
            var gate: int = previous_step_gate
            if not starts.is_empty() and completed < gate:
                _fail("attack bypassed three new walk steps " +
                    str([completed, gate, starts]))
                return false
            starts.append(kind)
            print("REPEAT_LIVE_ATTACK_START tick=", tick,
                " kind=", kind, " step_count=", completed,
                " history=", starts)
        if previous_active and not active:
            first_attack_completed = true
        if first_attack_completed and bool(
                ik.call("source_postattack_replant_active")):
            postattack_replant_seen = true
        battle.call("_finalize_target_pose", DT)
        previous_active = active
        var walk_steps: int = int(ik.call(
            "source_completed_walk_steps"))
        max_gait = maxi(max_gait, walk_steps)
        if first_attack_completed and walk_steps >= 6:
            minimum_three_steps_met = true
        if tick % 300 == 0:
            print("REPEAT_LIVE_STATE ", tick,
                " attacks=", starts,
                " phase=", str(frame.get("phase", "-")),
                " motion=", battle.get("bittaran_motion"),
                " steps=", walk_steps,
                " gate=", battle.get("bittaran_walk_attack_step_gate"),
                " postactive=", ik.get("source_ik_postattack_active"),
                " posthold=", ik.get("source_ik_postattack_hold"),
                " stepping_pair=", ik.get("source_ik_step_pair"),
                " boss_distance=", boss.global_position.distance_to(
                    player.global_position),
                " blocked_kind=", director.get("last_kind"))
        if starts.size() >= 3 and tick > 2200:
            break
    if starts.size() < 3 or not first_attack_completed or (
            not postattack_replant_seen) or not minimum_three_steps_met:
        _fail("only " + str(starts.size()) + " attacks / " +
            str([starts, first_attack_completed,
                postattack_replant_seen, minimum_three_steps_met,
                max_gait, battle.get("bittaran_motion"),
                ik.get("source_ik_postattack_active"),
                ik.get("source_ik_postattack_hold")]))
        return false
    print("REPEAT_LIVE_SCENARIO_PASS start_distance=",
        start_distance, " attacks=", ",".join(starts),
        " max_gait_steps=", max_gait)
    battle.queue_free()
    return true

func _run() -> void:
    # Both a fixed-range SWEEP encounter and close-range encounter
    # must lead to repeated legal attacks autonomously. In the
    # close-range case, the required first three walk steps can
    # legitimately move the boss from STOMP into KICK range before
    # the first attack, so the starting type is intentionally flexible.
    if not _run_scenario(6.8, "sweep"):
        return
    if not _run_scenario(1.65, ""):
        return
    print("GODOT_BITTARAN_REPEAT_LIVE_PASS stationary_scenarios=2",
        " repeated_attacks=true",
        " three_new_steps_per_cycle=true",
        " postattack_two_pairs=true",
        " same_kind_consecutive=false")
    quit(0)
