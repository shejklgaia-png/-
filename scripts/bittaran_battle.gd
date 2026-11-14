extends "res://scripts/main.gd"
## Dedicated Bittaran battle. Reuse proven SERA controls/combat/camera/HP,
## but replace the red training dummy with the authored quadruped.
const BittaranRig = preload("res://scripts/bittaran_rig.gd")
const BittaranAI = preload("res://scripts/bittaran_ai.gd")
const BittaranFootIK = preload("res://scripts/bittaran_foot_ik.gd")
const BittaranParts = preload("res://scripts/bittaran_parts.gd")
const DOWN_CLEARANCE = preload("res://scripts/bittaran_down_clearance.gd")
const CONTROLLER_AXIS = preload("res://scripts/bittaran_controller_axis.gd")
const NAME_TEXT: String = "BITTARAN  /  ビットタラン"
const BOSS_WORLD_SCALE: float = 2.0
const BOSS_DEATH_RESPAWN_SECONDS: float = 3.0
const BOSS_FAR_SIDE_ENTER_METERS: float = 0.65
const BOSS_FAR_SIDE_EXIT_METERS: float = -0.25
const DOWN_ESCAPE_SPEED_MPS: float = 15.0
const HEAD_TRACK_MAX_YAW_DEGREES: float = 48.0
const HEAD_TRACK_DEGREES_PER_SECOND: float = 140.0
const HEAD_TRACK_STANDUP_START_FRACTION: float = 0.70
# A gentle, weaker head reacquisition starts at 70% ACTUAL upright pose.
# End the physical rise at only 60% head authority; the post-upright
# settle eases the remaining 40% in smoothly without a rotation snap.
const HEAD_TRACK_RISE_FOLLOW_WEIGHT: float = 0.60
const HEAD_TRACK_RECOVERY_DEGREES_PER_SECOND: float = 48.0
# Head tracks SERA despite up to 30cm of oriented-mesh penetration.
# Only sustained greater depth softly reduces yaw; never snap backwards.
const HEAD_LEG_ALLOWED_PENETRATION_METERS: float = (
    BittaranParts.HEAD_LEG_ALLOWED_PENETRATION_METERS)
const HEAD_TRACK_COLLISION_FILTER_PER_SECOND: float = 9.0
const HEAD_TRACK_COLLISION_SOFT_START_METERS: float = 0.030
const HEAD_TRACK_COLLISION_SOFT_FULL_METERS: float = 0.145
const HEAD_TRACK_COLLISION_MIN_SPEED_FACTOR: float = 0.55

var bittaran_rig: Node3D
var bittaran_ai: RefCounted
var bittaran_foot_ik: RefCounted
var bittaran_motion: String = "Idle"
var boss_name_label: Label
var victory_label: Label
var boss_death_particles: CPUParticles3D
var boss_death_elapsed: float = -1.0
var boss_far_side_screen_axis: bool = false
var boss_last_controller_axis: Vector2 = Vector2.UP
var bittaran_head: Node3D
var boss_head_yaw: float = 0.0
var boss_head_default_rotation: Quaternion = Quaternion.IDENTITY
var boss_head_windup_start_yaw: float = 0.0
var head_neutral_overlap: Dictionary = {}
var head_neutral_component_overlap: Dictionary = {}
var head_collision_filtered_excess: float = 0.0
var boss_downed_escaping: bool = false

func _ready() -> void:
    super._ready()
    # Dedicated boss locomotion is not controlled by training-room settings.
    target_move_enabled = true
    if move_target_button != null:
        move_target_button.visible = false
    var layer := CanvasLayer.new()
    layer.name = "BittaranBattleLabels"
    layer.layer = 30
    add_child(layer)
    boss_name_label = _make_boss_label(layer, NAME_TEXT, 115.0, 22)
    victory_label = _make_boss_label(layer, "BITTARAN DEFEATED", 176.0, 26)
    victory_label.visible = false
    _update_bittaran_lock_permissions()

