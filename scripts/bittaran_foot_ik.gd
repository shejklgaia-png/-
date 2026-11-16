extends RefCounted
const BittaranParts = preload("res://scripts/bittaran_parts.gd")
## Analytical two-bone IK for four independent Bittaran legs.
## The authored Blockbench asset, joints, Wait pose and animation UUIDs are
## unchanged. The pose clips are evaluated first; grounded IK is layered last.
## The sole anchor is measured from the real imported foot mesh AABB.
const FLOOR_Y: float = 0.0
# A visible chassis plate must never intersect the arena when the
# authored low attack pose or leg-break nose-dip lowers the rig.
const BODY_MESH_FLOOR_CLEARANCE_METERS: float = 0.020
# v414: Rear-leg attacks go from the authored Wait backward lean to an
# equal-magnitude FORWARD lean at full strike/hold. Never stack a relative
# 8-degree tail lift onto the authored BODY rotation. The Wait local-X
# angle is measured from rest_chassis_rotation, so asset edits remain valid.
# Only the pitch is replaced; authored yaw/roll, head aim and limb clips
# retain their existing owners. Rear attacks never translate the visual
# BODY/root vertically as a workaround for reaching a contact.
const STEP_TRIGGER_METERS: float = 0.76
const STEP_DURATION_SECONDS: float = 0.58
const STEP_HEIGHT_METERS: float = 0.34
# Two IK-controlled diagonal replanting pairs before any attack begins.
# The untouched diagonal remains planted during each move; the authored
# windup/strike never starts until both pairs reach their Wait sole
# positions AND orientations. This interval is outside attack playback.
const ATTACK_STANCE_PAIR_SECONDS: float = 0.32
const ATTACK_STANCE_STEP_HEIGHT_METERS: float = 0.12
const ATTACK_STANCE_STEP_LIFT_DISTANCE_METERS: float = 0.35
## Approach feet land 1.30x farther ahead without speeding up the swing.
const STEP_FORWARD_LEAD_METERS: float = 0.364
## Scale the translation threshold only while approaching. Turning feet
## retain the original 0.76m threshold and swing time.
const STEP_APPROACH_TRIGGER_METERS: float = 0.988
const STEP_COOLDOWN_SECONDS: float = 0.10
# Locomotion weight shift (v401): while a diagonal pair is airborne the
# chassis leans toward the planted pair's support centroid and sinks a
# few centimetres, so the body reads as heavy instead of gliding at a
# perfectly constant height. Purely additive on top of the sampled rig
# pose, exactly like the attack chassis pose: the four world-anchored
# soles are re-solved against their fixed positions afterwards, and
# every term decays to zero when locomotion stops.
const GAIT_SWAY_MAX_RADIANS: float = 0.040
const GAIT_SWAY_RESPONSE_PER_SECOND: float = 5.0
const GAIT_DIP_METERS: float = 0.040
const GAIT_TOUCHDOWN_DIP_METERS: float = 0.020
# A landing target must be the live foot placement beneath the turned
# chassis. Do not alter the authored STEP_DURATION_SECONDS to catch up.
const RECOVERY_FOOT_CATCHUP_THRESHOLD_METERS: float = 0.16
const MAX_TELEPORT_METERS: float = 1.50
const MAX_YAW_SNAP_RADIANS: float = 1.4
const IK_REACH_MARGIN_METERS: float = 0.002
# v406: KICK strike shortening, calibrated with bittaran_rig's
# KICK_REACH_BASE_METERS / KICK_REACH_PER_FACTOR (the target
# hip->foot XZ length is BASE + reach_factor * PER, i.e. the
# locked aim distance + the rig's aim margin when unclamped).
const KICK_REACH_BASE_METERS: float = 2.30
const KICK_REACH_PER_FACTOR: float = 3.2
# v410: the KICK trajectory blends from the planted basic stance
# (held through the windup) to the reflected source trajectory
# over this first segment of the strike; the source clip holds
# its fold for roughly the first 0.25s of clip time, so the blend
# completes inside that hold and the extension is purely authored.
const KICK_TRAJECTORY_ENTRY_BLEND_SECONDS: float = 0.25
# v410: the SWEEP strike entry blends from the planted basic
# stance to the sampled authored pose over this window; it must
# match the SWEEP leg blend-in ramp in bittaran_rig's
# apply_authored_attack_pose (0.36s, the clip's full-speed
# outbound lead-in), at whose end the solved pose meets the pure
# authored pose the freeze branch takes over.
const SWEEP_ENTRY_BLEND_SECONDS: float = 0.36
# v410: extra whole-limb lift margin for the SWEEP entry blend,
# enveloped by 4*bw*(1-bw) so it peaks mid-blend and vanishes at
# the plant and at the freeze handover (see the entry branch).
const SWEEP_ENTRY_LIFT_MARGIN_METERS: float = 0.06
# When the chest turns beyond the planted foot's stance bearing, wrap
# its knee pole around the hip-to-ankle axis to make a controlled HELIX,
# instead of stretching one unchanging flat knee plane. Bone lengths and
# exact world-planted soles remain owned by the ordinary two-bone IK.
const SPIRAL_START_LAG_DEGREES: float = 8.0
const SPIRAL_FULL_LAG_DEGREES: float = 75.0
const SPIRAL_MAX_TWIST_DEGREES: float = 70.0
const SPIRAL_TWIST_SPEED_DEGREES_PER_SECOND: float = 220.0
# Fold the knees farther when THEY swing or replant into the head.
# Keep the exact heel/sole target; increase the lateral pole only.
const HEAD_KNEE_SCAN_SECONDS: float = 0.05
const HEAD_KNEE_OUTWARD_DOWN_BIAS: float = 0.28
const HEAD_KNEE_PROXIMITY_METERS: float = 0.45
const HEAD_KNEE_MAX_BEND: float = 0.70
const HEAD_KNEE_FLEX_IN_PER_SECOND: float = 3.00
const HEAD_KNEE_FLEX_OUT_PER_SECOND: float = 1.35
# Shared hard limit is 20cm; begin bending knees at 13cm so the
# head can keep tracking while its support leg yields first.
const HEAD_KNEE_ALLOWED_PENETRATION_METERS: float = (
    BittaranParts.HEAD_LEG_ALLOWED_PENETRATION_METERS)
const HEAD_KNEE_PREFERRED_PENETRATION_METERS: float = 0.13
const HEAD_KNEE_MIN_BENEFIT_METERS: float = 0.008
const HEAD_KNEE_BEND_PENALTY_METERS: float = 0.025
const HEAD_KNEE_TARGET_HYSTERESIS_METERS: float = 0.009
# A heavy chassis dominates the approximate center of mass, while four
# independent knee/leg assemblies each contribute 4.5% of the total.
const HEAD_KNEE_BODY_MASS: float = 0.82
const HEAD_KNEE_LEG_MASS: float = 0.045
const HEAD_KNEE_BALANCE_PENALTY: float = 0.020
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
# After the last recovery frame, finish one complete Idle pose/blend
# before Turn/Approach is permitted. Matches BittaranRig.BLEND_SECONDS.
const POST_DOWN_IDLE_SETTLE_SECONDS: float = 0.24
const POST_DOWN_UPRIGHT_TOLERANCE_WORLD_METERS: float = 0.06
const LEG_BREAK_RECOVER_START_SECONDS: float = 2.10
const ALL_LEGS_BREAK_REACTION_SECONDS: float = 6.0
const ALL_LEGS_BREAK_RECOVER_START_SECONDS: float = 5.40
# Exactly timed rise, independent of the original fall/grounded hold.
const SINGLE_LEG_RISE_SECONDS: float = 1.0
const FOUR_LEG_RISE_SECONDS: float = 1.3
# Positive local-X BODY pitch raises the two front shoulder pivots.
const STANDUP_BACK_LEAN_DEGREES: float = 10.0
const LEG_BREAK_SLIDE_METERS: float = 1.05
const HEAD_MELEE_REACH_WORLD_Y: float = 1.35
const MAX_LEG_BREAK_DROP_METERS: float = 1.45
const MAX_LEG_BREAK_NOSE_DIP_DEGREES: float = 68.0
const HEAD_HEIGHT_SOLVE_STEPS: int = 13
# Only a foot close to the actual nose/head XZ footprint may turn sideways.
# The threshold includes the measured head/leg collision footprints, with
# a small allowance for a rotating IK stance; Y NEVER enters the decision.
const HEAD_FOOT_HORIZONTAL_EXTRA_METERS: float = 0.18
const HEAD_FOOT_HORIZONTAL_MAX_METERS: float = 1.75
const HEAD_FOOT_HORIZONTAL_MIN_METERS: float = 0.65
const SUPPORT_LEG_OUTWARD_METERS: float = 0.62
const SUPPORT_FOOT_ROLL_DEGREES: float = 72.0
const SUPPORT_HEAD_COLLISION_GAP_METERS: float = 0.015
const SUPPORT_COLLISION_ITERATIONS: int = 12
const LEG_PART_IDS: Array[String] = ["leg_fr", "leg_rl", "leg_fl", "leg_rr"]

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
var gait_sway_roll: float = 0.0
var gait_sway_pitch: float = 0.0
var gait_dip: float = 0.0
var gait_dip_pulse: float = 0.0
var gait_prev_stepping: Array[bool] = [false, false, false, false]
var rest_actor_local_y: float = 0.0
var break_elapsed: float = -1.0
var windup_elapsed: float = -1.0
var post_down_idle_remaining: float = 0.0
var recovery_gait_started: bool = false
var recovery_catchup_pending_pair: int = -1
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
var collision_parts: Node3D
var head_support_leg_index: int = -1
var head_support_leg_id: String = ""
var head_support_sole_at_down: Vector3 = Vector3.ZERO
var head_support_outward: Vector3 = Vector3.ZERO
var head_support_foot_rotation: Quaternion = Quaternion.IDENTITY
var head_support_contact: bool = false
var break_chassis_base_pose: Quaternion = Quaternion.IDENTITY
var break_chassis_pitch_radians: float = 0.0
var head_knee_scan_elapsed: float = HEAD_KNEE_SCAN_SECONDS
var head_knee_active: bool = false
var attack_pose: Dictionary = {}
var attack_stance_active: bool = false
var attack_stance_ready: bool = false
var attack_stance_leg_id: String = ""
var attack_stance_elapsed: float = 0.0
# Attack-interrupted knockdown keeps the original head tracker active
# and blends only the former attacking limb + chassis to STOMP prepose.
var attack_down_windup_leg_id: String = ""
# Nose-up pitch is an additive DOWN-anticipation tilt only. HEAD yaw is
# always owned by battle.gd; the rig never plays/overwrites HEAD keys.
var head_windup_pitch_degrees: float = 0.0
# Calculated once from the authored t=0 contact pose when KICK/SWEEP
# begins, then retained across the strike without resampling the floor.
var initial_attack_contact_height_world: float = 0.0

## Queue a separate neutral-stance return without changing the attack
## timeline, root position/yaw, bone keys or the down/recovery state.
## The standing legs use existing analytical two-bone _solve() IK.
func begin_attack_stance(id: String) -> void:
    if attack_stance_active or not ready or legs.size() != 4:
        return
    attack_stance_active = true
    attack_stance_ready = false
    attack_stance_leg_id = id
    attack_stance_elapsed = 0.0
    # Any ordinary Turn/Approach step is replaced by this pair-by-pair
    # controlled replant. Preserve the actual visible ankle position
    # when a gait is interrupted rather than jumping to cached anchors.
    stepping_pair = -1
    for leg in legs:
        var foot: Node3D = leg["foot"]
        # set_motion() restores local authored pivots before IK runs in
        # this frame, so sampling foot.global_position here would read
        # the unsolved Idle foot and cause a visible one-frame teleport.
        # last_goal/last_rotation are the FINAL rendered contacts from
        # the previous IK frame and form the continuous prep entry.
        leg["stance_from"] = leg.get("last_goal",
            foot.to_global(leg["sole_local"] as Vector3))
        leg["stance_rotation_from"] = leg.get("last_rotation",
            foot.global_basis.get_rotation_quaternion())
        leg["stance_to"] = _home(leg, false)
        leg["stance_rotation_to"] = _rotation_home(leg)
        leg["stepping"] = false
        leg["anchor"] = leg["stance_from"]
        leg["anchor_rotation"] = leg["stance_rotation_from"]


func attack_stance_is_ready() -> bool:
    return attack_stance_active and attack_stance_ready


func clear_attack_stance() -> void:
    attack_stance_active = false
    attack_stance_ready = false
    attack_stance_leg_id = ""
    attack_stance_elapsed = 0.0
    for leg in legs:
        for key in ["stance_from", "stance_rotation_from",
                "stance_to", "stance_rotation_to"]:
            leg.erase(key)


func _advance_attack_stance(delta: float) -> void:
    if not attack_stance_active or attack_stance_ready:
        return
    var pair_seconds: float = ATTACK_STANCE_PAIR_SECONDS
    attack_stance_elapsed = minf(2.0 * pair_seconds,
        attack_stance_elapsed + maxf(delta, 0.0))
    # Existing LEG_PAIRS are [front-right, rear-left] and
    # [front-left, rear-right]: true diagonal supports.
    var pair: int = mini(1, int(attack_stance_elapsed / pair_seconds))
    var pair_time: float = (attack_stance_elapsed -
        float(pair) * pair_seconds)
    var u: float = clampf(pair_time / pair_seconds, 0.0, 1.0)
    var eased: float = u * u * (3.0 - 2.0 * u)
    for i in range(legs.size()):
        var leg: Dictionary = legs[i]
        var from: Vector3 = leg["stance_from"]
        var to: Vector3 = leg["stance_to"]
        var from_rot: Quaternion = leg["stance_rotation_from"]
        var to_rot: Quaternion = leg["stance_rotation_to"]
        var leg_pair: int = 0 if LEG_PAIRS[0].has(i) else 1
        if leg_pair < pair:
            leg["anchor"] = to
            leg["anchor_rotation"] = to_rot
        elif leg_pair == pair:
            var target: Vector3 = from.lerp(to, eased)
            var distance: float = Vector2(
                from.x - to.x, from.z - to.z).length()
            var turn: float = from_rot.angle_to(to_rot)
            var lift_weight: float = clampf(maxf(
                distance / ATTACK_STANCE_STEP_LIFT_DISTANCE_METERS,
                turn / deg_to_rad(35.0)), 0.0, 1.0)
            target.y += sin(PI * u) * (
                ATTACK_STANCE_STEP_HEIGHT_METERS * lift_weight)
            leg["anchor"] = target
            leg["anchor_rotation"] = from_rot.slerp(
                to_rot, eased).normalized()
        # The other diagonal remains planted at its original actual
        # world-space sole during the moving diagonal's IK transition.
    if attack_stance_elapsed >= 2.0 * pair_seconds - 0.000001:
        for leg in legs:
            leg["anchor"] = leg["stance_to"]
            leg["anchor_rotation"] = leg["stance_rotation_to"]
        attack_stance_ready = true


func set_collision_parts(parts: Node3D) -> void:
    # Use the SAME authored collider AABBs that sync_bittaran_parts() places
    # on target_collider. Head/leg do not self-resolve inside one physics body.
    collision_parts = parts


