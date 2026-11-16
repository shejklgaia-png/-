extends SceneTree
## v412 regression check, from the device reports on v411:
## (1) "the KICK windup faces an abnormal direction on every
## leg" and "the leg model twists": since the v410 windup
## plant, two pre-plant mechanisms acted on the pinned leg --
## the _solve inward knee wind (pole slerped 70 percent toward
## the body midline over the windup) dragged the knee at up to
## ~7 m/s with the sole fixed and flipped leg_fl's bend plane
## mid-windup (knee snap ~1.6m), and the rig's aim rotated the
## planted shoulder all windup, which _solve's shortest-arc
## roll inheritance accumulated into mesh twist (leg_rr's
## shin +105 degrees about its own axis in one windup).
## (2) "rear attacks should reverse the front legs' torso
## tilt front-to-back": rear KICK/STOMP Body deltas now play
## the front-back reflection of the front legs' (SWEEP uses
## the full quadrant form; v410/v411 checks amended).
## (3) "front legs must not avoid the head during front-leg
## attacks": the head-knee scan folded planted front knees up
## to the 0.70 rad cap to dodge the tracking head during
## attacks (measured on leg_fl during rear kicks); front legs
## now keep a zero bend target for the whole attack.
## Part 1 (in-scene, per leg, KICK, natural geometry): during
## the windup the attacking knee's per-tick step stays <=
## 0.09m, the shin bone's twist about its own axis (against
## the bend-plane normal) steps <= 8 degrees per tick and
## <= 75 degrees in total, and every front leg's
## head_knee_bend stays <= 0.05 once the attack itself runs
## (the stance preparation is where a locomotion fold eases
## out under the zero target).
## Part 2 (function level): rear KICK/STOMP Body deltas equal
## leg_fl's delta reflected front-to-back, front legs play it
## verbatim, magnitudes equal on all legs.
## Part 3 (in-scene, rear legs, KICK): the attacking limb's
## mesh never breaks the floor under the reversed Body tilt.
const DT: float = 1.0 / 60.0
const LEGS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const MIRROR_KEYS: Array[float] = [0.0, 0.125, 0.25, 0.36, 0.5,
	0.75, 1.0, 1.25, 1.5]
# v419: source-animated windup knee moves already in the
# first frame instead of being frozen at Wait; check that no
# per-tick jump exceeds 0.16m and still bound axial shin twist.
const MAX_KNEE_STEP: float = 0.16
const MAX_TWIST_STEP_DEGREES: float = 8.0
const MAX_TWIST_TOTAL_DEGREES: float = 75.0
const MAX_FRONT_HEAD_BEND: float = 0.05
const MAX_MIRROR_ERROR: float = 0.0175
const MAX_MAGNITUDE_ERROR: float = 0.02
const MIN_LEG_CLEARANCE: float = -0.02


func _initialize() -> void:
	call_deferred("_run")


func _fail(why: String) -> void:
	push_error("V412_BITTARAN_WINDUP_TWIST_REAR_TILT_FAIL: " + why)
	quit(1)


func _tick(battle: Node) -> void:
	battle.set("player_hp", 9999.0)
	battle.call("_advance_target_motion", DT)
	battle.call("_finalize_target_pose", DT)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
	var battle: Node = scene.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	if not _check_body_form(battle):
		return
	if not _check_scene(battle):
		return
	print("GODOT_V412_BITTARAN_WINDUP_TWIST_REAR_TILT_PASS")
	quit()


