extends SceneTree
## v430 anatomical SWEEP: no post-hoc mesh flattening, local ankle source
## retained, no joint offset, body drop chosen by connected IK, no roll drift.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 0.05

func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    push_error("V430_CONNECTED_SWEEP_FAIL: " + msg)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("missing battle scene")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    var player: CharacterBody3D = battle.get("player")
    var target: Node3D = battle.get("target")
    if ik == null or director == null:
        _fail("combat IK missing")
        return
    var first_samples: Dictionary = {}
    for iteration in range(2):
        for id in ["leg_fl", "leg_fr"]:
            var index: int = IK.LEG_PART_IDS.find(id)
            var leg: Dictionary = ik.get("legs")[index]
            var upper: Node3D = leg["upper"]
            var lower: Node3D = leg["lower"]
            var foot: Node3D = leg["foot"]
            var pos_upper: Vector3 = upper.position
            var pos_lower: Vector3 = lower.position
            var pos_foot: Vector3 = foot.position
            var shin_mesh: MeshInstance3D
            var toe_mesh: MeshInstance3D
            for child in lower.get_children():
                if child is MeshInstance3D:
                    shin_mesh = child
                    break
            for child in foot.get_children():
                if child is MeshInstance3D:
                    toe_mesh = child
                    break
            if shin_mesh == null or toe_mesh == null:
                _fail("missing visible shin or toe mesh")
                return
            var shin_mesh_rotation: Quaternion = shin_mesh.quaternion
            var toe_mesh_rotation: Quaternion = toe_mesh.quaternion
            player.global_position = target.global_position + Vector3(0, 0, 7)
            if not bool(director.call("force_start", id, "sweep")):
                _fail("cannot force " + id)
                return
            var max_drop: float = 0.0
            var worst_toe_tilt: float = 0.0
            var max_contact_error: float = 0.0
            var checked: int = 0
            var stage_rotation: Quaternion = Quaternion.IDENTITY
            var stage_captured: bool = false
            for tick in range(110):
                battle.call("_advance_target_motion", DT)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                if frame.is_empty():
                    break
                battle.call("_finalize_target_pose", DT)
                var t: float = float(frame.get("time", 0.0))
                max_drop = maxf(max_drop, -float(
                    ik.get("front_attack_drop_world")))
                if upper.position.distance_to(pos_upper) > 0.00001 or (
                        lower.position.distance_to(pos_lower) > 0.00001) or (
                        foot.position.distance_to(pos_foot) > 0.00001):
                    _fail("joint pivot was translated: " + str([id, t]))
                    return
                if shin_mesh.quaternion.angle_to(shin_mesh_rotation) > 0.0005 or (
                        toe_mesh.quaternion.angle_to(toe_mesh_rotation) > 0.0005):
                    _fail("visual mesh rotation was modified: " + str([id,t]))
                    return
                if t >= 0.8 and t <= 1.60:
                    var axis: Vector3 = (
                        foot.global_basis
                        * (ik.call("_toe_axis_local_point", foot) as Vector3)
                        ).normalized()
                    var tilt: float = absf(axis.y)
                    worst_toe_tilt = maxf(worst_toe_tilt, tilt)
                    var toe_y: float = float(ik.call(
                        "_foot_mesh_lowest_y", foot))
                    max_contact_error = maxf(max_contact_error, absf(toe_y))
                    if t >= 1.00 and t <= 1.05:
                        stage_rotation = lower.global_basis
                            .orthonormalized().get_rotation_quaternion()
                        stage_captured = true
                    checked += 1
            print("V430_CONNECTED_SWEEP_DIAG: ", id,
                " pass=", iteration, " max_drop=", max_drop,
                " max_tilt=", worst_toe_tilt,
                " max_foot_y=", max_contact_error,
                " frames=", checked)
            if checked < 12 or not stage_captured:
                _fail("missing rendered strike samples " + id)
                return
            if max_drop < 0.3 or max_drop > (
                    IK.FRONT_SWEEP_MAX_DROP_METERS + 0.001):
                _fail("torso height was not searched: " + str(max_drop))
                return
            if worst_toe_tilt > 0.32:
                _fail("connected toe still tilts too far: "
                    + str([id,worst_toe_tilt]))
                return
            if max_contact_error > 0.18:
                _fail("connected toe missed the floor: " +
                    str([id,max_contact_error]))
                return
            var key: String = id
            if iteration == 0:
                first_samples[key] = {
                    "rotation": stage_rotation,
                    "drop": max_drop
                }
            else:
                var start: Dictionary = first_samples[key]
                if stage_rotation.angle_to(start["rotation"]) > 0.04:
                    _fail("repeated shin accumulated twist " + id)
                    return
                if absf(max_drop - float(start["drop"])) > 0.10:
                    _fail("repeated crouch changed height " + id)
                    return
            for j in range(45):
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
            if bool(ik.call("front_height_recovery_active")) or absf(
                    float(ik.get("front_attack_drop_world"))) > 0.0001:
                _fail("recovery state leaked into next attack")
                return
    print("GODOT_V430_CONNECTED_SWEEP_PASS: source mesh/pivots intact, body-driven toe angle, no twist or drift")
    quit(0)