func _make_boss_label(parent: CanvasLayer, caption: String,
        y: float, font_size: int) -> Label:
    var label := Label.new()
    label.name = "BittaranName" if y < 150.0 else "BittaranVictory"
    label.text = caption
    label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    label.offset_top = y
    label.offset_bottom = y + 34.0
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("#c8ebff"))
    parent.add_child(label)
    return label

func _build_target() -> void:
    # Preserve the combat HP and part-break code but replace all training
    # lock geometry with Bittaran BODY/HEAD/real articulated SHIN volumes.
    super._build_target()
    # Scale the full target root (model, lock positions and collision shapes)
    # as one object; scaling the mesh alone would leave combat hits behind.
    target.scale = Vector3.ONE * BOSS_WORLD_SCALE
    target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
    target_mesh.visible = false
    bittaran_rig = BittaranRig.new()
    bittaran_rig.name = "BittaranRig"
    # The authored head faces -Z; SERA's target-space forward is +Z.
    # Only the model turns 180 degrees here; AI owns the root yaw.
    bittaran_rig.rotation.y = PI
    bittaran_rig.position.y = -1.12
    target.add_child(bittaran_rig)
    bittaran_head = bittaran_rig.find_child("Head", true, false) as Node3D
    if bittaran_head != null:
        boss_head_default_rotation = bittaran_head.quaternion
    bittaran_ai = BittaranAI.new()
    bittaran_ai.call("reset")
    bittaran_foot_ik = BittaranFootIK.new()
    if not bool(bittaran_foot_ik.call("setup", bittaran_rig)):
        push_error("Bittaran: four-leg IK setup failed")
    # The original training parts do not follow the mesh bones and their
    # collision boxes stay at old dummy positions. Use a named boss adapter.
    var old_parts: Node3D = target_parts
    target_mesh.remove_child(old_parts)
    old_parts.queue_free()
    target_parts = BittaranParts.new()
    target_parts.name = "BittaranTargetParts"
    target_mesh.add_child(target_parts)
    if not bool(target_parts.call("setup_bittaran", bittaran_rig, target_collider)):
        push_error("Bittaran: six-part lock adapter failed")
    # The shared physical HEAD/leg AABBs form a self-contact constraint
    # on down. Godot cannot collide sibling shapes on one AnimatableBody3D.
    bittaran_foot_ik.call("set_collision_parts", target_parts)
    _build_boss_death_particles()

func _build_boss_death_particles() -> void:
    # Use depth-tested opaque fragments rather than transparent boss overlays.
    boss_death_particles = CPUParticles3D.new()
    boss_death_particles.name = "BittaranDeathFragments"
    boss_death_particles.emitting = false
    boss_death_particles.one_shot = true
    boss_death_particles.amount = 90
    boss_death_particles.lifetime = 1.15
    boss_death_particles.explosiveness = 1.0
    boss_death_particles.direction = Vector3.UP
    boss_death_particles.spread = 180.0
    boss_death_particles.gravity = Vector3(0.0, -3.0, 0.0)
    boss_death_particles.initial_velocity_min = 2.5
    boss_death_particles.initial_velocity_max = 7.0
    boss_death_particles.scale_amount_min = 0.08
    boss_death_particles.scale_amount_max = 0.22
    var fragment := BoxMesh.new()
    fragment.size = Vector3(0.2, 0.07, 0.14)
    var sparks := StandardMaterial3D.new()
    sparks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sparks.albedo_color = Color("#ff7540")
    sparks.emission_enabled = true
    sparks.emission = Color("#ff4a22")
    sparks.emission_energy_multiplier = 1.8
    fragment.material = sparks
    boss_death_particles.mesh = fragment
    add_child(boss_death_particles)

func _start_boss_death_fx() -> void:
    boss_death_elapsed = 0.0
    if boss_death_particles != null and target_parts != null:
        var body_bounds: AABB = target_parts.call("get_body_hit_aabb")
        boss_death_particles.global_position = body_bounds.get_center()
        boss_death_particles.emitting = true
        boss_death_particles.restart()

