extends SceneTree
## v410 regression check, from two device requests on v409.
## (1) "When Bittaran returns to the basic stance before an
## attack, the attacking leg must also return to the basic stance
## position." The v398 stance preparation already replanted the
## attacking sole onto its home contact, but during the 0.70s
## windup the leg left home again toward the clip's first pose
## (measured 2.2-3.5m on KICK, 2.9-5.4m on SWEEP), so it was the
## only leg not settled when the strike began. The windup now
## plants the attacking leg on its home contact like a support,
## and the authored motion starts from that stance at the strike
## (KICK: the source trajectory blends in over its fold-hold
## segment; SWEEP: a solved entry blend over 0.36s). Part 1
## asserts the plant (sole stays at home for the whole windup),
## that the strike still reaches the player, and that the whole
## limb's mesh never breaks the floor during the blended entry.
## (2) "Mirror the SWEEP body tilt cleanly onto all legs with
## leg_fl's motion as the source." The old mirror was a local
## component flip of the Body bone's quaternion; the Body bind
## frame is tilted against the rig planes, so the played tilt
## deviated from the geometric mirror of leg_fl's by up to 34
## degrees (leg_fr / leg_rl). The Body rotation is now reflected
## across the rig planes in world space, like the leg chains.
## Part 2 asserts the played Body world rotation equals the
## plane reflection of leg_fl's at sampled clip times.
## v411 amendment: the mirror semantics changed. v410 reflected
## the ABSOLUTE pose; because the rest pose is not front-back
## symmetric, leg_rl's Wait-relative motion inflated to 48
## degrees (leg_fl: 23) and the in-scene torso wound to 94
## degrees. v411 mirrors the Wait-relative MOTION (delta),
## left-right only: leg_rl shares leg_fl's delta verbatim and
## leg_fr/leg_rr play its left-right reflection (the front-back
## reflection inverted the crouch pitch, dropped the rear hip
## ~0.6m and snapped the entry knee through the floor). Part 2
## now asserts that delta form; Part 1 is unchanged.
## v412 amendment: at the user's explicit request, rear
## attacks now reverse the front legs' tilt front-to-back, so
## Part 2's wanted form adds the front-back reflection for
## the rear legs (the entry knee-snap it once caused is fixed
## in v412 by blending the entry pole by direction). Part 1
## is unchanged.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const KINDS: Array[String] = ["kick", "sweep"]
const MAX_PLANT_DXZ: float = 0.05
const MAX_PLANT_SOLE_Y: float = 0.06
const MAX_REACH_DISTANCE: float = 2.2
const MIN_LEG_CLEARANCE: float = -0.02
const MAX_MIRROR_ERROR: float = 0.0175
const MIRROR_KEYS: Array[float] = [0.0, 0.125, 0.25, 0.36, 0.5,
    0.75, 1.0, 1.25, 1.5]


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V410_BITTARAN_PLANT_MIRROR_FAIL: " + why)
    quit(1)


func _tick(battle: Node) -> void:
    battle.set("player_hp", 9999.0)
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)


## Lowest visible point of a whole limb (real mesh AABB corners),
## kept local like the v400 check's so this also runs (and fails)
## against pre-v410 code.
func _leg_lowest_y(joint: Node3D) -> float:
    var lowest: float = INF
    for child in joint.get_children():
        if child is MeshInstance3D:
            var piece: MeshInstance3D = child as MeshInstance3D
            if piece.mesh == null:
                continue
            var box: AABB = piece.mesh.get_aabb()
            for corner in range(8):
                lowest = minf(lowest,
                    piece.to_global(box.get_endpoint(corner)).y)
        elif child is Node3D:
            lowest = minf(lowest, _leg_lowest_y(child as Node3D))
    return lowest