## The attack director is the sole writer of this per-frame, deterministic pose.
## IK remains the only owner of foot goals, joint lengths and knee poles.
func set_attack_pose(pose: Dictionary) -> void:
    # v410: a restarted attack (the director force-started over a
    # still-active one) never empties the pose, so the previous
    # attack's recovery never runs and its fitted KICK sole point
    # leaks into this attack: the contact probe below and the
    # trajectory's clearance reference both read the SOURCE leg's
    # sole point and would silently use the stale fit (measured:
    # leg_rr's played fold shifted 0.12 rad across a sequence of
    # interrupted attacks). Detect the restart (identity change
    # or a rewound attack clock) and restore every fitted sole
    # point before anything reads one.
    # A normal completed attack follows exactly the same teardown as
    # interruption. Merely setting attack_pose={} left fitted sole,
    # exit-lift and pole caches available to contaminate the next windup.
    if pose.is_empty() and not attack_pose.is_empty():
        clear_attack_pose()
        return
    if not pose.is_empty() and not attack_pose.is_empty():
        var restarted: bool = (
            str(pose.get("id", "")) != str(attack_pose.get("id", ""))
            or str(pose.get("kind", ""))
                != str(attack_pose.get("kind", ""))
            or float(pose.get("time", 0.0))
                < float(attack_pose.get("time", 0.0)) - 0.0001)
        if restarted:
            # Every attack (including forced restarts in tests) must
            # start with untouched pivots, pole targets and height.
            clear_attack_pose()
    if attack_pose.is_empty() and not pose.is_empty() and legs.size() == 4:
        initial_attack_contact_height_world = 0.0
        var kind: String = str(pose.get("kind", ""))
        if bool(pose.get("authored", false)) and (
                kind == "kick" or kind == "sweep"):
            var attack_id: String = str(pose.get("id", ""))
            var index: int = LEG_PART_IDS.find(attack_id)
            if index >= 0 and actor != null and actor.has_method(
                    "initial_authored_sole_height"):
                # v409: for KICK the played pose is the reflected
                # source trajectory, so the contact offset is
                # calibrated to that trajectory's clip-0 sole for
                # this leg, not to its delta fold (the folds sit
                # up to 1.15m apart between legs). The kick probe
                # reads the SOURCE leg's sole point on leg_fl's
                # foot, so it takes leg_fl's sole_local; passing
                # the attacker's own read a point up to 3.0m away
                # on the wrong side of the source foot and pushed
                # the whole trajectory that far under the floor
                # (the post-solve clip guard then lifted the sole
                # back by the penetration, flattening the fold).
                var probe_sole: Vector3 = legs[index]["source_sole_local"]
                var first_height: float = NAN
                if kind == "kick":
                    probe_sole = legs[LEG_PART_IDS.find(
                        "leg_fl")]["source_sole_local"]
                    first_height = float(actor.call(
                        "kick_source_contact_height", attack_id,
                        probe_sole))
                else:
                    first_height = float(actor.call(
                        "initial_authored_sole_height", kind,
                        attack_id, probe_sole))
                if is_finite(first_height):
                    # All 4 retargeted limbs differ in actual pivot
                    # height. Limiting the measured displacement caused
                    # rear/other-side feet to remain visibly airborne.
                    # The authored contact sample is finite and canonical:
                    # use its exact initial offset, once per attack.
                    initial_attack_contact_height_world = FLOOR_Y - first_height
        # End the previous gait in its actual contact position; attack
        # telegraphs begin from the visible, not the cached old, sole.
        for leg in legs:
            leg.erase("stomp_authored_windup_goal")
            leg.erase("stomp_authored_windup_rotation")
            leg.erase("stomp_impact_sole")
            leg.erase("stomp_impact_rotation")
            # Capture the visible sole and orientation BEFORE cancelling
            # the Turn/Approach swing. Preserve its world XZ position and
            # ease any airborne toe down during the 0.24s clip crossfade.
            leg["attack_entry_goal"] = leg["last_goal"]
            if bool(leg["stepping"]):
                var world: Vector3 = leg["last_goal"]
                world.y = FLOOR_Y
                leg["anchor"] = world
                leg["anchor_rotation"] = leg["last_rotation"]
                leg["stepping"] = false
        stepping_pair = -1
        cooldown = STEP_COOLDOWN_SECONDS
    if pose.is_empty():
        initial_attack_contact_height_world = 0.0
    attack_pose = pose.duplicate()

func begin_attack_down_windup(id: String) -> void:
    attack_down_windup_leg_id = id


func attack_down_windup_active() -> bool:
    return not attack_down_windup_leg_id.is_empty() and windup_active()


func clear_attack_down_windup() -> void:
    attack_down_windup_leg_id = ""


func clear_attack_pose() -> void:
    attack_pose.clear()
    clear_attack_stance()
    # Clear even when the attack is cancelled INSIDE a damage callback,
    # before the next normal set_attack_pose(empty) frame.
    initial_attack_contact_height_world = 0.0
    gait_sway_roll = 0.0
    gait_sway_pitch = 0.0
    gait_dip = 0.0
    gait_dip_pulse = 0.0
    gait_prev_stepping = [false, false, false, false]
    for leg in legs:
        # Spiral winding is a transient positional compensation, not
        # a persistent limb calibration carried between attacks.
        leg["spiral_twist"] = 0.0
        leg.erase("stomp_authored_windup_goal")
        leg.erase("stomp_authored_windup_rotation")
        leg.erase("stomp_impact_sole")
        leg.erase("stomp_impact_rotation")
        leg.erase("attack_exit_goal")
        leg.erase("attack_exit_rotation")
        leg.erase("attack_exit_lift_world")
        leg.erase("attack_entry_goal")
        leg.erase("authored_pole_active")
        leg.erase("authored_pole_point")
        leg.erase("kick_traj_entry_sole")
        leg.erase("kick_traj_entry_rotation")
        leg.erase("kick_traj_entry_knee")
        leg.erase("kick_traj_entry_foot")
        leg.erase("sweep_entry_sole")
        leg.erase("sweep_entry_rotation")
        leg.erase("sweep_entry_knee")
        leg.erase("sweep_entry_foot")
        leg.erase("plant_goal")
        leg.erase("plant_rotation")
        # Each kick may temporarily fit a different sole point to
        # mirror the author's ankle trajectory. The original contact
        # must be the single source of truth for the next strike.
        leg["sole_local"] = leg["source_sole_local"]
        leg.erase("sole_local_saved")
        leg.erase("sole_local_traj")

func available_attack_feet() -> Dictionary:
    var result: Dictionary = {}
    if not ready:
        return result
    for i in range(legs.size()):
        result[LEG_PART_IDS[i]] = legs[i]["anchor"]
    return result

func attack_foot_aabb() -> AABB:
    # The STOMP's physical foot strike is independent of its 1.5x
    # ground shockwave. Only actual attached foot meshes count here.
    if attack_pose.is_empty():
        return AABB()
    var i: int = LEG_PART_IDS.find(str(attack_pose.get("id", "")))
    if i < 0 or i >= legs.size():
        return AABB()
    var foot: Node3D = legs[i]["foot"]
    var first: bool = true
    var low: Vector3 = Vector3.ZERO
    var high: Vector3 = Vector3.ZERO
    for child in foot.get_children():
        if not child is MeshInstance3D:
            continue
        var piece: MeshInstance3D = child as MeshInstance3D
        if piece.mesh == null:
            continue
        var bounds: AABB = piece.mesh.get_aabb()
        for j in range(8):
            var vertex: Vector3 = piece.to_global(bounds.get_endpoint(j))
            if first:
                low = vertex
                high = vertex
                first = false
            else:
                low = low.min(vertex)
                high = high.max(vertex)
    if first:
        return AABB()
    return AABB(low, high - low)


func attack_contact_world() -> Vector3:
    if attack_pose.is_empty():
        return Vector3.ZERO
    var i: int = LEG_PART_IDS.find(str(attack_pose.get("id", "")))
    if i < 0 or i >= legs.size():
        return Vector3.ZERO
    # A saturated two-bone IK limb can fall short of the requested head
    # position. STOMP's impact/shockwave must use the VISIBLE real sole,
    # not the unreachable requested point.
    if str(attack_pose.get("kind", "")) == "stomp":
        # The Wait-stance sole marker is on the SIDE of the long toe
        # after the STOMP short end is made horizontal. Use the actual
        # bottom face of the rendered striking foot for shockwave/hit.
        var foot_box: AABB = attack_foot_aabb()
        if foot_box.has_volume():
            var center: Vector3 = foot_box.get_center()
            return Vector3(center.x, foot_box.position.y, center.z)
        var leg: Dictionary = legs[i]
        return (leg["foot"] as Node3D).to_global(
            leg["sole_local"] as Vector3)
    return legs[i]["last_goal"]

func _attack_weight() -> float:
    if attack_pose.is_empty():
        return 0.0
    var t: float = float(attack_pose.get("time", 0.0))
    var windup: float = float(attack_pose.get("windup", 1.0))
    var strike: float = float(attack_pose.get("strike", 0.2))
    var recovery: float = float(attack_pose.get("recovery", 0.5))
    var hold: float = float(attack_pose.get("hold", 0.0))
    var incoming: float = _cubic(t / maxf(windup, 0.001))
    var outgoing: float = 1.0 - _cubic(
        (t - windup - strike - hold) / maxf(recovery, 0.001))
    return incoming * outgoing

func _rear_attack_active() -> bool:
    return (not attack_pose.is_empty()
        and str(attack_pose.get("id", "")).begins_with("leg_r")
        and ["kick", "stomp", "sweep"].has(
            str(attack_pose.get("kind", ""))))


func _apply_attack_chassis_pose() -> void:
    if attack_pose.is_empty() or actor == null or chassis_bone == null:
        return
    var kind: String = str(attack_pose.get("kind", ""))
    var weight: float = _attack_weight()
    # Rotate only the articulated BODY, not target/root or the whole rig.
    # The head inherits this turn, and the four world-anchored soles are
    # solved back against their fixed positions on every physics tick.
    # Windup tracks the player; swing locks the sampled heading; recovery
    # unwinds smoothly to the authored Idle torso pose.
    var t: float = float(attack_pose.get("time", 0.0))
    var swing_end: float = float(attack_pose.get("windup", 1.0)) + float(
        attack_pose.get("strike", 0.2))
    var recover: float = float(attack_pose.get("recovery", 0.5))
    var hold: float = float(attack_pose.get("hold", 0.0))
    var yaw_release: float = 1.0 - _cubic(
        (t - swing_end - hold) / maxf(recover, 0.001))
    var rear_attack: bool = _rear_attack_active()
    if rear_attack:
        # v416: v415 counter-rotated the shoulder to retain the
        # authored upper/lower/foot WORLD orientations, but it left
        # the shoulder SOCKET POSITION parented to the newly pitched
        # chassis. At constant root height the rear socket rose >1m,
        # so the original hip-relative KICK trajectory hovered
        # 0.84–2.81m over the floor (v416 live-scene evidence).
        # Compensate the shoulder's translation too: the complete
        # authored attacking-leg transform (including its socket)
        # remains the same under v414's independent BODY pitch.
        # The correction is derived from THIS frame's original keyed
        # pose, never from last frame's IK-adjusted transforms.
        var original_body: Quaternion = chassis_bone.quaternion
        var neutral_pitch: float = rest_chassis_rotation.get_euler().x
        var keyed_euler: Vector3 = original_body.get_euler()
        keyed_euler.x = lerpf(neutral_pitch, -neutral_pitch, weight)
        var desired_body: Quaternion = Basis.from_euler(
            keyed_euler).get_rotation_quaternion().normalized()
        # Cache the original source socket BEFORE the BODY changes.
        var source_shoulder: Node3D = null
        var source_socket_world: Vector3 = Vector3.ZERO
        if bool(attack_pose.get("authored", false)):
            var index: int = LEG_PART_IDS.find(
                str(attack_pose.get("id", "")))
            if index >= 0 and index < legs.size():
                source_shoulder = legs[index]["upper"]
                source_socket_world = source_shoulder.global_position
        chassis_bone.quaternion = desired_body
        if source_shoulder != null:
            source_shoulder.quaternion = (
                desired_body.inverse() * original_body
                * source_shoulder.quaternion).normalized()
            # Translate at the anatomical SHOULDER, never the BODY root.
            # The caller's chest aim yaw applies afterward, to both
            # the original source socket and the source rotations.
            source_shoulder.global_position = source_socket_world
    var body_yaw: float = float(attack_pose.get("body_yaw", 0.0))
    chassis_bone.quaternion = (Quaternion(
        Vector3.UP, body_yaw * yaw_release)
        * chassis_bone.quaternion).normalized()
    var scale_y: float = maxf(
        absf(actor.get_parent().global_basis.get_scale().y), 0.001)
    if not rear_attack and (kind == "kick" or kind == "sweep"):
        var prepare: float = float(attack_pose.get("windup", 0.70))
        var strike: float = float(attack_pose.get("strike", 1.0))
        var ease_in: float = _cubic(t / maxf(prepare, 0.001))
        var ease_out: float = 1.0 - _cubic(
            (t - prepare - strike - hold) / maxf(recover, 0.001))
        # Contact height is sampled exactly ONCE at attack entry from
        # the author's LOW initial BODY/limb pose. No mid-swing bobbing
        # or following the moving attacking foot toward the ground.
        actor.position.y += initial_attack_contact_height_world * (
            ease_in * ease_out) / scale_y
    if kind == "stomp" and not rear_attack:
        # STOMP now plants the entire long toe VERTICALLY, which gives
        # substantially more ground reach than the horizontal v386 toe.
        # The obsolete 8cm forced BODY dip pulled supporting feet off
        # their reach limits; leave the chassis at its authored height.
        var i: int = LEG_PART_IDS.find(str(attack_pose.get("id", "")))
        if i >= 0 and i < legs.size():
            var aim: Vector3 = attack_pose.get("stomp_aim", Vector3.INF)
            var windup: float = float(attack_pose.get("windup", 1.25))
            var strike: float = float(attack_pose.get("strike", 0.25))
            if aim != Vector3.INF and t >= windup:
                var leg: Dictionary = legs[i]
                var hip: Vector3 = (leg["upper"] as Node3D).global_position
                var knee: Vector3 = (leg["lower"] as Node3D).global_position
                var foot: Node3D = leg["foot"]
                var limb_length: float = hip.distance_to(knee) + (
                    knee.distance_to(foot.global_position)) - IK_REACH_MARGIN_METERS
                # The toe points straight down at floor contact (v400),
                # restoring its vertical reach. Lower ONLY the chassis
                # enough for the two-bone limb to physically hit the floor,
                # while the other three soles remain world-planted in IK.
                var foot_quat: Quaternion = _attack_rotation(leg)
                var tip_offset: Vector3 = (
                    Basis(foot_quat).scaled(foot.global_basis.get_scale())
                    * (leg["stomp_tip_local"] as Vector3))
                var ankle_goal: Vector3 = Vector3(
                    aim.x, FLOOR_Y, aim.z) - tip_offset
                var across: Vector3 = ankle_goal - hip
                across.y = 0.0
                var up_reach: float = sqrt(maxf(
                    limb_length * limb_length - across.length_squared(), 0.0))
                var shortage: float = maxf(
                    hip.y - ankle_goal.y - up_reach, 0.0)
                var lower: float = _cubic((t - windup) / maxf(strike, 0.001))
                lower *= 1.0 - _cubic(
                    (t - windup - strike - hold) / maxf(recover, 0.001))
                actor.position.y -= minf(shortage + 0.035, 2.2) * lower / scale_y
    # KICK/SWEEP crouch/roll are now entirely driven by the user-authored
    # BODY keyframe, reached over 0.70s. Never stack the old procedural
    # crouch/67-degree roll on top of the user's exact keyframed posture.

# Convert the attack direction to an exact two-bone reach in WORLD
# metres. _solve() receives a sole position but solves the FOOT PIVOT;
# the sampled sole offset must be added back or a nominally extended
# leg stays bent. Attack poses deliberately ignore the planted floor.
func _straight_attack_goal(leg: Dictionary, world_direction: Vector3,
        desired_rotation: Quaternion) -> Vector3:
    var hip: Vector3 = (leg["upper"] as Node3D).global_position
    var knee: Vector3 = (leg["lower"] as Node3D).global_position
    var ankle: Vector3 = (leg["foot"] as Node3D).global_position
    var max_reach: float = hip.distance_to(knee) + knee.distance_to(ankle)
    var outward: Vector3 = Vector3(
        world_direction.x, 0.0, world_direction.z)
    if outward.length_squared() < 0.000001:
        outward = actor.global_basis.x
        outward.y = 0.0
    outward = outward.normalized()
    var foot: Node3D = leg["foot"]
    var target_foot_basis := Basis(desired_rotation)
    var sole_offset: Vector3 = (
        target_foot_basis.scaled(foot.global_basis.get_scale())
        * (leg["sole_local"] as Vector3))
    # The reachable end is a straight shoulder-knee-ankle line. Leave
    # only the existing 2mm solver margin, never a grounded-foot limit.
    return (hip + outward * maxf(0.0,
        max_reach - IK_REACH_MARGIN_METERS) + sole_offset)


## STOMP contact frame: the level frame pitched about the forward
## axis by a quarter turn, choosing the sign that points the MEASURED
## toe axis (see _toe_axis_local_point) straight down. The short end
## face is then level with the arena and the long toe perpendicular
## to the ground, as the v387 design intended; the previous frame
## kept local +Y up, which left the +/-X toe lying almost flat.
func _stomp_contact_rotation(leg: Dictionary, upright: Quaternion,
        forward: Vector3) -> Quaternion:
    var toe_axis: Vector3 = leg.get("toe_axis_local", Vector3.DOWN)
    var axis: Vector3 = forward.normalized()
    var best: Quaternion = upright
    var best_error: float = INF
    for sign in [1.0, -1.0]:
        var candidate: Quaternion = (Quaternion(
            axis, sign * PI * 0.5) * upright).normalized()
        var error: float = (Basis(candidate) * toe_axis).angle_to(
            Vector3.DOWN)
        if error < best_error:
            best_error = error
            best = candidate
    return best


