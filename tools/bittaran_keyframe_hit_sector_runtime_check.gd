extends SceneTree
## v451: source-keyed real hit windows, floor contact and sector targeting.
## This does NOT spoof attack/mesh collisions or substitute an arbitrary
## elapsed-time timer for the imported Blockbench keyframe timeline.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const RIG = preload("res://scripts/bittaran_rig.gd")
const DT: float = 1.0 / 60.0
const CASES: Array = [
    ["leg_fl", "sweep", "なぎ払い", "FrontLeg_L", 2.04167, 2.14167, 2.50],
    ["leg_fr", "sweep", "なぎ払い_R", "FrontLeg_R", 2.04167, 2.14167, 2.50],
    ["leg_rl", "sweep", "後足なぎ払い_L", "RearLeg_L", 0.875, 0.975, 1.25],
    ["leg_rr", "sweep", "後足なぎ払い_R", "RearLeg_R", 0.875, 0.975, 1.25],
    ["leg_fl", "kick", "弾き", "FrontLeg_L", 0.25, 0.35, 0.75],
    ["leg_fr", "kick", "弾き_R", "FrontLeg_R", 0.25, 0.35, 0.75]
]

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("BITTARAN_KEYFRAME_HIT_SECTOR_FAIL " + reason)
    quit(1)

func _near(a: float, b: float, tol: float = 0.00015) -> bool:
    return absf(a - b) < tol

func _polar(distance: float, degrees: float) -> Vector3:
    var a: float = deg_to_rad(degrees)
    return Vector3(sin(a) * distance, 0.0, cos(a) * distance)