func _touch_to_lock_forward(_origin_screen: Vector2) -> Vector2:
    # Both input and HUD use exactly ONE depth-safe projected direction.
    # Projecting elevated HEAD straight to the screen can invert its Y
    # relative to the ground direction when SERA is beyond the lock.
    # Never return Vector2.UP solely because of camera near-plane failure.
    if camera == null or player == null or target == null:
        return boss_last_controller_axis
    var aim: Vector3 = _current_lock_aim_world()
    var actor_center: Vector3 = player.global_position + (
        Vector3.UP * PLAYER_COLLISION_HEIGHT * 0.5)
    var camera_forward: Vector3 = -camera.global_transform.basis.z
    camera_forward.y = 0.0
    if camera_forward.length_squared() > 0.000001:
        camera_forward = camera_forward.normalized()
        var relative: Vector3 = player.global_position - aim
        relative.y = 0.0
        var depth: float = relative.dot(camera_forward)
        if boss_far_side_screen_axis:
            if depth < BOSS_FAR_SIDE_EXIT_METERS:
                boss_far_side_screen_axis = false
        elif depth > BOSS_FAR_SIDE_ENTER_METERS:
            boss_far_side_screen_axis = true
    boss_last_controller_axis = CONTROLLER_AXIS.heading(
        camera, actor_center, aim, boss_last_controller_axis)
    return boss_last_controller_axis


func _update_controller_flick_guide(delta: float) -> void:
    # While an ordinary touch is held, the target can move or the camera
    # can orbit without any finger movement. Refresh the uncommitted
    # controller every render, not only when RUN/BOOST is already moving.
    # Guard, committed combo flicks and STEP retain their captured axis.
    if gesture_active and not guard_active and not bash_flick_candidate \
            and not side_kick_flick_candidate and not step_active \
            and not damage_reaction_active and not _combo_lock_retention_active():
        gesture_screen_forward = _touch_to_lock_forward(pointer_origin)
    super._update_controller_flick_guide(delta)


func _head_depth_excess(base_pose: Quaternion,
        relative_yaw: float) -> float:
    if bittaran_head == null or target_parts == null:
        return 0.0
    bittaran_head.quaternion = (base_pose *
        Quaternion(Vector3.UP, relative_yaw)).normalized()
    var depths: Dictionary = target_parts.call(
        "get_head_leg_penetration_depths")
    var deepest: float = 0.0
    for value in depths.values():
        deepest = maxf(deepest, float(value))
    return maxf(0.0, deepest - HEAD_LEG_ALLOWED_PENETRATION_METERS)


func _head_collision_motion_scale(current_excess: float,
        next_excess: float, delta: float) -> float:
    # Low-pass filtering suppresses one-frame IK/AABB contact noise.
    # Even under persistent deep intrusion, allow >=55% of the requested
    # head rotation: it must keep looking at SERA instead of getting stuck.
    var alpha: float = 1.0 - exp(
        -HEAD_TRACK_COLLISION_FILTER_PER_SECOND * maxf(delta, 0.0))
    head_collision_filtered_excess = lerpf(
        head_collision_filtered_excess, next_excess, alpha)
    # A turn AWAY from an obstruction is always allowed at full speed.
    # Tiny differences below this deadband cannot cause head jitter.
    if next_excess <= current_excess + 0.007:
        return 1.0
    var u: float = clampf(
        (head_collision_filtered_excess - HEAD_TRACK_COLLISION_SOFT_START_METERS)
        / (HEAD_TRACK_COLLISION_SOFT_FULL_METERS
        - HEAD_TRACK_COLLISION_SOFT_START_METERS), 0.0, 1.0)
    var eased: float = u * u * (3.0 - 2.0 * u)
    return lerpf(1.0, HEAD_TRACK_COLLISION_MIN_SPEED_FACTOR, eased)


func _head_smootherstep(t: float) -> float:
    # Quintic: zero first AND second derivatives at each boundary.
    # Unlike the older cubic-squared ramp this has no harsh late surge.
    var x: float = clampf(t, 0.0, 1.0)
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


func _head_post_upright_progress() -> float:
    if bittaran_foot_ik == null:
        return 1.0
    var remaining: float = float(bittaran_foot_ik.get(
        "post_down_idle_remaining"))
    return clampf(1.0 - remaining /
        BittaranFootIK.POST_DOWN_IDLE_SETTLE_SECONDS, 0.0, 1.0)


