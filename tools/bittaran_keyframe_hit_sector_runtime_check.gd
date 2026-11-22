extends SceneTree
## v451: source-keyed real hit windows, floor contact and sector targeting.
## This does NOT spoof attack/mesh collisions or substitute an arbitrary
## elapsed-time timer for the imported Blockbench keyframe timeline.
const ATTACKS = preload("res://scripts/bittaran_attacks.gd")
const RIG = preload("res://scripts/bittaran_rig.gd")
const DT: float = 1.0 / 60.0
const CASES: Array = [
    ["leg_fl", "sweep", "なぎ払い", "FrontLeg_L", 0.75, 0.67, 1.38],
    ["leg_fr", "sweep", "なぎ払い_R", "FrontLeg_R", 0.75, 0.67, 1.38],
    ["leg_rl", "sweep", "後足なぎ払い_L", "RearLeg_L", 0.25, 0.17, 0.63],
    ["leg_rr", "sweep", "後足なぎ払い_R", "RearLeg_R", 0.25, 0.17, 0.63],
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
    # v460: each kind is evaluated from its own LEG'S sole, not the
    # boss center. Single-foot probes isolate expanded v541 KICK sectors
    # boundaries without accidentally selecting another foot.
    for row in [
            [2.0, 0.0, "stomp", "leg_fr"],
            [2.0, 155.0, "stomp", "leg_rr"],
            [4.0, 0.0, "kick", "leg_fr"],
            [4.0, 35.0, "kick", "leg_fr"],
            [4.0, 55.0, "kick", "leg_fr"],
            [4.0, 61.0, "sweep", "leg_fr"],
            [4.0, 85.0, "sweep", "leg_fr"],
            [5.6, 0.0, "sweep", "leg_fr"],
            [6.8, 80.0, "sweep", "leg_fr"],
            [5.8, 145.0, "sweep", "leg_rr"],
            [5.8, 176.0, "", "leg_rr"],
            [7.3, 0.0, "", "leg_fr"]]:
        var one_foot: Dictionary = {
            str(row[3]): Vector3.ZERO}
        var actual: String = direct.call("_choose_kind",
            _polar(float(row[0]), float(row[1])), one_foot, 0.0)
        if actual != str(row[2]):
            _fail("wrong physical sole sector " + str([row, actual]))
            return
    # Choose the closest eligible actual foot. Front legs have KICK,
    # rear legs only SWEEP/STOMP as in the imported Blockbench asset.
    var feet: Dictionary = {
        "leg_fl": Vector3(-1.0, 0, 1.3),
        "leg_fr": Vector3(1.0, 0, 1.3),
        "leg_rl": Vector3(-1.0, 0, -1.3),
        "leg_rr": Vector3(1.0, 0, -1.3)
    }
    for data in [
            [Vector3(-2.69, 0, 4.925), "kick", "leg_fl"],
            [Vector3(2.69, 0, 4.925), "kick", "leg_fr"],
            [Vector3(-3.58, 0, -4.986), "sweep", "leg_rl"],
            [Vector3(3.58, 0, -4.986), "sweep", "leg_rr"]]:
        var selected: String = direct.call("_choose_leg",
            data[0], feet, str(data[1]), Vector3.ZERO, 0.0)
        if selected != str(data[2]):
            _fail("wrong real-foot leg " + str([data, selected]))
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
            _fail("wrong source attack onset key " + str(spec))
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
        if kind == "sweep":
            # v482: user-selected exact source seconds override v481's
            # estimated stop-relative time. Keep Blockbench's real
            # first-stroke rotation keys & separate pre-baked dirt timing.
            var requested_begin: float = (
                ATTACKS.SWEEP_REAR_HIT_START_SECONDS
                if id.begins_with("leg_r")
                else ATTACKS.SWEEP_FRONT_HIT_START_SECONDS)
            var requested_end: float = (
                ATTACKS.SWEEP_REAR_HIT_END_SECONDS
                if id.begins_with("leg_r")
                else ATTACKS.SWEEP_FRONT_HIT_END_SECONDS)
            if not _near(requested_begin, hit_begin, 0.00001) or (
                    not _near(requested_end, hit_end, 0.00001)):
                _fail("explicit sweep collision start/end changed " + str(spec))
                return
            if ATTACKS.source_hit_window(kind, id, hit_begin - 0.001) or (
                    not ATTACKS.source_hit_window(kind, id, hit_begin)) or (
                    not ATTACKS.source_hit_window(kind, id, hit_end)) or (
                    ATTACKS.source_hit_window(kind, id, hit_end + 0.001)):
                _fail("sweep collider not gated at precise user seconds")
                return
            var fx_begin: float = (
                ATTACKS.SWEEP_REAR_FIRST_STROKE_START_KEY_SECONDS
                if id.begins_with("leg_r")
                else ATTACKS.SWEEP_FRONT_FIRST_STROKE_START_KEY_SECONDS)
            var fx_end: float = (
                ATTACKS.SWEEP_REAR_FX_FIRST_STROKE_END_KEY_SECONDS
                if id.begins_with("leg_r")
                else ATTACKS.SWEEP_FRONT_FX_FIRST_STROKE_END_KEY_SECONDS)
            if ATTACKS.source_sweep_fx_window(id, fx_begin - 0.001) or (
                    not ATTACKS.source_sweep_fx_window(id, fx_begin)) or (
                    not ATTACKS.source_sweep_fx_window(id, fx_end)) or (
                    ATTACKS.source_sweep_fx_window(id, fx_end + 0.001)):
                _fail("original dirt FX time is not independent from collision")
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
        # Keep the player away from real damage until we deliberately
        # overlap a rendered attack mesh to test actual hit consumption.
        var safe_player: Vector3 = (
            target.global_position + Vector3(0, 0, 30.0))
        player.global_position = safe_player
        var parts: Node3D = battle.get("target_parts")
        if parts == null:
            _fail("missing live part hitboxes")
            return
        if not director.call("force_start", str(spec[0]), str(spec[1])):
            _fail("cannot force " + str(spec))
            return
        var touched: int = 0
        var hit_frames: int = 0
        var prevented_early_hit: bool = false
        var did_damage_inside_window: bool = false
        var afterglow_contact_blocked: bool = false
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
            # In addition to the director's metadata, exercise the
            # *actual* game damage code with the player's floor-level
            # capsule overlapping the rendered lower shin/foot.
            # The explicit 0.67/0.17s timing is authoritative, even
            # before the foot grounds; the real mesh must still overlap.
            var clip_t: float = float(f.get("authored_time", -1.0))
            var phase: String = str(f.get("phase", ""))
            var before_key_hit: bool = phase == "strike" and (
                clip_t >= float(spec[5]) - 0.080) and (
                clip_t < float(spec[5]) - 0.015)
            var should_try_hit: bool = (
                phase == "strike" and expected and
                not did_damage_inside_window)
            # Deliberately RE-ARM the one-hit latch in the test only:
            # even with a fresh hit budget the visibly grounded,
            # post-window/return must NEVER apply damage.
            var afterglow: bool = str(spec[1]) == "sweep" and (
                phase == "strike") and (
                clip_t >= float(spec[6]) + 0.06) and (
                clip_t <= float(spec[6]) + 0.12)
            if afterglow:
                director.set("hit_consumed", false)
            if (before_key_hit or should_try_hit or afterglow) and (
                    not bool(director.get("hit_consumed"))):
                var mesh_boxes: Array = parts.call(
                    "get_leg_attack_mesh_boxes", str(spec[0]))
                for raw_box in mesh_boxes:
                    var box: AABB = raw_box
                    if not box.has_volume():
                        continue
                    # The player's normal floor-level capsule, not a
                    # synthetic enlarged collision box.
                    var center: Vector3 = box.get_center()
                    player.global_position = Vector3(
                        center.x, 0.0, center.z)
                    battle.call("_check_bittaran_attack_hit")
                    player.global_position = safe_player
                    if bool(director.get("hit_consumed")):
                        break
                if before_key_hit:
                    if bool(director.get("hit_consumed")):
                        _fail("damage before authored extension/return "
                            + str([spec, clip_t]))
                        return
                    prevented_early_hit = true
                elif should_try_hit and bool(director.get(
                        "hit_consumed")):
                    did_damage_inside_window = true
                elif afterglow:
                    if bool(director.get("hit_consumed")):
                        _fail("damage during slowed afterglow " +
                            str([spec, clip_t]))
                        return
                    afterglow_contact_blocked = true
        if hit_frames < 2 or not prevented_early_hit or (
                not did_damage_inside_window) or (
                str(spec[1]) == "sweep" and
                not afterglow_contact_blocked):
            _fail("real collision did not obey keyframe window " +
                str([spec, hit_frames, prevented_early_hit,
                did_damage_inside_window,
                afterglow_contact_blocked]))
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
            " foot_grounded_frames=", touched,
            " actual_early_hit_blocked=", prevented_early_hit,
            " actual_hit_inside_window=", did_damage_inside_window,
            " afterglow_safe=", afterglow_contact_blocked)
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
