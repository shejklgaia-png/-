extends SceneTree
## v385: all three USER-authored Blockbench clips must be reachable via
## the actual combat path. KICK/SWEEP 0.70s BODY prepose, all four limbs,
## world-planted supports, and real earth/debris FX for every attack.
## v411 amendment: the BODY prepose reference is the rig's played
## target (_authored_body_rotation_for_attack: damped since v404,
## delta-mirrored for SWEEP since v411), not the raw clip rotation.
## The raw key is leg_fl's unmirrored source; a correctly mirrored
## rear leg plays a pose more than the 1.15 rad tolerance away from
## it. The invariant is unchanged: at the strike the Body must have
## moved >0.12 rad from its start pose toward the attack's intended
## opening pose.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const BittaranRig = preload("res://scripts/bittaran_rig.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V385_AUTHORED_ATTACK_DIRT_FAIL: " + why)
    quit(1)

func _run_case(battle: Node3D, id: String, kind: String) -> bool:
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", true)
    var brain: RefCounted = battle.get("bittaran_attacks")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var fx: Node3D = battle.get("bittaran_dirt_fx")
    var ring: MeshInstance3D = battle.get("bittaran_shockwave")
    if fx == null or not bool(rig.get("loading_ok")):
        _fail("authored model or dirt effects missing")
        return false
    var index: int = IK.LEG_PART_IDS.find(id)
    var leg: Dictionary = ik.get("legs")[index]
    var supports: Dictionary = {}
    for i in range(IK.LEG_PART_IDS.size()):
        if i != index:
            supports[IK.LEG_PART_IDS[i]] = ik.get("legs")[i]["anchor"]
    if not bool(brain.call("force_start", id, kind)):
        _fail("unable to start " + kind + " for " + id)
        return false
    var clip: String = str(BittaranRig.ATTACK_NAMES[kind])
    if not bool(rig.get("animations").has(clip)):
        _fail("missing real user clip " + clip)
        return false
    var clip_length: float = float(rig.call("authored_clip_length", kind))
    if absf(clip_length - (1.75 if kind == "stomp"
            else (1.0 if kind == "kick" else 1.5))) > 0.0001:
        _fail(kind + " changed length of authored source")
        return false
    var preview: float = 0.70 if kind != "stomp" else 0.0
    var strike_end: float = (
        BRAIN.STOMP_WINDUP_SECONDS + BRAIN.STOMP_STRIKE_SECONDS
        if kind == "stomp" else (
        BRAIN.KICK_WINDUP_SECONDS + BRAIN.KICK_STRIKE_SECONDS
        if kind == "kick" else
        BRAIN.SWEEP_WINDUP_SECONDS + BRAIN.SWEEP_STRIKE_SECONDS))
    var reached_prepose: bool = false
    var source_pose_sampled: bool = false
    var head_followed: bool = false
    var torso_aim_before_strike: float = 0.0
    var impact_seen: bool = false
    var earthen_fx_seen: bool = false
    var stopped_aim: Vector3 = Vector3.INF
    var recovered: bool = false
    var last_root: Vector3 = boss.global_position
    var last_yaw: float = boss.rotation.y
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    var start_pose: Quaternion = body.quaternion
    var delta_prepose: float = 0.0
    var first_foot_y: float = -INF
    var close_foot_horizontal: bool = false
    for tick in range(290):
        var sideways: float = (
            0.0 if tick < 20 else (
            1.0 if tick < 40 else -0.6))
        player.global_position = boss.global_position + Vector3(
            sideways, 0.0, 7.6)
        battle.call("_advance_target_motion", DT)
        var frame: Dictionary = battle.get("bittaran_attack_frame")
        if frame.is_empty():
            recovered = true
            break
        var t: float = float(frame.get("time", 0.0))
        if boss.global_position.distance_to(last_root) > 0.00001 or absf(
                wrapf(boss.rotation.y - last_yaw, -PI, PI)) > 0.00001:
            _fail("attack root moved: " + kind + "/" + id)
            return false
        if bool(frame.get("tracking", false)):
            torso_aim_before_strike = float(frame.get("body_yaw", 0.0))
        elif stopped_aim == Vector3.INF:
            stopped_aim = frame.get("aim", Vector3.INF)
        elif (frame.get("aim", Vector3.INF) as Vector3).distance_to(
                stopped_aim) > 0.0001:
            _fail("aim continued after swing start: " + kind)
            return false
        # Validate that the authored source joint key is genuinely
        # sampled BEFORE contact IK changes only buried frames. Comparing
        # the final compensated joint directly to the raw key is now
        # invalid when that raw foot would intersect the ground.
        if kind != "stomp" and t >= preview + 0.30 and (
                t <= preview + 0.35):
            var raw: Dictionary = frame.duplicate()
            rig.call("apply_authored_attack_pose", raw)
            var raw_name: String = str(
                BittaranRig.ATTACK_LEG_BONES[id][0])
            var raw_joint: Node3D = rig.find_child(
                raw_name, true, false)
            var raw_expected: Quaternion = rig.call(
                "_authored_rotation_for_leg", kind, id, 0,
                t - preview)
            source_pose_sampled = source_pose_sampled or (
                raw_joint.quaternion.angle_to(raw_expected) < 0.05)
        battle.call("_finalize_target_pose", DT)
        var goal: Vector3 = leg["last_goal"]
        for support_id in supports:
            var support: Dictionary = ik.get("legs")[
                IK.LEG_PART_IDS.find(support_id)]
            var old: Vector3 = supports[support_id]
            var planted: Vector3 = support["last_goal"]
            if Vector2(planted.x - old.x,
                    planted.z - old.z).length() > 0.0001:
                _fail("support anchor moved on " + kind + " " + support_id)
                return false
            if t >= 0.30:
                var real: Vector3 = (
                    support["foot"] as Node3D).to_global(
                    support["sole_local"] as Vector3)
                if Vector2(real.x - old.x,
                        real.z - old.z).length() > 0.10:
                    _fail("real support foot slipped " + support_id)
                    return false
        if kind != "stomp":
            if absf(t - preview) <= DT:
                var want: Quaternion = rig.call(
                    "_authored_body_rotation_for_attack",
                    kind, id, 0.0)
                delta_prepose = start_pose.angle_to(body.quaternion)
                # The rebuilt four-leg attack does not add a rear-only
                # BODY pitch. The raw mirrored key is measured before
                # the shared tracking yaw.
                reached_prepose = delta_prepose > 0.12 and (
                    body.quaternion.angle_to(want) < 1.15)
            if t >= preview + 0.30 and t <= preview + 0.35:
                # The final result is an IK rotation, not the same
                # LOCAL quaternion as the raw authored shoulder.
                # Compare the actual FOOT WORLD orientation with the
                # mirrored original source clip at the same frame.
                var sample_func: String = (
                    "sample_authored_kick_source" if kind == "kick"
                    else "sample_authored_sweep_source")
                var sole_fl: Vector3 = ik.get("legs")[0][
                    "source_sole_local"]
                var expected: Dictionary = rig.call(
                    sample_func, id, float(
                        frame.get("authored_time", t - preview)),
                    sole_fl)
                if not expected.is_empty():
                    var yaw: Quaternion = Quaternion(
                        Vector3.UP, float(
                            rig.get("attack_leg_aim_yaw")))
                    var wanted: Quaternion = (
                        yaw * (expected["rotation"] as Quaternion)
                        ).normalized()
                    var actual: Quaternion = (
                        (leg["foot"] as Node3D).global_basis
                        .get_rotation_quaternion())
                    source_pose_sampled = source_pose_sampled or (
                        actual.angle_to(wanted) < 0.05 and
                        bool(leg.get("unified_strike", false)))
            var contact: Vector3 = (leg["foot"] as Node3D).to_global(
                leg["sole_local"] as Vector3)
            if contact.distance_to(goal) > 0.001 and t < strike_end:
                _fail("IK overrode imported joint track: " + kind)
                return false
            if kind == "sweep" and t > preview + 0.10 and t < strike_end:
                if bool((fx.get("sweep_dust") as CPUParticles3D).emitting):
                    earthen_fx_seen = true
            if kind == "kick" and t > preview + 0.15 and t < strike_end:
                if bool((fx.get("kick_chunks") as CPUParticles3D).emitting):
                    earthen_fx_seen = true
        else:
            var foot: Node3D = leg["foot"]
            var real_sole: Vector3 = foot.to_global(
                leg["sole_local"] as Vector3)
            if t >= BRAIN.STOMP_WINDUP_SECONDS - 0.035 and t <= (
                    BRAIN.STOMP_WINDUP_SECONDS + 0.015):
                first_foot_y = real_sole.y
            if t > 0.34 and t < BRAIN.STOMP_WINDUP_SECONDS - 0.20:
                # Original STOMP toe keys must survive the windup.
                var original: Quaternion = rig.call(
                    "_authored_rotation_for_leg", "stomp", id, 2, t)
                if foot.quaternion.angle_to(original) > 0.045:
                    _fail("stomp foot original windup was overwritten")
                    return false
            if bool(frame.get("impact", false)):
                impact_seen = true
                # v400: the model's long toe runs along the foot
                # joint's +/-X, not -Y as originally assumed. Measure
                # the toe itself from the real mesh (joint to mesh
                # centre): at contact it must point straight down,
                # leaving the short end face flat on the floor.
                var toe_axis: Vector3 = Vector3.ZERO
                for child in foot.get_children():
                    if child is MeshInstance3D:
                        var piece: MeshInstance3D = child as MeshInstance3D
                        if piece.mesh != null:
                            toe_axis = (piece.to_global(
                                piece.mesh.get_aabb().get_center())
                                - foot.global_position).normalized()
                            break
                close_foot_horizontal = toe_axis.dot(Vector3.DOWN) > 0.998
                earthen_fx_seen = (ring.visible and bool(
                    (fx.get("stomp_dust") as CPUParticles3D).emitting)
                    and bool((fx.get("stomp_chunks") as CPUParticles3D).emitting))
                if not (ring.mesh is ArrayMesh) or (
                        ring.mesh is TorusMesh):
                    _fail("stomp used unbroken/old circular TorusMesh")
                    return false
                var old_scale: Vector3 = ring.scale
                battle.call("_tick_bittaran_shockwave", 0.14)
                if old_scale.distance_to(ring.scale) > 0.0001:
                    _fail("grey impact ring expanded from its center")
                    return false
    if not recovered or (kind != "sweep" and stopped_aim == Vector3.INF) \
            or not earthen_fx_seen:
        _fail(kind + "/" + id + ": incomplete authored playback or FX")
        return false
    if kind != "stomp" and (not reached_prepose or not source_pose_sampled):
        _fail(kind + "/" + id + ": not playing keyframed low prepose/strike")
        return false
    if kind == "stomp" and (
            not impact_seen or not close_foot_horizontal
            or first_foot_y < 1.90):
        _fail("stomp did not raise above head / keep long toe vertical at contact " + id
            + " " + str([first_foot_y, close_foot_horizontal]))
        return false
    return true

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var count: int = 0
    for id in BRAIN.LEG_IDS:
        for kind in BRAIN.ATTACK_KINDS:
            if not _run_case(battle, id, kind):
                return
            count += 1
    print("GODOT_V385_AUTHORED_DIRT_PASS: 12 real bone-retargeted attacks, "
        + "0.70s authored low preposes, frozen 3 support feet, stomp "
        + "toe horizontal at contact, fixed-size broken grey ring, "
        + "kick/sweep dirt particles and actual clip playback")
    quit(0)
