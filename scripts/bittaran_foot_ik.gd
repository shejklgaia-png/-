extends RefCounted
## Analytical two-bone IK for four independent Bittaran legs.
## The authored Blockbench asset, joints, Wait pose and animation UUIDs are
## unchanged. The pose clips are evaluated first; grounded IK is layered last.
## The sole anchor is measured from the real imported foot mesh AABB.
const FLOOR_Y: float = 0.0
const STEP_TRIGGER_METERS: float = 0.76
const STEP_DURATION_SECONDS: float = 0.58
const STEP_HEIGHT_METERS: float = 0.34
const STEP_FORWARD_LEAD_METERS: float = 0.28
const STEP_COOLDOWN_SECONDS: float = 0.10
const MAX_TELEPORT_METERS: float = 1.50
const MAX_YAW_SNAP_RADIANS: float = 1.4
const IK_REACH_MARGIN_METERS: float = 0.002
## World-space crouch and inward sole placement increase actual joint flexion.
## Do not subtract a fixed number from IK reach: that would cause foot sliding.
const BODY_CROUCH_WORLD_METERS: float = 0.34
const STANCE_TUCK_METERS: float = 0.42
## A broken shin skids out while the chassis briefly dips to melee-head height.
const LEG_BREAK_REACTION_SECONDS: float = 2.5
# A full, separate anticipatory beat; the original down duration begins
# AFTER these 0.60 seconds, not inside it.
const LEG_BREAK_WINDUP_SECONDS: float = 0.60
const LEG_BREAK_WINDUP_HEAD_LIFT_DEGREES: float = 26.0
const LEG_BREAK_WINDUP_HEAD_DIP_DEGREES: float = 4.0
const LEG_BREAK_FRONT_REACH_METERS: float = 0.24
const GROUND_HOVER_THRESHOLD_METERS: float = 0.045
const GROUND_CORRECTION_MAX_PER_TICK_METERS: float = 0.18
const LEG_BREAK_FALL_SECONDS: float = 0.17
const LEG_BREAK_RECOVER_START_SECONDS: float = 2.10
const ALL_LEGS_BREAK_REACTION_SECONDS: float = 6.0
const ALL_LEGS_BREAK_RECOVER_START_SECONDS: float = 5.40
const LEG_BREAK_SLIDE_METERS: float = 1.05
const HEAD_MELEE_REACH_WORLD_Y: float = 1.35
const MAX_LEG_BREAK_DROP_METERS: float = 1.45
const MAX_LEG_BREAK_NOSE_DIP_DEGREES: float = 68.0
const HEAD_HEIGHT_SOLVE_STEPS: int = 13

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
var rest_actor_local_y: float = 0.0
var break_elapsed: float = -1.0
var windup_elapsed: float = -1.0
var front_anchor_rest: Dictionary = {}
var front_extension_direction: Dictionary = {}
var ground_correction_world: float = 0.0
var head_bone: Node3D
var break_duration: float = LEG_BREAK_REACTION_SECONDS
var break_recover_start: float = LEG_BREAK_RECOVER_START_SECONDS
var break_drop_world: float = 0.0
var break_leg_index: int = -1
var break_anchor: Vector3 = Vector3.ZERO
var break_slide: Vector3 = Vector3.ZERO
var chassis_bone: Node3D
var rest_chassis_rotation: Quaternion = Quaternion.IDENTITY
var head_mesh_for_height: MeshInstance3D
var break_head_start_y: float = 0.0

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
    # actor.position is in the scaled target's local units, while contact
    # measurements and the requested crouch are in world metres.
    var parent_scale_y: float = maxf(absf(actor.get_parent().global_basis.get_scale().y), 0.001)
    actor.position.y += (FLOOR_Y - average_sole_y - BODY_CROUCH_WORLD_METERS) / parent_scale_y
    rest_actor_local_y = actor.position.y
    chassis_bone = actor.find_child("Body", true, false) as Node3D
    if chassis_bone == null:
        return false
    # Keep the authored Wait 25-degree BODY pose through setup/reset.
    rest_chassis_rotation = chassis_bone.quaternion
    var authored_head: Node3D = actor.find_child("Head", true, false) as Node3D
    if authored_head == null:
        return false
    head_bone = authored_head
    for head_child in authored_head.get_children():
        if head_child is MeshInstance3D:
            head_mesh_for_height = head_child as MeshInstance3D
            break
    if head_mesh_for_height == null:
        return false
    reset()
    ready = true
    # Ensure soles are on the floor immediately, before the first physics tick.
    advance_ik(0.0, "Idle")
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
    actor.position.y = rest_actor_local_y
    if chassis_bone != null:
        chassis_bone.quaternion = rest_chassis_rotation
    break_elapsed = -1.0
    windup_elapsed = -1.0
    ground_correction_world = 0.0
    front_anchor_rest.clear()
    front_extension_direction.clear()
    break_duration = LEG_BREAK_REACTION_SECONDS
    break_recover_start = LEG_BREAK_RECOVER_START_SECONDS
    break_drop_world = 0.0
    break_leg_index = -1
    stepping_pair = -1
    preferred_pair = 0
    cooldown = 0.0
    last_actor_position = actor.global_position
    last_actor_yaw = actor.global_rotation.y
    for leg in legs:
        var foot: Node3D = leg["foot"]
        # Reinitialize with a tucked, reachable world-space stance rather
        # than anchoring to the formerly straight-legged visual pose.
        leg["anchor"] = _home(leg, false)
        leg["stepping"] = false
        leg["swing_elapsed"] = 0.0
        leg["anchor_rotation"] = foot.global_basis.get_rotation_quaternion()

