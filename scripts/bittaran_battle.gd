extends "res://scripts/main.gd"
## Dedicated Bittaran battle. Reuse proven SERA controls/combat/camera/HP,
## but replace the red training dummy with the authored quadruped.
const BittaranRig = preload("res://scripts/bittaran_rig.gd")
const BittaranAI = preload("res://scripts/bittaran_ai.gd")
const BittaranFootIK = preload("res://scripts/bittaran_foot_ik.gd")
const BittaranParts = preload("res://scripts/bittaran_parts.gd")
const NAME_TEXT: String = "BITTARAN  /  ビットタラン"
const BOSS_WORLD_SCALE: float = 2.0
const BOSS_DEATH_RESPAWN_SECONDS: float = 3.0
const BOSS_FAR_SIDE_ENTER_METERS: float = 0.65
const BOSS_FAR_SIDE_EXIT_METERS: float = -0.25

var bittaran_rig: Node3D
var bittaran_ai: RefCounted
var bittaran_foot_ik: RefCounted
var bittaran_motion: String = "Idle"
var boss_name_label: Label
var victory_label: Label
var boss_death_particles: CPUParticles3D
var boss_death_elapsed: float = -1.0
var boss_far_side_screen_axis: bool = false

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

func _touch_to_lock_forward(origin_screen: Vector2) -> Vector2:
    # Behind the locked boss, screen-UP remains front for combo flicks.
    # Ordinary STEP displacement is screen-relative and unchanged.
    if camera == null or player == null or target == null:
        return super._touch_to_lock_forward(origin_screen)
    var camera_forward: Vector3 = -camera.global_transform.basis.z
    camera_forward.y = 0.0
    if camera_forward.length_squared() > 0.000001:
        camera_forward = camera_forward.normalized()
        var to_player: Vector3 = player.global_position - _current_lock_aim_world()
        to_player.y = 0.0
        var depth: float = to_player.dot(camera_forward)
        if boss_far_side_screen_axis:
            if depth < BOSS_FAR_SIDE_EXIT_METERS:
                boss_far_side_screen_axis = false
        elif depth > BOSS_FAR_SIDE_ENTER_METERS:
            boss_far_side_screen_axis = true
    if boss_far_side_screen_axis:
        return Vector2.UP
    return super._touch_to_lock_forward(origin_screen)

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

func _physics_process(delta: float) -> void:
    # Provide the policy *before* base AUTO/MANUAL selection, then refresh
    # after IK finishes its fall/recovery tick. Do not allow a one-frame leak.
    _update_bittaran_lock_permissions()
    super._physics_process(delta)
    _update_bittaran_lock_permissions()

func _finalize_target_pose(delta: float) -> void:
    # main calls this after root motion/bob, before collision and AUTO.
    # Otherwise AUTO samples the reset animation pose, then IK moves the
    # visible shins to different positions later in the same frame.
    if bittaran_foot_ik != null and target != null and target_hp > 0:
        bittaran_foot_ik.call("advance_ik", delta, bittaran_motion)
    if target_parts != null:
        target_parts.call("sync_bittaran_parts")
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
