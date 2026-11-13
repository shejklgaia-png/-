## v101: Hold-to-guard user-authored pose, lock actions, suppress damage reaction.
## v100: Jump removed from normal touch input; debug-only TEST button/keyboard J.
## v99: Authored jump landing pose, hold 0.60s after landing before standing.
extends Node3D
const VersionIndicator = preload("res://scripts/version_indicator.gd")
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const CombatVitals = preload("res://scripts/combat_vitals.gd")
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
# RUN uses a continuously varying analog vector within a 70px radius.
# BOOST remains based on distance from the initial touch point.
# v161: bring BOOST entry 25.2px closer; retain 15% radial hysteresis.
const BOOST_START_RADIUS_RATIO: float = 1.10
const BOOST_EXIT_RADIUS_RATIO: float = 0.90
const BOOST_CONFIRM_SECONDS: float = 0.10
# v163: RUN <-> BOOST speed uses a 0.20s smoothstep transition.
# Changes of direction of the transition start at the CURRENT multiplier.
const BOOST_SPEED_BLEND_SECONDS: float = 0.20
# v159: avoid RUN/WAIT clips interrupting quick BOOST direction changes.
# This is VISUAL ONLY: physics speed and BOOST input thresholds stay unchanged.
# v162: hold the authored BOOST pose for 0.50s after BOOST input ends.
# The rig then crossfades to RUN over 0.20s independently of move speed.
const BOOST_POSE_GRACE_SECONDS: float = 0.50
# v248: RUN, deadzone and BOOST dimensions are 150% of v247.
# BOOST entry/exit percentages and 0.10s confirmation stay unchanged.
const RUN_CONTROL_RADIUS: float = 105.0
const RUN_INPUT_DEADZONE_PIXELS: float = 16.875
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
# v256: Bash alone gets forgiving human-thumb timings. These constants are
# separate from STEP and archived JUMP so the 45-degree 8-way rule remains.
const BASH_FLICK_MAX_SECONDS: float = 0.42  # old: 0.24s
const BASH_FLICK_MIN_FORWARD_PIXELS: float = 30.0  # old: 50px
const BASH_FLICK_MIN_FORWARD_SPEED: float = 200.0  # old: 500px/s
const BASH_FLICK_CANDIDATE_GRACE_PIXELS: float = 38.0  # old: 18px
const BASH_FLICK_REVERSAL_RATIO: float = 1.35  # old: 1.20
const BASH_FLICK_TAIL_SECONDS: float = BASH_FLICK_MAX_SECONDS
const STEP_BACK: int = 2  # step_side: -1=left, +1=right, 2=back
# v100: Jump is archived as an optional debug-only action. It is NOT part of
# ordinary touch controls. Turning this flag on restores the v99 up-flick path
# without deleting the authored Jump animation, air actions or landing code.
const JUMP_TOUCH_INPUT_ENABLED: bool = false
const JUMP_FLICK_TAIL_SECONDS: float = 0.20
const JUMP_FLICK_MIN_VERTICAL: float = 50.0  # Reduced from 78px; backstep unchanged.
const JUMP_HEIGHT: float = 1.50  # fixed world-space apex above takeoff plane
# v300: Melee3 -> screen-DOWN flick: 5m rearward arc / 1.5m apex.
# Unlike archived ordinary Jump, this is a dedicated combo action.
const BACK_SOMERSAULT_DISTANCE: float = 5.0
const BACK_SOMERSAULT_HEIGHT: float = 1.5
# Symmetrical cubic Bezier controls at 4/3 of the actual 1.5m apex.
# Starts vertically, moves fastest near its peak, ends vertically.
const BACK_SOMERSAULT_ARC_CONTROL_HEIGHT_RATIO: float = 4.0 / 3.0
const BACK_SOMERSAULT_FLIGHT_SECONDS: float = 0.80
const BACK_SOMERSAULT_LANDING_SECONDS: float = 0.20
const BACK_SOMERSAULT_VISUAL_PIVOT_HEIGHT: float = 0.90
# Kick_b's extended right leg at original 0.20833s/0.79167s.
const BACK_SOMERSAULT_HIT_PROGRESS: float = 0.20833 / 0.79167
# v284: authored foot extension precedes liftoff. One 0.8s clip has
# contact at 0.20833/0.79167 of its duration and a post-hit rear flight.
const BACK_SOMERSAULT_STRIKE_SECONDS: float = (
    BACK_SOMERSAULT_FLIGHT_SECONDS * BACK_SOMERSAULT_HIT_PROGRESS)
const BACK_SOMERSAULT_REAR_FLIGHT_SECONDS: float = (
    BACK_SOMERSAULT_FLIGHT_SECONDS - BACK_SOMERSAULT_STRIKE_SECONDS)
const JUMP_FLIGHT_SECONDS: float = 0.80  # 0.000..0.375 authored seconds are retimed over flight
# New authored landing transition 0.375->0.500 runs after floor contact.
const JUMP_LANDING_MOTION_SECONDS: float = 0.125
const JUMP_LANDING_HOLD_SECONDS: float = 0.60  # hold the last landing key before standing
const JUMP_TAKEOFF_HORIZONTAL_FACTOR: float = 0.80  # retain 80% of horizontal speed
const JUMP_AIR_STEER_SPEED_FACTOR: float = 0.30  # ground RUN speed; never boosts in air
const JUMP_GRAVITY: float = 8.0 * JUMP_HEIGHT / (JUMP_FLIGHT_SECONDS * JUMP_FLIGHT_SECONDS)
# Authored clip's fall pose begins at the 0.20833s key of its 0.375s duration.
const JUMP_FALL_CLIP_START: float = 0.20833 / 0.375
# v300: screen STEP travel is determined ONLY by flick angle, never
# player-target distance. Equipment speed/time multipliers still apply.
const BACK_STEP_DISTANCE: float = 5.0
const STEP_FORWARD_DISTANCE: float = 3.0
const STEP_SIDE_DISTANCE: float = 3.0
const STEP_SPEED: float = 10.0  # m/s, equipment-adjusted
# Legacy speed policy retained for historic tests, not called by STEP.
const STEP_CLOSE_SPEED: float = 8.0
const STEP_CLOSE_SURFACE_DISTANCE: float = 2.0
const STEP_FALLOFF_START_SURFACE_DISTANCE: float = 5.0
const STEP_ORBIT_ANGLE_DEGREES: float = 35.0  # legacy-only reference
const STEP_MIN_ARC_LENGTH: float = 3.0
const STEP_MAX_ARC_LENGTH: float = 5.0
const STEP_MAX_DURATION: float = 0.50  # 5m / 10m/s
const STEP_MIN_ORBIT_RADIUS: float = 0.10  # tangent is unstable at the exact center
const STEP_CLOSE_ORBIT_MAX_DEGREES: float = 120.0  # prevent circular loops when overlapping target
# v82: At point-blank range the player may orbit around the target rapidly.
# Limit the camera/player ANGULAR SEPARATION around the target, not the total
# camera rotation from a step's starting orientation. The rate cap prevents
# an instantaneous camera whip if the constraint is first exceeded.
const STEP_CLOSE_CAMERA_SURFACE_DISTANCE: float = 1.0  # distance to cube face (meters)
# v285: narrower target-centered camera/player separation during close orbit.
const STEP_CLOSE_CAMERA_MAX_RELATIVE_DEGREES: float = 45.0
# v287/v288: retain the low shoulder camera and prevent attack-by-attack
# zoom pumping. v288 also pursues SERA's position and yaw DURING attacks;
# the hold timer below controls zoom recovery, not angular follow.
# Never raise the pitch for combat: retain v56's 0.21 elevation.
const CAMERA_COMBAT_VISIBILITY_DISTANCE: float = 6.5
const CAMERA_COMBAT_YAW_HOLD_SECONDS: float = 0.45
const CAMERA_COMBAT_SHOULDER_DEGREES: float = 12.0
const CAMERA_COMBAT_MAX_PLAYER_SIDE_DEGREES: float = 30.0
# v288: small SERA-follow lag with a hard distance/angle leash. Beyond the
# leash the camera moves at exactly the player's rate, never falling farther
# behind during fast movement or homing attacks.
const CAMERA_PLAYER_FOCUS_LEAD_METERS: float = 2.0
const CAMERA_PLAYER_FOCUS_FOLLOW_RATE: float = 15.0
const CAMERA_PLAYER_FOCUS_MAX_LAG_METERS: float = 0.65
const CAMERA_PLAYER_YAW_FOLLOW_RATE: float = 10.0
const CAMERA_PLAYER_YAW_MAX_LAG_DEGREES: float = 12.0
const CAMERA_COMBAT_MIN_RADIUS: float = 11.3
const CAMERA_COMBAT_ZOOM_OUT_SPEED: float = 8.0
# v286: minimum safe target->SERA orbit radius includes the wide outer
# legs and SERA's shoulder width, not merely the central hitbox.
const SIDE_KICK_BOOST_DISTANCE: float = 3.0
const SIDE_KICK_SAFE_ORBIT_RADIUS: float = 3.55  # historic bound; not boost distance
const STEP_CLOSE_CAMERA_MAX_TURN_RATE_DEGREES: float = 300.0
const STEP_CLOSE_CAMERA_RECOVERY_SECONDS: float = 0.18
# Attack begins on a short tap. Dragging still uses v9's screen-space controls.
const TAP_MAX_TRAVEL: float = 18.0  # Pixels, measured over the full pointer gesture.
const TAP_MAX_DURATION: float = 0.32  # Seconds; long holds are not attacks.
const GUARD_HOLD_SECONDS: float = TAP_MAX_DURATION  # Hold still for 0.32s to raise shield.
# v185: The attack starts when the player's center is within 2m of the
# target collision surface; this also terminates PRE-attack melee homing.
const MELEE_SURFACE_REACH: float = 2.0
# Preserve v183 melee contact assist and independent Bash activation distance.
const MELEE_HIT_ASSIST_BASE_REACH: float = 0.75
const MELEE_BOOST_DEFAULT_SPEED: float = 11.5  # v181: A speed; per-booster stat overrides.
const MELEE_BOOST_DEFAULT_DURATION: float = 0.4  # v182 A pre-strike homing cap.
# Preserve v13 hit timing (confirmed by user).
const TARGET_MAX_HP: int = 500
const STRIKE_DAMAGE = [12, 12, 26]  # Per-stage damage for melee1, Melee2, Melee3.
const STRIKE_ACTIVE_FROM: float = 0.130
const STRIKE_ACTIVE_TO: float = 0.345
const STRIKE_ASSIST_AT: float = 0.170
# The Blockbench clips use 24 fps. Cancel roughly two frames (0.0833 s)
# after each authored follow-through, without shortening standalone recovery.
const STRIKE_CLIPS = ["melee1", "Melee2", "Melee3"]
const KATANA_STRIKE_CLIP: String = "Melee_katana"
const KATANA_SECOND_STRIKE_CLIP: String = "Melee_katana2"
# Katana's 2-stage chain ends on its second authored-derived slash,
# while the original sword keeps its independent 3-stage chain.
# v167: a forward flick after stage 3 triggers the authored shield bash.
# Allow a brief post-finisher window, then one tap after Bash to loop to stage 1.
const BASH_LINK_SECONDS: float = 0.65
# Post-Melee3 lateral flick uses the same trajectory and cost as a STEP.
# Kick damage borrows melee1 until dedicated kick stats are specified.
# Both authored kicks straighten alternate legs at these original 1s keys.
const SIDE_KICK_HIT_PROGRESS = [0.25, 0.58333]
# v280: start lateral travel at each authored SECOND windup, not on kick start.
# Original 1.0s Blockbench keys: Kick_r=0.33333, Kick_l=0.41667.
const SIDE_KICK_SECOND_WINDUP_R: float = 0.33333
const SIDE_KICK_SECOND_WINDUP_L: float = 0.41667
# v278: lateral kick animation lasts twice as long without reducing
# normal STEP travel speed/distance, changing Kick_b, or cutting off clips.
const SIDE_KICK_MOTION_TIME_MULTIPLIER: float = 2.0
const SIDE_KICK_REACH: float = MELEE_SURFACE_REACH
const BASH_CONTACT_TIME: float = 0.25
const BASH_TRACK_SECONDS: float = 0.20  # Max time to enter Bash reach before launch.
const FOLLOWUP_TRACK_SECONDS: float = 0.20  # Melee2/Melee3 pre-strike homing cap.
# Verified Blockbench key times from assets/sera_source.json (v181 model).
const BASH_WINDUP_KEY: float = 0.20833
const FOLLOWUP_WINDUP_KEYS = [0.0, 0.08333, 0.20833]
const BASH_DAMAGE: int = 12
const BASH_REACH: float = 0.95  # Unchanged from v183 (0.75 + 0.20).
const STRIKE_CANCEL_TIMES = [7.0 / 24.0, 7.0 / 24.0, 15.0 / 24.0]
# v284: a reserved cardinal flick cancels Melee3 0.05s after its
# authored 15/24s swing-through. Melee1 restart remains unchanged.
const MELEE3_FLICK_CANCEL_DELAY: float = 0.05
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
enum CombatState { IDLE, MELEE_APPROACH, DASH, STRIKE, BASH, BASH_TRACK, STRIKE_TRACK, BACK_KICK_TRACK }
# v112: Persistent handedness changes RUN animation selection only.
const HANDEDNESS_SETTINGS_FILE: String = "user://sera_settings.cfg"
const NEXUS_SCENE: String = "res://scenes/command_nexus.tscn"
const DRAG_RADIUS: float = 157.5  # v248: 150% of v247; same BOOST entry/exit ratios.
const CAMERA_FOLLOW_RATE: float = 1.65
const CAMERA_IDLE_RECENTER_RATE: float = 1.05  # How quickly the player eases toward a clear centered resting position.
const CAMERA_MOVING_YAW_SCALE: float = 0.55  # Softer rotation during drag to preserve left/right movement.
# v229: anticipate screen edges, cap angular corrections and reserve zoom.
const CAMERA_EDGE_GUARD_RATIO: float = 0.008
const CAMERA_EDGE_MAX_CORRECTION_DEGREES_PER_SECOND: float = 240.0
const CAMERA_FIT_RADIUS_RESERVE: float = 0.12
# v230: close-range BOOST uses zoom framing instead of competing yaw
# correction. Keep a fitted minimum until closer zoom is safely possible.
const CAMERA_CLOSE_BOOST_ENTER_DISTANCE: float = 6.0
const CAMERA_CLOSE_BOOST_EXIT_DISTANCE: float = 7.5
const CAMERA_FIT_RELAX_SPEED: float = 1.25
# v234: responsive but slightly trailing camera dolly as the player closes
# distance to the target. These govern zoom IN only, never safety zoom OUT.
const CAMERA_NEAR_DOLLY_BLEND_START: float = 8.0
const CAMERA_NEAR_DOLLY_BLEND_FULL: float = 5.0
const CAMERA_NEAR_DOLLY_PLAYER_SPEED_RATIO: float = 0.88
const CAMERA_NEAR_DOLLY_SPEED_FILTER_RATE: float = 10.0
const CAMERA_NEAR_DOLLY_MAX_ACCEL: float = 24.0
const CAMERA_NEAR_DOLLY_SETTLE_SPEED: float = 0.70
const CAMERA_NEAR_DOLLY_GAP_RATE: float = 6.0
const CAMERA_NEAR_DOLLY_MAX_CLOSING_SAMPLE: float = 12.0
const TARGET_IDLE_GAP_RATIO: float = 0.034  # Resting silhouette gap as a fraction of viewport width.
const SIDE_SWITCH_PIXELS: float = 2.0  # Only used while moving and on release: no 3.5% dead-band.
const MAX_SIDE_SEARCH_ANGLE: float = 1.5  # radians; only the nearest clear orbit angle is used
# Scale the preferred combat orbit, not frame-fit/clearance corrections.
const CAMERA_DISTANCE_SCALE: float = 0.60
const MIN_SEPARABLE_DISTANCE: float = 1.9  # closer than silhouettes: orbit cannot solve occlusion
const CAMERA_BASE_RADIUS: float = 16.0
const CAMERA_CLOSE_RADIUS: float = 8.8  # v233: slightly wider closest framing (previously 7.8m).
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
const TARGET_HALF_SIZE: float = 1.0  # 2m wide and 2m tall (X/Y).
const TARGET_BODY_HALF_DEPTH: float = 1.70  # v239: 3.4m nose-to-tail along Z.
# Framing includes the attached head, side-frame legs and feet (not only the core).
const TARGET_FRAME_HALF_WIDTH: float = 2.35  # v240 broad arm/leg outer frame.
const TARGET_FRAME_HALF_HEIGHT: float = 1.53
const TARGET_FRAME_HALF_DEPTH: float = 2.35
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
const PART_STATS = preload("res://scripts/sera_part_stats.gd")
const TARGET_MOTION_SCRIPT = preload("res://scripts/training_target_motion.gd")
const TARGET_PARTS_SCRIPT = preload("res://scripts/target_parts.gd")
# Shared screen projection and directional rules for new flick actions.
const FLICK_DIRECTION_POLICY = preload("res://scripts/flick_direction_policy.gd")
const TrainingDefaults = preload("res://scripts/training_defaults.gd")
# v178 prototype damage table: AIM, LEAD, SHOCK, ARC, respectively.
const ENEMY_ATTACK_HP_DAMAGE = [18.0, 22.0, 28.0, 34.0]
const ENEMY_ATTACK_SHIELD_COST = [23.0, 28.0, 36.0, 42.0]
const TRAINING_KO_RECOVERY: float = 2.5
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

# v177: trial A medium/B heavy equipment performance.
const TEST_EN_MAX: float = 100.0
const EN_RECOVERY_UNLOCK_RATIO: float = 0.60
const EN_EMPTY_FLASH_SECONDS: float = 0.60
const EN_EMPTY_FLASH_HZ: float = 7.0
const TEST_SH_MAX: float = 100.0
var part_stats: Dictionary = {}
var player_hp: float = 800.0
var energy: float = TEST_EN_MAX
var shield: float = TEST_SH_MAX
var energy_exhausted: bool = false
var energy_recovery_pause: float = 0.0
var en_empty_flash_remaining: float = 0.0
var shield_recovery_pause: float = 0.0
var guard_break_remaining: float = 0.0
var guard_break_hits: int = 0
var down_remaining: float = 0.0
var resources_label: Label
var vitals_hud: Control
const TARGET_HP_BAR_WIDTH: float = 246.0
var core_label: Label
var test_hit_button: Button
var test_break_button: Button
var move_target_button: Button
var incoming_damage_label: Label
var incoming_damage_remaining: float = 0.0
var training_ko_remaining: float = 0.0
var target_motion: RefCounted
var target_floor_mark: Node3D
var target_move_enabled: bool = true
var training_settings: Dictionary = {}
var stagger_value: float = 0.0
var stagger_remaining: float = 0.0
var part_break_remaining: float = 0.0
var last_hit_time: float = -100.0

var player: CharacterBody3D
var rig: Node3D
var camera: Camera3D
var target: Node3D
var target_parts: Node3D
var locked_target_part_id: String = ""
# An empty part ID identifies BODY; auto_lock_initialized distinguishes
# an intentional BODY lock from initial acquisition (manual compatibility).
var auto_lock_initialized: bool = false
var manual_part_lock_active: bool = false
var auto_lock_enabled: bool = true
# v305: AUTO has no confirmation timer. Retain the historic constant and
# pending variables only as zeroed compatibility state for older callers.
const AUTO_LOCK_SWITCH_CONFIRM_SECONDS: float = 0.0
var auto_lock_pending_part: String = ""
var auto_lock_pending_elapsed: float = 0.0
var lock_switch_left_button: Button
var lock_switch_right_button: Button
var lock_mode_button: Button
# v303: optional two-ray world visualization, OFF by default.
var lock_lines_button: Button
var lock_lines_visible: bool = false
var lock_line_root: Node3D
var lock_line_meshes: Array[MeshInstance3D] = []
const LOCK_LINE_BEAM_RADIUS: float = 0.017
const LOCK_LINES_BUTTON_SIZE: Vector2 = Vector2(128.0, 43.0)
# Horizontal lock layout is preserved: left near center, AUTO at 75%,
# right at the edge. Only the vertical anchor is moved below combatants.
const CONTROLLER_REGION_START_RATIO: float = 0.50
# v286: keep persistent LOCK UI off the middle of the combat scene.
const LOCK_CONTROLS_VERTICAL_RATIO: float = 0.76
const LOCK_SWITCH_BUTTON_SIZE: Vector2 = Vector2(104.0, 58.0)
const LOCK_MODE_BUTTON_SIZE: Vector2 = Vector2(128.0, 58.0)
const CONTROLLER_BUTTON_TOP_INSET: float = 8.0
const LOCK_SWITCH_EDGE_INSET: float = 8.0
var target_parts_label: Label
var target_collider: AnimatableBody3D
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
var nexus_button: Button
var _returning_to_nexus: bool = false
var _previous_quit_on_go_back: bool = true
# v231: sample the same physics-interpolated actor positions that render.
var _previous_physics_interpolation: bool = false
var camera_player_render_position: Vector3 = Vector3.ZERO
var camera_target_render_position: Vector3 = Vector3.ZERO
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
var boost_speed_transition_start: float = 1.0
var boost_speed_transition_target: float = 1.0
var boost_speed_transition_elapsed: float = BOOST_SPEED_BLEND_SECONDS
var boost_pose_grace_remaining: float = 0.0
# Keep the last commanded jet heading across the momentary neutral thumb
# crossing when the rig still renders its held BOOST directional pose.
var held_boost_exhaust_direction: Vector3 = Vector3.ZERO
var held_boost_backstroke_weight: float = 0.0
var held_boost_left_sector_world: Vector3 = Vector3.ZERO
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
var landing_from_somersault: bool = false
var back_somersault_active: bool = false
var back_somersault_launched: bool = false  # set only after confirmed foot contact
var back_somersault_elapsed: float = 0.0
var back_somersault_start: Vector3 = Vector3.ZERO
var back_somersault_direction: Vector3 = Vector3.ZERO
var back_somersault_original_rig_y: float = 0.195
var back_somersault_has_authored_clip: bool = false
var back_somersault_hit: bool = false
var back_somersault_hit_checked: bool = false
var back_kick_track_elapsed: float = 0.0
var player_floor_mark: Node3D
var step_active: bool = false
var step_kick_side_request: int = 0  # transient; keep STEP method API unchanged
var side_kick_active: bool = false
var side_kick_side: int = 0  # -1 Kick_l, +1 Kick_r; distinct from screen travel
var side_kick_travel_anchor_set: bool = false  # do not undo first-strike homing
# v300: circle around the locked PART until the authored second kick hit,
# then move on the instantaneous tangent with no further rotation.
var side_kick_linear_active: bool = false
var side_kick_linear_start: Vector2 = Vector2.ZERO
var side_kick_linear_direction: Vector2 = Vector2.ZERO
var side_kick_linear_distance: float = 0.0
var side_kick_orbit_sign: float = 1.0
var side_kick_did_hit: bool = false
var side_kick_hit_mask: int = 0
var side_kick_hit_count: int = 0
var step_elapsed: float = 0.0
var step_duration_current: float = STEP_MIN_ARC_LENGTH / STEP_SPEED
var step_speed_current: float = STEP_SPEED  # snapshotted once on each flick
var step_arc_length: float = 0.0
var step_start_offset: Vector2 = Vector2.ZERO  # Player XZ relative to target.
var step_target_center: Vector2 = Vector2.ZERO
var step_signed_angle: float = 0.0
var step_linear_fallback: bool = false  # ordinary screen STEPs linear; side kicks orbit target
var step_linear_offset: Vector2 = Vector2.ZERO
# In screen-directed flicks, this holds forward/back step distance signed
# against SERA's own facing; legacy debug STEPs retain their old orbit.
var step_radial_delta: float = 0.0
var step_flick_direction: Vector2 = Vector2.ZERO
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
var camera_focus_follow_xz: Vector2 = Vector2.ZERO
var camera_combat_hold_remaining: float = 0.0
var camera_radius: float = CAMERA_BASE_RADIUS * CAMERA_DISTANCE_SCALE
var camera_follow_radius: float = CAMERA_BASE_RADIUS * CAMERA_DISTANCE_SCALE
var camera_fit_radius_floor: float = 0.0
var camera_last_separation: float = -1.0
var camera_filtered_closing_speed: float = 0.0
var camera_dolly_in_speed: float = 0.0
var camera_near_dolly_weight: float = 0.0
var close_boost_camera_active: bool = false
var player_screen_side: int = 1  # Last observed player side of the target on screen.
var was_running: bool = false
var floor_stage: Node3D
var blur_last_player_position: Vector3 = Vector3.ZERO
var blur_velocity: Vector3 = Vector3.ZERO
var blur_active_this_physics_frame: bool = false
var blur_step_this_physics_frame: bool = false
# v216: one acceleration flare for each STEP or new melee homing action,
# not a continuous flicker while the action remains active.
var thruster_accel_previous_step: bool = false
var thruster_accel_previous_somersault: bool = false
var thruster_accel_previous_tracking_state: int = -1
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
var footstep_audio: AudioStreamPlayer  # Visual sole contacts; no timer-based walking beat.
var player_collision_shape: CollisionShape3D
var collision_height_extension: float = 0.0
var sword_trail: Node3D
var target_hp: int = TARGET_MAX_HP
var hit_stop_remaining: float = 0.0
var hit_flash_remaining: float = 0.0
var target_respawn_remaining: float = 0.0
var damage_popup_remaining: float = 0.0
var impact_origin: Vector3 = Vector3.ZERO
var strike_index: int = 0  # 0, 1 or 2; only meaningful in STRIKE.
var combo_queued: bool = false  # One buffered tap for the next attack stage.
var bash_queued: bool = false
var bash_combo_queued: bool = false
# A flick during Melee3 is buffered until 0.10s after its strike-through key.
var buffered_side_kick_flick: Vector2 = Vector2.ZERO
var buffered_side_kick_side: int = 0  # -1=Kick_l, +1=Kick_r, 2=Kick_b
var bash_flick_candidate: bool = false
var side_kick_flick_candidate: bool = false
var kick_touch_started_in_window: bool = false
var kick_debug_text: String = ""
var kick_debug_remaining: float = 0.0
var last_melee3_finished_ms: int = -9999999
var gesture_screen_forward: Vector2 = Vector2.UP  # Screen-projected SERA front at flick start.
var guard_flick_axis_captured: bool = false  # A long GUARD hold can outlast camera recentering.
var bash_followup_window_remaining: float = 0.0
var bash_loop_window_remaining: float = 0.0
var bash_did_hit: bool = false
var bash_prev_time: float = 0.0
var bash_track_elapsed: float = 0.0
var melee_boost_elapsed: float = 0.0
var followup_track_elapsed: float = 0.0
var strike_did_hit: bool = false
var strike_prev_time: float = 0.0
var strike_prev_blade: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
    # Enable interpolation only in training. Animated joints and menus must
    # retain render-frequency evaluation; opt-in physics-driven actors below.
    _previous_physics_interpolation = get_tree().physics_interpolation
    get_tree().physics_interpolation = true
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    # Android Back should return to the base here instead of closing the app.
    _previous_quit_on_go_back = get_tree().quit_on_go_back
    get_tree().quit_on_go_back = false
    _load_handedness_preference()
    training_settings = TrainingDefaults.load_defaults()
    target_move_enabled = bool(training_settings.get("move_enabled", true))
    _build_world()
    _build_character()
    _update_equipped_collision_height()
    _load_part_stats()
    _build_target()
    _build_enemy_shooter()
    _build_camera()
    _build_lock_line_visuals()
    _build_overlay()
    _build_hit_effects()
    _build_motion_blur()
    _update_target_marker_projection()  # Initial position before the first rendered frame.