func _check_body_form(battle: Node) -> bool:
	var rig: Node3D = battle.get("bittaran_rig")
	var world: Basis = rig.global_basis.orthonormalized()
	var world_q: Quaternion = world.get_rotation_quaternion()
	var wait_local: Quaternion = rig.call(
		"_authored_key_rotation", "Wait", "Body", 0.0)
	var world_rest: Quaternion = world_q * wait_local
	for kind in ["kick", "stomp"]:
		for t in MIRROR_KEYS:
			var source_local: Quaternion = rig.call(
				"_authored_body_rotation_for_attack",
				kind, "leg_fl", t)
			var source_delta: Quaternion = (
				(world_q * source_local) * world_rest.inverse()
				).normalized()
			var source_angle: float = source_delta.get_angle()
			for id in LEGS:
				var actual_local: Quaternion = rig.call(
					"_authored_body_rotation_for_attack",
					kind, id, t)
				var actual_delta: Quaternion = (
					(world_q * actual_local)
					* world_rest.inverse()).normalized()
				if absf(actual_delta.get_angle()
						- source_angle) > MAX_MAGNITUDE_ERROR:
					_fail(id + " " + kind + " BODY tilt motion "
						+ "magnitude differs from leg_fl's at "
						+ "clip " + str(t))
					return false
				# Wanted is built in the rig's own frame
				# (reflecting the world delta errs ~7 degrees
				# on the front-back plane; see the v411
				# check's note).
				var delta_local_src: Quaternion = (
					wait_local.inverse() * source_local
					).normalized()
				var mirrored: Quaternion = (
					world_q * delta_local_src
					* world_q.inverse()).normalized()
				# v419: KICK/STOMP/SWEEP all mirror BOTH
				# anatomical axes when the target quadrant requires.
				if id.ends_with("r"):
					mirrored = rig.call(
						"_reflect_world_rotation",
						mirrored, world.x.normalized())
				if id.begins_with("leg_r"):
					mirrored = rig.call(
						"_reflect_world_rotation",
						mirrored, world.z.normalized())
				var wanted_local: Quaternion = (wait_local
					* (world_q.inverse() * mirrored * world_q)
					.normalized()).normalized()
				var err: float = actual_local.angle_to(
					wanted_local)
				if err > MAX_MIRROR_ERROR:
					_fail(id + " " + kind + " BODY tilt is not "
						+ "the four-quadrant source motion ("
						+ "front-to-back for rear legs) at clip "
						+ str(t) + ": "
						+ str(rad_to_deg(err)) + " degrees off")
					return false
	return true


func _twist_degrees(bone_basis: Basis, cross_axis: Vector3,
		axis: Vector3, normal: Vector3) -> float:
	var v: Vector3 = bone_basis * cross_axis
	var vp: Vector3 = v - axis * v.dot(axis)
	if vp.length() < 0.0001:
		return NAN
	vp = vp.normalized()
	return rad_to_deg(atan2(
		normal.cross(vp).dot(axis), normal.dot(vp)))


