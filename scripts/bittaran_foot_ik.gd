extends RefCounted
## Analytical two-bone IK for four independent Bittaran legs.
## The authored Blockbench asset, joints, Wait pose and animation UUIDs are
## unchanged. The pose clips are evaluated first; grounded IK is layered last.
## The sole anchor is measured from the real imported foot mesh AABB.
const FLOOR_Y: float = 0.0
const STEP_TRIGGER_METERS: float = 0.38
const STEP_DURATION_SECONDS: float = 0.52
const STEP_HEIGHT_METERS: float = 0.19
const STEP_FORWARD_LEAD_METERS: float = 0.14
const STEP_COOLDOWN_SECONDS: float = 0.09
const MAX_TELEPORT_METERS: float = 0.75
const MAX_YAW_SNAP_RADIANS: float = 1.4
const IK_REACH_MARGIN_METERS: float = 0.002

const LEG_NAMES: Array[String] = [
    "FrontLeg_R", "RearLeg_L", "FrontLeg_L", "RearLeg_R"
]
const LEG_PAIRS: Array[Array] = [[0, 1], [2, 3]]

var actor: Node3D
var legs: Array[Dictionary] = []
var ready: bool = false
var last_actor_position: Vector3 = Vector3.ZERO
var last_actor_yaw: float = 0.0
var stepping_pair: int = -1
var preferred_pair: int = 0
var cooldown: float = 0.0

func setup(model: Node3D) -> bool:
    actor = model
    legs.clear()
    ready = false
    if actor == null or not actor.is_inside_tree():
        return false
    # Sample precise sole contact from the authored pose, not an assumed toe
    # offset or a shortcut that depends on whether an element was rotated.
    for name in LEG_NAMES:
        var root: String = name.trim_suffix("_R").trim_suffix("_L")
        var suffix: String = "_R" if name.ends_with("_R") else "_L"
        var region: String = "Front" if root.begins_with("Front") else "Rear"
        var upper: Node3D = actor.find_child(region + "Leg" + suffix, true, false) as Node3D
        var lower: Node3D = actor.find_child(region + "LowerLeg" + suffix, true, false) as Node3D
        var foot: Node3D = actor.find_child(region + "Foot" + suffix, true, false) as Node3D
        if upper == null or lower == null or foot == null:
            push_error("Bittaran IK: missing joint in " + name)
            return false
        var sole_local: Vector3 = _sole_local_point(foot)
        if sole_local == Vector3.INF:
            push_error("Bittaran IK: foot mesh missing for " + name)
            return false
        var hip_pos: Vector3 = upper.global_position
        var knee_pos: Vector3 = lower.global_position
        var tip_pos: Vector3 = foot.global_position
        var axis: Vector3 = (tip_pos - hip_pos).normalized()
        var pole: Vector3 = knee_pos - hip_pos
        pole -= axis * pole.dot(axis)
        if pole.length_squared() < 0.00001:
            pole = Vector3.RIGHT if suffix == "_R" else Vector3.LEFT
            pole -= axis * pole.dot(axis)
        if pole.length_squared() < 0.00001:
            pole = Vector3.UP
        legs.append({
            "upper": upper, "lower": lower, "foot": foot,
            "sole_local": sole_local,
            "pole_local": actor.global_basis.inverse() * pole.normalized(),
            "rest_sole_local": actor.to_local(foot.to_global(sole_local)),
            "rest_foot_rotation_local": actor.global_basis.get_rotation_quaternion().inverse()
                * foot.global_basis.get_rotation_quaternion(),
            "anchor": foot.to_global(sole_local),
            "anchor_rotation": foot.global_basis.get_rotation_quaternion(),
            "swing_from": Vector3.ZERO, "swing_to": Vector3.ZERO,
            "rotation_from": Quaternion.IDENTITY, "rotation_to": Quaternion.IDENTITY,
            "swing_elapsed": 0.0, "stepping": false
        })
    # Establish the ground level once. Keep the user's entire articulated
    # neutral stance: shift only the visual model, never individual pivots.
    var average_sole_y: float = 0.0
    for leg in legs:
        average_sole_y += (leg["anchor"] as Vector3).y / float(legs.size())
    actor.position.y += FLOOR_Y - average_sole_y
    reset()
    ready = true
    return true