func _exit_tree() -> void:
    get_tree().quit_on_go_back = _previous_quit_on_go_back
    get_tree().physics_interpolation = _previous_physics_interpolation

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _request_return_to_nexus()

func _request_return_to_nexus() -> void:
    if _returning_to_nexus:
        return
    _returning_to_nexus = true
    call_deferred("_change_to_nexus")

func _change_to_nexus() -> void:
    var result: Error = get_tree().change_scene_to_file(NEXUS_SCENE)
    if result != OK:
        _returning_to_nexus = false
        push_error("Training to Nexus scene load failed (%d)" % result)

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

func _load_part_stats() -> void:
    var chosen: Dictionary = {}
    for slot in ["head", "torso", "arms", "legs", "booster", "weapon_r", "weapon_l"]:
        chosen[slot] = str(rig.call("get_equipment_selection", slot))
    part_stats = PART_STATS.build(chosen)
    rig.call("set_heavy_slide_run_enabled", str(part_stats.get("run_motion", "run")) == "slide")
    player_hp = float(part_stats.get("max_hp", 800.0))
    rig.call("set_equipment_motion_scales", float(part_stats.get("damage_time_mult", 1.0)),
        float(part_stats.get("guard_speed_mult", 1.0)),
        float(part_stats.get("guard_transition", 0.095)),
        str(part_stats.get("guard_reaction", "medium")))

func _enter_energy_exhaustion() -> void:
    if energy_exhausted:
        return
    energy_exhausted = true
    en_empty_flash_remaining = EN_EMPTY_FLASH_SECONDS
    if rig != null:
        rig.call("set_energy_flash_active", true)

func _tick_energy_empty_flash(delta: float) -> void:
    if en_empty_flash_remaining <= 0.0:
        return
    en_empty_flash_remaining = maxf(0.0, en_empty_flash_remaining - maxf(delta, 0.0))
    var elapsed: float = EN_EMPTY_FLASH_SECONDS - en_empty_flash_remaining
    var red_phase: bool = (en_empty_flash_remaining > 0.0
        and int(floor(elapsed * EN_EMPTY_FLASH_HZ * 2.0)) % 2 == 0)
    if rig != null:
        rig.call("set_energy_flash_active", red_phase)

func _spend_energy(amount: float) -> bool:
    if amount <= 0.0:
        return true
    # Exhaustion is a global EN-spend lock, not merely a BOOST restriction.
    # Free actions still work; positive EN costs cannot bypass recovery.
    if energy_exhausted:
        return false
    if energy + 0.0001 < amount:
        if energy <= 0.0001:
            _enter_energy_exhaustion()
        return false
    energy = maxf(0.0, energy - amount)
    energy_recovery_pause = 0.25
    if energy <= 0.0001:
        _enter_energy_exhaustion()
    return true

func _tick_resources(delta: float) -> void:
    energy_recovery_pause = maxf(0.0, energy_recovery_pause - delta)
    shield_recovery_pause = maxf(0.0, shield_recovery_pause - delta)
    if energy_recovery_pause <= 0.0:
        energy = minf(TEST_EN_MAX, energy + 24.0 * delta)
    if shield_recovery_pause <= 0.0 and guard_break_remaining <= 0.0 and down_remaining <= 0.0:
        shield = minf(TEST_SH_MAX, shield + 16.0 * delta)
    if energy_exhausted and energy >= TEST_EN_MAX * EN_RECOVERY_UNLOCK_RATIO:
        energy_exhausted = false
    _refresh_player_hp_bar()
    if resources_label != null:
        resources_label.text = "DEF %d%%  SH %d" % [
            roundi(float(part_stats.get("defense", 0.16)) * 100.0),
            ceili(shield)]
    if core_label != null:
        var label_name: String = "BODY"
        var integrity: float = float(target_hp)
        var maximum: float = float(TARGET_MAX_HP)
        if target_parts != null and not locked_target_part_id.is_empty():
            label_name = str(target_parts.call("get_part_name", locked_target_part_id))
            integrity = float(target_parts.call("get_part_integrity", locked_target_part_id))
            maximum = float(target_parts.call("get_part_max_integrity", locked_target_part_id))
        core_label.text = "LOCK %s  %d/%d  STAGGER %d/50  %s" % [
            label_name, ceili(integrity), ceili(maximum), ceili(stagger_value),
            "DOWN" if part_break_remaining >= 3.0 else (
                "BREAK" if part_break_remaining > 0.0 else (
                    "STUN" if stagger_remaining > 0.0 else (
                        "MOVE" if target_move_enabled else "HOLD")))]
    if target_parts_label != null and target_parts != null:
        var next_status: String = str(target_parts.call("status_line"))
        if target_parts_label.text != next_status:
            target_parts_label.text = next_status

func _take_test_damage(raw: float) -> void:
    if training_ko_remaining > 0.0 or player_hp <= 0.0:
        return
    var final_damage: float = raw * (
        1.0 - clampf(float(part_stats.get("defense", 0.16)), 0.0, 0.90))
    player_hp = maxf(0.0, player_hp - final_damage)
    _refresh_player_hp_bar()
    incoming_damage_remaining = 0.75
    if incoming_damage_label != null:
        incoming_damage_label.text = "-%d HP" % ceili(final_damage)
        incoming_damage_label.modulate.a = 1.0
        incoming_damage_label.visible = true
    if player_hp <= 0.0:
        _begin_training_ko()

func _begin_training_ko() -> void:
    # Training-only recovery. Hold the exact final Damageknock keyframe.
    training_ko_remaining = TRAINING_KO_RECOVERY
    _refresh_player_hp_bar()
    if guard_active:
        _set_guard(false)
    if step_active:
        _finish_side_step(false)
    if back_somersault_active:
        _cancel_back_somersault()
    if landing_from_somersault:
        landing_active = false
        landing_elapsed = 0.0
        landing_from_somersault = false
        if rig != null:
            rig.call("finish_jump", false, false)
    if combat_state != CombatState.IDLE:
        _cancel_attack()
    # Complete any ordinary action transitions before locking the KO pose.
    if rig != null:
        rig.call("set_training_ko", true)
    direction_input = Vector2.ZERO
    movement_boost_active = false
    boost_pose_grace_remaining = 0.0
    gesture_active = false
    en_empty_flash_remaining = 0.0
    rig.call("set_energy_flash_active", false)
    player.velocity = Vector3.ZERO
    if touch_ui != null:
        touch_ui.call("hide_drag")
        touch_ui.call("set_movement_boost", false)
    if enemy_shooter != null:
        enemy_shooter.set("can_fire", false)
    if enemy_attack_pool != null:
        for active_attack in enemy_attack_pool.get_children():
            active_attack.queue_free()

func _tick_training_ko(delta: float) -> void:
    if training_ko_remaining <= 0.0:
        return
    training_ko_remaining = maxf(0.0, training_ko_remaining - delta)
    if training_ko_remaining > 0.0:
        return
    player_hp = float(part_stats.get("max_hp", 800.0))
    energy = TEST_EN_MAX
    shield = TEST_SH_MAX
    energy_exhausted = false
    energy_recovery_pause = 0.0
    shield_recovery_pause = 0.0
    guard_break_remaining = 0.0
    guard_break_hits = 0
    down_remaining = 0.0
    damage_reaction_active = false
    damage_knockback_elapsed = 0.0
    damage_knockback_direction = Vector3.ZERO
    if rig != null:
        rig.call("set_training_ko", false)
    _refresh_player_hp_bar()
    player.position = Vector3.ZERO
    player.velocity = Vector3.ZERO
    target.position = Vector3(0.0, TARGET_BASE_HEIGHT, -8.0)
    # Teleports never blend from previous physics-frame transforms.
    player.reset_physics_interpolation()
    target.reset_physics_interpolation()
    # Reset the derivative estimator after teleports; otherwise the new
    # separation can be mistaken for a huge physical approach velocity.
    camera_last_separation = -1.0
    camera_filtered_closing_speed = 0.0
    camera_dolly_in_speed = 0.0
    camera_near_dolly_weight = 0.0
    camera_player_render_position = player.global_position
    camera_target_render_position = target.global_position
    camera_focus_follow_xz = _desired_camera_follow_focus_xz()
    var respawn_radial: Vector2 = Vector2(
        player.position.x - target.position.x, player.position.z - target.position.z)
    if respawn_radial.length_squared() > 0.000001:
        camera_yaw = atan2(respawn_radial.x, respawn_radial.y) - deg_to_rad(
            CAMERA_COMBAT_SHOULDER_DEGREES)
    target_motion = TARGET_MOTION_SCRIPT.new()
    if target_floor_mark != null:
        target_floor_mark.position = Vector3(0.0, -0.026, -8.0)
    target_hp = TARGET_MAX_HP
    target_respawn_remaining = 0.0
    if target_parts != null:
        target_parts.call("reset_parts")
    locked_target_part_id = ""
    auto_lock_initialized = false
    auto_lock_pending_part = ""
    auto_lock_pending_elapsed = 0.0
    manual_part_lock_active = not auto_lock_enabled
    if enemy_shooter != null:
        enemy_shooter.call("set_head_destroyed", false)
    stagger_value = 0.0
    stagger_remaining = 0.0
    part_break_remaining = 0.0
    _refresh_hp_bar()

func _advance_target_motion(delta: float) -> void:
    if target == null or player == null or target_motion == null:
        return
    # The projectile/ARC telegraph snapshots its origin and facing at warning
    # start. Freeze the moving target until launch to keep that cue truthful.
    var warning: bool = enemy_shooter != null and bool(
        enemy_shooter.call("warning_in_progress"))
    var frozen: bool = (not target_move_enabled or warning or target_hp <= 0
        or stagger_remaining > 0.0 or part_break_remaining > 0.0
        or down_remaining > 0.0 or training_ko_remaining > 0.0)
    target.position = target_motion.call("advance", delta, target.position,
        player.position, frozen)
    if target_floor_mark != null:
        target_floor_mark.position = Vector3(
            target.position.x, -0.026, target.position.z)

func _begin_test_down() -> void:
    if down_remaining > 0.0:
        return
    guard_break_remaining = 0.0
    down_remaining = 1.45
    var away: Vector3 = player.global_position - target.global_position
    away.y = 0.0
    if away.length_squared() < 0.000001:
        away = player.global_transform.basis.z
    _move_player_swept(away.normalized() * 4.0, true)
    if rig != null:
        rig.call("set_combat_paused", false)

func _register_test_hit(stagger_amount: float, extension: float) -> void:
    # Weak stagger accumulates on the entire boss, not on separate limbs.
    # Old shared CORE 75 break gauge has been replaced by per-part durability.
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    if stagger_remaining > 0.0:

        if now - last_hit_time <= 0.36:
            stagger_remaining = minf(1.5, stagger_remaining + extension)
    else:
        stagger_value += stagger_amount
        if stagger_value >= 50.0:
            stagger_value = 0.0
            stagger_remaining = 0.55
    last_hit_time = now

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
    # Actual BOOST input (or STEP) alone emits afterimages. The heavy-leg
    # SLIDE animation reuses Boost_* poses without enabling boost effects.
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
    player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
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
    player_collision_shape = CollisionShape3D.new()
    player_collision_shape.name = "PlayerBodyCollision"
    player_collision_shape.shape = player_capsule
    player_collision_shape.position.y = PLAYER_COLLISION_HEIGHT * 0.5
    player.add_child(player_collision_shape)
    rig = SERA_SCRIPT.new()
    rig.name = "SeraRig"
    # Only parent world motion is interpolated; joints/IK run per render.
    rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    rig.position.y = 0.195  # Compensates for -3 BB units in Wait_motion root track
    player.add_child(rig)
    if rig.has_signal("foot_contact"):
        rig.connect("foot_contact", Callable(self, "_on_foot_contact"))
    # v97: anchor the ground marker to the world, not the jumping player's Y.
    _add_round_ground_shadow("PlayerFloorMark", self, Vector3(0.0, -0.026, 0.0))
    player_floor_mark = get_node_or_null("PlayerFloorMark") as Node3D
    if player_floor_mark != null:
        player_floor_mark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

func _build_target() -> void:
    target = Node3D.new()
    target.name = "VirtualTarget"
    target.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
    target.position = Vector3(0, TARGET_BASE_HEIGHT, -8.0)
    add_child(target)
    target_motion = TARGET_MOTION_SCRIPT.new()

    var cube := BoxMesh.new()
    cube.size = Vector3(
        TARGET_HALF_SIZE * 2.0, TARGET_HALF_SIZE * 2.0, TARGET_BODY_HALF_DEPTH * 2.0)
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
    # The core collider stays exactly 2 x 2 x 3.4m; v251 attaches the
    # visual head/leg solids and junction guards to the same moving body.
    # Breakable strike AABBs remain independent of physics.
    target_collider = AnimatableBody3D.new()
    target_collider.name = "TargetSolidBody"
    target_collider.sync_to_physics = false
    target_collider.collision_layer = TARGET_COLLISION_LAYER
    target_collider.collision_mask = 0  # The player's mask includes this layer.
    target.add_child(target_collider)
    var target_box := BoxShape3D.new()
    target_box.size = cube.size
    var target_shape := CollisionShape3D.new()
    target_shape.name = "TargetBoxCollision"
    target_shape.shape = target_box
    target_collider.add_child(target_shape)
    target_mesh = marker
    target_material = cube_mat
    # Five independent opaque rectangular parts follow the extended body.
    # Keep the camera anchor at the same center even when the length changes.
    target_parts = TARGET_PARTS_SCRIPT.new()
    target_parts.name = "TargetBreakableParts"
    marker.add_child(target_parts)
    # v251: the same moving physical body holds the core, the modeled
    # part solids and hidden limb/body junction guards. Physical collisions
    # never affect the separate per-lock sword hit AABBs.
    target_parts.call("install_movement_colliders", target_collider)

    # Target marker stays on the ground even when its cube bobs vertically.
    _add_round_ground_shadow("TargetFloorMark", self, Vector3(target.position.x, -0.026, target.position.z))
    target_floor_mark = get_node_or_null("TargetFloorMark") as Node3D
    if target_floor_mark != null:
        target_floor_mark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

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
    # Apply the saved starting mode before the AI enters the scene tree.
    enemy_shooter.set("selected_attack", int(training_settings.get("attack_type", 0)))
    enemy_shooter.set("auto_fire_enabled", bool(training_settings.get("auto_fire_enabled", true)))
    enemy_shooter.connect("projectile_hit", Callable(self, "_on_enemy_projectile_hit"))
    add_child(enemy_shooter)

func _on_enemy_projectile_hit(_world_position: Vector3, incoming_direction: Vector3,
        is_bullet: bool, attack_type: int) -> void:
    if down_remaining > 0.0 or training_ko_remaining > 0.0:
        return
    # The attack subtype is captured when the projectile or area is created.
    # Changing the debug selection cannot change damage on an attack in flight.
    var attack_index: int = clampi(attack_type, 0, ENEMY_ATTACK_HP_DAMAGE.size() - 1)
    var incoming_damage: float = float(ENEMY_ATTACK_HP_DAMAGE[attack_index])
    if guard_break_remaining > 0.0:
        _take_test_damage(incoming_damage)
        if training_ko_remaining > 0.0:
            return
        guard_break_hits += 1
        if guard_break_hits >= int(part_stats.get("down_hits", 3)):
            _begin_test_down()
        return
    if guard_active:
        var cost: float = float(ENEMY_ATTACK_SHIELD_COST[attack_index]) * (
            float(part_stats.get("guard_cost_mult", 1.0)) /
            maxf(0.2, float(part_stats.get("guard_defense_mult", 1.0))))
        shield = maxf(0.0, shield - cost)
        shield_recovery_pause = 0.45
        SeraSave.record_defensive_impact(true)
        if shield <= 0.0:
            _set_guard(false)
            _begin_damage_reaction(incoming_direction)
            guard_break_remaining = 2.25
            guard_break_hits = 0
            return
        var guard_sound: AudioStreamPlayer = guard_bullet_hit_audio if is_bullet else player_hit_audio
        if is_instance_valid(guard_sound) and guard_sound.stream != null:
            guard_sound.play()
        if rig != null and bool(rig.get("loading_ok")):
            rig.call("trigger_guard_reaction")
        return
    SeraSave.record_defensive_impact(false)
    _take_test_damage(incoming_damage)
    # Keep the preexisting projectile and area hit sound identities.
    projectile_hit_flash_remaining = PROJECTILE_HIT_FLASH_SECONDS
    if projectile_hit_overlay != null:
        projectile_hit_overlay.visible = true
    var damage_sound: AudioStreamPlayer = player_bullet_hit_audio if is_bullet else player_hit_audio
    if is_instance_valid(damage_sound) and damage_sound.stream != null:
        damage_sound.play()
    if training_ko_remaining <= 0.0:
        _begin_damage_reaction(incoming_direction)

func _begin_damage_reaction(incoming_direction: Vector3) -> void:
    # A second projectile can flash the screen but cannot restart an in-progress
    # animation or overwrite its knockback vector (avoids permanent stun).
    if guard_active or damage_reaction_active or rig == null or not bool(rig.get("loading_ok")):
        return
    if step_active:
        _finish_side_step(false)
    if back_somersault_active:
        _cancel_back_somersault()
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
        if landing_from_somersault:
            landing_from_somersault = false
            rig.call("finish_jump", false, false)
    rig.call("start_damage")
    damage_reaction_active = true
    if gesture_active:
        gesture_suppressed_from_damage = true

func _advance_damage_knockback(delta: float) -> void:
    if not damage_reaction_active or damage_knockback_elapsed >= DAMAGE_KNOCKBACK_DURATION * float(part_stats.get("damage_time_mult", 1.0)):
        return
    # Quadratic ease-out: maximum displacement on impact, smoothly settles.
    # Step by the difference of cumulative progress so travel is FPS-independent.
    var duration: float = DAMAGE_KNOCKBACK_DURATION * float(part_stats.get("damage_time_mult", 1.0))
    var old_progress: float = clampf(damage_knockback_elapsed / duration, 0.0, 1.0)
    damage_knockback_elapsed = minf(duration, damage_knockback_elapsed + delta)
    var new_progress: float = damage_knockback_elapsed / duration
    var old_eased: float = 1.0 - pow(1.0 - old_progress, 2.0)
    var new_eased: float = 1.0 - pow(1.0 - new_progress, 2.0)
    # The same swept collision routine used by steps slides along the cube.
    _move_player_swept(damage_knockback_direction * (DAMAGE_KNOCKBACK_DISTANCE * float(part_stats.get("damage_push_mult", 1.0)) * (new_eased - old_eased)), true)

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
    # Camera itself updates each render and must not be interpolated twice.
    camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    camera_player_render_position = player.global_position
    camera_target_render_position = target.global_position
    camera_focus_follow_xz = _desired_camera_follow_focus_xz()
    camera.fov = 61.0  # Vertical FOV; keeps player visible in tall portrait
    camera.near = 0.08
    camera.far = 200.0
    add_child(camera)
    camera.current = true
    camera_yaw = 0.0
    camera_radius = CAMERA_BASE_RADIUS * CAMERA_DISTANCE_SCALE
    camera_follow_radius = CAMERA_BASE_RADIUS * CAMERA_DISTANCE_SCALE
    camera_fit_radius_floor = 0.0
    close_boost_camera_active = false
    camera_combat_hold_remaining = 0.0
    _place_camera()
    # Start behind SERA with a mild 12deg shoulder offset. The old
    # silhouette-search could choose a near-90deg sideways first view.
    var start_delta: Vector2 = Vector2(player.position.x - target.position.x,
        player.position.z - target.position.z)
    var start_bearing: float = atan2(start_delta.x, start_delta.y)
    camera_yaw = start_bearing - deg_to_rad(CAMERA_COMBAT_SHOULDER_DEGREES)
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
    _build_lock_switch_buttons(layer)
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

    # Place the return control between left-side status and right-side telemetry.
    # Its raw touch hit-test below works even when mouse emulation is disabled.
    nexus_button = Button.new()
    nexus_button.name = "ReturnToNexus"
    nexus_button.text = "BACK TO NEXUS"
    nexus_button.position = Vector2(226.0, 59.0)
    nexus_button.size = Vector2(176.0, 35.0)
    nexus_button.focus_mode = Control.FOCUS_NONE
    nexus_button.mouse_filter = Control.MOUSE_FILTER_STOP
    nexus_button.add_theme_font_size_override("font_size", 15)
    nexus_button.add_theme_color_override("font_color", Color("d5faff"))
    var nexus_button_style := StyleBoxFlat.new()
    nexus_button_style.bg_color = Color(0.08, 0.17, 0.22, 0.94)
    nexus_button_style.border_color = Color("3fabb8")
    nexus_button_style.set_border_width_all(1)
    nexus_button_style.set_corner_radius_all(6)
    nexus_button.add_theme_stylebox_override("normal", nexus_button_style)
    nexus_button.add_theme_stylebox_override("hover", nexus_button_style)
    nexus_button.pressed.connect(_request_return_to_nexus)
    hud_panel.add_child(nexus_button)

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
    # Enemy health remains on the right; the SERA HP/EN meters sit together
    # on the top-left inside this existing header without covering the field.
    hp_label.position = Vector2(414.0, 80.0)
    hp_label.add_theme_font_size_override("font_size", 14)
    hp_label.add_theme_color_override("font_color", Color("d3e9ed"))
    hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(hp_label)

    var bar_background := ColorRect.new()
    bar_background.name = "TargetHpBackground"
    bar_background.position = Vector2(414.0, 105.0)
    bar_background.size = Vector2(TARGET_HP_BAR_WIDTH, 7.0)
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

    # Two unobtrusive read-only meters in the top-left: HP above EN.
    # They share the existing header rather than extending over the arena.
    vitals_hud = CombatVitals.new()
    vitals_hud.name = "CombatVitals"
    vitals_hud.position = Vector2(27.0, 62.0)
    vitals_hud.size = Vector2(190.0, 61.0)
    vitals_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(vitals_hud)
    _refresh_player_hp_bar()

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
    resources_label = Label.new()
    resources_label.position = Vector2(226.0, 103.0)
    resources_label.add_theme_font_size_override("font_size", 12)
    resources_label.add_theme_color_override("font_color", Color("bbd9e5"))
    resources_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_panel.add_child(resources_label)
    core_label = Label.new()
    core_label.position = Vector2(22.0, 239.0)
    core_label.add_theme_font_size_override("font_size", 16)
    core_label.add_theme_color_override("font_color", Color("b5e4f5"))
    core_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(core_label)
    target_parts_label = Label.new()
    target_parts_label.name = "TargetPartsStatus"
    target_parts_label.position = Vector2(22.0, 320.0)
    target_parts_label.add_theme_font_size_override("font_size", 13)
    target_parts_label.add_theme_color_override("font_color", Color("e0b8a8"))
    target_parts_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(target_parts_label)
    # Android-safe debug triggers: touches never reach movement/attack gestures.
    test_hit_button = Button.new()
    test_hit_button.name = "DebugIncomingHit"
    test_hit_button.text = "TEST HIT"
    test_hit_button.position = Vector2(22.0, 268.0)
    test_hit_button.size = Vector2(122.0, 42.0)
    test_hit_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(test_hit_button)
    test_break_button = Button.new()
    test_break_button.name = "DebugGuardBreak"
    test_break_button.text = "TEST BREAK"
    test_break_button.position = Vector2(154.0, 268.0)
    test_break_button.size = Vector2(150.0, 42.0)
    test_break_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(test_break_button)
    move_target_button = Button.new()
    move_target_button.name = "DebugTargetMotion"
    move_target_button.text = "MOVE: ON" if target_move_enabled else "MOVE: OFF"
    move_target_button.position = Vector2(314.0, 268.0)
    move_target_button.size = Vector2(148.0, 42.0)
    move_target_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(move_target_button)
    incoming_damage_label = Label.new()
    incoming_damage_label.name = "PlayerDamagePopup"
    incoming_damage_label.position = Vector2(476.0, 275.0)
    incoming_damage_label.add_theme_font_size_override("font_size", 22)
    incoming_damage_label.add_theme_color_override("font_color", Color("ff9c88"))
    incoming_damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    incoming_damage_label.visible = false
    layer.add_child(incoming_damage_label)
    _tick_resources(0.0)

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
    # The second HP bar occupies this row; action hint remains in the README.
    control_hint.text = ""
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
    enemy_debug_ui.call("apply_initial_defaults",
        int(training_settings.get("attack_type", 0)),
        bool(training_settings.get("auto_fire_enabled", true)))
    VersionIndicator.attach(layer)