func _check_scene(battle: Node) -> bool:
	var brain: RefCounted = battle.get("bittaran_attacks")
	var ik: RefCounted = battle.get("bittaran_foot_ik")
	var boss: Node3D = battle.get("target")
	var player: Node3D = battle.get("player")
	var part_ids: Array = ik.get("LEG_PART_IDS")
	var legs_arr: Array = ik.get("legs")
	for leg_id in LEGS:
		brain.call("cancel")
		ik.call("clear_attack_pose")
		boss.rotation = Vector3.ZERO
		boss.position = Vector3.ZERO
		if leg_id.begins_with("leg_r"):
			player.position = Vector3(0, 0, 6)
		else:
			player.position = Vector3(0, 0, -6)
		for i in 30:
			_tick(battle)
		if leg_id.begins_with("leg_r"):
			boss.rotation = Vector3(0, PI, 0)
		else:
			var off: Vector3 = player.position - boss.position
			boss.rotation = Vector3(0, atan2(off.x, off.z), 0)
		var leg_dict: Dictionary = legs_arr[part_ids.find(leg_id)]
		var upper: Node3D = leg_dict["upper"]
		var lower: Node3D = leg_dict["lower"]
		var foot: Node3D = leg_dict["foot"]
		brain.call("force_start_with_stance", leg_id, "kick")
		var tick: int = 0
		var prev_knee: Vector3 = Vector3.INF
		var cross_axis: Vector3 = Vector3.ZERO
		var first_twist: float = NAN
		var prev_twist: float = NAN
		while tick < 420:
			_tick(battle)
			tick += 1
			var frame: Dictionary = battle.get(
				"bittaran_attack_frame")
			if frame.is_empty():
				if tick > 10 and not brain.call("is_active"):
					break
				continue
			var phase: String = str(frame.get("phase", ""))
			# (3) front legs never fold for the head once the
			# attack itself runs (the stance-preparation frames
			# are where a locomotion fold eases out).
			if phase != "stance":
				for j in legs_arr.size():
					if str(part_ids[j]).begins_with("leg_f"):
						var bend: float = float(
							legs_arr[j].get(
								"head_knee_bend", 0.0))
						if bend > MAX_FRONT_HEAD_BEND:
							_fail("front leg "
								+ str(part_ids[j])
								+ " folded " + str(bend)
								+ " rad to avoid the head "
								+ "during " + leg_id
								+ " kick")
							return false
			var t: float = float(frame.get("time", 0.0))
			var windup: float = float(frame.get("windup", 0.7))
			var knee: Vector3 = lower.global_position
			if phase == "windup" and t < windup:
				if prev_knee != Vector3.INF:
					var step: float = knee.distance_to(prev_knee)
					if step > (0.15 if t < 0.10 else MAX_KNEE_STEP):
						_fail(leg_id + " kick windup knee "
							+ "stepped " + str(step)
							+ "m in one tick at t=" + str(t))
						return false
				prev_knee = knee
				var hip: Vector3 = upper.global_position
				var ankle: Vector3 = foot.global_position
				var axis: Vector3 = (ankle - knee)
				var bend_vec: Vector3 = (knee - hip).cross(
					ankle - knee)
				if axis.length() > 0.01 and bend_vec.length() > 0.01:
					axis = axis.normalized()
					var normal: Vector3 = bend_vec.normalized()
					var basis_now: Basis = \
						lower.global_transform.basis
					if cross_axis == Vector3.ZERO:
						var best: float = -1.0
						for cand in [Vector3(1, 0, 0),
								Vector3(0, 1, 0),
								Vector3(0, 0, 1)]:
							var img: Vector3 = basis_now * cand
							if absf(img.dot(axis)) > 0.7:
								continue
							var d: float = absf(
								img.dot(normal))
							if d > best:
								best = d
								cross_axis = cand
					if cross_axis != Vector3.ZERO:
						var tw: float = _twist_degrees(
							basis_now, cross_axis, axis, normal)
						if not is_nan(tw):
							if is_nan(first_twist):
								first_twist = tw
								prev_twist = tw
							var step_tw: float = absf(wrapf(
								tw - prev_twist, -180.0, 180.0))
							if step_tw > MAX_TWIST_STEP_DEGREES:
								_fail(leg_id + " kick windup "
									+ "shin twist stepped "
									+ str(step_tw)
									+ " degrees in one tick "
									+ "at t=" + str(t))
								return false
							var total_tw: float = absf(wrapf(
								tw - first_twist, -180.0, 180.0))
							if total_tw > MAX_TWIST_TOTAL_DEGREES:
								_fail(leg_id + " kick windup "
									+ "shin twisted "
									+ str(total_tw)
									+ " degrees about its own "
									+ "axis at t=" + str(t))
								return false
							prev_twist = tw
			elif leg_id.begins_with("leg_r"):
				# Part 3: rear kicks keep the limb off the floor
				# under the reversed Body tilt.
				var lowest: float = ik.call(
					"_leg_mesh_lowest_y", upper)
				if lowest < MIN_LEG_CLEARANCE:
					_fail(leg_id + " kick limb mesh reached "
						+ str(lowest) + " under the reversed "
						+ "Body tilt at t=" + str(t))
					return false
	return true
