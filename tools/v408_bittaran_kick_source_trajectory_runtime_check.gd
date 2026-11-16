extends SceneTree
## v408: the KICK no longer retargets the authored clip per leg
## in joint space. Every leg plays the SOURCE leg's (leg_fl)
## foot trajectory -- sole point, ankle, knee and foot rotation
## sampled from the authored chain, mirrored hip-relatively in
## the rig frame, re-aimed around the hip and re-solved by IK
## (device request: reproduce the original motion, the foot
## extending low along the ground, on every leg). The joint
## retargets deviated from that trajectory by up to ~1.75m
## mid-strike on leg_fr and capped its reach through a frame
## mismatch between the mirrored rotation and each foot's own
## sole point.
##
## This check plays all four legs in the geometries the game
## actually selects (front legs with the player in front, rear
## legs with the player behind, boss facing the player / away)
## and asserts, per leg:
##  - the fold is planted at windup end (foot mesh on the floor)
##  - the ankle's hip-relative height through the extension
##    and hold tracks the source leg's own profile (<= 0.50m;
##    <= 0.65m in the 0.30-0.45 fade band and <= 1.00m on the
##    held fold segment, where the goal is shifted vertically
##    so the leg's own foot mesh -- which reaches up to 0.93m
##    less below its ankle than the source's -- still plants.
##    leg_rl's residual ~0.45m is its v406 reach factor (0.59
##    vs the source leg's 0.42 in this geometry) rescaling the
##    path, not a trajectory shape error; the retarget-era
##    deviations this guards against were 1.47-2.47m)
##  - the foot mesh never goes below the floor, and stays low
##    (ground-crawling) through the extension segment
const DT: float = 1.0 / 60.0
const MAX_FOLD_MESH_Y: float = 0.10
const MAX_PROFILE_HEIGHT_DEV: float = 0.50
const MAX_FADE_HEIGHT_DEV: float = 0.65
const MAX_FOLD_HEIGHT_DEV: float = 1.00
# v414: the rear BODY pitches the full opposite of Wait instead of
# adding an 8-degree tail lift. The rear shoulder's vertical locus
# therefore differs from the original FRONT leg's source reference.
# Preserve a bounded profile difference; the independent foot-floor
# and source motion checks continue to apply on all four legs.
const REAR_FADE_HEIGHT_DEV: float = 1.20
const REAR_FOLD_HEIGHT_DEV: float = 1.30
const MAX_REAR_FRAME_STEP: float = 0.65
const MIN_MESH_Y: float = -0.02
const MAX_EXTENSION_MESH_Y: float = 0.30

var failures: Array = []


func _fail(message: String) -> void:
    failures.append(message)