func _build_lock_switch_buttons(layer: CanvasLayer) -> void:
    # Three lock controls sit on the lower floor portion of the portrait
    # screen, not on top of SERA's body / the boss's legs as in v285.
    # Their gesture exclusion, styling and hit boxes are unchanged.
    var normal_style := StyleBoxFlat.new()
    normal_style.bg_color = Color(0.055, 0.12, 0.17, 0.82)
    normal_style.border_color = Color(0.28, 0.72, 0.78, 0.88)
    normal_style.set_border_width_all(2)
    normal_style.set_corner_radius_all(10)
    var press_style := normal_style.duplicate() as StyleBoxFlat
    press_style.bg_color = Color(0.13, 0.34, 0.41, 0.95)
    var disabled_style := normal_style.duplicate() as StyleBoxFlat
    disabled_style.bg_color = Color(0.055, 0.12, 0.17, 0.38)
    disabled_style.border_color = Color(0.20, 0.36, 0.42, 0.45)
    for direction in [-1, 1]:
        var button := Button.new()
        button.name = "LockSwitchLeft" if direction < 0 else "LockSwitchRight"
        button.text = "◀ LOCK" if direction < 0 else "LOCK ▶"
        button.focus_mode = Control.FOCUS_NONE
        # Android native touch is processed in _input, not Button signals.
        button.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_theme_font_size_override("font_size", 15)
        button.add_theme_color_override("font_color", Color("b9f5ff"))
        button.add_theme_color_override("font_disabled_color", Color("68858c"))
        button.add_theme_stylebox_override("normal", normal_style)
        button.add_theme_stylebox_override("hover", normal_style)
        button.add_theme_stylebox_override("pressed", press_style)
        button.add_theme_stylebox_override("disabled", disabled_style)
        button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO
        button.anchor_bottom = LOCK_CONTROLS_VERTICAL_RATIO
        button.offset_top = CONTROLLER_BUTTON_TOP_INSET
        button.offset_bottom = CONTROLLER_BUTTON_TOP_INSET + LOCK_SWITCH_BUTTON_SIZE.y
        if direction < 0:
            button.anchor_left = CONTROLLER_REGION_START_RATIO
            button.anchor_right = CONTROLLER_REGION_START_RATIO
            button.offset_left = LOCK_SWITCH_EDGE_INSET
            button.offset_right = LOCK_SWITCH_EDGE_INSET + LOCK_SWITCH_BUTTON_SIZE.x
            lock_switch_left_button = button
        else:
            button.anchor_left = 1.0
            button.anchor_right = 1.0
            button.offset_left = -LOCK_SWITCH_EDGE_INSET - LOCK_SWITCH_BUTTON_SIZE.x
            button.offset_right = -LOCK_SWITCH_EDGE_INSET
            lock_switch_right_button = button
        layer.add_child(button)
    lock_mode_button = Button.new()
    lock_mode_button.name = "LockModeToggle"
    lock_mode_button.focus_mode = Control.FOCUS_NONE
    lock_mode_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lock_mode_button.add_theme_font_size_override("font_size", 16)
    lock_mode_button.add_theme_color_override("font_color", Color("f4f9fc"))
    lock_mode_button.add_theme_stylebox_override("normal", normal_style)
    lock_mode_button.add_theme_stylebox_override("hover", normal_style)
    lock_mode_button.add_theme_stylebox_override("pressed", press_style)
    lock_mode_button.anchor_left = 0.75
    lock_mode_button.anchor_right = 0.75
    lock_mode_button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO
    lock_mode_button.anchor_bottom = LOCK_CONTROLS_VERTICAL_RATIO
    lock_mode_button.offset_left = -LOCK_MODE_BUTTON_SIZE.x * 0.5
    lock_mode_button.offset_right = LOCK_MODE_BUTTON_SIZE.x * 0.5
    lock_mode_button.offset_top = CONTROLLER_BUTTON_TOP_INSET
    lock_mode_button.offset_bottom = CONTROLLER_BUTTON_TOP_INSET + LOCK_MODE_BUTTON_SIZE.y
    layer.add_child(lock_mode_button)
    # The optional pair-lines debug control sits BELOW AUTO, leaving all
    # three existing LOCK button hitboxes, size and anchors unchanged.
    lock_lines_button = Button.new()
    lock_lines_button.name = "LockLinesVisibility"
    lock_lines_button.focus_mode = Control.FOCUS_NONE
    lock_lines_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lock_lines_button.add_theme_font_size_override("font_size", 14)
    lock_lines_button.add_theme_color_override("font_color", Color("b9f5ff"))
    lock_lines_button.add_theme_stylebox_override("normal", normal_style)
    lock_lines_button.add_theme_stylebox_override("hover", normal_style)
    lock_lines_button.add_theme_stylebox_override("pressed", press_style)
    lock_lines_button.anchor_left = 0.75
    lock_lines_button.anchor_right = 0.75
    lock_lines_button.anchor_top = LOCK_CONTROLS_VERTICAL_RATIO
    lock_lines_button.anchor_bottom = LOCK_CONTROLS_VERTICAL_RATIO
    lock_lines_button.offset_left = -LOCK_LINES_BUTTON_SIZE.x * 0.5
    lock_lines_button.offset_right = LOCK_LINES_BUTTON_SIZE.x * 0.5
    lock_lines_button.offset_top = (
        CONTROLLER_BUTTON_TOP_INSET + LOCK_MODE_BUTTON_SIZE.y + 8.0)
    lock_lines_button.offset_bottom = (
        lock_lines_button.offset_top + LOCK_LINES_BUTTON_SIZE.y)
    layer.add_child(lock_lines_button)
    _refresh_lock_mode_buttons()
    _refresh_lock_lines_button()


func _refresh_lock_mode_buttons() -> void:
    if lock_mode_button != null:
        lock_mode_button.text = "AUTO" if auto_lock_enabled else "MANUAL"
    if lock_switch_left_button != null:
        lock_switch_left_button.disabled = auto_lock_enabled
    if lock_switch_right_button != null:
        lock_switch_right_button.disabled = auto_lock_enabled


# Lines are world-space, depth-tested, narrow non-colliding beams;
# this is an optional observation aid and must never change lock decisions.
func _build_lock_line_visuals() -> void:
    lock_line_root = Node3D.new()
    lock_line_root.name = "DualLockRayDebug"
    lock_line_root.visible = lock_lines_visible
    add_child(lock_line_root)
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.36, 0.93, 1.0, 0.82)
    material.no_depth_test = false
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    material.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
    for side in range(2):
        var cylinder := CylinderMesh.new()
        cylinder.top_radius = LOCK_LINE_BEAM_RADIUS
        cylinder.bottom_radius = LOCK_LINE_BEAM_RADIUS
        cylinder.height = 1.0
        var line := MeshInstance3D.new()
        line.name = "LeftParallelLockRay" if side == 0 else "RightParallelLockRay"
        line.mesh = cylinder
        line.material_override = material
        line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        lock_line_root.add_child(line)
        lock_line_meshes.append(line)


func _refresh_lock_lines_button() -> void:
    if lock_lines_button != null:
        lock_lines_button.text = "LINES ON" if lock_lines_visible else "LINES OFF"


func _toggle_lock_lines() -> void:
    lock_lines_visible = not lock_lines_visible
    if lock_line_root != null:
        lock_line_root.visible = lock_lines_visible
    _refresh_lock_lines_button()
    if lock_lines_visible:
        _update_lock_line_visuals()


func _update_lock_line_visuals() -> void:
    if not lock_lines_visible or lock_line_root == null \
            or target_parts == null or player == null or target == null:
        return
    # Interpolated positions match the render camera's own coordinate
    # sampling. Both beams use the very same pair-line geometry as AUTO.
    var endpoints: PackedVector3Array = target_parts.call(
        "get_actor_parallel_lock_segments",
        camera_player_render_position, camera_target_render_position)
    if endpoints.size() != 4:
        return
    for side in range(2):
        var from_point: Vector3 = endpoints[side * 2]
        var to_point: Vector3 = endpoints[side * 2 + 1]
        var segment: Vector3 = to_point - from_point
        var line: MeshInstance3D = lock_line_meshes[side]
        if segment.length_squared() < 0.000001:
            line.visible = false
            continue
        line.visible = true
        line.global_position = (from_point + to_point) * 0.5
        line.global_basis = Basis(Quaternion(Vector3.UP, segment.normalized()))
        line.scale = Vector3(1.0, segment.length(), 1.0)


func _toggle_auto_lock_mode() -> void:
    auto_lock_pending_part = ""
    auto_lock_pending_elapsed = 0.0
    auto_lock_enabled = not auto_lock_enabled
    manual_part_lock_active = not auto_lock_enabled
    if auto_lock_enabled:
        # MANUAL can intentionally hold BODY; a fresh AUTO acquires immediately.
        auto_lock_initialized = false
    # Only pre-acquisition emptiness needs the legacy MANUAL center fallback.
    # Do not replace an intentionally selected BODY lock on mode toggle.
    if not auto_lock_enabled and locked_target_part_id.is_empty() \
            and not auto_lock_initialized and target_parts != null and camera != null:
        locked_target_part_id = str(target_parts.call(
            "select_camera_front_part", camera, ""))
    _refresh_lock_mode_buttons()
    _update_target_marker_projection()


# v305: AUTO selection applies on the SAME physics tick as the dual-ray
# intersection test. No pending candidate, debounce or 0.22s confirmation.
# The caller continues to suppress acquisition throughout attack/combo
# retention; MANUAL keeps its independent selection/part-break behavior.
# Keep the historical function signature for compatibility with tests/tools.
func _acquire_stable_camera_part(delta: float,
        current_broken: bool) -> void:
    if target_parts == null or player == null or target == null:
        return
    var center: Vector3 = target.global_position
    var sera_origin: Vector3 = player.global_position
    var preferred: String = str(target_parts.call(
        "select_actor_parallel_lines_part", sera_origin, center))
    locked_target_part_id = preferred
    auto_lock_initialized = true
    auto_lock_pending_part = ""
    auto_lock_pending_elapsed = 0.0


# v305: yaw SERA toward the actual current LOCK target. HEAD and each leg
# use their world-space authored aim/pivot; BODY ("") uses the boss center.
# A broken part retained by an active combo keeps its original aim point.
# Never pitch or roll the collision root toward low/high parts.
func _locked_target_facing_direction() -> Vector3:
    if player == null or target == null:
        return Vector3.ZERO
    var point: Vector3 = target.global_position
    if target_parts != null and not locked_target_part_id.is_empty():
        point = target_parts.call("get_part_aim_world", locked_target_part_id)
    return Vector3(
        point.x - player.global_position.x, 0.0,
        point.z - player.global_position.z)


func _controller_start_area_contains(pos: Vector2) -> bool:
    # v246: The floating controller can start anywhere inside the viewport.
    # _input checks UI button hitboxes before calling this function.
    # An active drag can still cross the entire screen without clamping.
    var screen: Vector2 = get_viewport().get_visible_rect().size
    return (pos.x >= 0.0 and pos.x <= screen.x
        and pos.y >= 0.0 and pos.y <= screen.y)


func _pointer_on_lock_lines_button(pos: Vector2) -> bool:
    return (lock_lines_button != null and lock_lines_button.visible
        and lock_lines_button.get_global_rect().has_point(pos))


func _pointer_on_lock_mode_button(pos: Vector2) -> bool:
    return (lock_mode_button != null and lock_mode_button.visible
        and lock_mode_button.get_global_rect().has_point(pos))


func _lock_switch_direction_at(pos: Vector2) -> int:
    if (lock_switch_left_button != null and lock_switch_left_button.visible
            and lock_switch_left_button.get_global_rect().has_point(pos)):
        return -1
    if (lock_switch_right_button != null and lock_switch_right_button.visible
            and lock_switch_right_button.get_global_rect().has_point(pos)):
        return 1
    return 0


func _switch_lock_screen_direction(direction: int) -> void:
    if (direction == 0 or auto_lock_enabled or target_parts == null
            or camera == null or target_hp <= 0 or training_ko_remaining > 0.0
            or _combo_lock_retention_active()):
        return
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return
    var reference_x: float = viewport_size.x * 0.5
    if not locked_target_part_id.is_empty() and bool(target_parts.call(
            "is_targetable", locked_target_part_id)):
        var current_aim: Vector3 = target_parts.call(
            "get_part_aim_world", locked_target_part_id)
        if not camera.is_position_behind(current_aim):
            reference_x = camera.unproject_position(current_aim).x
    # v291: never discard candidates just because another box intersects
    # the camera ray. Sort projected X, and WRAP at the edge so a manual
    # button always cycles if two or more healthy parts remain visible.
    var candidates: Array = target_parts.call("get_visible_part_ids",
        camera.global_position, _target_hit_aabb())
    var forward_id: String = ""
    var forward_gap: float = INF
    var wrapped_id: String = ""
    var wrapped_x: float = INF if direction > 0 else -INF
    for raw_candidate in candidates:
        var id: String = str(raw_candidate)
        if id == locked_target_part_id:
            continue
        var aim: Vector3 = target_parts.call("get_part_aim_world", id)
        if camera.is_position_behind(aim):
            continue
        var projected: Vector2 = camera.unproject_position(aim)
        # Even an offscreen part remains a viable fallback while the boss
        # is near an edge; projected X is still stable for ordering.
        var gap: float = (projected.x - reference_x) * float(direction)
        if gap > 3.0 and gap < forward_gap:
            forward_gap = gap
            forward_id = id
        if (direction > 0 and projected.x < wrapped_x) or (
                direction < 0 and projected.x > wrapped_x):
            wrapped_x = projected.x
            wrapped_id = id
    var next_id: String = forward_id if not forward_id.is_empty() else wrapped_id
    if next_id.is_empty():
        return
    locked_target_part_id = next_id
    auto_lock_pending_part = ""
    auto_lock_pending_elapsed = 0.0
    manual_part_lock_active = true
    _update_target_marker_projection()


func _update_target_marker_projection() -> void:
    # Camera3D.unproject_position() gives screen coordinates in the viewport.
    # HUD's full-rect Control uses those same pixels; no fixed center offset.
    # Re-read target.global_position: animation / future movement both follow.
    if camera == null or target == null or touch_ui == null:
        return
    var center_world: Vector3 = camera_target_render_position
    # Keep the camera framed on the stable boss center. Only the lock reticle
    # follows the selected head/leg, using the same interpolated target origin.
    if target_parts != null and not locked_target_part_id.is_empty():
        center_world += target_parts.call("get_part_local_aim", locked_target_part_id)
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or camera.is_position_behind(center_world):
        touch_ui.call("set_target_marker_projection", Vector2.ZERO, false)
        return
    var screen_position: Vector2 = camera.unproject_position(center_world)
    # A valid lock may be outside the view, especially when circling a
    # large boss. Show an amber EDGE marker rather than making the lock
    # look disabled. Clamp only the HUD indicator, never the real aim/hit.
    var is_offscreen: bool = (screen_position.x < 0.0
        or screen_position.x > viewport_size.x
        or screen_position.y < 0.0
        or screen_position.y > viewport_size.y)
    var edge_margin: float = 42.0
    var safe_screen: Vector2 = Vector2(
        clampf(screen_position.x, edge_margin, maxf(edge_margin, viewport_size.x-edge_margin)),
        clampf(screen_position.y, edge_margin, maxf(edge_margin, viewport_size.y-edge_margin)))
    touch_ui.call("set_target_marker_projection", safe_screen, true, is_offscreen)


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
    return lerpf(STEP_SPEED, STEP_CLOSE_SPEED, eased) * float(part_stats.get("step_speed_mult", 1.0))

func _refresh_step_status_ui() -> void:
    if step_status_label == null or step_detail_label == null:
        return
    # During a step display its snapshotted speed.
    # Outside a step the HUD shows the pure lateral speed (distance-independent).
    var display_speed: float = step_speed_current
    if not step_active:
        display_speed = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))
    step_status_label.text = "STEP SPEED %.1fm/s" % display_speed
    if back_somersault_active:
        step_detail_label.text = "KICK B / BACK ARC 5.0m"
    elif landing_from_somersault:
        step_detail_label.text = "KICK B / LAND 0.2s"
    elif step_active:
        if side_kick_active:
            step_detail_label.text = "KICK %s %.2fm planned" % [
                "R" if side_kick_side > 0 else "L", step_arc_length]
        elif kick_debug_remaining > 0.0:
            step_detail_label.text = kick_debug_text
        else:
            step_detail_label.text = "STEP %.2fm planned" % step_arc_length
    elif kick_debug_remaining > 0.0:
        step_detail_label.text = kick_debug_text
    elif step_has_last:
        # When a body blocks a step, don't mislabel the planned length as actual.
        step_detail_label.text = "LAST %.2fm  /  %.2fs" % [step_traveled_distance, step_last_elapsed]
    else:
        step_detail_label.text = "SIDE 3.0m / BACK 5.0m"

# Record why an intended combo flick did or did not become a kick.
# Visible for two seconds in the existing debug HUD; no new UI widgets.
func _record_kick_debug(message: String) -> void:
    kick_debug_text = "KICK: " + message
    kick_debug_remaining = 2.0
    _refresh_step_status_ui()


func _pointer_on_training_test_button(pos: Vector2) -> bool:
    if test_hit_button == null or test_break_button == null:
        return false
    return (test_hit_button.get_global_rect().has_point(pos)
        or test_break_button.get_global_rect().has_point(pos)
        or (move_target_button != null
            and move_target_button.get_global_rect().has_point(pos)))

func _press_training_test_button(pos: Vector2) -> void:
    if move_target_button != null and move_target_button.get_global_rect().has_point(pos):
        target_move_enabled = not target_move_enabled
        move_target_button.text = "MOVE: ON" if target_move_enabled else "MOVE: OFF"
        return
    if training_ko_remaining > 0.0:
        return
    if test_break_button != null and test_break_button.get_global_rect().has_point(pos):
        if not guard_active:
            _set_guard(true)
        if guard_active:
            shield = 1.0
    var incoming: Vector3 = player.global_position - target.global_position
    if incoming.length_squared() < 0.000001:
        incoming = Vector3.FORWARD
    _on_enemy_projectile_hit(player.global_position, incoming.normalized(), true, 0)

func _pointer_on_nexus_button(pos: Vector2) -> bool:
    return (nexus_button != null and nexus_button.visible
        and nexus_button.get_global_rect().has_point(pos))

func _pointer_on_step_hud(pos: Vector2) -> bool:
    # v246: Reserve actual interactive UI buttons, not read-only HUD panels.
    # This preserves GUI control without unnecessarily restricting gestures.
    if (handedness_button != null and handedness_button.visible
            and handedness_button.get_global_rect().has_point(pos)):
        return true
    if enemy_debug_ui != null and enemy_debug_ui.visible:
        for gui_node in enemy_debug_ui.find_children("*", "Button", true, false):
            var gui_button := gui_node as Button
            if (gui_button != null and gui_button.is_visible_in_tree()
                    and gui_button.get_global_rect().has_point(pos)):
                return true
    return false

# The body remains on the original XZ plane; lift the visual model to keep
# enlarged soles on that plane, and extend only the capsule's upper envelope.
# Do not touch velocity, the movement controller, or collision radius.
func _update_equipped_collision_height() -> void:
    if rig == null or player_collision_shape == null:
        return
    var lift: float = maxf(0.0, float(rig.call("get_grounding_height_offset")))
    if absf(lift - collision_height_extension) < 0.001:
        return
    collision_height_extension = lift
    var capsule: CapsuleShape3D = player_collision_shape.shape as CapsuleShape3D
    if capsule == null:
        return
    capsule.height = PLAYER_COLLISION_HEIGHT + collision_height_extension
    player_collision_shape.position.y = capsule.height * 0.5

func _on_foot_contact(side: String) -> void:
    if footstep_audio == null or footstep_audio.stream == null:
        return
    if player == null or player.position.y > 0.05:
        return
    # A small pitch alternation keeps repeated mechanical contacts readable.
    footstep_audio.pitch_scale = 0.96 if side == "L" else 1.03
    footstep_audio.play()

func _make_mechanical_footstep() -> AudioStreamWAV:
    # Original short metallic sole impact; 16-bit PCM generated once at startup.
    # No copyrighted sound sample and no continuous CPU audio synthesizer.
    var rate: int = 22050
    var frame_count: int = 3087  # 0.14 s
    var samples := PackedByteArray()
    samples.resize(frame_count * 2)
    var seed: int = 93157
    for i in range(frame_count):
        var t: float = float(i) / float(rate)
        seed = (seed * 1664525 + 1013904223) & 0x7fffffff
        var noise: float = (float(seed % 65536) / 32768.0) - 1.0
        var low: float = sin(TAU * (78.0 * t + 36.0 * t * t)) * exp(-t * 36.0)
        var shell: float = sin(TAU * (440.0 * t + 105.0 * t * t)) * exp(-t * 64.0)
        var edge: float = noise * exp(-t * 110.0)
        var signal_level: float = clampf(low * 0.62 + shell * 0.19 + edge * 0.10, -0.96, 0.96)
        samples.encode_s16(i * 2, roundi(signal_level * 32767.0))
    var sound := AudioStreamWAV.new()
    sound.mix_rate = rate
    sound.format = AudioStreamWAV.FORMAT_16_BITS
    sound.stereo = false
    sound.data = samples
    return sound

func _build_hit_effects() -> void:
    footstep_audio = AudioStreamPlayer.new()
    footstep_audio.name = "GroundFootContact"
    footstep_audio.stream = _make_mechanical_footstep()
    footstep_audio.volume_db = -11.0
    footstep_audio.max_polyphony = 3
    add_child(footstep_audio)
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

func _refresh_player_hp_bar() -> void:
    if vitals_hud == null:
        return
    vitals_hud.call("set_vitals", player_hp,
        float(part_stats.get("max_hp", 800.0)), energy, TEST_EN_MAX, energy_exhausted)

func _refresh_hp_bar() -> void:
    if hp_label == null:
        return
    hp_label.text = "TARGET   %d / %d HP" % [target_hp, TARGET_MAX_HP] if target_hp > 0 else "TARGET   DOWN / RESTARTING"
    hp_fill.size = Vector2(TARGET_HP_BAR_WIDTH * float(target_hp) / float(TARGET_MAX_HP), 7.0)
    hp_fill.color = Color("5de4d1") if float(target_hp) / float(TARGET_MAX_HP) > 0.40 else Color("ffb85d")

func _clear_strike_tracking() -> void:
    strike_did_hit = false
    strike_prev_time = 0.0
    strike_prev_blade = PackedVector3Array()

func _target_hit_aabb() -> AABB:
    # This matches the actual 2m x 2m x 3.4m physical body.
    var extents := Vector3(TARGET_HALF_SIZE, TARGET_HALF_SIZE, TARGET_BODY_HALF_DEPTH)
    return AABB(target.global_position - extents, extents * 2.0)

# A destroyed part stays LOCKED and keeps its original hit volume until
# the committed three-hit/Bash/Kick sequence (including input links) ends.
# New locks still exclude broken candidates via is_targetable().
func _locked_part_hit_volume_available() -> bool:
    return (target_parts != null
        and not locked_target_part_id.is_empty()
        and bool(target_parts.call("has_part", locked_target_part_id))
        and (bool(target_parts.call("is_targetable", locked_target_part_id))
            or _combo_lock_retention_active()))


func _blade_contact(from_pt: Vector3, to_pt: Vector3) -> Variant:
    # Sword sweeps may hit an exterior head or leg without crossing the cube.
    # v251 movement solids are separate; lock-exclusive hit AABBs stay intact.
    if _locked_part_hit_volume_available():
        var part_box: AABB = target_parts.call("get_part_aabb", locked_target_part_id)
        # v249: Locked part is exclusive; never fall through to the core.
        return part_box.grow(BLADE_THICKNESS).intersects_segment(from_pt, to_pt)
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
    var active_from: float = STRIKE_ACTIVE_FROM if _katana_equipped() else float(STRIKE_ACTIVE_FROM_TIMES[strike_index])
    var active_to: float = STRIKE_ACTIVE_TO if _katana_equipped() else float(STRIKE_ACTIVE_TO_TIMES[strike_index])
    var assist_at: float = STRIKE_ASSIST_AT if _katana_equipped() else float(STRIKE_ASSIST_TIMES[strike_index])
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
            _register_strike_hit(contact as Vector3)
        elif interval_end >= assist_at and _distance_to_attack_target_surface(player.position) <= MELEE_HIT_ASSIST_BASE_REACH + 0.08 * float(part_stats.get("tracking", 1.0)):
            # Assist checks the locked part rather than another nearby surface.
            var hit_point: Vector3 = Vector3(
                clampf(player.position.x, target.position.x - TARGET_HALF_SIZE, target.position.x + TARGET_HALF_SIZE),
                target.position.y,
                clampf(player.position.z, target.position.z - TARGET_BODY_HALF_DEPTH, target.position.z + TARGET_BODY_HALF_DEPTH)
            )
            if _locked_part_hit_volume_available():
                var part_box: AABB = target_parts.call("get_part_aabb", locked_target_part_id)
                hit_point = Vector3(
                    clampf(player.position.x, part_box.position.x, part_box.end.x),
                    part_box.get_center().y,
                    clampf(player.position.z, part_box.position.z, part_box.end.z))
            _register_strike_hit(hit_point)
    strike_prev_time = strike_t
    strike_prev_blade = blade

