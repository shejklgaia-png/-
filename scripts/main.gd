## v101: Hold-to-guard user-authored pose, lock actions, suppress damage reaction.
## v100: Jump removed from normal touch input; debug-only TEST button/keyboard J.
## v99: Authored jump landing pose, hold 0.60s after landing before standing.
extends Node3D
## v84: Authored 3-stage Swordeffect atlas, exact board placement.
## v83: Three-stage tap melee combo; cancel 2 authored frames after follow-through.
## v82: Close-range side-step camera bound by target-relative player/camera bearing.
## One-finger portrait prototype: drag/hold to move, release to idle.
## v53: restore v51 camera elevation angle; preserve v52 camera screen-height framing; step minimum 2.0m.
## v54: project the target center through the final camera every frame for HUD marker following.
## v55: compact top-only HUD and lower camera focus, preserving the v51/v53 overhead angle.
## v56: slightly increase camera overhead angle while keeping v55 focus, zoom and HUD limits.
## v62: close step speed follows the target box SURFACE, not its center.
## v63: smoothly reduce side-step speed from 10m/s at 5m surface distance to 6m/s at 2m.
## v45 release-only flick classification and v9 held drag remain unchanged.
## v66: isolated, low-frequency enemy shooter with telegraph and projectile collision.
## v68: Blockbench-authored damage reaction on projectile hit.
## v69: Short Damageknock + direction-accurate collision-aware knockback.
## v70: Knockback range 1.20m; Damageknock clip retimed to 0.22s.
## v72: Radial run/boost toggle, with outer-ring input at 1.5x movement speed.
## v73: Full 168px radius is a single RUN disc; BOOST activates only beyond its rim.
## v74: Minimum side-step speed raised from 6m/s to 8m/s; smooth distance falloff retained.
## v77: time-delayed, fading player pose snapshots during step/boost.
## v90: RUN edge snap, 125%/110% BOOST hysteresis, 0.10s confirm and 0.15s acceleration.
## v92: Restore BOOST eligibility after damage without requiring touch release.
## v93: Shared user-authored metal impact sound on both enemy and player damage.
## v94: Supplied sound per actual hit: projectile, melee1/2, melee3; keep metal for areas.
## v91: Enemy attack-mode debug controls and four telegraphed enemy attacks.

const MOVE_SPEED: float = 3.25
const GROUND_MOVE_SPEED_SCALE: float = 1.25  # v148: speed up ground RUN and BOOST; debug airborne control unchanged.
const MOVEMENT_BOOST_MULTIPLIER: float = 1.5
# RUN uses a continuously varying analog vector within a compact 112px radius.
# BOOST remains based on distance from the initial touch point.
# v161: bring BOOST entry 25.2px closer; retain 15% radial hysteresis.
const BOOST_START_RADIUS_RATIO: float = 1.10
const BOOST_EXIT_RADIUS_RATIO: float = 0.95
const BOOST_CONFIRM_SECONDS: float = 0.10
const BOOST_ACCELERATION_SECONDS: float = 0.15
# v159: avoid RUN/WAIT clips interrupting quick BOOST direction changes.
# This is VISUAL ONLY: physics speed and BOOST input thresholds stay unchanged.
const BOOST_POSE_GRACE_SECONDS: float = 0.30
# v158: full 360-degree analog heading on a shorter fixed RUN disc.
# Keep the BOOST thresholds tied to the ORIGINAL 168px touch radius.
const RUN_CONTROL_RADIUS: float = 112.0
const RUN_INPUT_DEADZONE_PIXELS: float = 18.0
# A side step is classified only when the finger is RELEASED.  In particular,
# a long horizontal hold/drag never becomes a step, even if it ends quickly.
const STEP_FLICK_MAX_SECONDS: float = 0.24
const STEP_FLICK_MIN_HORIZONTAL: float = 78.0  # viewport pixels (720px wide virtual screen)
const STEP_FLICK_MIN_PIXELS_PER_SEC: float = 500.0
const STEP_FLICK_MAX_VERTICAL_RATIO: float = 0.42  # abs(dy) / abs(dx)
# Downward release flick is BACKSTEP; v97 upward flick is JUMP only when debug-enabled.
# Preserve the side-step release-only threshold and orthogonal direction guard.
const STEP_FLICK_MIN_VERTICAL: float = 78.0  # Backstep unchanged; jump has a shorter threshold.
const STEP_FLICK_MAX_HORIZONTAL_RATIO: float = 0.42
const STEP_BACK: int = 2  # step_side: -1=left, +1=right, 2=back
# v100: Jump is archived as an optional debug-only action. It is NOT part of
# ordinary touch controls. Turning this flag on restores the v99 up-flick path
# without deleting the authored Jump animation, air actions or landing code.
const JUMP_TOUCH_INPUT_ENABLED: bool = false
const JUMP_FLICK_TAIL_SECONDS: float = 0.20
const JUMP_FLICK_MIN_VERTICAL: float = 50.0  # Reduced from 78px; backstep unchanged.
const JUMP_HEIGHT: float = 1.50  # fixed world-space apex above takeoff plane
const JUMP_FLIGHT_SECONDS: float = 0.80  # 0.000..0.375 authored seconds are retimed over flight
# New authored landing transition 0.375->0.500 runs after floor contact.
const JUMP_LANDING_MOTION_SECONDS: float = 0.125
const JUMP_LANDING_HOLD_SECONDS: float = 0.60  # hold the last landing key before standing
const JUMP_TAKEOFF_HORIZONTAL_FACTOR: float = 0.80  # retain 80% of horizontal speed
const JUMP_AIR_STEER_SPEED_FACTOR: float = 0.30  # ground RUN speed; never boosts in air
const JUMP_GRAVITY: float = 8.0 * JUMP_HEIGHT / (JUMP_FLIGHT_SECONDS * JUMP_FLIGHT_SECONDS)
# Authored clip's fall pose begins at the 0.20833s key of its 0.375s duration.
const JUMP_FALL_CLIP_START: float = 0.20833 / 0.375
const BACK_STEP_DISTANCE: float = 4.0  # meters; side-step distance remains unchanged
# Side steps have a fixed world-space speed, so longer orbits last longer.
# Sample step speed at the start (10m/s far, smooth falloff, 8m/s close);
# keep that speed constant throughout each individual step.
const STEP_ORBIT_ANGLE_DEGREES: float = 35.0
const STEP_MIN_ARC_LENGTH: float = 2.0  # v53: minimum planned step path length in meters
const STEP_MAX_ARC_LENGTH: float = 4.0  # meter cap even at very long target range
const STEP_SPEED: float = 10.0  # normal step speed, m/s
const STEP_CLOSE_SPEED: float = 8.0  # 2m or less from target box surface
const STEP_CLOSE_SURFACE_DISTANCE: float = 2.0  # closest horizontal distance to the target box
const STEP_FALLOFF_START_SURFACE_DISTANCE: float = 5.0  # start slowing when closer than 5m
const STEP_MAX_DURATION: float = 0.40  # seconds: maximum step time
const STEP_MIN_ORBIT_RADIUS: float = 0.10  # tangent is unstable at the exact center
const STEP_CLOSE_ORBIT_MAX_DEGREES: float = 120.0  # prevent circular loops when overlapping target
# v82: At point-blank range the player may orbit around the target rapidly.
# Limit the camera/player ANGULAR SEPARATION around the target, not the total
# camera rotation from a step's starting orientation. The rate cap prevents
# an instantaneous camera whip if the constraint is first exceeded.
const STEP_CLOSE_CAMERA_SURFACE_DISTANCE: float = 1.0  # distance to cube face (meters)
const STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 65.0
const STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES: float = 300.0
const STEP_CLOSE_CAMERA_RECOVERY_SECONDS: float = 0.18
# Attack begins on a short tap. Dragging still uses v9's screen-space controls.
const TAP_MAX_TRAVEL: float = 18.0  # Pixels, measured over the full pointer gesture.
const TAP_MAX_DURATION: float = 0.32  # Seconds; long holds are not attacks.
const GUARD_HOLD_SECONDS: float = TAP_MAX_DURATION  # Hold still for 0.32s to raise shield.
const MELEE_SURFACE_REACH: float = 0.75  # Distance from player center to 2m cube surface.
const MELEE_DASH_SPEED: float = 11.5  # World meters per second; no root-motion double movement.
# Preserve v13 hit timing (confirmed by user).
const TARGET_MAX_HP: int = 100
const STRIKE_DAMAGE = [12, 12, 26]  # Per-stage damage for melee1, Melee2, Melee3.
const STRIKE_ACTIVE_FROM: float = 0.130
const STRIKE_ACTIVE_TO: float = 0.345
const STRIKE_ASSIST_AT: float = 0.170
# The Blockbench clips use 24 fps. Cancel roughly two frames (0.0833 s)
# after each authored follow-through, without shortening standalone recovery.
const STRIKE_CLIPS = ["melee1", "Melee2", "Melee3"]
const STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]
# Each strike has an independent active window and close-range assist.
# melee1 preserves the original hit and impact timing exactly.
const STRIKE_ACTIVE_FROM_TIMES = [0.130, 0.130, 0.290]
const STRIKE_ACTIVE_TO_TIMES = [0.345, 0.345, 0.625]
const STRIKE_ASSIST_TIMES = [0.170, 0.170, 0.350]
# Stage 3 is longer; keep the v82 sword-trail frames in sync with its swing.
const STRIKE_TRAIL_OFFSETS = [0.0, 0.0, 0.210]
const BLADE_THICKNESS: float = 0.14
const HIT_STOP_SECONDS: float = 0.060
const HIT_FLASH_SECONDS: float = 0.145
const TARGET_RESPAWN_SECONDS: float = 1.35
enum CombatState { IDLE, MELEE_APPROACH, DASH, STRIKE }
# v112: Persistent handedness changes RUN animation selection only.
const HANDEDNESS_SETTINGS_FILE: String = "user://sera_settings.cfg"
const DRAG_RADIUS: float = 168.0  # v73: retain v72 outer diameter for the single RUN disc.
const CAMERA_FOLLOW_RATE: float = 1.65
const CAMERA_IDLE_RECENTER_RATE: float = 1.05  # How quickly the player eases toward a clear centered resting position.
const CAMERA_MOVING_YAW_SCALE: float = 0.55  # Softer rotation during drag to preserve left/right movement.
const TARGET_IDLE_GAP_RATIO: float = 0.034  # Resting silhouette gap as a fraction of viewport width.
const SIDE_SWITCH_PIXELS: float = 2.0  # Only used while moving and on release: no 3.5% dead-band.
const MAX_SIDE_SEARCH_ANGLE: float = 1.5  # radians; only the nearest clear orbit angle is used
const MIN_SEPARABLE_DISTANCE: float = 1.9  # closer than silhouettes: orbit cannot solve occlusion
const CAMERA_BASE_RADIUS: float = 16.0
const CAMERA_CLOSE_RADIUS: float = 7.8  # v52: pull the closest zoom back from 6.5m (~20%).
const CAMERA_CLOSE_RANGE: float = 1.5  # Player-target distance where zoom-in is complete.
const CAMERA_FAR_RANGE: float = 12.0  # Restore standard view beyond this separation.
const CAMERA_ELEVATION_RATIO: float = 0.21  # v56: slightly stronger bird's-eye pitch (11.9 degrees vs 7.5 degrees).
const CAMERA_FOCUS_DROP: float = 1.35  # v55: move camera AND focus down 0.45m; preserve the pitch via elevation ratio.
const SCREEN_MARGIN_X: float = 0.02  # Only 2% margin for the core torso; forearms may leave view.
const SCREEN_MARGIN_TOP: float = 0.145  # v55: keep the whole player below the compact top HUD.
const SCREEN_MARGIN_BOTTOM: float = 0.75  # v52: reserve bottom 25% for thumb / on-screen controls.
const CAMERA_BODY_HALF_WIDTH: float = 0.78  # Idle composition silhouette (shoulders/arms)
const CAMERA_SAFE_CORE_HALF_WIDTH: float = 0.38  # Hard edge limit only protects the core torso
const CAMERA_HEAD_HEIGHT: float = 1.85
const TARGET_BASE_HEIGHT: float = 1.53
const TARGET_HALF_SIZE: float = 1.0  # Cube size 2.0 x 2.0 x 2.0m (v8 was 1m)
# Only the target blocks movement. The visual ground is deliberately unbounded.
const PLAYER_COLLISION_LAYER: int = 1
const TARGET_COLLISION_LAYER: int = 2
# Root motion stays y=0; this standing capsule covers the character's torso/legs.
const PLAYER_COLLISION_RADIUS: float = 0.40
const PLAYER_COLLISION_HEIGHT: float = 1.85
const TARGET_FRAME_MARGIN_X: float = 0.025  # Keep all target corners onscreen
const TARGET_FRAME_MARGIN_Y: float = 0.145  # v55: do not frame the target behind the top HUD.
const TARGET_FRAME_BOTTOM: float = 0.75  # v52: reserve the same lower control area for target corners.
const SERA_SCRIPT = preload("res://scripts/sera_rig.gd")
const UI_SCRIPT = preload("res://scripts/touch_overlay.gd")
const SWORD_TRAIL_SCRIPT = preload("res://scripts/sword_trail.gd")
const HIT_BURST_SCRIPT = preload("res://scripts/hit_burst.gd")
const ENEMY_SHOOTER_SCRIPT = preload("res://scripts/enemy_shooter.gd")
const ENEMY_DEBUG_SCRIPT = preload("res://scripts/enemy_debug_ui.gd")
const PROJECTILE_HIT_FLASH_SECONDS: float = 0.22
# Knockback is real CharacterBody3D displacement, not Blockbench root motion.
# A brief ease-out moves up to 1.2 m without passing through the target cube.
const DAMAGE_KNOCKBACK_DISTANCE: float = 1.20  # meters
const DAMAGE_KNOCKBACK_DURATION: float = 0.24  # seconds
# v77: temporal afterimages are world-space pose snapshots, not offset
# overlays of the current rig pose. No background blur or post-process.

