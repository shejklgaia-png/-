extends SceneTree
## v349: all lock entry points obey Bittaran's actual 1.15s IK down window.
const LOCK = preload("res://scripts/sera_lock_management.gd")
const SHINS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]

func _initialize() -> void:
    call_deferred("_run")

func _fail(detail: String) -> void:
    push_error("V349_BITTARAN_LOCK_FAIL: " + detail)
    quit(1)

func _assert_standing_only_shins(parts: Node3D, center: Vector3) -> bool:
    for i in range(24):
        var radians: float = TAU * float(i) / 24.0
        var actor: Vector3 = center + Vector3(sin(radians) * 13.0, 0.0,
            cos(radians) * 13.0)
        var auto: String = str(parts.call("select_actor_parallel_lines_part",
            actor, center))
        if not SHINS.has(auto):
            _fail("standing AUTO selected a weakpoint/BODY at angle " + str(i)
                + ": " + auto)
            return false
    return true

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("scene load")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var parts: Node3D = battle.get("target_parts")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if parts == null or ik == null or boss == null or player == null:
        _fail("boss parts, IK or actor missing")
        return
    if bool(parts.get("down_lock_enabled")):
        _fail("weakpoints opened at spawn without a down")
        return
    for id in ["", "body", "head"]:
        if bool(parts.call("can_lock_boss_part", id)):
            _fail("standing boss permits core weakpoint: " + id)
            return
    var visible: Array = parts.call("get_visible_part_ids",
        player.global_position, battle.call("_target_hit_aabb"))
    if visible.size() != 4 or visible.has("head") or visible.has("body"):
        _fail("MANUAL standing candidate catalog is not 4 shins: " + str(visible))
        return
    if not _assert_standing_only_shins(parts, boss.global_position):
        return
    for id in ["head", "body", ""]:
        battle.set("locked_target_part_id", id)
        battle.call("_update_bittaran_lock_permissions")
        if not SHINS.has(str(battle.get("locked_target_part_id"))):
            _fail("existing " + id + " lock was retained while upright")
            return
    # Actual leg destruction starts the short stumble window immediately.
    battle.set("locked_target_part_id", "leg_fr")
    var broken: Dictionary = battle.call("_apply_target_part_damage",
        "melee", 1, 240.0, 0.0, 0.0)
    if not bool(broken.get("broken", false)) or not bool(
            ik.call("break_reaction_active")):
        _fail("shin break did not start boss down")
        return
    if not bool(parts.get("down_lock_enabled")):
        _fail("head/body not opened on breaking frame")
        return
    for id in ["", "body", "head"]:
        if not bool(parts.call("can_lock_boss_part", id)):
            _fail("downed boss cannot lock " + id)
            return
    visible = parts.call("get_visible_part_ids", player.global_position,
        battle.call("_target_hit_aabb"))
    if not visible.has("head") or not visible.has("body") or visible.size() != 6:
        _fail("downed manual catalog did not expose both weakpoints")
        return
    # Both explicit BODY (manual) and legacy empty BODY (AUTO) hit the same
    # unbreakable core, rather than accidentally creating a sixth break gauge.
    var core_hit: Dictionary = parts.call("apply_part_hit", "body", 16.0, 70.0)
    if not str(core_hit["part"]).is_empty() or bool(core_hit["broken"]):
        _fail("explicit manual BODY hit did not route to the core")
        return
    battle.set("locked_target_part_id", "head")
    battle.call("_update_bittaran_lock_permissions")
    if str(battle.get("locked_target_part_id")) != "head":
        _fail("downed HEAD lock was rejected")
        return
    battle.set("locked_target_part_id", "body")
    battle.call("_update_bittaran_lock_permissions")
    if str(battle.get("locked_target_part_id")) != "body":
        _fail("downed manual BODY lock was rejected")
        return
    var duration: float = 0.0
    for frame in range(78):
        var dt: float = 1.0 / 60.0
        duration += dt
        (battle.get("bittaran_rig") as Node3D).call("set_motion", "Idle", dt)
        ik.call("advance_ik", dt, "Idle")
        parts.call("sync_bittaran_parts")
        battle.call("_update_bittaran_lock_permissions")
        if bool(ik.call("break_reaction_active")) and not bool(
                parts.get("down_lock_enabled")):
            _fail("weakpoints closed early during the actual down")
            return
    if bool(parts.get("down_lock_enabled")) or bool(
            ik.call("break_reaction_active")):
        _fail("head/body never closed after stand-up")
        return
    if not SHINS.has(str(battle.get("locked_target_part_id"))):
        _fail("manual BODY lock did not redirect to a shin on recovery")
        return
    if not _assert_standing_only_shins(parts, boss.global_position):
        return
    battle.set("locked_target_part_id", "head")
    battle.call("_update_bittaran_lock_permissions")
    if not SHINS.has(str(battle.get("locked_target_part_id"))):
        _fail("manual HEAD lock persisted after recovery")
        return
    battle.call("_reset_target_after_respawn")
    if bool(parts.get("down_lock_enabled")) or not SHINS.has(
            str(battle.get("locked_target_part_id"))):
        _fail("new encounter failed to reset weakpoint-lock policy")
        return
    print("GODOT_V349_BITTARAN_LOCK_PASS: normal 4 shins, down 6 targets, "
        + "manual core damage, instant unlock on recovery, 24-angle AUTO")
    quit(0)