func _head_recovery_follow_weight() -> float:
    if bittaran_foot_ik == null:
        return 1.0
    if bool(bittaran_foot_ik.call("down_pose_active")):
        var upright: float = float(bittaran_foot_ik.call(
            "standup_pose_fraction"))
        if upright <= HEAD_TRACK_STANDUP_START_FRACTION:
            return 0.0
        var ratio: float = clampf(
            (upright - HEAD_TRACK_STANDUP_START_FRACTION) /
            (1.0 - HEAD_TRACK_STANDUP_START_FRACTION), 0.0, 1.0)
        # Weak S-curve: only 60% authority at the end of physical rise.
        # Smootherstep squared is gentler than the old cubic-squared ramp.
        var eased: float = _head_smootherstep(ratio)
        return HEAD_TRACK_RISE_FOLLOW_WEIGHT * eased * eased
    var remaining: float = float(bittaran_foot_ik.get(
        "post_down_idle_remaining"))
    if remaining > 0.0:
        # No abrupt 60% -> 100% jump on the first fully upright frame.
        return lerpf(HEAD_TRACK_RISE_FOLLOW_WEIGHT, 1.0,
            _head_smootherstep(_head_post_upright_progress()))
    return 1.0


func _head_recovery_turn_speed() -> float:
    if bittaran_foot_ik == null:
        return HEAD_TRACK_DEGREES_PER_SECOND
    if bool(bittaran_foot_ik.call("down_pose_active")):
        return HEAD_TRACK_RECOVERY_DEGREES_PER_SECOND
    if float(bittaran_foot_ik.get("post_down_idle_remaining")) > 0.0:
        # Blend from 48°/s to the normal 140°/s during upright settle,
        # rather than accelerating in a single frame at the boundary.
        return lerpf(HEAD_TRACK_RECOVERY_DEGREES_PER_SECOND,
            HEAD_TRACK_DEGREES_PER_SECOND,
            _head_smootherstep(_head_post_upright_progress()))
    return HEAD_TRACK_DEGREES_PER_SECOND


func _head_knee_look_weight() -> float:
    # The chest turns from the FIRST rise frame, but HEAD follows only
    # after 70% upright. Anticipate the future head sweep gently so the
    # remaining knees can clear its path DURING stand-up instead of
    # waiting for a collision at the last frame.
    var follow: float = _head_recovery_follow_weight()
    if bittaran_foot_ik != null and bool(
            bittaran_foot_ik.call("standup_knee_enabled")):
        var upright: float = float(bittaran_foot_ik.call(
            "standup_pose_fraction"))
        var anticipation: float = (HEAD_TRACK_RISE_FOLLOW_WEIGHT
            * _head_smootherstep(clampf(
            upright / HEAD_TRACK_STANDUP_START_FRACTION, 0.0, 1.0)))
        return maxf(follow, anticipation)
    return follow


