extends "res://scripts/main.gd"
## Dedicated Bittaran battle. Reuse proven SERA controls/combat/camera/HP,
## but replace the red training dummy with the authored quadruped.
const BittaranRig = preload("res://scripts/bittaran_rig.gd")
const BittaranAI = preload("res://scripts/bittaran_ai.gd")
const BittaranFootIK = preload("res://scripts/bittaran_foot_ik.gd")
const BittaranParts = preload("res://scripts/bittaran_parts.gd")
const DOWN_CLEARANCE = preload("res://scripts/bittaran_down_clearance.gd")
const CONTROLLER_AXIS = preload("res://scripts/bittaran_controller_axis.gd")
const HEAD_SUPPORT = preload("res://scripts/bittaran_head_support.gd")
const NAME_TEXT: String = "BITTARAN  /  ビットタラン"
const BOSS_WORLD_SCALE: float = 2.0
const BOSS_DEATH_RESPAWN_SECONDS: float = 3.0
const BOSS_FAR_SIDE_ENTER_METERS: float = 0.65
const BOSS_FAR_SIDE_EXIT_METERS: float = -0.25
const DOWN_ESCAPE_SPEED_MPS: float = 15.0
const HEAD_TRACK_MAX_YAW_DEGREES: float = 48.0
const HEAD_TRACK_DEGREES_PER_SECOND: float = 140.0
const HEAD_LEG_CLEARANCE_METERS: float = 0.05
const HEAD_LEG_BASELINE_AABB_TOLERANCE_M3: float = 0.035

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
var boss_downed_escaping: bool = false
var boss_head_supported_leg: String = ""

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


func _head_leg_overlap_by_id(base_pose: Quaternion,
        relative_yaw: float) -> Dictionary:
    # Axis-aligned bounds include empty corners at the authored neck/hip
    # junction. Permit the original bind-pose overlap, but never let a turn
    # substantially INCREASE penetration into a currently posed leg.
    var overlaps: Dictionary = {}
    if bittaran_head == null or target_parts == null:
        return overlaps
    bittaran_head.quaternion = (base_pose *
        Quaternion(Vector3.UP, relative_yaw)).normalized()
    var tip: AABB = (target_parts.call(
        "get_head_swing_aabb") as AABB).grow(HEAD_LEG_CLEARANCE_METERS)
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        var leg: AABB = target_parts.call("get_leg_visual_aabb", id)
        var volume: float = 0.0
        if leg.has_volume() and tip.intersects(leg):
            volume = tip.intersection(leg).get_volume()
        overlaps[id] = volume
    return overlaps


func _head_collides_with_leg(base_pose: Quaternion,
        relative_yaw: float, resting: Dictionary) -> bool:
    var overlaps: Dictionary = _head_leg_overlap_by_id(base_pose, relative_yaw)
    for id in overlaps:
        if float(overlaps[id]) > float(resting.get(id, 0.0))                 + HEAD_LEG_BASELINE_AABB_TOLERANCE_M3:
            return true
    return false


func _aim_bittaran_head(delta: float) -> void:
    if bittaran_head == null or player == null or target_hp <= 0:
        return
    if bittaran_foot_ik != null and bool(
            bittaran_foot_ik.call("down_pose_active")):
        # The 0.6-second throw has finished. Down and recovery must use the
        # ORIGINAL head joint rotation, not the standing player-facing yaw.
        boss_head_yaw = 0.0
        bittaran_head.quaternion = boss_head_default_rotation
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
    # Continuously check ACTUAL posed upper legs, shins and feet against
    # the proposed head swing, stopping at the last collision-free angle.
    head_neutral_overlap = _head_leg_overlap_by_id(base_pose, 0.0)
    var feasible: float = 0.0
    for step in range(1, 13):
        var candidate: float = wanted * float(step) / 12.0
        if _head_collides_with_leg(base_pose, candidate, head_neutral_overlap):
            break
        feasible = candidate
    # Restore and smoothly turn in local yaw; chassis down pitch remains.
    boss_head_yaw = move_toward(boss_head_yaw, feasible,
        deg_to_rad(HEAD_TRACK_DEGREES_PER_SECOND) * maxf(delta, 0.0))
    if _head_collides_with_leg(base_pose, boss_head_yaw, head_neutral_overlap):
        # A moving foot can enter the old heading. Resolve this immediately
        # instead of allowing a collision during a smooth turn.
        boss_head_yaw = feasible
    bittaran_head.quaternion = (base_pose *
        Quaternion(Vector3.UP, boss_head_yaw)).normalized()


## Resolve the head AFTER final leg IK and the down-pose neutral head
## quaternion have been applied, then replant the four feet in the same tick.
## Mesh AABBs for each real upper/lower/toe piece replace the broad shin
## lock areas, which are deliberately enlarged and must never block HEAD.
func _resolve_downed_head_leg_support() -> void:
    if target_parts == null or bittaran_foot_ik == null or target_hp <= 0 \
            or not bool(bittaran_foot_ik.call("down_pose_active")):
        boss_head_supported_leg = ""
        if target_parts != null:
            target_parts.call("set_head_support_leg", "")
        return
    var boxes: Dictionary = {}
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        boxes[id] = target_parts.call("get_leg_support_mesh_boxes", id)
    var nose: AABB = target_parts.call("get_head_swing_aabb")
    var hit: Dictionary = HEAD_SUPPORT.find_contact(
        nose, boxes, boss_head_supported_leg)
    var supported: String = str(hit["leg_id"])
    # One penetration correction may slightly shift articulated elbows.
    # Re-sample the real mesh contacts after IK and apply a second small
    # correction, with no additional advancement of fall/animation time.
    for correction_pass in range(2):
        if supported.is_empty():
            break
        var penetration: float = float(hit["penetration"])
        if penetration <= 0.0001:
            break
        var raised: float = float(bittaran_foot_ik.call(
            "apply_head_leg_support_lift", penetration))
        if raised <= 0.00001:
            break
        nose = target_parts.call("get_head_swing_aabb")
        for id in boxes:
            boxes[id] = target_parts.call("get_leg_support_mesh_boxes", id)
        hit = HEAD_SUPPORT.find_contact(nose, boxes, supported)
        if str(hit["leg_id"]).is_empty():
            break
        supported = str(hit["leg_id"])
    boss_head_supported_leg = supported
    target_parts.call("set_head_support_leg", supported)


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
    var frozen: bool = (
        not target_move_enabled or target_hp <= 0
        or stagger_remaining > 0.0 or part_break_remaining > 0.0
        or down_remaining > 0.0 or training_ko_remaining > 0.0)
    var result: Dictionary = bittaran_ai.call("advance", delta,
        target.position, target.rotation.y, player.position, frozen)
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
    _aim_bittaran_head(delta)
    _resolve_downed_head_leg_support()
    if target_parts != null:
        target_parts.call("sync_bittaran_parts")
    _push_player_out_of_downed_body(delta)
    _update_bittaran_lock_permissions()

func _target_hit_aabb() -> AABB:
    if target_parts != null and target_parts.has_method("get_body_hit_aabb"):
        return target_parts.call("get_body_hit_aabb")
    return super._target_hit_aabb()

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
            var head_world: Vector3 = target_parts.call("get_part_aim_world", "head")
            bittaran_foot_ik.call("start_leg_break_slide", hit_id, head_world.y,
                int(result.get("broken_legs", 0)) >= 4)
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
    boss_downed_escaping = false
    boss_head_supported_leg = ""
    if target_parts != null:
        target_parts.call("set_head_support_leg", "")
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