var player: CharacterBody3D
var rig: Node3D
var camera: Camera3D
var target: Node3D
var target_collider: StaticBody3D
var enemy_shooter: Node3D
var enemy_attack_pool: Node3D
var enemy_debug_ui: Control
var projectile_hit_overlay: ColorRect
var projectile_hit_flash_remaining: float = 0.0
var damage_reaction_active: bool = false
var guard_active: bool = false
var keyboard_guard_held: bool = false
var damage_knockback_elapsed: float = 0.0
var damage_knockback_direction: Vector3 = Vector3.ZERO
var touch_ui: Control
var state_label: Label
var hud_panel: Panel  # v55: compact header; a single v112 preference button receives touch.
var handedness_button: Button
var left_handed: bool = false
var step_status_label: Label
var step_detail_label: Label
var step_hud_touch: int = -1
var step_hud_mouse_press: bool = false
var current_touch: int = -1
var mouse_down: bool = false
var pointer_origin: Vector2 = Vector2.ZERO
var pointer_location: Vector2 = Vector2.ZERO
# Analog 360-degree input is continuous; no 45-degree quantization.
var direction_input: Vector2 = Vector2.ZERO
var movement_boost_active: bool = false
var boost_confirm_elapsed: float = 0.0
var boost_has_activated_this_gesture: bool = false
var boost_speed_multiplier: float = 1.0
var boost_pose_grace_remaining: float = 0.0
var gesture_active: bool = false
var gesture_suppressed_from_damage: bool = false
var gesture_suppressed_from_landing: bool = false
var gesture_start_ms: int = 0
var gesture_max_travel: float = 0.0
var gesture_start_ground_velocity: Vector3 = Vector3.ZERO
var jump_flick_samples: Array[Dictionary] = []
var jump_active: bool = false
var jump_elapsed: float = 0.0
var jump_horizontal_velocity: Vector3 = Vector3.ZERO
# An aerial step/attack suspends the ascent/descent. Once finished, gravity
# resumes from the actual current height, playing only Jump's falling keys.
var jump_fall_after_action: bool = false
var jump_fall_elapsed: float = 0.0
var jump_fall_start_height: float = 0.0
var jump_fall_duration: float = 0.0
# Landing is a separate grounded, input-locked state. The exact final authored
# key is held 0.60s AFTER the 0.125s landing transition finishes.
var landing_active: bool = false
var landing_elapsed: float = 0.0
var player_floor_mark: Node3D
var step_active: bool = false
var step_elapsed: float = 0.0
var step_duration_current: float = STEP_MIN_ARC_LENGTH / STEP_SPEED
var step_speed_current: float = STEP_SPEED  # snapshotted once on each flick
var step_arc_length: float = 0.0
var step_start_offset: Vector2 = Vector2.ZERO  # Player XZ relative to target.
var step_target_center: Vector2 = Vector2.ZERO
var step_signed_angle: float = 0.0
var step_linear_fallback: bool = false  # only near target center: no circular loop
var step_linear_offset: Vector2 = Vector2.ZERO
var step_side: int = 0  # -1 left / +1 right / STEP_BACK backward
var step_close_camera: bool = false
# Shared across _physics_process and _process. Avoid a cross-function local.
var close_step_camera_this_frame: bool = false
var close_step_camera_recovery_remaining: float = 0.0
var step_traveled_distance: float = 0.0  # Measured, not the intended orbit length.
var step_last_elapsed: float = 0.0
var step_has_last: bool = false
var combat_state: CombatState = CombatState.IDLE
var elapsed: float = 0.0
var camera_yaw: float = 0.0
var camera_radius: float = CAMERA_BASE_RADIUS
var player_screen_side: int = 1  # Last observed player side of the target on screen.
var was_running: bool = false
var floor_stage: Node3D
var blur_last_player_position: Vector3 = Vector3.ZERO
var blur_velocity: Vector3 = Vector3.ZERO
var blur_active_this_physics_frame: bool = false
var blur_step_this_physics_frame: bool = false
# v36: One shared low-cost circular ground shadow for both combatants.
var ground_shadow_mesh: CylinderMesh
var ground_shadow_material: StandardMaterial3D
# v13 strike timing and v9 camera retained; v17 crescent texture and larger sparks.
var target_mesh: MeshInstance3D
var target_material: StandardMaterial3D
var hp_label: Label
var hp_fill: ColorRect
var damage_label: Label
var hit_burst: Node3D
var hit_audio: AudioStreamPlayer  # Combo stages 1+2, on confirmed target hit only.
var melee_finisher_audio: AudioStreamPlayer  # Combo stage 3, confirmed hit only.
var player_hit_audio: AudioStreamPlayer  # v93 metal sound retained for area attacks.
var player_bullet_hit_audio: AudioStreamPlayer  # AIM/LEAD projectile hit only.
var guard_bullet_hit_audio: AudioStreamPlayer  # Guarded AIM/LEAD projectile hit only.
var sword_trail: Node3D
var target_hp: int = TARGET_MAX_HP
var hit_stop_remaining: float = 0.0
var hit_flash_remaining: float = 0.0
var target_respawn_remaining: float = 0.0
var damage_popup_remaining: float = 0.0
var impact_origin: Vector3 = Vector3.ZERO
var strike_index: int = 0  # 0, 1 or 2; only meaningful in STRIKE.
var combo_queued: bool = false  # One buffered tap for the next attack stage.
var strike_did_hit: bool = false
var strike_prev_time: float = 0.0
var strike_prev_blade: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
    _load_handedness_preference()
    _build_world()
    _build_character()
    _build_target()
    _build_enemy_shooter()
    _build_camera()
    _build_overlay()
    _build_hit_effects()
    _build_motion_blur()
    _update_target_marker_projection()  # Initial position before the first rendered frame.

func _load_handedness_preference() -> void:
    var settings := ConfigFile.new()
    if settings.load(HANDEDNESS_SETTINGS_FILE) == OK:
        left_handed = bool(settings.get_value("controls", "left_handed", false))

func _toggle_handedness() -> void:
    left_handed = not left_handed
    if rig != null:
        rig.call("set_run_left_handed", left_handed)
    _refresh_handedness_button()
    var settings := ConfigFile.new()
    settings.load(HANDEDNESS_SETTINGS_FILE)
    settings.set_value("controls", "left_handed", left_handed)
    var save_result: Error = settings.save(HANDEDNESS_SETTINGS_FILE)
    if save_result != OK:
        push_warning("Could not save SERA handedness setting: %d" % save_result)

func _refresh_handedness_button() -> void:
    if handedness_button != null:
        handedness_button.text = "HAND: LEFT" if left_handed else "HAND: RIGHT"

func _build_world() -> void:
    var world := WorldEnvironment.new()
    world.name = "WorldEnvironment"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("131b29")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("bbc9e1")
    env.ambient_light_energy = 0.60
    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.name = "KeyLight"
    sun.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
    sun.light_color = Color("e3ecff")
    sun.light_energy = 1.7
    sun.shadow_enabled = false  # v36: remove real-time cast shadows; use circular ground marks instead
    add_child(sun)

    # The ground is a repeating visual tile, not a physical movement boundary.
    # Snap its origin by one grid interval to avoid visible grid drift.
    floor_stage = Node3D.new()
    floor_stage.name = "ScrollingGround"
    add_child(floor_stage)

    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(160.0, 0.12, 160.0)
    var floor_mat := StandardMaterial3D.new()
    floor_mat.albedo_color = Color("252f3b")
    floor_mat.roughness = 1.0
    var floor_instance := MeshInstance3D.new()
    floor_instance.name = "Floor"
    floor_instance.mesh = floor_mesh
    floor_instance.material_override = floor_mat
    floor_instance.position.y = -0.105
    floor_stage.add_child(floor_instance)

    var grid_mat := StandardMaterial3D.new()
    grid_mat.albedo_color = Color("111821")  # v37: higher-contrast dark grid
    grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for n in range(-80, 81, 4):
        _floor_line(Vector3(float(n), -0.038, 0.0), Vector3(0.032, 0.009, 160.0), grid_mat)
        _floor_line(Vector3(0.0, -0.038, float(n)), Vector3(160.0, 0.009, 0.032), grid_mat)

func _build_motion_blur() -> void:
    # Player-only afterimages. No distant environment blur in v76.
    blur_last_player_position = player.global_position


func _update_motion_blur(delta: float) -> void:
    if rig == null:
        return
    var active: bool = blur_active_this_physics_frame and blur_velocity.length_squared() > 0.16
    # Always tick the temporal pool: no new snapshots while inactive, but
    # previously captured poses continue fading for their remaining lifetime.
    rig.call("update_motion_afterimages", delta, active, blur_step_this_physics_frame)


func _floor_line(center: Vector3, dimensions: Vector3, material: Material) -> void:
    var box := BoxMesh.new()
    box.size = dimensions
    var part := MeshInstance3D.new()
    part.mesh = box
    part.material_override = material
    part.position = center
    floor_stage.add_child(part)

func _build_character() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.collision_layer = PLAYER_COLLISION_LAYER
    player.collision_mask = TARGET_COLLISION_LAYER
    # There is no physics floor yet: motion remains on the original XZ plane.
    player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    player.floor_snap_length = 0.0
    player.safe_margin = 0.01
    add_child(player)
    var player_capsule := CapsuleShape3D.new()
    player_capsule.radius = PLAYER_COLLISION_RADIUS
    player_capsule.height = PLAYER_COLLISION_HEIGHT
    var player_shape := CollisionShape3D.new()
    player_shape.name = "PlayerBodyCollision"
    player_shape.shape = player_capsule
    player_shape.position.y = PLAYER_COLLISION_HEIGHT * 0.5
    player.add_child(player_shape)
    rig = SERA_SCRIPT.new()
    rig.name = "SeraRig"
    rig.position.y = 0.195  # Compensates for -3 BB units in Wait_motion root track
    player.add_child(rig)
    # v97: anchor the ground marker to the world, not the jumping player's Y.
    _add_round_ground_shadow("PlayerFloorMark", self, Vector3(0.0, -0.026, 0.0))
    player_floor_mark = get_node_or_null("PlayerFloorMark") as Node3D

func _build_target() -> void:
    target = Node3D.new()
    target.name = "VirtualTarget"
    target.position = Vector3(0, TARGET_BASE_HEIGHT, -8.0)
    add_child(target)

    var cube := BoxMesh.new()
    cube.size = Vector3.ONE * TARGET_HALF_SIZE * 2.0
    var cube_mat := StandardMaterial3D.new()
    cube_mat.albedo_color = Color("e53935")
    cube_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # v38: directional lighting restores face shading
    cube_mat.metallic = 0.05
    cube_mat.roughness = 0.74
    cube_mat.emission_enabled = true
    cube_mat.emission = Color("a92724")
    cube_mat.emission_energy_multiplier = 0.08  # v38: subtle glow, preserve directional contrast
    var marker := MeshInstance3D.new()
    marker.name = "FloatingBox"
    marker.mesh = cube
    marker.material_override = cube_mat
    marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    target.add_child(marker)
    # A solid target body follows the same transform as the visible 2m cube.
    # Use a box rather than a circle so its faces/corners match the graphics.
    target_collider = StaticBody3D.new()
    target_collider.name = "TargetSolidBody"
    target_collider.collision_layer = TARGET_COLLISION_LAYER
    target_collider.collision_mask = 0  # The player's mask includes this layer.
    target.add_child(target_collider)
    var target_box := BoxShape3D.new()
    target_box.size = Vector3.ONE * TARGET_HALF_SIZE * 2.0
    var target_shape := CollisionShape3D.new()
    target_shape.name = "TargetBoxCollision"
    target_shape.shape = target_box
    target_collider.add_child(target_shape)
    target_mesh = marker
    target_material = cube_mat

    # Target marker stays on the ground even when its cube bobs vertically.
    _add_round_ground_shadow("TargetFloorMark", self, Vector3(target.position.x, -0.026, target.position.z))

func _build_enemy_shooter() -> void:
    # Keep all live enemy bullets/areas isolated so debug-mode switches can
    # remove only these attacks, never scene objects or combat effects.
    enemy_attack_pool = Node3D.new()
    enemy_attack_pool.name = "EnemyAttackPool"
    add_child(enemy_attack_pool)
    enemy_shooter = ENEMY_SHOOTER_SCRIPT.new()
    enemy_shooter.name = "EnemyRangedAI"
    enemy_shooter.set("target_node", target)
    enemy_shooter.set("player_node", player)
    enemy_shooter.set("projectile_parent", enemy_attack_pool)
    enemy_shooter.connect("projectile_hit", Callable(self, "_on_enemy_projectile_hit"))
    add_child(enemy_shooter)

func _on_enemy_projectile_hit(_world_position: Vector3, incoming_direction: Vector3,
        is_bullet: bool) -> void:
    if guard_active:
        # Guarded bullets use their own impact sound, but never
        # triggers the unguarded red damage flash, Damageknock or knockback.
        var block_sound: AudioStreamPlayer = guard_bullet_hit_audio if is_bullet else player_hit_audio
        if is_instance_valid(block_sound) and block_sound.stream != null:
            block_sound.play()
        return
    # Both straight bullets (AIM and LEAD) use the supplied projectile impact.
    # SHOCK and ARC keep v93's metal sound: they are not bullet contacts.
    # The flag is captured per spawned attack and cannot change with debug UI.
    projectile_hit_flash_remaining = PROJECTILE_HIT_FLASH_SECONDS
    if projectile_hit_overlay != null:
        projectile_hit_overlay.visible = true
    var damage_sound: AudioStreamPlayer = player_bullet_hit_audio if is_bullet else player_hit_audio
    # Play even during an ongoing Damageknock; do not restart its animation.
    if is_instance_valid(damage_sound) and damage_sound.stream != null:
        damage_sound.play()
    _begin_damage_reaction(incoming_direction)