func _apply_target_part_damage(kind: String, raw_attack: int, raw_break: float,
        weak_stagger: float, extension: float) -> Dictionary:
    # A-type damage: one confirmed contact reduces common boss HP AND the
    # locked part's independent break gauge. The two powers are independent.
    var hp_before_hit: int = target_hp
    var result: Dictionary = {
        "body_damage": 0, "part_damage": 0.0, "broken": false
    }
    if target_hp > 0 and target_parts != null:
        result = target_parts.call(
            "apply_part_hit", locked_target_part_id, raw_attack, raw_break)
        # Every strike/Bash/kick hit now animates the struck module too,
        # including a part just destroyed or already broken in this combo.
        target_parts.call("trigger_part_hit_fx",
            locked_target_part_id, HIT_FLASH_SECONDS)
        # A part hit must not flash the central BODY. Conversely, BODY
        # hits have no part ID and only run the core material flash.
        # Use the LOCKED ID even if a broken part is held by a combo:
        # apply_part_hit() may report BODY damage for its broken gauge.
        hit_flash_remaining = (
            HIT_FLASH_SECONDS if locked_target_part_id.is_empty() else 0.0)
        target_hp = maxi(0, target_hp - int(result["body_damage"]))
        _register_test_hit(weak_stagger, extension)
        if bool(result["broken"]):
            # Every break causes a stronger reaction. Two leg breaks satisfy
            # this training boss's explicitly configurable long-down rule.
            part_break_remaining = maxf(part_break_remaining, 1.0)
            stagger_remaining = 0.0
            stagger_value = 0.0
            if str(result["kind"]) == "leg" and int(result["broken_legs"]) >= 2:
                part_break_remaining = maxf(part_break_remaining, 3.5)
            elif str(result["kind"]) == "head" and enemy_shooter != null:
                enemy_shooter.call("set_head_destroyed", true)
            # Keep the broken ID and its hitbox until all linked attacks
            # and 0.65s input windows have finished; reacquire only then.
    var actual_damage: int = hp_before_hit - target_hp
    result["applied_damage"] = actual_damage
    SeraSave.record_target_hit(kind, actual_damage,
        hp_before_hit > 0 and target_hp == 0)
    if hp_before_hit > 0 and target_hp == 0:
        target_respawn_remaining = TARGET_RESPAWN_SECONDS
    _refresh_hp_bar()
    return result

func _register_strike_hit(world_hit: Vector3) -> void:
    if strike_did_hit:
        return
    strike_did_hit = true
    var hit_part: String = locked_target_part_id
    var damages: Array = part_stats.get("attack_damage", STRIKE_DAMAGE)
    var strike_damage: int = roundi(float(damages[strike_index]) * float(part_stats.get("attack_mult", 1.0)))
    var breaks: Array = part_stats.get("break_damage", [14, 14, 32])
    var staggers: Array = part_stats.get("stagger_gain", [10.0, 10.0, 24.0])
    var result: Dictionary = _apply_target_part_damage("melee", strike_damage,
        float(breaks[strike_index]), float(staggers[strike_index]),
        float(part_stats.get("stagger_extend", 0.18)))
    hit_stop_remaining = HIT_STOP_SECONDS
    damage_popup_remaining = 0.58
    impact_origin = _part_hit_surface(hit_part, world_hit)
    rig.call("set_combat_paused", true)
    damage_label.text = "%d" % int(result["applied_damage"])
    damage_label.visible = true
    var strike_sound: AudioStreamPlayer = melee_finisher_audio if _is_strike_finisher() else hit_audio
    if is_instance_valid(strike_sound) and strike_sound.stream != null:
        strike_sound.play()
    _spawn_sparks(impact_origin)
    if sword_trail != null:
        sword_trail.call("on_hit", impact_origin)

# Reuse melee1 equipment damage parameters for this single foot impact.
# No sword trail or shield burst; the STEP collision sweep stays intact.
func _register_side_kick_hit() -> void:
    side_kick_did_hit = true
    var hit_part: String = locked_target_part_id
    var damages: Array = part_stats.get("attack_damage", STRIKE_DAMAGE)
    var breaks: Array = part_stats.get("break_damage", [14, 14, 32])
    var staggers: Array = part_stats.get("stagger_gain", [10.0, 10.0, 24.0])
    var damage: int = roundi(float(damages[0]) *
        float(part_stats.get("attack_mult", 1.0)))
    var result: Dictionary = _apply_target_part_damage("melee", damage,
        float(breaks[0]), float(staggers[0]),
        float(part_stats.get("stagger_extend", 0.18)))
    var closest: Vector3 = Vector3(
        clampf(player.position.x, target.position.x - TARGET_HALF_SIZE, target.position.x + TARGET_HALF_SIZE),
        target.position.y,
        clampf(player.position.z, target.position.z - TARGET_BODY_HALF_DEPTH, target.position.z + TARGET_BODY_HALF_DEPTH))
    impact_origin = _part_hit_surface(hit_part, closest)
    damage_popup_remaining = 0.58
    damage_label.text = "%d" % int(result["applied_damage"])
    damage_label.visible = true
    if is_instance_valid(hit_audio) and hit_audio.stream != null:
        hit_audio.play()
    _spawn_sparks(impact_origin)


func _part_hit_surface(id: String, hit: Vector3) -> Vector3:
    if target_parts == null or id.is_empty():
        return _visible_hit_surface(hit)
    # Even on the breaking blow, place sparks on the struck limb, not the core.
    var box: AABB = target_parts.call("get_part_aabb", id)
    var visible: Vector3 = hit.clamp(box.position, box.end)
    var toward_camera: Vector3 = camera.global_position - box.get_center()
    if absf(toward_camera.x) > absf(toward_camera.z):
        visible.x = box.get_center().x + signf(toward_camera.x) * (box.size.x * 0.5 + 0.035)
    else:
        visible.z = box.get_center().z + signf(toward_camera.z) * (box.size.z * 0.5 + 0.035)
    return visible

func _visible_hit_surface(hit: Vector3) -> Vector3:
    # Collision/assist can report an interior point; project its spark onto
    # the camera-facing surface of the elongated rectangular body.
    var visible: Vector3 = Vector3(
        clampf(hit.x, target.global_position.x - TARGET_HALF_SIZE, target.global_position.x + TARGET_HALF_SIZE),
        clampf(hit.y, target.global_position.y - TARGET_HALF_SIZE, target.global_position.y + TARGET_HALF_SIZE),
        clampf(hit.z, target.global_position.z - TARGET_BODY_HALF_DEPTH, target.global_position.z + TARGET_BODY_HALF_DEPTH)
    )
    var toward_camera: Vector3 = camera.global_position - target.global_position
    if absf(toward_camera.x) > absf(toward_camera.z):
        visible.x = target.global_position.x + signf(toward_camera.x) * (TARGET_HALF_SIZE + 0.035)
    else:
        visible.z = target.global_position.z + signf(toward_camera.z) * (TARGET_BODY_HALF_DEPTH + 0.035)
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
    # TargetBreakableParts is a CHILD of target_mesh. Moving/rotating
    # that parent on any BODY hit would wobble every head/leg together,
    # even though their materials and own pivots are otherwise isolated.
    # Keep the parent transform fixed; core retains its dark-red material
    # flash, and only the actual struck limb gets a localized visual wobble.
    if target_mesh != null:
        target_mesh.position = Vector3.ZERO
        target_mesh.rotation_degrees.z = 0.0
    if target_parts != null:
        target_parts.call("advance_part_hit_fx", delta)
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
    incoming_damage_remaining = maxf(0.0, incoming_damage_remaining - delta)
    if incoming_damage_label != null and incoming_damage_label.visible:
        incoming_damage_label.modulate.a = minf(1.0, incoming_damage_remaining / 0.18)
        if incoming_damage_remaining <= 0.0:
            incoming_damage_label.visible = false
    if target_respawn_remaining > 0.0:
        target_respawn_remaining = maxf(0.0, target_respawn_remaining - delta)
        if target_respawn_remaining <= 0.0 and _combo_lock_retention_active():
            # A full boss KO must not reset/erase the locked broken part
            # while a queued combo is still animating. Retry on next tick.
            target_respawn_remaining = 0.01
        elif target_respawn_remaining == 0.0:
            target_hp = TARGET_MAX_HP
            if target_parts != null:
                target_parts.call("reset_parts")
            locked_target_part_id = ""
            auto_lock_initialized = false
            auto_lock_pending_part = ""
            auto_lock_pending_elapsed = 0.0
            manual_part_lock_active = not auto_lock_enabled
            if enemy_shooter != null:
                enemy_shooter.call("set_head_destroyed", false)
            stagger_value = 0.0
            stagger_remaining = 0.0
            part_break_remaining = 0.0
            _refresh_hp_bar()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            # Any new finger press cancels a prior tap ripple immediately,
            # including taps on HUD buttons (which must keep their own input).
            if touch_ui != null:
                touch_ui.call("cancel_gesture_effects")
            if _pointer_on_lock_lines_button(event.position):
                step_hud_touch = event.index
                _toggle_lock_lines()
                get_viewport().set_input_as_handled()
                return
            if _pointer_on_lock_mode_button(event.position):
                step_hud_touch = event.index
                _toggle_auto_lock_mode()
                get_viewport().set_input_as_handled()
                return
            var switch_direction: int = _lock_switch_direction_at(event.position)
            if switch_direction != 0:
                step_hud_touch = event.index
                _switch_lock_screen_direction(switch_direction)
                get_viewport().set_input_as_handled()
                return
            if _pointer_on_training_test_button(event.position):
                step_hud_touch = event.index
                _press_training_test_button(event.position)
                get_viewport().set_input_as_handled()
                return
            if _pointer_on_nexus_button(event.position):
                step_hud_touch = event.index
                _request_return_to_nexus()
                get_viewport().set_input_as_handled()
                return
            if _pointer_on_step_hud(event.position):
                # GUI handles the button event; gameplay owns no such touch.
                step_hud_touch = event.index
                return
            if current_touch < 0 and _controller_start_area_contains(event.position):
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
                if touch_ui != null:
                    touch_ui.call("cancel_gesture_effects")
                if _pointer_on_lock_lines_button(event.position):
                    step_hud_mouse_press = true
                    _toggle_lock_lines()
                    get_viewport().set_input_as_handled()
                    return
                if _pointer_on_lock_mode_button(event.position):
                    step_hud_mouse_press = true
                    _toggle_auto_lock_mode()
                    get_viewport().set_input_as_handled()
                    return
                var switch_direction: int = _lock_switch_direction_at(event.position)
                if switch_direction != 0:
                    step_hud_mouse_press = true
                    _switch_lock_screen_direction(switch_direction)
                    get_viewport().set_input_as_handled()
                    return
                if _pointer_on_training_test_button(event.position):
                    step_hud_mouse_press = true
                    _press_training_test_button(event.position)
                    get_viewport().set_input_as_handled()
                    return
                if _pointer_on_nexus_button(event.position):
                    step_hud_mouse_press = true
                    _request_return_to_nexus()
                    get_viewport().set_input_as_handled()
                    return
                if _pointer_on_step_hud(event.position):
                    step_hud_mouse_press = true
                    return
                if not _controller_start_area_contains(event.position):
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
    return (not guard_active and not damage_reaction_active and down_remaining <= 0.0
        and not (energy_exhausted and bool(part_stats.get("energy_shield", false)))
        and guard_break_remaining <= 0.0 and not landing_active
        and not jump_active and not step_active and not back_somersault_active
        and combat_state == CombatState.IDLE
        and rig != null and bool(rig.get("loading_ok")))

func _set_guard(active: bool) -> void:
    if active == guard_active:
        return
    if active:
        if not _guard_can_start():
            return
        guard_active = true
        bash_followup_window_remaining = 0.0
        bash_loop_window_remaining = 0.0
        direction_input = Vector2.ZERO
        player.velocity = Vector3.ZERO
        movement_boost_active = false
        boost_confirm_elapsed = 0.0
        boost_has_activated_this_gesture = false
        _reset_boost_speed_transition()
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
    if back_somersault_active or landing_active:
        return
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
    # Keep this projected axis for existing camera/debug/guard diagnostics.
    # All actual combo and Bash flick decisions are fixed SCREEN sectors.
    gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)
    guard_flick_axis_captured = false
    # Preserve the third strike while classifying a screen-UP Bash flick;
    # unrelated drags still cancel attacks as before.
    bash_flick_candidate = ((combat_state == CombatState.STRIKE
        or combat_state == CombatState.STRIKE_TRACK)
        and _is_strike_finisher()) or (
        combat_state == CombatState.IDLE and bash_followup_window_remaining > 0.0)
    # Accept lateral kick input DURING the last authored strike as a buffer.
    # It launches at Melee3's dedicated flick cancel point. Touch-down
    # during the 0.65s post-finisher link is also accepted.
    side_kick_flick_candidate = (
        ((combat_state == CombatState.STRIKE or combat_state == CombatState.STRIKE_TRACK)
            and _is_strike_finisher())
        or (combat_state == CombatState.IDLE and bash_followup_window_remaining > 0.0))
    kick_touch_started_in_window = side_kick_flick_candidate
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
    _reset_boost_speed_transition()
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
    # full RUN speed is reached at the v245 70px rim.
    var strength: float = clampf(
        (distance - RUN_INPUT_DEADZONE_PIXELS) /
        (RUN_CONTROL_RADIUS - RUN_INPUT_DEADZONE_PIXELS), 0.0, 1.0)
    return displacement / distance * strength

func _change_drag(pos: Vector2) -> void:
    if not gesture_active:
        return
    if back_somersault_active:
        # The committed arc is not steerable or cancellable by another drag.
        pointer_location = pos
        direction_input = Vector2.ZERO
        return
    if guard_active:
        # GUARD may outlast idle camera orbit. Reacquire SERA's visible
        # facing at the final flick onset, then keep it until release.
        if not guard_flick_axis_captured and pos.distance_to(pointer_origin) >= TAP_MAX_TRAVEL:
            gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)
            guard_flick_axis_captured = true
        pointer_location = pos
        _remember_jump_flick_sample(pos)
        return
    pointer_location = pos
    _remember_jump_flick_sample(pos)
    gesture_max_travel = maxf(gesture_max_travel, pos.distance_to(pointer_origin))
    var displacement: Vector2 = pos - pointer_origin
    if bash_flick_candidate and gesture_max_travel > BASH_FLICK_CANDIDATE_GRACE_PIXELS:
        # Initial finger wobble will not immediately cancel the combo.
        # Candidate and final Bash both use the fixed 90deg screen-UP sector.
        if not FLICK_DIRECTION_POLICY.within_sector(
                displacement, Vector2.UP, STEP_FLICK_MAX_HORIZONTAL_RATIO):
            bash_flick_candidate = false
    # Keep the post-finisher kick reservation through intermediate diagonal
    # thumb movement. Only the RELEASE direction chooses kick vs other STEP.
    # Expired/long gestures still fall back to ordinary RUN/BOOST handling.
    if side_kick_flick_candidate and (
            float(Time.get_ticks_msec() - gesture_start_ms) / 1000.0 > BASH_FLICK_MAX_SECONDS):
        side_kick_flick_candidate = false
    # Reserve short lateral release before interpreting RUN.
    direction_input = Vector2.ZERO if (bash_flick_candidate or side_kick_flick_candidate) else _analog_stick_direction(pos)
    touch_ui.call("set_analog_direction", direction_input)
    # BOOST uses the existing 110% entry and 90% exit ratios at half-size.
    _update_boost_gesture(0.0)
    # A RUN/BOOST drag cancels the post-finisher links immediately.
    if direction_input.length_squared() > 0.000001 or movement_boost_active:
        _cancel_combo_followup_windows_for_movement()
    if gesture_max_travel > TAP_MAX_TRAVEL:
        if step_active and not jump_active:
            _finish_side_step(true)
        if combat_state != CombatState.IDLE and not (bash_flick_candidate or side_kick_flick_candidate):
            _cancel_attack()
    # The compact RUN ring rotates its indicator without moving its anchor.
    touch_ui.call("show_drag", pointer_origin, pointer_location, DRAG_RADIUS)

func _update_boost_gesture(delta: float) -> void:
    # Gate BOOST only while the damage reaction is actually in progress.
    # gesture_suppressed_from_damage is deliberately latched until release to
    # prevent a damaged hold from triggering a phantom STEP or tap attack;
    # it must NOT block BOOST after the damage reaction finishes.
    if not gesture_active or guard_active or damage_reaction_active \
            or energy_exhausted or bash_flick_candidate or side_kick_flick_candidate \
            or jump_active or landing_active or back_somersault_active:
        boost_confirm_elapsed = 0.0
        if movement_boost_active:
            movement_boost_active = false
            touch_ui.call("set_movement_boost", false)
        return
    # Preserve the held pointer/direction across EN exhaustion. Unlocking at
    # 60% may restart BOOST on this very same outer-ring gesture.
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
        # Guard takes priority; only a brisk forward flick ON RELEASE may
        # change it into Bash, never ordinary movement or an attack tap.
        pointer_location = release_pos
        _remember_jump_flick_sample(release_pos)
        # If Android coalesces drag into release only, sample the current
        # projected body facing; the touch origin/marker are irrelevant.
        if not guard_flick_axis_captured:
            gesture_screen_forward = FLICK_DIRECTION_POLICY.projected_forward(camera, player)
        var guard_bash_requested: bool = _classify_recent_character_forward_flick() and not keyboard_guard_held
        # A long-held guard responds to a short final facing-direction swipe.
        var guard_flick_origin: Vector2 = pointer_origin
        if not jump_flick_samples.is_empty():
            guard_flick_origin = jump_flick_samples[0]["pos"]
        bash_flick_candidate = false
        # Consume the whole hold, including any movement made before release.
        # Keyboard G may continue Guard after the finger lifts.
        gesture_active = false
        gesture_suppressed_from_damage = false
        gesture_suppressed_from_landing = false
        direction_input = Vector2.ZERO
        movement_boost_active = false
        boost_confirm_elapsed = 0.0
        boost_has_activated_this_gesture = false
        _reset_boost_speed_transition()
        boost_pose_grace_remaining = 0.0
        jump_flick_samples.clear()
        touch_ui.call("set_movement_boost", false)
        touch_ui.call("hide_drag")
        if not keyboard_guard_held:
            _set_guard(false)
            if guard_bash_requested:
                _start_bash()
                if combat_state == CombatState.BASH_TRACK:
                    touch_ui.call("show_flick_wake", guard_flick_origin, release_pos)
        return
    # Include release coordinates: some devices coalesce the final drag event.
    pointer_location = release_pos
    _remember_jump_flick_sample(release_pos)
    gesture_max_travel = maxf(gesture_max_travel, release_pos.distance_to(pointer_origin))
    var press_duration: float = float(Time.get_ticks_msec() - gesture_start_ms) / 1000.0
    var was_tap: bool = (gesture_max_travel <= TAP_MAX_TRAVEL
        and press_duration <= TAP_MAX_DURATION)
    var bash_requested: bool = (bash_flick_candidate
        and not boost_has_activated_this_gesture
        and _is_character_forward_flick(release_pos - pointer_origin, press_duration)
        and gesture_max_travel <= (release_pos - pointer_origin).length() * BASH_FLICK_REVERSAL_RATIO)
    var side_kick_requested: bool = (side_kick_flick_candidate
        and not boost_has_activated_this_gesture)
    var kick_started_eligible: bool = kick_touch_started_in_window
    kick_touch_started_in_window = false
    bash_flick_candidate = false
    side_kick_flick_candidate = false
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
    var flick_direction: Vector2 = Vector2.ZERO if suppress_flick else _classify_step_flick(
        release_pos - pointer_origin, press_duration)
    # Melee3 reserves a valid flick until 0.1s after the final swing;
    # Kick uses the Bash 0.42s threshold; normal STEP stays at 0.24s.
    var kick_flick_direction: Vector2 = Vector2.ZERO if suppress_flick or not side_kick_requested \
        else _classify_combo_kick_flick(release_pos - pointer_origin, press_duration)
    var takeoff_momentum: Vector3 = gesture_start_ground_velocity if jump_from_initial_flick else Vector3(player.velocity.x, 0.0, player.velocity.z)
    gesture_active = false
    var suppress_release_action: bool = gesture_suppressed_from_damage or gesture_suppressed_from_landing
    gesture_suppressed_from_damage = false
    gesture_suppressed_from_landing = false
    direction_input = Vector2.ZERO
    movement_boost_active = false
    boost_confirm_elapsed = 0.0
    boost_has_activated_this_gesture = false
    _reset_boost_speed_transition()
    boost_pose_grace_remaining = 0.0
    jump_flick_samples.clear()
    touch_ui.call("set_movement_boost", false)
    touch_ui.call("hide_drag")
    if damage_reaction_active or landing_active or back_somersault_active or suppress_release_action:
        return  # Airborne somersault and landing own the input until fully complete.
    # A screen-left/right/down combo swipe MUST resolve to a kick before
    # screen-UP Bash or general 360-degree STEP. If it does not,
    # show the reason in the existing debug panel for recorded phone tests.
    var screen_sector: int = FLICK_DIRECTION_POLICY.sector_index(
        release_pos - pointer_origin, Vector2.UP)
    var recent_finisher: bool = (Time.get_ticks_msec() - last_melee3_finished_ms < 1600)
    if side_kick_requested and kick_flick_direction.length_squared() > 0.000001 \
            and _combo_kick_side_for_flick(kick_flick_direction) != 0:
        if _request_combo_side_kick(kick_flick_direction):
            touch_ui.call("show_flick_wake", pointer_origin, release_pos)
        return
    if kick_started_eligible and screen_sector in [1, 2, 3]:
        if not side_kick_requested:
            _record_kick_debug("HOLD >0.42s / BOOST")
        elif kick_flick_direction.length_squared() < 0.000001:
            _record_kick_debug("TOO SHORT / SLOW")
        else:
            _record_kick_debug("ANGLE")
    elif recent_finisher and screen_sector in [1, 2, 3] \
            and (release_pos - pointer_origin).length() >= BASH_FLICK_MIN_FORWARD_PIXELS:
        _record_kick_debug("WINDOW CLOSED")
    if bash_requested and _request_combo_bash():
        touch_ui.call("show_flick_wake", pointer_origin, release_pos)
        return
    if jump_requested:
        _start_jump(takeoff_momentum)
        if jump_active:
            touch_ui.call("show_flick_wake", pointer_origin, release_pos)
    elif flick_direction.length_squared() > 0.000001:
        if _start_omni_step(flick_direction):
            touch_ui.call("show_flick_wake", pointer_origin, release_pos)
    elif was_tap:
        # The finger has already been released; play feedback only if the
        # combat state accepted this tap (including buffered combo inputs).
        if _start_attack():
            touch_ui.call("show_attack_ripple", release_pos)

func _remember_jump_flick_sample(pos: Vector2) -> void:
    var now_ms: int = Time.get_ticks_msec()
    jump_flick_samples.append({"ms": now_ms, "pos": pos})
    # GUARD Bash gets a larger tail for a slower, shorter final flick.
    # Archived debug-only Jump retains its original 0.20s sample window.
    var tail_seconds: float = BASH_FLICK_TAIL_SECONDS if guard_active else JUMP_FLICK_TAIL_SECONDS
    while jump_flick_samples.size() > 1 and now_ms - int(jump_flick_samples[0]["ms"]) > int(tail_seconds * 1000.0):
        jump_flick_samples.pop_front()
    if jump_flick_samples.size() > 32:
        jump_flick_samples.pop_front()

# v284: Bash is SCREEN-UP; actor yaw must never change the gesture mapping.
# Preserve the method name for existing guard/flick call sites.
func _is_character_forward_flick(displacement: Vector2, seconds: float) -> bool:
    return FLICK_DIRECTION_POLICY.is_flick(
        displacement, seconds, Vector2.UP,
        BASH_FLICK_MAX_SECONDS, BASH_FLICK_MIN_FORWARD_PIXELS,
        BASH_FLICK_MIN_FORWARD_SPEED, STEP_FLICK_MAX_HORIZONTAL_RATIO)

func _classify_recent_character_forward_flick() -> bool:
    if jump_flick_samples.size() < 2:
        return false
    var first: Dictionary = jump_flick_samples[0]
    var last: Dictionary = jump_flick_samples[jump_flick_samples.size() - 1]
    var duration: float = float(int(last["ms"]) - int(first["ms"])) / 1000.0
    return _is_character_forward_flick(
        (last["pos"] as Vector2) - (first["pos"] as Vector2), duration)

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
    _reset_boost_speed_transition()
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

func _begin_landing(from_back_somersault: bool = false) -> void:
    landing_from_somersault = from_back_somersault
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
    rig.call("start_landing", from_back_somersault)

