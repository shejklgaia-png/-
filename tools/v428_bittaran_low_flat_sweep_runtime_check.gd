extends SceneTree
## v430 contract for the original v428 sweep regression: connected
## toe tilt emerges from BODY lowering, never independent mesh rotation.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 0.05
const AXIS_ANGLE_TOLERANCE: float = 0.32

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V428_LOW_SWEEP_FAIL: " + reason)
    quit(1)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("battle scene not found")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var foot_ik: RefCounted = battle.get("bittaran_foot_ik")
    var attack_director: RefCounted = battle.get("bittaran_attacks")
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if foot_ik == null or attack_director == null:
        _fail("Bittaran IK/director missing")
        return
    var summary: Dictionary = {}
    for repeat in range(2):
        for id in ["leg_fl", "leg_fr"]:
            battle.call("_reset_target_after_respawn")
            player.global_position = target.global_position + Vector3(0.0, 0.0, 7.0)
            if not bool(attack_director.call("force_start", id, "sweep")):
                _fail("cannot start authored sweep " + id)
                return
            var leg: Dictionary = foot_ik.get("legs")[IK.LEG_PART_IDS.find(id)]
            var foot: Node3D = leg["foot"]
            var axis_local: Vector3 = foot_ik.call("_toe_axis_local_point", foot)
            var max_tilt: float = 0.0
            var max_foot_gap: float = 0.0
            var max_drop: float = 0.0
            var fully_horizontal_frames: int = 0
            var drop_at_contact: float = 0.0
            for tick in range(120):
                battle.call("_advance_target_motion", DT)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                if frame.is_empty():
                    break
                battle.call("_finalize_target_pose", DT)
                var time: float = float(frame.get("time", 0.0))
                var drop: float = -float(foot_ik.get("front_attack_drop_world"))
                max_drop = maxf(max_drop, drop)
                if not is_finite(drop) or drop > (
                        IK.FRONT_SWEEP_MAX_DROP_METERS + 0.002):
                    _fail("unbounded BODY offset " + str([id,drop]))
                    return
                if time >= 0.77 and time <= 1.60:
                    var world_axis: Vector3 = (
                        foot.global_basis * axis_local).normalized()
                    var tilt: float = absf(world_axis.y)
                    max_tilt = maxf(max_tilt, tilt)
                    if tilt > AXIS_ANGLE_TOLERANCE:
                        _fail("sweep toe is not horizontal: "
                            + str([id,time,tilt]))
                        return
                    fully_horizontal_frames += 1
                    if bool(leg.get("front_sweep_contact", false)):
                        var low: float = float(foot_ik.call(
                            "_foot_mesh_lowest_y", foot))
                        max_foot_gap = maxf(max_foot_gap, absf(low))
                        if absf(low) > 0.028:
                            _fail("flattened toe left arena floor: "
                                + str([id,time,low]))
                            return
                        drop_at_contact = maxf(drop_at_contact,drop)
            if fully_horizontal_frames < 8:
                _fail("no sustained flat sweeping frames")
                return
            if drop_at_contact < 0.30:
                _fail("BODY did not lower for anatomically connected sweep: "
                    + str([id,drop_at_contact,max_drop]))
                return
            var key: String = id
            if repeat == 0:
                summary[key] = max_drop
            elif absf(max_drop - float(summary[key])) > 0.12:
                _fail("lower stance drifted across repeated attacks: "
                    + str([id,summary[key],max_drop]))
                return
            print("V428_SWEEP_CASE ", id, " repeat=", repeat,
                " max_drop=", max_drop, " flat_tilt=", max_tilt,
                " toe_gap=", max_foot_gap, " contact_drop=", drop_at_contact)
            # Finish the leg-home and BODY-rise stages fully.
            for tick in range(40):
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
            if bool(foot_ik.call("front_height_recovery_active")):
                _fail("BODY not returned to neutral")
                return
    print("GODOT_V428_SWEEP_CONNECTED_PASS: both front legs, height-driven toe angle, floor safety, no drift")
    quit(0)
