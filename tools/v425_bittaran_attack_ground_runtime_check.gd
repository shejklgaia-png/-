extends SceneTree
## v425: real mesh grounding for all six authored L/R front-leg attacks.
## STOMP: toe; KICK: toe; SWEEP: lower shin AND toe, with support-leg IK.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const DT: float = 0.05
const FLOOR_TOLERANCE: float = 0.055
const SHIN_TOLERANCE: float = 0.105

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V425_ATTACK_GROUND_FAIL: " + message)
    quit(1)

func _run() -> void:
    var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if packed == null:
        _fail("battle scene missing")
        return
    var battle: Node3D = packed.instantiate()
    root.add_child(battle)
    var rig: Node3D = battle.get("bittaran_rig")
    var foot_ik: RefCounted = battle.get("bittaran_foot_ik")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var target: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    if rig == null or not bool(rig.get("loading_ok")) or foot_ik == null:
        _fail("Bittaran rig or IK unavailable")
        return
    var verified: int = 0
    for id in ["leg_fl", "leg_fr"]:
        for kind in ["sweep", "stomp", "kick"]:
            battle.call("_reset_target_after_respawn")
            player.global_position = target.global_position + Vector3(0.0, 0.0, 7.0)
            if not bool(brain.call("force_start", id, kind)):
                _fail("unable to begin " + id + "/" + kind)
                return
            var index: int = IK.LEG_PART_IDS.find(id)
            var leg: Dictionary = foot_ik.get("legs")[index]
            var foot: Node3D = leg["foot"]
            var lower: Node3D = leg["lower"]
            var checked: int = 0
            var worst_toe: float = 0.0
            var worst_shin: float = 0.0
            for tick in range(110):
                battle.call("_advance_target_motion", DT)
                var frame: Dictionary = battle.get("bittaran_attack_frame")
                if frame.is_empty():
                    break
                battle.call("_finalize_target_pose", DT)
                if not bool(frame.get("direct_front_test", false)):
                    _fail("front source mode lost: " + id + "/" + kind)
                    return
                var foot_y: float = float(foot_ik.call("_foot_mesh_lowest_y", foot))
                var shin_y: float = float(foot_ik.call("_foot_mesh_lowest_y", lower))
                if not is_finite(foot_y) or not is_finite(shin_y):
                    _fail("mesh contact probe returned invalid height")
                    return
                # A raised windup is intentional, but penetration is never.
                if foot_y < -0.025:
                    _fail(id + "/" + kind + " toe penetrated: "
                        + str([tick, foot_y]))
                    return
                var t: float = float(frame.get("time", 0.0))
                var windup: float = float(frame.get("windup", 0.0))
                var strike: float = float(frame.get("strike", 0.0))
                var contact: bool = (t >= windup + strike
                    if kind == "stomp" else t >= windup + 0.10)
                var recovering: bool = str(frame.get("phase", "")) == "recovery"
                if not contact or recovering:
                    continue
                worst_toe = maxf(worst_toe, absf(foot_y))
                if absf(foot_y) > FLOOR_TOLERANCE:
                    _fail(id + "/" + kind + " toe not seated: "
                        + str([tick, foot_y]))
                    return
                if kind == "sweep":
                    worst_shin = maxf(worst_shin, absf(shin_y))
                    if absf(shin_y) > SHIN_TOLERANCE:
                        _fail(id + "/sweep shin not grounded: "
                            + str([tick, shin_y, foot_y]))
                        return
                checked += 1
            if checked < 3:
                _fail("insufficient grounded attack frames: " + id + "/" + kind)
                return
            print("V425_CONTACT_CASE: ", id, " ", kind, " frames=", checked,
                " toe=", worst_toe, " shin=", worst_shin)
            verified += 1
    if verified != 6:
        _fail("not all six authored front attacks were verified")
        return
    print("GODOT_V425_ATTACK_GROUND_PASS: sweep shin/toe, stomp toe, kick toe, both sides")
    quit(0)