func _advance_landing(delta: float) -> void:
    if not landing_active:
        return
    landing_elapsed += maxf(delta, 0.0)
    player.velocity = Vector3.ZERO
    # Archived Jump remains 0.125s + 0.60s hold. Only Kick_b uses the
    # authored Jump landing keys at 0.20s with no subsequent static hold.
    var duration: float = (BACK_SOMERSAULT_LANDING_SECONDS
        if landing_from_somersault else JUMP_LANDING_MOTION_SECONDS)
    var hold: float = 0.0 if landing_from_somersault else JUMP_LANDING_HOLD_SECONDS
    var landing_fraction: float = clampf(landing_elapsed / duration, 0.0, 1.0)
    if rig != null:
        rig.call("set_landing_progress", landing_fraction)
    if landing_elapsed >= duration + hold:
        var was_somersault_landing: bool = landing_from_somersault
        landing_active = false
        landing_elapsed = 0.0
        landing_from_somersault = false
        if was_somersault_landing and gesture_active:
            # The kickoff of Kick_b zeroes the old movement vector. If a
            # finger is already held at touchdown, re-read that SAME stick
            # position instead of waiting for an extra Android motion event
            # before RUN can begin again.
            direction_input = _analog_stick_direction(pointer_location)
            if touch_ui != null:
                touch_ui.call("set_analog_direction", direction_input)
        if rig != null:
            rig.call("finish_jump",
                gesture_active and direction_input.length_squared() > 0.000001, false)

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

func _classify_step_flick(displacement: Vector2, seconds: float) -> Vector2:
    # v262: preserve any 360deg screen flick as one STEP vector for
    # both world movement and four-clip animation interpolation.
    # Bash remains a separate SERA-facing, four-sector action.
    # Hold, BOOST suppression, Bash priority, reversal filtering and
    # archived debug-only Jump retain their existing precedence.
    if seconds <= 0.0 or seconds > STEP_FLICK_MAX_SECONDS:
        return Vector2.ZERO
    var distance: float = displacement.length()
    if distance < STEP_FLICK_MIN_HORIZONTAL:
        return Vector2.ZERO
    if distance / seconds < STEP_FLICK_MIN_PIXELS_PER_SEC:
        return Vector2.ZERO
    if gesture_max_travel > distance * 1.20:
        return Vector2.ZERO
    # Exact angle is preserved; cardinal and diagonal motions share input.
    return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)

# The same Bash-like flick timing applies to every fixed SCREEN quadrant.
# Kick selection is unrelated to target-facing orientation.
func _classify_combo_kick_flick(displacement: Vector2, seconds: float) -> Vector2:
    if seconds <= 0.0 or seconds > BASH_FLICK_MAX_SECONDS:
        return Vector2.ZERO
    var distance: float = displacement.length()
    if distance < BASH_FLICK_MIN_FORWARD_PIXELS:
        return Vector2.ZERO
    if distance / seconds < BASH_FLICK_MIN_FORWARD_SPEED:
        return Vector2.ZERO
    if gesture_max_travel > distance * BASH_FLICK_REVERSAL_RATIO:
        return Vector2.ZERO
    return FLICK_DIRECTION_POLICY.screen_step_direction(displacement)

# v284: Every Melee3 flick uses fixed SCREEN sectors: UP is Bash,
# RIGHT Kick_r, DOWN Kick_b, LEFT Kick_l. Facing/camera recentering can
# never reclassify the same finger motion into a different attack.
func _combo_kick_side_for_flick(flick: Vector2) -> int:
    var screen_sector: int = FLICK_DIRECTION_POLICY.sector_index(
        flick, Vector2.UP)
    match screen_sector:
        1:
            return 1  # screen right -> Kick_r
        2:
            return 2  # screen down -> Kick_b
        3:
            return -1  # screen left -> Kick_l
        _:
            return 0  # screen up -> Bash (handled by _request_combo_bash)


# Historical local-space diagnostic kept for older tooling. Ordinary STEP
# clip selection no longer uses this transform: flick pose is screen-relative
# so RIGHT always uses Step_R, even during lock-on turns (v310).
func _step_local_pose_direction(world_direction: Vector3) -> Vector2:
    if world_direction.length_squared() < 0.000001:
        return Vector2.UP
    var facing: Vector3 = _locked_target_facing_direction()
    if facing.length_squared() < 0.000001:
        facing = -player.global_transform.basis.z
    facing.y = 0.0
    if facing.length_squared() < 0.000001:
        return Vector2.UP
    facing = facing.normalized()
    var right: Vector3 = facing.cross(Vector3.UP)
    var world_unit: Vector3 = world_direction.normalized()
    return Vector2(world_unit.dot(right), -world_unit.dot(facing)).normalized()

# Kick sectors are fixed SCREEN left/right/down. Travel stays screen-relative.
# An unavailable kick consumes a reserved lateral gesture (never STEP).
func _request_combo_side_kick(flick: Vector2) -> bool:
    # _end_drag calls this only for a kick gesture latched during _begin_drag.
    # The 0.65s follow-up window must be checked on touch-down, NOT again on
    # release: a valid flick may outlast the remaining window by up to 0.24s.
    var side: int = _combo_kick_side_for_flick(flick)
    if side == 0:
        return false
    if rig == null:
        _record_kick_debug("CLIP MISSING RIG")
        return false
    # Kick_b uses a genuine authored clip when present. Until the uploaded
    # .bbmodel includes Kick_b, the same action has an explicit Jump-pose +
    # rotating-body fallback (not a phantom CLIP MISSING).
    if side != 2 and not bool(rig.call("has_side_kick", side)):
        _record_kick_debug("CLIP MISSING " + str(rig.call("get_side_kick_diagnostic", side)))
        return false
    if (combat_state == CombatState.STRIKE or combat_state == CombatState.STRIKE_TRACK) \
            and _is_strike_finisher():
        buffered_side_kick_flick = flick.normalized()
        buffered_side_kick_side = side
        bash_queued = false  # Latest combo direction wins.
        _record_kick_debug("QUEUED " + ("B" if side == 2 else ("R" if side > 0 else "L")))
        return true
    if combat_state != CombatState.IDLE:
        _record_kick_debug("STATE BLOCKED")
        return false
    return _launch_combo_side_kick(flick, side)


func _launch_combo_side_kick(flick: Vector2, side: int) -> bool:
    if side == 2:
        var launched: bool = (_start_back_somersault()
            if _distance_to_attack_target_surface(player.position) <= BASH_REACH
            else _start_back_kick_track())
        _record_kick_debug("START B" if launched else "B EN / ACTION BLOCKED")
        return launched
    if (side != 1 and side != -1) or rig == null \
            or not bool(rig.call("has_side_kick", side)):
        return false
    step_kick_side_request = side
    var started: bool = _start_omni_step(flick)
    step_kick_side_request = 0
    _record_kick_debug(("START " + ("R" if side > 0 else "L")) if started
        else "EN / ACTION BLOCKED")
    return started


# Same maximum 0.2s lock-on approach as Bash, before (never during) rear flight.
func _start_back_kick_track() -> bool:
    if (guard_active or damage_reaction_active or landing_active or jump_active
            or step_active or back_somersault_active
            or combat_state != CombatState.IDLE or rig == null
            or not bool(rig.get("loading_ok"))):
        return false
    if energy_exhausted or energy < 15.0 * float(part_stats.get("energy_cost_mult", 1.0)):
        return false
    combat_state = CombatState.BACK_KICK_TRACK
    back_kick_track_elapsed = 0.0
    direction_input = Vector2.ZERO
    movement_boost_active = false
    boost_confirm_elapsed = 0.0
    _reset_boost_speed_transition()
    _cancel_combo_followup_windows_for_movement()
    rig.call("start_melee_approach")
    return true

# Backward somersault is a distinct aerial combo, NOT a STEP: the 5m
# displacement is behind SERA / away from the lock target even when the
# on-screen DOWN flick points in a different world direction. A 1.5m arc
# keeps player collision physically airborne, with a single foot impact.
# Capture the opposite target heading only AFTER homing is shut off,
# so the retreat arc starts precisely at the kick impact location.
func _capture_back_somersault_retreat_direction() -> void:
    back_somersault_direction = player.global_position - target.global_position
    back_somersault_direction.y = 0.0
    if back_somersault_direction.length_squared() < 0.000001:
        back_somersault_direction = player.global_transform.basis.z
        back_somersault_direction.y = 0.0
    back_somersault_direction = back_somersault_direction.normalized()


func _start_back_somersault() -> bool:
    if (back_somersault_active or landing_active or jump_active or step_active
            or guard_active or damage_reaction_active
            or combat_state != CombatState.IDLE or rig == null
            or not bool(rig.get("loading_ok"))):
        return false
    if not _spend_energy(15.0 * float(part_stats.get("energy_cost_mult", 1.0))):
        return false
    if not bool(rig.call("start_back_somersault")):
        return false
    _cancel_combo_followup_windows_for_movement()
    back_somersault_active = true
    back_somersault_launched = false
    back_somersault_elapsed = 0.0
    back_somersault_hit = false
    back_somersault_hit_checked = false
    back_somersault_start = player.position
    back_somersault_original_rig_y = rig.position.y
    back_somersault_has_authored_clip = bool(rig.call("back_somersault_uses_authored_clip"))
    # The final retreat vector is captured AT CONTACT, after the last
    # homing movement; the initial fallback is kept for animation setup.
    _capture_back_somersault_retreat_direction()
    direction_input = Vector2.ZERO
    movement_boost_active = false
    boost_confirm_elapsed = 0.0
    _reset_boost_speed_transition()
    boost_pose_grace_remaining = 0.0
    if touch_ui != null:
        touch_ui.call("set_movement_boost", false)
    return true


# v281: One geometric Bezier arc drives BOTH horizontal displacement and
# altitude, avoiding a linear XZ slide pasted onto an independent jump.
# P0=(0,0), P1=(0,2m), P2=(5m,2m), P3=(5m,0) for the standard kick.
# At t=0.5 this gives 2.5m rear travel and 1.5m genuine apex; it also
# approaches launch and landing with vertical tangents (no horizontal pop).
func _back_somersault_arc_offset(progress: float) -> Vector3:
    var p: float = clampf(progress, 0.0, 1.0)
    var finish: Vector3 = back_somersault_direction * BACK_SOMERSAULT_DISTANCE
    var control_up: Vector3 = Vector3.UP * (
        BACK_SOMERSAULT_HEIGHT * BACK_SOMERSAULT_ARC_CONTROL_HEIGHT_RATIO)
    return Vector3.ZERO.bezier_interpolate(
        control_up, finish + control_up, finish, p)


# v284: Pre-impact Kick_b is a grounded, homing strike. Only a real hit
# triggers the curved leap. On a miss the complete pose still plays, but
# there is no phantom retreat or landing. The authored clip clock remains
# 0..0.8s and its last sample is held until the rig has rendered it.
func _advance_back_somersault(delta: float) -> void:
    if not back_somersault_active:
        return
    var remaining: float = maxf(0.0, delta)
    if not back_somersault_hit_checked:
        var strike_dt: float = minf(remaining, maxf(
            0.0, BACK_SOMERSAULT_STRIKE_SECONDS - back_somersault_elapsed))
        if strike_dt > 0.0:
            # Reuse the normal melee swept chase, EN and current target lock.
            # Do not allow this chase to continue once a kick connects.
            if target_hp > 0:
                _advance_homing_toward_target(strike_dt, BASH_REACH)
            back_somersault_elapsed += strike_dt
            remaining -= strike_dt
        rig.call("set_back_somersault_progress",
            back_somersault_elapsed / BACK_SOMERSAULT_FLIGHT_SECONDS)
        if back_somersault_elapsed >= BACK_SOMERSAULT_STRIKE_SECONDS - 0.000001:
            back_somersault_hit_checked = true
            if target_hp > 0 and _distance_to_attack_target_surface(player.position) <= SIDE_KICK_REACH:
                back_somersault_hit = true
                _register_side_kick_hit()
                # This is the FIRST frame of the retreat: no arc displacement
                # occurred during pursuit or windup.
                back_somersault_launched = true
                back_somersault_start = player.position
                _capture_back_somersault_retreat_direction()
    var previous: float = clampf(
        (back_somersault_elapsed - BACK_SOMERSAULT_STRIKE_SECONDS)
            / BACK_SOMERSAULT_REAR_FLIGHT_SECONDS, 0.0, 1.0)
    back_somersault_elapsed = minf(
        BACK_SOMERSAULT_FLIGHT_SECONDS, back_somersault_elapsed + remaining)
    var progress: float = clampf(
        (back_somersault_elapsed - BACK_SOMERSAULT_STRIKE_SECONDS)
            / BACK_SOMERSAULT_REAR_FLIGHT_SECONDS, 0.0, 1.0)
    if back_somersault_launched:
        # Horizontal and vertical path are one swept cubic curve. No chase
        # is ever applied in flight, even if the target keeps moving.
        var previous_offset: Vector3 = _back_somersault_arc_offset(previous)
        var next_offset: Vector3 = _back_somersault_arc_offset(progress)
        var arc_delta: Vector3 = next_offset - previous_offset
        _move_player_swept(Vector3(arc_delta.x, 0.0, arc_delta.z), true)
        var wanted_y: float = back_somersault_start.y + next_offset.y
        var vertical_delta: float = wanted_y - player.position.y
        if absf(vertical_delta) > 0.000001:
            player.move_and_collide(Vector3.UP * vertical_delta)
        player.velocity = Vector3.ZERO
    # The original Kick_b starts while on the ground; its contact pose
    # occurs at BACK_SOMERSAULT_HIT_PROGRESS. After contact, continue the
    # same authored clock while the 5m / 1.5m arc plays.
    var pose_progress: float = back_somersault_elapsed / BACK_SOMERSAULT_FLIGHT_SECONDS
    if not back_somersault_has_authored_clip and back_somersault_launched:
        # Procedural rotation is fallback-only and begins on contact.
        var angle: float = TAU * progress
        rig.rotation.x = angle
        rig.position.y = back_somersault_original_rig_y + (
            BACK_SOMERSAULT_VISUAL_PIVOT_HEIGHT * (1.0 - cos(angle)))
    rig.call("set_back_somersault_progress", pose_progress)
    if back_somersault_elapsed >= BACK_SOMERSAULT_FLIGHT_SECONDS:
        if back_somersault_launched:
            player.position.y = back_somersault_start.y
            player.velocity = Vector3.ZERO
        if back_somersault_has_authored_clip and not bool(
                rig.call("back_somersault_final_pose_sampled")):
            return
        back_somersault_active = false
        back_somersault_launched = false
        back_somersault_elapsed = 0.0
        rig.rotation.x = 0.0
        rig.position.y = back_somersault_original_rig_y
        if back_somersault_hit:
            _begin_landing(true)
        else:
            # Miss: do not fabricate airborne movement or landing.
            rig.call("finish_jump", false, false)


func _cancel_back_somersault() -> void:
    if not back_somersault_active:
        return
    back_somersault_active = false
    back_somersault_launched = false
    back_somersault_elapsed = 0.0
    back_somersault_hit = false
    back_somersault_hit_checked = false
    if rig != null:
        rig.rotation.x = 0.0
        rig.position.y = back_somersault_original_rig_y
        rig.call("finish_jump", false, false)
    if player != null:
        player.position.y = 0.0
        player.velocity = Vector3.ZERO


# Fixed 3m front/side, 5m rear. Rear-diagonal angles interpolate with a
# smoothstep: both 45-degree rear diagonals travel exactly 4m.
func _step_fixed_distance_for_direction(direction: Vector2) -> float:
    if direction.length_squared() < 0.000001:
        return STEP_SIDE_DISTANCE
    var unit: Vector2 = direction.normalized()
    var rear_angle: float = atan2(maxf(unit.y, 0.0), absf(unit.x))
    var rear_mix: float = smoothstep(0.0, 1.0, rear_angle / (PI * 0.5))
    return lerpf(STEP_SIDE_DISTANCE, BACK_STEP_DISTANCE, rear_mix)


func _start_omni_step(flick: Vector2) -> bool:
    if (guard_active or damage_reaction_active or landing_active
            or rig == null or not bool(rig.get("loading_ok"))
            or flick.length_squared() < 0.000001):
        return false
    if not _spend_energy(15.0 * float(part_stats.get("energy_cost_mult", 1.0))):
        return false
    # A successfully initiated STEP cancels both follow-up input links.
    # Do this only AFTER EN is spent, never for an unsuccessful STEP.
    _cancel_combo_followup_windows_for_movement()
    if combat_state != CombatState.IDLE:
        _cancel_attack()
    if step_active:
        _finish_side_step(false)

    # v263: one gesture, one SCREEN-space direction for all 360 degrees.
    # The earlier mix of camera RIGHT and ACTOR FORWARD was non-orthogonal
    # near the boss, so rear/side diagonal commands could cancel or rotate.
    # Snapshot the same orthogonal CAMERA basis used by normal RUN/BOOST;
    # hold camera YAW for the committed STEP to preserve screen alignment.
    var direction: Vector2 = flick.normalized()
    var radial: Vector2 = Vector2(
        player.position.x - target.position.x,
        player.position.z - target.position.z)
    # No target-radius term in distance or speed. The committed motion is
    # screen-directed, so lock/pose rotation cannot change its trajectory.
    step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))
    step_arc_length = _step_fixed_distance_for_direction(direction)
    step_radial_delta = 0.0

    # Project BOTH screen axes through the camera. No actor-forward
    # component in the path: even if SERA faces screen-right, UP+RIGHT
    # flicks do not cancel or rotate into unrelated directions.
    var world_step: Vector3 = _screen_drag_to_ground(direction)
    if world_step.length_squared() < 0.000001:
        world_step = Vector3(direction.x, 0.0, direction.y)
    world_step = world_step.normalized() * step_arc_length
    # v310: STEP animation selection is SCREEN-relative, exactly like the
    # committed flick/travel. Reprojecting against boss-facing SERA caused
    # RIGHT flicks to blend into Frontstep as SERA circled the boss.
    var pose_direction: Vector2 = direction
    step_start_offset = radial
    step_target_center = Vector2(target.position.x, target.position.z)
    step_linear_fallback = true
    step_signed_angle = 0.0
    step_linear_offset = Vector2(world_step.x, world_step.z)

    step_duration_current = (step_arc_length / step_speed_current
        * float(part_stats.get("step_time_mult", 1.0)))
    # Side kicks use the enemy as an orbit pivot, so their camera guard
    # activates throughout the nearby melee range; ordinary STEP retains
    # the older 1m proximity threshold and committed screen trajectory.
    step_close_camera = (
        (step_kick_side_request != 0
            and _distance_to_cube_surface(player.position) <= MELEE_SURFACE_REACH)
        or (absf(pose_direction.x) > 0.001
            and _distance_to_cube_surface(player.position) <= STEP_CLOSE_CAMERA_SURFACE_DISTANCE))
    close_step_camera_recovery_remaining = 0.0
    if jump_active:
        jump_horizontal_velocity = Vector3.ZERO
    step_active = true
    step_flick_direction = direction
    step_side = STEP_BACK if direction.y > 0.8 else (1 if direction.x > 0.0 else -1)
    step_elapsed = 0.0
    step_traveled_distance = 0.0
    side_kick_active = step_kick_side_request != 0
    side_kick_side = step_kick_side_request
    side_kick_travel_anchor_set = false
    side_kick_linear_active = false
    side_kick_linear_start = Vector2.ZERO
    side_kick_linear_direction = Vector2.ZERO
    side_kick_linear_distance = 0.0
    side_kick_orbit_sign = 1.0
    # A kick follows a target-centered orbit rather than this normal
    # screen-linear STEP. Its angle and anchor are finalized at the SECOND
    # windup after the first-foot homing, so no early snap-back can occur.
    # Each kick travels a total of 3m across its arc and tangent boost.
    if side_kick_active:
        step_arc_length = SIDE_KICK_BOOST_DISTANCE
        step_duration_current = (step_arc_length / step_speed_current
            * float(part_stats.get("step_time_mult", 1.0))
            * SIDE_KICK_MOTION_TIME_MULTIPLIER)
        step_linear_fallback = false
        step_signed_angle = 0.0
    side_kick_did_hit = false
    side_kick_hit_mask = 0
    side_kick_hit_count = 0
    if side_kick_active:
        if not bool(rig.call("start_side_kick", step_kick_side_request, step_duration_current)):
            # Do not claim KICK START if the rig refused playback.
            _finish_side_step(false)
            return false
    else:
        rig.call("start_omni_step", pose_direction)
    _refresh_step_status_ui()
    return true

func _start_back_step() -> bool:
    if guard_active or damage_reaction_active or landing_active or rig == null or not bool(rig.get("loading_ok")):
        return false
    if not _spend_energy(15.0 * float(part_stats.get("energy_cost_mult", 1.0))):
        return false
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
    step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))
    # 5m at 10m/s = 0.50 seconds before equipment scaling.
    step_duration_current = BACK_STEP_DISTANCE / step_speed_current * float(part_stats.get("step_time_mult", 1.0))
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
    return true

func _start_side_step(side: int) -> bool:
    if guard_active or damage_reaction_active or landing_active or side == 0 or rig == null or not bool(rig.get("loading_ok")):
        return false
    if not _spend_energy(15.0 * float(part_stats.get("energy_cost_mult", 1.0))):
        return false
    if combat_state != CombatState.IDLE:
        # v45: a flick can cancel an in-progress attack.
        _cancel_attack()
    if step_active:
        _finish_side_step(false)

    # Legacy direct side-step entry (touch uses _start_omni_step):
    # fixed 3m arc length even though this helper retains its orbit path.
    var radial: Vector2 = Vector2(
        player.position.x - target.position.x,
        player.position.z - target.position.z
    )
    var radius: float = radial.length()
    var camera_right: Vector3 = _screen_drag_to_ground(Vector2.RIGHT).normalized()
    # A tiny radius would require circling the target multiple times to
    # cover 2.0m. Only in this extreme overlap state use a 2.0m tangent
    # translation instead; the player must never spin in place.
    var close_radius_limit: float = (STEP_SIDE_DISTANCE
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
    # Dedicated legacy left/right input uses the same constant lateral speed.
    # Orbit geometry and its 2-4m path-length bounds are unchanged.
    step_speed_current = STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0))
    var path_length: float = STEP_SIDE_DISTANCE
    if step_linear_fallback:
        step_signed_angle = 0.0
        step_linear_offset = Vector2(orbit_tangent.x, orbit_tangent.z) * (
            STEP_SIDE_DISTANCE * orbit_sign)
    else:
        step_signed_angle = STEP_SIDE_DISTANCE / radius * orbit_sign
    step_arc_length = path_length
    # Keep the selected speed for the entire step (do not change mid-orbit).
    # Base 2m minimum at 10m/s lasts 0.20s, within the 0.40s cap.
    step_duration_current = path_length / step_speed_current * float(part_stats.get("step_time_mult", 1.0))
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
    return true

func _finish_side_step(resume_moving: bool) -> void:
    if not step_active:
        return
    step_last_elapsed = step_elapsed
    step_has_last = true
    step_active = false
    side_kick_active = false
    side_kick_side = 0
    side_kick_travel_anchor_set = false
    side_kick_linear_active = false
    side_kick_linear_start = Vector2.ZERO
    side_kick_linear_direction = Vector2.ZERO
    side_kick_linear_distance = 0.0
    side_kick_orbit_sign = 1.0
    side_kick_did_hit = false
    side_kick_hit_mask = 0
    side_kick_hit_count = 0
    if step_close_camera:
        # Retain the target-relative guard very briefly after the final
        # physics tick so idle recenter cannot immediately undo it.
        close_step_camera_recovery_remaining = STEP_CLOSE_CAMERA_RECOVERY_SECONDS
    step_close_camera = false
    step_side = 0
    step_flick_direction = Vector2.ZERO
    step_radial_delta = 0.0
    step_elapsed = 0.0
    var resume_fall: bool = jump_active and not damage_reaction_active
    if resume_fall:
        _enter_jump_fall()
    rig.call("finish_side_step", resume_moving, resume_fall)
    _refresh_step_status_ui()

# The orbit center is the ACTUALLY LOCKED part, not the target BODY.
# Preserve locked broken parts during the active combo until its lock
# retention finishes, just like melee/bash hit selection.
func _kick_lock_center_xz() -> Vector2:
    var point: Vector3 = target.global_position
    if target_parts != null and not locked_target_part_id.is_empty() \
            and bool(target_parts.call("has_part", locked_target_part_id)):
        point = target_parts.call("get_part_aim_world", locked_target_part_id)
    return Vector2(point.x, point.z)


# At second windup, AFTER the first Bash-style homing movement, snapshot
# the radius around the locked part. Spend the first part of the FIXED 3m
# movement following that circular arc until second contact. The remaining
# distance is a straight tangent BOOST after second contact, not more orbit.
func _configure_side_kick_orbit() -> void:
    step_target_center = _kick_lock_center_xz()
    var radial: Vector2 = Vector2(
        player.position.x - step_target_center.x,
        player.position.z - step_target_center.y)
    step_start_offset = radial
    var radius: float = radial.length()
    var world_right: Vector3 = _screen_drag_to_ground(Vector2.RIGHT)
    if world_right.length_squared() < 0.000001:
        world_right = Vector3.RIGHT
    var screen_right_xz: Vector2 = Vector2(world_right.x, world_right.z).normalized()
    var tangent: Vector2 = screen_right_xz
    if radius >= STEP_MIN_ORBIT_RADIUS:
        tangent = Vector2(-radial.y, radial.x) / radius
    side_kick_orbit_sign = (
        1.0 if tangent.dot(screen_right_xz) >= 0.0 else -1.0) * float(side_kick_side)
    var second_windup: float = (
        SIDE_KICK_SECOND_WINDUP_R if side_kick_side > 0 else SIDE_KICK_SECOND_WINDUP_L)
    var orbit_fraction: float = clampf(
        (float(SIDE_KICK_HIT_PROGRESS[1]) - second_windup)
        / (1.0 - second_windup), 0.0, 1.0)
    var requested_orbit_length: float = SIDE_KICK_BOOST_DISTANCE * orbit_fraction
    step_signed_angle = 0.0
    if radius >= STEP_MIN_ORBIT_RADIUS:
        step_signed_angle = minf(
            requested_orbit_length / radius,
            deg_to_rad(STEP_CLOSE_ORBIT_MAX_DEGREES)) * side_kick_orbit_sign
    # If the locked pivot lies inside SERA or the maximum safe turn is hit,
    # carry any unused arc metres into the straight phase. Always total 3m.
    side_kick_linear_distance = maxf(0.0,
        SIDE_KICK_BOOST_DISTANCE - radius * absf(step_signed_angle))
    side_kick_linear_direction = screen_right_xz * float(side_kick_side)
    step_linear_fallback = false
    step_linear_offset = Vector2.ZERO
    step_radial_delta = 0.0