func _begin_damage_reaction(incoming_direction: Vector3) -> void:
    # A second projectile can flash the screen but cannot restart an in-progress
    # animation or overwrite its knockback vector (avoids permanent stun).
    if guard_active or damage_reaction_active or rig == null or not bool(rig.get("loading_ok")):
        return
    if step_active:
        _finish_side_step(false)
    if combat_state != CombatState.IDLE:
        _cancel_attack()
    # Cancel attack hit-stop / frozen sword pose before entering damage state.
    hit_stop_remaining = 0.0
    rig.call("set_combat_paused", false)

    # Project the incoming bullet velocity onto the ground. This is more
    # accurate than assuming the player is still on the enemy's centerline.
    var horizontal_push: Vector3 = Vector3(incoming_direction.x, 0.0, incoming_direction.z)
    if horizontal_push.length_squared() < 0.000001:
        horizontal_push = player.global_position - target.global_position
        horizontal_push.y = 0.0
    if horizontal_push.length_squared() < 0.000001:
        horizontal_push = player.global_transform.basis.z
        horizontal_push.y = 0.0
    damage_knockback_direction = horizontal_push.normalized()
    damage_knockback_elapsed = 0.0
    if jump_active:
        _enter_jump_fall()
    if landing_active:
        # Real damage interrupts landing recovery. Damageknock has priority.
        landing_active = false
        landing_elapsed = 0.0
    rig.call("start_damage")
    damage_reaction_active = true
    if gesture_active:
        gesture_suppressed_from_damage = true

func _advance_damage_knockback(delta: float) -> void:
    if not damage_reaction_active or damage_knockback_elapsed >= DAMAGE_KNOCKBACK_DURATION:
        return
    # Quadratic ease-out: maximum displacement on impact, smoothly settles.
    # Step by the difference of cumulative progress so travel is FPS-independent.
    var old_progress: float = clampf(damage_knockback_elapsed / DAMAGE_KNOCKBACK_DURATION, 0.0, 1.0)
    damage_knockback_elapsed = minf(DAMAGE_KNOCKBACK_DURATION, damage_knockback_elapsed + delta)
    var new_progress: float = damage_knockback_elapsed / DAMAGE_KNOCKBACK_DURATION
    var old_eased: float = 1.0 - pow(1.0 - old_progress, 2.0)
    var new_eased: float = 1.0 - pow(1.0 - new_progress, 2.0)
    # The same swept collision routine used by steps slides along the cube.
    _move_player_swept(damage_knockback_direction * (DAMAGE_KNOCKBACK_DISTANCE * (new_eased - old_eased)), true)

func _advance_projectile_hit_overlay(delta: float) -> void:
    if projectile_hit_overlay == null:
        return
    projectile_hit_flash_remaining = maxf(0.0, projectile_hit_flash_remaining - delta)
    var intensity: float = projectile_hit_flash_remaining / PROJECTILE_HIT_FLASH_SECONDS
    projectile_hit_overlay.color = Color(1.0, 0.26, 0.15, 0.13 * intensity)
    projectile_hit_overlay.visible = projectile_hit_flash_remaining > 0.0

func _add_round_ground_shadow(node_name: String, owner: Node3D, local_position: Vector3) -> void:
    # Exactly the same size/color/thickness as v35's target floor circle.
    # The mesh/material are shared to keep the two shadows visually identical.
    if ground_shadow_mesh == null:
        ground_shadow_mesh = CylinderMesh.new()
        ground_shadow_mesh.top_radius = 1.38
        ground_shadow_mesh.bottom_radius = 1.38
        ground_shadow_mesh.height = 0.014
    if ground_shadow_material == null:
        ground_shadow_material = StandardMaterial3D.new()
        ground_shadow_material.albedo_color = Color("202329")  # v37: dark gray for both ground markers
        ground_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var mark := MeshInstance3D.new()
    mark.name = node_name
    mark.mesh = ground_shadow_mesh
    mark.material_override = ground_shadow_material
    mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mark.position = local_position
    if node_name == "PlayerFloorMark":
        mark.scale = Vector3(0.5, 1.0, 0.5)  # v37: half diameter, unchanged target circle
    owner.add_child(mark)

func _build_camera() -> void:
    camera = Camera3D.new()
    camera.name = "DelayedTargetCamera"
    camera.fov = 61.0  # Vertical FOV; keeps player visible in tall portrait
    camera.near = 0.08
    camera.far = 200.0
    add_child(camera)
    camera.current = true
    camera_yaw = 0.0
    camera_radius = CAMERA_BASE_RADIUS
    _place_camera()
    # Begin with an unobstructed composition instead of starting fully aligned.
    var start_delta: Vector2 = Vector2(player.position.x - target.position.x, player.position.z - target.position.z)
    var start_bearing: float = atan2(start_delta.x, start_delta.y)
    camera_yaw = _nearest_clear_yaw(start_bearing, player_screen_side, TARGET_IDLE_GAP_RATIO)
    _place_camera()

func _build_overlay() -> void:
    var layer := CanvasLayer.new()
    layer.name = "HUD"
    add_child(layer)
    touch_ui = UI_SCRIPT.new()
    touch_ui.name = "DragGuide"
    touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(touch_ui)
    touch_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _update_melee_lock_marker()  # Initial state before the first physics frame.

    # Compact read-only console occupies only the top ~12% of a 1280px portrait
    # viewport. Anchors keep the right-side telemetry aligned on other aspect ratios.
    hud_panel = Panel.new()
    hud_panel.name = "CompactCombatHUD"
    hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(hud_panel)
    hud_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    hud_panel.offset_left = 18.0
    hud_panel.offset_right = -18.0
    hud_panel.offset_top = 26.0
    hud_panel.offset_bottom = 150.0
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.055, 0.088, 0.13, 0.91)
    panel_style.border_color = Color(0.19, 0.37, 0.43, 0.82)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(12)
    hud_panel.add_theme_stylebox_override("panel", panel_style)

    var accent_bar := ColorRect.new()
    accent_bar.name = "Accent"
    accent_bar.position = Vector2(13.0, 13.0)
    accent_bar.size = Vector2(3.0, 31.0)
    accent_bar.color = Color("5de4d1")
    accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(accent_bar)

    var heading := Label.new()
    heading.name = "CombatTitle"
    heading.text = "SERA   /   LOCK"
    heading.position = Vector2(27.0, 10.0)
    heading.add_theme_font_size_override("font_size", 20)
    heading.add_theme_color_override("font_color", Color("dceef2"))
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(heading)

    # A compact in-game setting, separate from the drag area and combat UI.
    # Button sits between the combat title and the right-side STEP telemetry.
    handedness_button = Button.new()
    handedness_button.name = "HandednessToggle"
    handedness_button.position = Vector2(226.0, 11.0)
    handedness_button.size = Vector2(176.0, 35.0)
    handedness_button.focus_mode = Control.FOCUS_NONE
    handedness_button.mouse_filter = Control.MOUSE_FILTER_STOP
    handedness_button.add_theme_font_size_override("font_size", 14)
    handedness_button.pressed.connect(_toggle_handedness)
    hud_panel.add_child(handedness_button)
    _refresh_handedness_button()
    if rig != null:
        rig.call("set_run_left_handed", left_handed)

    state_label = Label.new()
    state_label.name = "ActionState"
    state_label.text = "WAIT  |  Wait_motion"
    state_label.position = Vector2(27.0, 43.0)
    state_label.add_theme_font_size_override("font_size", 14)
    state_label.add_theme_color_override("font_color", Color("8fb3c1"))
    state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(state_label)

    hp_label = Label.new()
    hp_label.name = "TargetHpLabel"
    hp_label.position = Vector2(27.0, 73.0)
    hp_label.add_theme_font_size_override("font_size", 14)
    hp_label.add_theme_color_override("font_color", Color("d3e9ed"))
    hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(hp_label)

    var bar_background := ColorRect.new()
    bar_background.name = "TargetHpBackground"
    bar_background.position = Vector2(27.0, 104.0)
    bar_background.size = Vector2(300.0, 7.0)
    bar_background.color = Color("23404a")
    bar_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(bar_background)
    hp_fill = ColorRect.new()
    hp_fill.name = "TargetHpFill"
    hp_fill.position = bar_background.position
    hp_fill.size = bar_background.size
    hp_fill.color = Color("5de4d1")
    hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(hp_fill)

    # Keep the floating hit number out of the fixed HUD, so it still follows
    # world-space impact positions as in v54.
    damage_label = Label.new()
    damage_label.name = "DamagePopup"
    damage_label.text = "12"
    damage_label.add_theme_font_size_override("font_size", 36)
    damage_label.add_theme_color_override("font_color", Color("ffd883"))
    damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    damage_label.visible = false
    layer.add_child(damage_label)
    _refresh_hp_bar()

    step_status_label = Label.new()
    step_status_label.name = "StepStatusLabel"
    hud_panel.add_child(step_status_label)
    step_status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    step_status_label.offset_left = -224.0
    step_status_label.offset_right = -18.0
    step_status_label.offset_top = 14.0
    step_status_label.offset_bottom = 50.0
    step_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    step_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    step_status_label.add_theme_font_size_override("font_size", 16)
    step_status_label.add_theme_color_override("font_color", Color("d5faff"))
    step_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var status_style := StyleBoxFlat.new()
    status_style.bg_color = Color("183a44")
    status_style.border_color = Color("3fabb8")
    status_style.set_border_width_all(1)
    status_style.set_corner_radius_all(7)
    step_status_label.add_theme_stylebox_override("normal", status_style)

    step_detail_label = Label.new()
    step_detail_label.name = "StepModeDetails"
    hud_panel.add_child(step_detail_label)
    step_detail_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    step_detail_label.offset_left = -250.0
    step_detail_label.offset_right = -18.0
    step_detail_label.offset_top = 60.0
    step_detail_label.offset_bottom = 79.0
    step_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    step_detail_label.add_theme_font_size_override("font_size", 14)
    step_detail_label.add_theme_color_override("font_color", Color("a5c5d0"))
    step_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var control_hint := Label.new()
    control_hint.name = "InputHint"
    control_hint.text = "TAP   /   DRAG   /   FLICK"
    hud_panel.add_child(control_hint)
    control_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    control_hint.offset_left = -250.0
    control_hint.offset_right = -18.0
    control_hint.offset_top = 94.0
    control_hint.offset_bottom = 114.0
    control_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    control_hint.add_theme_font_size_override("font_size", 12)
    control_hint.add_theme_color_override("font_color", Color("7195a3"))
    control_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _refresh_step_status_ui()

    # A brief, non-interactive hit tint; no HP or shield logic is implied.
    projectile_hit_overlay = ColorRect.new()
    projectile_hit_overlay.name = "ProjectileHitTint"
    projectile_hit_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    projectile_hit_overlay.color = Color(1.0, 0.26, 0.15, 0.0)
    projectile_hit_overlay.visible = false
    layer.add_child(projectile_hit_overlay)
    projectile_hit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # v91: Touch-enabled but separate from the game's movement/attack gestures.
    # Compact row immediately below the old HUD; no existing HUD is reshaped.
    enemy_debug_ui = ENEMY_DEBUG_SCRIPT.new()
    enemy_debug_ui.name = "EnemyAttackDebug"
    layer.add_child(enemy_debug_ui)
    enemy_debug_ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    enemy_debug_ui.offset_left = 18.0
    enemy_debug_ui.offset_right = -18.0
    enemy_debug_ui.offset_top = 156.0
    enemy_debug_ui.offset_bottom = 233.0
    enemy_debug_ui.connect("attack_selected", Callable(enemy_shooter, "set_attack_type"))
    enemy_debug_ui.connect("fire_requested", Callable(enemy_shooter, "trigger_attack"))
    enemy_debug_ui.connect("auto_fire_changed", Callable(enemy_shooter, "set_auto_fire"))
    enemy_debug_ui.connect("jump_test_requested", Callable(self, "_debug_jump"))

func _update_target_marker_projection() -> void:
    # Camera3D.unproject_position() gives screen coordinates in the viewport.
    # HUD's full-rect Control uses those same pixels; no fixed center offset.
    # Re-read target.global_position: animation / future movement both follow.
    if camera == null or target == null or touch_ui == null:
        return
    var center_world: Vector3 = target.global_position
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or camera.is_position_behind(center_world):
        touch_ui.call("set_target_marker_projection", Vector2.ZERO, false)
        return
    var screen_position: Vector2 = camera.unproject_position(center_world)
    # Hide offscreen instead of pinning the marker to an incorrect position.
    var on_screen: bool = (screen_position.x >= 0.0 and screen_position.x <= viewport_size.x
        and screen_position.y >= 0.0 and screen_position.y <= viewport_size.y)
    touch_ui.call("set_target_marker_projection", screen_position, on_screen)


func _step_speed_for_player_position(pos: Vector3) -> float:
    # v63: Use the target BOX SURFACE (not its center), as introduced in v62.
    # From 5m down to 2m, smoothly interpolate 10m/s -> 8m/s.
    # Smoothstep has a zero slope at both ends, preventing sudden speed jumps.
    var surface_distance: float = _distance_to_cube_surface(pos)
    var falloff: float = clampf(
        (STEP_FALLOFF_START_SURFACE_DISTANCE - surface_distance)
        / (STEP_FALLOFF_START_SURFACE_DISTANCE - STEP_CLOSE_SURFACE_DISTANCE),
        0.0, 1.0)
    var eased: float = falloff * falloff * (3.0 - 2.0 * falloff)
    return lerpf(STEP_SPEED, STEP_CLOSE_SPEED, eased)