# Preserve the source foot keys during the entire authored windup;
# pitch the toe toward the ground-normal during the 0.25s downstroke.
func _attack_rotation(leg: Dictionary) -> Quaternion:
    var original: Quaternion = leg["anchor_rotation"]
    var forward: Vector3 = Basis(original).z
    forward.y = 0.0
    if forward.length_squared() < 0.000001:
        forward = actor.global_basis.z
        forward.y = 0.0
    # Level frame (local +Y up): the KICK/SWEEP foot-levelling target.
    # STOMP derives its toe-down contact frame from it below. Neither
    # is forced onto the authored windup.
    var upright: Quaternion = Basis.looking_at(
        -forward.normalized(), Vector3.UP).get_rotation_quaternion()
    var t: float = float(attack_pose.get("time", 0.0))
    var windup: float = float(attack_pose.get("windup", 1.0))
    var strike: float = float(attack_pose.get("strike", 0.2))
    var hold: float = float(attack_pose.get("hold", 0.0))
    var recovery: float = float(attack_pose.get("recovery", 0.5))
    var release: float = _cubic((t - windup - strike - hold) /
        maxf(recovery, 0.001))
    if str(attack_pose.get("kind", "")) == "stomp":
        var windup_source: Quaternion = leg.get(
            "stomp_authored_windup_rotation",
            (leg["foot"] as Node3D).global_basis.get_rotation_quaternion())
        # The last genuine user key is the entry orientation. The actual
        # strike rotates this same toe smoothly until its short end is
        # flat on the floor and the long toe points straight down; the
        # shoulder/knee source keys are never overwritten here.
        var touchdown: float = _cubic(
            (t - windup) / maxf(strike, 0.001))
        var contact: Quaternion = _stomp_contact_rotation(
            leg, upright, forward)
        return windup_source.slerp(contact, touchdown).slerp(
            original, release).normalized()
    var preparation: float = _cubic(t / maxf(windup, 0.001))
    return original.slerp(upright, preparation * (1.0 - release)).normalized()



func _reachable_stomp_goal(leg: Dictionary, goal: Vector3,
        rotation: Quaternion) -> Vector3:
    var hip: Vector3 = (leg["upper"] as Node3D).global_position
    var knee: Vector3 = (leg["lower"] as Node3D).global_position
    var foot: Node3D = leg["foot"]
    var max_reach: float = (hip.distance_to(knee)
        + knee.distance_to(foot.global_position)
        - IK_REACH_MARGIN_METERS)
    var sole_offset: Vector3 = Basis(rotation).scaled(
        foot.global_basis.get_scale()) * (leg["sole_local"] as Vector3)
    var ankle_goal: Vector3 = goal - sole_offset
    var delta: Vector3 = ankle_goal - hip
    if delta.length_squared() > max_reach * max_reach:
        ankle_goal = hip + delta.normalized() * max_reach
    return ankle_goal + sole_offset


func _attack_goal(leg: Dictionary, desired_rotation: Quaternion) -> Vector3:
    var goal: Vector3 = leg["anchor"]
    if attack_pose.is_empty() or str(attack_pose.get("id", "")) != (
            LEG_PART_IDS[legs.find(leg)]):
        return goal
    var t: float = float(attack_pose.get("time", 0.0))
    var windup: float = float(attack_pose.get("windup", 1.0))
    var strike: float = float(attack_pose.get("strike", 0.2))
    var recovery: float = float(attack_pose.get("recovery", 0.5))
    var hold: float = float(attack_pose.get("hold", 0.0))
    var kind: String = str(attack_pose.get("kind", ""))
    var attack_progress: float = _cubic(
        (t - windup) / maxf(strike, 0.001))
    var finish: float = 1.0 - _cubic(
        (t - windup - strike - hold) / maxf(recovery, 0.001))
    var outward: Vector3 = goal - (
        leg["upper"] as Node3D).global_position
    outward.y = 0.0
    if outward.length_squared() < 0.0001:
        outward = actor.global_basis.x
    outward = outward.normalized()
    if kind == "stomp":
        # Lift THE WHOLE windup while following SERA's real head XZ.
        # The sole/toe points straight down and reaches ABOVE the head
        # before the first downstroke frame (never level with the floor).
        var aim: Vector3 = attack_pose.get("stomp_aim", Vector3.INF)
        if aim == Vector3.INF:
            aim = (leg["anchor"] as Vector3) + Vector3.UP * 1.85
        var overhead: Vector3 = Vector3(
            aim.x, maxf(aim.y + 0.35, goal.y + 1.05), aim.z)
        var touchdown: Vector3 = Vector3(aim.x, FLOOR_Y, aim.z)
        # IK requests the WAIT sole position, not the contact point.
        # Offset that solver goal by the actual short toe end's distance
        # from the old sole marker in the *current* intended toe pose.
        var toe: Node3D = leg["foot"]
        var tip_minus_sole: Vector3 = (
            Basis(desired_rotation).scaled(toe.global_basis.get_scale())
            * ((leg["stomp_tip_local"] as Vector3)
            - (leg["sole_local"] as Vector3)))
        touchdown -= tip_minus_sole
        if t <= windup:
            var lift: float = _cubic(t / maxf(windup, 0.001))
            goal = goal.lerp(overhead, lift)
        elif t <= windup + strike:
            # Strike from the LAST real authored windup pose; no snap.
            var top: Vector3 = leg.get("stomp_authored_windup_goal", overhead)
            var downward: float = _cubic(
                (t - windup) / maxf(strike, 0.001))
            goal = top.lerp(touchdown, downward)
        elif t <= windup + strike + hold:
            # Freeze the foot at impact for the complete 1.5s hit pause.
            goal = touchdown
        else:
            var retract: float = _cubic(
                (t - windup - strike - hold) / maxf(recovery, 0.001))
            # v414: the no-height-shift rear STOMP can reach the floor
            # only through its actual solved/end-effector contact point,
            # not the nominal head-target foot position. Begin recovery
            # from the recorded visible impact sole to avoid a large
            # hold->recovery teleport when the BODY pitches back.
            var return_from: Vector3 = (
                leg.get("stomp_impact_sole", touchdown)
                if _rear_attack_active() else touchdown)
            goal = return_from.lerp(goal, retract)
            # After contact, lift a little while retracting; no foot drag.
            goal.y += 0.18 * sin(PI * retract)
        # The captured rear contact was grounded by a small foot-only
        # correction during hold. Clamping its return goal to the new
        # shoulder's reach on the FIRST recovery frame would lift the toe
        # about a metre instantly. Keep the exact saved contact/return
        # goal and fade that temporary end-effector offset in the solver
        # below; never move the BODY root to resolve it.
        if not (_rear_attack_active()
                and t > windup + strike + hold):
            goal = _reachable_stomp_goal(leg, goal, desired_rotation)
    elif kind == "kick":
        # Legacy procedural fallback for tests that do not request the authored clip.
        # On release, extend HIP-KNEE-ANKLE to the physical full reach,
        # even when the foot must leave the floor to form a straight leg.
        var straight: Vector3 = _straight_attack_goal(leg, outward,
            desired_rotation)
        goal = goal.lerp(straight, attack_progress * finish)
    elif kind == "sweep":
        # The shoulder rolls close to the floor. Extend the attacking
        # leg nearly straight during anticipation, then maintain that
        # full reach throughout a horizontal side-to-side sweep.
        # Do not clamp the sole to FLOOR_Y: that artificial grounding
        # previously forced the knee to remain visibly bent.
        var preparation: float = _cubic(t / maxf(windup, 0.001))
        var tangent: Vector3 = Vector3.UP.cross(outward).normalized()
        var sweep_angle: float = deg_to_rad(52.0) * (
            2.0 * attack_progress - 1.0)
        var sweep_dir: Vector3 = (
            outward * cos(sweep_angle)
            + tangent * sin(sweep_angle)).normalized()
        var straight: Vector3 = _straight_attack_goal(leg, sweep_dir,
            desired_rotation)
        goal = goal.lerp(straight, preparation * finish)
    # Blend an in-flight locomotion foot into its new world-fixed attack
    # anchor. This avoids an abrupt Y snap when cancelling Approach/Turn.
    var from: Vector3 = leg.get("attack_entry_goal", goal)
    var entry_alpha: float = _cubic(
        t / maxf(minf(0.24, windup * 0.5), 0.001))
    return from.lerp(goal, entry_alpha)

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
            "source_sole_local": sole_local,
            "stomp_tip_local": _stomp_tip_local_point(foot),
            "toe_axis_local": _toe_axis_local_point(foot),
            "pole_local": actor.global_basis.inverse() * pole.normalized(),
            "rest_sole_local": actor.to_local(foot.to_global(sole_local)),
            "rest_foot_rotation_local": actor.global_basis.get_rotation_quaternion().inverse()
                * foot.global_basis.get_rotation_quaternion(),
            "anchor": foot.to_global(sole_local),
            "anchor_rotation": foot.global_basis.get_rotation_quaternion(),
            "swing_from": Vector3.ZERO, "swing_to": Vector3.ZERO,
            "rotation_from": Quaternion.IDENTITY, "rotation_to": Quaternion.IDENTITY,
            "swing_elapsed": 0.0, "stepping": false,
            "head_knee_bend": 0.0, "head_knee_target": 0.0,
            "spiral_twist": 0.0,
            "last_goal": foot.to_global(sole_local),
            "last_rotation": foot.global_basis.get_rotation_quaternion()
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

## World-space lower bound of the ACTUAL authored foot mesh, not the
## initial sole contact point. A rotated foot can present another corner
## below ground even when the captured sole-local coordinate is above it.
## The BODY bone has exactly one direct authored mesh; its HEAD and
## articulated limbs are child joints and must NOT be included here.
## Check 8 WORLD-space mesh bounds corners, including the authored pitch/
## yaw at this physics tick, instead of assuming a static body height.
func chassis_mesh_lowest_world_y() -> float:
    if chassis_bone == null:
        return INF
    var lowest: float = INF
    for child in chassis_bone.get_children():
        if child is MeshInstance3D:
            var piece: MeshInstance3D = child as MeshInstance3D
            if piece.mesh == null:
                continue
            var bounds: AABB = piece.mesh.get_aabb()
            for index in range(8):
                lowest = minf(lowest, piece.to_global(
                    bounds.get_endpoint(index)).y)
    return lowest


func _keep_chassis_above_ground() -> void:
    if actor == null or chassis_bone == null:
        return
    # Rear attacks are rotation-only by design. This floor guard
    # previously lifted the entire BODY/root when a forward pitched
    # rear attack brought its nose close to the floor. Preserve the
    # exact standing Y and leave planted-foot geometry to IK instead.
    if _rear_attack_active():
        return
    var bottom: float = chassis_mesh_lowest_world_y()
    if not is_finite(bottom):
        return
    var required: float = (FLOOR_Y + BODY_MESH_FLOOR_CLEARANCE_METERS
        - bottom)
    if required <= 0.0:
        return
    # The actor is child of the uniformly scaled boss target. Move its
    # visual root in local Y by the exact positive WORLD-space deficit.
    # This is applied AFTER both attack-height and down-pitch controllers
    # but BEFORE world-anchored feet are solved, so no soles are dragged.
    var scale_y: float = maxf(absf(
        actor.get_parent().global_basis.get_scale().y), 0.001)
    actor.position.y += required / scale_y


func _foot_mesh_lowest_y(foot: Node3D) -> float:
    var lowest: float = INF
    for child in foot.get_children():
        if child is MeshInstance3D:
            var piece: MeshInstance3D = child as MeshInstance3D
            if piece.mesh == null:
                continue
            var box: AABB = piece.mesh.get_aabb()
            for corner in range(8):
                lowest = minf(lowest,
                    piece.to_global(box.get_endpoint(corner)).y)
    return lowest


## Lowest visible point of an entire articulated limb (the joint's own
## meshes plus every descendant joint), sampled exactly like
## _foot_mesh_lowest_y. INF when the limb has no meshes at all.
func _leg_mesh_lowest_y(joint: Node3D) -> float:
    var lowest: float = _foot_mesh_lowest_y(joint)
    for child in joint.get_children():
        if child is Node3D:
            lowest = minf(lowest, _leg_mesh_lowest_y(child as Node3D))
    return lowest


## Direction from the foot joint to the centre of its toe mesh, in
## foot-joint coordinates (pose independent). Measured from the real
## imported geometry: on this model the long toe runs along the
## joint's +/-X axis (sign differs per side), NOT along -Y as older
## comments assumed.
func _toe_axis_local_point(foot: Node3D) -> Vector3:
    for child in foot.get_children():
        if child is MeshInstance3D:
            var piece: MeshInstance3D = child as MeshInstance3D
            if piece.mesh == null:
                continue
            var centre: Vector3 = foot.to_local(
                piece.to_global(piece.mesh.get_aabb().get_center()))
            if centre.length_squared() > 0.000001:
                return centre.normalized()
    return Vector3.DOWN


## Centre of the short end of the LONG toe, in the foot joint's
## coordinates, regardless of Wait pose. v400: the previous version
## averaged the mesh corners with the lowest joint-local Y, which
## lands mid-toe (the toe runs along +/-X, so its whole underside
## shares nearly the same Y); with the toe vertical at contact, the
## goal/chassis math then placed that mid-toe point on the floor and
## the recovery goal dropped the sole ~0.94m in one tick. Measure the
## actual end face: from the mesh centre, step half the box's extent
## along the measured toe axis.
func _stomp_tip_local_point(foot: Node3D) -> Vector3:
    var axis: Vector3 = _toe_axis_local_point(foot)
    for child in foot.get_children():
        if not child is MeshInstance3D:
            continue
        var piece: MeshInstance3D = child as MeshInstance3D
        if piece.mesh == null:
            continue
        var bounds: AABB = piece.mesh.get_aabb()
        var centre: Vector3 = foot.to_local(
            piece.to_global(bounds.get_center()))
        var half_extent: float = 0.0
        for i in range(8):
            var corner: Vector3 = foot.to_local(
                piece.to_global(bounds.get_endpoint(i)))
            half_extent = maxf(half_extent,
                absf((corner - centre).dot(axis)))
        return centre + axis * half_extent
    return Vector3.ZERO


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
    gait_sway_roll = 0.0
    gait_sway_pitch = 0.0
    gait_dip = 0.0
    gait_dip_pulse = 0.0
    gait_prev_stepping = [false, false, false, false]
    post_down_idle_remaining = 0.0
    recovery_gait_started = false
    recovery_catchup_pending_pair = -1
    ground_correction_world = 0.0
    head_knee_scan_elapsed = HEAD_KNEE_SCAN_SECONDS
    head_knee_active = false
    clear_attack_pose()
    attack_down_windup_leg_id = ""
    initial_attack_contact_height_world = 0.0
    front_anchor_rest.clear()
    front_extension_direction.clear()
    break_recover_start = LEG_BREAK_RECOVER_START_SECONDS
    break_duration = break_recover_start + SINGLE_LEG_RISE_SECONDS
    break_drop_world = 0.0
    break_leg_index = -1
    _clear_head_support()
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
        leg["head_knee_bend"] = 0.0
        leg["head_knee_target"] = 0.0
        leg["spiral_twist"] = 0.0

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
        p += -actor.global_basis.z.normalized() * STEP_FORWARD_LEAD_METERS
    p.y = FLOOR_Y
    return p

func _rotation_home(leg: Dictionary) -> Quaternion:
    return (actor.global_basis.get_rotation_quaternion()
        * (leg["rest_foot_rotation_local"] as Quaternion)).normalized()

func _pair_error(pair_index: int, with_lead: bool = false) -> float:
    var magnitude: float = 0.0
    for i in LEG_PAIRS[pair_index]:
        var leg: Dictionary = legs[i]
        magnitude = maxf(magnitude,
            (leg["anchor"] as Vector3).distance_to(_home(leg, with_lead)))
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


## Compute each planted limb's rotational LAG against the BODY's current
## neutral sole bearing. Unlike foot position interpolation, this only
## changes the knee's bend plane, so the toe stays at its fixed anchor.
func _update_spiral_legs(delta: float, active_attack: bool) -> void:
    if actor == null or chassis_bone == null:
        return
    var down: bool = break_reaction_active()
    for i in range(legs.size()):
        var leg: Dictionary = legs[i]
        var target_twist: float = 0.0
        var active_limb: bool = active_attack and (
            LEG_PART_IDS[i] == str(attack_pose.get("id", "")))
        if not down and not bool(leg["stepping"]) and not active_limb:
            var hip: Vector3 = (leg["upper"] as Node3D).global_position
            var home_vector: Vector3 = _home(leg, false) - hip
            var planted_vector: Vector3 = (leg["anchor"] as Vector3) - hip
            home_vector.y = 0.0
            planted_vector.y = 0.0
            if home_vector.length_squared() > 0.01 and (
                    planted_vector.length_squared() > 0.01):
                home_vector = home_vector.normalized()
                planted_vector = planted_vector.normalized()
                var lag: float = atan2(
                    home_vector.cross(planted_vector).y,
                    home_vector.dot(planted_vector))
                var amount: float = smoothstep(
                    deg_to_rad(SPIRAL_START_LAG_DEGREES),
                    deg_to_rad(SPIRAL_FULL_LAG_DEGREES), absf(lag))
                target_twist = signf(lag) * deg_to_rad(
                    SPIRAL_MAX_TWIST_DEGREES) * amount
        leg["spiral_twist"] = move_toward(
            float(leg.get("spiral_twist", 0.0)), target_twist,
            deg_to_rad(SPIRAL_TWIST_SPEED_DEGREES_PER_SECOND)
            * maxf(delta, 0.0))

