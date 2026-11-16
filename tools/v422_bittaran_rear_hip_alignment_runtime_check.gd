extends SceneTree
## v422: rear-leg attacks must not be dragged down by the uniform
## chassis calibration. The v419/v421 chassis applies one constant
## clip-0 sole calibration as a uniform Y translation; for rear
## legs that dropped the whole body ~1.45m for the entire attack
## and let the floor guard flatten the trajectory (measured
## windup/strike sole deviation 2.84m / 2.20m against the played
## front-left mirror). The attacking rear hip is now aligned to
## the SOURCE hip's height per tick (the trajectory's own
## premise), which brings those to ~1.90m / ~1.39m; this check
## guards the improvement and the front legs' exactness.
## Known remaining deviations, NOT asserted here: (a) at full
## extension the rear mesh sole still lands ~1.29m from the
## mirrored point at the REAL mesh sole point (the gameplay sole
## is the per-tick fitted point and is exact). The rear feet's
## local frames are not mirror images of the front pair's, so no
## rotation makes ankle, orientation and mesh sole all exact at
## once; bending the foot to the fitted point was measured to
## cost a 33.7-degree extension tilt (source: ~9 degrees) and is
## left as a design decision. (b) The chain-played windup fold
## still hangs from the front-back reversed Body pitch, so its
## shape differs from the source fold by the pitch delta and the
## fold sole floats ~0.94m before the contact correction.
const DT: float = 1.0 / 60.0
const CORNERS: Dictionary = {
	"leg_fl": 34.4, "leg_fr": -33.8, "leg_rl": 145.8, "leg_rr": -146.0}
const REAR_SOLE_ERROR_METERS: float = 1.60
const REAR_WINDUP_ERROR_METERS: float = 2.10
const FRONT_HOLD_ERROR_METERS: float = 0.10
const FRONT_SWEEP_ERROR_METERS: float = 0.20
const MAX_STRIKE_JOINT_STEP_DEGREES: float = 65.0

var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(why: String) -> void:
	failures.append(why)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
	for kind in ["kick", "sweep"]:
		var base: Dictionary = await _run_traj(packed, "leg_fl", kind)
		for leg_id in ["leg_fr", "leg_rl", "leg_rr"]:
			var rec: Dictionary = await _run_traj(packed, leg_id, kind)
			_compare(kind, leg_id, base, rec)
	if failures.is_empty():
		print("V422_REAR_HIP_ALIGNMENT_PASS")
		quit(0)
	else:
		for why in failures:
			push_error("V422_REAR_HIP_ALIGNMENT_FAIL: " + why)
		quit(1)

