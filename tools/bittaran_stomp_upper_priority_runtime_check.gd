extends SceneTree
## Precise, bounded real-skeleton check for priority-guided STOMP.
## Aimed lift may alter UPPER pitch only. LOWER local quaternion must
## be identical to its authored source key for all four limbs.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const RIG = preload("res://scripts/bittaran_rig.gd")
const TIMING = preload("res://scripts/bittaran_attacks.gd")
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("BITTARAN_UPPER_PRIORITY_FAIL " + message)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var controller: RefCounted = battle.get("bittaran_foot_ik")
    if rig == null or controller == null:
        _fail("missing actual Bittaran joints")
        return
    var limbs: Array = controller.get("legs")
    for id in IDS:
        var index: int = IK.LEG_PART_IDS.find(id)
        var limb: Dictionary = limbs[index]
        var upper: Node3D = limb["upper"]
        var lower: Node3D = limb["lower"]
        var foot: Node3D = limb["foot"]
        var clip: String = str(
            RIG.SOURCE_ATTACK_CLIPS[id]["stomp"])
        var t: float = TIMING.source_authored_windup_clip_seconds(
            "stomp", id) * 0.62
        rig.call("apply_source_clip_exact", clip, t)
        var authored_lower: Quaternion = lower.quaternion
        var hip: Vector3 = upper.global_position
        var foot_rel: Vector3 = foot.global_position - hip
        var knee_rel: Vector3 = lower.global_position - hip
        var pitch_axis: Vector3 = foot_rel.cross(Vector3.UP)
        pitch_axis.y = 0.0
        if pitch_axis.length_squared() < 0.00001:
            _fail("cannot aim upper pitch " + id)
            return
        pitch_axis = pitch_axis.normalized()
        var toe_offset: Vector3 = (
            foot.to_global(limb["source_sole_local"] as Vector3)
            - foot.global_position)
        var turn := Quaternion(pitch_axis, deg_to_rad(16.0))
        var knee_rise: float = (
            (turn * knee_rel).y - knee_rel.y)
        # Aim at an analytically reachable toe waypoint for an
        # upward rotation. Not a hypothetical telescoping leg.
        var target: Vector3 = hip + turn * foot_rel + toe_offset
        target.y = 0.0
        rig.set("source_aim_stomp_player_position", target)
        rig.set("source_aim_stomp_descent_started", false)
        controller.set("source_ik_stomp_upper_pitch_radians", 0.0)
        controller.set("source_ik_stomp_target_offset", Vector3.ZERO)
        var frame: Dictionary = {
            "kind": "stomp", "id": id,
            "phase": "strike", "authored_time": t
        }
        # Priority proof: no length/pitch correction while BODY
        # and the socket have not settled on their allowed target.
        rig.set("source_aim_primary_settled", false)
        controller.call("_source_ik_aim_stomp_raising_limb", limb, frame)
        if float(controller.get(
                "source_ik_stomp_upper_pitch_radians")) > 0.00001 or (
                lower.quaternion.angle_to(authored_lower) > 0.0001):
            _fail("leg aimed before torso and shoulder " + id)
            return
        rig.set("source_aim_primary_settled", true)
        var peak_pitch: float = 0.0
        var peak_knee_rise: float = 0.0
        for tick in range(24):
            rig.call("apply_source_clip_exact", clip, t)
            var knee_before: float = lower.global_position.y
            var foot_rotation_before: Quaternion = (
                foot.global_basis.get_rotation_quaternion())
            controller.call("_source_ik_aim_stomp_raising_limb",
                limb, frame)
            peak_pitch = maxf(peak_pitch, float(controller.get(
                "source_ik_stomp_upper_pitch_radians")))
            peak_knee_rise = maxf(peak_knee_rise,
                lower.global_position.y - knee_before)
            if lower.quaternion.angle_to(authored_lower) > 0.0005:
                _fail("lower/shin authored angle changed " + str([
                    id, tick, lower.quaternion.angle_to(authored_lower)]))
                return
            if foot.global_basis.get_rotation_quaternion().angle_to(
                    foot_rotation_before) > 0.002:
                _fail("toe orientation twisted " + id)
                return
        # The model may already have an almost vertical upper link
        # at this instant. Every leg still has to obey the hard
        # quaternion and pitch constraints; knee lift is recorded.
        if peak_pitch > deg_to_rad(
                IK.STOMP_AIM_UPPER_MAX_DEGREES) + 0.0001 or (
                peak_knee_rise < -0.0001):
            _fail("upper pitch limit or rise direction wrong " + id)
            return
        var held_pitch: float = peak_pitch
        rig.set("source_aim_stomp_descent_started", true)
        rig.set("source_aim_stomp_player_position",
            Vector3(100.0, 0.0, 100.0))
        rig.call("apply_source_clip_exact", clip, t)
        controller.call("_source_ik_aim_stomp_raising_limb", limb, frame)
        if absf(float(controller.get(
                "source_ik_stomp_upper_pitch_radians"))
                - held_pitch) > 0.00001:
            _fail("upper aim changed after downswing " + id)
            return
        print("BITTARAN_UPPER_CASE ", id,
            " pitch_deg=", rad_to_deg(peak_pitch),
            " knee_rise_m=", peak_knee_rise,
            " source_knee_angle_unchanged=true",
            " primary_moves_first=true")
    print("BITTARAN_UPPER_PRIORITY_PASS all_four=true")
    quit(0)