## v407: rotate a world point around the vertical line through the
## hip by an aim-yaw quaternion. The rig's aim post-multiplies the
## attacking shoulder by exactly this rotation, so applying it to a
## sampled (unaimed) sole/knee reproduces the aimed pose's point.
## v409: how far the foot mesh's lowest point hangs below the sole
## point when the foot joint sits at `joint_pos` with rotation `rot`.
## The foot node is restored before returning.
func _trajectory_mesh_clearance(leg: Dictionary, joint_pos: Vector3,
        rot: Quaternion, sole_pos: Vector3) -> float:
    var foot: Node3D = leg["foot"]
    var saved: Transform3D = foot.global_transform
    foot.global_position = joint_pos
    foot.global_basis = Basis(rot).scaled(saved.basis.get_scale())
    var lowest: float = _foot_mesh_lowest_y(foot)
    foot.global_transform = saved
    return sole_pos.y - lowest

func _aim_rotated(point: Vector3, hip: Vector3,
        yaw_q: Quaternion) -> Vector3:
    return hip + yaw_q * (point - hip)


# v416: rear KICKs follow the original source trajectory, but the
# independently forward-pitched chassis keeps its height. Even after
# preserving the authored rear shoulder socket, the mirrored mid-strike
# toe can hover 0.94m/1.19m above the arena: the copied source path
# attempts to reach farther horizontally than the rear two-bone limb
# can reach at the floor. Do not move BODY, distort toe rotation or
# accumulate a new IK offset. Re-solve the original trajectory's sole
# along the same world XZ bearing at the mesh-ground height, shortening
# its horizontal radius ONLY by the minimum needed for anatomical
# reach. Apply from clip 0.18, full at 0.32..0.62, and taper to zero
# at clip 0.85 so the original hold/recovery handover stays smooth.
func _ground_rear_kick_foot(leg: Dictionary) -> void:
    if not _rear_attack_active() or str(
            attack_pose.get("kind", "")) != "kick":
        return
    var t: float = float(attack_pose.get(
        "time", 0.0))
    var windup: float = float(attack_pose.get(
        "windup", 0.70))
    if t < windup:
        return
    var clip_t: float = float(attack_pose.get(
        "authored_time", 0.0))
    var contact_weight: float = (
        _cubic((clip_t - 0.18) / 0.14)
        * (1.0 - _cubic((clip_t - 0.62) / 0.23)))
    if contact_weight <= 0.0001:
        return
    var upper: Node3D = leg["upper"]
    var lower: Node3D = leg["lower"]
    var foot: Node3D = leg["foot"]
    var visible_low: float = _foot_mesh_lowest_y(foot)
    var gap: float = maxf(0.0, visible_low - (FLOOR_Y + 0.025))
    if gap <= 0.004:
        return
    var rotation: Quaternion = leg["last_rotation"]
    var new_goal: Vector3 = (
        leg["last_goal"] as Vector3) - Vector3.UP * (
            gap * contact_weight)
    var foot_offset: Vector3 = (
        Basis(rotation).scaled(foot.global_basis.get_scale())
        * (leg["sole_local"] as Vector3))
    var hip: Vector3 = upper.global_position
    var delta: Vector3 = new_goal - foot_offset - hip
    # After the authored trajectory was mirrored to this limb,
    # the knee and shin have EXACTLY these physical lengths.
    # Respect them rather than letting _solve silently clamp the
    # desired FLOOR goal, which leaves the ankle high again.
    var reach: float = (
        hip.distance_to(lower.global_position)
        + lower.global_position.distance_to(foot.global_position)
        - IK_REACH_MARGIN_METERS)
    var horizontal: Vector2 = Vector2(delta.x, delta.z)
    var allowed: float = sqrt(maxf(
        reach * reach - delta.y * delta.y, 0.0))
    if horizontal.length() > allowed and horizontal.length() > 0.0001:
        var adjusted: Vector2 = (
            horizontal.normalized() * maxf(0.0, allowed - 0.004))
        new_goal.x += adjusted.x - horizontal.x
        new_goal.z += adjusted.y - horizontal.y
    # This second solve starts from the same authored key every
    # frame (rig.apply_pose), uses a fresh source pole and only
    # changes the attacking leg. The shoulder stays at its original
    # Blockbench socket; BODY/root Y and supporting soles do not move.
    leg["last_error"] = _solve(leg, new_goal, rotation)
    # Some authored rear shin corners reach lower than the toe when
    # the knee folds close to the floor (~7.7cm in the v410 fixture).
    # Keep the entire visual limb outside the arena: raise ONLY this
    # foot's IK contact goal as much as the exposed shin demands.
    # This keeps the shoulder at its authored attachment point,
    # avoids the old artificial whole-body/whole-hip lifts, and
    # still leaves the toe scraping within 0.20m of the floor.
    for retry in range(3):
        var limb_low: float = _leg_mesh_lowest_y(upper)
        if limb_low >= FLOOR_Y + 0.002:
            break
        new_goal.y += maxf(
            FLOOR_Y + 0.005 - limb_low, 0.0)
        leg["last_error"] = _solve(leg, new_goal, rotation)
    # Preserve the final grounded goal for a continuous poststrike
    # blend if the source timeline ever ends inside this window.
    leg["attack_exit_goal"] = new_goal
    leg["attack_exit_rotation"] = rotation




func _solve(leg: Dictionary, sole_goal: Vector3, desired_rotation: Quaternion) -> float:
    var upper: Node3D = leg["upper"]
    var lower: Node3D = leg["lower"]
    var foot: Node3D = leg["foot"]
    leg["last_goal"] = sole_goal
    leg["last_rotation"] = desired_rotation
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
    if (not attack_pose.is_empty() and bool(attack_pose.get("authored", false)) \
            and str(attack_pose.get("kind", "")) == "stomp" \
            and LEG_PART_IDS[legs.find(leg)] == str(attack_pose.get("id", ""))) \
            or bool(leg.get("authored_pole_active", false)):
        # The animated front-left knee describes the intended bend plane.
        # Keep that authored pole while IK moves the foot toward SERA's
        # live head. This preserves the clip's keyframed windup silhouette.
        # v406: the same authored pole serves the KICK reach solve, so a
        # shortened strike bends exactly in the authored plane.
        pole = knee - hip
        # v407: the KICK mirror-blend solve passes the blended knee
        # position explicitly (the current knee belongs to the rig's
        # joint-slerped pose, not to the foot-space blend).
        var pole_point: Vector3 = leg.get(
            "authored_pole_point", Vector3.ZERO)
        if pole_point != Vector3.ZERO:
            pole = pole_point - hip
    pole -= direction * pole.dot(direction)
    if pole.length_squared() < 0.00001:
        pole = Vector3.UP - direction * direction.y
    if pole.length_squared() < 0.00001:
        pole = Vector3.RIGHT
    pole = pole.normalized()
    # An under-head limb cannot genuinely lie on its side if the authored
    # IK knee pole still bends UP: it holds the lower shin >3m in the air
    # and the head cannot ever rest on it. Fold that knee DOWN and laterally
    # while preserving the exact upper/lower lengths and the planted sole.
    if head_support_leg_index >= 0 and break_elapsed >= 0.0             and leg["upper"] == legs[head_support_leg_index]["upper"]:
        var fold: float = _cubic(clampf(
            break_elapsed / LEG_BREAK_FALL_SECONDS, 0.0, 1.0))
        if break_elapsed > break_recover_start:
            fold *= 1.0 - _cubic((break_elapsed - break_recover_start) /
                maxf(break_duration - break_recover_start, 0.001))
        var toppled_pole: Vector3 = (
            Vector3.DOWN * 1.15 + head_support_outward * 0.45)
        toppled_pole -= direction * toppled_pole.dot(direction)
        if toppled_pole.length_squared() > 0.00001:
            var start_pole: Vector3 = pole
            pole = start_pole.lerp(toppled_pole.normalized(), fold)
            if pole.length_squared() > 0.00001:
                pole = pole.normalized()
            else:
                pole = toppled_pole.normalized()
    # Preserve the original authored pole while falling or lying still.
    # During PHYSICAL STAND-UP, also allow a small lateral knee fold,
    # including the under-head support leg. Blend it over the folded
    # support pole without moving the world-planted sole or body root.
    if windup_elapsed < 0.0 and (
            break_elapsed < 0.0 or standup_knee_enabled()):
        var sideways_bend: float = clampf(
            float(leg.get("head_knee_bend", 0.0)), 0.0, HEAD_KNEE_MAX_BEND)
        if sideways_bend > 0.00001 and chassis_bone != null:
            var lateral: Vector3 = actor.global_basis.x.normalized()
            var hip_offset: Vector3 = hip - chassis_bone.global_position
            var sign: float = 1.0 if hip_offset.dot(lateral) >= 0.0 else -1.0
            var escape: Vector3 = (lateral * sign
                + Vector3.DOWN * HEAD_KNEE_OUTWARD_DOWN_BIAS)
            escape -= direction * escape.dot(direction)
            if escape.length_squared() > 0.00001:
                pole = pole.slerp(escape.normalized(), sideways_bend).normalized()
    # The planted-foot kick winds the knee inward without sliding the sole.
    # v406: skipped while the reach solve is bending this leg in its
    # authored plane; the block still shapes the recovery solves.
    # v412: the wind now starts WITH the strike. Since v410 the leg
    # stays planted at the basic stance for the whole windup, and
    # winding the pinned leg's knee inward read as the preparation
    # facing an abnormal direction (device report): the knee
    # travelled at up to ~7 m/s with the sole fixed, and on leg_fl
    # the slerped pole crossed the hip->sole axis mid-windup and
    # flipped the bend plane (knee snap ~1.6m). The fold now forms
    # over the strike entry like the rest of the authored motion.
    if not attack_pose.is_empty() and str(attack_pose.get("kind", "")) == "kick" \
            and not bool(leg.get("authored_pole_active", false)) \
            and float(attack_pose.get("time", 0.0)) >= float(attack_pose.get("windup", 0.0)):
        var active_index: int = LEG_PART_IDS.find(
            str(attack_pose.get("id", "")))
        if active_index >= 0 and leg["upper"] == legs[active_index]["upper"]:
            var inward: Vector3 = -actor.global_basis.x
            var offset: Vector3 = hip - actor.global_position
            if offset.dot(actor.global_basis.x) < 0.0:
                inward = actor.global_basis.x
            inward -= direction * inward.dot(direction)
            if inward.length_squared() > 0.00001:
                # v402: release the inward wind over the first 0.12s
                # of recovery instead of letting _attack_weight()'s
                # tail drag it through the whole recovery blend. With
                # the tail, the slerped pole crossed the hip-ankle
                # bend-plane singularity mid-recovery on the rear
                # legs and the solved knee flipped in one tick
                # (measured 56 degrees on the lower joint, both rear
                # legs, with smooth goal/hip/rotation inputs).
                var inward_factor: float = 0.70 * _attack_weight()
                var kick_t: float = float(attack_pose.get("time", 0.0))
                var freeze_end: float = float(
                    attack_pose.get("windup", 0.0)) + float(
                    attack_pose.get("strike", 0.0)) + float(
                    attack_pose.get("hold", 0.0))
                if kick_t > freeze_end:
                    inward_factor *= clampf(
                        1.0 - (kick_t - freeze_end) / 0.12, 0.0, 1.0)
                pole = pole.slerp(inward.normalized(),
                    inward_factor).normalized()
    # Swing the middle joint around the actual hip/ankle axis as the
    # grounded toe lags behind chest rotation: a helical, not planar,
    # three-dimensional knee path. No pivot translation or bone scaling.
    var spiral: float = float(leg.get("spiral_twist", 0.0))
    if absf(spiral) > 0.000001 and not break_reaction_active():
        pole = (Quaternion(direction, spiral) * pole).normalized()
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
    # v410: remember the SOLVED knee/ankle positions. The strike
    # entry blends (KICK trajectory, SWEEP entry) capture their
    # entry knee/ankle from these, never from the live joints:
    # when advance_ik runs, the rig has already reset the joints
    # to its entry snapshot under the current Body, which throws
    # a captured knee metres sideways (measured 2.4m on leg_fl's
    # sweep entry).
    leg["last_knee"] = lower.global_position
    leg["last_foot"] = foot.global_position
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
    # Any new collapse invalidates the last stand-up handoff, including
    # another broken leg during the previous recovery/Idle-settle phase.
    post_down_idle_remaining = 0.0
    recovery_gait_started = false
    recovery_catchup_pending_pair = -1
    # A new collapse invalidates ALL previous avoidance goals; otherwise
    # the knees can snap back into the last standing turn on recovery.
    head_knee_scan_elapsed = HEAD_KNEE_SCAN_SECONDS
    head_knee_active = false
    for leg in legs:
        leg["head_knee_bend"] = 0.0
        leg["head_knee_target"] = 0.0
    # A second leg can break while the boss is already down. Refresh the
    # down timer but never snap an already fallen chassis UP into a windup.
    var already_downed: bool = break_elapsed >= 0.0
    var already_winding: bool = windup_elapsed >= 0.0
    break_leg_index = -1
    if not already_downed:
        _clear_head_support()
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
    break_recover_start = (ALL_LEGS_BREAK_RECOVER_START_SECONDS if all_legs_broken
        else LEG_BREAK_RECOVER_START_SECONDS)
    # Preserve the previous stand-up start; physical rise now lasts 1.0s
    # for a normal knockdown and 1.3s after all four legs break.
    break_duration = break_recover_start + (
        FOUR_LEG_RISE_SECONDS if all_legs_broken else SINGLE_LEG_RISE_SECONDS)
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


func _clear_head_support() -> void:
    head_support_leg_index = -1
    head_support_leg_id = ""
    head_support_sole_at_down = Vector3.ZERO
    head_support_outward = Vector3.ZERO
    head_support_foot_rotation = Quaternion.IDENTITY
    head_support_contact = false
    break_chassis_pitch_radians = 0.0
    if collision_parts != null and collision_parts.has_method(
            "set_head_support_leg"):
        collision_parts.call("set_head_support_leg", "")


func _select_head_support_leg() -> void:
    # Evaluate only when the real fall starts, AFTER the 0.6s anticipation.
    # During TURN a planted foot can lag beneath the nose while the BODY
    # rotates above it. Compare HEAD/FOOT XZ, not their different heights.
    _clear_head_support()
    if collision_parts == null or legs.size() != 4:
        return
    var head_box: AABB = collision_parts.call("get_head_swing_aabb")
    if not head_box.has_volume():
        return
    var head_center: Vector3 = head_box.get_center()
    var best_distance: float = INF
    for i in range(legs.size()):
        var leg: Dictionary = legs[i]
        var foot: Node3D = leg["foot"]
        var sole: Vector3 = foot.to_global(leg["sole_local"])
        var id: String = LEG_PART_IDS[i]
        var foot_box: AABB = collision_parts.call("get_part_aabb", id)
        # Front/rear and left/right must use identical geometry thresholds.
        var head_radius: float = maxf(head_box.size.x, head_box.size.z) * 0.5
        var foot_radius: float = maxf(foot_box.size.x, foot_box.size.z) * 0.5
        var threshold: float = clampf(
            head_radius + foot_radius + HEAD_FOOT_HORIZONTAL_EXTRA_METERS,
            HEAD_FOOT_HORIZONTAL_MIN_METERS,
            HEAD_FOOT_HORIZONTAL_MAX_METERS)
        var horizontal: Vector2 = Vector2(head_center.x - sole.x,
            head_center.z - sole.z)
        var gap: float = horizontal.length()
        if gap > threshold or gap >= best_distance:
            continue
        best_distance = gap
        head_support_leg_index = i
        head_support_leg_id = id
        head_support_sole_at_down = leg["anchor"]
        head_support_foot_rotation = leg["anchor_rotation"]
        var lateral: Vector3 = actor.global_basis.x
        lateral.y = 0.0
        lateral = lateral.normalized()
        var from_body: Vector3 = sole - actor.global_position
        from_body.y = 0.0
        if from_body.dot(lateral) < 0.0:
            lateral = -lateral
        head_support_outward = lateral
    if collision_parts.has_method("set_head_support_leg"):
        collision_parts.call("set_head_support_leg", head_support_leg_id)


func _support_boxes_overlap_xz(head_box: AABB, leg_box: AABB) -> bool:
    return (head_box.position.x < leg_box.end.x
        and leg_box.position.x < head_box.end.x
        and head_box.position.z < leg_box.end.z
        and leg_box.position.z < head_box.end.z)


