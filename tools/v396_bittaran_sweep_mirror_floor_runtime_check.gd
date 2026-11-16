extends SceneTree
## v396: sweep is the exact mirrored front-left spatial animation on
## all four limbs. BODY roll MUST mirror too; the rear WAIT axes are
## intentionally different and may NOT be used as the sweep basis.
## During live SWEEP the IK floor correction must not rewrite knee
## or ankle keyframed rotations.
## v410 amendment: the rotation-equality window starts after the
## strike's 0.36s entry blend. Since v410 the windup keeps the
## attacking leg planted at the basic stance (device request) and
## the entry is an IK-solved blend from that stance to the authored
## pose, so during the blend the knee/toe locals are the solver's
## by design. After the blend the played pose is the authored pose
## and the original assertion applies unchanged; the floor
## penetration assertion still covers every tick, blend included.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const KEYS: Array[float] = [0.0, 0.125, 0.25, 0.36, 0.41667,
    0.50, 0.625, 0.75, 1.0]
const LEG_BONES: Dictionary = {
    "leg_fl": ["FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L"],
    "leg_fr": ["FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R"],
    "leg_rl": ["RearLeg_L", "RearLowerLeg_L", "RearFoot_L"],
    "leg_rr": ["RearLeg_R", "RearLowerLeg_R", "RearFoot_R"]
}


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V396_BITTARAN_SWEEP_FAIL: " + message)
    quit(1)


func _sample_author_pose(rig: Node3D, id: String, at: float) -> Dictionary:
    # Restore immutable Blockbench joint origins before each new sample.
    rig.call("apply_pose", "Wait", 0.0)
    var body: Node3D = rig.find_child("Body", true, false)
    if body == null:
        return {}
    body.quaternion = rig.call(
        "_authored_body_rotation_for_attack", "sweep", id, at)
    var nodes: Array[Node3D] = []
    for slot in range(3):
        var joint: Node3D = rig.find_child(
            str(LEG_BONES[id][slot]), true, false) as Node3D
        if joint == null:
            return {}
        joint.quaternion = rig.call(
            "_authored_rotation_for_leg", "sweep", id, slot, at)
        nodes.append(joint)
    return {
        "ankle_from_hip": nodes[2].global_position - nodes[0].global_position,
        "toe_down": -nodes[2].global_basis.y.normalized()
    }


func _check_all_four_mirrors(rig: Node3D) -> bool:
    for t in KEYS:
        var source: Dictionary = _sample_author_pose(rig, "leg_fl", t)
        if source.is_empty():
            _fail("front-left source pose unavailable")
            return false
        var reference: Vector3 = source["ankle_from_hip"]
        var tip: Vector3 = source["toe_down"]
        for id in IDS:
            var actual: Dictionary = _sample_author_pose(rig, id, t)
            if actual.is_empty():
                _fail(id + ": mirrored pose unavailable")
                return false
            var x_sign: float = -1.0 if id.ends_with("r") else 1.0
            var z_sign: float = -1.0 if id.begins_with("leg_r") else 1.0
            var wanted: Vector3 = Vector3(
                reference.x * x_sign, reference.y,
                reference.z * z_sign)
            var wanted_tip: Vector3 = Vector3(
                tip.x * x_sign, tip.y, tip.z * z_sign)
            var offset_error: float = (actual["ankle_from_hip"]
                as Vector3).distance_to(wanted)
            var toe_angle_error: float = (actual["toe_down"]
                as Vector3).angle_to(wanted_tip)
            if offset_error > 0.025 or toe_angle_error > 0.045:
                _fail(id + " at key=" + str(t) +
                    " mirrored toe path or rotation mismatched source: "
                    + str([offset_error, rad_to_deg(toe_angle_error)]))
                return false
        if t >= 0.25 and t <= 1.0 and reference.y >= 0.0:
            _fail("front-left source sweep rises above hip at " + str(t))
            return false
    return true


func _check_live_attacks(battle: Node3D) -> bool:
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var player: CharacterBody3D = battle.get("player")
    var boss: Node3D = battle.get("target")
    for id in IDS:
        battle.call("_reset_target_after_respawn")
        battle.set("target_move_enabled", true)
        var side: float = -1.0 if id.ends_with("r") else 1.0
        var fore: float = -1.0 if id.begins_with("leg_r") else 1.0
        # Keep SERA out of strike range, avoiding an unrelated KO.
        player.global_position = boss.global_position + Vector3(
            13.0 * side, 0.0, 13.0 * fore)
        if not bool(brain.call("force_start", id, "sweep")):
            _fail(id + ": failed to start sweep")
            return false
        var idx: int = IK.LEG_PART_IDS.find(id)
        if idx < 0:
            _fail(id + ": missing leg IK index")
            return false
        var leg: Dictionary = ik.get("legs")[idx]
        var knee: Node3D = leg["lower"]
        var foot: Node3D = leg["foot"]
        var checked: int = 0
        var active: int = 0
        for tick in range(300):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                if active > 0:
                    break
                continue
            active += 1
            battle.call("_finalize_target_pose", DT)
            var floor_depth: float = float(ik.call(
                "_foot_mesh_lowest_y", foot))
            if not is_finite(floor_depth) or floor_depth < -0.012:
                _fail(id + ": striking toe penetrated floor " +
                    str([tick, floor_depth]))
                return false
            var t: float = float(frame.get("time", 0.0))
            var start: float = float(frame.get("windup", 0.70))
            var end: float = start + float(frame.get("strike", 2.06))
            if t > start + 0.41 and t < end - 0.05:
                var clip_time: float = float(frame.get("authored_time", 0.0))
                var expected_knee: Quaternion = rig.call(
                    "_authored_rotation_for_leg", "sweep", id, 1, clip_time)
                var expected_toe: Quaternion = rig.call(
                    "_authored_rotation_for_leg", "sweep", id, 2, clip_time)
                if knee.quaternion.angle_to(expected_knee) > 0.012 or (
                        foot.quaternion.angle_to(expected_toe) > 0.012):
                    _fail(id + ": floor correction rewrote authored " +
                        "SWEEP knee/toe rotations " +
                        str([tick, clip_time]))
                    return false
                checked += 1
        if active < 130 or checked < 55:
            _fail(id + ": not enough live SWEEP frames " +
                str([active, checked]))
            return false
    return true


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    if rig == null:
        _fail("Bittaran rig not initialized")
        return
    if not _check_all_four_mirrors(rig):
        return
    if not _check_live_attacks(battle):
        return
    print("GODOT_V396_BITTARAN_SWEEP_PASS: 4 limbs x 9 mirrored "
        + "source samples match both ankle path and toe angle; full "
        + "live attacks keep original knee/toe keys and floor clearance")
    quit(0)
