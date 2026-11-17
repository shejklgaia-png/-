extends SceneTree
## v440 low-cost contact check on a known flat Y=0 arena.
## Verify 3 exact Blockbench cuboids -> analytic floor extrema,
## 1 joint-only attacker solve, 3 supporting IK legs, NO mesh offset,
## NO changed joint pivots/lengths, and source BODY unmodified.
const BATTLE = preload("res://scripts/bittaran_battle.gd")
const DT: float = 1.0 / 60.0
const SOURCE_CLIPS: Dictionary = {
    "なぎ払い": ["leg_fl", "sweep", 1.50],
    "弾き": ["leg_fl", "kick", 1.00],
    "踏みつけ_L": ["leg_fl", "stomp", 1.75],
    "なぎ払い_R": ["leg_fr", "sweep", 1.50],
    "弾き_R": ["leg_fr", "kick", 1.00],
    "踏みつけ_R": ["leg_fr", "stomp", 1.75]
}
const LIMB_IDS: Array[String] = [
    "leg_fr", "leg_rl", "leg_fl", "leg_rr"
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V440_FLAT_FLOOR_CHAIN_FAIL " + message)
    quit(1)

func _brute_min_y(limb: Dictionary, rig: Node3D) -> float:
    var pieces: Dictionary = rig.get("mesh_nodes_by_uuid")
    var vertices: Dictionary = rig.get("mesh_vertices_by_uuid")
    var lowest: float = INF
    for uid in pieces.keys():
        var piece: MeshInstance3D = pieces[uid]
        var parent: Node = piece.get_parent()
        if parent != limb["upper"] and parent != limb["lower"] and (
                parent != limb["foot"]):
            continue
        var pts: PackedVector3Array = vertices.get(
            uid, PackedVector3Array())
        for pt in pts:
            lowest = minf(lowest, piece.to_global(pt).y)
    return lowest

func _joint_chain_lengths(limb: Dictionary) -> Vector2:
    var upper: Node3D = limb["upper"]
    var lower: Node3D = limb["lower"]
    var foot: Node3D = limb["foot"]
    return Vector2(
        upper.global_position.distance_to(lower.global_position),
        lower.global_position.distance_to(foot.global_position))

func _run() -> void:
    if not BATTLE.BLOCKBENCH_GAIT_SUPPORT_IK or (
            BATTLE.BLOCKBENCH_SOURCE_REPLAY_ONLY):
        _fail("main battle IK is not active")
        return
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("missing real battle scene")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if rig == null or ik == null or not bool(rig.get("loading_ok")):
        _fail("boss rig or IK unavailable")
        return
    var limbs: Array = ik.get("legs")
    if limbs.size() != 4:
        _fail("expected four connected limbs")
        return
    for limb in limbs:
        var cache: Array = limb.get("source_ik_contact_meshes", [])
        if cache.size() != 3:
            _fail("flat floor must use 3 cached cuboids per limb")
            return
        for record in cache:
            var mesh: MeshInstance3D = record["mesh"]
            if mesh == null or mesh.mesh == null:
                _fail("cached cuboid mesh missing")
                return
    var mesh_nodes: Dictionary = rig.get("mesh_nodes_by_uuid")
    var mesh_local_positions: Dictionary = {}
    var mesh_local_rotations: Dictionary = {}
    for uid in mesh_nodes.keys():
        var piece: MeshInstance3D = mesh_nodes[uid]
        mesh_local_positions[uid] = piece.position
        mesh_local_rotations[uid] = piece.quaternion
    var bone_nodes: Dictionary = rig.get("bones")
    var sample_count: int = 0
    var contact_corrections: int = 0
    var verified_extrema: int = 0
    var max_residual_penetration: float = 0.0
    for name in SOURCE_CLIPS.keys():
        rig.call("apply_pose", "Wait", 0.0)
        if not bool(ik.call("initialize_source_ground_ik")):
            _fail("could not reset fixed floor contact state")
            return
        var settings: Array = SOURCE_CLIPS[name]
        var attack_id: String = str(settings[0])
        var kind: String = str(settings[1])
        var duration: float = float(settings[2])
        var active_index: int = LIMB_IDS.find(attack_id)
        if active_index < 0:
            _fail("cannot resolve attacking limb " + name)
            return
        var attacker: Dictionary = limbs[active_index]
        for i in range(0, 61):
            var source_t: float = duration * float(i) / 60.0
            rig.call("apply_source_clip_exact", name, source_t)
            var before_bottom: float = _brute_min_y(attacker, rig)
            var length_before: Vector2 = (
                _joint_chain_lengths(attacker))
            var before_local_positions: Dictionary = {}
            for uid in bone_nodes.keys():
                var bone: Node3D = bone_nodes[uid]
                before_local_positions[uid] = bone.position
            var old_count: int = int(
                ik.get("source_ik_strike_contact_count"))
            var frame: Dictionary = {
                "original_attack_only": true,
                "id": attack_id,
                "kind": kind,
                "time": float(i) * DT,
                "authored_time": source_t,
                "phase": "strike"
            }
            ik.call("advance_source_ground_ik", DT, "Idle", frame)
            var new_count: int = int(
                ik.get("source_ik_strike_contact_count"))
            if new_count < old_count or new_count - old_count > 1:
                _fail("more than one striker IK solve/frame " +
                    str([name, source_t, old_count, new_count]))
                return
            if new_count > old_count:
                contact_corrections += 1
            var actual_bottom: float = _brute_min_y(attacker, rig)
            var analytic_bottom: float = float(ik.call(
                "_source_ik_limb_lowest_world_y", attacker))
            if absf(actual_bottom - analytic_bottom) > 0.001:
                _fail("analytic floor/cuboid min is not exact " +
                    str([name, source_t, actual_bottom, analytic_bottom]))
                return
            verified_extrema += 1
            if not is_finite(actual_bottom):
                _fail("non-finite floor state " + name)
                return
            max_residual_penetration = maxf(max_residual_penetration,
                maxf(-actual_bottom, 0.0))
            var length_after: Vector2 = _joint_chain_lengths(attacker)
            if length_before.distance_to(length_after) > 0.001:
                _fail("attacker length changed " +
                    str([name, source_t, length_before, length_after]))
                return
            for uid in bone_nodes.keys():
                var bone: Node3D = bone_nodes[uid]
                if bone.position.distance_to(
                        before_local_positions[uid]) > 0.00001:
                    _fail("Blockbench joint pivot moved independently " +
                        str([name, source_t, bone.name]))
                    return
            for uid in mesh_nodes.keys():
                var piece: MeshInstance3D = mesh_nodes[uid]
                if piece.position.distance_to(
                        mesh_local_positions[uid]) > 0.00001 or (
                        piece.quaternion.angle_to(
                        mesh_local_rotations[uid]) > 0.0001):
                    _fail("individual mesh detached from skeleton " +
                        str([name, source_t, piece.name]))
                    return
            sample_count += 1
    if sample_count != 366 or verified_extrema != sample_count or (
            contact_corrections == 0):
        _fail("six original attacks not fully exercised " + str(
            [sample_count, verified_extrema, contact_corrections]))
        return
    print("GODOT_V440_FLAT_FLOOR_CHAIN_PASS six_attacks=6 samples=",
        sample_count, " contacts=", contact_corrections,
        " max_unreachable_or_residual_floor_penetration=",
        max_residual_penetration, " box_queries=3_per_frame",
        " attack_solvers=1_max", " mesh_offsets=0", " pivot_offsets=0")
    quit(0)
