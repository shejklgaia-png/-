extends SceneTree
## v430 revalidation of v429's STOMP-inspired foot return: visible shin
## remains linked; its mesh must NOT be forcibly leveled independently.
## Test two complete cycles without resetting the arena between attacks.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 0.05

func _initialize() -> void:
    call_deferred("_run")

func _fail(detail: String) -> void:
    push_error("V429_SHIN_RETURN_FAIL: " + detail)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("battle scene not loadable")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var director: RefCounted = battle.get("bittaran_attacks")
    var player: CharacterBody3D = battle.get("player")
    var target: Node3D = battle.get("target")
    if ik == null or director == null:
        _fail("battle IK and attack director missing")
        return
    var completed: int = 0
    var baseline: Dictionary = {}
    for repeat in range(2):
        for id in ["leg_fl", "leg_fr"]:
            var index: int = IK.LEG_PART_IDS.find(id)
            var leg: Dictionary = ik.get("legs")[index]
            var shin: Node3D = leg["lower"]
            var foot: Node3D = leg["foot"]
            var shin_mesh: MeshInstance3D
            for node in shin.get_children():
                if node is MeshInstance3D:
                    shin_mesh = node
                    break
            if shin_mesh == null:
                _fail("no shin mesh " + id)
                return
            var neutral_shin_mesh: Quaternion = shin_mesh.quaternion
            for kind in ["sweep", "stomp", "kick"]:
                player.global_position = (
                    target.global_position + Vector3(0.0, 0.0, 7.0))
                if not bool(director.call("force_start", id, kind)):
                    _fail("cannot force front attack " + id + "/" + kind)
                    return
                var sweep_frames: int = 0
                var worst_toe_tilt: float = 0.0
                var worst_shin_tilt: float = 0.0
                var worst_toe_contact: float = 0.0
                var seen_return: bool = false
                var max_lift_goal: float = 0.0
                var peak_toe_mesh_y: float = -INF
                var entry_toe_mesh_y: float = 0.0
                var saw_raise_sample: bool = false
                var saw_height_rise: bool = false
                var low_body_at_start: float = 0.0
                var return_count: int = 0
                for tick in range(160):
                    battle.call("_advance_target_motion", DT)
                    var frame: Dictionary = battle.get("bittaran_attack_frame")
                    battle.call("_finalize_target_pose", DT)
                    var in_return: bool = bool(ik.call(
                        "front_height_recovery_active"))
                    if kind == "sweep" and not frame.is_empty():
                        var t: float = float(frame.get("time", 0.0))
                        if t >= 0.77 and t <= 1.60:
                            # The original v429 flatten-by-rotating-mesh
                            # requirement was superseded. Verify the shin
                            # mesh's imported local rotation never changes;
                            # only shoulder/knee hinge motion is allowed.
                            if shin_mesh.quaternion.angle_to(
                                    neutral_shin_mesh) > 0.0005:
                                _fail("independent shin mesh rotation " +
                                    str([id, t]))
                                return
                            var foot_axis_local: Vector3 = ik.call(
                                "_toe_axis_local_point", foot)
                            var toe_long_world: Vector3 = (
                                foot.global_basis * foot_axis_local).normalized()
                            worst_toe_tilt = maxf(worst_toe_tilt,
                                absf(toe_long_world.y))
                            if absf(toe_long_world.y) > 0.32:
                                _fail("connected sweep toe tilt beyond reach: "+
                                    str([id,t,toe_long_world.y]))
                                return
                            var toe_low: float = float(ik.call(
                                "_foot_mesh_lowest_y", foot))
                            worst_toe_contact = maxf(
                                worst_toe_contact, absf(toe_low))
                            if absf(toe_low) > 0.028:
                                _fail("sweep toe left floor")
                                return
                            sweep_frames += 1
                    if in_return:
                        var rt: float = float(ik.get("front_return_elapsed"))
                        var low: float = float(ik.get(
                            "front_attack_drop_world"))
                        if not seen_return:
                            seen_return = true
                            low_body_at_start = low
                            entry_toe_mesh_y = float(ik.call(
                                "_foot_mesh_lowest_y", foot))
                        if rt <= IK.FRONT_STANCE_RETURN_SECONDS:
                            if absf(low - low_body_at_start) > 0.01:
                                _fail("BODY rose before the leg returned")
                                return
                            var toe_y: float = float(ik.call(
                                "_foot_mesh_lowest_y", foot))
                            peak_toe_mesh_y = maxf(peak_toe_mesh_y, toe_y)
                            max_lift_goal = maxf(max_lift_goal,
                                float(ik.get("front_return_lift_world")))
                            if rt >= 0.18 and rt <= 0.26:
                                saw_raise_sample = true
                                if float(ik.get("front_return_lift_world")) < 0.48:
                                    _fail("no STOMP-like raised mid-return")
                                    return
                        elif rt > IK.FRONT_STANCE_RETURN_SECONDS + 0.10:
                            saw_height_rise = true
                        return_count += 1
                    if seen_return and not in_return:
                        break
                if kind == "sweep" and sweep_frames < 8:
                    _fail("insufficient flattened shin strike frames")
                    return
                if not seen_return or not saw_raise_sample or not saw_height_rise:
                    _fail("missing two-phase raised foot return " +
                        id + "/" + kind)
                    return
                if max_lift_goal < 0.62:
                    _fail("foot arc never reached lift apex " + str(max_lift_goal))
                    return
                if peak_toe_mesh_y < entry_toe_mesh_y + 0.16:
                    _fail("actual visible toe did not lift " +
                        str([id, kind, entry_toe_mesh_y, peak_toe_mesh_y]))
                    return
                if absf(float(ik.get("front_return_lift_world"))) > 0.00001:
                    _fail("foot lift cache survived recovery")
                    return
                if bool(ik.call("front_height_recovery_active")):
                    _fail("BODY/leg recovery is still active")
                    return
                if leg.has("front_sweep_shin_mesh_original"):
                    _fail("temporary shin mesh orientation cached after attack")
                    return
                if shin_mesh.quaternion.angle_to(neutral_shin_mesh) > 0.004:
                    _fail("shin mesh orientation accumulated after attack")
                    return
                var key: String = id + "/" + kind
                if repeat == 0:
                    baseline[key] = peak_toe_mesh_y - entry_toe_mesh_y
                elif absf(float(baseline[key]) -
                        (peak_toe_mesh_y - entry_toe_mesh_y)) > 0.18:
                    _fail("raised return drifted after repeats " + key)
                    return
                print("V429_CASE ", key, " repeat=", repeat,
                    " shin_y_axis=", worst_shin_tilt,
                    " toe_y_axis=", worst_toe_tilt,
                    " toe_floor=", worst_toe_contact,
                    " lifted_toe=", peak_toe_mesh_y - entry_toe_mesh_y,
                    " lift_arc=", max_lift_goal)
                completed += 1
    if completed != 12:
        _fail("not all 12 attacks finished")
        return
    print("GODOT_V429_RETURN_CONNECTED_PASS: 12 attacks, unchanged shin mesh, STOMP-style lift, no drift")
    quit(0)