func _aim_bittaran_head(delta: float) -> void:
    if bittaran_head == null or player == null or target_hp <= 0:
        return
    # While lying down keep the head on its original bind orientation.
    # Once 70% of the ACTUAL eased rise is complete, softly fade in the
    # ordinary collision-aware look-at without a sudden yaw jump.
    var head_track_weight: float = _head_recovery_follow_weight()
    if bittaran_foot_ik != null and bool(
            bittaran_foot_ik.call("down_pose_active")):
        bittaran_head.quaternion = boss_head_default_rotation
        if head_track_weight <= 0.0:
            boss_head_yaw = 0.0
            head_collision_filtered_excess = 0.0
            return
    if bittaran_foot_ik != null and bool(
            bittaran_foot_ik.call("windup_active")):
        # Let the heavy nose-up throw lead the motion. Smoothly unwind the
        # old yaw so the down phase meets neutral without a rotation snap.
        var t: float = float(bittaran_foot_ik.call("windup_progress"))
        var ease: float = t * t * (3.0 - 2.0 * t)
        boss_head_yaw = boss_head_windup_start_yaw * (1.0 - ease)
        bittaran_head.quaternion = (bittaran_head.quaternion *
            Quaternion(Vector3.UP, boss_head_yaw)).normalized()
        return
    # Each authored animation reinitializes the HEAD joint before this
    # post-IK step. Do not accumulate on its already turned quaternion.
    var base_pose: Quaternion = bittaran_head.quaternion
    var parent_joint: Node3D = bittaran_head.get_parent() as Node3D
    if parent_joint == null:
        return
    var toward: Vector3 = parent_joint.to_local(
        player.global_position + Vector3.UP * 0.9) - bittaran_head.position
    toward.y = 0.0
    if toward.length_squared() < 0.0001:
        return
    # Blockbench head's authored forward is local -Z (the rig has PI yaw).
    var wanted: float = clampf(atan2(-toward.x, -toward.z),
        -deg_to_rad(HEAD_TRACK_MAX_YAW_DEGREES),
        deg_to_rad(HEAD_TRACK_MAX_YAW_DEGREES))
    # HEAD follows SERA freely until penetration exceeds 30cm;
    # persistent deeper contact only damps the angular speed.
    var degrees_per_second: float = _head_recovery_turn_speed()
    var proposed_yaw: float = move_toward(
        boss_head_yaw, wanted * head_track_weight,
        deg_to_rad(degrees_per_second) * maxf(delta, 0.0)
        * head_track_weight)
    # Per-element oriented-mesh penetration depth in WORLD METRES.
    var current_excess: float = _head_depth_excess(base_pose, boss_head_yaw)
    var proposed_excess: float = _head_depth_excess(base_pose, proposed_yaw)
    # Keep diagnostic compatibility with prior runtime fixtures.
    head_neutral_overlap = target_parts.call(
        "get_head_leg_penetration_depths")
    head_neutral_component_overlap = head_neutral_overlap.duplicate()
    var motion_scale: float = _head_collision_motion_scale(
        current_excess, proposed_excess, delta)
    boss_head_yaw = lerpf(boss_head_yaw, proposed_yaw, motion_scale)
    bittaran_head.quaternion = (base_pose *
        Quaternion(Vector3.UP, boss_head_yaw)).normalized()


func _push_player_out_of_downed_body(delta: float) -> void:
    if player == null or target_parts == null or bittaran_foot_ik == null:
        return
    if target_hp <= 0 or not bool(bittaran_foot_ik.call(
            "break_reaction_active")):
        boss_downed_escaping = false
        return
    var body: AABB = target_parts.call("get_body_hit_aabb")
    if player.global_position.y > body.end.y + 0.35:
        # SERA is airborne ABOVE the collapsing body, not underneath it.
        return
    var foot_boxes: Array[AABB] = []
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        foot_boxes.append(target_parts.call("get_part_aabb", id))
    var route: Dictionary = DOWN_CLEARANCE.escape_waypoint(
        player.global_position, body, foot_boxes, PLAYER_COLLISION_RADIUS,
        target.global_transform.basis.z)
    if not bool(route["active"]):
        boss_downed_escaping = false
        return
    boss_downed_escaping = true
    var destination: Vector3 = route["waypoint"]
    var position: Vector3 = player.global_position
    var difference: Vector3 = destination - position
    difference.y = 0.0
    if difference.length_squared() < 0.000001:
        return
    var step: Vector3 = difference.limit_length(
        DOWN_ESCAPE_SPEED_MPS * maxf(delta, 0.0))
    var wanted: Vector3 = position + step
    var safe: Vector3 = DOWN_CLEARANCE.safe_advance(
        position, wanted, foot_boxes, PLAYER_COLLISION_RADIUS)
    # Direct horizontal recovery while the torso overlap is active avoids
    # Godot solving penetration along -Y through the visual-only floor.
    # Foot boxes are treated as 2D barriers and the path follows a side.
    player.global_position = Vector3(safe.x, maxf(position.y, 0.0), safe.z)