func _resolve_head_on_leg_contact() -> void:
    # The HEAD and SHIN shapes belong to ONE AnimatableBody3D: Godot cannot
    # generate self-collision impulses between its own sibling shapes.
    # Resolve their actual collision AABBs by limiting the BODY's nose-down
    # pitch, rather than letting the head mesh intersect the toppled leg.
    head_support_contact = false
    if break_elapsed < 0.0 or head_support_leg_index < 0             or collision_parts == null or chassis_bone == null             or break_chassis_pitch_radians <= 0.0001:
        return
    var leg_box: AABB = collision_parts.call(
        "get_part_aabb", head_support_leg_id)
    var head_box: AABB = collision_parts.call("get_part_aabb", "head")
    if not _support_boxes_overlap_xz(head_box, leg_box):
        return
    var contact_y: float = leg_box.end.y + SUPPORT_HEAD_COLLISION_GAP_METERS
    if head_box.position.y >= contact_y:
        head_support_contact = head_box.position.y <= contact_y + 0.04
        return
    var lowest_pitch: float = 0.0
    var steepest_pitch: float = break_chassis_pitch_radians
    for _i in range(SUPPORT_COLLISION_ITERATIONS):
        var trial: float = (lowest_pitch + steepest_pitch) * 0.5
        chassis_bone.quaternion = (break_chassis_base_pose *
            Quaternion(Vector3.RIGHT, -trial)).normalized()
        var current_head: AABB = collision_parts.call("get_part_aabb", "head")
        if current_head.position.y < contact_y:
            steepest_pitch = trial
        else:
            lowest_pitch = trial
    chassis_bone.quaternion = (break_chassis_base_pose *
        Quaternion(Vector3.RIGHT, -lowest_pitch)).normalized()
    break_chassis_pitch_radians = lowest_pitch
    head_box = collision_parts.call("get_part_aabb", "head")
    head_support_contact = (
        _support_boxes_overlap_xz(head_box, leg_box) and
        absf(head_box.position.y - contact_y) <= 0.065)


func locomotion_ready() -> bool:
    # Whether the old post-down neutral settle has completed. This is
    # still useful for lock/contact cleanup, but is NO LONGER the gate
    # for beginning Turn/Approach animation or locomotion on stand-up.
    return ready and not break_reaction_active()         and post_down_idle_remaining <= 0.0         and head_support_leg_index < 0


# Actual return-to-upright fraction, NOT raw elapsed time. Both
# chassis drop and the sideways supporting leg use this cubic easing.
func standup_pose_fraction() -> float:
    if break_elapsed < break_recover_start or break_elapsed < 0.0:
        return 0.0
    if break_duration <= break_recover_start:
        return 1.0
    return _cubic((break_elapsed - break_recover_start) /
        (break_duration - break_recover_start))


# A planted knee can already fold sideways while the chest is rising
# and turning. Do not wait for down_pose_active() to become false.
func standup_knee_enabled() -> bool:
    return windup_elapsed < 0.0 and break_elapsed >= break_recover_start \
        and break_elapsed >= 0.0 and break_elapsed < break_duration


func standup_turn_enabled(next_delta: float = 0.0) -> bool:
    # The physical recovery begins when _advance_leg_break(delta) crosses
    # break_recover_start. Preview that SAME tick from _advance_target_motion
    # (called before IK), so root yaw starts on the exact first rising frame.
    # No lead-in, smoothstep or angular-speed ramp is applied.
    if down_pose_active():
        return break_elapsed + maxf(next_delta, 0.0) >= break_recover_start
    # Keep ordinary gait enabled during the post-down pose settle too.
    return post_down_idle_remaining > 0.0


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
        # The attack-only interruption must not inject the normal
        # nose-up/forward-reach telegraph into the HEAD's live look.
        if not attack_down_windup_leg_id.is_empty():
            pitch_degrees = 0.0
        head_windup_pitch_degrees = pitch_degrees
        # Do not write HEAD rotation from IK: the live collision-aware
        # player tracking controller composes this pitch with its yaw
        # exactly once later in the SAME physics frame.

        # Reach forward with both forelimbs by extending their PLANTED sole
        # anchors, rather than raising toes or moving the whole robot upward.
        var reach: float = LEG_BREAK_FRONT_REACH_METERS * _cubic(
            minf(progress / 0.72, 1.0))
        if not attack_down_windup_leg_id.is_empty():
            reach = 0.0
        for index in front_anchor_rest:
            var leg: Dictionary = legs[index]
            leg["anchor"] = (front_anchor_rest[index] as Vector3) + (
                front_extension_direction[index] as Vector3) * reach
        actor.position.y = (rest_actor_local_y
            + ground_correction_world / parent_scale_y)
        if windup_elapsed >= LEG_BREAK_WINDUP_SECONDS:
            attack_down_windup_leg_id = ""
            # The last windup frame is exactly neutral, so the original
            # head joint starts the falling animation without a rotation pop.
            windup_elapsed = -1.0
            break_elapsed = 0.0
            _select_head_support_leg()
        return

    head_windup_pitch_degrees = 0.0
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
    break_chassis_pitch_radians = 0.0
    if break_elapsed >= 0.0 and chassis_bone != null             and head_mesh_for_height != null:
        var base_pose: Quaternion = chassis_bone.quaternion
        # Backward (nose-up) pitch raises front shoulders during the rise.
        # A sine envelope keeps both transition boundaries at neutral.
        var rise_back_lean: float = 0.0
        if break_elapsed >= break_recover_start and break_elapsed < break_duration:
            var rise_phase: float = clampf(
                (break_elapsed - break_recover_start) /
                maxf(break_duration - break_recover_start, 0.001), 0.0, 1.0)
            rise_back_lean = (deg_to_rad(STANDUP_BACK_LEAN_DEGREES)
                * sin(PI * rise_phase))
        # The head/leg collision resolver retains this lean in its base pose.
        break_chassis_base_pose = (base_pose *
            Quaternion(Vector3.RIGHT, rise_back_lean)).normalized()
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
            break_chassis_pitch_radians = (lo + hi) * 0.5
            chassis_bone.quaternion = (break_chassis_base_pose *
                Quaternion(Vector3.RIGHT, -break_chassis_pitch_radians)).normalized()
        else:
            chassis_bone.quaternion = break_chassis_base_pose
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
            # The chassis/sole collapse has eased to zero on this tick, but
            # don't start Turn/Approach while the rendered rig and four IK
            # feet finish returning to their neutral standing posture.
            post_down_idle_remaining = POST_DOWN_IDLE_SETTLE_SECONDS
            break_elapsed = -1.0
            break_leg_index = -1
            _clear_head_support()
            front_anchor_rest.clear()
            front_extension_direction.clear()


func break_reaction_active() -> bool:
    # Freeze AI/gait and permit weakpoint lock from the breaking hit onward.
    # The original 2.5/6s down timer itself starts after the 0.6s windup.
    return windup_active() or down_pose_active()