func _refresh_step_status_ui() -> void:
    if step_status_label == null or step_detail_label == null:
        return
    # During a step show its fixed speed, even if the target/player move.
    # While idle, show the speed the NEXT flick would use at this distance.
    var display_speed: float = step_speed_current
    if not step_active:
        display_speed = _step_speed_for_player_position(player.position)
    step_status_label.text = "STEP SPEED %.1fm/s" % display_speed
    if step_active:
        step_detail_label.text = "STEP %.2fm planned" % step_arc_length
    elif step_has_last:
        # When a body blocks a step, don't mislabel the planned length as actual.
        step_detail_label.text = "LAST %.2fm  /  %.2fs" % [step_traveled_distance, step_last_elapsed]
    else:
        step_detail_label.text = "SIDE <=0.4s / BACK 4.0m"

func _pointer_on_step_hud(pos: Vector2) -> bool:
    # The compact header is informational only. Do not interpret taps or
    # horizontal swipes originating over it as attacks / side steps.
    return ((hud_panel != null and hud_panel.visible and hud_panel.get_global_rect().has_point(pos))
        or (enemy_debug_ui != null and enemy_debug_ui.visible
            and enemy_debug_ui.get_global_rect().has_point(pos)))

func _build_hit_effects() -> void:
    # v95: All three confirmed combo hits use the same decoded user-provided sound.
    # Separate AudioStreamPlayers preserve overlapping impact tails.
    hit_audio = AudioStreamPlayer.new()
    hit_audio.name = "SwordHitSound"
    hit_audio.stream = load("res://assets/sera_melee_hit_all.wav")
    hit_audio.volume_db = -5.0
    hit_audio.max_polyphony = 4
    add_child(hit_audio)

    melee_finisher_audio = AudioStreamPlayer.new()
    melee_finisher_audio.name = "MeleeFinisherHitSound"
    melee_finisher_audio.stream = load("res://assets/sera_melee_hit_all.wav")
    melee_finisher_audio.volume_db = -5.0
    melee_finisher_audio.max_polyphony = 3
    add_child(melee_finisher_audio)

    player_bullet_hit_audio = AudioStreamPlayer.new()
    player_bullet_hit_audio.name = "PlayerBulletHitSound"
    player_bullet_hit_audio.stream = load("res://assets/sera_player_bullet_hit_v96.wav")
    player_bullet_hit_audio.volume_db = -5.0
    player_bullet_hit_audio.max_polyphony = 3
    add_child(player_bullet_hit_audio)

    guard_bullet_hit_audio = AudioStreamPlayer.new()
    guard_bullet_hit_audio.name = "GuardBulletHitSound"
    guard_bullet_hit_audio.stream = load("res://assets/sera_bullet_hit_short.wav")
    guard_bullet_hit_audio.volume_db = -5.0
    guard_bullet_hit_audio.max_polyphony = 3
    add_child(guard_bullet_hit_audio)

    # Areas are not bullets: preserve v93's metal contact sound for them.
    player_hit_audio = AudioStreamPlayer.new()
    player_hit_audio.name = "PlayerDamageSound"
    player_hit_audio.stream = load("res://assets/metal_damage_hit.wav")
    player_hit_audio.volume_db = -5.0
    player_hit_audio.max_polyphony = 3
    add_child(player_hit_audio)

    # No Sprite3D/black-alpha impact tiles: sparks are depth-tested triangles.
    # The separate sword crescent uses an alpha-masked additive mesh shader.
    hit_burst = HIT_BURST_SCRIPT.new()
    hit_burst.name = "LargeVisibleHitBurst"
    add_child(hit_burst)
    hit_burst.set("view_camera", camera)
    hit_burst.set("target_node", target)

    sword_trail = SWORD_TRAIL_SCRIPT.new()
    sword_trail.name = "CurvedSlashTexture"
    add_child(sword_trail)
    sword_trail.set("view_camera", camera)
    sword_trail.set("target_node", target)
    sword_trail.set("player_node", player)
    sword_trail.set("rig_node", rig)
    sword_trail.call("attach_to_rig", rig)

func _refresh_hp_bar() -> void:
    if hp_label == null:
        return
    hp_label.text = "TARGET   %d / %d HP" % [target_hp, TARGET_MAX_HP] if target_hp > 0 else "TARGET   DOWN / RESTARTING"
    hp_fill.size = Vector2(300.0 * float(target_hp) / float(TARGET_MAX_HP), 7.0)
    hp_fill.color = Color("5de4d1") if target_hp > 40 else Color("ffb85d")

func _clear_strike_tracking() -> void:
    strike_did_hit = false
    strike_prev_time = 0.0
    strike_prev_blade = PackedVector3Array()

func _target_hit_aabb() -> AABB:
    # The visual target is a 2m cube; animation bobbing is included in the AABB.
    var extents := Vector3.ONE * TARGET_HALF_SIZE
    return AABB(target.global_position - extents, extents * 2.0)

func _blade_contact(from_pt: Vector3, to_pt: Vector3) -> Variant:
    # A swept blade point or blade segment against a padded target AABB.
    return _target_hit_aabb().grow(BLADE_THICKNESS).intersects_segment(from_pt, to_pt)

func _check_strike_contact() -> void:
    if combat_state != CombatState.STRIKE or strike_did_hit:
        return
    if hit_stop_remaining > 0.0:
        return
    var strike_t: float = float(rig.call("get_clip_time"))
    var blade: PackedVector3Array = rig.call("get_blade_world_segment")
    if blade.size() != 2:
        return

    # Only evaluate *clipped active* sword motion. In v11 the first sword pose
    # (windup) could bleed into the hit sweep as soon as the window opened.
    # This also works if low FPS skips across the start or end timestamp.
    var contact: Variant = null
    var active_from: float = float(STRIKE_ACTIVE_FROM_TIMES[strike_index])
    var active_to: float = float(STRIKE_ACTIVE_TO_TIMES[strike_index])
    var assist_at: float = float(STRIKE_ASSIST_TIMES[strike_index])
    var interval_begin: float = maxf(active_from, strike_prev_time)
    var interval_end: float = minf(active_to, strike_t)
    if interval_begin <= interval_end and strike_t >= active_from:
        if strike_prev_blade.size() == 2 and strike_t > strike_prev_time + 0.000001:
            var duration: float = strike_t - strike_prev_time
            var begin_alpha: float = clampf((interval_begin - strike_prev_time) / duration, 0.0, 1.0)
            var end_alpha: float = clampf((interval_end - strike_prev_time) / duration, 0.0, 1.0)
            var begin_base: Vector3 = strike_prev_blade[0].lerp(blade[0], begin_alpha)
            var begin_tip: Vector3 = strike_prev_blade[1].lerp(blade[1], begin_alpha)
            var end_base: Vector3 = strike_prev_blade[0].lerp(blade[0], end_alpha)
            var end_tip: Vector3 = strike_prev_blade[1].lerp(blade[1], end_alpha)
            # Inspect the blade at both active endpoints, plus swept root, tip,
            # and midpoint. The pre-0.130s windup is excluded.
            contact = _blade_contact(begin_base, begin_tip)
            if contact == null:
                contact = _blade_contact(end_base, end_tip)
            if contact == null:
                contact = _blade_contact(begin_base, end_base)
            if contact == null:
                contact = _blade_contact(begin_tip, end_tip)
            if contact == null:
                contact = _blade_contact((begin_base + begin_tip) * 0.5,
                    (end_base + end_tip) * 0.5)
        elif strike_t <= active_to:
            # First available sample is already inside the attack window.
            contact = _blade_contact(blade[0], blade[1])
        if contact != null:
            _register_strike_hit((contact as Vector3).clamp(_target_hit_aabb().position, _target_hit_aabb().end))
        elif interval_end >= assist_at and _distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH + 0.08:
            # The preexisting close-range assist is ALSO delayed, so no hit is
            # possible during the backswing even if the target overlaps it.
            var hit_point: Vector3 = Vector3(
                clampf(player.position.x, target.position.x - TARGET_HALF_SIZE, target.position.x + TARGET_HALF_SIZE),
                target.position.y,
                clampf(player.position.z, target.position.z - TARGET_HALF_SIZE, target.position.z + TARGET_HALF_SIZE)
            )
            _register_strike_hit(hit_point)
    strike_prev_time = strike_t
    strike_prev_blade = blade

func _register_strike_hit(world_hit: Vector3) -> void:
    if strike_did_hit:
        return
    strike_did_hit = true
    var hp_before_hit: int = target_hp
    var strike_damage: int = int(STRIKE_DAMAGE[strike_index])
    target_hp = maxi(0, target_hp - strike_damage)  # Hits at 0 HP still play VFX, never go negative.
    hit_stop_remaining = HIT_STOP_SECONDS
    hit_flash_remaining = HIT_FLASH_SECONDS
    damage_popup_remaining = 0.58
    impact_origin = _visible_hit_surface(world_hit)
    rig.call("set_combat_paused", true)
    if hp_before_hit > 0 and target_hp == 0:
        target_respawn_remaining = TARGET_RESPAWN_SECONDS  # Keep the v38 reset; do not rearm at every 0-HP hit.
    _refresh_hp_bar()
    damage_label.text = "%d" % strike_damage
    damage_label.visible = true
    # strike_index is 0/1/2 and this function is only called on a confirmed
    # blade/assist collision, never on attack input or an empty swing.
    var strike_sound: AudioStreamPlayer = melee_finisher_audio if strike_index == 2 else hit_audio
    if is_instance_valid(strike_sound) and strike_sound.stream != null:
        strike_sound.play()
    _spawn_sparks(impact_origin)
    if sword_trail != null:
        sword_trail.call("on_hit", impact_origin)

func _visible_hit_surface(hit: Vector3) -> Vector3:
    # Collision can return an interior point, especially the v13 close-range
    # assist. Keep the burst visible on the camera-facing face of the real cube.
    var visible: Vector3 = Vector3(
        clampf(hit.x, target.global_position.x - TARGET_HALF_SIZE, target.global_position.x + TARGET_HALF_SIZE),
        clampf(hit.y, target.global_position.y - TARGET_HALF_SIZE, target.global_position.y + TARGET_HALF_SIZE),
        clampf(hit.z, target.global_position.z - TARGET_HALF_SIZE, target.global_position.z + TARGET_HALF_SIZE)
    )
    var toward_camera: Vector3 = camera.global_position - target.global_position
    if absf(toward_camera.x) > absf(toward_camera.z):
        visible.x = target.global_position.x + signf(toward_camera.x) * (TARGET_HALF_SIZE + 0.035)
    else:
        visible.z = target.global_position.z + signf(toward_camera.z) * (TARGET_HALF_SIZE + 0.035)
    return visible

func _spawn_sparks(world_hit: Vector3) -> void:
    if hit_burst == null:
        return
    var current_blade: PackedVector3Array = rig.call("get_blade_world_segment")
    var sweep: Vector3 = Vector3.ZERO
    if current_blade.size() == 2 and strike_prev_blade.size() == 2:
        sweep = current_blade[1] - strike_prev_blade[1]
    if sweep.length_squared() < 0.0002 and current_blade.size() == 2:
        # A single-frame assisted hit still uses the ACTUAL blade orientation.
        var blade_axis: Vector3 = current_blade[1] - current_blade[0]
        sweep = blade_axis.cross((target.global_position - player.global_position).normalized())
    hit_burst.call("start_burst", world_hit, sweep)

func _advance_hit_fx(delta: float) -> void:
    # UI and particles continue during the manual 60 ms combat animation pause.
    if hit_flash_remaining > 0.0:
        hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
    if target_material != null:
        var ratio: float = hit_flash_remaining / HIT_FLASH_SECONDS
        # Darken enemy on contact instead of duplicating the sparks' yellow.
        target_material.albedo_color = Color("e53935").lerp(Color("632535"), ratio * 0.78)
        target_material.emission_energy_multiplier = lerpf(0.08, 0.03, ratio)
        target_material.emission = Color("a92724").lerp(Color("6b1727"), ratio)
    if target_mesh != null:
        var bounce: float = hit_flash_remaining / HIT_FLASH_SECONDS
        target_mesh.position.x = sin((1.0 - bounce) * 44.0) * 0.09 * bounce
        target_mesh.rotation_degrees.z = sin((1.0 - bounce) * 22.0) * 6.0 * bounce
    if hit_burst != null:
        hit_burst.call("advance", delta)
    if damage_popup_remaining > 0.0:
        damage_popup_remaining = maxf(0.0, damage_popup_remaining - delta)
        if camera != null:
            var screen_pt: Vector2 = camera.unproject_position(impact_origin + Vector3.UP * 0.28)
            var lift: float = (0.58 - damage_popup_remaining) * 75.0
            damage_label.position = screen_pt - Vector2(26.0, 30.0 + lift)
            damage_label.modulate.a = minf(1.0, damage_popup_remaining / 0.17)
    elif damage_label != null:
        damage_label.visible = false
    if target_respawn_remaining > 0.0:
        target_respawn_remaining = maxf(0.0, target_respawn_remaining - delta)
        if target_respawn_remaining == 0.0:
            target_hp = TARGET_MAX_HP
            _refresh_hp_bar()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if _pointer_on_step_hud(event.position):
                # GUI handles the button event; gameplay owns no such touch.
                step_hud_touch = event.index
                return
            if current_touch < 0:
                current_touch = event.index
                _begin_drag(event.position)
        elif event.index == step_hud_touch:
            step_hud_touch = -1
            return
        elif event.index == current_touch:
            current_touch = -1
            _end_drag(event.position)
    elif event is InputEventScreenDrag:
        if event.index == step_hud_touch:
            return
        if event.index == current_touch:
            _change_drag(event.position)
    elif not OS.has_feature("mobile"):
        # Desktop editor test: drag with left mouse button; HUD tap is isolated.
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                if _pointer_on_step_hud(event.position):
                    step_hud_mouse_press = true
                    return
                mouse_down = true
                _begin_drag(event.position)
            elif step_hud_mouse_press:
                step_hud_mouse_press = false
                return
            elif mouse_down:
                mouse_down = false
                _end_drag(event.position)
        elif event is InputEventMouseMotion and mouse_down and not step_hud_mouse_press:
            _change_drag(event.position)