func _build_enemy_shooter() -> void:
    # Bittaran's requested initial moveset is movement only, not the
    # unrelated training cube's automatic bullet/ARC attacks.
    super._build_enemy_shooter()
    if enemy_shooter != null:
        enemy_shooter.set("auto_fire_enabled", false)

func _advance_target_motion(delta: float) -> void:
    if target == null or player == null or bittaran_ai == null:
        return
    # The fall and its 0.60s anticipation remain motion-locked, but
    # Turn/Approach animation, root yaw and approaching movement must all
    # begin on the SAME tick that the physical stand-up first starts.
    # IK advances after AI, so preview its next fall/recovery timer tick.
    var rising_now: bool = (bittaran_foot_ik != null
        and bool(bittaran_foot_ik.call("standup_turn_enabled", delta)))
    var recovered: bool = (bittaran_foot_ik == null
        or bool(bittaran_foot_ik.call("locomotion_ready")))
    var recovery_motion_locked: bool = not (rising_now or recovered)
    # A 2nd/3rd broken shin gives main.gd a 3.5s part-break stun.
    # Its timer outlasts this boss's physical stand-up, suppressing
    # Turn/Approach on every subsequent destruction. The Bittaran IK
    # reaction already owns this freeze; while physically rising the
    # generic part-break/stagger timers must not block its AI again.
    var rising_after_break: bool = rising_now and bittaran_foot_ik != null \
        and bool(bittaran_foot_ik.call("down_pose_active"))
    var generic_damage_frozen: bool = (
        (stagger_remaining > 0.0 or part_break_remaining > 0.0)
        and not rising_after_break)
    var frozen: bool = (
        not target_move_enabled or target_hp <= 0
        or generic_damage_frozen
        or down_remaining > 0.0 or training_ko_remaining > 0.0
        or recovery_motion_locked)
    # Use the normal AI branch to choose Turn, Approach, or Idle. Do not
    # substitute the v365 Idle-only recovery yaw controller here.
    var result: Dictionary = bittaran_ai.call("advance", delta,
        target.position, target.rotation.y, player.position, frozen)
    # During physical stand-up the CHEST always turns toward SERA at the
    # stationary 34deg/s turn rate, even when Approach would normally use
    # the slower moving-turn rate. The feet stay world-planted until upright.
    # Approach is still allowed to translate as in v366; rebuild its next
    # root XZ using the corrected chassis yaw and the SAME traveled distance.
    var rising: bool = (bittaran_foot_ik != null
        and bool(bittaran_foot_ik.call("down_pose_active"))
        and rising_now and not frozen)
    if rising:
        var toward: Vector3 = player.global_position - target.global_position
        toward.y = 0.0
        if toward.length_squared() > 0.000001:
            var desired_yaw: float = atan2(toward.x, toward.z)
            var yaw_error: float = wrapf(
                desired_yaw - target.rotation.y, -PI, PI)
            var yaw_limit: float = deg_to_rad(BittaranAI.STATIONARY_TURN_DEG_PER_SEC) * maxf(delta, 0.0)
            var upright_yaw: float = target.rotation.y + clampf(
                yaw_error, -yaw_limit, yaw_limit)
            if str(result["motion"]) == "Approach":
                var step: Vector3 = (result["position"] as Vector3) - target.position
                var distance: float = Vector2(step.x, step.z).length()
                result["position"] = target.position + Vector3(
                    sin(upright_yaw), 0.0, cos(upright_yaw)) * distance
            result["yaw"] = upright_yaw
    target.position = result["position"]
    target.rotation.y = float(result["yaw"])
    bittaran_motion = str(result["motion"])
    if bittaran_rig != null:
        bittaran_rig.call("set_motion", bittaran_motion, delta)
    if target_floor_mark != null:
        target_floor_mark.position = Vector3(
            target.position.x, -0.026, target.position.z)