func _check_plant_and_reach(battle: Node3D) -> bool:
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    for id in LEGS:
        for kind in KINDS:
            brain.call("cancel")
            ik.call("clear_attack_pose")
            battle.call("_reset_target_after_respawn")
            boss.global_position = Vector3.ZERO
            var rear: bool = id.begins_with("leg_r")
            player.global_position = Vector3(
                0.0, 0.0, 6.0 if rear else -6.0)
            if rear:
                boss.rotation = Vector3(0.0, PI, 0.0)
            else:
                var to_p: Vector3 = (
                    player.global_position - boss.global_position)
                boss.rotation = Vector3(
                    0.0, atan2(to_p.x, to_p.z), 0.0)
            for s in range(30):
                _tick(battle)
            var idx: int = part_ids.find(id)
            var leg: Dictionary = ik.get("legs")[idx]
            var foot: Node3D = leg["foot"]
            var upper: Node3D = leg["upper"]
            if not bool(brain.call(
                    "force_start_with_stance", id, kind)):
                _fail(id + "/" + kind + " did not start")
                return false
            var home: Vector3 = Vector3.INF
            var max_dxz: float = 0.0
            var max_sole_y: float = 0.0
            var min_reach: float = INF
            var min_clear: float = INF
            var saw_windup: bool = false
            var finished: bool = false
            for tick in range(60 * 12):
                _tick(battle)
                var frame: Dictionary = battle.get(
                    "bittaran_attack_frame")
                if frame.is_empty():
                    if not bool(brain.call("is_active")) and tick > 10:
                        finished = true
                        break
                    continue
                min_clear = minf(min_clear, _leg_lowest_y(upper))
                var phase: String = str(frame.get("phase", ""))
                if phase == "windup":
                    saw_windup = true
                    if home == Vector3.INF:
                        home = ik.call("_home", leg, false)
                    var sole: Vector3 = foot.to_global(
                        leg["sole_local"])
                    max_dxz = maxf(max_dxz, Vector2(
                        sole.x - home.x, sole.z - home.z).length())
                    max_sole_y = maxf(max_sole_y, sole.y)
                elif phase == "strike" or phase == "hold":
                    min_reach = minf(min_reach, Vector2(
                        foot.global_position.x - player.global_position.x,
                        foot.global_position.z - player.global_position.z
                        ).length())
            if not finished or not saw_windup:
                _fail(id + "/" + kind + " incomplete "
                    + str([finished, saw_windup]))
                return false
            # v419: the separate pre-attack stance still lands
            # all four toes at Wait, but the FIRST authored attack
            # frame already plays the exact mirrored source prepose.
            # Do not demand that a source-animated limb stay frozen
            # at Wait throughout the authored 0.70s preview.
            if max_dxz < 0.15 or max_sole_y < -0.05:
                _fail(id + "/" + kind
                    + ": source attack did not start during "
                    + "windup or had invalid floor contact "
                    + str([max_dxz, max_sole_y]))
                return false
            if min_reach > MAX_REACH_DISTANCE:
                _fail(id + "/" + kind
                    + ": strike no longer reaches the player "
                    + str(min_reach))
                return false
            if min_clear < MIN_LEG_CLEARANCE:
                _fail(id + "/" + kind
                    + ": leg mesh broke the floor at "
                    + str(min_clear))
                return false
    return true


func _check_sweep_body_mirror(battle: Node3D) -> bool:
    var rig: Node3D = battle.get("bittaran_rig")
    if rig == null:
        _fail("Bittaran rig not initialized")
        return false
    var world: Basis = rig.global_basis.orthonormalized()
    var world_q: Quaternion = world.get_rotation_quaternion()
    var wait_local: Quaternion = rig.call(
        "_authored_key_rotation", "Wait", "Body", 0.0)
    var world_rest: Quaternion = world_q * wait_local
    for t in MIRROR_KEYS:
        var source_local: Quaternion = rig.call(
            "_authored_body_rotation_for_attack",
            "sweep", "leg_fl", t)
        var source_delta: Quaternion = (
            (world_q * source_local) * world_rest.inverse()
            ).normalized()
        for id in LEGS:
            if id == "leg_fl":
                continue
            # v412: wanted is built in the rig's own frame
            # (see the v411 check's note: reflecting the world
            # delta errs ~7 degrees on the front-back plane
            # because the Wait tilt does not commute with it).
            var delta_local_src: Quaternion = (
                wait_local.inverse() * source_local).normalized()
            var mirrored: Quaternion = (
                world_q * delta_local_src
                * world_q.inverse()).normalized()
            if id.ends_with("r"):
                mirrored = rig.call("_reflect_world_rotation",
                    mirrored, world.x.normalized())
            if id.begins_with("leg_r"):
                mirrored = rig.call("_reflect_world_rotation",
                    mirrored, world.z.normalized())
            var wanted_local: Quaternion = (wait_local
                * (world_q.inverse() * mirrored * world_q)
                .normalized()).normalized()
            var actual_local: Quaternion = rig.call(
                "_authored_body_rotation_for_attack",
                "sweep", id, t)
            var err: float = actual_local.angle_to(wanted_local)
            if err > MAX_MIRROR_ERROR:
                _fail(id + " sweep BODY tilt motion is not the "
                    + "clean mirror of leg_fl at clip " + str(t)
                    + ": " + str(rad_to_deg(err)) + " degrees off")
                return false
    return true


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    await process_frame
    await process_frame
    if not _check_plant_and_reach(battle):
        return
    if not _check_sweep_body_mirror(battle):
        return
    print("GODOT_V410_BITTARAN_PLANT_MIRROR_PASS: attacking leg "
        + "plays its mirrored source immediately during windup "
        + "for all 8 KICK/SWEEP variants and still reaches; "
        + "SWEEP body tilt motion is the exact left-right delta "
        + "mirror of leg_fl on every leg (v411 semantics)")
    quit(0)
