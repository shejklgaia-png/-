extends SceneTree
## Play user-authored front/rear left/right collapse clips at native 1x.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("BITTARAN_AUTHORED_DOWN_FAIL " + message)
    quit(1)

func _run() -> void:
    var scene: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(scene)
    scene.set_process(false)
    scene.set_physics_process(false)
    var rig: Node3D = scene.get("bittaran_rig")
    var ik: RefCounted = scene.get("bittaran_foot_ik")
    var parts: Node3D = scene.get("target_parts")
    if rig == null or ik == null or parts == null:
        _fail("missing real battle, rig or IK")
        return
    var cases: Dictionary = {
        "leg_fl": ["前脚ダウン_L", 2.75, 78],
        "leg_fr": ["前脚ダウン_R", 2.75, 78],
        "leg_rl": ["後足ダウン_L", 2.0, 62],
        "leg_rr": ["後足ダウン_R", 2.0, 62]
    }
    var animations: Dictionary = rig.get("animations")
    for id in cases:
        var spec: Array = cases[id]
        var clip_name: String = str(spec[0])
        if not animations.has(clip_name):
            _fail("runtime clip missing: " + clip_name)
            return
        var clip: Dictionary = animations[clip_name]
        if absf(float(clip["length"]) - float(spec[1])) > 0.001:
            _fail("source 1x clip length changed: " + clip_name)
            return
        var keys: int = 0
        for track in (clip["animators"] as Dictionary).values():
            keys += (track as Dictionary).get("keyframes", []).size()
        if keys != int(spec[2]):
            _fail("source key count changed: " + clip_name)
            return
        var head: Vector3 = parts.call("get_part_aim_world", "head")
        ik.call("start_leg_break_slide", str(id), head.y, false)
        if str(ik.get("authored_down_clip")) != clip_name:
            _fail("broken leg did not select authored clip " + str(id))
            return
        ik.set("authored_down_source_seconds", 0.50)
        ik.set("windup_elapsed", 0.95)
        ik.set("break_elapsed", -1.0)
        if absf(float(ik.call("authored_down_motion_time")) - 0.50) > 0.001:
            _fail("source-time cursor did not reach 0.50")
            return
        ik.set("authored_down_source_seconds", 1.50)
        ik.set("windup_elapsed", 3.20)
        ik.set("break_elapsed", -1.0)
        if absf(float(ik.call("authored_down_motion_time")) - 1.50) > 0.001:
            _fail("fall source clock did not sample 1.50")
            return
        rig.call("apply_authored_down_pose", clip_name,
            float(ik.call("authored_down_motion_time")), 0.0)
        var body: Node3D = rig.find_child("Body", true, false) as Node3D
        var expect: Quaternion = rig.call(
            "_authored_key_rotation", clip_name, "Body", 1.50)
        if absf(body.quaternion.dot(expect)) < 0.999:
            _fail("authored BODY rotation not played: " + clip_name)
            return
        # No wrap to the anticipation pose after the author's last key.
        rig.call("apply_authored_down_pose", clip_name, 6.0, 0.0)
        expect = rig.call("_authored_key_rotation", clip_name,
            "Body", float(spec[1]) - 0.001)
        if absf(body.quaternion.dot(expect)) < 0.999:
            _fail("held collapse pose wraps to first key: " + clip_name)
            return
        # Restore neutral with smooth, continuous original rise clock.
        rig.call("apply_authored_down_pose", clip_name, 6.0, 1.0)
        expect = rig.call("_authored_key_rotation", "Wait", "Body", 0.0)
        if absf(body.quaternion.dot(expect)) < 0.999:
            _fail("stand-up never returned BODY to Wait: " + clip_name)
            return
        ik.set("break_elapsed", -1.0)
    # A second break during the same fall may reset the down hold, but
    # it must NEVER rewind a body already on the floor to its anticipation.
    var head_last: Vector3 = parts.call("get_part_aim_world", "head")
    ik.call("start_leg_break_slide", "leg_fl", head_last.y, false)
    ik.set("authored_down_source_seconds", 1.75)
    ik.set("windup_elapsed", -1.0)
    ik.set("break_elapsed", 1.70)
    var before_repeat: float = float(
        ik.call("authored_down_motion_time"))
    ik.call("start_leg_break_slide", "leg_fr", head_last.y, false)
    var after_repeat: float = float(
        ik.call("authored_down_motion_time"))
    if after_repeat + 0.001 < before_repeat:
        _fail("repeat shin break rewound authored collapse pose")
        return
    if (absf(IK.LEG_BREAK_REACTION_SECONDS - 2.5) > 0.001
            or absf(IK.ALL_LEGS_BREAK_REACTION_SECONDS - 6.0) > 0.001
            or absf(IK.SINGLE_LEG_RISE_SECONDS - 1.0) > 0.001
            or absf(IK.FOUR_LEG_RISE_SECONDS - 1.3) > 0.001):
        _fail("existing down / recovery time changed")
        return
    print("GODOT_BITTARAN_AUTHORED_DOWN_PASS 4_clips=true source_keys=true authored_body=true")
    quit(0)
