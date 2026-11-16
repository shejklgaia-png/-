extends SceneTree
## v416: reproduce the ACTUAL defects: rear KICK does not crawl along
## floor, and front-right KICK toe bends more after repeat 2.
## Stronger than v415's 3/4-degree 3-frame snapshots: compare a toe
## joint at the exact same authored clip phase over eight real attacks.
const DT: float = 1.0 / 60.0
const REPEATS: int = 8
const IDS: Array[String] = ["leg_fr", "leg_rl", "leg_rr"]
const SAMPLES: Array[float] = [0.12, 0.40, 0.75]
const MAX_RIGHT_TOE_LOCAL_DRIFT_DEGREES: float = 0.12
const MAX_RIGHT_TOE_WORLD_DRIFT_DEGREES: float = 0.20
const MAX_REAR_CRAWL_FOOT_Y: float = 0.20
const MIN_REAR_CRAWL_FRACTION: float = 0.80


func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("V416_REAR_GROUND_RIGHT_TOE_FAIL: " + reason)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    if rig == null or ik == null or brain == null or boss == null             or player == null:
        _fail("missing battle")
        return
    var errors: Array[String] = []
    for id in IDS:
        battle.call("_reset_target_after_respawn")
        battle.set("target_move_enabled", true)
        var side: float = -1.0 if id.ends_with("l") else 1.0
        var z: float = 6.0 if id.begins_with("leg_r") else -6.0
        var fixed_root: Transform3D = boss.global_transform
        # Right-front near-side target reproduces the player's
        # close-range KICK reach and high chest-aim correction. The
        # earlier far-range v415 fixture concealed toe bending after
        # successive strikes.
        var spot: Vector3 = (
            Vector3(2.5, 0.0, -3.54) if id == "leg_fr"
            else Vector3(1.5 * side, 0.0, z))
        var fixed_player: Vector3 = (
            boss.global_position + spot)
        player.global_position = fixed_player
        var leg_idx: int = ik.LEG_PART_IDS.find(id)
        var leg: Dictionary = ik.get("legs")[leg_idx]
        var foot: Node3D = leg["foot"]
        var reference: Dictionary = {}
        var time_reference: Dictionary = {}
        var trace: Array[String] = []
        var geometry: Array[String] = []
        for rep in range(REPEATS):
            boss.global_transform = fixed_root
            player.global_position = fixed_player
            if not bool(brain.call("force_start_with_stance", id, "kick")):
                _fail("kick failed: " + id + " rep=" + str(rep))
                return
            var observed: Dictionary = {}
            var crawl: int = 0
            var crawl_total: int = 0
            var worst_height: float = -INF
            var lowest_height: float = INF
            var peak_toe_local: float = 0.0
            var peak_toe_world: float = 0.0
            var finished: bool = false
            var started: bool = false
            var biggest_time_local: float = 0.0
            var biggest_time_world: float = 0.0
            var biggest_time_at: float = 0.0
            var checked_times: Dictionary = {}
            for tick in range(520):
                battle.set("player_hp", 9999.0)
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                if frame.is_empty():
                    if started and not bool(brain.call("is_active")):
                        finished = true
                        break
                    continue
                if str(frame.get("phase", "")) == "stance":
                    continue
                started = true
                var phase: String = str(frame.get("phase", ""))
                if id == "leg_fr" and phase != "stance":
                    for requested in [0.25, 0.55, 0.71, 0.95, 1.2,
                            1.5, 1.9, 2.8, 3.25, 3.50, 3.7]:
                        var time_key: String = str(requested)
                        var real_t: float = float(
                            frame.get("time", -100.0))
                        if checked_times.has(time_key) or                                 absf(real_t - float(requested)) >                                 DT * 0.52:
                            continue
                        checked_times[time_key] = true
                        var rot_local: Quaternion = foot.quaternion
                        var rot_world: Quaternion = (
                            foot.global_basis.get_rotation_quaternion())
                        if rep == 0:
                            time_reference[time_key] = [rot_local, rot_world]
                        elif time_reference.has(time_key):
                            var source: Array = time_reference[time_key]
                            var diff_local: float = rad_to_deg(
                                rot_local.angle_to(source[0]))
                            var diff_world: float = rad_to_deg(
                                rot_world.angle_to(source[1]))
                            if diff_local > biggest_time_local:
                                biggest_time_local = diff_local
                                biggest_time_at = real_t
                            biggest_time_world = maxf(
                                biggest_time_world, diff_world)
                if phase != "strike" and phase != "hold":
                    continue
                var clip_t: float = float(frame.get(
                    "authored_time", -100.0))
                if id.begins_with("leg_r") and clip_t >= 0.35                         and clip_t <= 0.60 and phase == "strike":
                    var low: float = float(ik.call(
                        "_foot_mesh_lowest_y", foot))
                    crawl_total += 1
                    if low <= MAX_REAR_CRAWL_FOOT_Y:
                        crawl += 1
                    worst_height = maxf(worst_height, low)
                    lowest_height = minf(lowest_height, low)
                    if rep == 0 and absf(clip_t - 0.48) < DT * 0.55:
                        var hip_node: Node3D = leg["upper"]
                        var knee_node: Node3D = leg["lower"]
                        var knee_world: Vector3 = knee_node.global_position
                        var toe_world: Vector3 = foot.global_position
                        var hip_world: Vector3 = hip_node.global_position
                        var foot_scale: Vector3 = (
                            foot.global_basis.get_scale())
                        var desired_foot_goal: Vector3 = (
                            toe_world + Vector3.DOWN
                            * maxf(low - 0.025, 0.0))
                        var reach: float = hip_world.distance_to(
                            knee_world) + knee_world.distance_to(toe_world)
                        var needed: float = hip_world.distance_to(
                            desired_foot_goal)
                        geometry.append(id + " hipY="
                            + str(snappedf(hip_world.y, 0.01))
                            + " ankleY=" + str(snappedf(toe_world.y, 0.01))
                            + " reach=" + str(snappedf(reach, 0.01))
                            + " need=" + str(snappedf(needed, 0.01))
                            + " floorGap=" + str(snappedf(low, 0.01))
                            + " scale=" + str(foot_scale))
                for target_t in SAMPLES:
                    var label: String = str(target_t)
                    if observed.has(label) or (
                            absf(clip_t - target_t) > DT * 0.55):
                        continue
                    observed[label] = true
                    var current_local: Quaternion = foot.quaternion
                    var current_world: Quaternion = (
                        foot.global_basis.get_rotation_quaternion())
                    if rep == 0:
                        reference[label] = [current_local, current_world]
                    else:
                        var prev: Array = reference.get(label, [])
                        if prev.is_empty():
                            _fail("first repeat did not sample " + label)
                            return
                        var local_degrees: float = rad_to_deg(
                            current_local.angle_to(prev[0]))
                        var world_degrees: float = rad_to_deg(
                            current_world.angle_to(prev[1]))
                        peak_toe_local = maxf(
                            peak_toe_local, local_degrees)
                        peak_toe_world = maxf(
                            peak_toe_world, world_degrees)
            if not finished or observed.size() != SAMPLES.size():
                _fail(id + " rep=" + str(rep) + " incomplete")
                return
            var crawl_fraction: float = (float(crawl) / float(
                crawl_total) if crawl_total > 0 else 0.0)
            trace.append(str(rep) + ":toe=" + str(snappedf(
                peak_toe_local, 0.01)) + "/" + str(snappedf(
                peak_toe_world, 0.01)) + "deg,floor="
                + str(snappedf(crawl_fraction, 0.01))
                + ",highest=" + str(snappedf(worst_height, 0.01))
                + ",lowest=" + str(snappedf(lowest_height, 0.01))
                + ",wind/recover-toe="
                + str(snappedf(biggest_time_local, 0.01))
                + "/" + str(snappedf(biggest_time_world, 0.01))
                + "@" + str(snappedf(biggest_time_at, 0.01)))
            if id == "leg_fr" and (
                    peak_toe_local > MAX_RIGHT_TOE_LOCAL_DRIFT_DEGREES
                    or peak_toe_world > MAX_RIGHT_TOE_WORLD_DRIFT_DEGREES
                    or biggest_time_local >
                        MAX_RIGHT_TOE_LOCAL_DRIFT_DEGREES
                    or biggest_time_world >
                        MAX_RIGHT_TOE_WORLD_DRIFT_DEGREES):
                errors.append(id + " rep=" + str(rep)
                    + " source local/world toe drift "
                    + str(peak_toe_local) + "/" + str(peak_toe_world)
                    + "; complete phase local/world "
                    + str(biggest_time_local) + "/"
                    + str(biggest_time_world)
                    + " at real t=" + str(biggest_time_at))
            if id.begins_with("leg_r") and crawl_fraction                     < MIN_REAR_CRAWL_FRACTION:
                errors.append(id + " rep=" + str(rep)
                    + " crawl fraction " + str(crawl_fraction)
                    + " peak gap=" + str(worst_height))
        print("GODOT_V416_DIAG " + id + " " + " | ".join(trace))
        print("GODOT_V416_GEOMETRY " + id + " "
            + " | ".join(geometry))
    if not errors.is_empty():
        _fail(" | ".join(errors))
        return
    print("GODOT_V416_REAR_GROUND_RIGHT_TOE_PASS: "
        + "rear crawls and front-right toe stable for 8 repeats")
    quit(0)