func _sole_local_point(foot: Node3D) -> Vector3:
    var lowest: float = INF
    var corners: Array[Vector3] = []
    for child in foot.get_children():
        if not child is MeshInstance3D:
            continue
        var piece: MeshInstance3D = child as MeshInstance3D
        if piece.mesh == null:
            continue
        var bounds: AABB = piece.mesh.get_aabb()
        for i in range(8):
            var world: Vector3 = piece.to_global(bounds.get_endpoint(i))
            corners.append(world)
            lowest = minf(lowest, world.y)
    if corners.is_empty():
        return Vector3.INF
    var point := Vector3.ZERO
    var count: float = 0.0
    for world in corners:
        if world.y <= lowest + 0.015:
            point += world
            count += 1.0
    point /= maxf(count, 1.0)
    point.y = lowest
    return foot.to_local(point)

func reset() -> void:
    if actor == null or legs.size() != 4:
        return
    stepping_pair = -1
    preferred_pair = 0
    cooldown = 0.0
    last_actor_position = actor.global_position
    last_actor_yaw = actor.global_rotation.y
    for leg in legs:
        var foot: Node3D = leg["foot"]
        var sole: Vector3 = foot.to_global(leg["sole_local"])
        sole.y = FLOOR_Y
        leg["anchor"] = sole
        leg["stepping"] = false
        leg["swing_elapsed"] = 0.0
        leg["anchor_rotation"] = foot.global_basis.get_rotation_quaternion()

func _home(leg: Dictionary, with_lead: bool) -> Vector3:
    var p: Vector3 = actor.to_global(leg["rest_sole_local"])
    if with_lead:
        # Authored Blockbench faces -Z, while the model's runtime +PI turn
        # makes Bittaran face the combat controller's +Z direction.
        p += -actor.global_basis.z * STEP_FORWARD_LEAD_METERS
    p.y = FLOOR_Y
    return p

func _rotation_home(leg: Dictionary) -> Quaternion:
    return (actor.global_basis.get_rotation_quaternion()
        * (leg["rest_foot_rotation_local"] as Quaternion)).normalized()

func _pair_error(pair_index: int) -> float:
    var magnitude: float = 0.0
    for i in LEG_PAIRS[pair_index]:
        var leg: Dictionary = legs[i]
        magnitude = maxf(magnitude,
            (leg["anchor"] as Vector3).distance_to(_home(leg, false)))
    return magnitude

func _start_pair(pair_index: int, walking: bool) -> void:
    stepping_pair = pair_index
    preferred_pair = 1 - pair_index
    for i in LEG_PAIRS[pair_index]:
        var leg: Dictionary = legs[i]
        leg["stepping"] = true
        leg["swing_elapsed"] = 0.0
        leg["swing_from"] = leg["anchor"]
        leg["swing_to"] = _home(leg, walking)
        leg["rotation_from"] = leg["anchor_rotation"]
        leg["rotation_to"] = _rotation_home(leg)

func _solve(leg: Dictionary, sole_goal: Vector3, desired_rotation: Quaternion) -> float:
    var upper: Node3D = leg["upper"]
    var lower: Node3D = leg["lower"]
    var foot: Node3D = leg["foot"]
    # Fix the sole's orientation (no toe roll while planted) and then solve
    # the exact foot-pivot target required to place its sole at sole_goal.
    var wanted_end: Vector3 = sole_goal - desired_rotation * (leg["sole_local"] as Vector3)
    var hip: Vector3 = upper.global_position
    var knee: Vector3 = lower.global_position
    var end: Vector3 = foot.global_position
    var upper_length: float = hip.distance_to(knee)
    var lower_length: float = knee.distance_to(end)
    if upper_length <= 0.0001 or lower_length <= 0.0001:
        return INF
    var direction: Vector3 = wanted_end - hip
    var actual_distance: float = direction.length()
    if actual_distance < 0.0001:
        return INF
    direction /= actual_distance
    var distance: float = clampf(actual_distance,
        absf(upper_length - lower_length) + IK_REACH_MARGIN_METERS,
        upper_length + lower_length - IK_REACH_MARGIN_METERS)
    var along: float = (
        upper_length * upper_length - lower_length * lower_length
        + distance * distance) / (2.0 * distance)
    var sideways: float = sqrt(maxf(0.0,
        upper_length * upper_length - along * along))
    var pole: Vector3 = actor.global_basis * (leg["pole_local"] as Vector3)
    pole -= direction * pole.dot(direction)
    if pole.length_squared() < 0.00001:
        pole = Vector3.UP - direction * direction.y
    if pole.length_squared() < 0.00001:
        pole = Vector3.RIGHT
    pole = pole.normalized()
    var knee_target: Vector3 = hip + direction * along + pole * sideways
    var end_target: Vector3 = hip + direction * distance
    _align(upper, knee - hip, knee_target - hip)
    knee = lower.global_position
    end = foot.global_position
    _align(lower, end - knee, end_target - knee)
    # Foot orientation is world-stable throughout stance. The foot mesh's
    # authored local rotation is preserved by leaving the mesh untouched.
    foot.global_basis = Basis(desired_rotation)
    return foot.to_global(leg["sole_local"]).distance_to(sole_goal)