func _advance_side_step(delta: float) -> void:
    if not step_active:
        return
    var previous_progress: float = step_elapsed / step_duration_current
    step_elapsed = minf(step_duration_current, step_elapsed + delta)
    var progress: float = step_elapsed / step_duration_current
    var before: Vector3 = player.position
    if side_kick_active:
        var second_windup: float = (SIDE_KICK_SECOND_WINDUP_R
            if side_kick_side > 0 else SIDE_KICK_SECOND_WINDUP_L)
        var second_hit: float = float(SIDE_KICK_HIT_PROGRESS[1])
        # Retain the original first-hit and pre-second-windup homing window.
        # The orbit starts from the ACTUAL chased position, never a stale
        # pre-homing point. A low-FPS tick crossing the windup is split.
        var previous_seconds: float = step_duration_current * previous_progress
        var chase_until: float = minf(
            BASH_TRACK_SECONDS, step_duration_current * second_windup)
        var chase_dt: float = minf(
            maxf(delta, 0.0), maxf(0.0, chase_until - previous_seconds))
        if chase_dt > 0.0 and target_hp > 0 and not side_kick_travel_anchor_set:
            _advance_homing_toward_target(chase_dt, BASH_REACH)
        if not side_kick_travel_anchor_set and progress >= second_windup:
            _configure_side_kick_orbit()
            side_kick_travel_anchor_set = true
        if side_kick_travel_anchor_set:
            if not side_kick_linear_active:
                # The active lock may move (e.g. animated HEAD or a moving
                # boss). Follow that pivot only during the circular part.
                step_target_center = _kick_lock_center_xz()
                var orbit_progress: float = clampf(
                    (progress - second_windup) / maxf(
                        second_hit - second_windup, 0.00001), 0.0, 1.0)
                var rotated: Vector2 = step_start_offset.rotated(
                    step_signed_angle * orbit_progress)
                var orbit_goal: Vector2 = step_target_center + rotated
                _move_player_swept(Vector3(
                    orbit_goal.x - player.position.x, 0.0,
                    orbit_goal.y - player.position.z), true)
                if progress >= second_hit:
                    # Record the SECOND foot impact while still on the arc,
                    # before applying any post-impact linear displacement.
                    if previous_progress < second_hit and (side_kick_hit_mask & 2) == 0:
                        side_kick_hit_mask |= 2
                        if target_hp > 0 and _distance_to_attack_target_surface(
                                player.position) <= SIDE_KICK_REACH:
                            _register_side_kick_hit()
                            side_kick_hit_count += 1
                    side_kick_linear_active = true
                    side_kick_linear_start = Vector2(
                        player.position.x, player.position.z)
                    var contact_pivot: Vector2 = _kick_lock_center_xz()
                    var contact_radial: Vector2 = side_kick_linear_start - contact_pivot
                    if contact_radial.length_squared() >= STEP_MIN_ORBIT_RADIUS * STEP_MIN_ORBIT_RADIUS:
                        side_kick_linear_direction = Vector2(
                            -contact_radial.y, contact_radial.x).normalized() * side_kick_orbit_sign
            if side_kick_linear_active:
                # No further center tracking, yaw or orbital rotation.
                # Straight BOOST advances along the tangent recorded at hit.
                var line_progress: float = clampf(
                    (progress - second_hit) / maxf(1.0 - second_hit, 0.00001),
                    0.0, 1.0)
                var line_goal: Vector2 = side_kick_linear_start + (
                    side_kick_linear_direction * side_kick_linear_distance * line_progress)
                _move_player_swept(Vector3(
                    line_goal.x - player.position.x, 0.0,
                    line_goal.y - player.position.z), true)
    else:
        # Ordinary 360deg STEP has a single committed screen-linear vector,
        # independent of target distance, target motion and player facing.
        var new_offset: Vector2 = step_start_offset + step_linear_offset * progress
        var requested: Vector3 = Vector3(
            step_target_center.x + new_offset.x - player.position.x,
            0.0,
            step_target_center.y + new_offset.y - player.position.z)
        _move_player_swept(requested, true)
    step_traveled_distance += Vector2(
        player.position.x - before.x, player.position.z - before.z).length()
    if side_kick_active:
        # Both authored foot-contact keys are still used exactly once.
        # The second key is handled above, at the arc/line boundary.
        for i in range(SIDE_KICK_HIT_PROGRESS.size()):
            var impact_progress: float = float(SIDE_KICK_HIT_PROGRESS[i])
            var bit: int = 1 << i
            if (side_kick_hit_mask & bit) != 0:
                continue
            if previous_progress < impact_progress and progress >= impact_progress:
                side_kick_hit_mask |= bit
                if target_hp > 0 and _distance_to_attack_target_surface(player.position) <= SIDE_KICK_REACH:
                    _register_side_kick_hit()
                    side_kick_hit_count += 1
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
    if event is InputEventKey and event.pressed and not event.echo:
        if event.is_action_pressed("ui_cancel") or event.keycode == KEY_BACK:
            _request_return_to_nexus()
            get_viewport().set_input_as_handled()
            return
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

func _start_attack() -> bool:
    # True means this tap was accepted, not necessarily that a hit connected.
    # Keyboard callers ignore the return value; only touch release uses it
    # to prevent false ripple feedback during guard, damage or approach.
    if guard_active or damage_reaction_active or landing_active or back_somersault_active \
            or step_active or rig == null or not rig.get("loading_ok"):
        return false
    if combat_state == CombatState.BASH or combat_state == CombatState.BASH_TRACK:
        # One follow-up melee tap can be buffered during tracking or Bash.
        bash_combo_queued = true
        return true
    if combat_state == CombatState.STRIKE:
        # Taps never restart the current attack. Buffer exactly one follow-up;
        # _advance_attack() consumes it at or after the authored cancel point.
        if strike_index < _strike_stage_count() - 1:
            combo_queued = true
            return true
        return false
    # No extra strikes can be queued before the initial melee has landed in
    # STRIKE (during MELEE_APPROACH/DASH), or while a side-step is playing.
    if combat_state != CombatState.IDLE:
        return false
    if _distance_to_attack_target_surface(player.position) > float(part_stats.get("lock_range", 24.0)):
        return false
    if bash_loop_window_remaining > 0.0 and _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH:
        bash_loop_window_remaining = 0.0
        _start_strike(0)
        return true
    bash_loop_window_remaining = 0.0
    bash_followup_window_remaining = 0.0
    strike_index = 0
    combo_queued = false
    _clear_strike_tracking()
    if sword_trail != null:
        sword_trail.call("stop_swing")
    if jump_active:
        jump_horizontal_velocity = Vector3.ZERO
    if energy_exhausted and _distance_to_attack_target_surface(player.position) > MELEE_SURFACE_REACH:
        _start_strike(0)  # EN exhausted: stationary swing remains available.
        return true
    melee_boost_elapsed = 0.0
    combat_state = CombatState.MELEE_APPROACH
    rig.call("start_melee_approach", _katana_equipped())
    return true

# The Melee3->Bash and Bash->Melee1 input windows persist in IDLE,
# but the active combo must still hold the same lock during either.
func _combo_followup_input_window_open() -> bool:
    return (bash_followup_window_remaining > 0.0
        or bash_loop_window_remaining > 0.0)


# v289: a combo includes all three strikes, Bash, the buffered side/back
# kicks, the resulting somersault landing and the two link windows. Broken
# part IDs must stay locked for EVERY frame of this entire lifecycle.
func _combo_lock_retention_active() -> bool:
    return (combat_state != CombatState.IDLE
        or side_kick_active or back_somersault_active
        or (landing_active and landing_from_somersault)
        or _combo_followup_input_window_open())


# RUN/BOOST or a confirmed STEP cancels pending follow-up input.
# Do not alter selected ID or AUTO/MANUAL preference here.
func _cancel_combo_followup_windows_for_movement() -> void:
    bash_followup_window_remaining = 0.0
    bash_loop_window_remaining = 0.0

func _cancel_attack() -> void:
    if combat_state == CombatState.IDLE:
        return
    combat_state = CombatState.IDLE
    melee_boost_elapsed = 0.0
    bash_track_elapsed = 0.0
    back_kick_track_elapsed = 0.0
    followup_track_elapsed = 0.0
    combo_queued = false
    bash_queued = false
    bash_combo_queued = false
    buffered_side_kick_flick = Vector2.ZERO
    buffered_side_kick_side = 0
    side_kick_flick_candidate = false
    bash_flick_candidate = false
    bash_followup_window_remaining = 0.0
    bash_loop_window_remaining = 0.0
    bash_did_hit = false
    strike_index = 0
    hit_stop_remaining = 0.0
    rig.call("set_combat_paused", false)
    _clear_strike_tracking()
    if sword_trail != null:
        sword_trail.call("stop_swing")
    if jump_active and not damage_reaction_active:
        _enter_jump_fall()
    rig.call("finish_attack", direction_input.length_squared() > 0.000001, jump_active and not damage_reaction_active)

func _request_combo_bash() -> bool:
    if (combat_state == CombatState.STRIKE or combat_state == CombatState.STRIKE_TRACK) \
            and _is_strike_finisher():
        buffered_side_kick_flick = Vector2.ZERO
        buffered_side_kick_side = 0
        bash_queued = true
        return true
    if combat_state == CombatState.IDLE and bash_followup_window_remaining > 0.0:
        _start_bash()
        return true
    return false

func _start_bash() -> void:
    if guard_active or damage_reaction_active or landing_active or step_active \
            or rig == null or not bool(rig.get("loading_ok")):
        return
    if combat_state != CombatState.IDLE and not (combat_state == CombatState.STRIKE
            and _is_strike_finisher()):
        return
    combat_state = CombatState.BASH_TRACK
    bash_track_elapsed = 0.0
    bash_queued = false
    bash_combo_queued = false
    buffered_side_kick_flick = Vector2.ZERO
    buffered_side_kick_side = 0
    bash_flick_candidate = false
    bash_followup_window_remaining = 0.0
    bash_loop_window_remaining = 0.0
    bash_did_hit = false
    bash_prev_time = 0.0
    combo_queued = false
    direction_input = Vector2.ZERO
    _clear_strike_tracking()
    if sword_trail != null:
        sword_trail.call("stop_swing")
    # Loop the actual Bash windup keys (0..0.20833s) during the chase.
    # Release immediately on entering range; never delay a close-range Bash.
    rig.call("start_attack_windup", "Bash", BASH_WINDUP_KEY)
    if _distance_to_attack_target_surface(player.position) <= BASH_REACH:
        _launch_bash_after_tracking()

func _launch_bash_after_tracking() -> void:
    if combat_state != CombatState.BASH_TRACK:
        return
    combat_state = CombatState.BASH
    rig.call("release_attack_windup")
    bash_prev_time = float(rig.call("get_clip_time"))

func _advance_homing_toward_target(delta: float, reach: float) -> bool:
    # Uses live target coordinates on every physics tick. True means homing
    # was allowed (or is already in range), not that an attack connected.
    if _distance_to_attack_target_surface(player.position) <= reach:
        return true
    if delta <= 0.0:
        return true
    if not _spend_energy(16.0 * delta * float(part_stats.get("energy_cost_mult", 1.0))):
        return false
    var pursuit_point: Vector3 = target.position
    if _locked_part_hit_volume_available():
        pursuit_point = target_parts.call("get_part_aim_world", locked_target_part_id)
    var destination_delta: Vector3 = pursuit_point - player.position
    destination_delta.y = 0.0
    if destination_delta.length_squared() < 0.000001:
        return true
    var speed: float = float(part_stats.get("melee_boost_speed", MELEE_BOOST_DEFAULT_SPEED))
    var travel: float = minf(speed * delta, destination_delta.length())
    var next_position: Vector3 = player.position + destination_delta.normalized() * travel
    if _distance_to_attack_target_surface(next_position) <= reach:
        # End at the first edge of the strike/bash range; never overshoot.
        var low: float = 0.0
        var high: float = 1.0
        for _i in range(16):
            var mid: float = (low + high) * 0.5
            if _distance_to_attack_target_surface(player.position.lerp(next_position, mid)) <= reach:
                high = mid
            else:
                low = mid
        _move_player_swept(player.position.lerp(next_position, high) - player.position, true)
    else:
        _move_player_swept(next_position - player.position, true)
    # v251: melee homing glides along visible part solids / joint guards,
    # rather than stopping at the first solid while chasing the lock.
    return true

func _check_bash_contact() -> void:
    if combat_state != CombatState.BASH or bash_did_hit or hit_stop_remaining > 0.0:
        return
    var bash_t: float = float(rig.call("get_clip_time"))
    # After the strike key, keep checking range on EVERY frame until a
    # confirmed hit or Bash ends. A moving target can evade the first sample.
    if bash_t >= BASH_CONTACT_TIME:
        if _distance_to_attack_target_surface(player.position) <= BASH_REACH:
            _register_bash_hit()
    bash_prev_time = bash_t

func _register_bash_hit() -> void:
    bash_did_hit = true
    var hit_part: String = locked_target_part_id
    var bash_damage: int = roundi(float(part_stats.get("bash_damage", BASH_DAMAGE)) *
        float(part_stats.get("attack_mult", 1.0)))
    var result: Dictionary = _apply_target_part_damage("bash", bash_damage,
        float(part_stats.get("bash_break", 12)), 12.0, 0.08)
    hit_stop_remaining = HIT_STOP_SECONDS
    damage_popup_remaining = 0.58
    var closest: Vector3 = Vector3(
        clampf(player.position.x, target.position.x - TARGET_HALF_SIZE, target.position.x + TARGET_HALF_SIZE),
        target.position.y,
        clampf(player.position.z, target.position.z - TARGET_BODY_HALF_DEPTH, target.position.z + TARGET_BODY_HALF_DEPTH))
    impact_origin = _part_hit_surface(hit_part, closest)
    rig.call("set_combat_paused", true)
    damage_label.text = "%d" % int(result["applied_damage"])
    damage_label.visible = true
    if is_instance_valid(hit_audio) and hit_audio.stream != null:
        hit_audio.play()
    if hit_burst != null:
        var shield_force: Vector3 = target.global_position - player.global_position
        shield_force.y = 0.0
        hit_burst.call("start_burst", impact_origin, shield_force.normalized())

func _update_melee_lock_marker() -> void:
    # Match the *same* distance rule used to stop the melee approach.
    # v39: Reticle distance cue remains active even with 0 HP.
    if touch_ui == null or player == null or target == null:
        return
    var can_melee: bool = _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH
    touch_ui.call("set_melee_in_range", can_melee)

func _distance_to_cube_surface(pos: Vector3) -> float:
    # 2D point-to-AABB distance; unlike center-to-center, it is accurate
    # near edges/corners of the enlarged target box.
    var dx: float = maxf(absf(pos.x - target.position.x) - TARGET_HALF_SIZE, 0.0)
    var dz: float = maxf(absf(pos.z - target.position.z) - TARGET_BODY_HALF_DEPTH, 0.0)
    return Vector2(dx, dz).length()

func _distance_to_attack_target_surface(pos: Vector3) -> float:
    # Chase, Bash and assisted hits share the active lock's horizontal AABB.
    if _locked_part_hit_volume_available():
        var part_box: AABB = target_parts.call("get_part_aabb", locked_target_part_id)
        var nearest_x: float = clampf(pos.x, part_box.position.x, part_box.end.x)
        var nearest_z: float = clampf(pos.z, part_box.position.z, part_box.end.z)
        return Vector2(pos.x - nearest_x, pos.z - nearest_z).length()
    # Unlocked attacks preserve the original core range.
    return _distance_to_cube_surface(pos)

# Weapon-specific playback; preserve existing combo stage/damage and controls.
func _katana_equipped() -> bool:
    return rig != null and str(rig.call("get_equipment_selection", "weapon_r")) == "K"

func _strike_stage_count() -> int:
    return 2 if _katana_equipped() else STRIKE_CLIPS.size()


func _is_strike_finisher() -> bool:
    return strike_index == _strike_stage_count() - 1


func _active_strike_clip(stage: int) -> String:
    if _katana_equipped():
        return KATANA_SECOND_STRIKE_CLIP if stage >= 1 else KATANA_STRIKE_CLIP
    return str(STRIKE_CLIPS[clampi(stage, 0, STRIKE_CLIPS.size() - 1)])

func _strike_cancel_time(stage: int) -> float:
    if _katana_equipped():
        return minf(float(STRIKE_CANCEL_TIMES[stage]), 0.5)
    return float(STRIKE_CANCEL_TIMES[stage])


func _melee3_flick_cancel_time() -> float:
    # The second Katana clip is authored at 0.58333s. Retain the existing
    # frame-7 + 0.05s flick gate, independent of its longer follow-through.
    if _katana_equipped():
        return 7.0 / 24.0 + MELEE3_FLICK_CANCEL_DELAY
    return float(STRIKE_CANCEL_TIMES[STRIKE_CLIPS.size() - 1]) + MELEE3_FLICK_CANCEL_DELAY


func _start_strike(stage: int = 0) -> void:
    var next_stage: int = clampi(stage, 0, _strike_stage_count() - 1)
    var costs: Array = part_stats.get("attack_energy", [0.0, 0.0, 0.0])
    if not _spend_energy(float(costs[next_stage])):
        _cancel_attack()
        return
    strike_index = next_stage
    combo_queued = false
    buffered_side_kick_flick = Vector2.ZERO
    buffered_side_kick_side = 0
    _clear_strike_tracking()
    if sword_trail != null:
        sword_trail.call("stop_swing")
    if next_stage > 0:
        # Melee2/3 loop their authored backswing while pursuing for up to
        # 0.2s. Do not begin the sword trail or hit window until in range.
        combat_state = CombatState.STRIKE_TRACK
        followup_track_elapsed = 0.0
        var windup_end: float = float(FOLLOWUP_WINDUP_KEYS[strike_index])
        if _katana_equipped():
            windup_end = minf(windup_end, 2.0 / 24.0)
        rig.call("start_attack_windup", _active_strike_clip(strike_index), windup_end)
        if _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH:
            _launch_followup_strike()
        return
    # Melee1 keeps the existing normal attack clip after its booster approach.
    combat_state = CombatState.STRIKE
    if sword_trail != null:
        sword_trail.call("begin_swing", (0.0 if _katana_equipped() else float(STRIKE_TRAIL_OFFSETS[strike_index])))
    rig.call("start_strike", _active_strike_clip(strike_index))

func _launch_followup_strike() -> void:
    if combat_state != CombatState.STRIKE_TRACK:
        return
    combat_state = CombatState.STRIKE
    rig.call("release_attack_windup")
    _clear_strike_tracking()
    if sword_trail != null:
        sword_trail.call("begin_swing", (0.0 if _katana_equipped() else float(STRIKE_TRAIL_OFFSETS[strike_index])))

# Exit an authored strike once, then dispatch any queued lateral/back Kick.
# Called either at Melee3's flick cancel point or at a clip's normal end.
# Only stage 3 opens the existing post-finisher Bash/Kick link window.
func _finish_strike_and_release_queued_kick() -> void:
    var committed_kick_flick: Vector2 = Vector2.ZERO
    var committed_kick_side: int = 0
    if _is_strike_finisher():
        bash_followup_window_remaining = BASH_LINK_SECONDS
        last_melee3_finished_ms = Time.get_ticks_msec()
        committed_kick_flick = buffered_side_kick_flick
        committed_kick_side = buffered_side_kick_side
    buffered_side_kick_flick = Vector2.ZERO
    buffered_side_kick_side = 0
    combat_state = CombatState.IDLE
    combo_queued = false
    bash_queued = false
    strike_index = 0
    if sword_trail != null:
        sword_trail.call("stop_swing")
    _clear_strike_tracking()
    if jump_active and not damage_reaction_active:
        _enter_jump_fall()
    rig.call("finish_attack", false, jump_active and not damage_reaction_active)
    if committed_kick_side != 0 and committed_kick_flick.length_squared() > 0.000001:
        _launch_combo_side_kick(committed_kick_flick, committed_kick_side)


func _advance_attack(delta: float) -> void:
    match combat_state:
        CombatState.MELEE_APPROACH:
            if rig.call("melee_approach_last_key_reached"):
                if _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH:
                    _start_strike()
                else:
                    rig.call("hold_melee_approach_last_pose")
                    melee_boost_elapsed = 0.0
                    combat_state = CombatState.DASH
        CombatState.DASH:
            # Booster duration caps the MOVING portion of normal melee boost;
            # the preceding authored approach animation stays unchanged.
            if _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH:
                _start_strike()
                return
            var maximum_duration: float = maxf(0.01,
                float(part_stats.get("melee_boost_duration", MELEE_BOOST_DEFAULT_DURATION)))
            var boost_dt: float = minf(maxf(0.0, delta),
                maxf(0.0, maximum_duration - melee_boost_elapsed))
            if boost_dt <= 0.0:
                _cancel_attack()  # Beyond timed range: no phantom hit.
                return
            if not _advance_homing_toward_target(boost_dt, MELEE_SURFACE_REACH):
                _cancel_attack()
                return
            melee_boost_elapsed += boost_dt
            if _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH:
                _start_strike()
            elif melee_boost_elapsed >= maximum_duration - 0.00001:
                _cancel_attack()
        CombatState.BACK_KICK_TRACK:
            # Share the actual Bash homing function, target, EN and collisions.
            var kick_dt: float = minf(maxf(delta, 0.0),
                maxf(0.0, BASH_TRACK_SECONDS - back_kick_track_elapsed))
            if _distance_to_attack_target_surface(player.position) > BASH_REACH:
                if kick_dt > 0.0 and not _advance_homing_toward_target(kick_dt, BASH_REACH):
                    _cancel_attack()
                    return
                back_kick_track_elapsed += kick_dt
            if _distance_to_attack_target_surface(player.position) <= BASH_REACH:
                combat_state = CombatState.IDLE
                back_kick_track_elapsed = 0.0
                if not _start_back_somersault():
                    rig.call("finish_attack", false)
            elif back_kick_track_elapsed >= BASH_TRACK_SECONDS - 0.00001:
                # Match Bash: abort if the target escaped the homing window.
                _cancel_attack()
        CombatState.BASH_TRACK:
            # Chase for up to 0.2s while the authored Bash windup ping-pongs.
            # Launch immediately on reaching range, including on frame 0.
            if _distance_to_attack_target_surface(player.position) <= BASH_REACH:
                _launch_bash_after_tracking()
                return
            var track_dt: float = minf(maxf(0.0, delta),
                maxf(0.0, BASH_TRACK_SECONDS - bash_track_elapsed))
            if track_dt > 0.0:
                # EN exhaustion prevents displacement but the target can move
                # into range during the remaining windup time.
                _advance_homing_toward_target(track_dt, BASH_REACH)
                bash_track_elapsed += track_dt
            if _distance_to_attack_target_surface(player.position) <= BASH_REACH:
                _launch_bash_after_tracking()
            elif bash_track_elapsed >= BASH_TRACK_SECONDS - 0.00001:
                _cancel_attack()
        CombatState.STRIKE_TRACK:
            # Same windup chase for second/third melee, 0.2s each.
            if _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH:
                _launch_followup_strike()
                return
            var follow_dt: float = minf(maxf(0.0, delta),
                maxf(0.0, FOLLOWUP_TRACK_SECONDS - followup_track_elapsed))
            if follow_dt > 0.0:
                _advance_homing_toward_target(follow_dt, MELEE_SURFACE_REACH)
                followup_track_elapsed += follow_dt
            if _distance_to_attack_target_surface(player.position) <= MELEE_SURFACE_REACH:
                _launch_followup_strike()
            elif followup_track_elapsed >= FOLLOWUP_TRACK_SECONDS - 0.00001:
                _cancel_attack()
        CombatState.STRIKE:
            # Continue homing during the actual blade swing until a hit is
            # confirmed (or the authored clip finishes). This is separate
            # from the pre-strike time cap and avoids misses on moving bosses.
            if not strike_did_hit:
                _advance_homing_toward_target(delta, MELEE_SURFACE_REACH)
            # Stage 3 alone can cancel into a RESERVED flick 0.05s after
            # its authored 15/24s swing-through. Do not unlock ordinary
            # Melee1 here: without a flick, the full 0.83333s clip runs.
            if _is_strike_finisher() \
                    and float(rig.call("get_clip_time")) >= _melee3_flick_cancel_time() \
                    and (bash_queued or buffered_side_kick_side != 0):
                if not strike_did_hit:
                    _check_strike_contact()
                    if hit_stop_remaining > 0.0:
                        return
                if bash_queued:
                    _start_bash()
                else:
                    _finish_strike_and_release_queued_kick()
                return
            # Existing Melee1 -> Melee2 -> Melee3 TAP progression is untouched.
            if (combo_queued and strike_index < _strike_stage_count() - 1
                    and float(rig.call("get_clip_time")) >= _strike_cancel_time(strike_index)):
                if not strike_did_hit:
                    _check_strike_contact()
                    if hit_stop_remaining > 0.0:
                        return
                _start_strike(strike_index + 1)
                return
            if rig.call("clip_finished", _active_strike_clip(strike_index)):
                # A frame skip can jump over contact: sample it before exit.
                if not strike_did_hit:
                    _check_strike_contact()
                    if hit_stop_remaining > 0.0:
                        return
                _finish_strike_and_release_queued_kick()
        CombatState.BASH:
            # Follow the moving target during the actual shield impact too.
            if not bash_did_hit:
                _advance_homing_toward_target(delta, BASH_REACH)
            _check_bash_contact()
            if hit_stop_remaining > 0.0:
                return
            if rig.call("clip_finished", "Bash"):
                if bash_combo_queued:
                    _start_strike(0)
                    return
                bash_loop_window_remaining = BASH_LINK_SECONDS
                combat_state = CombatState.IDLE
                rig.call("finish_attack", false)

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


