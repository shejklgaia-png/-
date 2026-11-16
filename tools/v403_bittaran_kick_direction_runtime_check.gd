extends SceneTree
## v403 regression check, from device feedback on v402: "the KICK
## still fires in a weird direction - rotation?". Measurement: the
## shoulder aim was fitted during the windup against a fixed
## extended-pose reference and then frozen, but the retargeted KICK
## clips rotate their hip->foot direction by 50-100 degrees while
## extending on every leg except the authored leg_fl, so by full
## extension the kick pointed up to ~91 degrees away from the player
## (travel-direction error up to ~102 degrees). The aim now samples
## the CURRENT pose during the strike/hold and keeps cancelling that
## drift against the windup-locked aim point. This check forces a
## KICK with every leg in the geometry the game actually selects it
## (front legs: player in front, boss facing them; rear legs: player
## behind, boss facing away) and asserts the foot's travel direction
## and the extended leg direction stay on the player.
## v409 amendment (setup only, assertions unchanged): the rear-leg
## lateral offset is placed on the attacking leg's OWN side. With
## the boss rotated PI, world +X is the boss's local -X (right)
## side, so the original +2.5 placement put the player on
## leg_rr's side while leg_rl attacked across the body -- a
## selection the director never makes (it picks the nearest foot).
## Under the user-requested v409 aim limit (85 degrees) that
## forced cross-side case lands 23.4 degrees off; the same-side
## geometry this check states it covers is unaffected.
const DT: float = 1.0 / 60.0
const LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const MAX_DIRECTION_ERROR_DEGREES: float = 20.0

var failures: Array[String] = []

func _fail(message: String) -> void:
    failures.append(message)

func _angle_error_deg(from: Vector3, to: Vector3) -> float:
    return rad_to_deg(wrapf(
        atan2(to.x, to.z) - atan2(from.x, from.z), -PI, PI))

func _run() -> void:
    var battle: Node3D = load(
        "res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    battle.set_process(false)
    battle.set_physics_process(false)
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    var boss: Node3D = battle.get("target")
    var player: CharacterBody3D = battle.get("player")
    var brain: RefCounted = battle.get("bittaran_attacks")
    var part_ids: Array = ik.get("LEG_PART_IDS")
    for lateral in [0.0, 2.5]:
        for leg_id in LEGS:
            boss.global_position = Vector3.ZERO
            var rear: bool = leg_id.begins_with("leg_r")
            var placed_lateral: float = lateral
            if rear and leg_id == "leg_rl":
                placed_lateral = -lateral
            player.global_position = Vector3(
                placed_lateral, 0.0, 6.0 if rear else -6.0)
            if rear:
                boss.rotation = Vector3(0.0, PI, 0.0)
            else:
                var to_p: Vector3 = (
                    player.global_position - boss.global_position)
                boss.rotation = Vector3(0.0, atan2(to_p.x, to_p.z), 0.0)
            for frame in range(30):
                battle.set("player_hp", 9999.0)
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
            brain.call("force_start_with_stance", leg_id, "kick")
            var idx: int = part_ids.find(leg_id)
            var leg: Dictionary = ik.get("legs")[idx]
            var foot: Node3D = leg["foot"]
            var hip: Node3D = leg["upper"]
            var started: bool = false
            var strike_foot0 := Vector3.ZERO
            var strike_hip := Vector3.ZERO
            var strike_player := Vector3.ZERO
            var max_reach: float = -1.0
            var max_foot := Vector3.ZERO
            var prev_phase: String = ""
            for frame in range(60 * 8):
                battle.set("player_hp", 9999.0)
                battle.call("_advance_target_motion", DT)
                battle.call("_finalize_target_pose", DT)
                var f: Dictionary = battle.get("bittaran_attack_frame")
                if f.is_empty():
                    if started:
                        break
                    continue
                started = true
                var phase: String = str(f.get("phase", ""))
                if phase == "strike" and prev_phase != "strike":
                    strike_foot0 = foot.global_position
                    strike_hip = hip.global_position
                    strike_player = player.global_position
                if phase == "strike" or phase == "hold":
                    var fp: Vector3 = foot.global_position
                    var reach: float = Vector2(
                        fp.x - strike_hip.x, fp.z - strike_hip.z).length()
                    if reach > max_reach:
                        max_reach = reach
                        max_foot = fp
                prev_phase = phase
            var travel := Vector3(
                max_foot.x - strike_foot0.x, 0.0,
                max_foot.z - strike_foot0.z)
            var want_travel := Vector3(
                strike_player.x - strike_foot0.x, 0.0,
                strike_player.z - strike_foot0.z)
            var travel_err: float = absf(
                _angle_error_deg(travel, want_travel))
            if travel_err > MAX_DIRECTION_ERROR_DEGREES:
                _fail("%s kick (lateral %.1f) travelled %.1f deg away "
                    % [leg_id, placed_lateral, travel_err]
                    + "from the player direction")
            var ext_dir := Vector3(
                max_foot.x - strike_hip.x, 0.0, max_foot.z - strike_hip.z)
            var want_ext := Vector3(
                strike_player.x - strike_hip.x, 0.0,
                strike_player.z - strike_hip.z)
            var ext_err: float = absf(_angle_error_deg(ext_dir, want_ext))
            if ext_err > MAX_DIRECTION_ERROR_DEGREES:
                _fail("%s kick (lateral %.1f) extended %.1f deg away "
                    % [leg_id, placed_lateral, ext_err]
                    + "from the player direction")
    if failures.is_empty():
        print("GODOT_V403_BITTARAN_KICK_DIRECTION_PASS")
        quit(0)
    else:
        for message in failures:
            printerr("V403_BITTARAN_KICK_DIRECTION_FAIL: ", message)
        quit(1)

func _initialize() -> void:
    call_deferred("_run")
