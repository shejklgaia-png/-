extends SceneTree
## v348: real shin target locations, independent hit FX and break-time fall.
const LIMIT: float = 0.18

func _initialize() -> void:
    call_deferred("_run")

func _fail(detail: String) -> void:
    push_error("V348_BITTARAN_PARTS_FAIL: " + detail)
    quit(1)

func _colour_for(parts: Node3D, id: String) -> Color:
    var records: Array = parts.get("fx_meshes")[id]
    if records.is_empty():
        return Color.TRANSPARENT
    var mat: StandardMaterial3D = records[0]["material"]
    return mat.albedo_color

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("scene missing")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var parts: Node3D = battle.get("target_parts")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    if parts == null or ik == null or rig == null or not bool(parts.get("installed")):
        _fail("Bittaran specialized parts are not installed")
        return
    var expected: Dictionary = {
        "leg_fl": "FrontLowerLeg_L", "leg_fr": "FrontLowerLeg_R",
        "leg_rl": "RearLowerLeg_L", "leg_rr": "RearLowerLeg_R"
    }
    if parts.get("parts").size() != 5 or parts.get("camera_areas").size() != 6:
        _fail("not exactly 6 lock slots (BODY + HEAD + four SHINS)")
        return
    for id in expected:
        var bone: Node3D = rig.find_child(expected[id], true, false) as Node3D
        if bone == null:
            _fail("missing shin bone " + id)
            return
        var area: Area3D = parts.get("camera_areas")[id]
        if area.get_parent() != bone:
            _fail("camera lock does not follow actual shin: " + id)
            return
        var box: AABB = parts.call("get_part_aabb", id)
        if not box.has_point(bone.global_position):
            # Lower bone origin can sit on its geometric edge. Require near
            # the real shin mesh rather than an unrelated dummy coordinate.
            if bone.global_position.distance_to(box.get_center()) > 3.0:
                _fail("shin lock is spatially detached: " + id)
                return
    var body_area: Area3D = parts.get("camera_areas")[""]
    if body_area.get_parent() != rig.find_child("Body", true, false):
        _fail("BODY lock not attached to Body bone")
        return

    # Each shin is a different damage gauge, but its entire 3-bone leg
    # flashes. HEAD and BODY must never flash one another.
    var baseline: Dictionary = {}
    for id in ["", "head", "leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        baseline[id] = _colour_for(parts, id)
        if baseline[id] == Color.TRANSPARENT:
            _fail("no independent material for " + id)
            return
    parts.call("trigger_part_hit_fx", "leg_fl", 0.14)
    parts.call("advance_part_hit_fx", 0.0)
    for id in baseline:
        var changed: bool = _colour_for(parts, id) != baseline[id]
        if changed != (id == "leg_fl"):
            _fail("shin visual effect leaked to another module: " + id)
            return
    parts.call("advance_part_hit_fx", 0.3)
    parts.call("trigger_part_hit_fx", "head", 0.14)
    parts.call("advance_part_hit_fx", 0.0)
    for id in baseline:
        var changed: bool = _colour_for(parts, id) != baseline[id]
        if changed != (id == "head"):
            _fail("HEAD effect not exclusive: " + id)
            return
    parts.call("advance_part_hit_fx", 0.3)
    parts.call("trigger_part_hit_fx", "", 0.14)
    parts.call("advance_part_hit_fx", 0.0)
    for id in baseline:
        var changed: bool = _colour_for(parts, id) != baseline[id]
        if changed != id.is_empty():
            _fail("BODY effect not exclusive: " + id)
            return
    parts.call("advance_part_hit_fx", 0.3)

    # Actually apply a breaking blow using the game's regular damage pipeline.
    battle.set("locked_target_part_id", "leg_fl")
    var head_before: float = (parts.call("get_part_aim_world", "head") as Vector3).y
    var start_foot: Vector3 = Vector3.ZERO
    for leg in ik.get("legs"):
        if (leg["upper"] as Node3D).name == "FrontLeg_L":
            start_foot = leg["anchor"]
    var hit: Dictionary = battle.call("_apply_target_part_damage",
        "melee", 1, 240.0, 0.0, 0.0)
    if not bool(hit.get("broken", false)) or str(hit.get("kind", "")) != "leg":
        _fail("real shin damage did not destroy its leg")
        return
    if not bool(ik.call("break_reaction_active")):
        _fail("leg break did not trigger skid/collapse")
        return
    if not bool(parts.call("is_targetable", "leg_fl")):
        _fail("destroyed shin stopped being attackable")
        return

    var lowered: float = INF
    var farthest: float = 0.0
    var highest_error: float = 0.0
    for frame in range(250):
        var delta: float = 1.0 / 60.0
        rig.call("set_motion", "Idle", delta)
        ik.call("advance_ik", delta, "Idle")
        parts.call("sync_bittaran_parts")
        var head_now: float = (parts.call("get_part_aim_world", "head") as Vector3).y
        lowered = minf(lowered, head_now)
        for leg in ik.get("legs"):
            if (leg["upper"] as Node3D).name == "FrontLeg_L":
                var anchor: Vector3 = leg["anchor"]
                farthest = maxf(farthest, Vector2(
                    anchor.x - start_foot.x,
                    anchor.z - start_foot.z).length())
                if absf(anchor.y) > 0.001:
                    _fail("broken foot skidded vertically through floor")
                    return
        highest_error = maxf(highest_error, float(ik.call("maximum_ground_error")))
    var head_after: float = (parts.call("get_part_aim_world", "head") as Vector3).y
    if farthest < 0.5:
        _fail("broken leg did not visibly slide: " + str(farthest))
        return
    if head_before - lowered < 0.15:
        _fail("head did not descend to melee height: " + str(head_before - lowered))
        return
    if lowered < 1.12 or lowered > 1.55:
        _fail("head did not settle at a safe reachable height: " + str(lowered))
        return
    if highest_error > 0.12:
        _fail("leg-break collapse pulled planted feet off the ground: " + str(highest_error))
        return
    if absf(head_after - head_before) > LIMIT or bool(ik.call("break_reaction_active")):
        _fail("boss did not quickly recover original stance")
        return
    # Independently break each of the remaining three shins. Every bone
    # mapping must move *its own* foot, not a shared or mirrored wrong leg.
    var remaining: Dictionary = {
        "leg_fr": "FrontLeg_R",
        "leg_rl": "RearLeg_L",
        "leg_rr": "RearLeg_R"
    }
    for broken_id in remaining:
        parts.call("reset_parts")
        rig.call("apply_pose", "Wait", 0.0)
        ik.call("reset")
        parts.call("sync_bittaran_parts")
        var selected_leg_name: String = str(remaining[broken_id])
        var selected_anchor := Vector3.ZERO
        for leg in ik.get("legs"):
            if (leg["upper"] as Node3D).name == selected_leg_name:
                selected_anchor = leg["anchor"]
        battle.set("locked_target_part_id", broken_id)
        var next_hit: Dictionary = battle.call("_apply_target_part_damage",
            "melee", 1, 240.0, 0.0, 0.0)
        if not bool(next_hit.get("broken", false)):
            _fail("other shin was not breakable: " + broken_id)
            return
        var skid: float = 0.0
        var next_lowest: float = INF
        for tick in range(250):
            var dt: float = 1.0 / 60.0
            rig.call("set_motion", "Idle", dt)
            ik.call("advance_ik", dt, "Idle")
            parts.call("sync_bittaran_parts")
            next_lowest = minf(next_lowest,
                (parts.call("get_part_aim_world", "head") as Vector3).y)
            for leg in ik.get("legs"):
                if (leg["upper"] as Node3D).name == selected_leg_name:
                    var a: Vector3 = leg["anchor"]
                    skid = maxf(skid, Vector2(
                        a.x - selected_anchor.x, a.z - selected_anchor.z).length())
        if skid < 0.5 or next_lowest < 1.12 or next_lowest > 1.55:
            _fail("wrong sliding leg/head height " + broken_id + " skid="
                + str(skid) + " head=" + str(next_lowest))
            return
        if bool(ik.call("break_reaction_active")):
            _fail("reaction failed to recover for " + broken_id)
            return
    print("GODOT_V348_BITTARAN_PARTS_PASS: all 4 shin breaks, 6 locks, isolated FX, skid="
        + str(farthest) + " head before/min/after="
        + str(head_before) + "/" + str(lowered) + "/"
        + str(head_after) + " max IK error=" + str(highest_error))
    quit(0)
