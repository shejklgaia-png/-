extends SceneTree
## v409 regression check, from device feedback on v408: the attack
## guidance rotated the body too far (weird twisting), front legs
## attacked to behind the rear legs, and rear-leg aims twisted the
## body grotesquely because the chest tracking pointed its front
## diagonal at the player. The guidance now turns the attacking
## leg's hip corner toward the player with natural caps: chest yaw
## <= 60 degrees, shoulder aim <= 85 (KICK) / 75 (SWEEP) degrees.
## Part A asserts those caps hold for every leg and kind with the
## player anywhere around the boss. Part B asserts the chest
## actually ends up turning the hip corner at the player in the
## natural geometries (front leg: player ahead, boss facing them;
## rear leg: player dead behind, boss facing away). Part C asserts
## a front leg KICK aimed at a player behind no longer lands its
## foot far behind the rear hip line (local z ~ -1.24; the old
## build reached -2.30). Part D asserts the caps did not break
## reach in the natural geometries (foot still gets to the
## player). Pre-fix values: chest up to 125 degrees (STOMP),
## aim up to 130, rear-leg chest 70 with ~63-127 degrees of
## chassis twist, front foot to local z -2.30.
const DT: float = 1.0 / 60.0
const LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const CORNERS: Dictionary = {
    "leg_fl": 34.4, "leg_fr": -33.8,
    "leg_rl": 145.8, "leg_rr": -146.0,
}
const MAX_BODY_DEGREES: float = 60.5
const MAX_AIM_KICK_DEGREES: float = 85.5
const MAX_AIM_SWEEP_DEGREES: float = 75.5
const MIN_FRONT_FOOT_LZ: float = -1.85
const MAX_NATURAL_DISTANCE: float = 2.2

var failures: Array[String] = []

