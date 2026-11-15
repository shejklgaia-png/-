extends SceneTree
## v400: the three user-reported Bittaran attack-motion defects.
## (1) KICK feet on non-source legs ended the strike rolled/pitched
## far from the source leg (measured 41/87/107 degrees versus the
## source leg's 9): the component-flip retarget error lives in the
## shoulder/knee parent frames, so those joints now blend to a
## world-space mirror across the strike while the delta-mapped fold
## keeps the foot planted through the windup. (2) SWEEP carried the
## upper/lower leg meshes up to 1.57m below the floor while only the
## foot was clamped; the authored branch now lifts the whole limb at
## its shoulder by the same translational correction. (3) STOMP's
## contact frame assumed the long toe runs along local -Y, but the
## model carries it along +/-X, so the toe landed almost flat; the
## contact frame is now built from the measured toe axis and the toe
## must stand perpendicular to the floor at impact.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const DT: float = 1.0 / 60.0
const MAX_KICK_FOOT_TILT_DEGREES: float = 20.0
const MAX_WINDUP_SOLE_LIFT: float = 0.10
const MIN_SWEEP_LEG_CLEARANCE: float = -0.01
const MAX_STOMP_TOE_TILT_DEGREES: float = 12.0
const MAX_STOMP_FOOT_GAP: float = 0.02


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V400_BITTARAN_ATTACK_MOTION_FAIL: " + why)
    quit(1)


func _tick(battle: Node) -> void:
    battle.set("player_hp", 9999.0)
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)


func _settle(battle: Node, ticks: int) -> void:
    for i in range(ticks):
        _tick(battle)


## Lowest visible point of a whole limb, sampled from the real mesh
## AABB corners. Kept local to this check so it also runs (and fails)
## against pre-v400 code, which has no equivalent IK helper.
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


func _run() -> void:
    var battle: Node = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    await process_frame
    await process_frame
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: Node3D = battle.get("player")
    if brain == null or ik == null or boss == null or player == null:
        _fail("missing live boss / IK / attack director")
        return
    var legs: Array = ik.get("legs")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    _settle(battle, 90)
    for id in ATTACKS.LEG_IDS:
        var li: int = part_ids.find(id)
        if li < 0:
            _fail("IK has no leg for " + id)
            return
        var leg: Dictionary = legs[li]
        var upper: Node3D = leg["upper"]
        var lower: Node3D = leg["lower"]
        var foot: Node3D = leg["foot"]
        var hip_off: Vector3 = upper.global_position - boss.global_position
        var outward: Vector3 = Vector3(hip_off.x, 0.0, hip_off.z).normalized()
        player.global_position = boss.global_position + outward * 3.6
        player.global_position.y = 0.0
        if not bool(brain.call("force_start_with_stance", id, "kick")):
            _fail("unable to start " + id + "/kick")
            return
        var ticks: int = 0
        var windup_sole: float = INF
        var best_ratio: float = 0.0
        var best_tilt: float = -1.0
        var finished: bool = false
        while ticks < 60 * 12:
            ticks += 1
            _tick(battle)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                if not bool(brain.call("is_active")) and ticks > 10:
                    finished = true
                    break
                continue
            var phase: String = str(frame.get("phase", ""))
            if phase == "windup":
                windup_sole = (foot.to_global(
                    leg["sole_local"] as Vector3)).y
            elif phase == "strike":
                var hip: Vector3 = upper.global_position
                var knee: Vector3 = lower.global_position
                var ankle: Vector3 = foot.global_position
                var seg: float = hip.distance_to(knee) \
                    + knee.distance_to(ankle)
                var ratio: float = hip.distance_to(ankle) / maxf(seg, 0.001)
                if ratio > best_ratio:
                    best_ratio = ratio
                    best_tilt = rad_to_deg(foot.global_basis
                        .orthonormalized().y.angle_to(Vector3.UP))
        if not finished:
            _fail(id + "/kick never completed")
            return
        if not is_finite(windup_sole) \
                or absf(windup_sole) > MAX_WINDUP_SOLE_LIFT:
            _fail(id + "/kick left its fold unplanted (sole y="
                + str(windup_sole) + ")")
            return
        if best_tilt < 0.0 or best_tilt > MAX_KICK_FOOT_TILT_DEGREES:
            _fail(id + "/kick foot tilt at extension is "
                + str(best_tilt) + " degrees")
            return
        _settle(battle, 30)
        player.global_position = boss.global_position + outward * 3.6
        player.global_position.y = 0.0
        if not bool(brain.call("force_start_with_stance", id, "sweep")):
            _fail("unable to start " + id + "/sweep")
            return
        ticks = 0
        finished = false
        var min_clearance: float = INF
        while ticks < 60 * 14:
            ticks += 1
            _tick(battle)
            var frame2: Dictionary = battle.get("bittaran_attack_frame")
            if frame2.is_empty():
                if not bool(brain.call("is_active")) and ticks > 10:
                    finished = true
                    break
                continue
            min_clearance = minf(min_clearance, _leg_lowest_y(upper))
        if not finished:
            _fail(id + "/sweep never completed")
            return
        if min_clearance < MIN_SWEEP_LEG_CLEARANCE:
            _fail(id + "/sweep buried its leg mesh at y="
                + str(min_clearance))
            return
        _settle(battle, 30)
        player.global_position = boss.global_position + outward * 3.6
        player.global_position.y = 0.0
        if not bool(brain.call("force_start_with_stance", id, "stomp")):
            _fail("unable to start " + id + "/stomp")
            return
        ticks = 0
        finished = false
        var toe_tilt: float = -1.0
        var foot_gap: float = -1.0
        while ticks < 60 * 12:
            ticks += 1
            _tick(battle)
            var frame3: Dictionary = battle.get("bittaran_attack_frame")
            if frame3.is_empty():
                if not bool(brain.call("is_active")) and ticks > 10:
                    finished = true
                    break
                continue
            if toe_tilt < 0.0 and str(frame3.get("phase", "")) == "hold":
                var toe_world: Vector3 = foot.global_basis.orthonormalized() \
                    * (leg["toe_axis_local"] as Vector3)
                toe_tilt = rad_to_deg(toe_world.angle_to(Vector3.DOWN))
                foot_gap = float(ik.call("_foot_mesh_lowest_y", foot))
        if not finished:
            _fail(id + "/stomp never completed")
            return
        if toe_tilt < 0.0 or toe_tilt > MAX_STOMP_TOE_TILT_DEGREES:
            _fail(id + "/stomp toe is not perpendicular at impact ("
                + str(toe_tilt) + " degrees from vertical)")
            return
        if foot_gap < -MAX_STOMP_FOOT_GAP or foot_gap > MAX_STOMP_FOOT_GAP:
            _fail(id + "/stomp foot does not rest on the floor (gap "
                + str(foot_gap) + ")")
            return
        _settle(battle, 30)
    print("GODOT_V400_BITTARAN_ATTACK_MOTION_PASS: kick extension tilt, "
        + "grounded folds, sweep leg clearance and perpendicular "
        + "stomp toes verified for all four legs")
    quit(0)