func _run() -> void:
    var direct: RefCounted = ATTACKS.new()
    for row in [
            [2.0, 0.0, "stomp"],
            [2.0, 155.0, "stomp"],
            [4.0, 0.0, "kick"],
            [4.0, 35.0, "kick"],
            [4.0, 41.0, "sweep"],
            [4.0, 85.0, "sweep"],
            [5.6, 0.0, "sweep"],
            [6.8, 80.0, "sweep"],
            [5.8, 145.0, "sweep"],
            [5.8, 176.0, ""],
            [7.3, 0.0, ""]]:
        var actual: String = direct.call("_choose_kind",
            _polar(float(row[0]), float(row[1])),
            Vector3.ZERO, 0.0)
        if actual != str(row[2]):
            _fail("wrong position-based kind " + str([row, actual]))
            return
    # New target-side and rear-leg selection must obey physical bones.
    var feet: Dictionary = {
        "leg_fl": Vector3(-1.0, 0, 1.3),
        "leg_fr": Vector3(1.0, 0, 1.3),
        "leg_rl": Vector3(-1.0, 0, -1.3),
        "leg_rr": Vector3(1.0, 0, -1.3)
    }
    for data in [
            [4.0, -34.0, "kick", "leg_fl"],
            [4.0, 34.0, "kick", "leg_fr"],
            [4.5, -147.0, "sweep", "leg_rl"],
            [4.5, 147.0, "sweep", "leg_rr"]]:
        var selected: String = direct.call("_choose_leg",
            _polar(float(data[0]), float(data[1])), feet,
            str(data[2]), Vector3.ZERO, 0.0)
        if selected != str(data[3]):
            _fail("wrong 3D leg " + str([data, selected]))
            return
    var rig: Node3D = RIG.new()
    root.add_child(rig)
    var names: Dictionary = rig.get("bone_uuid_by_name")
    var animations: Dictionary = rig.get("animations")
    for spec in CASES:
        var id: String = str(spec[0])
        var kind: String = str(spec[1])
        var clip: String = str(spec[2])
        var bone: String = str(spec[3])
        var start_key: float = float(spec[4])
        var hit_begin: float = float(spec[5])
        var hit_end: float = float(spec[6])
        if not _near(ATTACKS.source_hit_start_seconds(kind, id),
                hit_begin):
            _fail("wrong source + .10 seconds " + str(spec))
            return
        if not animations.has(clip) or not names.has(bone):
            _fail("missing canonical clip/bone " + str(spec))
            return
        var animator: Dictionary = (
            animations[clip]["animators"] as Dictionary).get(
            names[bone], {})
        var key_found: bool = false
        for key in animator.get("keyframes", []):
            if str(key.get("channel", "")) == "rotation" and (
                    _near(float(key.get("time", 0.0)), start_key)):
                key_found = true
        if not key_found:
            _fail("timing does not originate from a real Blockbench key "
                + str(spec))
            return
        for t in [start_key - 0.001, hit_begin - 0.004,
                hit_begin, hit_begin + 0.017,
                hit_end - 0.008, hit_end + 0.008]:
            var expected: bool = (
                t >= hit_begin - 0.000001 and
                t <= hit_end + 0.000001)
            if ATTACKS.source_hit_window(kind, id, t) != expected:
                _fail("attack window outside authored key range " +
                    str([spec, t, expected]))
                return
    # Actual scene pipeline: force a selected clip only to inspect
    # rendered foot-floor contact and source hit_window. The real
    # autonomous multiple-attack test is a separate registered test.
    var valid_ground_frames: int = 0
    var total_windows: int = 0
    for spec in CASES:
        var scene: PackedScene = load(
            "res://scenes/bittaran_battle.tscn")
        var battle: Node3D = scene.instantiate()
        root.add_child(battle)
        battle.set_process(false)
        battle.set_physics_process(false)
        var target: Node3D = battle.get("target")
        var player: CharacterBody3D = battle.get("player")
        var director: RefCounted = battle.get("bittaran_attacks")
        if director == null or target == null or player == null:
            _fail("live scene not initialized")
            return
        player.global_position = target.global_position + Vector3(0,0,6)
        if not director.call("force_start", str(spec[0]), str(spec[1])):
            _fail("cannot force " + str(spec))
            return
        var touched: int = 0
        var hit_frames: int = 0
        for frame_no in range(310):
            battle.call("_advance_target_motion", DT)
            var f: Dictionary = battle.get("bittaran_attack_frame")
            if f.is_empty():
                break
            battle.call("_finalize_target_pose", DT)
            var expected: bool = str(f.get("phase", "")) == "strike" and (
                ATTACKS.source_hit_window(
                    str(spec[1]), str(spec[0]), float(
                        f.get("authored_time", -1))))
            if bool(f.get("hit_window", false)) != expected:
                _fail("live director window not equal source event time "+
                    str([spec, f.get("phase"), f.get("authored_time")]))
                return
            if expected:
                hit_frames += 1
                if str(spec[1]) == "sweep" and bool(battle.call(
                        "_bittaran_striking_foot_grounded",
                        str(spec[0]))):
                    touched += 1
        if hit_frames < 2:
            _fail("real clip never reaches collision window " + str(spec))
            return
        if str(spec[1]) == "sweep" and touched == 0:
            _fail("returning sweep has no grounded hit frames " +
                str(spec))
            return
        valid_ground_frames += touched
        total_windows += hit_frames
        print("SOURCE_HIT_GEOMETRY_PASS ", spec[0], "/", spec[1],
            " source_start=", spec[5], " source_end=", spec[6],
            " window_frames=", hit_frames,
            " foot_grounded_frames=", touched)
        battle.queue_free()
    if total_windows < 50 or valid_ground_frames < 10:
        _fail("missing animated collision window samples")
        return
    rig.queue_free()
    print("GODOT_BITTARAN_KEYFRAME_HIT_SECTOR_PASS ",
        "source_events=6 position_sectors=11 limb_bearings=4",
        " windows=", total_windows,
        " grounded_sweep_frames=", valid_ground_frames,
        " real_foot_contact_required=true")
    quit(0)