func _guard_can_start() -> bool:
    return (not guard_active and not damage_reaction_active and not landing_active
        and not jump_active and not step_active and combat_state == CombatState.IDLE
        and rig != null and bool(rig.get("loading_ok")))

func _set_guard(active: bool) -> void:
    if active == guard_active:
        return
    if active:
        if not _guard_can_start():
            return
        guard_active = true
        direction_input = Vector2.ZERO
        player.velocity = Vector3.ZERO
        movement_boost_active = false
        boost_confirm_elapsed = 0.0
        boost_has_activated_this_gesture = false
        boost_speed_multiplier = 1.0
        boost_pose_grace_remaining = 0.0
        if touch_ui != null:
            touch_ui.call("set_movement_boost", false)
            touch_ui.call("set_analog_direction", Vector2.ZERO)
            touch_ui.call("hide_drag")
        rig.call("start_guard")
    else:
        guard_active = false
        if rig != null:
            rig.call("finish_guard")

func _update_guard_hold() -> void:
    # A hold with <18px maximum travel enters Guard on a physics frame.
    # Only a fresh release lowers the shield; dragging during Guard has no
    # movement, attack, flick or boost semantics.
    if guard_active:
        if not keyboard_guard_held and not gesture_active:
            _set_guard(false)
        return
    var touch_held: bool = (gesture_active
        and not gesture_suppressed_from_damage and not gesture_suppressed_from_landing
        and gesture_max_travel <= TAP_MAX_TRAVEL
        and float(Time.get_ticks_msec() - gesture_start_ms) / 1000.0 >= GUARD_HOLD_SECONDS)
    if keyboard_guard_held or touch_held:
        _set_guard(true)

func _begin_drag(pos: Vector2) -> void:
    if gesture_active:
        return
    gesture_active = true
    # New drag/tap takes over immediately: never retain close-step recovery
    # camera mode during a new move, boost, or attack.
    close_step_camera_recovery_remaining = 0.0
    gesture_suppressed_from_damage = damage_reaction_active
    gesture_suppressed_from_landing = landing_active
    gesture_start_ms = Time.get_ticks_msec()
    gesture_max_travel = 0.0
    gesture_start_ground_velocity = Vector3(player.velocity.x, 0.0, player.velocity.z)
    jump_flick_samples.clear()
    _remember_jump_flick_sample(pos)
    pointer_origin = pos
    pointer_location = pos
    direction_input = Vector2.ZERO
    movement_boost_active = false
    boost_confirm_elapsed = 0.0
    boost_has_activated_this_gesture = false
    boost_speed_multiplier = 1.0
    boost_pose_grace_remaining = 0.0
    touch_ui.call("set_movement_boost", false)
    touch_ui.call("set_analog_direction", Vector2.ZERO)
    if not guard_active:
        touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)

func _analog_stick_direction(pos: Vector2) -> Vector2:
    var displacement: Vector2 = pos - pointer_origin
    var distance: float = displacement.length()
    if distance <= RUN_INPUT_DEADZONE_PIXELS:
        return Vector2.ZERO
    # No angular quantization: tiny heading changes remain continuous, and
    # full RUN speed is reached at the shortened 112px rim.
    var strength: float = clampf(
        (distance - RUN_INPUT_DEADZONE_PIXELS) /
        (RUN_CONTROL_RADIUS - RUN_INPUT_DEADZONE_PIXELS), 0.0, 1.0)
    return displacement / distance * strength

func _change_drag(pos: Vector2) -> void:
    if not gesture_active or guard_active:
        return
    pointer_location = pos
    _remember_jump_flick_sample(pos)
    gesture_max_travel = maxf(gesture_max_travel, pos.distance_to(pointer_origin))
    # Fixed origin; continuous 360-degree heading and analog RUN strength.
    direction_input = _analog_stick_direction(pos)
    touch_ui.call("set_analog_direction", direction_input)
    # BOOST continues to use the original, fixed 125%/110% radial thresholds.
    _update_boost_gesture(0.0)
    if gesture_max_travel > TAP_MAX_TRAVEL:
        if step_active and not jump_active:
            _finish_side_step(true)
        if combat_state != CombatState.IDLE:
            _cancel_attack()
    # The compact RUN ring rotates its indicator without moving its anchor.
    touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)

func _update_boost_gesture(delta: float) -> void:
    # Gate BOOST only while the damage reaction is actually in progress.
    # gesture_suppressed_from_damage is deliberately latched until release to
    # prevent a damaged hold from triggering a phantom STEP or tap attack;
    # it must NOT block BOOST after the damage reaction finishes.
    if not gesture_active or guard_active or damage_reaction_active or jump_active or landing_active:
        boost_confirm_elapsed = 0.0
        if movement_boost_active:
            movement_boost_active = false
            touch_ui.call("set_movement_boost", false)
        return
    # RUN rim is 112px, but BOOST stays at the original 168px reference.
    var finger_distance: float = pointer_location.distance_to(pointer_origin)
    if movement_boost_active:
        # Hysteresis: do not flicker between RUN and BOOST at the entry rim.
        if finger_distance < DRAG_RADIUS * BOOST_EXIT_RADIUS_RATIO:
            movement_boost_active = false
            boost_confirm_elapsed = 0.0
            touch_ui.call("set_movement_boost", false)
    elif finger_distance >= DRAG_RADIUS * BOOST_START_RADIUS_RATIO:
        boost_confirm_elapsed += maxf(delta, 0.0)
        if boost_confirm_elapsed >= BOOST_CONFIRM_SECONDS:
            movement_boost_active = true
            boost_has_activated_this_gesture = true
            touch_ui.call("set_movement_boost", true)
    else:
        # Even a very short dip below 125% restarts entry confirmation.
        boost_confirm_elapsed = 0.0

func _end_drag(release_pos: Vector2) -> void:
    if not gesture_active:
        return
    if guard_active:
        # Consume the whole hold, including any movement made before release.
        # Keyboard G may continue Guard after the finger lifts.
        gesture_active = false
        gesture_suppressed_from_damage = false
        gesture_suppressed_from_landing = false
        direction_input = Vector2.ZERO
        movement_boost_active = false
        boost_confirm_elapsed = 0.0
        boost_has_activated_this_gesture = false
        boost_speed_multiplier = 1.0
        boost_pose_grace_remaining = 0.0
        jump_flick_samples.clear()
        touch_ui.call("set_movement_boost", false)
        touch_ui.call("hide_drag")
        if not keyboard_guard_held:
            _set_guard(false)
        return
    # Include release coordinates: some devices coalesce the final drag event.
    pointer_location = release_pos
    _remember_jump_flick_sample(release_pos)
    gesture_max_travel = maxf(gesture_max_travel, release_pos.distance_to(pointer_origin))
    var press_duration: float = float(Time.get_ticks_msec() - gesture_start_ms) / 1000.0
    var was_tap: bool = (gesture_max_travel <= TAP_MAX_TRAVEL
        and press_duration <= TAP_MAX_DURATION)
    # A completed BOOST gesture is never reinterpreted as a release flick;
    # a quick flick BEFORE BOOST confirmation still causes a STEP as before.
    # v100: no normal UP flick launches a jump. The v99 recognizers remain
    # available for a future design revision when the debug flag is enabled.
    var jump_from_initial_flick: bool = JUMP_TOUCH_INPUT_ENABLED \
        and _is_upward_jump_flick(release_pos - pointer_origin, press_duration) \
        and gesture_max_travel <= (release_pos - pointer_origin).length() * 1.20
    var jump_requested: bool = JUMP_TOUCH_INPUT_ENABLED \
        and (jump_from_initial_flick or _classify_recent_upward_flick())
    # Only a deliberate UP flick may exit BOOST into JUMP; existing release
    # gestures may not become sideways or backwards steps after a boost.
    var suppress_flick: bool = boost_has_activated_this_gesture or jump_requested
    var flick_direction: int = 0 if suppress_flick else _classify_step_flick(
        release_pos - pointer_origin, press_duration)
    var takeoff_momentum: Vector3 = gesture_start_ground_velocity if jump_from_initial_flick else Vector3(player.velocity.x, 0.0, player.velocity.z)
    gesture_active = false
    var suppress_release_action: bool = gesture_suppressed_from_damage or gesture_suppressed_from_landing
    gesture_suppressed_from_damage = false
    gesture_suppressed_from_landing = false
    direction_input = Vector2.ZERO
    movement_boost_active = false
    boost_confirm_elapsed = 0.0
    boost_has_activated_this_gesture = false
    boost_speed_multiplier = 1.0
    boost_pose_grace_remaining = 0.0
    jump_flick_samples.clear()
    touch_ui.call("set_movement_boost", false)
    touch_ui.call("hide_drag")
    if damage_reaction_active or landing_active or suppress_release_action:
        return  # A gesture interrupted by damage never queues a step/attack.
    if jump_requested:
        _start_jump(takeoff_momentum)
    elif flick_direction == STEP_BACK:
        _start_back_step()
    elif flick_direction != 0:
        _start_side_step(flick_direction)
    elif was_tap:
        _start_attack()

func _remember_jump_flick_sample(pos: Vector2) -> void:
    var now_ms: int = Time.get_ticks_msec()
    jump_flick_samples.append({"ms": now_ms, "pos": pos})
    # A tail window allows a RUN/BOOST drag to end in a deliberate upward
    # flick without changing the original release-only lateral/back steps.
    while jump_flick_samples.size() > 1 and now_ms - int(jump_flick_samples[0]["ms"]) > int(JUMP_FLICK_TAIL_SECONDS * 1000.0):
        jump_flick_samples.pop_front()
    if jump_flick_samples.size() > 32:
        jump_flick_samples.pop_front()

func _is_upward_jump_flick(displacement: Vector2, seconds: float) -> bool:
    if seconds <= 0.0 or seconds > STEP_FLICK_MAX_SECONDS:
        return false
    var upward: float = -displacement.y
    return upward >= JUMP_FLICK_MIN_VERTICAL \
        and upward / seconds >= STEP_FLICK_MIN_PIXELS_PER_SEC \
        and absf(displacement.x) <= upward * STEP_FLICK_MAX_HORIZONTAL_RATIO

func _classify_recent_upward_flick() -> bool:
    if jump_flick_samples.size() < 2:
        return false
    var first: Dictionary = jump_flick_samples[0]
    var last: Dictionary = jump_flick_samples[jump_flick_samples.size() - 1]
    var duration: float = float(int(last["ms"]) - int(first["ms"])) / 1000.0
    return _is_upward_jump_flick((last["pos"] as Vector2) - (first["pos"] as Vector2), duration)

func _start_jump(inherited_velocity: Vector3) -> void:
    # A second jump is never allowed until the original flight has landed.
    if guard_active or jump_active or landing_active or damage_reaction_active or step_active or combat_state != CombatState.IDLE \
            or rig == null or not bool(rig.get("loading_ok")):
        return
    jump_active = true
    jump_elapsed = 0.0
    jump_fall_after_action = false
    jump_fall_elapsed = 0.0
    jump_fall_start_height = 0.0
    jump_fall_duration = 0.0
    landing_elapsed = 0.0
    jump_horizontal_velocity = Vector3(inherited_velocity.x, 0.0, inherited_velocity.z) * JUMP_TAKEOFF_HORIZONTAL_FACTOR
    # BOOST never modifies airborne control or inherits a held boost gesture.
    movement_boost_active = false
    boost_confirm_elapsed = 0.0
    boost_speed_multiplier = 1.0
    if touch_ui != null:
        touch_ui.call("set_movement_boost", false)
    rig.call("start_jump")
    rig.call("set_jump_progress", 0.0)

func _enter_jump_fall() -> void:
    if not jump_active:
        return
    # Each newly completed aerial action restarts descent from its actual
    # current height, including actions launched during a previous fall.
    jump_fall_after_action = true
    jump_fall_elapsed = 0.0
    jump_fall_start_height = maxf(player.position.y, 0.0)
    jump_fall_duration = maxf(0.05, sqrt(2.0 * jump_fall_start_height / JUMP_GRAVITY))
    # Aerial action takes ownership of XZ displacement. In the following fall
    # only fresh thumb steering (30% RUN) applies; no old pre-action drift.
    jump_horizontal_velocity = Vector3.ZERO

func _advance_jump(delta: float) -> void:
    if not jump_active:
        return
    # Aerial STEP/MELEE uses its existing authored motion at constant altitude.
    # Do not play/replace those clips or finish the jump during an action.
    if (step_active or combat_state != CombatState.IDLE) and not damage_reaction_active:
        player.velocity = Vector3.ZERO
        return
    var y_wanted: float = 0.0
    var clip_progress: float = 0.0
    var vertical_speed: float = 0.0
    var flight_complete: bool = false
    if jump_fall_after_action:
        jump_fall_elapsed = minf(jump_fall_duration, jump_fall_elapsed + maxf(delta, 0.0))
        var fall_ratio: float = clampf(jump_fall_elapsed / jump_fall_duration, 0.0, 1.0)
        # Gravity starts from rest at the action's ending altitude; no pop to
        # the ordinary parabola, and no jump ascent is replayed.
        y_wanted = maxf(0.0, jump_fall_start_height - 0.5 * JUMP_GRAVITY * jump_fall_elapsed * jump_fall_elapsed)
        clip_progress = lerpf(JUMP_FALL_CLIP_START, 1.0, fall_ratio)
        vertical_speed = -JUMP_GRAVITY * jump_fall_elapsed
        flight_complete = jump_fall_elapsed >= jump_fall_duration
    else:
        jump_elapsed = minf(JUMP_FLIGHT_SECONDS, jump_elapsed + maxf(delta, 0.0))
        var progress: float = clampf(jump_elapsed / JUMP_FLIGHT_SECONDS, 0.0, 1.0)
        y_wanted = JUMP_HEIGHT * 4.0 * progress * (1.0 - progress)
        clip_progress = progress
        vertical_speed = 4.0 * JUMP_HEIGHT / JUMP_FLIGHT_SECONDS * (1.0 - 2.0 * progress)
        flight_complete = jump_elapsed >= JUMP_FLIGHT_SECONDS
    var vertical_delta: float = y_wanted - player.position.y
    if absf(vertical_delta) > 0.000001:
        player.move_and_collide(Vector3(0.0, vertical_delta, 0.0))
    # Air-control is additive to launch inertia, capped at 30% of RUN speed.
    # No pose/animation change occurs when the thumb changes direction.
    var steering_velocity: Vector3 = Vector3.ZERO
    if gesture_active and not damage_reaction_active:
        steering_velocity = _screen_drag_to_ground(direction_input) * (MOVE_SPEED * JUMP_AIR_STEER_SPEED_FACTOR)
    var horizontal_velocity: Vector3 = jump_horizontal_velocity + steering_velocity
    if not damage_reaction_active:
        _move_player_swept(horizontal_velocity * delta, true)
    player.velocity = horizontal_velocity + Vector3.UP * vertical_speed
    if rig != null and not damage_reaction_active:
        rig.call("set_jump_progress", clip_progress)
    if flight_complete:
        player.position.y = 0.0
        jump_active = false
        jump_elapsed = 0.0
        jump_horizontal_velocity = Vector3.ZERO
        jump_fall_after_action = false
        jump_fall_elapsed = 0.0
        jump_fall_start_height = 0.0
        jump_fall_duration = 0.0
        player.velocity = Vector3.ZERO
        if not damage_reaction_active and rig != null:
            _begin_landing()

