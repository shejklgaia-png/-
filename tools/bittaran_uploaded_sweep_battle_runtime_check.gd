extends SceneTree
## New uploaded full sweep live-battle regression (not a source-only
## sampler). All four attacker limbs complete the original clip with
## the three supporting soles IK-pinned while the BODY crouches/rises.
const BATTLE = preload("res://scripts/bittaran_battle.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const DT: float = 0.0333333333

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("AUTHORED_SWEEP_BATTLE_FAIL " + why)
    quit(1)

func _run() -> void:
    var total_frames: int = 0
    for active_id in IDS:
        var scene: PackedScene = load(
            "res://scenes/bittaran_battle.tscn")
        if scene == null:
            _fail("missing battle scene")
            return
        var battle: Node3D = scene.instantiate()
        root.add_child(battle)
        var director: RefCounted = battle.get("bittaran_attacks")
        var rig: Node3D = battle.get("bittaran_rig")
        var ik: RefCounted = battle.get("bittaran_foot_ik")
        var target: Node3D = battle.get("target")
        var player: CharacterBody3D = battle.get("player")
        if director == null or ik == null or rig == null or (
                target == null or player == null) or not (
                bool(rig.get("loading_ok"))):
            _fail("missing battle dependencies " + active_id)
            return
        player.global_position = target.global_position + (
            Vector3(0, 0, -7) if active_id.begins_with("leg_r")
            else Vector3(0, 0, 7))
        if not bool(director.call(
                "force_start", active_id, "sweep")):
            _fail("cannot force " + active_id)
            return
        var limbs: Array = ik.get("legs")
        var frames: int = 0
        var max_contact_error: float = 0.0
        var max_penetration: float = 0.0
        var max_shin_frame_step: float = 0.0
        var last_shin: Quaternion = Quaternion.IDENTITY
        var previous_clock: float = -0.0001
        var saw_strike: bool = false
        var saw_recovery: bool = false
        for step in range(200):
            battle.call("_advance_target_motion", DT)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                break
            battle.call("_finalize_target_pose", DT)
            if str(frame.get("kind", "")) != "sweep" or (
                    not bool(frame.get("authored_full_sweep", false))):
                _fail("incorrect live attack dispatch " + str([
                    active_id, frame]))
                return
            var clock: float = float(
                frame.get("authored_time", -1))
            if clock < previous_clock - 0.00001:
                _fail("authored timeline reversed " + active_id)
                return
            previous_clock = clock
            var phase: String = str(frame.get("phase", ""))
            if phase == "strike":
                saw_strike = true
            if phase == "recovery":
                saw_recovery = true
            for i in range(limbs.size()):
                var limb: Dictionary = limbs[i]
                var foot: Node3D = limb["foot"]
                if IK.LEG_PART_IDS[i] == active_id:
                    var lowest: float = ik.call(
                        "_source_ik_sweep_toe_lowest_world_y", limb)
                    if is_finite(lowest):
                        max_penetration = maxf(
                            max_penetration, maxf(-lowest, 0.0))
                    var shin: Node3D = limb["lower"]
                    var angle: Quaternion = (
                        shin.global_basis.get_rotation_quaternion())
                    if frames > 0:
                        max_shin_frame_step = maxf(
                            max_shin_frame_step,
                            last_shin.angle_to(angle))
                    last_shin = angle
                    continue
                var contact: Vector3 = foot.to_global(
                    limb["sole_local"] as Vector3)
                var anchor: Vector3 = limb.get(
                    "source_ik_attack_anchor", Vector3.INF)
                if anchor == Vector3.INF:
                    _fail("support has no anchor " + active_id)
                    return
                var error: float = contact.distance_to(anchor)
                max_contact_error = maxf(max_contact_error, error)
                if error > 0.105 or absf(contact.y) > 0.075:
                    _fail("support toe lost contact " + str([
                        active_id, step, clock, phase,
                        IK.LEG_PART_IDS[i], contact, anchor,
                        error, limb.get("last_error", NAN)]))
                    return
            frames += 1
            if step >= 199:
                _fail("sweep never finished " + active_id)
                return
        print("LIVE_FULL_SWEEP ", active_id,
            " frames=", frames,
            " max_support_contact_error=", max_contact_error,
            " max_toe_penetration=", max_penetration,
            " max_shin_delta_rad=", max_shin_frame_step)
        if not saw_strike or not saw_recovery or frames < 35:
            _fail("full sweep timeline incomplete " + str([
                active_id, frames, saw_strike, saw_recovery]))
            return
        if max_penetration > 0.08:
            _fail("attacker mesh deeply below floor " + str([
                active_id, max_penetration]))
            return
        if max_shin_frame_step > 1.40:
            _fail("attacker shin jump " + str([
                active_id, max_shin_frame_step]))
            return
        total_frames += frames
        battle.queue_free()
    print("GODOT_AUTHORED_SWEEP_LIVE_BATTLE_PASS ",
        "four_legs=true frames=", total_frames,
        " three_supports_planted=true no_deep_toe_clip=true")
    quit(0)