## Locomotion weight shift (v401). While a diagonal pair is airborne,
## lean the chassis toward the planted pair's support centroid and sink
## it slightly; add a short extra sink as each foot lands. Applied on
## top of the freshly sampled rig pose (never accumulated), before the
## chassis floor clamp and the foot IK, so planted soles stay locked.
## All terms decay to exactly zero outside Approach/Turn.
func _apply_gait_sway(delta: float, motion: String) -> void:
    var active: bool = (motion == "Approach" or motion == "Turn") \
        and not attack_stance_active and not attack_down_windup_active()
    var desired_roll: float = 0.0
    var desired_pitch: float = 0.0
    var desired_dip: float = 0.0
    if active and stepping_pair != -1:
        # Carry the weight over the PLANTED pair's front foot: pair 0
        # plants leg_fr (+X front), pair 1 plants leg_fl (-X front).
        # Rotation about the forward (+Z) axis by a NEGATIVE angle tips
        # the chassis top toward +X; rotation about +X tips it toward
        # +Z (front). The roll therefore alternates with the diagonal
        # pairs while the pitch stays gently forward under way.
        var support_pair: int = 1 - stepping_pair
        var front_sign: float = 1.0 if support_pair == 0 else -1.0
        desired_roll = -front_sign * GAIT_SWAY_MAX_RADIANS * 0.85
        desired_pitch = GAIT_SWAY_MAX_RADIANS * 0.45
        desired_dip = GAIT_DIP_METERS
    for i in range(legs.size()):
        var stepping: bool = bool(legs[i]["stepping"])
        if gait_prev_stepping[i] and not stepping and active:
            gait_dip_pulse = GAIT_TOUCHDOWN_DIP_METERS
        gait_prev_stepping[i] = stepping
    gait_dip_pulse = maxf(0.0, gait_dip_pulse
        - delta * GAIT_TOUCHDOWN_DIP_METERS * 3.0)
    desired_dip += gait_dip_pulse
    var blend: float = 1.0 - exp(
        -GAIT_SWAY_RESPONSE_PER_SECOND * maxf(delta, 0.0))
    gait_sway_roll = lerpf(gait_sway_roll, desired_roll, blend)
    gait_sway_pitch = lerpf(gait_sway_pitch, desired_pitch, blend)
    gait_dip = lerpf(gait_dip, desired_dip,
        1.0 - exp(-7.0 * maxf(delta, 0.0)))
    if chassis_bone == null:
        return
    if absf(gait_sway_roll) > 0.00001 or absf(gait_sway_pitch) > 0.00001:
        chassis_bone.quaternion = (chassis_bone.quaternion
            * Quaternion(Vector3.RIGHT, gait_sway_pitch)
            * Quaternion(Vector3.BACK, gait_sway_roll)).normalized()
    if gait_dip > 0.00001:
        var scale_y: float = maxf(
            absf(actor.get_parent().global_basis.get_scale().y), 0.001)
        actor.position.y -= gait_dip / scale_y


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
    _advance_attack_stance(delta)
    var attacking: bool = not attack_pose.is_empty() and not break_reaction_active()
    if attacking:
        _apply_attack_chassis_pose()
        # The chest heading is now final. Steer only the attacking
        # shoulder in WORLD Y, preserving source hip/knee/foot keys.
        if bool(attack_pose.get("authored", false)) and actor.has_method(
                "aim_authored_attack_leg"):
            actor.call("aim_authored_attack_leg", attack_pose, delta)
    elif not break_reaction_active():
        _apply_gait_sway(delta, motion)
    # Both authored KICK/SWEEP start-height calibration and leg-break
    # nose-dip can bury the actual chassis mesh. Enforce a real mesh
    # floor bound *after* every torso adjustment and *before* foot IK.
    _keep_chassis_above_ground()
    _update_spiral_legs(delta, attacking)
    # During the physical stand-up, planted feet keep their world-space
    # anchors as the chassis turns toward SERA. Locomotion clips already
    # play on the rig, but the IK soles must NOT chase the torso until
    # the head/torso have completely risen and their support is released.
    var upright: bool = not break_reaction_active()
    var active: bool = (motion == "Approach" or motion == "Turn") and upright and not attacking
    if active and stepping_pair == -1 and cooldown <= 0.0:
        var a: float = _pair_error(0, motion == "Approach")
        var b: float = _pair_error(1, motion == "Approach")
        if not recovery_gait_started and post_down_idle_remaining > 0.0:
            # The first fully upright IK tick selects the pair furthest
            # from its NEW stance under the rotated/moved chassis.
            var first_pair: int = 0 if a >= b else 1
            _start_pair(first_pair, motion == "Approach")
            recovery_catchup_pending_pair = 1 - first_pair
            recovery_gait_started = true
        elif recovery_catchup_pending_pair >= 0:
            # Both pairs must eventually place their feet under the new
            # body heading. Keep the original gait duration, not faster
            # animation, and retarget their landing positions instead.
            _start_pair(recovery_catchup_pending_pair, motion == "Approach")
            recovery_catchup_pending_pair = -1
        else:
            var selected: int = preferred_pair
            var trigger: float = (STEP_APPROACH_TRIGGER_METERS
                if motion == "Approach" else STEP_TRIGGER_METERS)
            if maxf(a, b) > trigger or (
                    recovery_gait_started
                    and maxf(a, b) > RECOVERY_FOOT_CATCHUP_THRESHOLD_METERS):
                if absf(a - b) > 0.12:
                    selected = 0 if a > b else 1
                _start_pair(selected, motion == "Approach")
    var done: bool = true
    for leg in legs:
        var position: Vector3 = leg["anchor"]
        var rotation: Quaternion = leg["anchor_rotation"]
        var attacking_this_leg: bool = (attacking and str(
            attack_pose.get("id", "")) == LEG_PART_IDS[legs.find(leg)])
        # The STOMP preparation for an interrupted attack is a real
        # authored limb clip, not a planted-foot IK target. Its other
        # three supports remain fixed while the former striker winds up.
        if attack_down_windup_active() and LEG_PART_IDS[legs.find(leg)]                 == attack_down_windup_leg_id:
            var windup_foot: Node3D = leg["foot"]
            leg["last_goal"] = windup_foot.to_global(
                leg["sole_local"] as Vector3)
            leg["last_rotation"] = (
                windup_foot.global_basis.get_rotation_quaternion())
            continue
        if attacking:
            if attacking_this_leg:
                var attack_kind: String = str(attack_pose.get("kind", ""))
                var attack_t: float = float(attack_pose.get("time", 0.0))
                var attack_windup: float = float(
                    attack_pose.get("windup", 1.25))
                if bool(attack_pose.get("authored", false)) and (
                        attack_kind == "stomp") and attack_t <= attack_windup:
                    # Preserve all THREE authored leg joints during the
                    # windup. Prematurely aligning the toe to world-up
                    # erased the original sweep/lift shape. Capture the
                    # real terminal keyframe as the downstroke's entry.
                    var foot: Node3D = leg["foot"]
                    var authored_foot_rotation: Quaternion = (
                        foot.global_basis.get_rotation_quaternion())
                    position = foot.to_global(leg["sole_local"] as Vector3)
                    leg["stomp_authored_windup_goal"] = position
                    leg["stomp_authored_windup_rotation"] = (
                        authored_foot_rotation)
                    leg["last_goal"] = position
                    leg["last_rotation"] = authored_foot_rotation
                    continue
                if bool(attack_pose.get("authored", false)) and (
                        attack_kind != "stomp"):
                    # The user's keyframes ARE the attacking limb pose:
                    # solving its old procedural IK would erase them.
                    var foot: Node3D = leg["foot"]
                    var actual: Vector3 = foot.to_global(
                        leg["sole_local"] as Vector3)
                    var t: float = float(attack_pose.get("time", 0.0))
                    var end: float = float(attack_pose.get("windup", 0.7)) + (
                        float(attack_pose.get("strike", 1.0)))
                    var hold: float = float(attack_pose.get("hold", 0.0))
                    var freeze_end: float = end + hold
                    var authored_rotation: Quaternion = (
                        foot.global_basis.get_rotation_quaternion())
                    # v406: the reach-solve pole flag is per-tick; the
                    # freeze branch below sets it only on ticks where
                    # the shortened KICK actually goes through _solve.
                    # v407: authored_pole_point is the same for the
                    # mirror-blend solve (ZERO = use the current knee).
                    leg["authored_pole_active"] = false
                    leg["authored_pole_point"] = Vector3.ZERO
                    if t < attack_windup:
                        # v410: during the preparation the striking
                        # leg stays planted at the basic stance,
                        # solved to its anchor exactly like the
                        # supports (device request: when Bittaran
                        # returns to the basic stance before an
                        # attack, the attacking leg also returns to
                        # the basic stance position). The authored
                        # motion starts from this stance at the
                        # strike: the rig blends the leg in over
                        # the first part of the strike, and the KICK
                        # trajectory blends from this planted entry.
                        # The exit goal/rotation are pre-set to the
                        # planted values so the recovery fallthrough
                        # below (recover_t == 0 here) is a no-op.
                        # The exit lift is zeroed for the same
                        # reason: the fallthrough re-applies it to
                        # the hip, and a previous attack's lift
                        # would otherwise hoist the planted leg's
                        # hip for the whole preparation (measured
                        # +0.48m on leg_rr, snapping off at the
                        # strike boundary). The freeze branch used
                        # to overwrite it every windup tick before
                        # the fallthrough; the plant must too.
                        # The plant target is the leg's true home,
                        # captured once per attack: the anchor
                        # ROTATION can be a stale mid-step capture
                        # (force-started attacks skip the stance
                        # preparation that refreshes it), which
                        # pitched leg_rr's planted foot ~14 degrees
                        # and fed the clip guard a 0.49m lift every
                        # windup tick. In real play the preparation
                        # already set anchor == home, so this
                        # changes nothing there.
                        if not leg.has("plant_goal"):
                            leg["plant_goal"] = _home(leg, false)
                            leg["plant_rotation"] = _rotation_home(leg)
                        position = leg["plant_goal"]
                        rotation = leg["plant_rotation"]
                        leg["attack_exit_goal"] = position
                        leg["attack_exit_rotation"] = rotation
                        leg["attack_exit_lift_world"] = 0.0
                        leg["last_goal"] = position
                        leg["last_rotation"] = rotation
                    elif attack_kind == "sweep" and t < attack_windup \
                            + SWEEP_ENTRY_BLEND_SECONDS:
                        # v410: blend the SWEEP strike entry from
                        # the planted stance to the authored pose
                        # in position space (the KICK trajectory
                        # pattern). The rig's leg is still slerping
                        # from its entry locals, whose raw foot sits
                        # metres under the floor under the fully
                        # turned Body, so the freeze branch and its
                        # floor lift cannot run on it yet; the goal
                        # instead follows the SAMPLED authored pose
                        # (sample_authored_sweep_pose), re-anchored
                        # at the live hip and aim-rotated. Sole,
                        # ankle and knee all blend (blending sole
                        # and rotation alone swings the ankle on
                        # the sole offset's ~2m arc and trips the
                        # reach clamp), the sole point is fitted
                        # per tick like the KICK trajectory's, and
                        # the sampled pose's own floor deficit is
                        # applied as the freeze branch's whole-limb
                        # lift, scaled by the blend weight and
                        # applied to hip and goals together, so
                        # the hip height is continuous at the
                        # handover. Entry knee/ankle come from the
                        # last SOLVED positions (last_knee /
                        # last_foot): the live joints at this
                        # point are the rig's entry snapshot under
                        # the turned Body, metres off the plant.
                        var src: Dictionary = actor.call(
                            "sample_authored_sweep_pose",
                            str(attack_pose.get("id", "")),
                            float(attack_pose.get(
                                "authored_time", 0.0)),
                            leg["sole_local"])
                        if not src.is_empty():
                            var hip_pos: Vector3 = (
                                leg["upper"] as Node3D).global_position
                            var aim_q: Quaternion = Quaternion(
                                Vector3.UP, float(actor.get(
                                    "attack_leg_aim_yaw")))
                            var goal_sole: Vector3 = _aim_rotated(
                                hip_pos + (src["sole"] as Vector3)
                                    - (src["hip"] as Vector3),
                                hip_pos, aim_q)
                            var goal_foot: Vector3 = _aim_rotated(
                                hip_pos + (src["foot"] as Vector3)
                                    - (src["hip"] as Vector3),
                                hip_pos, aim_q)
                            var goal_knee: Vector3 = _aim_rotated(
                                hip_pos + (src["knee"] as Vector3)
                                    - (src["hip"] as Vector3),
                                hip_pos, aim_q)
                            var goal_rot: Quaternion = aim_q * (
                                src["rotation"] as Quaternion)
                            if not leg.has("sweep_entry_sole"):
                                leg["sweep_entry_sole"] = leg.get(
                                    "last_goal", position)
                                leg["sweep_entry_rotation"] = leg.get(
                                    "last_rotation", rotation)
                                leg["sweep_entry_knee"] = leg.get(
                                    "last_knee",
                                    (leg["lower"] as Node3D
                                    ).global_position)
                                leg["sweep_entry_foot"] = leg.get(
                                    "last_foot", foot.global_position)
                            var bw: float = clampf(
                                (t - attack_windup)
                                / SWEEP_ENTRY_BLEND_SECONDS, 0.0, 1.0)
                            bw = bw * bw * (3.0 - 2.0 * bw)
                            position = (leg["sweep_entry_sole"]
                                as Vector3).lerp(goal_sole, bw)
                            goal_foot = (leg["sweep_entry_foot"]
                                as Vector3).lerp(goal_foot, bw)
                            rotation = (leg["sweep_entry_rotation"]
                                as Quaternion).slerp(goal_rot, bw)
                            # v412: blend the pole point by
                            # DIRECTION around the hip, not by
                            # position. With the rear legs'
                            # front-back-reversed Body tilt (v412),
                            # the sampled knee can sit on the
                            # opposite side of the hip->sole axis
                            # from the planted knee; the straight
                            # position lerp then passes through the
                            # axis mid-blend and _solve's projected
                            # pole flips the bend plane, snapping
                            # the knee through the floor (measured
                            # -0.214m on leg_rl in the v411
                            # experiment). Slerping the direction
                            # keeps the pole off the axis for the
                            # whole blend.
                            var entry_knee: Vector3 = (
                                leg["sweep_entry_knee"] as Vector3)
                            var e_dir: Vector3 = entry_knee - hip_pos
                            var g_dir: Vector3 = goal_knee - hip_pos
                            if e_dir.length() > 0.05 \
                                    and g_dir.length() > 0.05:
                                var mid_dir: Vector3 = \
                                    e_dir.normalized().slerp(
                                        g_dir.normalized(), bw)
                                leg["authored_pole_point"] = \
                                    hip_pos + mid_dir * lerpf(
                                        e_dir.length(),
                                        g_dir.length(), bw)
                            else:
                                leg["authored_pole_point"] = \
                                    entry_knee.lerp(goal_knee, bw)
                            leg["authored_pole_active"] = true
                            var entry_lift: float = 0.0
                            var src_bottom: float = float(
                                src.get("mesh_lowest", INF))
                            if src_bottom < FLOOR_Y - 0.001:
                                entry_lift = (FLOOR_Y + 0.003
                                    - src_bottom) * bw
                            # Mid-blend the slerped foot rotation
                            # traces its toe corner on an arc below
                            # both endpoints' clearance (measured
                            # -0.041 at clip 0.23 on leg_fl); add a
                            # margin that peaks mid-blend and is
                            # zero at both ends, so neither the
                            # plant nor the freeze handover moves.
                            entry_lift += (SWEEP_ENTRY_LIFT_MARGIN_METERS
                                * 4.0 * bw * (1.0 - bw))
                            if entry_lift > 0.0:
                                # The goals carry the lift; the
                                # HIP translation is applied once
                                # by the recovery fallthrough below
                                # (recover_t == 0 throughout the
                                # entry), which re-applies
                                # attack_exit_lift_world before the
                                # loop-end _solve -- translating
                                # the hip here as well would apply
                                # the lift twice (measured: hip
                                # hoisted ~1.4m by clip 0.25).
                                position += Vector3.UP * entry_lift
                                goal_foot += Vector3.UP * entry_lift
                                leg["authored_pole_point"] = (
                                    leg["authored_pole_point"]
                                    as Vector3) + Vector3.UP * entry_lift
                            var offset_want: Vector3 = (
                                position - goal_foot)
                            if offset_want.length_squared() > 0.000001:
                                if not leg.has("sole_local_saved"):
                                    leg["sole_local_saved"] = (
                                        leg["sole_local"])
                                leg["sole_local"] = Basis(
                                    rotation).inverse() * offset_want \
                                    / maxf(foot.global_basis
                                        .get_scale().x, 0.001)
                                leg["sole_local_traj"] = (
                                    leg["sole_local"])
                            if bw >= 0.999 and leg.has(
                                    "sole_local_saved"):
                                # At bw == 1 the fit IS the leg's
                                # real sole point (the authored
                                # pose satisfies it by construction),
                                # so restoring here is seamless and
                                # the freeze branch reads the real
                                # point from the handover on.
                                leg["sole_local"] = (
                                    leg["sole_local_saved"])
                                leg.erase("sole_local_saved")
                                leg.erase("sole_local_traj")
                            leg["attack_exit_goal"] = position
                            leg["attack_exit_rotation"] = rotation
                            leg["attack_exit_lift_world"] = entry_lift
                            leg["last_goal"] = position
                            leg["last_rotation"] = rotation
                    elif t <= freeze_end:
                        # v409: for KICK the whole-limb lift below
                        # corrects the joint retarget's floor
                        # penetration; the played trajectory is
                        # sampled from the unlifted hip and does not
                        # penetrate, so the hip is restored before
                        # the trajectory block and no lift is
                        # recorded for the recovery.
                        var kick_pre_lift_hip: Vector3 = Vector3.INF
                        if attack_kind == "kick":
                            kick_pre_lift_hip = (
                                leg["upper"] as Node3D).global_position
                        # Let the authored shoulder/knee/foot keys play,
                        # correcting ONLY frames where a rotated foot's
                        # visible geometry actually intersects the floor.
                        # Sole-only checks miss the opposite long-edge
                        # corner during a kick or lateral sweep.
                        # v400: sole-only checks also miss the upper and
                        # lower leg meshes entirely: the SWEEP swing
                        # carried them to -1.22m (front) / -1.57m (rear)
                        # while the foot stayed clamped. Translate the
                        # whole limb at its shoulder by the deficit,
                        # exactly like the foot correction below:
                        # authored rotations are untouched and
                        # apply_pose restores every pivot before the
                        # next frame, so nothing accumulates.
                        var leg_bottom: float = _leg_mesh_lowest_y(
                            leg["upper"] as Node3D)
                        var lift_applied: float = 0.0
                        if leg_bottom < FLOOR_Y - 0.001:
                            lift_applied = FLOOR_Y + 0.003 - leg_bottom
                            (leg["upper"] as Node3D).global_position += (
                                Vector3.UP * lift_applied)
                        # v402: remember the lift so the recovery blend
                        # can decay it instead of dropping it in one
                        # tick at the authored->IK handover (measured
                        # hip teleport 0.74m and a 49-degree shoulder
                        # snap on rear SWEEPs at that boundary).
                        leg["attack_exit_lift_world"] = lift_applied
                        if attack_kind == "kick":
                            (leg["upper"] as Node3D
                                ).global_position = kick_pre_lift_hip
                            leg["attack_exit_lift_world"] = 0.0
                        # v409: for KICK, the two foot-node
                        # translations below (toe contact, floor
                        # lift) correct the joint retarget's pose;
                        # they also change the knee->foot distance
                        # _solve measures, which threw the played
                        # trajectory off its goal by the clamp
                        # amount (measured +1.25m at the fold).
                        # The trajectory replaces that pose, so
                        # restore the foot node before the reads.
                        var kick_pre_clamp_foot: Vector3 = Vector3.INF
                        if attack_kind == "kick":
                            kick_pre_clamp_foot = foot.global_position
                        var bottom: float = _foot_mesh_lowest_y(foot)
                        # The BODY floor clamp can lift the authored
                        # low KICK/SWEEP preparation by several centimetres.
                        # Re-seat the active striking foot only during the
                        # FINAL 0.12s of the original 0.70s windup. Keep the
                        # chassis above ground and the other three feet
                        # world-anchored; from the strike boundary onward
                        # the original authored limb is free to swing.
                        var windup: float = float(
                            attack_pose.get("windup", 0.70))
                        if t >= windup - 0.12 and (
                                t <= windup + 0.12) and (
                                bottom > FLOOR_Y + 0.004):
                            # C1-continuous contact at the boundary:
                            # real frame time can be windup + 1e-15
                            # after 42 updates at 60Hz. Do not end
                            # ground correction on an exact t<=windup
                            # comparison or the start toe will float.
                            # Ease out over 0.12s of the actual strike,
                            # so the raw authored foot never jumps.
                            var contact_mix: float = _cubic(
                                (t - (windup - 0.12)) / 0.12) * (
                                1.0 - _cubic((t - windup) / 0.12))
                            var lower: float = maxf(
                                bottom - FLOOR_Y - 0.003, 0.0)
                            var ground_goal: Vector3 = (
                                foot.to_global(leg["sole_local"])
                                + Vector3.DOWN * lower * contact_mix)
                            # KICK and SWEEP are authored joint
                            # trajectories. Do not run two-bone _solve()
                            # on their striking limb: it recomputes the
                            # knee/shoulder angles and visibly changes
                            # the reflected right/rear SWEEP silhouette.
                            # The chest floor correction has already
                            # grounded the source prepose; use a purely
                            # translational final toe contact adjustment.
                            foot.global_position += Vector3.DOWN * (
                                lower * contact_mix)
                            bottom = _foot_mesh_lowest_y(foot)
                        if bottom < FLOOR_Y - 0.001:
                            # Keep all three authored local rotations and
                            # the mesh above the floor. World-space toe
                            # adjustment never feeds back into the NEXT
                            # authored frame because pivots are restored
                            # before every new pose sample.
                            foot.global_position += Vector3.UP * (
                                FLOOR_Y + 0.003 - bottom)
                        if attack_kind == "kick":
                            foot.global_position = kick_pre_clamp_foot
                        position = foot.to_global(leg["sole_local"])
                        rotation = foot.global_basis.get_rotation_quaternion()
                        # v409: for KICK, play the source leg's
                        # reflected trajectory in foot space for
                        # the whole attack (the rig's
                        # sample_authored_kick_source): the goal
                        # is the original motion's sole position,
                        # foot rotation and knee, reflected for
                        # this leg, with the aim yaw re-applied
                        # around the hip. Joint-space retargets
                        # preserve the source orientations but
                        # not its foot trajectory on each leg's
                        # own bind geometry (leg_fr deviated up
                        # to 1.75m mid-strike, 0.36m at hold), so
                        # the trajectory itself is what is
                        # reproduced now (device request: the
                        # original motion, foot extending low
                        # along the ground, on every leg). v410:
                        # the goal blends from the planted basic
                        # stance over the first 0.25s of the
                        # strike (the clip's fold-hold segment);
                        # during the windup the leg stays planted
                        # (see the v410 plant branch above). The v407
                        # ramp blend and the v408 per-leg choice
                        # are superseded: there are no longer two
                        # chains to blend between.
                        var solve_for_trajectory: bool = false
                        var foot_ref: Vector3 = foot.global_position
                        if attack_kind == "kick":
                            var sole_local_v: Vector3 = (
                                leg["source_sole_local"] as Vector3)
                            var clip_t: float = clampf(float(
                                attack_pose.get("authored_time",
                                    0.0)), 0.0, 1.0)
                            var src: Dictionary = actor.call(
                                "sample_authored_kick_source",
                                str(attack_pose.get("id", "")),
                                clip_t, legs[LEG_PART_IDS.find(
                                    "leg_fl")]["source_sole_local"])
                            if not src.is_empty():
                                var hip_pos: Vector3 = (
                                    leg["upper"] as Node3D
                                    ).global_position
                                var aim_yaw: float = float(
                                    actor.get("attack_leg_aim_yaw"))
                                # v410: the trajectory starts at the
                                # strike (the windup plants the leg),
                                # when the rig's own aim factor has
                                # reached 1.0, so the full yaw applies
                                # from the first trajectory tick. The
                                # old windup scaling is gone with the
                                # windup entry blend it matched.
                                var aim_q: Quaternion = Quaternion(
                                    Vector3.UP, aim_yaw)
                                var goal_rot: Quaternion = aim_q * (
                                    src["rotation"] as Quaternion)
                                var goal_sole: Vector3 = _aim_rotated(
                                    src["sole"] as Vector3,
                                    hip_pos, aim_q)
                                var goal_knee: Vector3 = _aim_rotated(
                                    src["knee"] as Vector3,
                                    hip_pos, aim_q)
                                var goal_foot: Vector3 = _aim_rotated(
                                    src["foot"] as Vector3,
                                    hip_pos, aim_q)
                                # v410: the entry is the planted
                                # basic stance the windup held (the
                                # last planted goal/rotation), not a
                                # windup capture: the trajectory now
                                # starts at the strike and blends
                                # from the stance over the source
                                # clip's fold-hold segment, so the
                                # leg folds out of the basic stance
                                # and then follows the pure
                                # trajectory (the v409 comment above
                                # describes the trajectory itself;
                                # only its entry changed).
                                if not leg.has(
                                        "kick_traj_entry_sole"):
                                    leg["kick_traj_entry_sole"] = (
                                        leg.get("last_goal", position))
                                    leg[
                                        "kick_traj_entry_rotation"
                                        ] = leg.get(
                                            "last_rotation", rotation)
                                    leg["kick_traj_entry_knee"] = (
                                        leg.get("last_knee",
                                            (leg["lower"] as Node3D
                                            ).global_position))
                                    leg["kick_traj_entry_foot"] = (
                                        leg.get("last_foot",
                                            foot.global_position))
                                if t < attack_windup + \
                                        KICK_TRAJECTORY_ENTRY_BLEND_SECONDS:
                                    var bw: float = clampf(
                                        (t - attack_windup)
                                        / KICK_TRAJECTORY_ENTRY_BLEND_SECONDS,
                                        0.0, 1.0)
                                    bw = bw * bw * (3.0 - 2.0 * bw)
                                    goal_sole = (leg[
                                        "kick_traj_entry_sole"]
                                        as Vector3).lerp(goal_sole, bw)
                                    goal_rot = (leg[
                                        "kick_traj_entry_rotation"]
                                        as Quaternion).slerp(
                                            goal_rot, bw)
                                    goal_knee = (leg[
                                        "kick_traj_entry_knee"]
                                        as Vector3).lerp(goal_knee, bw)
                                    goal_foot = (leg[
                                        "kick_traj_entry_foot"]
                                        as Vector3).lerp(goal_foot, bw)
                                # v409: the reflected foot frame is
                                # not an exact mirror of the source
                                # frame, so on the other legs a mesh
                                # corner hangs lower below the sole
                                # than the source's own corner does
                                # (clip-0 fold clearance: fl 0.05 vs
                                # fr 0.24, rear legs 0.37). Raise the
                                # goal by the clearance difference so
                                # the played mesh keeps the source's
                                # own clearance instead of the
                                # post-solve clip guard below lifting
                                # the sole by the full penetration
                                # (measured +0.37 on leg_fr's fold).
                                var fl_index: int = (
                                    LEG_PART_IDS.find("leg_fl"))
                                var fl_sole_local: Vector3 = legs[
                                    fl_index]["source_sole_local"]
                                var src_fl: Dictionary = actor.call(
                                    "sample_authored_kick_source",
                                    "leg_fl", clip_t, fl_sole_local)
                                if not src_fl.is_empty():
                                    var leg_clear: float = (
                                        _trajectory_mesh_clearance(
                                            leg, goal_foot, goal_rot,
                                            goal_sole))
                                    var fl_clear: float = (
                                        _trajectory_mesh_clearance(
                                            legs[fl_index],
                                            src_fl["foot"] as Vector3,
                                            src_fl["rotation"]
                                                as Quaternion,
                                            src_fl["sole"] as Vector3))
                                    var clear_diff: float = (
                                        leg_clear - fl_clear)
                                    var clear_dy: float = 0.0
                                    if clear_diff > 0.0:
                                        clear_dy = clear_diff
                                    elif clear_diff < 0.0:
                                        # The leg's mesh reaches
                                        # less below its sole than
                                        # the source's does, so
                                        # its fold mesh floats
                                        # (up to 0.93m on leg_rl).
                                        # Lower the goal toward
                                        # the floor by the
                                        # difference, bounded by
                                        # the mesh's headroom
                                        # above the floor and
                                        # faded out as the
                                        # extension begins.
                                        var headroom: float = maxf(
                                            goal_sole.y
                                            - leg_clear, 0.0)
                                        var fold_w: float = 1.0 \
                                            - smoothstep(
                                                0.25, 0.45, clip_t)
                                        clear_dy = -minf(
                                            -clear_diff,
                                            headroom) * fold_w
                                    if clear_dy != 0.0:
                                        # v413: A rear KICK needs the whole
                                        # limb's clearance, not a taller
                                        # ankle-only target. Previously the
                                        # toe correction raised its target
                                        # above an unchanged hip, stretching
                                        # the knee far beyond its source fold
                                        # (~19 degrees with clean sole data).
                                        # Keep hip and knee/ankle/sole targets
                                        # in the same frame. The authored
                                        # local shoulder pivot is restored on
                                        # the next rig sample and the final
                                        # lift decays in recovery.
                                        if clear_dy > 0.0 and str(
                                                attack_pose.get("id", "")
                                                ).begins_with("leg_r"):
                                            # The common recovery-tail
                                            # fallthrough below moves the
                                            # upper pivot exactly once.
                                            # Do not also translate it
                                            # here (that would double-lift).
                                            hip_pos.y += clear_dy
                                            leg["attack_exit_lift_world"] = (
                                                clear_dy)
                                        # Shift the whole goal:
                                        # the sole-point fitting
                                        # below would absorb a
                                        # sole-only shift without
                                        # moving the ankle or the
                                        # mesh at all.
                                        goal_sole.y += clear_dy
                                        goal_foot.y += clear_dy
                                        goal_knee.y += clear_dy
                                # v413: after clearing previous
                                # attacks' fitted sole coordinates the rear
                                # KICK's source retarget can demand an
                                # ankle radius longer than its actual two
                                # bones can take at the source knee angle.
                                # The old, stale toe offset accidentally
                                # concealed that mismatch. Keep the new
                                # attack independent of older toes: during
                                # the folded entry, shorten ONLY the ankle
                                # radius to the physically attainable
                                # distance for the authored knee fold.
                                # The original far-reaching extension is
                                # unaffected (the guard fades to zero).
                                if str(attack_pose.get("id", "")
                                        ).begins_with("leg_r"):
                                    var knee_node: Node3D = leg["lower"]
                                    var upper_len: float = hip_pos.distance_to(
                                        knee_node.global_position)
                                    var lower_len: float = (
                                        knee_node.global_position
                                        .distance_to(foot.global_position))
                                    var source_fold: float = (
                                        hip_pos - goal_knee).angle_to(
                                            goal_foot - goal_knee)
                                    var attainable: float = sqrt(maxf(
                                        upper_len * upper_len
                                        + lower_len * lower_len
                                        - 2.0 * upper_len * lower_len
                                        * cos(source_fold), 0.0))
                                    var ray: Vector3 = goal_foot - hip_pos
                                    var actual_radius: float = ray.length()
                                    var fold_guard: float = (
                                        smoothstep(0.05, 0.22, clip_t)
                                        * (1.0 - smoothstep(
                                            0.36, 0.55, clip_t)))
                                    if actual_radius > attainable + 0.005                                             and fold_guard > 0.0:
                                        var shorten: float = minf(
                                            actual_radius - attainable,
                                            0.75) * fold_guard
                                        var shift: Vector3 = (
                                            -ray / actual_radius) * shorten
                                        goal_sole += shift
                                        goal_foot += shift
                                # v409: the plane-reflected rotation
                                # does not act on this leg's own
                                # sole_local the way it acts on the
                                # source's: each foot's local frame
                                # differs from the mirrored source
                                # frame by a constant rotation
                                # (measured offset error, constant
                                # over the whole clip: fr 1.70m /
                                # 49.2 deg, rl 1.44m / 41.2 deg,
                                # rr 1.29m / 36.7 deg). _solve
                                # derives the ankle target from
                                # (goal sole - rotation * sole_local),
                                # so the mismatch threw the ankle
                                # metres off the transferred joint
                                # and tripped the reach clamp at
                                # extension, capping the played
                                # reach. Bending the rotation to
                                # fit tipped the rear feet (38.7
                                # degrees at extension), so instead
                                # hand _solve a per-tick sole point
                                # that the reflected rotation maps
                                # exactly onto the transferred
                                # ankle->sole offset: the ankle
                                # lands on the transferred joint
                                # and the foot keeps the pure
                                # reflected orientation (extension
                                # tilt ~9 degrees, like the
                                # source). The original sole_local
                                # is restored when the freeze ends
                                # (recovery branch, clear_attack_pose).
                                var offset_want: Vector3 = (
                                    goal_sole - goal_foot)
                                if offset_want.length_squared() > 0.000001:
                                    if not leg.has(
                                            "sole_local_saved"):
                                        leg["sole_local_saved"] = (
                                            sole_local_v)
                                    leg["sole_local"] = Basis(
                                        goal_rot).inverse() \
                                        * offset_want / maxf(foot
                                            .global_basis
                                            .get_scale().x, 0.001)
                                    leg["sole_local_traj"] = (
                                        leg["sole_local"])
                                position = goal_sole
                                rotation = goal_rot
                                leg["authored_pole_point"] = goal_knee
                                foot_ref = goal_foot
                                solve_for_trajectory = true
                        # v406: shorten an over-extended KICK along its
                        # own hip->foot ray and let _solve bend the
                        # knee in the authored plane (see _solve's
                        # authored-pole override). The v404 pose
                        # slerp rotated the leg through the floor and
                        # the floor lift above then hoisted the hip
                        # by up to 2.5m for the whole strike/hold.
                        # Engages only once the authored extension
                        # passes the target length, so the strike
                        # path, direction and foot orientation stay
                        # authored; at full reach it never engages.
                        var solve_for_reach: bool = false
                        if attack_kind == "kick" and (
                                t >= attack_windup):
                            var reach_factor: float = float(
                                actor.get("kick_reach_factor"))
                            if reach_factor < 0.999:
                                var hip_pos: Vector3 = (
                                    leg["upper"] as Node3D
                                    ).global_position
                                var ray: Vector3 = (
                                    foot_ref - hip_pos)
                                var ray_xz: float = Vector2(
                                    ray.x, ray.z).length()
                                var target_xz: float = (
                                    KICK_REACH_BASE_METERS
                                    + reach_factor
                                    * KICK_REACH_PER_FACTOR)
                                if ray_xz > target_xz + 0.001:
                                    position += hip_pos + ray * (
                                        target_xz / ray_xz) \
                                        - foot_ref
                                    solve_for_reach = true
                        leg["attack_exit_goal"] = position
                        leg["attack_exit_rotation"] = rotation
                        leg["last_goal"] = position
                        leg["last_rotation"] = rotation
                        if not solve_for_reach and not solve_for_trajectory:
                            continue
                        leg["authored_pole_active"] = true
                    # After the exact 1.5s KICK hold, or immediately after
                    # SWEEP's strike, blend from the LAST grounded pose,
                    # not the newly resampled/rest-keyed pose (no jump).
                    var recover_t: float = _cubic((t - freeze_end) / maxf(
                        float(attack_pose.get("recovery", 0.60)), 0.001))
                    position = (leg.get("attack_exit_goal",
                        actual) as Vector3).lerp(leg["anchor"], recover_t)
                    rotation = (leg.get("attack_exit_rotation",
                        authored_rotation) as Quaternion).slerp(
                        leg["anchor_rotation"] as Quaternion, recover_t)
                    # v409: the freeze branch solved the KICK
                    # trajectory against a per-tick sole point
                    # fitted to the reflected rotation; blend that
                    # point back to the leg's real sole point over
                    # the recovery so the ankle target stays
                    # continuous across the handover (restoring it
                    # in one tick would jump the ankle by the
                    # frame mismatch, up to 1.7m on leg_fr).
                    if leg.has("sole_local_saved"):
                        var orig_sole: Vector3 = (
                            leg["sole_local_saved"] as Vector3)
                        var traj_sole: Vector3 = leg.get(
                            "sole_local_traj", orig_sole)
                        if recover_t >= 0.999:
                            leg["sole_local"] = orig_sole
                            leg.erase("sole_local_saved")
                            leg.erase("sole_local_traj")
                        else:
                            leg["sole_local"] = traj_sole.lerp(
                                orig_sole, recover_t)
                    # v402: decay the whole-limb floor lift over the
                    # blend instead of dropping it at the boundary.
                    # apply_pose restored the shoulder pivot to its
                    # bind position this tick, so re-apply the
                    # remaining lift before _solve reads the hip: at
                    # recover_t == 0 the hip is exactly where the
                    # authored branch left it, and the solve geometry
                    # now moves continuously on both sides of the
                    # handover.
                    var exit_lift: float = float(
                        leg.get("attack_exit_lift_world", 0.0))
                    if exit_lift > 0.0:
                        (leg["upper"] as Node3D).global_position += (
                            Vector3.UP * exit_lift * (1.0 - recover_t))
                else:
                    rotation = _attack_rotation(leg)
                    position = _attack_goal(leg, rotation)
                    if attack_kind == "stomp":
                        var t_stomp: float = float(attack_pose.get(
                            "time", 0.0))
                        var strike_at: float = float(attack_pose.get(
                            "windup", 1.25)) + float(attack_pose.get(
                            "strike", 0.25))
                        var pause_end: float = strike_at + float(
                            attack_pose.get("hold", 1.50))
                        # Lock the ACTUAL reached tip and angle on the
                        # first contact frame. Holding a nominally
                        # unreachable sole=0 goal recalculates a new
                        # joint chain each tick and visibly slides it.
                        if t_stomp > strike_at + 0.001 and (
                                t_stomp <= pause_end) and (
                                leg.has("stomp_impact_sole")):
                            position = leg["stomp_impact_sole"]
                            rotation = leg["stomp_impact_rotation"]
            else:
                # No gait, foot replanting, or root yaw while attacking.
                # A support foot interrupted midstep settles ONLY in Y;
                # its frozen world X/Z contact must never drift.
                var start: Vector3 = leg.get("attack_entry_goal", position)
                var settle: float = _cubic(
                    float(attack_pose.get("time", 0.0)) / 0.24)
                position.y = lerpf(start.y, position.y, settle)
        if bool(leg["stepping"]):
            leg["swing_elapsed"] = minf(STEP_DURATION_SECONDS,
                float(leg["swing_elapsed"]) + delta)
            var ratio: float = float(leg["swing_elapsed"]) / STEP_DURATION_SECONDS
            var eased: float = ratio * ratio * (3.0 - 2.0 * ratio)
            # Target the actual landing location for THIS body's CURRENT
            # position/yaw, not the old chassis orientation at step start.
            # The 0.58s swing duration remains fixed. Both the foot's
            # touchdown position and rotation match the body's NEW stance.
            leg["swing_to"] = _home(leg, motion == "Approach")
            leg["rotation_to"] = _rotation_home(leg)
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
        # Sideways topple only the leg whose planted foot was under the
        # head on the XZ plane at the moment the body began falling.
        if break_elapsed >= 0.0 and head_support_leg_index >= 0                 and leg["upper"] == legs[head_support_leg_index]["upper"]:
            var collapse: float = _cubic(clampf(
                break_elapsed / LEG_BREAK_FALL_SECONDS, 0.0, 1.0))
            if break_elapsed > break_recover_start:
                collapse *= 1.0 - _cubic(
                    (break_elapsed - break_recover_start) /
                    maxf(break_duration - break_recover_start, 0.001))
            position += head_support_outward * (
                SUPPORT_LEG_OUTWARD_METERS * collapse)
            var tilt_axis: Vector3 = actor.global_basis.z.normalized()
            var sign: float = 1.0 if head_support_outward.dot(
                actor.global_basis.x) >= 0.0 else -1.0
            rotation = (Quaternion(tilt_axis, sign * deg_to_rad(
                SUPPORT_FOOT_ROLL_DEGREES) * collapse) *
                head_support_foot_rotation).normalized()
        leg["last_error"] = _solve(leg, position, rotation)
        # v414: do not abandon the actually grounded end-effector at
        # hold->recovery when the fixed-height, forward-pitched BODY puts
        # the nominal contact just outside the two-bone reach sphere.
        # This is the same toe-only contact correction already used in
        # STOMP hold, now decaying with the return goal instead of
        # snapping upward on the first recovery tick.
        if attacking and attacking_this_leg and _rear_attack_active()                 and str(attack_pose.get("kind", "")) == "stomp":
            var stomp_recovery_start: float = (
                float(attack_pose.get("windup", 1.25))
                + float(attack_pose.get("strike", 0.25))
                + float(attack_pose.get("hold", 1.50)))
            if float(attack_pose.get("time", 0.0)) > stomp_recovery_start:
                var recovery_foot: Node3D = leg["foot"]
                var foot_error: Vector3 = (
                    position - recovery_foot.to_global(
                        leg["sole_local"] as Vector3))
                recovery_foot.global_position += foot_error
                leg["last_goal"] = position
                leg["last_error"] = 0.0
        if attacking and attacking_this_leg and str(
                attack_pose.get("kind", "")) == "stomp":
            var stomp_t: float = float(attack_pose.get("time", 0.0))
            var touchdown_t: float = float(attack_pose.get("windup", 1.25)) \
                + float(attack_pose.get("strike", 0.25))
            var hold_end_t: float = touchdown_t + float(
                attack_pose.get("hold", 1.50))
            if stomp_t >= touchdown_t - 0.002 and stomp_t <= hold_end_t:
                # The collision contact belongs to the visible SHORT tip
                # face, not a sole marker measured in the Wait foot pose.
                # Correct a final reach error in IK, only at touchdown;
                # preserve the authored descending limb path before it.
                var stomp_foot: Node3D = leg["foot"]
                var toe_bottom: float = _foot_mesh_lowest_y(stomp_foot)
                for attempt in range(2):
                    if absf(toe_bottom - FLOOR_Y) < 0.004:
                        break
                    var correction: float = clampf(
                        FLOOR_Y + 0.002 - toe_bottom, -0.22, 0.22)
                    leg["last_error"] = _solve(leg,
                        stomp_foot.to_global(leg["sole_local"] as Vector3)
                        + Vector3.UP * correction, rotation)
                    toe_bottom = _foot_mesh_lowest_y(stomp_foot)
                if absf(toe_bottom - FLOOR_Y) > 0.004:
                    # At a saturated reach, move the tiny remainder at
                    # the end effector rather than folding the knee or
                    # driving the other three supports into the floor.
                    stomp_foot.global_position.y += (
                        FLOOR_Y + 0.002 - toe_bottom)
                leg["last_goal"] = stomp_foot.to_global(
                    leg["sole_local"] as Vector3)
                if not leg.has("stomp_impact_sole"):
                    leg["stomp_impact_sole"] = leg["last_goal"]
                    leg["stomp_impact_rotation"] = (
                        stomp_foot.global_basis.get_rotation_quaternion())
        if attacking and not attacking_this_leg:
            # Some BODY windup poses sit a few centimetres outside a
            # full-extension support knee's reachable sphere. Do not
            # let the real visible foot drift from its WORLD-FIXED
            # contact when the goal remains unchanged. Apply at most
            # a tiny end-effector contact correction; IK still handles
            # the actual large-scale articulation of the entire leg.
            var support_foot: Node3D = leg["foot"]
            var support_error: Vector3 = position - support_foot.to_global(
                leg["sole_local"] as Vector3)
            # A very low authored KICK/SWEEP torso can exceed even
            # the full anatomical two-bone support reach. Prefer the
            # guaranteed world-fixed visible sole to stepping/sliding
            # it up to 40cm (or more) from its contact. This position
            # is restored from the same fixed anchor every physics tick.
            support_foot.global_position += support_error
            leg["last_error"] = support_foot.to_global(
                leg["sole_local"] as Vector3).distance_to(position)
        if attacking and attacking_this_leg and bool(
                attack_pose.get("authored", false)) and str(
                attack_pose.get("kind", "")) != "stomp":
            # Recovering the authored foot changes its pitch. Its
            # formerly planted corner may become the low corner again.
            # Check the full mesh AFTER recovery IK, not just during
            # the strike and post-hit hold.
            var clip_foot: Node3D = leg["foot"]
            # v410: during the SWEEP strike entry the played pose
            # is an IK blend toward the authored pose, and the
            # dipping point is a shin/toe corner of the whole
            # limb, not just the foot; guard the whole limb's mesh
            # there with the hip+goal lift strategy below.
            var sweep_entry: bool = str(
                attack_pose.get("kind", "")) == "sweep" and (
                float(attack_pose.get("time", 0.0)) >= float(
                    attack_pose.get("windup", 0.0))) and (
                float(attack_pose.get("time", 0.0)) < float(
                    attack_pose.get("windup", 0.0))
                    + SWEEP_ENTRY_BLEND_SECONDS)
            var kick_freeze: bool = str(
                attack_pose.get("kind", "")) == "kick" and (
                float(attack_pose.get("time", 0.0)) <= float(
                    attack_pose.get("windup", 0.0)) + float(
                    attack_pose.get("strike", 0.0)) + float(
                    attack_pose.get("hold", 0.0)))
            # v412: during the KICK freeze the guard measures
            # the WHOLE limb, not just the foot. The rear legs'
            # front-back-reversed Body tilt (v412) drops the rear
            # hip mid-strike, and leg_rl's shin corner dipped
            # -0.054m under the floor while its foot stayed
            # clear -- invisible to the foot-only measurement.
            var whole_limb: bool = sweep_entry or kick_freeze
            var clip_min: float = (
                _leg_mesh_lowest_y(leg["upper"] as Node3D)
                if whole_limb else _foot_mesh_lowest_y(clip_foot))
            if clip_min < FLOOR_Y - 0.001:
                # v409: during the KICK trajectory freeze, lift
                # the HIP and the goal together instead of
                # re-solving the sole upward. The source
                # trajectory's toe scrapes the floor mid-
                # extension (mesh up to ~0.9m under at the
                # authored actor height); lifting only the sole
                # bent that scrape into the hip-relative profile
                # (ankle +0.9m), while lifting hip+goal keeps
                # the profile exact and the mesh skimming the
                # floor. The lift is recorded as the exit lift
                # so the recovery decays it like the v402 one.
                var lift_strategy: bool = kick_freeze or sweep_entry
                var guard_lift: float = 0.0
                for retry in range(2):
                    var extra: float = maxf(
                        FLOOR_Y + 0.003 - clip_min, 0.0)
                    if extra < 0.0001:
                        break
                    if lift_strategy:
                        (leg["upper"] as Node3D
                            ).global_position += (
                            Vector3.UP * extra)
                        position += Vector3.UP * extra
                        guard_lift += extra
                        leg["last_error"] = _solve(
                            leg, position, rotation)
                    else:
                        var safe: Vector3 = (
                            clip_foot.to_global(
                                leg["sole_local"] as Vector3)
                            + Vector3.UP * extra)
                        leg["last_error"] = _solve(
                            leg, safe, rotation)
                    clip_min = (
                        _leg_mesh_lowest_y(leg["upper"] as Node3D)
                        if whole_limb else
                        _foot_mesh_lowest_y(clip_foot))
                if kick_freeze and guard_lift > 0.0:
                    leg["attack_exit_lift_world"] = guard_lift
                    leg["attack_exit_goal"] = position
                elif sweep_entry and guard_lift > 0.0:
                    # Add to the entry branch's own lift (already
                    # recorded this tick) so the recorded total
                    # stays the hip's actual displacement.
                    leg["attack_exit_lift_world"] = float(
                        leg.get("attack_exit_lift_world", 0.0)) \
                        + guard_lift
                    leg["attack_exit_goal"] = position
                if clip_min < FLOOR_Y - 0.001 and not whole_limb:
                    clip_foot.global_position += Vector3.UP * (
                        FLOOR_Y + 0.003 - clip_min)
                leg["last_goal"] = clip_foot.to_global(
                    leg["sole_local"] as Vector3)
        if attacking and attacking_this_leg and str(
                attack_pose.get("kind", "")) == "kick":
            _ground_rear_kick_foot(leg)
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
    # Never reconcile while the v398 attack-stance preparation owns
    # the feet: its moving diagonal is intentionally airborne and the
    # waiting diagonal may still sit at its interrupted gait-step
    # height, so every sole can read above the floor at once. Treating
    # them as planted dragged the chassis down and accumulated the
    # error in the persistent ground correction on every attack.
    # The preparation itself lands all four soles on exact Wait
    # contacts, so reconciliation safely resumes once it hands off.
    if not attacking and not attack_stance_active and planted_count >= 2 and min_planted_height != INF             and absf(min_planted_height) > GROUND_HOVER_THRESHOLD_METERS:
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
            if break_elapsed >= 0.0 and head_support_leg_index >= 0                     and leg["upper"] == legs[head_support_leg_index]["upper"]:
                var collapse: float = _cubic(clampf(
                    break_elapsed / LEG_BREAK_FALL_SECONDS, 0.0, 1.0))
                if break_elapsed > break_recover_start:
                    collapse *= 1.0 - _cubic(
                        (break_elapsed - break_recover_start) /
                        maxf(break_duration - break_recover_start, 0.001))
                foot_pos += head_support_outward * (
                    SUPPORT_LEG_OUTWARD_METERS * collapse)
                var tilt_axis: Vector3 = actor.global_basis.z.normalized()
                var sign: float = 1.0 if head_support_outward.dot(
                    actor.global_basis.x) >= 0.0 else -1.0
                foot_rot = (Quaternion(tilt_axis, sign * deg_to_rad(
                    SUPPORT_FOOT_ROLL_DEGREES) * collapse) *
                    head_support_foot_rotation).normalized()
            leg["last_error"] = _solve(leg, foot_pos, foot_rot)
    if break_elapsed >= 0.0 and head_support_leg_index >= 0:
        _resolve_head_on_leg_contact()
        # Limiting chassis pitch changes the hip position. Re-solve soles
        # against the same planted floor anchors AFTER the head touches the
        # support leg, without undoing the sideways foot roll.
        for i in range(legs.size()):
            var leg: Dictionary = legs[i]
            if bool(leg["stepping"]):
                continue
            var foot_pos: Vector3 = leg["anchor"]
            var foot_rot: Quaternion = leg["anchor_rotation"]
            if i == head_support_leg_index:
                var collapse: float = _cubic(clampf(
                    break_elapsed / LEG_BREAK_FALL_SECONDS, 0.0, 1.0))
                if break_elapsed > break_recover_start:
                    collapse *= 1.0 - _cubic(
                        (break_elapsed - break_recover_start) /
                        maxf(break_duration - break_recover_start, 0.001))
                foot_pos += head_support_outward * (
                    SUPPORT_LEG_OUTWARD_METERS * collapse)
                var sign: float = 1.0 if head_support_outward.dot(
                    actor.global_basis.x) >= 0.0 else -1.0
                foot_rot = (Quaternion(actor.global_basis.z.normalized(),
                    sign * deg_to_rad(SUPPORT_FOOT_ROLL_DEGREES) * collapse) *
                    head_support_foot_rotation).normalized()
            leg["last_error"] = _solve(leg, foot_pos, foot_rot)
    # The last pose-settle counter is for collision/weakpoint lifecycle,
    # NOT a motion gate. The locomotion clip and planted-foot IK are
    # allowed to run while this counter drains.
    if post_down_idle_remaining > 0.0 and not break_reaction_active()             and head_support_leg_index < 0:
        var scale_y: float = maxf(
            absf(actor.get_parent().global_basis.get_scale().y), 0.001)
        var expected_local_y: float = (rest_actor_local_y
            + ground_correction_world / scale_y)
        var upright_error_world: float = (
            absf(actor.position.y - expected_local_y) * scale_y)
        if upright_error_world <= POST_DOWN_UPRIGHT_TOLERANCE_WORLD_METERS:
            post_down_idle_remaining = maxf(0.0,
                post_down_idle_remaining - maxf(delta, 0.0))
    # Save the FINAL visual model transform, after authored chassis dips,
    # fall recovery and contact correction. Recording the PRE-attack pose
    # here previously treated a real 1.5m STOMP crouch as an arena
    # teleport on the next tick and reset() erased the active attack pose.
    last_actor_position = actor.global_position
    last_actor_yaw = actor.global_rotation.y