func _update_bittaran_lock_permissions() -> void:
    if target_parts == null or bittaran_foot_ik == null or target == null:
        return
    var down: bool = target_hp > 0 and bool(
        bittaran_foot_ik.call("break_reaction_active"))
    target_parts.call("set_down_lock_enabled", down)
    # Empty ID means BODY in the inherited AUTO code. Replace that fallback
    # with a shin whenever the boss is standing, even during a held combo.
    if not down and not bool(target_parts.call(
            "can_lock_boss_part", locked_target_part_id)):
        if player != null:
            locked_target_part_id = str(target_parts.call(
                "select_actor_parallel_lines_part",
                player.global_position, target.global_position))
        else:
            locked_target_part_id = "leg_fl"
        auto_lock_pending_part = ""
        auto_lock_pending_elapsed = 0.0
        auto_lock_initialized = true
        _update_target_marker_projection()

func _acquire_stable_camera_part(delta: float,
        current_broken: bool) -> void:
    # In the standing boss only, resolve the left/right overlap with a
    # symmetric lateral deadband. The generic training-room target and
    # downed BODY/HEAD AUTO selection keep their original behavior.
    if target_parts == null or player == null or target == null:
        super._acquire_stable_camera_part(delta, current_broken)
        return
    if bool(target_parts.get("down_lock_enabled")):
        # v359: paired HORIZONTAL body rays strike low BODY/limbs before
        # the raised HEAD volume, so normal AUTO virtually never reaches
        # HEAD despite it being targetable. During actual knockdown make
        # the exposed head the explicit AUTO weakpoint. The preceding
        # 0.60s nose-up windup keeps existing selection, and MANUAL can
        # still select any available head/body/leg part independently.
        if target_hp > 0 and bittaran_foot_ik != null and bool(
                bittaran_foot_ik.call("down_pose_active")) and bool(
                target_parts.call("can_lock_boss_part", "head")):
            locked_target_part_id = "head"
            auto_lock_initialized = true
            auto_lock_pending_part = ""
            auto_lock_pending_elapsed = 0.0
        else:
            super._acquire_stable_camera_part(delta, current_broken)
        return
    locked_target_part_id = str(target_parts.call(
        "select_stable_actor_parallel_lines_part",
        player.global_position, target.global_position, locked_target_part_id))
    auto_lock_initialized = true
    auto_lock_pending_part = ""
    auto_lock_pending_elapsed = 0.0


func _physics_process(delta: float) -> void:
    # Provide the policy *before* base AUTO/MANUAL selection, then refresh
    # after IK finishes its fall/recovery tick. Do not allow a one-frame leak.
    _update_bittaran_lock_permissions()
    super._physics_process(delta)
    # The arena ground is visual (no floor physics). Enemy collision recovery
    # may push an action-locked capsule below zero while the torso descends.
    if player != null and player.position.y < 0.0:
        player.position.y = 0.0
        passive_fall_velocity = 0.0
    _update_bittaran_lock_permissions()

func _finalize_target_pose(delta: float) -> void:
    # main calls this after root motion/bob, before collision and AUTO.
    # Otherwise AUTO samples the reset animation pose, then IK moves the
    # visible shins to different positions later in the same frame.
    if bittaran_foot_ik != null and target != null and target_hp > 0:
        bittaran_foot_ik.call("advance_ik", delta, bittaran_motion)
        if bittaran_head != null and player != null:
            # Reconfigure the planted knees BEFORE the head follows SERA;
            # the final collision-aware head sweep remains a safety net.
            var head_parent: Node3D = bittaran_head.get_parent() as Node3D
            if head_parent != null:
                var toward: Vector3 = head_parent.to_local(
                    player.global_position + Vector3.UP * 0.9) - bittaran_head.position
                toward.y = 0.0
                if toward.length_squared() > 0.0001:
                    var wanted: float = clampf(
                        atan2(-toward.x, -toward.z),
                        -deg_to_rad(HEAD_TRACK_MAX_YAW_DEGREES),
                        deg_to_rad(HEAD_TRACK_MAX_YAW_DEGREES))
                    bittaran_foot_ik.call("steer_knees_for_head", delta,
                        wanted * _head_knee_look_weight())
    _aim_bittaran_head(delta)
    if target_parts != null:
        target_parts.call("sync_bittaran_parts")
    _push_player_out_of_downed_body(delta)
    _update_bittaran_lock_permissions()