func _reset_boost_speed_transition() -> void:
    # Hard reset only when the touch / locomotion is explicitly interrupted.
    # Both ends of the interpolation reset together so a fresh gesture
    # cannot inherit a stale BOOST ramp from the previous touch.
    boost_speed_multiplier = 1.0
    boost_speed_transition_start = 1.0
    boost_speed_transition_target = 1.0
    boost_speed_transition_elapsed = BOOST_SPEED_BLEND_SECONDS


func _update_boost_speed(delta: float) -> void:
    var wanted: float = (float(part_stats.get("boost_speed", 6.09375)) *
        float(part_stats.get("boost_speed_mult", 1.0)) /
        maxf(0.1, float(part_stats.get("run_speed", 4.0625)))) if movement_boost_active else 1.0
    if not is_equal_approx(wanted, boost_speed_transition_target):
        # A reversal during an incomplete blend resumes from the PRESENT
        # multiplier, never from RUN=1.0 or BOOST=1.5 prematurely.
        boost_speed_transition_start = boost_speed_multiplier
        boost_speed_transition_target = wanted
        boost_speed_transition_elapsed = 0.0
    boost_speed_transition_elapsed = minf(
        BOOST_SPEED_BLEND_SECONDS, boost_speed_transition_elapsed + maxf(delta, 0.0))
    var t: float = clampf(boost_speed_transition_elapsed / BOOST_SPEED_BLEND_SECONDS, 0.0, 1.0)
    # Zero slope at the beginning/end, unlike the old constant-speed ramp.
    var eased: float = t * t * (3.0 - 2.0 * t)
    boost_speed_multiplier = lerpf(
        boost_speed_transition_start, boost_speed_transition_target, eased)


func _physics_process(delta: float) -> void:
    _update_equipped_collision_height()
    _tick_training_ko(delta)
    if training_ko_remaining > 0.0:
        if state_label != null:
            state_label.text = "SERA KO / RESTART %.1fs" % training_ko_remaining
        _tick_resources(delta)
        _tick_energy_empty_flash(delta)
        return
    _advance_target_motion(delta)
    # An interpolated target must not update its bob inside _process().
    if hit_stop_remaining <= 0.0:
        elapsed += delta
        target.position.y = TARGET_BASE_HEIGHT + sin(elapsed * 1.4) * 0.07
    bash_followup_window_remaining = maxf(0.0, bash_followup_window_remaining - delta)
    bash_loop_window_remaining = maxf(0.0, bash_loop_window_remaining - delta)
    if kick_debug_remaining > 0.0:
        kick_debug_remaining = maxf(0.0, kick_debug_remaining - delta)
        if kick_debug_remaining == 0.0:
            _refresh_step_status_ui()
    _update_guard_hold()
    # Sample the outer-ring hold independently of touch event frequency.
    _update_boost_gesture(delta)
    if movement_boost_active:
        var boost_energy_ok: bool = _spend_energy(
            20.0 * delta * float(part_stats.get("energy_cost_mult", 1.0)))
        if not boost_energy_ok or energy_exhausted:
            # A final BOOST tick can cost more than the tiny remaining EN.
            # Count that as depletion, then require 60% regeneration before
            # ANY positive-cost EN action is available again.
            if not boost_energy_ok and not energy_exhausted:
                energy = 0.0
                energy_recovery_pause = 0.25
                _enter_energy_exhaustion()
            # Keep the held touch valid; no inward-thumb reset is needed.
            boost_confirm_elapsed = 0.0
            movement_boost_active = false
            if touch_ui != null:
                touch_ui.call("set_movement_boost", false)
    if guard_active and bool(part_stats.get("energy_shield", false)):
        if energy_exhausted or not _spend_energy(6.0 * delta):
            # Energy-backed guards must not become free while EN is locked.
            _set_guard(false)
    var was_energy_exhausted: bool = energy_exhausted
    _tick_resources(delta)
    _tick_energy_empty_flash(delta)
    if was_energy_exhausted and not energy_exhausted:
        # After 60% unlock, resume on the existing held outer-ring drag.
        _update_boost_gesture(BOOST_CONFIRM_SECONDS)
    stagger_remaining = maxf(0.0, stagger_remaining - delta)
    part_break_remaining = maxf(0.0, part_break_remaining - delta)
    if stagger_remaining <= 0.0:
        stagger_value = maxf(0.0, stagger_value - 8.0 * delta)
    # v163: symmetric eased 0.20s RUN <-> BOOST speed transitions.
    # This is independent of the 0.50s BOOST pose hold and 0.20s pose fade.
    _update_boost_speed(delta)
    # Hold BOOST pose for 0.50s after release from BOOST. The rig separately
    # blends BOOST -> RUN over 0.20s once the hold expires.
    # The hold counts down while crossing the 18px RUN deadzone;
    # speed and HUD mode still use the real BOOST state. Back-nozzle FX
    # follows the displayed pose during direction changes (v214).
    # Attacks, steps, guard, damage, jumps and touch release cancel the grace.
    if not gesture_active or guard_active or damage_reaction_active \
            or jump_active or landing_active or step_active or back_somersault_active \
            or combat_state != CombatState.IDLE:
        boost_pose_grace_remaining = 0.0
    elif movement_boost_active:
        boost_pose_grace_remaining = BOOST_POSE_GRACE_SECONDS
    else:
        boost_pose_grace_remaining = maxf(0.0, boost_pose_grace_remaining - delta)
    # When the training cube is at zero HP, suspend its firing cycle.
    if enemy_shooter != null:
        enemy_shooter.set("can_fire", target_hp > 0 and player_hp > 0.0
            and stagger_remaining <= 0.0 and part_break_remaining <= 0.0)
    # The authored 0.16667s reaction runs while the body moves. Only regain
    # control when BOTH the animation and short physical knockback are done.
    if down_remaining > 0.0:
        down_remaining = maxf(0.0, down_remaining - delta)
        if down_remaining <= 0.0:
            energy = TEST_EN_MAX
            shield = TEST_SH_MAX
            energy_exhausted = false
            energy_recovery_pause = 0.0
            shield_recovery_pause = 0.0
            damage_reaction_active = false
            damage_knockback_direction = Vector3.ZERO
            if rig != null:
                rig.call("finish_damage", false)
    if guard_break_remaining > 0.0:
        guard_break_remaining = maxf(0.0, guard_break_remaining - delta)
    if damage_reaction_active:
        _advance_damage_knockback(delta)
        if guard_break_remaining <= 0.0 and down_remaining <= 0.0 and damage_knockback_elapsed >= DAMAGE_KNOCKBACK_DURATION * float(part_stats.get("damage_time_mult", 1.0)) and rig != null and bool(rig.call("damage_finished")):
            damage_reaction_active = false
            damage_knockback_direction = Vector3.ZERO
            rig.call("finish_damage", gesture_active and direction_input.length_squared() > 0.000001)
            if jump_active:
                rig.call("resume_jump_fall")
    var running: bool = direction_input.length() > 0.001
    var stepping_this_frame: bool = step_active
    var jumping_this_frame: bool = jump_active
    var somersault_this_frame: bool = back_somersault_active
    var landing_this_frame: bool = landing_active
    # Snapshot before _advance_side_step() can finish the step on this frame.
    close_step_camera_this_frame = stepping_this_frame and step_close_camera
    var step_side_this_frame: int = step_side
    var kick_side_this_frame: int = side_kick_side
    var step_flick_this_frame: Vector2 = step_flick_direction
    if step_active:
        _advance_side_step(delta)
    if back_somersault_active:
        _advance_back_somersault(delta)
    if jump_active:
        _advance_jump(delta)
    if landing_this_frame:
        # Begin counting only from the first frame AFTER ground contact.
        _advance_landing(delta)
    if combat_state != CombatState.IDLE:
        if running and gesture_max_travel > TAP_MAX_TRAVEL \
                and not (bash_flick_candidate or side_kick_flick_candidate):
            _cancel_attack()
        elif hit_stop_remaining <= 0.0:
            _advance_attack(delta)
    if damage_reaction_active:
        # Freeze player input while physical knockback is applied above;
        # keep collision recovery available even in the damage state.
        player.velocity = Vector3.ZERO
        player.move_and_slide()
    elif jumping_this_frame or landing_this_frame or somersault_this_frame \
            or back_somersault_active or landing_active:
        # Any committed flight or landing owns displacement; no RUN tick
        # can interrupt the somersault on its first or final physics frame.
        player.velocity = Vector3.ZERO
    elif combat_state == CombatState.IDLE and not stepping_this_frame:
        # Keep v9 camera-relative input and choose animation relative to the
        # target-facing character, not to the camera or the screen.
        var world_move: Vector3 = _screen_drag_to_ground(direction_input) if running else Vector3.ZERO
        if rig != null:
            # Match RUN pose directions to SERA's real locked-part-facing
            # heading rather than the former whole-BODY reference.
            var target_forward: Vector3 = _locked_target_facing_direction()
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
            rig.call("set_moving", show_moving_pose, show_boost_pose,
                local_run_direction, movement_boost_active)
        if running:
            # v9 behavior: world_move already uses the current camera's ground axes.
            # Analog RUN strength reaches unity at the 112px rim; BOOST changes
            # speed only after the new 184.8px threshold is confirmed.
            player.velocity = world_move * float(part_stats.get("run_speed", 4.0625)) * boost_speed_multiplier
            # Drag keeps working along the cube's faces instead of becoming
            # blocked or falling through it. No world X/Z bounds are added.
        else:
            player.velocity = Vector3.ZERO
        player.move_and_slide()
    elif not stepping_this_frame and combat_state != CombatState.DASH \
            and combat_state != CombatState.BASH_TRACK and combat_state != CombatState.STRIKE_TRACK \
            and combat_state != CombatState.BACK_KICK_TRACK:
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
    # Keep effects tied to the confirmed BOOST action, not the rig animation.
    blur_active_this_physics_frame = (not damage_reaction_active and (
        blur_step_this_physics_frame or (combat_state == CombatState.IDLE
        and movement_boost_active and running)))
    # The paired SERA->BODY rays still determine AUTO candidates. Lock
    # selection never depends on the SERA body's displayed facing.
    # Keep a locked ID across the whole combo and its input windows.
    var aim: Vector3 = Vector3.ZERO
    if target_parts != null:
        var combo_held: bool = _combo_lock_retention_active()
        var locked_part_broken: bool = (
            not locked_target_part_id.is_empty()
            and not bool(target_parts.call("is_targetable", locked_target_part_id)))
        if not combo_held:
            if target_hp > 0 and (not manual_part_lock_active or locked_part_broken):
                # No AUTO delay: change to the current paired-ray candidate
                # in this tick after the committed combo has finished.
                # MANUAL and broken-part fallback retain their own gates.
                _acquire_stable_camera_part(delta, locked_part_broken)
                if locked_part_broken:
                    manual_part_lock_active = not auto_lock_enabled
            elif locked_part_broken:
                locked_target_part_id = ""
                manual_part_lock_active = not auto_lock_enabled
        else:
            # Keep the current lock through the full combo and follow-up
            # windows even though ordinary AUTO now changes immediately.
            auto_lock_pending_part = ""
            auto_lock_pending_elapsed = 0.0
    # SERA's collision root looks at the SELECTED part's horizontal
    # direction (BODY center when BODY is locked). Evaluate this after
    # the AUTO switch so heading and reticle agree in the same tick.
    aim = _locked_target_facing_direction()
    if aim.length_squared() > 0.000001:
        player.look_at(player.global_position + aim, Vector3.UP)
    # v310: persist the SCREEN flick pose for the full STEP, regardless of
    # SERA's changing lock-facing yaw/camera orbit. Motion and physical travel
    # must refer to the same committed screen direction. Kicks use their
    # dedicated clips and keep the existing target-relative orbit.
    if stepping_this_frame and rig != null and step_linear_fallback:
        rig.call("update_omni_step_direction", step_flick_this_frame, delta)
    # Real BOOST provides movement speed and costs EN. During a direction
    # change the rig keeps displaying BOOST for 0.50s and crossfades to RUN
    # over 0.20s; keep the nozzle flames present for that *visible* motion
    # even across a neutral-thumb frame. Heavy SLIDE by itself never fires.
    var boost_exhaust: bool = movement_boost_active and running \
        and combat_state == CombatState.IDLE
    var boost_pose_exhaust: bool = (
        gesture_active and boost_has_activated_this_gesture and rig != null
        and bool(rig.call("is_boost_exhaust_pose_visible")))
    var tracking_exhaust: bool = (
        combat_state == CombatState.DASH
        or combat_state == CombatState.BASH_TRACK
        or combat_state == CombatState.BACK_KICK_TRACK
        or combat_state == CombatState.STRIKE_TRACK
        or (combat_state == CombatState.STRIKE and not strike_did_hit)
        or (combat_state == CombatState.BASH and not bash_did_hit))
    # When a wall prevents a chase, do not display a false pursuing jet.
    # This movement-only condition is also the source for the acceleration
    # burst; it must NOT suppress the ordinary exhaust during a sword swing.
    tracking_exhaust = (tracking_exhaust
        or (back_somersault_active and not back_somersault_hit_checked)
        or (side_kick_active and step_elapsed < BASH_TRACK_SECONDS)) \
        and blur_velocity.length_squared() > 0.04
    # v284: Bash and all kicks share the three normal strikes' continuous
    # exhaust across homing, hit-stop and final follow-through. No chase-only
    # special-case remains for Bash.
    # One identical continuous-exhaust policy applies to ALL melee actions:
    # homing, strike, contact and full authored follow-through. The same
    # stable rearward nozzle is used whenever a swing has little velocity.
    var normal_melee_exhaust: bool = (
        combat_state == CombatState.MELEE_APPROACH
        or combat_state == CombatState.DASH
        or combat_state == CombatState.STRIKE_TRACK
        or combat_state == CombatState.STRIKE
        or combat_state == CombatState.BASH_TRACK
        or combat_state == CombatState.BASH
        or combat_state == CombatState.BACK_KICK_TRACK)
    var normal_kick_exhaust: bool = (kick_side_this_frame != 0
        or somersault_this_frame)
    var normal_attack_exhaust: bool = normal_melee_exhaust or normal_kick_exhaust
    var exhaust_on: bool = (not damage_reaction_active and not jump_active
        and not landing_active and not guard_active and not energy_exhausted
        and (boost_exhaust or boost_pose_exhaust or stepping_this_frame
            or tracking_exhaust or normal_attack_exhaust))
    # A short visual burst marks the *start* of high acceleration. STEP can
    # use move_and_collide() (not player.velocity); a homing attack must have
    # actual displacement before emitting, avoiding false wall-blocked jets.
    # Repeated strike/bash homing phases can restart a new flare when the
    # tracking state changes. Do not retrigger every physics frame.
    var tracking_accel_state: int = combat_state if tracking_exhaust else -1
    # Launch backflip with the existing one-shot acceleration flare.
    var new_somersault_burst: bool = (somersault_this_frame
        and back_somersault_launched and not thruster_accel_previous_somersault)
    var acceleration_burst: bool = (exhaust_on
        and ((stepping_this_frame and not thruster_accel_previous_step)
            or new_somersault_burst
            or (tracking_accel_state >= 0
                and tracking_accel_state != thruster_accel_previous_tracking_state)))
    thruster_accel_previous_step = stepping_this_frame
    thruster_accel_previous_somersault = somersault_this_frame and back_somersault_launched
    thruster_accel_previous_tracking_state = tracking_accel_state
    var direction_of_exhaust: Vector3 = -blur_velocity
    direction_of_exhaust.y = 0.0
    # A BOOST direction change should follow the live input when present,
    # even when a wall blocks velocity; with no new direction, retain the
    # last active nozzle heading instead of jumping to the body rear axis.
    if boost_pose_exhaust and running:
        var requested_boost: Vector3 = _screen_drag_to_ground(direction_input)
        if requested_boost.length_squared() > 0.000001:
            direction_of_exhaust = -requested_boost.normalized()
    elif boost_pose_exhaust and held_boost_exhaust_direction.length_squared() > 0.000001:
        direction_of_exhaust = held_boost_exhaust_direction
    if somersault_this_frame and back_somersault_launched:
        # Once the kick connects, exhaust opposes the actual rearward leap.
        direction_of_exhaust = -back_somersault_direction
    if normal_attack_exhaust and not tracking_exhaust \
            and not (somersault_this_frame and back_somersault_launched) \
            and not stepping_this_frame:
        # Full melee follow-through can have tiny collision/hit-stop position
        # jitter even while the blade is still airborne. Never steer these
        # small deltas into the body; hold a stable jet to SERA's rear.
        direction_of_exhaust = player.global_transform.basis.z
    if direction_of_exhaust.length_squared() < 0.0004:
        # A wall can stop BOOST or STEP while the control remains active.
        # Keep the nozzle pointed behind SERA instead of using a zero vector.
        direction_of_exhaust = player.global_transform.basis.z
    # A backward BOOST/STEP drives the actual nozzle downward like a
    # backstroke. Use the intended target-relative movement, not collision-
    # blocked velocity, to avoid a one-frame nozzle flip against a wall.
    # Partial rear diagonals blend continuously into the downward posture.
    var backstroke_weight: float = 0.0
    if stepping_this_frame:
        # A camera-UP gesture can be SERA-relative backward during an
        # oblique close-up: nozzle reverse bias must follow actual travel.
        if step_linear_fallback and step_linear_offset.length_squared() > 0.000001:
            var step_world_rear: Vector3 = Vector3(
                step_linear_offset.x, 0.0, step_linear_offset.y).normalized()
            backstroke_weight = clampf(step_world_rear.dot(
                player.global_transform.basis.z), 0.0, 1.0)
        else:
            backstroke_weight = clampf(step_flick_this_frame.y, 0.0, 1.0)
        # Legacy dedicated Backstep has no omnidirectional flick vector.
        if step_side_this_frame == STEP_BACK and step_flick_this_frame.is_zero_approx():
            backstroke_weight = 1.0
    elif somersault_this_frame and back_somersault_launched:
        backstroke_weight = 1.0
    elif boost_exhaust or boost_pose_exhaust:
        var intended_boost: Vector3 = _screen_drag_to_ground(direction_input)
        if intended_boost.length_squared() > 0.000001:
            backstroke_weight = clampf(intended_boost.normalized().dot(
                player.global_transform.basis.z), 0.0, 1.0)
        else:
            backstroke_weight = held_boost_backstroke_weight
    # Camera-left motion should fire toward the bottom-right of the SCREEN,
    # like a swimmer's backstroke, regardless of the target orbit or camera
    # heading. Blend by leftward input to keep diagonals continuous.
    var leftward_weight: float = 0.0
    if stepping_this_frame:
        leftward_weight = clampf(-step_flick_this_frame.x, 0.0, 1.0)
        if step_side_this_frame == -1 and step_flick_this_frame.is_zero_approx():
            leftward_weight = 1.0  # Legacy dedicated STEP_LEFT input.
    elif (boost_exhaust or boost_pose_exhaust) and direction_input.length_squared() > 0.000001:
        leftward_weight = clampf(-direction_input.normalized().x, 0.0, 1.0)
    # A leftward STEP/BOOST uses the screen-down -> screen-right fan.
    # Previously ANY left component overrode the backstroke nozzle pitch:
    # back-left diagonal BOOST could keep a sideways nozzle even while
    # moving rearward. Blend that special sector BACK TO WORLD DOWN by the
    # same actor-relative backstroke weight used for the normal nozzle.
    # Pure-left still targets its original 45-degree down/right aim.
    var left_sector_world: Vector3 = Vector3.ZERO
    if exhaust_on and leftward_weight > 0.0:
        var screen_right: Vector3 = _screen_drag_to_ground(Vector2.RIGHT).normalized()
        left_sector_world = Vector3.DOWN.slerp(
            screen_right, leftward_weight * 0.50).normalized()
        left_sector_world = left_sector_world.slerp(
            Vector3.DOWN, backstroke_weight).normalized()
    if boost_pose_exhaust:
        if running:
            held_boost_exhaust_direction = direction_of_exhaust.normalized()
            held_boost_backstroke_weight = backstroke_weight
            held_boost_left_sector_world = left_sector_world
        elif held_boost_exhaust_direction.length_squared() > 0.000001:
            # Neutral thumb: preserve the previous direction AND special
            # backstroke / camera-left limits until a new heading is supplied.
            backstroke_weight = held_boost_backstroke_weight
            left_sector_world = held_boost_left_sector_world
    elif not boost_exhaust:
        held_boost_exhaust_direction = Vector3.ZERO
        held_boost_backstroke_weight = 0.0
        held_boost_left_sector_world = Vector3.ZERO
    rig.call("update_back_thruster_fx", exhaust_on,
        direction_of_exhaust.normalized(), delta, backstroke_weight,
        left_sector_world, acceleration_burst, normal_attack_exhaust)
    _update_melee_lock_marker()  # Update after player movement and auto-approach.
    # The idle HUD shows lateral step speed; equipment changes still refresh it.
    if not step_active and step_status_label != null:
        var next_speed_label: String = "STEP SPEED %.1fm/s" % (
            STEP_SPEED * float(part_stats.get("step_speed_mult", 1.0)))
        if step_status_label.text != next_speed_label:
            _refresh_step_status_ui()
    if floor_stage != null:
        floor_stage.position = Vector3(
            roundf(player.position.x / 4.0) * 4.0,
            0.0,
            roundf(player.position.z / 4.0) * 4.0
        )
    if down_remaining > 0.0:
        state_label.text = "DOWN / INVULNERABLE"
    elif guard_break_remaining > 0.0:
        state_label.text = "GUARD BREAK  %d/%d" % [
            guard_break_hits, int(part_stats.get("down_hits", 3))]
    elif damage_reaction_active:
        state_label.text = "DAMAGE  |  Damageknock"
    elif guard_active:
        state_label.text = "GUARD HIT  |  Guard_REACTION" if bool(rig.call("guard_reaction_playing")) else "GUARD  |  Guard"
    elif back_somersault_active or somersault_this_frame:
        state_label.text = ("KICK BACK  |  Kick_b" if back_somersault_has_authored_clip
            else "KICK BACK  |  Jump FALLBACK")
    elif landing_this_frame or landing_active:
        state_label.text = ("KICK BACK LAND  |  0.2s" if landing_from_somersault
            else "JUMP LAND  |  Jump")
    elif jumping_this_frame and combat_state == CombatState.IDLE and not stepping_this_frame:
        state_label.text = "AIR FALL  |  Jump" if jump_fall_after_action else "JUMP  |  Jump (1.5m)"
    elif stepping_this_frame:
        if kick_side_this_frame != 0:
            state_label.text = "KICK RIGHT  |  Kick_r" if kick_side_this_frame > 0 else "KICK LEFT  |  Kick_l"
        elif step_flick_this_frame.y < -0.8:
            state_label.text = "STEP FORWARD  |  Frontstep"
        elif step_flick_this_frame.y > 0.8:
            state_label.text = "STEP BACK  |  Backstep"
        elif absf(step_flick_this_frame.y) > 0.15:
            state_label.text = "STEP DIAGONAL  |  BLENDED"
        else:
            state_label.text = "STEP RIGHT  |  Step_R" if step_side_this_frame > 0 else "STEP LEFT  |  Step_L"
    else:
        match combat_state:
            CombatState.MELEE_APPROACH:
                state_label.text = "MELEE APPROACH  |  meleeboost"
            CombatState.DASH:
                state_label.text = "MELEE BOOST  %.1fm/s  %.2f/%.1fs" % [
                    float(part_stats.get("melee_boost_speed", MELEE_BOOST_DEFAULT_SPEED)),
                    melee_boost_elapsed,
                    float(part_stats.get("melee_boost_duration", MELEE_BOOST_DEFAULT_DURATION))]
            CombatState.STRIKE:
                var count: int = _strike_stage_count()
                if buffered_side_kick_side == 2:
                    state_label.text = "STRIKE %d/%d  |  KICK B QUEUED" % [
                        strike_index + 1, count]
                elif buffered_side_kick_side != 0:
                    state_label.text = "STRIKE %d/%d  |  KICK QUEUED" % [
                        strike_index + 1, count]
                else:
                    state_label.text = "STRIKE %d/%d  |  %s" % [
                        strike_index + 1, count, _active_strike_clip(strike_index)]
            CombatState.BACK_KICK_TRACK:
                state_label.text = "KICK BACK TRACK  %.2f / %.2fs" % [
                    back_kick_track_elapsed, BASH_TRACK_SECONDS]
            CombatState.BASH_TRACK:
                state_label.text = "BASH WINDUP  %.2f / %.2fs" % [
                    bash_track_elapsed, BASH_TRACK_SECONDS]
            CombatState.STRIKE_TRACK:
                state_label.text = "MELEE %d WINDUP  %.2f / %.2fs" % [
                    strike_index + 1, followup_track_elapsed, FOLLOWUP_TRACK_SECONDS]
            CombatState.BASH:
                state_label.text = "SHIELD BASH  |  Bash"
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
    # At 90-120Hz render vs 60Hz physics, current tick positions alternate
    # between stale and new values. Follow what the interpolated actors show.
    camera_player_render_position = player.get_global_transform_interpolated().origin
    camera_target_render_position = target.get_global_transform_interpolated().origin
    _update_lock_line_visuals()
    # Elapsed training time stays in the active profile until an explicit SAVE.
    SeraSave.record_training_time(delta)
    SeraSave.record_game_time(delta)
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
    # Sample the camera follow focus once per rendered frame. _place_camera
    # and fit searches must all use the same frozen focus for that frame.
    _advance_camera_follow_focus(delta)
    var radial: Vector2 = Vector2(
        camera_player_render_position.x - camera_target_render_position.x,
        camera_player_render_position.z - camera_target_render_position.z
    )
    var separation: float = radial.length()
    # Auto-approach is camera movement, not idle recentering.
    var running: bool = (direction_input.length_squared() > 0.000001
        or combat_state == CombatState.DASH
        or combat_state == CombatState.BASH_TRACK
        or combat_state == CombatState.STRIKE_TRACK
        or (combat_state == CombatState.BASH and not bash_did_hit)
        or (combat_state == CombatState.STRIKE and not strike_did_hit)
        or step_active)
    var bearing: float = camera_yaw
    if separation > 0.08:
        bearing = atan2(radial.x, radial.y)

    # When the player approaches the target, dolly IN smoothly (but stop at
    # a wider close-up than v51). Never crop
    # the rectangular boss: _fit_full_frame() tests all eight outer corners.
    # At longer distances, retain the original standard composition.
    # Close BOOST moves fast enough for edge yaw correction and its subsequent
    # zoom fit to fight each other, especially for screen-left/rear movement.
    # Hysteresis prevents mode chatter near the distance boundary. The close
    # STEP camera has its own independent angular limit.
    var active_boost_travel: bool = (movement_boost_active and running
        and combat_state == CombatState.IDLE and not step_active)
    if close_boost_camera_active:
        close_boost_camera_active = (
            (active_boost_travel or (gesture_active and boost_pose_grace_remaining > 0.0))
            and separation < CAMERA_CLOSE_BOOST_EXIT_DISTANCE)
    elif active_boost_travel and separation <= CAMERA_CLOSE_BOOST_ENTER_DISTANCE:
        close_boost_camera_active = true

    # A combo or committed kick holds camera ZOOM, not its orientation.
    # Continue tracking SERA in position and yaw with v288's short-delay
    # leashes. Keep the zoom hold 0.45s after the final blow to prevent
    # back-to-back attack dolly pumping.
    var active_attack_camera: bool = (
        combat_state != CombatState.IDLE
        or side_kick_active or back_somersault_active
        or landing_active or damage_reaction_active
        or hit_stop_remaining > 0.0)
    if active_attack_camera:
        camera_combat_hold_remaining = CAMERA_COMBAT_YAW_HOLD_SECONDS
    else:
        camera_combat_hold_remaining = maxf(0.0,
            camera_combat_hold_remaining - maxf(delta, 0.0))
    var hold_attack_camera: bool = camera_combat_hold_remaining > 0.0
    var easing: float = 1.0 - exp(-CAMERA_FOLLOW_RATE * delta)
    var zoom_ratio: float = clampf(
        (separation - CAMERA_CLOSE_RANGE) / (CAMERA_FAR_RANGE - CAMERA_CLOSE_RANGE),
        0.0, 1.0
    )
    zoom_ratio = zoom_ratio * zoom_ratio * (3.0 - 2.0 * zoom_ratio)
    var preferred_radius: float = lerpf(
        CAMERA_CLOSE_RADIUS, CAMERA_BASE_RADIUS, zoom_ratio) * CAMERA_DISTANCE_SCALE
    # A requested closer zoom must NEVER override the player-behind-camera
    # safety clearance; frame-fit can also move the camera farther out.
    preferred_radius = maxf(preferred_radius, separation + 2.0)
    # v234: derive near-field dolly speed from the ACTUAL interpolated
    # player-target closing rate. A filtered derivative prevents small physics
    # corrections or input turns from shaking the zoom. This controls only
    # inward movement; outward zoom retains the existing exponential follow.
    var raw_closing_speed: float = 0.0
    if camera_last_separation >= 0.0 and delta > 0.00001:
        raw_closing_speed = clampf(
            (camera_last_separation - separation) / delta,
            0.0, CAMERA_NEAR_DOLLY_MAX_CLOSING_SAMPLE)
    camera_last_separation = separation
    var closing_blend: float = 1.0 - exp(
        -CAMERA_NEAR_DOLLY_SPEED_FILTER_RATE * maxf(delta, 0.0))
    camera_filtered_closing_speed = lerpf(
        camera_filtered_closing_speed, raw_closing_speed, closing_blend)
    camera_near_dolly_weight = clampf(
        (CAMERA_NEAR_DOLLY_BLEND_START - separation) /
        (CAMERA_NEAR_DOLLY_BLEND_START - CAMERA_NEAR_DOLLY_BLEND_FULL),
        0.0, 1.0)
    camera_near_dolly_weight = camera_near_dolly_weight * camera_near_dolly_weight * (
        3.0 - 2.0 * camera_near_dolly_weight)
    var follow_easing: float = easing * 0.9
    if hold_attack_camera:
        # Never run the velocity-reactive inward dolly during individual
        # strikes: intermittent contact and hit-stop previously caused
        # a different camera distance at every attack. Only move OUT,
        # smoothly, to a modest frame-safe radius. _fit_full_frame may
        # still expand if actual objects approach a viewport boundary.
        camera_follow_radius = move_toward(
            camera_follow_radius,
            maxf(camera_follow_radius, CAMERA_COMBAT_MIN_RADIUS * CAMERA_DISTANCE_SCALE),
            CAMERA_COMBAT_ZOOM_OUT_SPEED * maxf(delta, 0.0))
        camera_dolly_in_speed = 0.0
        camera_filtered_closing_speed = 0.0
    elif camera_follow_radius > preferred_radius and delta > 0.00001:
        var distance_to_preferred: float = camera_follow_radius - preferred_radius
        var old_inward_speed: float = distance_to_preferred * follow_easing / delta
        var near_inward_speed: float = maxf(
            CAMERA_NEAR_DOLLY_SETTLE_SPEED,
            camera_filtered_closing_speed * CAMERA_NEAR_DOLLY_PLAYER_SPEED_RATIO)
        var requested_inward_speed: float = lerpf(
            old_inward_speed, near_inward_speed, camera_near_dolly_weight)
        if camera_near_dolly_weight <= 0.00001:
            # Far-field behavior is exactly the original follow equation.
            camera_dolly_in_speed = old_inward_speed
        else:
            # Acceleration/deceleration bounded, with no sign reversal or
            # overshoot even when target movement suddenly stops.
            camera_dolly_in_speed = move_toward(
                camera_dolly_in_speed, requested_inward_speed,
                CAMERA_NEAR_DOLLY_MAX_ACCEL * delta)
        # Exponential gap braking avoids a hard stop at the exact preferred
        # radius, including when input/target motion changes abruptly.
        var gap_stop_speed: float = distance_to_preferred * (
            1.0 - exp(-CAMERA_NEAR_DOLLY_GAP_RATE * delta)) / delta
        camera_dolly_in_speed = minf(camera_dolly_in_speed, gap_stop_speed)
        camera_follow_radius = maxf(
            preferred_radius, camera_follow_radius - camera_dolly_in_speed * delta)
    else:
        camera_follow_radius = lerpf(
            camera_follow_radius, preferred_radius, follow_easing)
        camera_dolly_in_speed = 0.0
    # The normal dolly must not try to erase a forced frame-fit zoom.
    camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)
    _place_camera()

    var protect_close_step: bool = (close_step_camera_this_frame
        or (close_step_camera_recovery_remaining > 0.0 and not gesture_active))
    # Boost stays screen-direction aligned. During combos and all side-kick
    # animations DO NOT change camera yaw at all, even during the orbit.
    # Normal 360deg STEP also retains its committed screen camera basis.
    var boost_edge_frame_guard: bool = (gesture_active and not protect_close_step
        and not hold_attack_camera and combat_state == CombatState.IDLE
        and not step_active and
        (movement_boost_active or boost_pose_grace_remaining > 0.0))
    if hold_attack_camera or step_active or close_step_camera_this_frame:
        # Only ordinary screen-relative STEP freezes yaw for its short
        # committed trajectory. Kick/Strike/Bash/Somersault keep tracking
        # SERA under the 12deg hard angular leash even during attacks.
        if (not step_active or side_kick_active) and separation > 0.08:
            camera_yaw = _stable_shoulder_camera_yaw(bearing, delta)
        _place_camera()
        _update_side_from_screen()
    elif protect_close_step and separation > 0.08:
        # An ordinary close STEP may gently recover, never with the old
        # frame-by-frame silhouette-search or sudden 45deg corrections.
        camera_yaw = _stable_shoulder_camera_yaw(bearing, delta)
        _place_camera()
        _update_side_from_screen()
    elif running:
        camera_yaw = _stable_shoulder_camera_yaw(bearing, delta)
        _place_camera()
        _update_side_from_screen()
        if not close_boost_camera_active and not boost_edge_frame_guard \
                and separation > CAMERA_COMBAT_VISIBILITY_DISTANCE:
            _enforce_screen_edge(bearing, delta)
    else:
        # Never snap behind a leg or abruptly switch the camera shoulder
        # after an attack. Use one continuous, low-speed idle follow.
        if separation > 0.08:
            camera_yaw = _stable_shoulder_camera_yaw(bearing, delta)
        _place_camera()
        if not close_boost_camera_active and not boost_edge_frame_guard \
                and separation > CAMERA_COMBAT_VISIBILITY_DISTANCE:
            _enforce_screen_edge(bearing, delta)

    # Frame protection applies in BOTH modes, but never enforces the gap
    # during drag. This maintains full left-to-right control.
    if boost_edge_frame_guard:
        # No iterative per-frame bisection on outward left/right BOOST:
        # solve the minimum perspective radius directly from the silhouettes.
        _fit_boost_frame_analytically(delta)
    else:
        _fit_full_frame()
        if not hold_attack_camera:
            _relax_camera_fit_radius(delta)
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