func _fail(message: String) -> void:
    failures.append(message)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik = battle.get("bittaran_foot_ik")
    var rig = battle.get("bittaran_rig")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var brain = battle.get("bittaran_attacks")
    var part_ids: Array = ik.get("LEG_PART_IDS")

    # ---- Part A + C: fixed facing, player on a circle.
    var plans: Array = []
    for kind in ["kick", "sweep"]:
        for ang in [0.0, 90.0, 180.0, 270.0]:
            plans.append([kind, ang])
    for ang in [0.0, 180.0]:
        plans.append(["stomp", ang])
    for plan in plans:
        var kind: String = plan[0]
        var ang: float = plan[1]
        var rad: float = deg_to_rad(ang)
        for leg_id in LEGS:
            boss.global_position = Vector3.ZERO
            boss.rotation = Vector3.ZERO
            player.global_position = Vector3(
                sin(rad), 0.0, cos(rad)) * 5.0
            for frame in range(30):
                battle.set("player_hp", 9999.0)
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
            boss.rotation = Vector3.ZERO
            player.global_position = Vector3(
                sin(rad), 0.0, cos(rad)) * 5.0
            brain.call("force_start_with_stance", leg_id, kind)
            var leg: Dictionary = ik.get("legs")[part_ids.find(leg_id)]
            var foot: Node3D = leg["foot"]
            var started: bool = false
            var peak_body: float = 0.0
            var peak_aim: float = 0.0
            var min_lz: float = 1e9
            for frame in range(60 * 9):
                battle.set("player_hp", 9999.0)
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
                var f: Dictionary = battle.get("bittaran_attack_frame")
                if f.is_empty():
                    if started:
                        break
                    continue
                started = true
                peak_body = maxf(peak_body, absf(rad_to_deg(
                    float(battle.get("bittaran_attack_body_yaw")))))
                peak_aim = maxf(peak_aim, absf(rad_to_deg(
                    float(rig.get("attack_leg_aim_yaw")))))
                var phase: String = str(f.get("phase", ""))
                if phase == "strike" or phase == "hold":
                    min_lz = minf(min_lz,
                        boss.to_local(foot.global_position).z)
            var tag: String = "%s %s ang=%.0f" % [leg_id, kind, ang]
            if peak_body > MAX_BODY_DEGREES:
                _fail(tag + ": chest yaw peaked %.1f deg (cap 60)"
                    % peak_body)
            if kind == "kick" and peak_aim > MAX_AIM_KICK_DEGREES:
                _fail(tag + ": aim yaw peaked %.1f deg (cap 85)"
                    % peak_aim)
            if kind == "sweep" and peak_aim > MAX_AIM_SWEEP_DEGREES:
                _fail(tag + ": aim yaw peaked %.1f deg (cap 75)"
                    % peak_aim)
            if (kind == "kick" and ang == 180.0
                    and not leg_id.begins_with("leg_r")
                    and min_lz < MIN_FRONT_FOOT_LZ):
                _fail(tag + ": front foot reached local z %.2f, "
                    % min_lz + "behind the rear hip line")

    # ---- Part B + D: natural geometries, corner tracking + reach.
    for leg_id in LEGS:
        var rear: bool = leg_id.begins_with("leg_r")
        boss.global_position = Vector3.ZERO
        player.global_position = Vector3(0.0, 0.0, 6.0 if rear else -6.0)
        if rear:
            boss.rotation = Vector3(0.0, PI, 0.0)
        else:
            var to_p: Vector3 = (
                player.global_position - boss.global_position)
            boss.rotation = Vector3(0.0, atan2(to_p.x, to_p.z), 0.0)
        for frame in range(30):
            battle.set("player_hp", 9999.0)
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
        if rear:
            # Keep the facing-away geometry exact: the free AI turns
            # toward the player during settle.
            boss.rotation = Vector3(0.0, PI, 0.0)
            player.global_position = Vector3(0.0, 0.0, 6.0)
        brain.call("force_start_with_stance", leg_id, "kick")
        var leg2: Dictionary = ik.get("legs")[part_ids.find(leg_id)]
        var foot2: Node3D = leg2["foot"]
        var started2: bool = false
        var last_track_yaw: float = 0.0
        var saw_tracking: bool = false
        var min_dist: float = 1e9
        for frame in range(60 * 8):
            battle.set("player_hp", 9999.0)
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
            var f: Dictionary = battle.get("bittaran_attack_frame")
            if f.is_empty():
                if started2:
                    break
                continue
            started2 = true
            if bool(f.get("tracking", false)):
                last_track_yaw = rad_to_deg(
                    float(battle.get("bittaran_attack_body_yaw")))
                saw_tracking = true
            var phase: String = str(f.get("phase", ""))
            if phase == "strike" or phase == "hold":
                min_dist = minf(min_dist, foot2.global_position
                    .distance_to(player.global_position))
        var corner: float = float(CORNERS[leg_id])
        var expected: float = rad_to_deg(clampf(wrapf(
            deg_to_rad(180.0 if rear else 0.0) - deg_to_rad(corner),
            -PI, PI), -deg_to_rad(60.0), deg_to_rad(60.0)))
        if not saw_tracking:
            _fail("%s kick: no tracking windup observed" % leg_id)
        elif absf(wrapf(deg_to_rad(last_track_yaw)
                - deg_to_rad(expected), -PI, PI)) > deg_to_rad(10.0):
            _fail("%s kick: chest ended windup at %.1f deg, hip "
                % [leg_id, last_track_yaw]
                + "corner bearing is %.1f deg" % expected)
        if min_dist > MAX_NATURAL_DISTANCE:
            _fail("%s kick: foot only reached %.2f m from the "
                % [leg_id, min_dist] + "player in natural geometry")

    if failures.is_empty():
        print("GODOT_V409_BITTARAN_GUIDANCE_LIMITS_PASS")
        quit(0)
    else:
        for message in failures:
            printerr("V409_BITTARAN_GUIDANCE_LIMITS_FAIL: ", message)
        quit(1)

func _initialize() -> void:
    call_deferred("_run")
