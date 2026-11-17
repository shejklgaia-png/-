extends SceneTree
## v435: source clip owns BODY and chosen striker. New isolated
## locomotion IK solves all 4 feet during Approach/Turn; strike IK
## solves exactly the 3 other limbs, never a mesh or joint on striker.
const BATTLE = preload("res://scripts/bittaran_battle.gd")
const DT: float = 0.05
const CONTACT_TOLERANCE_METERS: float = 0.065
const ATTACKS: Dictionary = {
    "なぎ払い": ["leg_fl", "sweep"],
    "弾き": ["leg_fl", "kick"],
    "踏みつけ_L": ["leg_fl", "stomp"],
    "なぎ払い_R": ["leg_fr", "sweep"],
    "弾き_R": ["leg_fr", "kick"],
    "踏みつけ_R": ["leg_fr", "stomp"],
}
const BONES: Dictionary = {
    "leg_fl": ["Body", "FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L"],
    "leg_fr": ["Body", "FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R"]
}
const LEG_IDS: Array[String] = ["leg_fr", "leg_rl", "leg_fl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V435_GAIT_SUPPORT_IK_FAIL " + message)
    quit(1)

func _sole(limb: Dictionary) -> Vector3:
    var foot: Node3D = limb["foot"]
    return foot.to_global(limb["source_sole_local"] as Vector3)

func _meshes_unchanged(rig: Node3D, label: String) -> bool:
    var mesh_map: Dictionary = rig.get("mesh_nodes_by_uuid")
    var source: Dictionary = rig.get("mesh_base_positions_by_uuid")
    if mesh_map.size() != 18:
        _fail("expected 18 original mesh elements")
        return false
    for uid in mesh_map.keys():
        var piece: MeshInstance3D = mesh_map[uid]
        if piece.position.distance_to(source[uid]) > 0.00001:
            _fail("mesh separated from its joint " + str([label, uid]))
            return false
    return true

func _run() -> void:
    if BATTLE.BLOCKBENCH_SOURCE_REPLAY_ONLY or not (
            BATTLE.BLOCKBENCH_GAIT_SUPPORT_IK):
        _fail("v435 isolated IK must be enabled in battle")
        return
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("cannot load battle scene")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if rig == null or ik == null or director == null or target == null or player == null:
        _fail("missing battle dependencies")
        return
    if not bool(rig.get("loading_ok")) or not bool(
            ik.get("source_ik_enabled")):
        _fail("source IK is not initialized")
        return
    var limbs: Array = ik.get("legs")
    if limbs.size() != 4 or not _meshes_unchanged(rig, "entry"):
        return
    var start_y: float = rig.position.y
    var gait_samples: int = 0
    var ground_contacts: int = 0
    var step_seen: bool = false
    for motion in ["Approach", "Turn", "Idle"]:
        for tick in range(55):
            if motion == "Approach":
                target.position += Vector3(0.0, 0.0, 0.033)
            elif motion == "Turn":
                target.rotation.y += 0.012
            rig.call("set_motion", motion, DT)
            ik.call("advance_source_ground_ik", DT, motion, {})
            if not _meshes_unchanged(rig, str([motion, tick])):
                return
            if absf(rig.position.y - start_y) > 0.0001:
                _fail("walking/turning moved the model root vertically")
                return
            for limb in limbs:
                var sole: Vector3 = _sole(limb)
                if bool(limb["stepping"]):
                    step_seen = true
                    if sole.y < -CONTACT_TOLERANCE_METERS:
                        _fail("stepping foot clipped floor " +
                            str([motion, tick, sole]))
                        return
                else:
                    var stance_anchor: Vector3 = limb["anchor"]
                    if absf(sole.y) > CONTACT_TOLERANCE_METERS or (
                            sole.distance_to(stance_anchor) > 0.09):
                        _fail("planted gait foot drifted from world anchor " +
                            str([motion, tick, sole, stance_anchor]))
                        return
                    ground_contacts += 1
            gait_samples += 1
    if not step_seen or gait_samples != 165:
        _fail("diagonal gait/turn sequence not exercised")
        return
    # Reset from the manual locomotion probe. Actual attack routing
    # calls both production methods and uses only original clip times.
    target.position = Vector3.ZERO
    target.rotation.y = 0.0
    rig.call("apply_pose", "Wait", 0.0)
    if not bool(ik.call("initialize_source_ground_ik")):
        _fail("cannot reset baseline for attack checks")
        return
    player.global_position = target.global_position + Vector3(0.0, 0.0, 7.0)
    var bone_map: Dictionary = rig.get("bone_uuid_by_name")
    var nodes: Dictionary = rig.get("bones")
    var attacks_checked: int = 0
    for clip in ATTACKS.keys():
        var options: Array = ATTACKS[clip]
        if not bool(director.call("force_start", options[0], options[1])):
            _fail("cannot start " + clip)
            return
        var frame_count: int = 0
        # Cover the complete timed attack, including 1.5s holding
        # and 0.42s leg / 0.62s body staged recovery.
        for tick in range(120):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            battle.call("_finalize_target_pose", DT)
            var t: float = float(frame.get("authored_time", 0.0))
            # Entry/recovery now intentionally interpolate Wait and
            # source poses. Original strike/hold MUST still match every
            # Blockbench joint key exactly, without IK on the striker.
            if ["strike", "hold"].has(str(frame.get("phase", ""))):
                for bone_name in BONES[options[0]]:
                    var uid: String = str(bone_map.get(bone_name, ""))
                    if uid.is_empty():
                        _fail("missing attacker joint " + bone_name)
                        return
                    var joint: Node3D = nodes[uid]
                    var authored_rot: Quaternion = rig.call(
                        "_authored_key_rotation", clip, bone_name, t)
                    var authored_pos: Vector3 = rig.call(
                        "_authored_key_position", clip, bone_name, t)
                    if joint.quaternion.angle_to(authored_rot) > 0.002 or (
                            joint.position.distance_to(authored_pos) > 0.0001):
                        _fail("striker/Body source key changed " +
                            str([clip, bone_name, t]))
                        return
            var supports: int = 0
            for i in range(limbs.size()):
                if LEG_IDS[i] == options[0]:
                    continue
                var contact: Vector3 = _sole(limbs[i])
                var planted: Vector3 = limbs[i]["source_ik_attack_anchor"]
                if absf(contact.y) > CONTACT_TOLERANCE_METERS or (
                        contact.distance_to(planted) > 0.09):
                    _fail("support foot drifted from planted anchor " +
                        str([clip, LEG_IDS[i], t, contact, planted]))
                    return
                supports += 1
                ground_contacts += 1
            if supports != 3 or not _meshes_unchanged(rig, clip):
                _fail("three planted supports and intact mesh joints required")
                return
            if absf(rig.position.y - start_y) > 0.0001:
                _fail("attack IK moved model root")
                return
            frame_count += 1
        if frame_count < 19:
            _fail("attack frames missing " + str([clip, frame_count]))
            return
        attacks_checked += 1
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
    if attacks_checked != 6 or ground_contacts < 100:
        _fail("not enough support contacts sampled")
        return
    print("GODOT_V435_GAIT_SUPPORT_IK_PASS ",
        "gait_frames=", gait_samples, " source_attacks=", attacks_checked,
        " grounded_contacts=", ground_contacts,
        " unreachable=", ik.get("source_ik_unreachable_supports"))
    quit(0)
