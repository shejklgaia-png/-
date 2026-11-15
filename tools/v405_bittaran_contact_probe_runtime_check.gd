extends SceneTree
## v405: the IK's actor offset is calibrated to the rig's canonical
## contact sample (initial_authored_sole_height = the author's
## original keyframe-zero pose, full Body track). v404's Body
## pitch/roll damping leaked into that sample through the rig's
## pose functions and shifted it by up to 0.65m; the offset then
## dragged the chassis to the floor during KICK/SWEEP (device
## report: the boss sprawled at chassis height 0.06m instead of
## the authored ~0.57m crouch). Part A pins the canonical sample
## values; Part B asserts the in-scene chassis crouch band for the
## affected attacks.
const DT: float = 1.0 / 60.0
const CANONICAL: Dictionary = {
    "leg_fl/kick": -0.5803, "leg_fl/sweep": 0.5232,
    "leg_fr/kick": 0.5670, "leg_fr/sweep": 0.5754,
    "leg_rl/kick": 1.1684, "leg_rl/sweep": 1.3812,
    "leg_rr/kick": 1.7591, "leg_rr/sweep": 1.4335,
}
const MIN_CHASSIS_Y: float = 0.45
const MAX_CHASSIS_Y: float = 0.75


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("V405_BITTARAN_CONTACT_PROBE_FAIL: " + message)
    quit(1)


func _tick(battle: Node) -> void:
    battle.set("player_hp", 9999.0)
    battle.call("_advance_target_motion", DT)
    battle.call("_finalize_target_pose", DT)


func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    await process_frame
    await process_frame
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var rig: Node3D = battle.get("bittaran_rig")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if brain == null or ik == null or rig == null \
            or boss == null or player == null:
        _fail("missing live boss / IK / rig / director")
        return
    player.global_position = Vector3(0.0, 0.0, -30.0)
    boss.global_position = Vector3.ZERO
    boss.rotation = Vector3.ZERO
    for frame in range(45):
        _tick(battle)
    # Part A: the canonical contact sample must not drift.
    var legs: Array = ik.get("legs")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    for key in CANONICAL:
        var id: String = key.split("/")[0]
        var kind: String = key.split("/")[1]
        var li: int = part_ids.find(id)
        if li < 0:
            _fail("IK has no leg for " + id)
            return
        var h: float = float(rig.call(
            "initial_authored_sole_height", kind, id,
            legs[li]["sole_local"]))
        if absf(h - float(CANONICAL[key])) > 0.01:
            _fail(key + " canonical contact sample drifted: "
                + str(h) + " vs " + str(CANONICAL[key]))
            return
    # Part B: close-range attacks keep the authored crouch band.
    var chassis: Node3D = ik.get("chassis_bone")
    if chassis == null:
        _fail("missing chassis bone")
        return
    for key in ["leg_fr/kick", "leg_fr/sweep", "leg_fl/sweep"]:
        var id: String = key.split("/")[0]
        var kind: String = key.split("/")[1]
        player.global_position = Vector3(1.8, 0.0, -3.2)
        var to_player: Vector3 = player.global_position \
            - boss.global_position
        boss.rotation.y = atan2(to_player.x, to_player.z)
        for frame in range(45):
            _tick(battle)
        if not bool(brain.call("force_start_with_stance", id, kind)):
            _fail("unable to start " + key)
            return
        var started: bool = false
        var min_y: float = 999.0
        var ticks: int = 0
        while ticks < 60 * 8:
            ticks += 1
            _tick(battle)
            var frame: Dictionary = battle.get("bittaran_attack_frame")
            if frame.is_empty():
                if started:
                    break
                continue
            started = true
            min_y = minf(min_y, chassis.global_position.y)
        if not started:
            _fail(key + " never produced an attack frame")
            return
        if min_y < MIN_CHASSIS_Y or min_y > MAX_CHASSIS_Y:
            _fail(key + " chassis crouch out of band: min_y="
                + str(min_y) + " (authored ~0.57, v404 defect 0.06)")
            return
    print("GODOT_V405_BITTARAN_CONTACT_PROBE_PASS")
    quit(0)