# Reuse final IK sole targets after the authored clip, grounding correction
# and head-support pitch have all been resolved. Search only articulated
# knee bend planes; the boss's root/center of mass never teleports.
func _head_knee_mass_center_xz() -> Vector2:
    var weighted: Vector3 = chassis_bone.global_position * HEAD_KNEE_BODY_MASS
    for leg in legs:
        weighted += (leg["lower"] as Node3D).global_position * HEAD_KNEE_LEG_MASS
    return Vector2(weighted.x, weighted.z)


func _head_knee_support_center_xz() -> Vector2:
    var point := Vector2.ZERO
    var count: float = 0.0
    for leg in legs:
        if bool(leg["stepping"]):
            continue
        var sole: Vector3 = leg["anchor"]
        point += Vector2(sole.x, sole.z)
        count += 1.0
    if count < 2.0:
        return Vector2(actor.global_position.x, actor.global_position.z)
    return point / count


func _head_knee_collision_cost(id: String, base_pose: Quaternion,
        swept_poses: Array[Quaternion]) -> float:
    # The deepest actual oriented-element overlap in world metres.
    # Fold the leg proactively above 13cm, before the shared 20cm hard
    # head limit. Use actual oriented-mesh depth, never AABB volume.
    var worst: float = 0.0
    for pose in swept_poses:
        head_bone.quaternion = pose
        var depth: float = float(collision_parts.call(
            "get_head_leg_penetration_depth", id))
        worst = maxf(worst, maxf(0.0,
            depth - HEAD_KNEE_PREFERRED_PENETRATION_METERS))
    head_bone.quaternion = base_pose
    return worst