# v288: keep the tracking anchor near SERA, with a short (up to 2m)
# lead toward the target for composition. At long range it translates
# with SERA essentially one-for-one instead of orbiting a stationary boss.
func _desired_camera_follow_focus_xz() -> Vector2:
    var player_xz: Vector2 = Vector2(
        camera_player_render_position.x, camera_player_render_position.z)
    var target_xz: Vector2 = Vector2(
        camera_target_render_position.x, camera_target_render_position.z)
    return player_xz + (target_xz - player_xz).limit_length(
        CAMERA_PLAYER_FOCUS_LEAD_METERS)


# Light exponential damping followed by a hard 0.65m leash. Once the
# cap is reached, translation matches SERA frame-for-frame with no
# accumulating spring momentum, oscillation, or long catch-up delay.
func _advance_camera_follow_focus(delta: float) -> void:
    var desired: Vector2 = _desired_camera_follow_focus_xz()
    var alpha: float = 1.0 - exp(
        -CAMERA_PLAYER_FOCUS_FOLLOW_RATE * maxf(delta, 0.0))
    camera_focus_follow_xz = camera_focus_follow_xz.lerp(desired, alpha)
    var error: Vector2 = desired - camera_focus_follow_xz
    if error.length_squared() > (
            CAMERA_PLAYER_FOCUS_MAX_LAG_METERS * CAMERA_PLAYER_FOCUS_MAX_LAG_METERS):
        camera_focus_follow_xz = desired - error.normalized() * (
            CAMERA_PLAYER_FOCUS_MAX_LAG_METERS)


# The same short-delay angular leash follows SERA through 3-hit combos.
# At >12deg error, track at SERA's angular speed, never letting the view
# fall to 90deg sideways. Ordinary STEP input retains its locked yaw.
func _stable_shoulder_camera_yaw(player_bearing: float, delta: float) -> float:
    var desired: float = player_bearing - deg_to_rad(
        CAMERA_COMBAT_SHOULDER_DEGREES)
    var error: float = wrapf(desired - camera_yaw, -PI, PI)
    var alpha: float = 1.0 - exp(
        -CAMERA_PLAYER_YAW_FOLLOW_RATE * maxf(delta, 0.0))
    var residual: float = error * (1.0 - alpha)
    var leash: float = deg_to_rad(CAMERA_PLAYER_YAW_MAX_LAG_DEGREES)
    return camera_yaw + error - clampf(residual, -leash, leash)


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
    var torso: Vector3 = camera_player_render_position + Vector3(0.0, 1.05, 0.0)
    if camera.is_position_behind(torso):
        return
    var offset: float = camera.unproject_position(torso).x - size.x * 0.5
    if offset > SIDE_SWITCH_PIXELS:
        player_screen_side = 1
    elif offset < -SIDE_SWITCH_PIXELS:
        player_screen_side = -1
    # Precisely centered: retain the last side until input makes it unambiguous.


func _signed_screen_gap(side: int) -> float:
    # Project the elongated body plus its four rectangular outer legs.
    # Using the camera's RIGHT vector works even after orbiting 90+ degrees.
    var view_right: Vector3 = camera.global_transform.basis.x.normalized()
    var torso: Vector3 = camera_player_render_position + Vector3(0.0, 1.05, 0.0)
    var pleft: Vector3 = torso - view_right * CAMERA_BODY_HALF_WIDTH
    var pright: Vector3 = torso + view_right * CAMERA_BODY_HALF_WIDTH
    if camera.is_position_behind(pleft) or camera.is_position_behind(pright):
        return -1.0e7
    var px_min: float = camera.unproject_position(pleft).x
    var px_max: float = camera.unproject_position(pright).x
    # A rectangular mechanical boss can be wider diagonally than its 2m core.
    var tx_min: float = INF
    var tx_max: float = -INF
    for dx in [-TARGET_FRAME_HALF_WIDTH, TARGET_FRAME_HALF_WIDTH]:
        for dz in [-TARGET_FRAME_HALF_DEPTH, TARGET_FRAME_HALF_DEPTH]:
            var corner: Vector3 = camera_target_render_position + Vector3(dx, 0.0, dz)
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


func _enforce_screen_edge(bearing: float, delta: float) -> void:
    # Only the outer safe frame is a hard limit while dragging. The target
    # overlap area has no force-field and can be crossed in either direction.
    # Start correction before either hard edge, preventing left/right yaw snap.
    if _horizontal_safe(CAMERA_EDGE_GUARD_RATIO):
        return
    var old_yaw: float = camera_yaw
    camera_yaw = bearing
    _place_camera()
    if not _horizontal_safe(CAMERA_EDGE_GUARD_RATIO):
        # If yaw alone cannot protect the frame, use existing fit zoom.
        camera_yaw = old_yaw
        _place_camera()
        return
    var low: float = 0.0
    var high: float = 1.0
    for i in range(17):
        var fraction: float = (low + high) * 0.5
        camera_yaw = lerp_angle(old_yaw, bearing, fraction)
        _place_camera()
        if _horizontal_safe(CAMERA_EDGE_GUARD_RATIO):
            high = fraction
        else:
            low = fraction
    var safe_yaw: float = lerp_angle(old_yaw, bearing, high)
    var delta_yaw: float = wrapf(safe_yaw - old_yaw, -PI, PI)
    var max_step: float = deg_to_rad(
        CAMERA_EDGE_MAX_CORRECTION_DEGREES_PER_SECOND) * maxf(delta, 0.0)
    camera_yaw = old_yaw + clampf(delta_yaw, -max_step, max_step)
    _place_camera()


# v232: perspective fitting is algebraic when yaw, pitch and focus are fixed.
# The minimum camera radius follows from the screen-space margin inequalities
# for each protected point. This is O(corners), not 16+ recursive reprojections.
func _camera_radius_for_safe_point(point: Vector3, focus: Vector3,
        screen_right: Vector3, screen_up: Vector3, outward: Vector3,
        radial_scale: float, tan_h: float, tan_v: float,
        margin_x: float, margin_top: float, margin_bottom: float) -> float:
    var offset: Vector3 = point - focus
    var screen_x: float = offset.dot(screen_right)
    var screen_y: float = offset.dot(screen_up)
    var horizontal_depth: float = absf(screen_x) / maxf(
        0.0001, tan_h * (1.0 - 2.0 * margin_x))
    var vertical_depth: float = 0.0
    if screen_y >= 0.0:
        vertical_depth = screen_y / maxf(
            0.0001, tan_v * (1.0 - 2.0 * margin_top))
    else:
        vertical_depth = -screen_y / maxf(
            0.0001, tan_v * (2.0 * margin_bottom - 1.0))
    # Camera-space depth = radial_scale * radius - offset.dot(outward).
    var depth: float = maxf(camera.near + 0.005,
        maxf(horizontal_depth, vertical_depth))
    return maxf(0.0, (depth + offset.dot(outward)) / radial_scale)


func _minimum_boost_camera_radius() -> float:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return camera_radius
    var aspect: float = viewport_size.x / viewport_size.y
    # Camera3D KEEP_HEIGHT is the project's default: FOV is vertical.
    var tan_v: float = tan(deg_to_rad(camera.fov) * 0.5)
    var tan_h: float = tan_v * aspect
    if camera.keep_aspect == Camera3D.KEEP_WIDTH:
        tan_h = tan(deg_to_rad(camera.fov) * 0.5)
        tan_v = tan_h / aspect
    var screen_right: Vector3 = camera.global_transform.basis.x.normalized()
    var screen_up: Vector3 = camera.global_transform.basis.y.normalized()
    var outward: Vector3 = Vector3(
        sin(camera_yaw), CAMERA_ELEVATION_RATIO, cos(camera_yaw))
    var radial_scale: float = outward.length()
    outward /= radial_scale
    var focus: Vector3 = Vector3(
        camera_focus_follow_xz.x, TARGET_BASE_HEIGHT - CAMERA_FOCUS_DROP,
        camera_focus_follow_xz.y)

    var min_radius: float = 0.0
    var torso: Vector3 = camera_player_render_position + Vector3(0.0, 1.05, 0.0)
    for lateral in [-CAMERA_SAFE_CORE_HALF_WIDTH, 0.0, CAMERA_SAFE_CORE_HALF_WIDTH]:
        min_radius = maxf(min_radius, _camera_radius_for_safe_point(
            torso + screen_right * lateral, focus,
            screen_right, screen_up, outward, radial_scale, tan_h, tan_v,
            SCREEN_MARGIN_X, 0.0, 1.0))
    for height in [CAMERA_HEAD_HEIGHT, 0.08]:
        min_radius = maxf(min_radius, _camera_radius_for_safe_point(
            camera_player_render_position + Vector3(0.0, height, 0.0), focus,
            screen_right, screen_up, outward, radial_scale, tan_h, tan_v,
            0.0, SCREEN_MARGIN_TOP, SCREEN_MARGIN_BOTTOM))
    for dx in [-TARGET_FRAME_HALF_WIDTH, TARGET_FRAME_HALF_WIDTH]:
        for dy in [-TARGET_FRAME_HALF_HEIGHT, TARGET_FRAME_HALF_HEIGHT]:
            for dz in [-TARGET_FRAME_HALF_DEPTH, TARGET_FRAME_HALF_DEPTH]:
                min_radius = maxf(min_radius, _camera_radius_for_safe_point(
                    camera_target_render_position + Vector3(dx, dy, dz), focus,
                    screen_right, screen_up, outward, radial_scale, tan_h, tan_v,
                    TARGET_FRAME_MARGIN_X, TARGET_FRAME_MARGIN_Y,
                    TARGET_FRAME_BOTTOM))
    return min_radius


func _camera_fit_release_speed() -> float:
    # Near-field closing uses the SAME inward speed budget for the fitted
    # safety radius. A fixed 1.25m/s release would otherwise leave the camera
    # far behind the player's approach even after the follow dolly speeds up.
    # This does not relax a minimum frame-safe radius.
    return maxf(CAMERA_FIT_RELAX_SPEED,
        camera_dolly_in_speed * camera_near_dolly_weight)


func _fit_boost_frame_analytically(delta: float) -> void:
    var safe_radius: float = (_minimum_boost_camera_radius()
        + CAMERA_FIT_RADIUS_RESERVE)
    # Only shrink when safely ABOVE the newly required radius. The old
    # _relax_camera_fit_radius could shrink below a margin and force the next
    # frame to enlarge again: a small but persistent zoom sawtooth.
    if camera_fit_radius_floor < safe_radius:
        camera_fit_radius_floor = safe_radius
    else:
        camera_fit_radius_floor = move_toward(camera_fit_radius_floor,
            safe_radius, _camera_fit_release_speed() * maxf(delta, 0.0))
    camera_radius = maxf(camera_follow_radius, camera_fit_radius_floor)
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
        # Reserve a little room to prevent the follow-zoom from oscillating
        # across an exactly fitted boundary on the next rendered frame.
        camera_radius = upper_radius + CAMERA_FIT_RADIUS_RESERVE
        # A fitted radius must survive the next frame's preferred close zoom;
        # otherwise the camera repeatedly expands and contracts at the edge.
        camera_fit_radius_floor = maxf(camera_fit_radius_floor, camera_radius)
        _place_camera()


func _relax_camera_fit_radius(delta: float) -> void:
    if camera_fit_radius_floor <= 0.0:
        return
    # Trial-release the guard slowly; commit only when the actual target and
    # player silhouettes still fit. No fixed timer, distance guess or repeated
    # forced-zoom sawtooth near the left/rear BOOST screen boundary.
    var candidate_floor: float = maxf(0.0,
        camera_fit_radius_floor - _camera_fit_release_speed() * maxf(delta, 0.0))
    var candidate_radius: float = maxf(camera_follow_radius, candidate_floor)
    if candidate_radius >= camera_radius:
        camera_fit_radius_floor = candidate_floor
        return
    var previous_radius: float = camera_radius
    camera_radius = candidate_radius
    _place_camera()
    if _full_frame_safe():
        camera_fit_radius_floor = candidate_floor
    else:
        camera_radius = previous_radius
        _place_camera()


func _place_camera() -> void:
    # Look below the target center so both combatants sit in the upper
    # playable portion of the portrait screen. Moving the camera with the
    # lower focus (rather than applying a canvas or HUD offset) preserves
    # world projection for drag, hit effects and screen-edge checks.
    # Fixed vertical reference avoids idle-bob camera shake. Elevation is
    # unchanged (the previous overhead adjustment stays removed).
    var focus: Vector3 = Vector3(
        camera_focus_follow_xz.x, TARGET_BASE_HEIGHT - CAMERA_FOCUS_DROP,
        camera_focus_follow_xz.y)
    camera.position = focus + Vector3(
        sin(camera_yaw) * camera_radius,
        CAMERA_ELEVATION_RATIO * camera_radius,
        cos(camera_yaw) * camera_radius
    )
    camera.far = maxf(200.0, camera_radius * 3.0)
    camera.look_at(focus, Vector3.UP)


func _horizontal_safe(extra_margin_ratio: float = 0.0) -> bool:
    var size: Vector2 = get_viewport().get_visible_rect().size
    if size.x <= 0.0:
        return true
    var right: Vector3 = camera.global_transform.basis.x.normalized()
    var torso: Vector3 = camera_player_render_position + Vector3(0.0, 1.05, 0.0)
    for x_offset in [-CAMERA_SAFE_CORE_HALF_WIDTH, 0.0, CAMERA_SAFE_CORE_HALF_WIDTH]:
        var point: Vector3 = torso + right * x_offset
        if camera.is_position_behind(point):
            return false
        var screen: Vector2 = camera.unproject_position(point)
        if screen.x < size.x * (SCREEN_MARGIN_X + extra_margin_ratio) \
                or screen.x > size.x * (1.0 - SCREEN_MARGIN_X - extra_margin_ratio):
            return false
    return true


func _target_fully_in_frame() -> bool:
    # Fit all corners of the rectangular boss including head and side legs,
    # not merely the center of the physical torso.
    var size: Vector2 = get_viewport().get_visible_rect().size
    if size.x <= 0.0 or size.y <= 0.0:
        return true
    for dx in [-TARGET_FRAME_HALF_WIDTH, TARGET_FRAME_HALF_WIDTH]:
        for dy in [-TARGET_FRAME_HALF_HEIGHT, TARGET_FRAME_HALF_HEIGHT]:
            for dz in [-TARGET_FRAME_HALF_DEPTH, TARGET_FRAME_HALF_DEPTH]:
                var world_corner: Vector3 = camera_target_render_position + Vector3(dx, dy, dz)
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
    var top: Vector3 = camera_player_render_position + Vector3(0.0, CAMERA_HEAD_HEIGHT, 0.0)
    var bottom: Vector3 = camera_player_render_position + Vector3(0.0, 0.08, 0.0)
    if camera.is_position_behind(top) or camera.is_position_behind(bottom):
        return false
    var upper_screen: Vector2 = camera.unproject_position(top)
    var lower_screen: Vector2 = camera.unproject_position(bottom)
    return upper_screen.y >= size.y * SCREEN_MARGIN_TOP and lower_screen.y <= size.y * SCREEN_MARGIN_BOTTOM