func _begin_landing() -> void:
    # Airborne traversal is over. Keep the authored landing motion in control;
    # no movement, boost, attack, step or second jump before the 0.60s hold ends.
    landing_active = true
    landing_elapsed = 0.0
    player.velocity = Vector3.ZERO
    movement_boost_active = false
    boost_confirm_elapsed = 0.0
    if gesture_active:
        gesture_suppressed_from_landing = true
    if touch_ui != null:
        touch_ui.call("set_movement_boost", false)
    rig.call("start_landing")

func _advance_landing(delta: float) -> void:
    if not landing_active:
        return
    landing_elapsed += maxf(delta, 0.0)
    player.velocity = Vector3.ZERO
    # Advance exactly the NEW authored 0.375->0.500 landing keys, then hold
    # final pose for a full 0.60 seconds with no further animation motion.
    var landing_fraction: float = clampf(landing_elapsed / JUMP_LANDING_MOTION_SECONDS, 0.0, 1.0)
    if rig != null:
        rig.call("set_landing_progress", landing_fraction)
    if landing_elapsed >= JUMP_LANDING_MOTION_SECONDS + JUMP_LANDING_HOLD_SECONDS:
        landing_active = false
        landing_elapsed = 0.0
        if rig != null:
            # Standing up is a blend from the final crouched landing pose,
            # never a replay of the jump's launch animation.
            rig.call("finish_jump", gesture_active and direction_input.length_squared() > 0.000001, false)

func _classify_side_flick(displacement: Vector2, seconds: float) -> int:
    # This check runs on release, NOT on the first fast drag event.  No
    # time-limited hold means normal lateral dragging is ever converted.
    if seconds <= 0.0 or seconds > STEP_FLICK_MAX_SECONDS:
        return 0
    var horizontal: float = absf(displacement.x)
    if horizontal < STEP_FLICK_MIN_HORIZONTAL:
        return 0
    if horizontal / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC:
        return 0
    if absf(displacement.y) > horizontal * STEP_FLICK_MAX_VERTICAL_RATIO:
        return 0
    # A reversal should not count as a flick from the initial touch position.
    if gesture_max_travel > displacement.length() * 1.20:
        return 0
    return 1 if displacement.x > 0.0 else -1

func _classify_step_flick(displacement: Vector2, seconds: float) -> int:
    # Side flick detection is unchanged. Back is DOWN on the screen, then
    # physical travel is away from the locked target (not camera-relative).
    var side: int = _classify_side_flick(displacement, seconds)
    if side != 0:
        return side
    if seconds <= 0.0 or seconds > STEP_FLICK_MAX_SECONDS:
        return 0
    var vertical: float = displacement.y
    if vertical < STEP_FLICK_MIN_VERTICAL:
        return 0
    if vertical / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC:
        return 0
    if absf(displacement.x) > vertical * STEP_FLICK_MAX_HORIZONTAL_RATIO:
        return 0
    if gesture_max_travel > displacement.length() * 1.20:
        return 0
    return STEP_BACK

func _start_back_step() -> void:
    if guard_active or damage_reaction_active or landing_active or rig == null or not bool(rig.get("loading_ok")):
        return
    if combat_state != CombatState.IDLE:
        _cancel_attack()  # Same attack-cancel behavior as left/right steps.
    if step_active:
        _finish_side_step(false)

    # The character looks toward the target. Backward travel follows that
    # facing, independent of camera yaw, and keeps the original y coordinate.
    var away: Vector3 = player.position - target.position
    away.y = 0.0
    if away.length_squared() < 0.000001:
        away = player.global_transform.basis.z
        away.y = 0.0
    away = away.normalized()
    step_start_offset = Vector2(player.position.x - target.position.x,
        player.position.z - target.position.z)
    step_target_center = Vector2(target.position.x, target.position.z)
    step_linear_offset = Vector2(away.x, away.z) * BACK_STEP_DISTANCE
    step_linear_fallback = true  # Reuse collision-swept linear step travel.
    step_signed_angle = 0.0
    step_arc_length = BACK_STEP_DISTANCE
    step_speed_current = _step_speed_for_player_position(player.position)
    # 4m / 8-10m/s = 0.40-0.50s. Side-step 0.40s limit is intentionally unchanged.
    step_duration_current = BACK_STEP_DISTANCE / step_speed_current
    # Unlike side steps, back steps do not orbit the target. Do not engage
    # the point-blank side-step camera constraint for backward movement.
    step_close_camera = false
    close_step_camera_recovery_remaining = 0.0
    if jump_active:
        jump_horizontal_velocity = Vector3.ZERO
    step_active = true
    step_side = STEP_BACK
    step_elapsed = 0.0
    step_traveled_distance = 0.0
    rig.call("start_back_step")
    _refresh_step_status_ui()

func _start_side_step(side: int) -> void:
    if guard_active or damage_reaction_active or landing_active or side == 0 or rig == null or not bool(rig.get("loading_ok")):
        return
    if combat_state != CombatState.IDLE:
        # v45: a flick can cancel an in-progress attack.
        _cancel_attack()
    if step_active:
        _finish_side_step(false)

    # Preserve v47's 35 degree arc at ordinary range. At close range expand
    # the angle so that the planned arc is at least 2.0m, while keeping
    # the same 4m distance ceiling. Keep the target-centered radius constant.
    var radial: Vector2 = Vector2(
        player.position.x - target.position.x,
        player.position.z - target.position.z
    )
    var radius: float = radial.length()
    var camera_right: Vector3 = _screen_drag_to_ground(Vector2.RIGHT).normalized()
    # A tiny radius would require circling the target multiple times to
    # cover 2.0m. Only in this extreme overlap state use a 2.0m tangent
    # translation instead; the player must never spin in place.
    var close_radius_limit: float = (STEP_MIN_ARC_LENGTH
        / deg_to_rad(STEP_CLOSE_ORBIT_MAX_DEGREES))
    step_linear_fallback = radius < close_radius_limit

    # +theta tangent in XZ coordinates is (-z, +x). Choose the sign to match
    # camera-left/right for BOTH the normal orbit and the overlap fallback.
    var orbit_tangent: Vector3 = camera_right
    if radius >= STEP_MIN_ORBIT_RADIUS:
        orbit_tangent = Vector3(-radial.y, 0.0, radial.x).normalized()
    var tangent_side: float = orbit_tangent.dot(camera_right)
    var orbit_sign: float = 1.0 if tangent_side * float(side) >= 0.0 else -1.0

    step_start_offset = radial
    step_target_center = Vector2(target.position.x, target.position.z)
    step_linear_offset = Vector2.ZERO
    # Snapshot the smooth 8-10m/s speed on release, based on BOX SURFACE
    # distance. Orbit geometry still uses center-to-center radius.
    step_speed_current = _step_speed_for_player_position(player.position)
    # Preserve the 0.40s ceiling without accelerating or compressing time.
    var max_path_length: float = minf(STEP_MAX_ARC_LENGTH, step_speed_current * STEP_MAX_DURATION)
    var path_length: float = STEP_MIN_ARC_LENGTH
    if step_linear_fallback:
        step_signed_angle = 0.0
        step_linear_offset = Vector2(orbit_tangent.x, orbit_tangent.z) * (STEP_MIN_ARC_LENGTH * orbit_sign)
    else:
        var angle: float = minf(
            maxf(deg_to_rad(STEP_ORBIT_ANGLE_DEGREES), STEP_MIN_ARC_LENGTH / radius),
            max_path_length / radius)
        path_length = radius * angle
        step_signed_angle = angle * orbit_sign
    step_arc_length = path_length
    # Keep the selected speed for the entire step (do not change mid-orbit).
    # Minimum path length (2m) at 8m/s lasts 0.250s, within the 0.40s cap.
    step_duration_current = path_length / step_speed_current
    # The orbit is measured around the target, not the old absolute camera
    # direction. At point-blank distance its bearing changes quickly.
    step_close_camera = _distance_to_cube_surface(player.position) <= STEP_CLOSE_CAMERA_SURFACE_DISTANCE
    close_step_camera_recovery_remaining = 0.0
    if jump_active:
        jump_horizontal_velocity = Vector3.ZERO
    step_active = true
    step_side = side
    step_elapsed = 0.0
    step_traveled_distance = 0.0
    rig.call("start_side_step", side)
    _refresh_step_status_ui()

func _finish_side_step(resume_moving: bool) -> void:
    if not step_active:
        return
    step_last_elapsed = step_elapsed
    step_has_last = true
    step_active = false
    if step_close_camera:
        # Retain the target-relative guard very briefly after the final
        # physics tick so idle recenter cannot immediately undo it.
        close_step_camera_recovery_remaining = STEP_CLOSE_CAMERA_RECOVERY_SECONDS
    step_close_camera = false
    step_side = 0
    step_elapsed = 0.0
    var resume_fall: bool = jump_active and not damage_reaction_active
    if resume_fall:
        _enter_jump_fall()
    rig.call("finish_side_step", resume_moving, resume_fall)
    _refresh_step_status_ui()

func _advance_side_step(delta: float) -> void:
    if not step_active:
        return
    # Linear path progression preserves the speed selected on step start
    # (smoothly selected from 8-10m/s), including close fallback.
    step_elapsed = minf(step_duration_current, step_elapsed + delta)
    var progress: float = step_elapsed / step_duration_current
    var new_offset: Vector2 = step_start_offset.rotated(step_signed_angle * progress)
    if step_linear_fallback:
        new_offset = step_start_offset + step_linear_offset * progress
    var requested: Vector3 = Vector3(
        step_target_center.x + new_offset.x - player.position.x,
        0.0,
        step_target_center.y + new_offset.y - player.position.z
    )
    var before: Vector3 = player.position
    # Continuous sweep (not teleport): no step frame can pass through the box.
    # Tangential remainder is allowed to slide along the box's sides.
    _move_player_swept(requested, true)
    step_traveled_distance += Vector2(
        player.position.x - before.x, player.position.z - before.z).length()
    # No Y/root-motion changes; preserve preexisting facing/camera pipeline.
    if step_elapsed >= step_duration_current:
        _finish_side_step(gesture_active and direction_input.length_squared() > 0.000001)

func _move_player_swept(motion: Vector3, slide_on_wall: bool) -> void:
    # Used for the curved step and attack dash. move_and_collide() performs
    # continuous motion collision detection, even for large physics deltas.
    # Sliding is intentionally horizontal and never teleports the root.
    var remainder: Vector3 = Vector3(motion.x, 0.0, motion.z)
    var max_attempts: int = 3 if slide_on_wall else 1
    for _attempt in range(max_attempts):
        if remainder.length_squared() <= 0.00000001:
            break
        var collision: KinematicCollision3D = player.move_and_collide(remainder)
        if collision == null:
            break
        if not slide_on_wall:
            break
        remainder = collision.get_remainder().slide(collision.get_normal())
        remainder.y = 0.0

# Explicit debug entry point: retained for future jump/air-combat experiments.
# No movement flick, tap or boost gesture calls this while the flag is false.
func _debug_jump() -> void:
    if player != null:
        _start_jump(Vector3(player.velocity.x, 0.0, player.velocity.z))

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.keycode == KEY_G and not event.echo:
        keyboard_guard_held = event.pressed
        if not keyboard_guard_held and not gesture_active:
            _set_guard(false)
        elif keyboard_guard_held:
            _update_guard_hold()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            _start_attack()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_J:
            _debug_jump()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_C and sword_trail != null:
            sword_trail.call("set_red_palette", not bool(sword_trail.get("use_red_palette")))
            get_viewport().set_input_as_handled()

func _start_attack() -> void:
    if guard_active or damage_reaction_active or landing_active or step_active or rig == null or not rig.get("loading_ok"):
        return
    if combat_state == CombatState.STRIKE:
        # Taps never restart the current attack. Buffer exactly one follow-up;
        # _advance_attack() consumes it at or after the authored cancel point.
        if strike_index < STRIKE_CLIPS.size() - 1:
            combo_queued = true
        return
    # No extra strikes can be queued before the initial melee has landed in
    # STRIKE (during MELEE_APPROACH/DASH), or while a side-step is playing.
    if combat_state != CombatState.IDLE:
        return
    strike_index = 0
    combo_queued = false
    _clear_strike_tracking()
    if sword_trail != null:
        sword_trail.call("stop_swing")
    if jump_active:
        jump_horizontal_velocity = Vector3.ZERO
    combat_state = CombatState.MELEE_APPROACH
    rig.call("start_melee_approach")

