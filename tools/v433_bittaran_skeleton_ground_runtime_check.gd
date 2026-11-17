extends SceneTree
## v433 regression: all 18 mesh elements retain their original parent-local
## geometry. No mesh-level translation is allowed. Three support legs use
## skeletal IK; authored attacking leg and Body stay untouched.
const DIRECTOR = preload("res://scripts/bittaran_attacks.gd")
const GROUND = preload("res://assets/bittaran_ground_contacts.gd")
const ATTACK_BONES: Dictionary = {
    "leg_fl": ["Body", "FrontLeg_L", "FrontLowerLeg_L", "FrontFoot_L"],
    "leg_fr": ["Body", "FrontLeg_R", "FrontLowerLeg_R", "FrontFoot_R"],
}
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const DT: float = 0.05
const FOOT_TOLERANCE: float = 0.035

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V433_SKELETON_GROUND_FAIL: " + reason)
    quit(1)

func _meshes_attached(rig: Node3D, phase: String) -> bool:
    var meshes: Dictionary = rig.get("mesh_nodes_by_uuid")
    var bind: Dictionary = rig.get("mesh_base_positions_by_uuid")
    if meshes.size() != 18:
        _fail("Expected 18 original mesh instances, got " + str(meshes.size()))
        return false
    for uid in meshes.keys():
        var mesh: MeshInstance3D = meshes[uid]
        if not is_instance_valid(mesh) or not bind.has(uid):
            _fail("Lost original mesh/parent: " + str([phase, uid]))
            return false
        if mesh.position.distance_to(bind[uid]) > 0.0001:
            _fail("Mesh was detached from its joint: "
                + str([phase, uid, mesh.position, bind[uid]]))
            return false
        if not mesh.get_parent() is Node3D:
            _fail("Missing parent joint for " + str(uid))
            return false
    return true

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("Battle scene not loadable")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if rig == null or ik == null or director == null or target == null or player == null:
        _fail("Missing real battle dependencies")
        return
    if not bool(rig.get("loading_ok")) or not DIRECTOR.ORIGINAL_ATTACK_ONLY:
        _fail("Cannot sample current authored attack pipeline")
        return
    if not _meshes_attached(rig, "initial"):
        return
    var catalog: Dictionary = GROUND.DATA["clips"]
    var authored: Dictionary = rig.get("animations")
    if catalog.size() != 10:
        _fail("The full ten-clip contact archive is missing")
        return
    # All ten animations and all eighteen mesh elements are analyzed,
    # but the resulting contact flags must remain observational only.
    for clip_name in catalog.keys():
        if not authored.has(clip_name):
            _fail("Missing original clip " + str(clip_name))
            return
        var duration: float = float(catalog[clip_name]["length"])
        var samples: Array[float] = [0.0, duration * 0.25,
            duration * 0.5, duration * 0.75, duration]
        for t in samples:
            rig.call("apply_pose", str(clip_name), t)
            var bones_before: Dictionary = {}
            var bones: Dictionary = rig.get("bones")
            for uid in bones.keys():
                var bone: Node3D = bones[uid]
                bones_before[uid] = [bone.position, bone.quaternion]
            var diagnostics: Dictionary = rig.call(
                "inspect_blockbench_ground_contacts", str(clip_name), t)
            if diagnostics.size() != 18:
                _fail("Diagnostic ignored mesh elements")
                return
            if not _meshes_attached(rig, str([clip_name, t])):
                return
            for uid in bones.keys():
                var bone: Node3D = bones[uid]
                if bone.position.distance_to(bones_before[uid][0]) > 0.00001:
                    _fail("Contact diagnosis moved an articulated joint")
                    return
                if bone.quaternion.angle_to(bones_before[uid][1]) > 0.00001:
                    _fail("Contact diagnosis rotated an articulated joint")
                    return
    var tested: int = 0
    var bone_map: Dictionary = rig.get("bone_uuid_by_name")
    var joints: Dictionary = rig.get("bones")
    var limbs: Array = ik.get("legs")
    for repeat in range(2):
        for id in ["leg_fl", "leg_fr"]:
            for kind in ["sweep", "kick", "stomp"]:
                var clip_name: String = (
                    "なぎ払い" if kind == "sweep" else (
                    "弾き" if kind == "kick" else "踏みつけ_L"))
                if id == "leg_fr":
                    clip_name = ("踏みつけ_R" if kind == "stomp"
                        else clip_name + "_R")
                if not bool(director.call("force_start", id, kind)):
                    _fail("Could not start attack: " + clip_name)
                    return
                player.global_position = target.global_position + Vector3(
                    0.0, 0.0, 7.0)
                for step in range(45):
                    battle.call("_advance_target_motion", DT)
                    var frame: Dictionary = battle.get("bittaran_attack_frame")
                    if frame.is_empty():
                        break
                    battle.call("_finalize_target_pose", DT)
                    if not _meshes_attached(rig, str(
                            [clip_name, repeat, step])):
                        return
                    var t: float = float(frame.get("authored_time", -1.0))
                    for bone_name in ATTACK_BONES[id]:
                        var uid: String = str(bone_map.get(bone_name, ""))
                        if uid.is_empty():
                            _fail("No authored bone " + bone_name)
                            return
                        var bone: Node3D = joints[uid]
                        var authored_rot: Quaternion = rig.call(
                            "_authored_key_rotation", clip_name, bone_name, t)
                        var authored_pos: Vector3 = rig.call(
                            "_authored_key_position", clip_name, bone_name, t)
                        if bone.quaternion.angle_to(authored_rot) > 0.002 or (
                                bone.position.distance_to(authored_pos) > 0.0001):
                            _fail("Attacking bone or Body deviated from source: "
                                + str([clip_name, bone_name, t]))
                            return
                    var grounded: int = 0
                    for index in range(limbs.size()):
                        if IDS[index] == id:
                            continue
                        var limb: Dictionary = limbs[index]
                        var foot: Node3D = limb["foot"]
                        var sole: Vector3 = foot.to_global(
                            limb["sole_local"] as Vector3)
                        if absf(sole.y) > FOOT_TOLERANCE:
                            _fail("Support IK lost ground contact: " +
                                str([clip_name, IDS[index], t, sole.y]))
                            return
                        grounded += 1
                    if grounded != 3:
                        _fail("Three support feet required")
                        return
                tested += 1
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
    if tested != 12:
        _fail("Six attacks x two repeats were not exercised")
        return
    print("GODOT_V433_SKELETON_GROUND_PASS: 18 meshes, 10 clips, 6x2 attacks, joints connected, 3 IK supports")
    quit(0)
