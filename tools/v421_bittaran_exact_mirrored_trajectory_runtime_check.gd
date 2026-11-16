extends SceneTree
## The four attack trajectories must be the reflection of ONE
## immutable front-left clip in the rig's anatomical world frame.
## Unlike a joint-quaternion-only assertion, this compares knee,
## ankle and end-effector positions as well as orientation, for
## both KICK and SWEEP over the complete authored source timeline.
const KINDS: Array[String] = ["kick", "sweep"]
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const TIMES: Array[float] = [
    0.0, 0.016666667, 0.125, 0.25, 0.35, 0.5, 0.625, 0.75, 0.9]
const POSITION_ERROR_METERS: float = 0.002
const ROTATION_ERROR_DEGREES: float = 0.12


func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    push_error("V421_SOURCE_SPACE_MIRROR_FAIL: " + why)
    quit(1)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if rig == null or ik == null:
        _fail("missing scene rig or IK")
        return
    var frame: Basis = rig.global_basis.orthonormalized()
    var inv: Basis = frame.inverse()
    var original_sole: Vector3 = ik.get("legs")[0][
        "source_sole_local"]
    var largest_position_error: float = 0.0
    var largest_rotation_error: float = 0.0
    var comparisons: int = 0
    for kind in KINDS:
        var sampler: String = (
            "sample_authored_kick_source" if kind == "kick"
            else "sample_authored_sweep_source")
        for t in TIMES:
            var source: Dictionary = rig.call(
                sampler, "leg_fl", t, original_sole)
            if source.is_empty():
                _fail("missing front-left clip " + kind)
                return
            for id in IDS:
                var names: Array = rig.ATTACK_LEG_BONES[id]
                var transforms: Array[Transform3D] = []
                for bone_name in names:
                    var joint: Node3D = rig.find_child(
                        str(bone_name), true, false)
                    transforms.append(joint.global_transform)
                var result: Dictionary = rig.call(
                    sampler, id, t, original_sole)
                if result.is_empty():
                    _fail(kind + "/" + id + " source missing")
                    return
                var reflected: Vector3 = Vector3(
                    -1.0 if id.ends_with("r") else 1.0,
                    1.0, -1.0 if id.begins_with("leg_r") else 1.0)
                var hip: Vector3 = result["hip"]
                for key in ["knee", "foot", "sole"]:
                    var expected: Vector3 = hip + frame * (
                        (inv * ((source[key] as Vector3)
                            - (source["hip"] as Vector3)))
                        * reflected)
                    var error: float = expected.distance_to(
                        result[key] as Vector3)
                    largest_position_error = maxf(
                        largest_position_error, error)
                    if error > POSITION_ERROR_METERS:
                        _fail(kind + "/" + id + " at " + str(t)
                            + " " + key + " is not mirrored: "
                            + str(error) + "m")
                        return
                var expected_q: Quaternion = source["rotation"]
                if id.ends_with("r"):
                    expected_q = rig.call(
                        "_reflect_world_rotation",
                        expected_q, frame.x.normalized())
                if id.begins_with("leg_r"):
                    expected_q = rig.call(
                        "_reflect_world_rotation",
                        expected_q, frame.z.normalized())
                var angle: float = rad_to_deg(
                    expected_q.angle_to(
                        result["rotation"] as Quaternion))
                largest_rotation_error = maxf(
                    largest_rotation_error, angle)
                if angle > ROTATION_ERROR_DEGREES:
                    _fail(kind + "/" + id
                        + " foot orientation not mirrored "
                        + str(angle) + "deg")
                    return
                for i in range(names.size()):
                    var restored: Node3D = rig.find_child(
                        str(names[i]), true, false)
                    if not restored.global_transform.is_equal_approx(
                            transforms[i]):
                        _fail("sampler mutates original joint "
                            + str(names[i]))
                        return
                comparisons += 1
    if comparisons != 72:
        _fail("sample coverage incomplete " + str(comparisons))
        return
    print("GODOT_V421_SOURCE_SPACE_MIRROR_PASS: "
        + str(comparisons) + " source trajectories; "
        + "max_pos_error=" + str(largest_position_error)
        + " max_angle_deg=" + str(largest_rotation_error)
        + " no persistent joint mutation")
    quit(0)