func _home(leg: Dictionary, with_lead: bool) -> Vector3:
    var p: Vector3 = actor.to_global(leg["rest_sole_local"])
    # Bring the wide original stance slightly inward to increase knee
    # flexion at the same planted toe height, without deforming the mesh.
    var radial: Vector3 = p - actor.global_position
    radial.y = 0.0
    if radial.length_squared() > 0.000001:
        p -= radial.normalized() * STANCE_TUCK_METERS
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
    # Rotation alone cannot transform a mesh-local sole offset when the
    # entire boss is uniformly scaled. Preserve the true world scale.
    var foot_world_scale: Vector3 = foot.global_basis.get_scale()
    var wanted_end: Vector3 = sole_goal - (Basis(desired_rotation).scaled(foot_world_scale)
        * (leg["sole_local"] as Vector3))
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
    # Never silently reset the foot's 2x inherited scale to 1x.
    foot.global_basis = Basis(desired_rotation).scaled(foot_world_scale)
    return foot.to_global(leg["sole_local"]).distance_to(sole_goal)

func _align(joint: Node3D, from_axis: Vector3, to_axis: Vector3) -> void:
    if from_axis.length_squared() <= 0.00000001 or (
            to_axis.length_squared() <= 0.00000001):
        return
    var q := Quaternion(from_axis.normalized(), to_axis.normalized())
    var original_scale: Vector3 = joint.global_basis.get_scale()
    joint.global_basis = Basis((q * joint.global_basis.get_rotation_quaternion()).normalized()).scaled(original_scale)

## Stop gait, plant all four feet, then skid the broken shin along the floor.
## The body drops only on the visual IK rig; combat target never teleports.
func start_leg_break_slide(id: String, head_world_y: float,
        all_legs_broken: bool = false) -> void:
    if not ready or actor == null:
        return
    var id_to_name: Dictionary = {
        "leg_fl": "FrontLeg_L", "leg_fr": "FrontLeg_R",
        "leg_rl": "RearLeg_L", "leg_rr": "RearLeg_R"
    }
    if not id_to_name.has(id):
        return
    # A second leg can break while the boss is already down. Refresh the
    # down timer but never snap an already fallen chassis UP into a windup.
    var already_downed: bool = break_elapsed >= 0.0
    var already_winding: bool = windup_elapsed >= 0.0
    break_leg_index = -1
    front_anchor_rest.clear()
    front_extension_direction.clear()
    for i in range(legs.size()):
        var leg: Dictionary = legs[i]
        leg["stepping"] = false
        var world_sole: Vector3 = (
            leg["foot"] as Node3D).to_global(leg["sole_local"])
        world_sole.y = FLOOR_Y
        leg["anchor"] = world_sole
        var root_name: String = (leg["upper"] as Node3D).name
        if root_name == id_to_name[id]:
            break_leg_index = i
        if root_name.begins_with("Front"):
            front_anchor_rest[i] = world_sole
            var outward: Vector3 = world_sole - actor.global_position
            outward.y = 0.0
            if outward.length_squared() < 0.00001:
                outward = actor.global_basis.x
            front_extension_direction[i] = outward.normalized()
    if break_leg_index < 0:
        return
    stepping_pair = -1
    cooldown = 0.0
    if already_downed:
        break_elapsed = 0.0
        windup_elapsed = -1.0
    elif not already_winding:
        windup_elapsed = 0.0
        break_elapsed = -1.0
    break_duration = (ALL_LEGS_BREAK_REACTION_SECONDS if all_legs_broken
        else LEG_BREAK_REACTION_SECONDS)
    break_recover_start = (ALL_LEGS_BREAK_RECOVER_START_SECONDS if all_legs_broken
        else LEG_BREAK_RECOVER_START_SECONDS)
    break_head_start_y = head_world_y
    break_drop_world = clampf(
        head_world_y - HEAD_MELEE_REACH_WORLD_Y, 0.20,
        MAX_LEG_BREAK_DROP_METERS)
    var broken: Dictionary = legs[break_leg_index]
    break_anchor = broken["anchor"]
    var spread: Vector3 = break_anchor - actor.global_position
    spread.y = 0.0
    if spread.length_squared() < 0.0001:
        spread = actor.global_basis.x
    break_slide = spread.normalized() * LEG_BREAK_SLIDE_METERS


