extends SceneTree
## v392: torso aims with a 45deg offset to the striking leg, HEAD
## looks down without roll, and STOMP preserves authored toe keys
## through windup before horizontal short-end ground contact.
const BRAIN = preload("res://scripts/bittaran_attacks.gd")
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 1.0 / 60.0

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V392_BITTARAN_PITCH_45_STOMP_FAIL: " + why)
    quit(1)

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var rig: Node3D = battle.get("bittaran_rig")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var head: Node3D = battle.get("bittaran_head")
    var count: int = 0
    for id in BRAIN.LEG_IDS:
        for kind in BRAIN.ATTACK_KINDS:
            battle.call("_reset_target_after_respawn")
            battle.set("target_move_enabled", true)
            if not bool(brain.call("force_start", id, kind)):
                _fail(id + "/" + kind + " could not start")
                return
            var side: float = 1.0 if id.ends_with("l") else -1.0
            var desired: float = -side * deg_to_rad(45.0)
            var angle_checked: bool = false
            var authored_checked: bool = kind != "stomp"
            var tip_contact_checked: bool = kind != "stomp"
            for tick in range(215):
                player.global_position = boss.global_position + (
                    boss.global_basis.z.normalized() * 7.5)
                battle.call("_advance_target_motion", DT)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                if frame.is_empty():
                    break
                var t: float = float(frame.get("time", 0.0))
                var windup: float = float(frame.get("windup", 0.0))
                if bool(frame.get("tracking", false)) and (
                        t >= windup - 0.035 and t < windup):
                    var chest: float = float(frame.get("body_yaw", 0.0))
                    if absf(wrapf(chest - desired, -PI, PI)) > deg_to_rad(9.0):
                        _fail(id + "/" + kind + ": BODY is not 45deg "
                            + "across the attacking arm: " + str(chest))
                        return
                    angle_checked = true
                battle.call("_finalize_target_pose", DT)
                var right: Vector3 = head.global_basis.x.normalized()
                if absf(right.y) > 0.05:
                    _fail(id + "/" + kind + ": HEAD acquired side roll")
                    return
                if kind != "stomp":
                    continue
                var foot: Node3D = ik.get("legs")[
                    IK.LEG_PART_IDS.find(id)]["foot"]
                if t >= 0.83 and t <= 1.00 and not authored_checked:
                    # v395: shoulder/knee remain authored, but the long
                    # toe is deliberately erected before impact.
                    if foot.global_basis.y.normalized().dot(
                            Vector3.UP) < 0.995:
                        _fail(id + ": STOMP toe horizontal during windup")
                        return
                    authored_checked = true
                if bool(frame.get("impact", false)):
                    var up: Vector3 = foot.global_basis.y.normalized()
                    if up.dot(Vector3.UP) < 0.995:
                        _fail(id + ": STOMP short tip not horizontal at hit")
                        return
                    var bottom: float = float(ik.call(
                        "_foot_mesh_lowest_y", foot))
                    if absf(bottom - IK.FLOOR_Y) > 0.07:
                        _fail(id + ": STOMP tip did not contact floor "
                            + str(bottom))
                        return
                    tip_contact_checked = true
            if not angle_checked or not authored_checked or not tip_contact_checked:
                _fail(id + "/" + kind + ": incomplete attack checks")
                return
            count += 1
    # Beyond the attack, the same pitched HEAD points its short nose
    # directly toward a player below it, with no side roll.
    battle.call("_reset_target_after_respawn")
    battle.set("target_move_enabled", false)
    var direction: Vector3 = -head.get_parent().global_basis.z
    direction.y = 0.0
    direction = direction.normalized()
    player.global_position = head.global_position + direction * 5.0 \
        - Vector3.UP * 2.1 - Vector3.UP * 0.9
    for tick in range(100):
        battle.call("_advance_target_motion", DT)
        battle.call("_finalize_target_pose", DT)
    var pitch: float = float(battle.get("boss_head_pitch"))
    if pitch >= -0.10 or absf(
            head.global_basis.x.normalized().y) > 0.025:
        _fail("HEAD did not look down without roll " + str(pitch))
        return
    var toward: Vector3 = (
        player.global_position + Vector3.UP * 0.9
        - head.global_position).normalized()
    if -head.global_basis.z.normalized().dot(toward) < 0.70:
        _fail("HEAD short front face missed the player")
        return
    if count != 12:
        _fail("not all attack combinations executed")
        return
    print("GODOT_V392_BITTARAN_PITCH_45_STOMP_PASS: 12 angled chest attack "
        + "aims, true source STOMP windup, level short-tip impact, "
        + "no-roll downward head pitch")
    quit(0)