func _scan_head_knee_targets(sweep_heads: Array[AABB],
        base_pose: Quaternion, swept_poses: Array[Quaternion]) -> void:
    var center: Vector2 = _head_knee_support_center_xz()
    for index in range(legs.size()):
        var leg: Dictionary = legs[index]
        var previous_target: float = float(leg["head_knee_target"])
        leg["head_knee_target"] = 0.0
        # The actively authored striker owns its three joints. Fold only
        # the other support legs so the original attack never gets erased.
        if not attack_pose.is_empty() and str(attack_pose.get("id", "")) == LEG_PART_IDS[index]:
            leg["head_knee_bend"] = 0.0
            continue
        # v412: during any attack the FRONT legs never fold to avoid
        # the head (device request). The head tracks the player
        # through every attack, and a planted front knee folding up
        # to 40 degrees to dodge it read as the leg shying away from
        # the head mid-attack (measured: leg_fl bend reached the
        # 0.70 cap during leg_rl/leg_rr kicks). The target stays
        # zero for the whole attack, stance preparation included
        # (the preparation is part of the attack sequence), and
        # steer_knees_for_head zeroes the bend itself; locomotion
        # and knockdown avoidance are unchanged.
        if (not attack_pose.is_empty() or attack_stance_active) \
                and LEG_PART_IDS[index].begins_with("leg_f"):
            continue
        # Do not skip a SWINGING leg: its moving knee/upper segment can
        # run into an otherwise stationary head. _solve() below preserves
        # the current sole swing target and the authored swing duration.
        var broad: AABB = collision_parts.call(
            "get_leg_visual_aabb", LEG_PART_IDS[index])
        var nearby: bool = false
        for head_box in sweep_heads:
            if broad.intersects(head_box.grow(HEAD_KNEE_PROXIMITY_METERS)):
                nearby = true
                break
        if not nearby:
            continue
        var sole_goal: Vector3 = leg["last_goal"]
        var sole_rotation: Quaternion = leg["last_rotation"]
        var before_bend: float = float(leg["head_knee_bend"])
        var initial_mass: Vector2 = _head_knee_mass_center_xz()
        # Re-evaluate the baseline as an exact neutral-pole pose.
        leg["head_knee_bend"] = 0.0
        _solve(leg, sole_goal, sole_rotation)
        var base_cost: float = _head_knee_collision_cost(
            LEG_PART_IDS[index], base_pose, swept_poses)
        var best_cost: float = base_cost
        var best: float = 0.0
        var retained_score: float = INF
        # Prefer letting a support knee fall outward and down before
        # the head approaches 20cm; include last target for stability.
        for candidate in [0.10, 0.20, 0.30, 0.45, 0.55, 0.65,
                HEAD_KNEE_MAX_BEND, previous_target]:
            leg["head_knee_bend"] = float(candidate)
            _solve(leg, sole_goal, sole_rotation)
            var collision_cost: float = _head_knee_collision_cost(
                LEG_PART_IDS[index], base_pose, swept_poses)
            var mass: Vector2 = _head_knee_mass_center_xz()
            var added_imbalance: float = maxf(0.0,
                mass.distance_to(center) - initial_mass.distance_to(center))
            var score: float = (collision_cost
                + added_imbalance * HEAD_KNEE_BALANCE_PENALTY
                + float(candidate) * HEAD_KNEE_BEND_PENALTY_METERS)
            if absf(float(candidate) - previous_target) < 0.00001:
                retained_score = score
            if score < best_cost - 0.00001:
                best_cost = score
                best = float(candidate)
        # Hysteresis of 9mm: a moving plate must not switch the knee
        # from slightly bent to neutral and back every 50ms scan.
        if previous_target > 0.0 and base_cost > 0.0 and (
                retained_score <= best_cost
                + HEAD_KNEE_TARGET_HYSTERESIS_METERS):
            best = previous_target
            best_cost = retained_score
        if best > 0.0 and (
                base_cost - best_cost >= HEAD_KNEE_MIN_BENEFIT_METERS
                or (previous_target > 0.0 and base_cost > 0.0
                and retained_score <= best_cost
                + HEAD_KNEE_TARGET_HYSTERESIS_METERS)):
            leg["head_knee_target"] = best
        leg["head_knee_bend"] = before_bend
        _solve(leg, sole_goal, sole_rotation)


func steer_knees_for_head(delta: float, desired_head_yaw: float,
        current_head_yaw: float = 0.0) -> void:
    if not ready or legs.size() != 4 or collision_parts == null \
            or head_bone == null or chassis_bone == null:
        return
    # Never interrupt the special falling/lying support-leg pose.
    # Once physical stand-up starts, however, the chest ALREADY rotates:
    # let the planted knees avoid the head throughout the rise. The
    # original 70% threshold still controls HEAD motion, not knee IK.
    if windup_active() or (down_pose_active() and not standup_knee_enabled()):
        head_knee_scan_elapsed = HEAD_KNEE_SCAN_SECONDS
        return
    var head_pose: Quaternion = head_bone.quaternion
    head_knee_scan_elapsed += maxf(0.0, delta)
    if head_knee_scan_elapsed >= HEAD_KNEE_SCAN_SECONDS:
        head_knee_scan_elapsed = 0.0
        var sweep_heads: Array[AABB] = []
        var sweep_poses: Array[Quaternion] = []
        # The current pose is essential: a planted/stepping knee may
        # INVADE the head even without any requested head rotation.
        for yaw in [current_head_yaw,
                lerpf(current_head_yaw, desired_head_yaw, 0.5),
                desired_head_yaw]:
            var pose: Quaternion = (head_pose *
                Quaternion(Vector3.UP,
                    float(yaw - current_head_yaw))).normalized()
            head_bone.quaternion = pose
            sweep_poses.append(pose)
            sweep_heads.append(collision_parts.call("get_head_swing_aabb"))
        head_bone.quaternion = head_pose
        _scan_head_knee_targets(sweep_heads, head_pose, sweep_poses)
    var active: bool = false
    for leg in legs:
        # v412: the attacking leg keeps its instant exemption.
        # The FRONT legs' bends are not zeroed here: the scan
        # gate (_scan_head_knee_targets) holds their target at
        # zero from the stance preparation on, so any locomotion
        # fold eases out over the preparation instead of popping
        # in one tick, and none is left by the windup (device
        # request: front legs must not avoid the head during
        # attacks).
        if not attack_pose.is_empty() and (
                str(attack_pose.get("id", "")) == LEG_PART_IDS[legs.find(leg)]):
            leg["head_knee_bend"] = 0.0
            continue
        var before: float = float(leg["head_knee_bend"])
        var target: float = clampf(
            float(leg["head_knee_target"]), 0.0, HEAD_KNEE_MAX_BEND)
        var rate: float = (HEAD_KNEE_FLEX_IN_PER_SECOND
            if target > before else HEAD_KNEE_FLEX_OUT_PER_SECOND)
        var after: float = move_toward(before, target,
            rate * maxf(0.0, delta))
        leg["head_knee_bend"] = after
        if after > 0.00001:
            active = true
        if absf(after - before) > 0.00001:
            # No new foot targets: re-solve against the exact final sole
            # goal, conserving reach, floor contact and 0.58s step timing.
            leg["last_error"] = _solve(leg,
                leg["last_goal"], leg["last_rotation"])
    head_knee_active = active

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