func _cancel_attack() -> void:
    if combat_state == CombatState.IDLE:
        return
    combat_state = CombatState.IDLE
    combo_queued = false
    strike_index = 0
    hit_stop_remaining = 0.0
    rig.call("set_combat_paused", false)
    _clear_strike_tracking()
    if sword_trail != null:
        sword_trail.call("stop_swing")
    if jump_active and not damage_reaction_active:
        _enter_jump_fall()
    rig.call("finish_attack", direction_input.length_squared() > 0.000001, jump_active and not damage_reaction_active)

func _update_melee_lock_marker() -> void:
    # Match the *same* distance rule used to stop the melee approach.
    # v39: Reticle distance cue remains active even with 0 HP.
    if touch_ui == null or player == null or target == null:
        return
    var can_melee: bool = _distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH
    touch_ui.call("set_melee_in_range", can_melee)

func _distance_to_cube_surface(pos: Vector3) -> float:
    # 2D point-to-AABB distance; unlike center-to-center, it is accurate
    # near edges/corners of the enlarged target box.
    var dx: float = maxf(absf(pos.x - target.position.x) - TARGET_HALF_SIZE, 0.0)
    var dz: float = maxf(absf(pos.z - target.position.z) - TARGET_HALF_SIZE, 0.0)
    return Vector2(dx, dz).length()

func _start_strike(stage: int = 0) -> void:
    strike_index = clampi(stage, 0, STRIKE_CLIPS.size() - 1)
    combo_queued = false
    _clear_strike_tracking()
    if sword_trail != null:
        sword_trail.call("begin_swing", float(STRIKE_TRAIL_OFFSETS[strike_index]))
    combat_state = CombatState.STRIKE
    rig.call("start_strike", str(STRIKE_CLIPS[strike_index]))

func _advance_attack(delta: float) -> void:
    match combat_state:
        CombatState.MELEE_APPROACH:
            if rig.call("melee_approach_last_key_reached"):
                if _distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH:
                    _start_strike()
                else:
                    rig.call("hold_melee_approach_last_pose")
                    combat_state = CombatState.DASH
        CombatState.DASH:
            if _distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH:
                _start_strike()
                return
            var destination_delta: Vector3 = target.position - player.position
            destination_delta.y = 0.0
            if destination_delta.length_squared() < 0.000001:
                _start_strike()
                return
            var travel: float = minf(MELEE_DASH_SPEED * delta, destination_delta.length())
            var next_position: Vector3 = player.position + destination_delta.normalized() * travel
            if _distance_to_cube_surface(next_position) <= MELEE_SURFACE_REACH:
                # Find first contact with the attack threshold; don't slide
                # past the target if frame rate drops or device lags.
                var low: float = 0.0
                var high: float = 1.0
                for _i in range(16):
                    var mid: float = (low + high) * 0.5
                    if _distance_to_cube_surface(player.position.lerp(next_position, mid)) <= MELEE_SURFACE_REACH:
                        high = mid
                    else:
                        low = mid
                _move_player_swept(player.position.lerp(next_position, high) - player.position, false)
                _start_strike()
            else:
                _move_player_swept(next_position - player.position, false)
        CombatState.STRIKE:
            # The second tap may arrive before or after the cancel frame.
            # In both cases the next strike starts only after that point.
            if (combo_queued and strike_index < STRIKE_CLIPS.size() - 1
                    and float(rig.call("get_clip_time")) >= float(STRIKE_CANCEL_TIMES[strike_index])):
                # Catch a low-FPS hit before switching clips. Respect hit-stop.
                if not strike_did_hit:
                    _check_strike_contact()
                    if hit_stop_remaining > 0.0:
                        return
                _start_strike(strike_index + 1)
                return
            if rig.call("clip_finished", str(STRIKE_CLIPS[strike_index])):
                # If a device skipped the entire active window in a long frame,
                # still evaluate contact once before ending the attack.
                if not strike_did_hit:
                    _check_strike_contact()
                    if hit_stop_remaining > 0.0:
                        return
                combat_state = CombatState.IDLE
                combo_queued = false
                strike_index = 0
                if sword_trail != null:
                    sword_trail.call("stop_swing")
                _clear_strike_tracking()
                if jump_active and not damage_reaction_active:
                    _enter_jump_fall()
                rig.call("finish_attack", false, jump_active and not damage_reaction_active)

func _screen_drag_to_ground(screen_drag: Vector2) -> Vector3:
    # InputEvent positions use screen axes: +X right, +Y down.
    # Camera3D basis.x points to screen-right; -basis.z points forward.
    # Project both into the XZ ground plane so motion never gains height.
    if screen_drag.length_squared() < 0.000001:
        return Vector3.ZERO

    var screen_right: Vector3 = camera.global_transform.basis.x
    screen_right.y = 0.0
    var screen_forward: Vector3 = -camera.global_transform.basis.z
    screen_forward.y = 0.0
    if screen_right.length_squared() < 0.000001 or screen_forward.length_squared() < 0.000001:
        # Defensive fallback if camera is in an invalid or vertical pose.
        return Vector3(screen_drag.x, 0.0, screen_drag.y).limit_length(1.0)

    screen_right = screen_right.normalized()
    screen_forward = screen_forward.normalized()
    # Up on screen has negative Y, hence the minus sign before forward.
    return (screen_right * screen_drag.x - screen_forward * screen_drag.y).limit_length(1.0)


func _physics_process(delta: float) -> void:
    _update_guard_hold()
    # Sample the outer-ring hold independently of touch event frequency.
    _update_boost_gesture(delta)
    # Acceleration/deceleration affect BOOST speed only, not STEP or attack.
    var boost_speed_target: float = MOVEMENT_BOOST_MULTIPLIER if movement_boost_active else 1.0
    boost_speed_multiplier = move_toward(boost_speed_multiplier, boost_speed_target,
        (MOVEMENT_BOOST_MULTIPLIER - 1.0) * delta / BOOST_ACCELERATION_SECONDS)
    # Only the rig pose retains BOOST briefly. This grace is refreshed during
    # active BOOST, then counts down even while the thumb crosses the 18px
    # RUN deadzone; speed, HUD mode and BOOST effects use the real BOOST state.
    # Attacks, steps, guard, damage, jumps and touch release cancel the grace.
    if not gesture_active or guard_active or damage_reaction_active \
            or jump_active or landing_active or step_active \
            or combat_state != CombatState.IDLE:
        boost_pose_grace_remaining = 0.0
    elif movement_boost_active:
        boost_pose_grace_remaining = BOOST_POSE_GRACE_SECONDS
    else:
        boost_pose_grace_remaining = maxf(0.0, boost_pose_grace_remaining - delta)
    # When the training cube is at zero HP, suspend its firing cycle.
    if enemy_shooter != null:
        enemy_shooter.set("can_fire", target_hp > 0)
    # The authored 0.16667s reaction runs while the body moves. Only regain
    # control when BOTH the animation and short physical knockback are done.
    if damage_reaction_active:
        _advance_damage_knockback(delta)
        if damage_knockback_elapsed >= DAMAGE_KNOCKBACK_DURATION and rig != null and bool(rig.call("damage_finished")):
            damage_reaction_active = false
            damage_knockback_direction = Vector3.ZERO
            rig.call("finish_damage", gesture_active and direction_input.length_squared() > 0.000001)
            if jump_active:
                rig.call("resume_jump_fall")
    var running: bool = direction_input.length() > 0.001
    var stepping_this_frame: bool = step_active
    var jumping_this_frame: bool = jump_active
    var landing_this_frame: bool = landing_active
    # Snapshot before _advance_side_step() can finish the step on this frame.
    close_step_camera_this_frame = stepping_this_frame and step_close_camera
    var step_side_this_frame: int = step_side
    if step_active:
        _advance_side_step(delta)
    if jump_active:
        _advance_jump(delta)
    if landing_this_frame:
        # Begin counting only from the first frame AFTER ground contact.
        _advance_landing(delta)
    if combat_state != CombatState.IDLE:
        if running and gesture_max_travel > TAP_MAX_TRAVEL:
            _cancel_attack()
        elif hit_stop_remaining <= 0.0:
            _advance_attack(delta)
    if damage_reaction_active:
        # Freeze player input while physical knockback is applied above;
        # keep collision recovery available even in the damage state.
        player.velocity = Vector3.ZERO
        player.move_and_slide()
    elif jumping_this_frame or landing_this_frame:
        # Flight is handled above; landing locks XZ until the final-pose hold
        # ends. Never run RUN/BOOST movement during landing recovery.
        player.velocity = Vector3.ZERO
    elif combat_state == CombatState.IDLE and not stepping_this_frame:
        # Keep v9 camera-relative input and choose animation relative to the
        # target-facing character, not to the camera or the screen.
        var world_move: Vector3 = _screen_drag_to_ground(direction_input) if running else Vector3.ZERO
        if rig != null:
            var target_forward: Vector3 = Vector3(
                target.position.x - player.position.x, 0.0,
                target.position.z - player.position.z)
            if target_forward.length_squared() < 0.000001:
                target_forward = -player.global_transform.basis.z
            target_forward = target_forward.normalized()
            var local_run_direction: Vector2 = Vector2(
                world_move.dot(target_forward.cross(Vector3.UP)),
                world_move.dot(target_forward))
            # A brief neutral thumb crossing MUST NOT flash WAIT or RUN
            # between two BOOST directions. Rig still receives the latest
            # local heading when RUN input is present; a zero heading keeps
            # the previously displayed BOOST direction until touch resumes.
            var show_boost_pose: bool = (
                movement_boost_active or boost_pose_grace_remaining > 0.0)
            var show_moving_pose: bool = running or (
                show_boost_pose and gesture_active)
            rig.call("set_moving", show_moving_pose, show_boost_pose, local_run_direction)
        if running:
            # v9 behavior: world_move already uses the current camera's ground axes.
            # Analog RUN strength reaches unity at the 112px rim; BOOST changes
            # speed only after the new 184.8px threshold is confirmed.
            player.velocity = world_move * MOVE_SPEED * GROUND_MOVE_SPEED_SCALE * boost_speed_multiplier
            # Drag keeps working along the cube's faces instead of becoming
            # blocked or falling through it. No world X/Z bounds are added.
        else:
            player.velocity = Vector3.ZERO
        player.move_and_slide()
    elif not stepping_this_frame and combat_state != CombatState.DASH:
        # Even with no input, resolve any pre-existing body penetration.
        player.velocity = Vector3.ZERO
        player.move_and_slide()
    # Sample actual collision-resolved displacement, including curved steps.
    # Steps move by move_and_collide(), not by player.velocity.
    if delta > 0.000001:
        blur_velocity = (player.global_position - blur_last_player_position) / delta
    else:
        blur_velocity = Vector3.ZERO
    blur_last_player_position = player.global_position
    if player_floor_mark != null:
        player_floor_mark.position = Vector3(player.position.x, -0.026, player.position.z)
    blur_step_this_physics_frame = stepping_this_frame and not damage_reaction_active
    blur_active_this_physics_frame = (not damage_reaction_active and (
        blur_step_this_physics_frame or (combat_state == CombatState.IDLE
        and movement_boost_active and running)))
    # At the exact target position the look direction has zero length.
    # Keep the last valid facing instead of calling look_at() with itself.
    var aim: Vector3 = Vector3(
        target.position.x - player.position.x,
        0.0,
        target.position.z - player.position.z
    )
    if aim.length_squared() > 0.000001:
        player.look_at(player.global_position + aim, Vector3.UP)
    _update_melee_lock_marker()  # Update after player movement and auto-approach.
    # Update the idle HUD whenever the next step's speed changes by 0.1m/s.
    if not step_active and step_status_label != null:
        var next_speed_label: String = "STEP SPEED %.1fm/s" % _step_speed_for_player_position(player.position)
        if step_status_label.text != next_speed_label:
            _refresh_step_status_ui()
    if floor_stage != null:
        floor_stage.position = Vector3(
            roundf(player.position.x / 4.0) * 4.0,
            0.0,
            roundf(player.position.z / 4.0) * 4.0
        )
    if damage_reaction_active:
        state_label.text = "DAMAGE  |  Damageknock"
    elif guard_active:
        state_label.text = "GUARD  |  Guard"
    elif jumping_this_frame and combat_state == CombatState.IDLE and not stepping_this_frame:
        state_label.text = "AIR FALL  |  Jump" if jump_fall_after_action else "JUMP  |  Jump (1.5m)"
    elif stepping_this_frame:
        if step_side_this_frame == STEP_BACK:
            state_label.text = "STEP BACK  |  Backstep"
        else:
            state_label.text = "STEP RIGHT  |  Step_R" if step_side_this_frame > 0 else "STEP LEFT  |  Step_L"
    else:
        match combat_state:
            CombatState.MELEE_APPROACH:
                state_label.text = "MELEE APPROACH  |  meleeboost"
            CombatState.DASH:
                state_label.text = "MELEE APPROACH  |  hold meleeboost last key"
            CombatState.STRIKE:
                state_label.text = "STRIKE %d/3  |  %s" % [strike_index + 1, str(STRIKE_CLIPS[strike_index])]
            _:
                if running and movement_boost_active:
                    state_label.text = "BOOST  x1.5  |  %s" % str(rig.call("get_boost_dominant_clip"))
                elif boost_pose_grace_remaining > 0.0 and gesture_active:
                    state_label.text = "RUN  |  BOOST POSE HOLD  |  %s" % str(rig.call("get_boost_dominant_clip"))
                elif running:
                    state_label.text = "RUN  x1.0  |  %s" % str(rig.call("get_run_dominant_clip"))
                else:
                    state_label.text = "WAIT  |  Wait_motion"

