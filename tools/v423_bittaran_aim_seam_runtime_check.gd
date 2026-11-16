extends SceneTree
## v423: the leg aim yaw must never somersault across the
## +-180-degree demand seam mid-attack. When the player sits in
## the sector opposite a rear leg's corner (reachable in play
## when Sera dashes across the boss during the stance/windup of
## a rear-leg KICK the director assigned), the aim demand sits
## at ~+-175 degrees; the extending clip keeps rotating the
## reference direction across the seam, so the wrapped demand
## flipped sign between ticks and the clamped target jumped
## from -85 to +85 degrees. The slew then dragged the whole
## kick 170 degrees around during the strike and hold
## (measured pre-fix on leg_rl at bearing 330 and leg_rr at
## bearing 30: hold sole deviation 6.43m from the played
## leg_fl mirror, foot orientation error 170 degrees).
## aim_authored_attack_leg now unwraps the demand against the
## current yaw before clamping, so the slew stays on one side.
## This check plays those exact geometries and compares each
## rear leg against leg_fl played at the reflected bearing,
## tick-aligned, target-local and hip-relative, with NO aim
## compensation: the flip cells must now sit at the ordinary
## rear-leg level (the known ~0.64m fitted-sole mesh offset),
## not metres away with a flipped foot.
const DT: float = 1.0 / 60.0
const DIST: float = 5.0
const MAX_SEAM_SOLE_ERROR_METERS: float = 1.0
const MAX_SEAM_ANGLE_ERROR_DEGREES: float = 30.0
# leg -> player bearing; baseline leg_fl bearing is the
# reflection of the placement across the leg's planes.
const CASES: Array = [
	["leg_rl", 330.0, 210.0],
	["leg_rr", 30.0, 210.0],
	["leg_rl", 300.0, 240.0],
]

var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(why: String) -> void:
	failures.append(why)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/bittaran_battle.tscn")
	var baselines: Dictionary = {}
	for c in CASES:
		var base_bearing: float = c[2]
		if not baselines.has(base_bearing):
			baselines[base_bearing] = await _run_traj(
				packed, "leg_fl", base_bearing)
		var rec: Dictionary = await _run_traj(packed, c[0], c[1])
		_compare(c[0], c[1], baselines[base_bearing], rec)
	if failures.is_empty():
		print("V423_AIM_SEAM_PASS")
		quit(0)
	else:
		for why in failures:
			push_error("V423_AIM_SEAM_FAIL: " + why)
		quit(1)

func _run_traj(packed: PackedScene, leg_id: String, theta_deg: float) -> Dictionary:
	var battle: Node = packed.instantiate()
	root.add_child(battle)
	await process_frame
	await process_frame
	battle.set_process(false)
	battle.set_physics_process(false)
	var brain: Object = battle.get("bittaran_attacks")
	var ik: Object = battle.get("bittaran_foot_ik")
	var target: Node3D = battle.get("target")
	var player: Node3D = battle.get("player")
	var part_ids: Array = ik.get("LEG_PART_IDS")
	var legs_arr: Array = ik.get("legs")
	var li: int = part_ids.find(leg_id)
	var leg: Dictionary = legs_arr[li]
	var upper: Node3D = leg["upper"]
	var foot: Node3D = leg["foot"]
	var sole_local: Vector3 = leg["source_sole_local"]
	for i in range(40):
		battle.set("player_hp", 9999.0)
		battle.call("_finalize_target_pose", DT)
	var th: float = deg_to_rad(theta_deg)
	player.global_position = target.global_position \
		+ Vector3(sin(th), 0.0, cos(th)) * DIST
	for i in range(10):
		battle.set("player_hp", 9999.0)
		battle.call("_finalize_target_pose", DT)
	brain.call("force_start_with_stance", leg_id, "kick")
	var out: Dictionary = {"phase": [], "sole": [], "footq": []}
	var seen: bool = false
	var recording: bool = false
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
		if not recording:
			continue
		var inv: Transform3D = target.global_transform.affine_inverse()
		var hip_l: Vector3 = inv * upper.global_position
		out["phase"].append(phase)
		out["sole"].append(inv * foot.to_global(sole_local) - hip_l)
		out["footq"].append(
			(inv.basis * foot.global_basis).get_rotation_quaternion())
	root.remove_child(battle)
	battle.free()
	await process_frame
	return out

func _compare(leg_id: String, theta_deg: float, base: Dictionary,
		rec: Dictionary) -> void:
	var flip := Vector3(
		-1.0 if leg_id.ends_with("r") else 1.0, 1.0,
		-1.0 if leg_id.begins_with("leg_r") else 1.0)
	var s_mat := Basis(
		Vector3(flip.x, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, flip.z))
	var n: int = mini(
		(base["sole"] as Array).size(), (rec["sole"] as Array).size())
	var stats: Dictionary = {}
	for i in range(n):
		var phase: String = str(base["phase"][i])
		if not stats.has(phase):
			stats[phase] = {"sole": 0.0, "ang": 0.0}
		var st: Dictionary = stats[phase]
		st["sole"] = maxf(st["sole"],
			((rec["sole"][i] as Vector3) * flip).distance_to(
				base["sole"][i]))
		var b_ref: Basis = s_mat * Basis(base["footq"][i] as Quaternion) * s_mat
		st["ang"] = maxf(st["ang"], rad_to_deg(
			b_ref.get_rotation_quaternion().angle_to(rec["footq"][i])))
		stats[phase] = st
	for phase in ["strike", "hold"]:
		if not stats.has(phase):
			_fail("kick %s at bearing %.0f produced no %s phase"
				% [leg_id, theta_deg, phase])
			continue
		var st: Dictionary = stats[phase]
		if float(st["sole"]) > MAX_SEAM_SOLE_ERROR_METERS:
			_fail("kick %s bearing %.0f %s sole deviation %.3fm exceeds %.2fm"
				% [leg_id, theta_deg, phase, float(st["sole"]),
					MAX_SEAM_SOLE_ERROR_METERS])
		if float(st["ang"]) > MAX_SEAM_ANGLE_ERROR_DEGREES:
			_fail("kick %s bearing %.0f %s foot angle error %.1fdeg exceeds %.1fdeg"
				% [leg_id, theta_deg, phase, float(st["ang"]),
					MAX_SEAM_ANGLE_ERROR_DEGREES])