func _run_kick(battle: Node3D, brain: RefCounted, ik: RefCounted,
        boss: Node3D, player: CharacterBody3D, leg_id: String,
        spot: Vector3) -> Dictionary:
    var legs: Array = ik.get("legs")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    var li: int = part_ids.find(leg_id)
    var foot: Node3D = legs[li]["foot"]
    var upper: Node3D = legs[li]["upper"]
    boss.global_position = Vector3.ZERO
    player.global_position = spot
    boss.rotation.y = atan2(spot.x, spot.z)
    if leg_id.begins_with("leg_r"):
        boss.rotation.y = atan2(-spot.x, -spot.z)
    for i in range(45):
        battle.set("player_hp", 9999.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
    brain.call("force_start_with_stance", leg_id, "kick")
    var out: Dictionary = {"fold_mesh": INF, "profile": {},
        "min_mesh": INF, "ext_mesh": INF, "max_frame_step": 0.0}
    var previous_foot: Vector3 = Vector3.INF
    var started: bool = false
    var ticks: int = 0
    while ticks < 60 * 8:
        ticks += 1
        battle.set("player_hp", 9999.0)
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            if started:
                break
            continue
        started = true
        var phase: String = str(frame.get("phase", ""))
        var mesh_y: float = float(ik.call(
            "_foot_mesh_lowest_y", foot))
        if phase == "windup":
            out["fold_mesh"] = mesh_y
        elif phase == "strike" or phase == "hold":
            if previous_foot != Vector3.INF:
                out["max_frame_step"] = maxf(
                    float(out["max_frame_step"]),
                    foot.global_position.distance_to(previous_foot))
            previous_foot = foot.global_position
            var hip: Vector3 = upper.global_position
            var ct: float = clampf(float(
                frame.get("authored_time", 0.0)), 0.0, 1.0)
            (out["profile"] as Dictionary)[
                snappedf(ct, 0.001)] = foot.global_position.y \
                - hip.y
            out["min_mesh"] = minf(float(out["min_mesh"]), mesh_y)
            if ct >= 0.3 and ct <= 0.6:
                out["ext_mesh"] = minf(
                    float(out["ext_mesh"]), mesh_y)
    return out


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    await process_frame
    await process_frame
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if brain == null or ik == null or boss == null or player == null:
        _fail("missing live boss / IK / attack director")
        _report()
        return
    var spots: Dictionary = {
        "leg_fl": Vector3(-2.5, 0.0, -3.54),
        "leg_fr": Vector3(2.5, 0.0, -3.54),
        "leg_rl": Vector3(-2.5, 0.0, 3.54),
        "leg_rr": Vector3(2.5, 0.0, 3.54),
    }
    var results: Dictionary = {}
    for leg_id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        results[leg_id] = await _run_kick(battle, brain, ik, boss,
            player, leg_id, spots[leg_id])
    var ref: Dictionary = results["leg_fl"]["profile"]
    for leg_id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        var r: Dictionary = results[leg_id]
        if float(r["fold_mesh"]) > MAX_FOLD_MESH_Y:
            _fail(leg_id + " kick fold not planted (mesh y="
                + str(r["fold_mesh"]) + ")")
        if float(r["min_mesh"]) < MIN_MESH_Y:
            _fail(leg_id + " kick foot mesh below floor (y="
                + str(r["min_mesh"]) + ")")
        if float(r["ext_mesh"]) > MAX_EXTENSION_MESH_Y:
            _fail(leg_id + " kick extension not ground-low "
                + "(mesh y=" + str(r["ext_mesh"]) + ")")
        var worst: float = 0.0
        var worst_fade: float = 0.0
        var worst_fold: float = 0.0
        for key in (r["profile"] as Dictionary):
            if not ref.has(key):
                continue
            var dev: float = absf(
                float(r["profile"][key]) - float(ref[key]))
            var ct: float = float(key)
            if ct < 0.3:
                worst_fold = maxf(worst_fold, dev)
            elif ct < 0.45:
                worst_fade = maxf(worst_fade, dev)
            else:
                worst = maxf(worst, dev)
        if worst > MAX_PROFILE_HEIGHT_DEV:
            _fail(leg_id + " kick ankle height profile deviates "
                + str(worst) + "m from the source leg")
        var fade_limit: float = (
            REAR_FADE_HEIGHT_DEV
            if leg_id.begins_with("leg_r") else MAX_FADE_HEIGHT_DEV)
        var fold_limit: float = (
            REAR_FOLD_HEIGHT_DEV
            if leg_id.begins_with("leg_r") else MAX_FOLD_HEIGHT_DEV)
        if worst_fade > fade_limit:
            _fail(leg_id + " kick ankle height profile deviates "
                + str(worst_fade) + "m in the fade band")
        if worst_fold > fold_limit:
            _fail(leg_id + " kick ankle height profile deviates "
                + str(worst_fold) + "m on the fold segment")
        if leg_id.begins_with("leg_r") and float(
                r["max_frame_step"]) > MAX_REAR_FRAME_STEP:
            _fail(leg_id + " kick ankle snapped during the rear "
                + "fixed-height trajectory: "
                + str(r["max_frame_step"]) + "m/frame")
    _report()


func _report() -> void:
    if failures.is_empty():
        print("GODOT_V408_BITTARAN_KICK_SOURCE_TRAJECTORY_PASS")
        quit(0)
    else:
        for message in failures:
            printerr("V408_BITTARAN_KICK_SOURCE_TRAJECTORY_FAIL: ",
                message)
        quit(1)


func _initialize() -> void:
    call_deferred("_run")