func _run_traj(packed: PackedScene, leg_id: String, kind: String) -> Dictionary:
	var battle: Node = packed.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	battle.set_process(false)
	battle.set_physics_process(false)
	var brain: Object = battle.get("bittaran_attacks")
	var ik: Object = battle.get("bittaran_foot_ik")
	var rig: Object = battle.get("bittaran_rig")
	var target: Node3D = battle.get("target")
	var player: Node3D = battle.get("player")
	var part_ids: Array = ik.get("LEG_PART_IDS")
	var legs_arr: Array = ik.get("legs")
	var li: int = part_ids.find(leg_id)
	var leg: Dictionary = legs_arr[li]
	var upper: Node3D = leg["upper"]
	var lower: Node3D = leg["lower"]
	var foot: Node3D = leg["foot"]
	var sole_local: Vector3 = leg["source_sole_local"]
	for i in range(40):
		battle.set("player_hp", 9999.0)
		battle.call("_finalize_target_pose", DT)
	var bearing: float = deg_to_rad(CORNERS[leg_id])
	player.global_position = target.global_position + Vector3(sin(bearing), 0.0, cos(bearing)) * 5.0
	for i in range(10):
		battle.set("player_hp", 9999.0)
		battle.call("_finalize_target_pose", DT)
	brain.call("force_start_with_stance", leg_id, kind)
	var out: Dictionary = {"phase": [], "sole": [],
		"windup_sole_y": -1.0, "strike_step": 0.0}
	var seen: bool = false
	var recording: bool = false
	var prev_q: Array = []
	for tick in range(460):
		battle.set("player_hp", 9999.0)
		battle.call("_advance_target_motion", DT)
		battle.call("_finalize_target_pose", DT)
		var frame: Dictionary = battle.get("bittaran_attack_frame")
		var active: bool = brain.call("is_active")
		if frame.is_empty() and not active:
			if seen:
				break
			continue
		seen = true
		var phase: String = str(frame.get("phase", ""))
		if phase == "windup":
			recording = true
			out["windup_sole_y"] = foot.to_global(sole_local).y
		if not recording:
			continue
		var hip: Vector3 = upper.global_position
		var aim_q: Quaternion = Quaternion(Vector3.UP,
			-float(rig.get("attack_leg_aim_yaw")))
		out["phase"].append(phase)
		out["sole"].append(aim_q * (foot.to_global(sole_local) - hip))
		if phase == "strike":
			var qs: Array = [
				upper.quaternion, lower.quaternion, foot.quaternion]
			if prev_q.size() == 3:
				for j in range(3):
					var step: float = rad_to_deg(
						(prev_q[j] as Quaternion).angle_to(qs[j]))
					out["strike_step"] = maxf(out["strike_step"], step)
			prev_q = qs
		else:
			prev_q = []
	root.remove_child(battle)
	battle.free()
	await process_frame
	return out

func _compare(kind: String, leg_id: String, base: Dictionary,
		rec: Dictionary) -> void:
	var flip := Vector3(
		-1.0 if leg_id.ends_with("r") else 1.0, 1.0,
		-1.0 if leg_id.begins_with("leg_r") else 1.0)
	var n: int = mini(base["sole"].size(), rec["sole"].size())
	var stats: Dictionary = {}
	for i in range(n):
		var phase: String = str(base["phase"][i])
		if not stats.has(phase):
			stats[phase] = 0.0
		var s: Vector3 = (rec["sole"][i] as Vector3) * flip
		stats[phase] = maxf(stats[phase],
			s.distance_to(base["sole"][i]))
	var rear: bool = leg_id.begins_with("leg_r")
	for phase in stats.keys():
		var dev: float = stats[phase]
		if rear:
			# Improvement guards for the hip alignment (pre-fix
			# values: windup 2.84m, strike 2.20m). The hold-phase
			# mesh-sole offset is documented in the header.
			if kind == "kick" and phase == "windup" \
					and dev > REAR_WINDUP_ERROR_METERS:
				_fail("%s %s %s sole deviation %.3fm exceeds %.2fm"
					% [kind, leg_id, phase, dev,
						REAR_WINDUP_ERROR_METERS])
			if kind == "kick" and phase == "strike" \
					and dev > REAR_SOLE_ERROR_METERS:
				_fail("%s %s %s sole deviation %.3fm exceeds %.2fm"
					% [kind, leg_id, phase, dev, REAR_SOLE_ERROR_METERS])
		elif kind == "kick" and phase == "hold":
			if dev > FRONT_HOLD_ERROR_METERS:
				_fail("kick %s hold sole deviation %.3fm exceeds %.2fm"
					% [leg_id, dev, FRONT_HOLD_ERROR_METERS])
		elif kind == "sweep":
			if dev > FRONT_SWEEP_ERROR_METERS:
				_fail("sweep %s %s sole deviation %.3fm exceeds %.2fm"
					% [leg_id, phase, dev, FRONT_SWEEP_ERROR_METERS])
	if rear and kind == "kick":
		if float(rec["strike_step"]) > MAX_STRIKE_JOINT_STEP_DEGREES:
			_fail("kick %s strike joint step %.1fdeg exceeds %.1fdeg"
				% [leg_id, float(rec["strike_step"]),
					MAX_STRIKE_JOINT_STEP_DEGREES])