func windup_active() -> bool:
    return windup_elapsed >= 0.0


func down_pose_active() -> bool:
    return break_elapsed >= 0.0


func windup_progress() -> float:
    if windup_elapsed < 0.0:
        return 0.0
    return clampf(windup_elapsed / LEG_BREAK_WINDUP_SECONDS, 0.0, 1.0)


func _cubic(t: float) -> float:
    var x: float = clampf(t, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)

func _advance_leg_break(delta: float) -> void:
    var parent_scale_y: float = maxf(
        absf(actor.get_parent().global_basis.get_scale().y), 0.001)
    if windup_elapsed >= 0.0:
        windup_elapsed += maxf(delta, 0.0)
        var progress: float = windup_progress()
        # Heavy anticipation: slight initial head dip, a slow accelerating
        # nose-up throw, then weight settling before the actual fall.
        var pitch_degrees: float = 0.0
        if progress < 0.20:
            pitch_degrees = -LEG_BREAK_WINDUP_HEAD_DIP_DEGREES * _cubic(
                progress / 0.20)
        elif progress < 0.80:
            pitch_degrees = lerpf(-LEG_BREAK_WINDUP_HEAD_DIP_DEGREES,
                LEG_BREAK_WINDUP_HEAD_LIFT_DEGREES,
                _cubic((progress - 0.20) / 0.60))
        else:
            pitch_degrees = LEG_BREAK_WINDUP_HEAD_LIFT_DEGREES * (
                1.0 - _cubic((progress - 0.80) / 0.20))
        if head_bone != null:
            head_bone.quaternion = (head_bone.quaternion *
                Quaternion(Vector3.RIGHT,
                deg_to_rad(pitch_degrees))).normalized()
        # Reach forward with both forelimbs by extending their PLANTED sole
        # anchors, rather than raising toes or moving the whole robot upward.
        var reach: float = LEG_BREAK_FRONT_REACH_METERS * _cubic(
            minf(progress / 0.72, 1.0))
        for index in front_anchor_rest:
            var leg: Dictionary = legs[index]
            leg["anchor"] = (front_anchor_rest[index] as Vector3) + (
                front_extension_direction[index] as Vector3) * reach
        actor.position.y = (rest_actor_local_y
            + ground_correction_world / parent_scale_y)
        if windup_elapsed >= LEG_BREAK_WINDUP_SECONDS:
            # The last windup frame is exactly neutral, so the original
            # head joint starts the falling animation without a rotation pop.
            windup_elapsed = -1.0
            break_elapsed = 0.0
        return

    var amount: float = 0.0
    if break_elapsed >= 0.0 and break_leg_index >= 0:
        break_elapsed += maxf(0.0, delta)
        if break_elapsed < LEG_BREAK_FALL_SECONDS:
            amount = _cubic(break_elapsed / LEG_BREAK_FALL_SECONDS)
        elif break_elapsed < break_recover_start:
            amount = 1.0
        elif break_elapsed < break_duration:
            amount = 1.0 - _cubic((break_elapsed - break_recover_start)
                / (break_duration - break_recover_start))
    # This is a visual-only chassis drop; foot anchors stay at world Y=0.
    # Include the persistent grounding correction to prevent a 1-frame
    # hover when the hips move through the analytical IK reach limit.
    actor.position.y = (rest_actor_local_y
        + (ground_correction_world - amount * break_drop_world)
        / parent_scale_y)
    if break_elapsed >= 0.0 and chassis_bone != null             and head_mesh_for_height != null:
        var base_pose: Quaternion = chassis_bone.quaternion
        var desired_head_y: float = lerpf(break_head_start_y,
            HEAD_MELEE_REACH_WORLD_Y, amount)
        if amount > 0.00001:
            var lo: float = 0.0
            var hi: float = deg_to_rad(MAX_LEG_BREAK_NOSE_DIP_DEGREES)
            for i in range(HEAD_HEIGHT_SOLVE_STEPS):
                var mid: float = (lo + hi) * 0.5
                chassis_bone.quaternion = (base_pose *
                    Quaternion(Vector3.RIGHT, -mid)).normalized()
                var head_y: float = head_mesh_for_height.to_global(
                    head_mesh_for_height.mesh.get_aabb().get_center()).y
                if head_y > desired_head_y:
                    lo = mid
                else:
                    hi = mid
            chassis_bone.quaternion = (base_pose *
                Quaternion(Vector3.RIGHT, -(lo + hi) * 0.5)).normalized()
        else:
            chassis_bone.quaternion = base_pose
    # Ease the two front legs from their slight stretch to the planted
    # anchors as the chest falls. The broken leg still skids separately.
    var reach_end: float = 1.0 - _cubic(
        clampf(break_elapsed / LEG_BREAK_FALL_SECONDS, 0.0, 1.0))
    if break_elapsed >= 0.0:
        for index in front_anchor_rest:
            var leg: Dictionary = legs[index]
            leg["anchor"] = (front_anchor_rest[index] as Vector3) + (
                front_extension_direction[index] as Vector3) * (
                LEG_BREAK_FRONT_REACH_METERS * reach_end)
        var leg: Dictionary = legs[break_leg_index]
        var skidding: Vector3 = break_anchor + break_slide * amount
        skidding.y = FLOOR_Y
        leg["anchor"] = skidding
        if break_elapsed >= break_duration:
            break_elapsed = -1.0
            break_leg_index = -1
            front_anchor_rest.clear()
            front_extension_direction.clear()