func _align(joint: Node3D, from_axis: Vector3, to_axis: Vector3) -> void:
    if from_axis.length_squared() <= 0.00000001 or (
            to_axis.length_squared() <= 0.00000001):
        return
    var q := Quaternion(from_axis.normalized(), to_axis.normalized())
    joint.global_basis = Basis((q * joint.global_basis.get_rotation_quaternion()).normalized())

func advance_ik(delta: float, motion: String) -> void:
    if not ready or legs.size() != 4 or actor == null:
        return
    # Reanchor only for an actual teleport or arena reset, not normal yaw or
    # a step; world-locked feet must stay locked as the torso moves above them.
    var displacement: float = actor.global_position.distance_to(last_actor_position)
    var yaw_delta: float = absf(wrapf(
        actor.global_rotation.y - last_actor_yaw, -PI, PI))
    if displacement > MAX_TELEPORT_METERS or yaw_delta > MAX_YAW_SNAP_RADIANS:
        reset()
    last_actor_position = actor.global_position
    last_actor_yaw = actor.global_rotation.y
    cooldown = maxf(0.0, cooldown - delta)
    var active: bool = motion == "Approach" or motion == "Turn"
    if stepping_pair == -1 and active and cooldown <= 0.0:
        var a: float = _pair_error(0)
        var b: float = _pair_error(1)
        var selected: int = preferred_pair
        if maxf(a, b) > STEP_TRIGGER_METERS:
            # Bias to alternating diagonal pairs, but never leave the other
            # diagonal pinned indefinitely when turning.
            if absf(a-b) > 0.12:
                selected = 0 if a > b else 1
            _start_pair(selected, motion == "Approach")
    var done: bool = true
    for leg in legs:
        var position: Vector3 = leg["anchor"]
        var rotation: Quaternion = leg["anchor_rotation"]
        if bool(leg["stepping"]):
            leg["swing_elapsed"] = minf(STEP_DURATION_SECONDS,
                float(leg["swing_elapsed"]) + delta)
            var ratio: float = float(leg["swing_elapsed"]) / STEP_DURATION_SECONDS
            var eased: float = ratio * ratio * (3.0 - 2.0 * ratio)
            position = (leg["swing_from"] as Vector3).lerp(
                leg["swing_to"] as Vector3, eased)
            position.y += sin(PI * ratio) * STEP_HEIGHT_METERS
            rotation = (leg["rotation_from"] as Quaternion).slerp(
                leg["rotation_to"] as Quaternion, eased)
            if ratio >= 1.0:
                leg["stepping"] = false
                leg["anchor"] = leg["swing_to"]
                leg["anchor_rotation"] = leg["rotation_to"]
            else:
                done = false
        leg["last_error"] = _solve(leg, position, rotation)
    if stepping_pair != -1 and done:
        stepping_pair = -1
        cooldown = STEP_COOLDOWN_SECONDS

func maximum_ground_error() -> float:
    var worst: float = 0.0
    for leg in legs:
        if not bool(leg["stepping"]):
            worst = maxf(worst, float(leg.get("last_error", 0.0)))
    return worst

func planted_foot_count() -> int:
    var count: int = 0
    for leg in legs:
        if not bool(leg["stepping"]):
            count += 1
    return count
