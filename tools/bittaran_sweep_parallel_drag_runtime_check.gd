extends SceneTree
## Focused live-bone regression, independent of the full battle scene.
## Runs actual authored sweep clips -> parallel recovery -> source ground
## IK; monitors the distal toe's XZ line and lower-shin rotation.
const Rig = preload("res://scripts/bittaran_rig.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const CASES: Array = [
    ["leg_fl", "なぎ払い", 1.50, "FrontFoot_L"],
    ["leg_fr", "なぎ払い_R", 1.50, "FrontFoot_R"],
    ["leg_rl", "後足なぎ払い_L", 0.75, "RearFoot_L"],
    ["leg_rr", "後足なぎ払い_R", 0.75, "RearFoot_R"]
]
const RETURN_SECONDS: float = 1.20
const FRAMES: int = 72

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SWEEP_PARALLEL_DRAG_FAIL: " + message)
    quit(1)

func _run() -> void:
    for settings in CASES:
        var id: String = str(settings[0])
        var clip: String = str(settings[1])
        var clip_length: float = float(settings[2])
        var foot_name: String = str(settings[3])
        var host: Node3D = Node3D.new()
        host.scale = Vector3.ONE * 0.145
        root.add_child(host)
        var rig: Node3D = Rig.new()
        host.add_child(rig)
        if not bool(rig.get("loading_ok")):
            _fail("rig did not load for " + id)
            return
        var foot: Node3D = rig.find_child(
            foot_name, true, false) as Node3D
        if foot == null:
            _fail("missing real foot: " + id)
            return
        var ik: RefCounted = IK.new()
        var sole: Vector3 = ik.call("_sole_local_point", foot)
        host.position.y -= foot.to_global(sole).y
        if not bool(ik.call("setup", rig, true)):
            _fail("IK setup failed: " + id)
            return
        if not bool(ik.call("initialize_source_ground_ik")):
            _fail("source IK failed: " + id)
            return
        var limb_index: int = IK.LEG_PART_IDS.find(id)
        var limb: Dictionary = ik.get("legs")[limb_index]
        rig.call("apply_source_clip_exact", clip, clip_length)
        ik.call("_source_ik_advance_attack", {
            "id": id, "kind": "sweep", "phase": "strike",
            "time": 0.01, "parallel_recovery": true,
            "authored_time": clip_length
        })
        var previous_shin: Quaternion = Quaternion.IDENTITY
        var previous_progress: float = -0.0001
        var max_lateral: float = 0.0
        var max_shin_jump: float = 0.0
        var max_below_floor: float = 0.0
        var samples: int = 0
        for step in range(FRAMES + 1):
            var u: float = float(step) / float(FRAMES)
            var frame: Dictionary = {
                "id": id, "kind": "sweep", "phase": "recovery",
                "recovery_stage": "parallel",
                "parallel_recovery": true,
                "source_timed_attack": true,
                "authored_time": clip_length,
                "phase_elapsed": RETURN_SECONDS * u,
                "leg_return_seconds": RETURN_SECONDS,
                "body_return_seconds": 1.40,
                "time": 0.02 + RETURN_SECONDS * u
            }
            rig.call("apply_original_attack_only", frame)
            ik.call("_source_ik_advance_attack", frame)
            var from: Vector3 = limb.get(
                "source_ik_leg_return_from", Vector3.INF)
            var tip_local: Vector3 = limb.get(
                "source_ik_leg_return_contact_local", Vector3.INF)
            if from == Vector3.INF or tip_local == Vector3.INF:
                _fail("no distal toe pin for " + id)
                return
            var tip: Vector3 = (limb["foot"] as Node3D).to_global(
                tip_local)
            var neutral: Quaternion = ik.call(
                "_source_ik_toe_down_rotation", limb,
                ik.call("_rotation_home", limb))
            var offset: Vector3 = (
                Basis(neutral).scaled(
                    (limb["foot"] as Node3D).global_basis.get_scale())
                * (tip_local - (limb["sole_local"] as Vector3)))
            var home: Vector3 = ik.call("_source_ik_home", limb)
            home += offset
            var line: Vector2 = Vector2(
                home.x - from.x, home.z - from.z)
            var moved: Vector2 = Vector2(
                tip.x - from.x, tip.z - from.z)
            if line.length_squared() > 0.000001:
                var progress: float = (
                    moved.dot(line) / line.length_squared())
                var lateral: float = absf(
                    line.x * moved.y - line.y * moved.x
                    ) / line.length()
                max_lateral = maxf(max_lateral, lateral)
                if progress + 0.035 < previous_progress:
                    _fail("toe reversed: " + str(
                        [id, step, progress, previous_progress]))
                    return
                previous_progress = progress
            var shin: Node3D = limb["lower"]
            var shin_rotation: Quaternion = (
                shin.global_basis.get_rotation_quaternion())
            if step > 0:
                max_shin_jump = maxf(max_shin_jump,
                    previous_shin.angle_to(shin_rotation))
            previous_shin = shin_rotation
            var lowest: float = ik.call(
                "_source_ik_sweep_toe_lowest_world_y", limb)
            if is_finite(lowest):
                max_below_floor = maxf(
                    max_below_floor, maxf(-lowest, 0.0))
            samples += 1
        print("SWEEP_DRAG_CASE ", id,
            " lateral=", max_lateral,
            " max_shin_step_radians=", max_shin_jump,
            " toe_floor_penetration=", max_below_floor)
        if max_lateral > 0.35 or max_shin_jump > 1.20:
            _fail("visual shin/toe return discontinuity: " + str(
                [id, max_lateral, max_shin_jump]))
            return
        if samples != FRAMES + 1:
            _fail("missing recovery frames")
            return
        host.queue_free()
    print("GODOT_SWEEP_PARALLEL_DRAG_PASS all_four_legs=true")
    quit(0)