func _target_hit_aabb() -> AABB:
    if target_parts != null and target_parts.has_method("get_body_hit_aabb"):
        return target_parts.call("get_body_hit_aabb")
    return super._target_hit_aabb()


func _blade_contact(from_pt: Vector3, to_pt: Vector3) -> Variant:
    # HEAD attack contact follows each visible mesh element's rotated
    # geometry, rather than the empty corners of the old axis-aligned box.
    # Keep the original lock-exclusive rules and sword thickness.
    if locked_target_part_id == "head" and _locked_part_hit_volume_available() \
            and target_parts != null:
        return target_parts.call("get_head_mesh_blade_contact",
            from_pt, to_pt, BLADE_THICKNESS)
    return super._blade_contact(from_pt, to_pt)

func _current_lock_aim_world() -> Vector3:
    if target_parts != null and target != null:
        if not locked_target_part_id.is_empty():
            return target_parts.call("get_part_aim_world", locked_target_part_id)
        if target_parts.has_method("get_body_hit_aabb"):
            var body: AABB = target_parts.call("get_body_hit_aabb")
            return body.get_center()
    return super._current_lock_aim_world()

func _apply_target_part_damage(kind: String, raw_attack: int, raw_break: float,
        weak_stagger: float, extension: float) -> Dictionary:
    var hit_id: String = locked_target_part_id
    var alive_before: bool = target_hp > 0
    var result: Dictionary = super._apply_target_part_damage(
        kind, raw_attack, raw_break, weak_stagger, extension)
    # A shin breaking makes its whole leg skid out; temporarily lower
    # the chassis until the HEAD comes into SERA's melee reach, then restore.
    if bool(result.get("broken", false)) and str(result.get("kind", "")) == "leg":
        if bittaran_foot_ik != null and target_parts != null:
            boss_head_windup_start_yaw = boss_head_yaw
            head_collision_filtered_excess = 0.0
            var head_world: Vector3 = target_parts.call("get_part_aim_world", "head")
            bittaran_foot_ik.call("start_leg_break_slide", hit_id, head_world.y,
                int(result.get("broken_legs", 0)) >= 4)
            # The base training boss starts a generic 1s/3.5s animation
            # freeze on every broken limb. Bittaran's longer physical
            # knockdown replaces it entirely; otherwise 2nd+ breaks
            # remain animation-locked past the first upward recovery.
            part_break_remaining = 0.0
            stagger_remaining = 0.0
            # Weakpoints become lockable in this very hit frame.
            target_parts.call("set_down_lock_enabled", true)
    if alive_before and target_hp == 0:
        target_respawn_remaining = BOSS_DEATH_RESPAWN_SECONDS
        _start_boss_death_fx()
    return result

func _tick_target_respawn(delta: float) -> void:
    # Shared countdown resets BODY and all parts together after combo finishes.
    super._tick_target_respawn(delta)

func _reset_target_after_respawn() -> void:
    # A player KO or boss revival starts a full-health encounter.
    super._reset_target_after_respawn()
    boss_death_elapsed = -1.0
    boss_far_side_screen_axis = false
    boss_last_controller_axis = Vector2.UP
    boss_head_yaw = 0.0
    boss_head_windup_start_yaw = 0.0
    head_neutral_overlap.clear()
    head_neutral_component_overlap.clear()
    head_collision_filtered_excess = 0.0
    boss_downed_escaping = false
    if boss_death_particles != null:
        boss_death_particles.emitting = false
    if bittaran_ai != null:
        bittaran_ai.call("reset")
    if target != null:
        target.rotation.y = 0.0
    if bittaran_foot_ik != null:
        bittaran_foot_ik.call("reset")
    _update_bittaran_lock_permissions()

func _process(delta: float) -> void:
    super._process(delta)
    if boss_death_elapsed >= 0.0 and target_parts != null:
        boss_death_elapsed += maxf(0.0, delta)
        target_parts.call("set_death_visual",
            clampf(boss_death_elapsed / 0.70, 0.0, 1.0))
    if victory_label != null:
        victory_label.visible = target_hp <= 0