func break_reaction_active() -> bool:
    # Freeze AI/gait and permit weakpoint lock from the breaking hit onward.
    # The original 2.5/6s down timer itself starts after the 0.6s windup.
    return windup_active() or down_pose_active()

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
    _advance_leg_break(delta)
    var active: bool = (motion == "Approach" or motion == "Turn") and not break_reaction_active()
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
    # Reconcile the actual visible sole contacts with the visual-only
    # arena floor. Some maximum-reach/down transitions can momentarily
    # leave ALL four soles hovering. Do not push the torso up in response to
    # a raised stepping foot; use only planted feet and solve once again.
    var min_planted_height: float = INF
    var planted_count: int = 0
    for leg in legs:
        if bool(leg["stepping"]):
            continue
        planted_count += 1
        var world_sole: Vector3 = (
            leg["foot"] as Node3D).to_global(leg["sole_local"])
        min_planted_height = minf(min_planted_height, world_sole.y)
    if planted_count >= 2 and min_planted_height != INF             and absf(min_planted_height) > GROUND_HOVER_THRESHOLD_METERS:
        var correction: float = clampf(-min_planted_height,
            -GROUND_CORRECTION_MAX_PER_TICK_METERS,
            GROUND_CORRECTION_MAX_PER_TICK_METERS)
        var scale_y: float = maxf(
            absf(actor.get_parent().global_basis.get_scale().y), 0.001)
        ground_correction_world += correction
        actor.position.y += correction / scale_y
        for leg in legs:
            var foot_pos: Vector3 = leg["anchor"]
            var foot_rot: Quaternion = leg["anchor_rotation"]
            if bool(leg["stepping"]):
                continue
            leg["last_error"] = _solve(leg, foot_pos, foot_rot)

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