func _process(delta: float) -> void:
    _advance_projectile_hit_overlay(delta)
    # Rig clip is updated first (process_priority=-1). Sample the actual
    # striking sword BEFORE evaluating a hit, so the visual arc reaches its
    # impact position even on the frame where hit-stop begins.
    var hit_stop_at_frame_start: bool = hit_stop_remaining > 0.0
    if sword_trail != null and combat_state == CombatState.STRIKE and not hit_stop_at_frame_start:
        var blade_for_trail: PackedVector3Array = rig.call("get_blade_world_segment")
        if blade_for_trail.size() == 2:
            sword_trail.call("sample_swing", blade_for_trail[0], blade_for_trail[1],
                float(rig.call("get_clip_time")), delta)
    if hit_stop_at_frame_start:
        hit_stop_remaining = maxf(0.0, hit_stop_remaining - delta)
        if hit_stop_remaining == 0.0:
            rig.call("set_combat_paused", false)
    elif combat_state == CombatState.STRIKE:
        _check_strike_contact()
    if sword_trail != null:
        sword_trail.call("advance", delta, hit_stop_remaining > 0.0)
    _advance_hit_fx(delta)
    if hit_stop_remaining > 0.0:
        _update_target_marker_projection()  # Still track externally moving targets during hit-stop.
        _update_motion_blur(delta)
        return  # Hold target bob and camera for the impact beat.
    elapsed += delta
    target.position.y = TARGET_BASE_HEIGHT + sin(elapsed * 1.4) * 0.07

    var radial: Vector2 = Vector2(
        player.global_position.x - target.global_position.x,
        player.global_position.z - target.global_position.z
    )
    var separation: float = radial.length()
    # Auto-approach is camera movement, not idle recentering.
    var running: bool = (direction_input.length_squared() > 0.000001
        or combat_state == CombatState.DASH or step_active)
    var bearing: float = camera_yaw
    if separation > 0.08:
        bearing = atan2(radial.x, radial.y)

    # When the player approaches the target, dolly IN smoothly (but stop at
    # a wider close-up than v51). Never crop
    # the enlarged target cube: _fit_full_frame() tests all eight corners.
    # At longer distances, retain the original standard composition.
    var easing: float = 1.0 - exp(-CAMERA_FOLLOW_RATE * delta)
    var zoom_ratio: float = clampf(
        (separation - CAMERA_CLOSE_RANGE) / (CAMERA_FAR_RANGE - CAMERA_CLOSE_RANGE),
        0.0, 1.0
    )
    zoom_ratio = zoom_ratio * zoom_ratio * (3.0 - 2.0 * zoom_ratio)
    var preferred_radius: float = lerpf(CAMERA_CLOSE_RADIUS, CAMERA_BASE_RADIUS, zoom_ratio)
    # Keep the camera behind the moving player rather than flying past them.
    preferred_radius = maxf(preferred_radius, separation + 2.0)
    camera_radius = lerpf(camera_radius, preferred_radius, easing * 0.9)
    _place_camera()

    var protect_close_step: bool = (close_step_camera_this_frame
        or (close_step_camera_recovery_remaining > 0.0 and not gesture_active))
    if protect_close_step and separation > 0.08:
        # Restrict the angle between target->camera and target->player.
        # Unlike the v80 start-yaw clamp, this bound follows an orbiting
        # player and cannot strand the camera on the other side of the target.
        # No _enforce_screen_edge() here: use zoom to protect the frame.
        camera_yaw = _close_step_target_relative_yaw(bearing, easing, delta)
        _place_camera()
        _update_side_from_screen()
    elif running:
        # IMPORTANT: during a drag, never force a minimum gap from the target.
        # The character must be allowed to cross the target's screen center
        # and move naturally to EITHER side. Only the outer screen edge is hard.
        camera_yaw = lerp_angle(camera_yaw, bearing, easing * CAMERA_MOVING_YAW_SCALE)
        _place_camera()
        _update_side_from_screen()  # Track the actual side while freely moving.
        _enforce_screen_edge(bearing)
    else:
        # Latch the last actual left/right side when the finger is released.
        # Do not re-evaluate it during idle: doing so can reverse the orbit
        # and make the player snap to the other side of the target.
        if was_running:
            _update_side_from_screen()
        if separation >= MIN_SEPARABLE_DISTANCE:
            # Closest angle to center that still keeps both silhouettes apart.
            # This is the ONLY time automatic target-avoidance turns the camera.
            var idle_yaw: float = _nearest_clear_yaw(bearing, player_screen_side, TARGET_IDLE_GAP_RATIO)
            var idle_easing: float = 1.0 - exp(-CAMERA_IDLE_RECENTER_RATE * delta)
            camera_yaw = lerp_angle(camera_yaw, idle_yaw, idle_easing)
        _place_camera()
        _enforce_screen_edge(bearing)

    # Frame protection applies in BOTH modes, but never enforces the gap
    # during drag. This maintains full left-to-right control.
    _fit_full_frame()
    _place_camera()

    # Do NOT override depth testing or render priority for the target.
    # If the player stands between the camera and the cube, it is naturally occluded.
    was_running = running
    # Always project AFTER the camera's yaw / zoom / framing corrections.
    # This follows both camera movement and a target whose world position changes.
    _update_target_marker_projection()
    _update_motion_blur(delta)
    close_step_camera_recovery_remaining = maxf(
        0.0, close_step_camera_recovery_remaining - delta)


func _close_step_target_relative_yaw(player_bearing: float, easing: float, delta: float) -> float:
    # First calculate the SAME gentle yaw follow used during normal movement.
    var desired_yaw: float = lerp_angle(
        camera_yaw, player_bearing, easing * CAMERA_MOVING_YAW_SCALE)
    # Then restrict this yaw in target-centered polar coordinates. The center
    # of the permitted sector moves with the player's actual target bearing.
    var offset_from_player: float = wrapf(desired_yaw - player_bearing, -PI, PI)
    var max_angle: float = deg_to_rad(STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES)
    var bounded_yaw: float = player_bearing + clampf(offset_from_player, -max_angle, max_angle)
    # If the bearing changes very quickly (or the guard is first activated),
    # limit how much the camera may turn in one frame. No angle teleport.
    var yaw_to_go: float = wrapf(bounded_yaw - camera_yaw, -PI, PI)
    var turn_limit: float = deg_to_rad(STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES) * delta
    return camera_yaw + clampf(yaw_to_go, -turn_limit, turn_limit)


func _update_side_from_screen() -> void:
    var size: Vector2 = get_viewport().get_visible_rect().size
    if size.x <= 0.0:
        return
    var torso: Vector3 = player.global_position + Vector3(0.0, 1.05, 0.0)
    if camera.is_position_behind(torso):
        return
    var offset: float = camera.unproject_position(torso).x - size.x * 0.5
    if offset > SIDE_SWITCH_PIXELS:
        player_screen_side = 1
    elif offset < -SIDE_SWITCH_PIXELS:
        player_screen_side = -1
    # Precisely centered: retain the last side until input makes it unambiguous.


func _signed_screen_gap(side: int) -> float:
    # Project a conservative body silhouette and the enlarged floating 2m box.
    # Using the camera's RIGHT vector works even after orbiting 90+ degrees.
    var view_right: Vector3 = camera.global_transform.basis.x.normalized()
    var torso: Vector3 = player.global_position + Vector3(0.0, 1.05, 0.0)
    var pleft: Vector3 = torso - view_right * CAMERA_BODY_HALF_WIDTH
    var pright: Vector3 = torso + view_right * CAMERA_BODY_HALF_WIDTH
    if camera.is_position_behind(pleft) or camera.is_position_behind(pright):
        return -1.0e7
    var px_min: float = camera.unproject_position(pleft).x
    var px_max: float = camera.unproject_position(pright).x
    # A cube seen diagonally can be wider than 2m on the screen.
    var tx_min: float = INF
    var tx_max: float = -INF
    for dx in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]:
        for dz in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]:
            var corner: Vector3 = target.global_position + Vector3(dx, 0.0, dz)
            if camera.is_position_behind(corner):
                return -1.0e7
            var x: float = camera.unproject_position(corner).x
            tx_min = minf(tx_min, x)
            tx_max = maxf(tx_max, x)
    return px_min - tx_max if side > 0 else tx_min - px_max


func _has_target_clearance(side: int, extra_gap_ratio: float) -> bool:
    var size: Vector2 = get_viewport().get_visible_rect().size
    return _signed_screen_gap(side) >= size.x * extra_gap_ratio


func _nearest_clear_yaw(bearing: float, side: int, gap_ratio: float) -> float:
    # Search from the dead-on angle toward the current side. First safe angle
    # is the closest position to screen center without covering the box.
    var saved_yaw: float = camera_yaw
    var low: float = 0.0
    var high: float = MAX_SIDE_SEARCH_ANGLE
    var found: bool = false
    var previous_angle: float = 0.0
    for step in range(1, 16):
        var angle: float = float(step) * 0.1
        camera_yaw = bearing - float(side) * angle
        _place_camera()
        if _has_target_clearance(side, gap_ratio):
            low = previous_angle
            high = angle
            found = true
            break
        previous_angle = angle
    if found:
        for i in range(13):
            var middle: float = (low + high) * 0.5
            camera_yaw = bearing - float(side) * middle
            _place_camera()
            if _has_target_clearance(side, gap_ratio):
                high = middle
            else:
                low = middle
    # If too close for any orbit to separate the objects, use a modest side
    # bias instead of spinning the camera toward an impossible solution.
    var result: float = bearing - float(side) * (high if found else 0.55)
    camera_yaw = saved_yaw
    _place_camera()
    return result


func _enforce_screen_edge(bearing: float) -> void:
    # Only the outer safe frame is a hard limit while dragging. The target
    # overlap area has no force-field and can be crossed in either direction.
    if _horizontal_safe():
        return
    var old_yaw: float = camera_yaw
    camera_yaw = bearing
    _place_camera()
    if not _horizontal_safe():
        # If angular correction alone cannot fix it, _fit_full_frame zooms out.
        camera_yaw = old_yaw
        _place_camera()
        return
    var low: float = 0.0
    var high: float = 1.0
    for i in range(17):
        var fraction: float = (low + high) * 0.5
        camera_yaw = lerp_angle(old_yaw, bearing, fraction)
        _place_camera()
        if _horizontal_safe():
            high = fraction
        else:
            low = fraction
    camera_yaw = lerp_angle(old_yaw, bearing, high)
    _place_camera()


func _fit_full_frame() -> void:
    if _full_frame_safe():
        return
    var lower_radius: float = camera_radius
    var upper_radius: float = camera_radius
    for i in range(22):
        if _full_frame_safe():
            break
        upper_radius *= 1.35
        camera_radius = upper_radius
        _place_camera()
    if _full_frame_safe():
        for i in range(16):
            var test_radius: float = (lower_radius + upper_radius) * 0.5
            camera_radius = test_radius
            _place_camera()
            if _full_frame_safe():
                upper_radius = test_radius
            else:
                lower_radius = test_radius
        camera_radius = upper_radius
        _place_camera()


func _place_camera() -> void:
    # Look below the target center so both combatants sit in the upper
    # playable portion of the portrait screen. Moving the camera with the
    # lower focus (rather than applying a canvas or HUD offset) preserves
    # world projection for drag, hit effects and screen-edge checks.
    var focus: Vector3 = target.global_position - Vector3(0.0, CAMERA_FOCUS_DROP, 0.0)
    camera.position = focus + Vector3(
        sin(camera_yaw) * camera_radius,
        CAMERA_ELEVATION_RATIO * camera_radius,
        cos(camera_yaw) * camera_radius
    )
    camera.far = maxf(200.0, camera_radius * 3.0)
    camera.look_at(focus, Vector3.UP)


func _horizontal_safe() -> bool:
    var size: Vector2 = get_viewport().get_visible_rect().size
    if size.x <= 0.0:
        return true
    var right: Vector3 = camera.global_transform.basis.x.normalized()
    var torso: Vector3 = player.global_position + Vector3(0.0, 1.05, 0.0)
    for x_offset in [-CAMERA_SAFE_CORE_HALF_WIDTH, 0.0, CAMERA_SAFE_CORE_HALF_WIDTH]:
        var point: Vector3 = torso + right * x_offset
        if camera.is_position_behind(point):
            return false
        var screen: Vector2 = camera.unproject_position(point)
        if screen.x < size.x * SCREEN_MARGIN_X or screen.x > size.x * (1.0 - SCREEN_MARGIN_X):
            return false
    return true


func _target_fully_in_frame() -> bool:
    # Project all eight corners, not only the target center. On a portrait
    # screen, rotating a large cube can otherwise crop its left/right edges.
    var size: Vector2 = get_viewport().get_visible_rect().size
    if size.x <= 0.0 or size.y <= 0.0:
        return true
    for dx in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]:
        for dy in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]:
            for dz in [-TARGET_HALF_SIZE, TARGET_HALF_SIZE]:
                var world_corner: Vector3 = target.global_position + Vector3(dx, dy, dz)
                if camera.is_position_behind(world_corner):
                    return false
                var projected: Vector2 = camera.unproject_position(world_corner)
                if projected.x < size.x * TARGET_FRAME_MARGIN_X:
                    return false
                if projected.x > size.x * (1.0 - TARGET_FRAME_MARGIN_X):
                    return false
                if projected.y < size.y * TARGET_FRAME_MARGIN_Y:
                    return false
                if projected.y > size.y * TARGET_FRAME_BOTTOM:
                    return false
    return true


func _full_frame_safe() -> bool:
    if not _horizontal_safe() or not _target_fully_in_frame():
        return false
    var size: Vector2 = get_viewport().get_visible_rect().size
    if size.y <= 0.0:
        return true
    var top: Vector3 = player.global_position + Vector3(0.0, CAMERA_HEAD_HEIGHT, 0.0)
    var bottom: Vector3 = player.global_position + Vector3(0.0, 0.08, 0.0)
    if camera.is_position_behind(top) or camera.is_position_behind(bottom):
        return false
    var upper_screen: Vector2 = camera.unproject_position(top)
    var lower_screen: Vector2 = camera.unproject_position(bottom)
    return upper_screen.y >= size.y * SCREEN_MARGIN_TOP and lower_screen.y <= size.y * SCREEN_MARGIN_BOTTOM
