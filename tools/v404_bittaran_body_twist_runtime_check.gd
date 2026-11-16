extends SceneTree
## v404 regression check, from device feedback on v403 (the same
## defect was still visible): during close-range KICKs and SWEEPs the
## whole torso corkscrewed. Decomposition showed the shared authored
## Body track itself pitches 34.4 degrees and rolls 19.7 degrees from
## Wait at its peak, the clips end at that peak, and the pose is then
## held fully twisted through the whole 1.50s KICK hold, stacked with
## the 45-degree chest tracking yaw (in-scene: pitch 33.5 / roll 21.1
## degrees). The rig now damps the Body track's pitch/roll delta to
## 45 percent for KICK/SWEEP. This check asserts the chassis pitch
## and roll stay bounded during close-range attacks while a real
## crouch (pitch) is still present, i.e. the nuance is kept.
##
## v418 supersedes v404's second contract: the player explicitly
## requires KICK to play its FULL source reach independent of their
## distance. Part B now verifies a nearby target is NOT used to trim
## the animation, even though the toe may legitimately overshoot.
const DT: float = 1.0 / 60.0
# v419: the user's request is the ORIGINAL complete BODY track.
# No artificial damping. The original clip peaks near 34deg
# pitch/20deg roll, so retain a bounded 45/28deg safety margin
# against any newly introduced non-authored corkscrew.
const MAX_PITCH_DEGREES: float = 45.0
const MAX_ROLL_DEGREES: float = 28.0
const MIN_PEAK_PITCH_DEGREES: float = 8.0

var failures: Array[String] = []

func _fail(message: String) -> void:
    failures.append(message)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var chassis: Node3D = ik.get("chassis_bone")
    var rig: Node3D = battle.get("bittaran_rig")
    var cases: Array = [
        ["leg_fr", "kick"], ["leg_fl", "kick"],
        ["leg_fr", "sweep"], ["leg_fl", "sweep"],
    ]
    for c in cases:
        var leg_id: String = c[0]
        var kind: String = c[1]
        boss.global_position = Vector3.ZERO
        player.global_position = Vector3(1.8, 0.0, -3.2)
        var to_p: Vector3 = player.global_position - boss.global_position
        boss.rotation = Vector3(0.0, atan2(to_p.x, to_p.z), 0.0)
        for frame in range(30):
            battle.set("player_hp", 9999.0)
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
        var rest_q: Quaternion = boss.global_basis \
            .get_rotation_quaternion().inverse() \
            * chassis.global_basis.get_rotation_quaternion()
        brain.call("force_start_with_stance", leg_id, kind)
        var started: bool = false
        var max_pitch: float = 0.0
        var max_roll: float = 0.0
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
            var rel: Quaternion = boss.global_basis \
                .get_rotation_quaternion().inverse() \
                * chassis.global_basis.get_rotation_quaternion()
            var e: Vector3 = (rel * rest_q.inverse()).get_euler()
            max_pitch = maxf(max_pitch, absf(rad_to_deg(e.x)))
            max_roll = maxf(max_roll, absf(rad_to_deg(e.z)))
        if max_pitch > MAX_PITCH_DEGREES:
            _fail("%s %s pitched the chassis %.1f deg (limit %.0f)"
                % [leg_id, kind, max_pitch, MAX_PITCH_DEGREES])
        if max_roll > MAX_ROLL_DEGREES:
            _fail("%s %s rolled the chassis %.1f deg (limit %.0f)"
                % [leg_id, kind, max_roll, MAX_ROLL_DEGREES])
        if max_pitch < MIN_PEAK_PITCH_DEGREES:
            _fail("%s %s lost its crouch: peak pitch only %.1f deg "
                % [leg_id, kind, max_pitch]
                + "(minimum %.0f)" % MIN_PEAK_PITCH_DEGREES)
    # Part B: a nearby player's position must NOT shorten the KICK.
    # Keep the old close-range and mid-range cases, but the old
    # "do not overshoot" assertion conflicts with v418's full
    # source animation contract. A close contact is intentionally
    # passed by the full-length limb; the attack hitbox determines
    # whether the strike connects.
    var part_ids: Array = ik.get("LEG_PART_IDS")
    var fr_idx: int = part_ids.find("leg_fr")
    var reach_cases: Array = [
        Vector3(0.0, 0.0, -2.8),
        Vector3(0.0, 0.0, -4.6),
    ]
    for rc in reach_cases:
        var spot: Vector3 = rc
        boss.global_position = Vector3.ZERO
        player.global_position = spot
        boss.rotation = Vector3(0.0, atan2(spot.x, spot.z), 0.0)
        for frame in range(30):
            battle.set("player_hp", 9999.0)
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
        brain.call("force_start_with_stance", "leg_fr", "kick")
        var started_b: bool = false
        var best_reach: float = -1.0
        var joint_over: float = -999.0
        var tip_over: float = -999.0
        for frame in range(60 * 9):
            battle.set("player_hp", 9999.0)
            battle.call("_advance_target_motion", DT)
            battle.call("_finalize_target_pose", DT)
            var f: Dictionary = battle.get("bittaran_attack_frame")
            if f.is_empty():
                if started_b:
                    break
                continue
            started_b = true
            var phase: String = str(f.get("phase", ""))
            if phase != "strike" and phase != "hold":
                continue
            var leg: Dictionary = (ik.get("legs") as Array)[fr_idx]
            var foot: Node3D = leg["foot"]
            var hip: Vector3 = (leg["upper"] as Node3D).global_position
            var reach: float = hip.distance_to(foot.global_position)
            if reach > best_reach:
                best_reach = reach
                var axis_dir: Vector3 = (
                    player.global_position - hip)
                axis_dir.y = 0.0
                axis_dir = axis_dir.normalized()
                joint_over = (foot.global_position
                    - player.global_position).dot(axis_dir)
                var toe_axis: Vector3 = leg.get(
                    "toe_axis_local", Vector3(1, 0, 0))
                var tip: Vector3 = foot.global_position \
                    + foot.global_basis * (toe_axis * 0.9715)
                tip_over = (tip - player.global_position).dot(axis_dir)
        if spot.z > -3.0 and joint_over < 2.0:
            _fail("leg_fr source KICK was shortened by nearby "
                + "player despite v418 full-range contract: "
                + str(joint_over) + "m past the target")
        if absf(float(rig.get("kick_reach_factor"))
                - 1.0) > 0.00001:
            _fail("leg_fr source KICK was distance-scaled")
        if spot.z < -4.0 and joint_over < -1.2:
            _fail("leg_fr kick at %s fell short: joint ended %.2fm "
                % [str(spot), joint_over]
                + "before the player at full extension")
    if failures.is_empty():
        print("GODOT_V404_BITTARAN_BODY_TWIST_PASS")
        quit(0)
    else:
        for message in failures:
            printerr("V404_BITTARAN_BODY_TWIST_FAIL: ", message)
        quit(1)

func _initialize() -> void:
    call_deferred("_run")
