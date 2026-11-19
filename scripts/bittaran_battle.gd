extends "res://scripts/main.gd"
## Dedicated Bittaran battle. Reuse proven SERA controls/combat/camera/HP,
## but replace the red training dummy with the authored quadruped.
const BittaranRig = preload("res://scripts/bittaran_rig.gd")
const BittaranAI = preload("res://scripts/bittaran_ai.gd")
const BittaranFootIK = preload("res://scripts/bittaran_foot_ik.gd")
const BittaranParts = preload("res://scripts/bittaran_parts.gd")
const BittaranAttacks = preload("res://scripts/bittaran_attacks.gd")
const BittaranDirtFX = preload("res://scripts/bittaran_dirt_fx.gd")
const BittaranRailgun = preload("res://scripts/bittaran_railgun.gd")
const BittaranSweepFXTrack = preload("res://scripts/bittaran_sweep_fx_track.gd")
const DOWN_CLEARANCE = preload("res://scripts/bittaran_down_clearance.gd")
const CONTROLLER_AXIS = preload("res://scripts/bittaran_controller_axis.gd")
const NAME_TEXT: String = "BITTARAN  /  ビットタラン"
const BOSS_WORLD_SCALE: float = 2.0
# v434: isolate the actual 17:21 Blockbench rotations and positions first.
# No supporting-leg IK, pose-independent head tracking, contact snap,
# pre-attack stance, or dynamic body height compensation in this mode.
# Reintroduce support IK only after comparing source poses in Godot.
const BLOCKBENCH_SOURCE_REPLAY_ONLY: bool = false
# v435: keep v434 source keys, but enable ONLY the isolated diagonal
# locomotion IK and the three non-striking support limbs during attacks.
# The original 4k-line legacy torso/chest compensation is not reenabled.
const BLOCKBENCH_GAIT_SUPPORT_IK: bool = true
const BOSS_DEATH_RESPAWN_SECONDS: float = 3.0
# During attacks only the articulated chest can follow the player.
# The boss root, gait and planted support-foot positions stay fixed.
const ATTACK_CHEST_TURN_DEGREES_PER_SECOND: float = 100.0
# v409: the chest yaw is capped at a range a heavy quadruped torso
# can actually twist through. The old 140-degree cap (100 deg/s
# slew over the windup) let the BODY bone corkscrew up to ~127
# degrees on a STOMP when the player circled behind.
const ATTACK_CHEST_MAX_YAW_DEGREES: float = 60.0
# v409: the chest turns the ATTACKING LEG'S HIP CORNER toward the
# player, instead of facing a fixed 45 degrees across the arm.
# The corner bearings are the legs' rest hip positions in
# boss-local space (measured in-scene): the front hips sit ~34
# degrees off the nose, the rear hips ~146 degrees. The old
# formula applied the front-leg 45-degree offset to the rear legs
# too, so aiming a rear leg at a player behind asked the chest
# for ~135 degrees of yaw and the body twisted grotesquely;
# turning the rear corner toward that player needs only ~34.
const ATTACK_CHEST_CORNER_DEGREES: Dictionary = {
    "leg_fl": 34.4, "leg_fr": -33.8,
    "leg_rl": 145.8, "leg_rr": -146.0,
}
const BOSS_FAR_SIDE_ENTER_METERS: float = 0.65
const BOSS_FAR_SIDE_EXIT_METERS: float = -0.25
const DOWN_ESCAPE_SPEED_MPS: float = 15.0
const HEAD_TRACK_MAX_YAW_DEGREES: float = 90.0
# The returned/neutral FRONT ARM pivots form a mechanical head-look
# envelope, independent of whether the currently animated arm actually
# intersects the head. Reserve clearance before the returning shoulder.
const HEAD_ARM_RETURN_GUARD_DEGREES: float = 45.0
const HEAD_ARM_RETURN_MIN_YAW_DEGREES: float = 40.0
const HEAD_TRACK_DEGREES_PER_SECOND: float = 140.0
# HEAD looks down/up from its actual neck pivot: yaw first, then a LOCAL
# pitch, never roll. Only the part-break anticipation and shin clearance
# can translate it vertically. The player is followed through rotation.
const HEAD_PITCH_MIN_DEGREES: float = -90.0
const HEAD_PITCH_MAX_DEGREES: float = 90.0
const HEAD_PITCH_TURN_DEGREES_PER_SECOND: float = 120.0
const HEAD_PITCH_FILTER_PER_SECOND: float = 8.0
const HEAD_PITCH_MIN_HORIZONTAL_METERS: float = 0.55
const HEAD_VERTICAL_FILTER_PER_SECOND: float = 8.0
const HEAD_VERTICAL_MAX_SPEED_MPS: float = 1.40
# World-level HEAD is wider across planted shins than the old angled
# head. Clear REAL animated head/leg AABB overlap by raising the head
# (not tilting it) while its collision-safe yaw is still tracking.
const HEAD_VISUAL_OVERLAP_MAX_VOLUME_M3: float = 0.030
const HEAD_VISUAL_CLEARANCE_MAX_LIFT_METERS: float = 1.00
const HEAD_VISUAL_CLEARANCE_RELEASE_SPEED_MPS: float = 0.75
const HEAD_WINDUP_LIFT_METERS_PER_DEGREE: float = 0.0120
const HEAD_TRACK_STANDUP_START_FRACTION: float = 0.70
# A gentle, weaker head reacquisition starts at 70% ACTUAL upright pose.
# End the physical rise at only 60% head authority; the post-upright
# settle eases the remaining 40% in smoothly without a rotation snap.
const HEAD_TRACK_RISE_FOLLOW_WEIGHT: float = 0.60
const HEAD_TRACK_RECOVERY_DEGREES_PER_SECOND: float = 48.0
# Head yaw eases continuously from first overlap to zero speed at
# 20cm of oriented-mesh penetration. The knees begin folding earlier.
# tunneling. A narrow release hysteresis prevents short-range flicker.
const HEAD_LEG_ALLOWED_PENETRATION_METERS: float = (
    BittaranParts.HEAD_LEG_ALLOWED_PENETRATION_METERS)
const HEAD_TRACK_COLLISION_FILTER_PER_SECOND: float = 7.0
const HEAD_TRACK_COLLISION_RELEASE_PER_SECOND: float = 4.0
const HEAD_TRACK_COLLISION_DEADBAND_METERS: float = 0.004
const HEAD_TRACK_COLLISION_BRAKE_START_METERS: float = 0.14
const HEAD_TRACK_COLLISION_RELEASE_DEPTH_METERS: float = 0.17
const HEAD_TRACK_COLLISION_STOP_SAFETY_METERS: float = 0.0005
const HEAD_TRACK_COLLISION_SWEEP_STEPS: int = 8
# Close targets can cross the nose's local +/-Z plane, making atan2
# alternate between +/-PI. Keep a forward-facing denominator, a short
# near-field hold, and a low-pass on the desired yaw (not the mesh pose).
const HEAD_AIM_MIN_FORWARD_METERS: float = 0.70
const HEAD_AIM_HOLD_RADIUS_METERS: float = 0.50
const HEAD_AIM_NEAR_RADIUS_METERS: float = 2.20
const HEAD_AIM_NEAR_FILTER_PER_SECOND: float = 2.8
const HEAD_AIM_FAR_FILTER_PER_SECOND: float = 12.0
const HEAD_AIM_NEAR_DEADBAND_DEGREES: float = 1.8
# Bound near-field desired-yaw changes to 4deg per 60Hz physics tick
# even when the player alternates rapidly behind the head pivot.
const HEAD_AIM_NEAR_MAX_DEGREES_PER_SECOND: float = 240.0
# A depth change caused by one replanting knee cannot instantly release
# the 30cm stop. The latch releases only after a stable gap persists.
const HEAD_TRACK_COLLISION_ESCAPE_MIN_SPEED_FACTOR: float = 0.40
const HEAD_TRACK_COLLISION_ESCAPE_GUARD_METERS: float = 0.008
const HEAD_TRACK_COLLISION_RELEASE_HOLD_SECONDS: float = 0.12

var bittaran_rig: Node3D
var bittaran_railgun: Node3D
var bittaran_ai: RefCounted
var bittaran_foot_ik: RefCounted
var bittaran_motion: String = "Idle"
# v464: never attack until three COMPLETED normal gait pair swings.
# After each attack the next required step count is reset +3.
# Postattack scripted replant pairs do not increment that counter.
const BITTARAN_MIN_WALK_STEPS: int = 3
var bittaran_walk_attack_step_gate: int = BITTARAN_MIN_WALK_STEPS
var bittaran_was_attacking: bool = false
var boss_name_label: Label
var victory_label: Label
var boss_death_particles: CPUParticles3D
var boss_death_elapsed: float = -1.0
var boss_far_side_screen_axis: bool = false
var boss_last_controller_axis: Vector2 = Vector2.UP
var bittaran_head: Node3D
var boss_head_yaw: float = 0.0
var head_arm_return_yaw_limit_degrees: float = 65.0
var boss_head_pitch: float = 0.0
var head_look_filtered_pitch: float = 0.0
var boss_head_default_rotation: Quaternion = Quaternion.IDENTITY
var boss_head_rest_local_position: Vector3 = Vector3.ZERO
var head_player_rest_world_y: float = 0.0
var head_vertical_offset_world: float = 0.0
var head_visual_clearance_lift_world: float = 0.0
var boss_head_windup_start_yaw: float = 0.0
var head_neutral_overlap: Dictionary = {}
var head_neutral_component_overlap: Dictionary = {}
var head_collision_filtered_depth: float = 0.0
var head_collision_blocked: bool = false
var head_collision_release_elapsed: float = 0.0
var head_look_filtered_yaw: float = 0.0
var head_look_initialized: bool = false
var boss_downed_escaping: bool = false
var bittaran_attacks: RefCounted
var bittaran_attack_frame: Dictionary = {}
var bittaran_attack_body_yaw: float = 0.0
var bittaran_shockwave: MeshInstance3D
var shockwave_elapsed: float = -1.0
var shockwave_half_extents: Vector2 = Vector2.ONE
var bittaran_dirt_fx: Node3D
var bittaran_sweep_fx_baked: bool = false
var bittaran_thud_audio: AudioStreamPlayer
# v454: gapless 174-BPM audio provided by the creator. The Ogg source
# must be included at this resource path for Android export; a user://
# fallback permits listening without rebuilding during development.
const BITTARAN_BGM_PATH: String = "res://assets/neural_flow_loop.ogg"
const BITTARAN_BGM_USER_PATH: String = "user://neural_flow_loop.ogg"
const BITTARAN_BGM_DURATION_SECONDS: float = 187.586207
var bittaran_bgm: AudioStreamPlayer
var impact_shake_strength: float = 0.0
var impact_shake_time: float = 0.0
var footfall_prev_stepping: Array[bool] = [false, false, false, false]
var last_attack_contact: Vector3 = Vector3.ZERO
var attack_contact_initialized: bool = false

func _ready() -> void:
    super._ready()
    _start_neural_flow_bgm()
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

## Only Bittaran's battle scene owns this player: no training-room
## BGM leakage. ResourceLoader loads Godot's imported Ogg on desktop
## and Android. The user:// fallback loads a development-time Ogg
## placed in the application's writable folder when the imported
## asset has not yet been copied into the repository.
## Load the imported stream when possible. On Android a fresh Git
## sync can leave an .ogg source present before the editor finishes
## generating the .godot imported cache; load the raw Vorbis bytes
## in that case instead of silently skipping music.
func _start_neural_flow_bgm() -> void:
    var music: AudioStream = null
    var loaded_via: String = ""
    if ResourceLoader.exists(BITTARAN_BGM_PATH):
        music = ResourceLoader.load(BITTARAN_BGM_PATH) as AudioStream
        if music != null:
            loaded_via = "imported"
    if music == null and FileAccess.file_exists(BITTARAN_BGM_PATH):
        var ogg_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
            BITTARAN_BGM_PATH)
        if ogg_bytes.size() > 0:
            music = AudioStreamOggVorbis.load_from_buffer(ogg_bytes)
            if music != null:
                loaded_via = "direct-res"
    if music == null and FileAccess.file_exists(
            BITTARAN_BGM_USER_PATH):
        music = AudioStreamOggVorbis.load_from_file(
            BITTARAN_BGM_USER_PATH)
        if music != null:
            loaded_via = "user-fallback"
    if music == null:
        push_error("SERA_BGM_MISSING: Cannot load Neural Flow at "
            + BITTARAN_BGM_PATH + "; check Godot audio import")
        return
    if music is AudioStreamOggVorbis:
        var ogg: AudioStreamOggVorbis = music
        ogg.bpm = 174.0
        ogg.bar_beats = 4
        ogg.beat_count = 544
        ogg.loop = true
        ogg.loop_offset = 0.0
    bittaran_bgm = AudioStreamPlayer.new()
    bittaran_bgm.name = "NeuralFlowBGM"
    bittaran_bgm.bus = "Master"
    bittaran_bgm.volume_db = -5.0
    bittaran_bgm.stream = music
    add_child(bittaran_bgm)
    bittaran_bgm.play()
    print("SERA_BGM_STARTED: ", loaded_via,
        " length=", music.get_length(),
        " playing=", bittaran_bgm.playing)
    # On some Android startup paths the first audio mixer tick occurs
    # after _ready. Verify on the next idle step and retry once.
    call_deferred("_verify_neural_flow_bgm")


func _verify_neural_flow_bgm() -> void:
    if bittaran_bgm == null or bittaran_bgm.stream == null:
        return
    if not bittaran_bgm.playing:
        bittaran_bgm.play()
    if not bittaran_bgm.playing:
        push_error("SERA_BGM_PLAY_FAILED: Neural Flow stream loaded, "
            + "but AudioStreamPlayer did not start")


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
    bittaran_rig.position.y = (
        0.0 if BLOCKBENCH_SOURCE_REPLAY_ONLY or (
            BLOCKBENCH_GAIT_SUPPORT_IK) else -1.12)
    target.add_child(bittaran_rig)
    # The authored rails become independent azimuth/elevation children of
    # Body; neither leg replay, support IK nor HEAD owns their transform.
    var railgun_body: Node3D = bittaran_rig.find_child(
        "Body", true, false) as Node3D
    if railgun_body != null:
        bittaran_railgun = BittaranRailgun.new()
        bittaran_railgun.name = "IndependentDorsalRailgun"
        railgun_body.add_child(bittaran_railgun)
        if not bool(bittaran_railgun.call("setup", bittaran_rig)):
            push_error("Bittaran: railgun setup failed")
    bittaran_head = bittaran_rig.find_child("Head", true, false) as Node3D
    if bittaran_head != null:
        boss_head_default_rotation = bittaran_head.quaternion
        boss_head_rest_local_position = bittaran_head.position
        head_arm_return_yaw_limit_degrees = _head_arm_return_yaw_limit()
        if player != null:
            head_player_rest_world_y = player.global_position.y
        head_vertical_offset_world = 0.0
        head_visual_clearance_lift_world = 0.0
    bittaran_ai = BittaranAI.new()
    bittaran_ai.call("reset")
    bittaran_foot_ik = BittaranFootIK.new()
    if not bool(bittaran_foot_ik.call("setup", bittaran_rig,
            BLOCKBENCH_SOURCE_REPLAY_ONLY or BLOCKBENCH_GAIT_SUPPORT_IK)):
        push_error("Bittaran: four-leg IK setup failed")
    if BLOCKBENCH_SOURCE_REPLAY_ONLY or BLOCKBENCH_GAIT_SUPPORT_IK:
        # Calibrate just the single VISUAL ROOT to the authored Wait
        # foot plane. This is a fixed initial placement (not IK).
        # No per-animation / per-mesh offsets or torso poses are changed.
        var min_wait_sole_y: float = INF
        var meshes: Dictionary = bittaran_rig.get("mesh_nodes_by_uuid")
        for uid in meshes.keys():
            var piece: MeshInstance3D = meshes[uid]
            if piece.name.begins_with("FrontFoot_") or (
                    piece.name.begins_with("RearFoot_")):
                min_wait_sole_y = minf(min_wait_sole_y, float(
                    bittaran_rig.call("_ground_mesh_lowest_world_y",
                        str(uid))))
        if is_finite(min_wait_sole_y):
            var root_parent_scale: float = maxf(absf(
                target.global_basis.get_scale().y), 0.001)
            bittaran_rig.position.y += (
                -min_wait_sole_y / root_parent_scale)
    if BLOCKBENCH_GAIT_SUPPORT_IK:
        bittaran_rig.set("source_ground_ik_active", true)
        # Save the fixed Blockbench-ground placement as the true respawn
        # height; setup(source_only=true) recorded the root BEFORE
        # the initial floor adjustment.
        bittaran_foot_ik.set(
            "rest_actor_local_y", bittaran_rig.position.y)
        if not bool(bittaran_foot_ik.call("initialize_source_ground_ik")):
            push_error("Bittaran: v435 simple skeletal IK setup failed")
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
    bittaran_attacks = BittaranAttacks.new()
    _build_bittaran_shockwave()
    _build_boss_death_particles()

func _make_bittaran_broken_ring() -> ArrayMesh:
    # Cracked grey annulus at FULL radius from the first frame. Do NOT
    # scale up from the center. Leave several distinct missing wedges.
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var pieces: int = 112
    for i in range(pieces):
        if (i >= 13 and i <= 20) or (i >= 50 and i <= 56) or (
                i >= 86 and i <= 95):
            continue
        var a0: float = TAU * float(i) / float(pieces)
        var a1: float = TAU * float(i + 1) / float(pieces)
        var inner0: float = 0.66 + 0.035 * sin(a0 * 13.0)
        var inner1: float = 0.66 + 0.035 * sin(a1 * 13.0)
        var outer0: float = 1.0 + 0.042 * sin(a0 * 17.0)
        var outer1: float = 1.0 + 0.042 * sin(a1 * 17.0)
        var p0 := Vector3(cos(a0) * inner0, 0.0, sin(a0) * inner0)
        var p1 := Vector3(cos(a0) * outer0, 0.0, sin(a0) * outer0)
        var p2 := Vector3(cos(a1) * inner1, 0.0, sin(a1) * inner1)
        var p3 := Vector3(cos(a1) * outer1, 0.0, sin(a1) * outer1)
        for v in [p0, p1, p2, p1, p3, p2]:
            tool.set_normal(Vector3.UP)
            tool.add_vertex(v)
    return tool.commit()


func _build_bittaran_shockwave() -> void:
    bittaran_shockwave = MeshInstance3D.new()
    bittaran_shockwave.name = "BittaranStompBrokenGreyRing"
    bittaran_shockwave.mesh = _make_bittaran_broken_ring()
    var earth := StandardMaterial3D.new()
    earth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    earth.cull_mode = BaseMaterial3D.CULL_DISABLED
    earth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    earth.albedo_color = Color(0.52, 0.52, 0.51, 0.70)
    # Depth-tested scene material: never show the dust ring through SERA.
    earth.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
    bittaran_shockwave.material_override = earth
    bittaran_shockwave.visible = false
    add_child(bittaran_shockwave)
    bittaran_dirt_fx = BittaranDirtFX.new()
    bittaran_dirt_fx.name = "BittaranDirtFX"
    add_child(bittaran_dirt_fx)
    bittaran_thud_audio = AudioStreamPlayer.new()
    bittaran_thud_audio.name = "BittaranThud"
    bittaran_thud_audio.stream = _make_bittaran_thud()
    bittaran_thud_audio.volume_db = -6.0
    bittaran_thud_audio.max_polyphony = 3
    add_child(bittaran_thud_audio)


func _make_bittaran_thud() -> AudioStreamWAV:
    # Original heavy ground thud for the boss (v401); 16-bit PCM
    # generated once at startup, mirroring the mechanical-footstep
    # synthesis in main.gd. No copyrighted sample, no runtime synth.
    var rate: int = 22050
    var frame_count: int = 8379  # 0.38 s
    var samples := PackedByteArray()
    samples.resize(frame_count * 2)
    var seed: int = 41731
    for i in range(frame_count):
        var t: float = float(i) / float(rate)
        seed = (seed * 1664525 + 1013904223) & 0x7fffffff
        var noise: float = (float(seed % 65536) / 32768.0) - 1.0
        var body: float = sin(TAU * (46.0 * t + 9.0 * t * t)) * exp(-t * 11.0)
        var partial: float = sin(
            TAU * (93.0 * t + 21.0 * t * t)) * exp(-t * 19.0)
        var crunch: float = noise * exp(-t * 42.0)
        var signal_level: float = clampf(
            body * 0.72 + partial * 0.22 + crunch * 0.16, -0.96, 0.96)
        samples.encode_s16(i * 2, roundi(signal_level * 32767.0))
    var sound := AudioStreamWAV.new()
    sound.mix_rate = rate
    sound.format = AudioStreamWAV.FORMAT_16_BITS
    sound.stereo = false
    sound.data = samples
    return sound


## Impact camera feedback (v401). main.gd never touches the camera's
## frustum offsets, so a decaying offset here cannot fight the normal
## follow camera; it always settles back to exactly zero.
# v452: scale EVERY Bittaran vibration at its shared injection point.
# This covers footsteps, impact rings, kicks, sweeps and damage feedback.
const BITTARAN_SHAKE_MULTIPLIER: float = 1.5

func _add_impact_shake(strength: float) -> void:
    impact_shake_strength = maxf(
        impact_shake_strength, strength * BITTARAN_SHAKE_MULTIPLIER)


func _tick_impact_shake(delta: float) -> void:
    if camera == null:
        return
    impact_shake_time += maxf(delta, 0.0)
    if impact_shake_strength <= 0.0004:
        impact_shake_strength = 0.0
        if camera.h_offset != 0.0 or camera.v_offset != 0.0:
            camera.h_offset = 0.0
            camera.v_offset = 0.0
        return
    impact_shake_strength *= exp(-5.5 * maxf(delta, 0.0))
    var t: float = impact_shake_time
    var nx: float = sin(t * 43.7) * 0.62 + sin(t * 29.3 + 1.7) * 0.38
    var ny: float = sin(t * 37.9 + 0.6) * 0.62 + sin(t * 24.1 + 2.9) * 0.38
    camera.h_offset = nx * impact_shake_strength
    camera.v_offset = ny * impact_shake_strength * 0.7


func _play_bittaran_thud(point: Vector3, pitch: float,
        base_volume_db: float) -> void:
    if bittaran_thud_audio == null or camera == null:
        return
    var distance: float = camera.global_position.distance_to(point)
    if distance > 30.0:
        return
    bittaran_thud_audio.pitch_scale = pitch
    bittaran_thud_audio.volume_db = base_volume_db - clampf(
        (distance - 6.0) * 0.55, 0.0, 12.0)
    bittaran_thud_audio.play()


func _tick_bittaran_footfalls() -> void:
    if bittaran_foot_ik == null or camera == null:
        return
    var legs: Array = bittaran_foot_ik.get("legs")
    if legs.size() != 4:
        return
    for i in range(legs.size()):
        var leg: Dictionary = legs[i]
        var stepping: bool = bool(leg["stepping"])
        if footfall_prev_stepping[i] and not stepping:
            var foot: Node3D = leg["foot"]
            if foot != null and camera.global_position.distance_to(
                    foot.global_position) <= 20.0:
                _play_bittaran_thud(foot.global_position, 1.3, -13.0)
                _add_impact_shake(0.030)
        footfall_prev_stepping[i] = stepping


## Footprint is computed from the LIVE rendered foot AABB after IK.
## Both horizontal dimensions are exactly 1.5x the real foot size.
## The original shin-wide hitbox must never define a ground slam.
func _bittaran_stomp_ground_half_extents(leg_id: String) -> Vector2:
    if target_parts == null:
        return Vector2.ZERO
    var foot_box: AABB = target_parts.call(
        "get_leg_foot_world_aabb", leg_id)
    if not foot_box.has_volume():
        return Vector2.ZERO
    return Vector2(foot_box.size.x, foot_box.size.z) * 0.75


## A SINGLE immediate collision pulse at the grounded toe's actual
## landing tick. Uses the 1.5x foot footprint (with the player's
## normal capsule radius), never a lingering/rising shockwave hitbox.
func _bittaran_stomp_ground_hit(
        point: Vector3, half_extents: Vector2) -> void:
    if player == null or bittaran_attacks == null or (
            target_hp <= 0.0 or player_hp <= 0.0) or (
            bool(bittaran_attacks.get("hit_consumed"))):
        return
    if half_extents.x <= 0.0 or half_extents.y <= 0.0:
        return
    var delta: Vector2 = Vector2(
        player.global_position.x - point.x,
        player.global_position.z - point.z)
    var capsule_radius: float = 0.40
    if absf(delta.x) > half_extents.x + capsule_radius or (
            absf(delta.y) > half_extents.y + capsule_radius):
        return
    # Resolve damage instantly on the impact frame, irrespective of
    # the visible dust/ring animation which continues afterward.
    bittaran_attacks.set("hit_consumed", true)
    var direction: Vector3 = Vector3(delta.x, 0.0, delta.y)
    if direction.length_squared() < 0.0001:
        direction = player.global_position - target.global_position
        direction.y = 0.0
    if direction.length_squared() < 0.0001:
        direction = Vector3.FORWARD
    _on_enemy_projectile_hit(
        player.global_position, direction.normalized(), false, 2)


func _emit_bittaran_shockwave(point: Vector3, half_size: Vector2,
        surface_fx_point: Vector3 = Vector3.INF) -> void:
    if half_size.x <= 0.0 or half_size.y <= 0.0:
        return
    # Physical damage is evaluated even if the optional shockwave
    # visual is not instantiated. An FX node must never gate STOMP.
    _bittaran_stomp_ground_hit(point, half_size)
    if bittaran_shockwave == null:
        return
    shockwave_elapsed = 0.0
    shockwave_half_extents = half_size
    bittaran_shockwave.global_position = Vector3(
        point.x, 0.055, point.z)
    # Live FOOT width x1.5, not shin width. The ring is cosmetic;
    # its fade never drives the instant one-shot area damage.
    var radius: float = maxf(half_size.x, half_size.y)
    bittaran_shockwave.scale = Vector3(radius, 1.0, radius)
    bittaran_shockwave.visible = true
    if bittaran_dirt_fx != null:
        # Hit region and ground ring still use the real whole-foot box.
        # Dense material must originate from the LOWEST visible toe
        # surface rather than the center of its rotated long mesh.
        var fx_origin: Vector3 = (
            surface_fx_point if surface_fx_point != Vector3.INF
            else point)
        bittaran_dirt_fx.call("emit_stomp", fx_origin, half_size)
    # The ground slam itself shakes the arena, hit or miss (v401).
    # v402: the v401 strengths were calibrated blind and measured only
    # ~5px of image displacement at fight distance (device feedback:
    # imperceptible). Strengths are frustum-offset units; measured
    # ~105px of displacement per unit at the battle camera, so the
    # values below target roughly 35px near / 10px far for a stomp.
    if camera != null:
        var distance: float = camera.global_position.distance_to(point)
        _add_impact_shake(lerpf(
            0.34, 0.10, clampf(distance / 26.0, 0.0, 1.0)))
    _play_bittaran_thud(point, 1.0, -5.0)


func _tick_bittaran_shockwave(delta: float) -> void:
    if shockwave_elapsed < 0.0 or bittaran_shockwave == null:
        return
    shockwave_elapsed += maxf(delta, 0.0)
    var progress: float = clampf(shockwave_elapsed / 0.30, 0.0, 1.0)
    # Only fade opacity. Never grow the ring from the impact center.
    var glow: StandardMaterial3D = (bittaran_shockwave.material_override as StandardMaterial3D)
    if glow != null:
        var fading: Color = glow.albedo_color
        fading.a = 0.70 * (1.0 - progress)
        glow.albedo_color = fading
    if progress >= 1.0:
        shockwave_elapsed = -1.0
        bittaran_shockwave.visible = false


func _bittaran_player_overlap(box: AABB) -> bool:
    if player == null:
        return false
    var capsule_box := AABB(
        player.global_position + Vector3(-0.40, 0.08, -0.40),
        Vector3(0.80, 1.70, 0.80))
    return box.intersects(capsule_box)


func _check_bittaran_attack_hit() -> void:
    if bittaran_attack_frame.is_empty() or bittaran_attacks == null \
            or target_parts == null or player == null or target_hp <= 0 \
            or player_hp <= 0 or training_ko_remaining > 0.0:
        return
    if bool(bittaran_attack_frame.get("stance_prepare", false)):
        return
    if bool(bittaran_attacks.get("hit_consumed")):
        return
    var kind: String = str(bittaran_attack_frame.get("kind", ""))
    var leg_id: String = str(bittaran_attack_frame.get("id", ""))
    if not BittaranFootIK.LEG_PART_IDS.has(leg_id):
        return
    var original: bool = bool(bittaran_attack_frame.get(
        "original_attack_only", false))
    var is_impact: bool = bool(bittaran_attack_frame.get("impact", false))
    var hit_window: bool = bool(bittaran_attack_frame.get("hit_window", false))
    if original:
        # The source attack director owns the actual Blockbench
        # keyframe window. KICK starts .10s after the first extension
        # key; the four SWEEPs start .10s after their grounded return
        # begins, not while the leg is being raised or drawn back.
        var phase: String = str(bittaran_attack_frame.get("phase", ""))
        var clip_time: float = float(bittaran_attack_frame.get(
            "authored_time", 0.0))
        is_impact = false
        hit_window = (phase == "strike" and (
            kind == "stomp" or bool(
                bittaran_attack_frame.get("hit_window", false))))
        if kind == "sweep":
            # A returning sweep can damage only while its real foot
            # mesh remains on the floor. An airborne toe, even at a
            # valid source key, never creates an invisible hit area.
            hit_window = hit_window and (
                _bittaran_striking_foot_grounded(leg_id))
        if kind == "stomp":
            if leg_id.begins_with("leg_r"):
                # Source t=.50 is AERIAL apex, not impact. During
                # v462's zero-hold test the physics step can skip
                # the last STRIKE tick. Permit the first .10s of
                # recovery only if the actual toe is grounded.
                var initial_recovery: bool = (
                    BittaranAttacks.TIMING_TEST_ENABLED
                    and phase == "recovery" and float(
                    bittaran_attack_frame.get("phase_elapsed", 1.0))
                    <= 0.10)
                var landing_window: bool = (
                    (phase == "strike" and clip_time >= 0.93) or (
                    phase == "hold" and float(
                    bittaran_attack_frame.get("phase_elapsed", 1.0))
                    <= 0.12) or initial_recovery)
                hit_window = landing_window and (
                    _bittaran_striking_foot_grounded(leg_id))
            else:
                # The front toe first descends from key t=1.25.
                # It contacts the real floor around t=1.467,
                # BEFORE the old late 1.50s cosmetic threshold.
                var front_landing: bool = (
                    (phase == "strike" and clip_time >= 1.375) or (
                    phase == "hold" and float(
                    bittaran_attack_frame.get("phase_elapsed", 1.0))
                    <= 0.12))
                hit_window = front_landing and (
                    _bittaran_striking_foot_grounded(leg_id))
    if not is_impact and not hit_window:
        return
    var contact: Vector3 = (
        _bittaran_original_attack_contact(leg_id) if original
        else bittaran_foot_ik.call("attack_contact_world"))
    # STOMP is a real ONE-SHOT grounded hit at first DESCENDING
    # foot contact, not a side effect of its dust emitter and never
    # a shin overlap. This path runs immediately after full source
    # clip + support IK, before particles can animate/fade.
    if kind == "stomp":
        if _bittaran_striking_foot_grounded(leg_id) and (
                bittaran_dirt_fx == null or not bool(
                bittaran_dirt_fx.get("stomped_this_attack"))):
            if bittaran_dirt_fx != null:
                bittaran_dirt_fx.set("stomped_this_attack", true)
            _emit_bittaran_shockwave(contact,
                _bittaran_stomp_ground_half_extents(leg_id),
                _bittaran_ground_fx_contact(leg_id))
        return
    # The ONLY attack collision volumes are rendered components below the
    # knee joint: lower-leg mesh + its attached foot. No upper limb,
    # torso, head, broad shin lock box or shockwave radius can deal damage.
    var struck: bool = false
    var boxes: Array = target_parts.call("get_leg_attack_mesh_boxes", leg_id)
    for raw in boxes:
        var box: AABB = raw
        if box.has_volume() and _bittaran_player_overlap(box.grow(0.08)):
            struck = true
            break
    if not struck:
        return
    bittaran_attacks.set("hit_consumed", true)
    var direction: Vector3 = player.global_position - contact
    direction.y = 0.0
    if direction.length_squared() < 0.0001:
        direction = player.global_position - target.global_position
    if direction.length_squared() < 0.0001:
        direction = Vector3.FORWARD
    if kind == "kick":
        _add_impact_shake(0.16)
        _play_bittaran_thud(player.global_position, 1.5, -10.0)
    elif kind == "sweep":
        _add_impact_shake(0.19)
        _play_bittaran_thud(player.global_position, 1.25, -9.0)
    # SERA's existing guard/HP/knockback and KO logic remains authoritative.
    var damage_index: int = 2 if kind == "stomp" else (
        1 if kind == "kick" else 3)
    _on_enemy_projectile_hit(
        player.global_position, direction.normalized(), false, damage_index)

func _bittaran_attack_candidates() -> Dictionary:
    var candidates: Dictionary = {}
    if bittaran_foot_ik == null or target_parts == null or (
            not bool(bittaran_foot_ik.get("ready"))):
        return candidates
    # The old available_attack_feet() exposes IK's PLANNED anchors,
    # not the actual rendered soles. At three gait touchdowns, some
    # feet have not yet reached their stored anchor — using them
    # would select an attack from a phantom position. Read each live
    # articulated foot in world space after IK instead.
    var legs: Array = bittaran_foot_ik.get("legs")
    for i in range(mini(BittaranFootIK.LEG_PART_IDS.size(), legs.size())):
        var leg: Dictionary = legs[i]
        var foot: Node3D = leg.get("foot", null) as Node3D
        if foot == null:
            continue
        var sole_local: Vector3 = leg.get(
            "sole_local", Vector3.ZERO)
        var world_sole: Vector3 = foot.to_global(sole_local)
        if is_finite(world_sole.x) and is_finite(world_sole.z):
            candidates[BittaranFootIK.LEG_PART_IDS[i]] = world_sole
    return candidates


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



## Compute the head's independent rotational ceiling from the ACTUAL
## returning front-arm shoulder pivots in BODY-local coordinates, not the
## instantaneous collision shape of an arm during an attack. This keeps
## the nose inside the place where the arms will come BACK even when the
## arms are currently swung outward and leave the head unobstructed.
func _head_arm_return_yaw_limit() -> float:
    if bittaran_rig == null or bittaran_head == null:
        return HEAD_TRACK_MAX_YAW_DEGREES
    var cap: float = HEAD_TRACK_MAX_YAW_DEGREES
    for name in ["FrontLeg_L", "FrontLeg_R"]:
        var arm: Node3D = bittaran_rig.find_child(
            name, true, false) as Node3D
        if arm == null or arm.get_parent() != bittaran_head.get_parent():
            continue
        var offset: Vector3 = arm.position - boss_head_rest_local_position
        var arm_return_bearing: float = rad_to_deg(
            absf(atan2(offset.x, -offset.z)))
        cap = minf(cap, maxf(HEAD_ARM_RETURN_MIN_YAW_DEGREES,
            arm_return_bearing - HEAD_ARM_RETURN_GUARD_DEGREES))
    return cap

func _head_penetration_depth(base_pose: Quaternion,
        relative_yaw: float, relative_pitch: float = NAN) -> float:
    if bittaran_head == null or target_parts == null:
        return 0.0
    var checked_pitch: float = (boss_head_pitch if is_nan(relative_pitch)
        else relative_pitch)
    bittaran_head.quaternion = _head_oriented_local_pose(
        base_pose, relative_yaw, checked_pitch)
    var depths: Dictionary = target_parts.call(
        "get_head_leg_penetration_depths")
    var deepest: float = 0.0
    for value in depths.values():
        deepest = maxf(deepest, float(value))
    return deepest


func _head_collision_motion_scale(current_depth: float,
        next_depth: float, delta: float) -> float:
    # Filter actual physical penetration in world metres; closing contacts
    # react promptly, opening contacts relax more slowly. The 4mm deadband
    # prevents tiny SAT/AABB pose changes from modulating HEAD yaw.
    var observed: float = maxf(0.0, next_depth)
    var rate: float = (HEAD_TRACK_COLLISION_FILTER_PER_SECOND
        if observed > head_collision_filtered_depth
        else HEAD_TRACK_COLLISION_RELEASE_PER_SECOND)
    if absf(observed - head_collision_filtered_depth) > (
            HEAD_TRACK_COLLISION_DEADBAND_METERS):
        var alpha: float = 1.0 - exp(-rate * maxf(delta, 0.0))
        head_collision_filtered_depth = lerpf(
            head_collision_filtered_depth, observed, alpha)
    var u: float = clampf(
        (head_collision_filtered_depth - HEAD_TRACK_COLLISION_BRAKE_START_METERS)
        / (HEAD_LEG_ALLOWED_PENETRATION_METERS
            - HEAD_TRACK_COLLISION_BRAKE_START_METERS), 0.0, 1.0)
    var brake: float = 1.0 - u * u * (3.0 - 2.0 * u)
    # Escaping an obstruction is possible even when already over 20cm.
    # However, do not jump to 100% speed merely because the moving knee
    # changed the sampled contact by a few millimetres in one frame.
    var escaping: bool = next_depth < (
        current_depth - HEAD_TRACK_COLLISION_ESCAPE_GUARD_METERS)
    if current_depth >= HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.00001:
        head_collision_blocked = true
        head_collision_release_elapsed = 0.0
    if head_collision_blocked:
        if (current_depth <= HEAD_TRACK_COLLISION_RELEASE_DEPTH_METERS
                and head_collision_filtered_depth <= (
                HEAD_TRACK_COLLISION_RELEASE_DEPTH_METERS)):
            head_collision_release_elapsed += maxf(delta, 0.0)
            if head_collision_release_elapsed >= (
                    HEAD_TRACK_COLLISION_RELEASE_HOLD_SECONDS):
                head_collision_blocked = false
                head_collision_release_elapsed = 0.0
        else:
            head_collision_release_elapsed = 0.0
        if head_collision_blocked:
            return (maxf(brake, HEAD_TRACK_COLLISION_ESCAPE_MIN_SPEED_FACTOR)
                if escaping else 0.0)
    return (maxf(brake, HEAD_TRACK_COLLISION_ESCAPE_MIN_SPEED_FACTOR)
        if escaping else brake)


func _update_head_look_target(delta: float) -> void:
    # Sample the true world-space bearing of the HEAD's short -Z nose
    # face. BODY's authored roll/pitch must never corrupt yaw acquisition.
    if bittaran_head == null or player == null:
        return
    var parent_joint: Node3D = bittaran_head.get_parent() as Node3D
    if parent_joint == null:
        return
    var target_point: Vector3 = player.global_position + Vector3.UP * 0.9
    var toward: Vector3 = target_point - bittaran_head.global_position
    var front: Vector3 = -parent_joint.global_basis.z
    front.y = 0.0
    if front.length_squared() <= 0.000001:
        front = Vector3.FORWARD
    var horizontal: float = Vector2(toward.x, toward.z).length()
    if head_look_initialized and horizontal <= HEAD_AIM_HOLD_RADIUS_METERS:
        return
    var raw_bearing: float = wrapf(
        atan2(toward.x, toward.z) - atan2(front.x, front.z),
        -PI, PI)
    # Directly behind the neck, the true bearing flips +/-180deg when
    # the player moves a few centimetres. Use the OLD safe positive
    # forward denominator only in the near field, fading to the exact
    # short-face bearing at normal distances. Preserve turn direction.
    var right: Vector3 = Vector3(-front.z, 0.0, front.x).normalized()
    var lateral: float = -right.dot(toward)
    var ahead: float = front.dot(toward)
    var near_bearing: float = atan2(lateral,
        maxf(ahead, HEAD_AIM_MIN_FORWARD_METERS))
    var near_weight: float = smoothstep(
        HEAD_AIM_HOLD_RADIUS_METERS,
        HEAD_AIM_NEAR_RADIUS_METERS, horizontal)
    # Never interpolate the two +/-PI representatives directly.
    raw_bearing = near_bearing + wrapf(
        raw_bearing - near_bearing, -PI, PI) * near_weight
    var mechanical_limit: float = deg_to_rad(
        minf(HEAD_TRACK_MAX_YAW_DEGREES,
            head_arm_return_yaw_limit_degrees))
    var raw_yaw: float = clampf(raw_bearing,
        -mechanical_limit, mechanical_limit)
    if not head_look_initialized:
        head_look_filtered_yaw = raw_yaw
        head_look_initialized = true
        return
    var error: float = wrapf(
        raw_yaw - head_look_filtered_yaw, -PI, PI)
    if absf(error) < deg_to_rad(HEAD_AIM_NEAR_DEADBAND_DEGREES) \
            and horizontal < HEAD_AIM_NEAR_RADIUS_METERS:
        return
    var distance_weight: float = smoothstep(
        HEAD_AIM_HOLD_RADIUS_METERS, HEAD_AIM_NEAR_RADIUS_METERS,
        horizontal)
    var speed: float = lerpf(HEAD_AIM_NEAR_FILTER_PER_SECOND,
        HEAD_AIM_FAR_FILTER_PER_SECOND, distance_weight)
    var alpha: float = 1.0 - exp(-speed * maxf(delta, 0.0))
    var yaw_step: float = error * alpha
    if horizontal < HEAD_AIM_NEAR_RADIUS_METERS:
        var cap: float = deg_to_rad(
            HEAD_AIM_NEAR_MAX_DEGREES_PER_SECOND) * maxf(delta, 0.0)
        yaw_step = clampf(yaw_step, -cap, cap)
    head_look_filtered_yaw = clampf(
        head_look_filtered_yaw + yaw_step,
        -mechanical_limit, mechanical_limit)


func _head_pitch_target(delta: float) -> void:
    if bittaran_head == null or player == null:
        return
    var toward: Vector3 = (
        player.global_position + Vector3.UP * 0.9
        - bittaran_head.global_position)
    var horizontal: float = maxf(Vector2(
        toward.x, toward.z).length(), HEAD_PITCH_MIN_HORIZONTAL_METERS)
    var desired: float = clampf(atan2(toward.y, horizontal),
        deg_to_rad(HEAD_PITCH_MIN_DEGREES),
        deg_to_rad(HEAD_PITCH_MAX_DEGREES))
    var alpha: float = 1.0 - exp(
        -HEAD_PITCH_FILTER_PER_SECOND * maxf(delta, 0.0))
    head_look_filtered_pitch = lerpf(
        head_look_filtered_pitch, desired, alpha)


## Yaw about the LEVEL world-up axis FIRST, then pitch about the new
## local right axis. No Euler reordering / arbitrary camera-style roll:
## head's visible short -Z face points toward SERA at any BODY pitch.
func _head_oriented_local_pose(base_pose: Quaternion,
        yaw: float, pitch: float) -> Quaternion:
    # A single physical 30deg envelope is authoritative in every state:
    # Idle, Turn, authored attacks, interrupted attacks, down and standup.
    # Clamp at the FINAL joint writer too, not just in the look target,
    # so an inherited/recovery yaw can never exceed the limit.
    var safe_yaw: float = clampf(yaw,
        -deg_to_rad(HEAD_TRACK_MAX_YAW_DEGREES),
        deg_to_rad(HEAD_TRACK_MAX_YAW_DEGREES))
    return (base_pose * Quaternion(Vector3.UP, safe_yaw)
        * Quaternion(Vector3.RIGHT, pitch)).normalized()

func _head_limit_yaw_to_30cm(base_pose: Quaternion, from_yaw: float,
        candidate_yaw: float, current_depth: float) -> float:
    if absf(candidate_yaw - from_yaw) <= 0.0000001:
        return from_yaw
    var limit: float = HEAD_LEG_ALLOWED_PENETRATION_METERS
    var candidate_depth: float = _head_penetration_depth(
        base_pose, candidate_yaw)
    if candidate_depth < limit - HEAD_TRACK_COLLISION_STOP_SAFETY_METERS:
        return candidate_yaw
    # Already embedded >30cm? Never advance INTO the overlap; let
    # backwards / outward tracking immediately escape it.
    if current_depth >= limit - HEAD_TRACK_COLLISION_STOP_SAFETY_METERS:
        return (candidate_yaw if candidate_depth <
            current_depth - HEAD_TRACK_COLLISION_DEADBAND_METERS
            else from_yaw)
    if candidate_depth <= current_depth:
        return candidate_yaw
    # A frame may cross 30cm even with soft damping at low FPS.
    # Clamp its FINAL angle to <=29.9cm, with no backwards snapping.
    var lo: float = 0.0
    var hi: float = 1.0
    for _i in range(HEAD_TRACK_COLLISION_SWEEP_STEPS):
        var mid: float = (lo + hi) * 0.5
        var probe: float = lerpf(from_yaw, candidate_yaw, mid)
        if _head_penetration_depth(base_pose, probe) < (
                limit - HEAD_TRACK_COLLISION_STOP_SAFETY_METERS):
            lo = mid
        else:
            hi = mid
    return lerpf(from_yaw, candidate_yaw, lo)


## PITCH is a second live tracking axis. It must pass the SAME actual
## head-vs-shin OBB depth bound as YAW; otherwise a low SERA causes the
## face to pitch straight INTO a stationary knee while the yaw-only
## collision solver incorrectly reports that turning was safe.
func _head_limit_pitch_to_10cm(base_pose: Quaternion,
        from_pitch: float, candidate_pitch: float,
        yaw: float, current_depth: float) -> float:
    if absf(candidate_pitch - from_pitch) <= 0.0000001:
        return from_pitch
    var safe: float = (HEAD_LEG_ALLOWED_PENETRATION_METERS
        - HEAD_TRACK_COLLISION_STOP_SAFETY_METERS)
    var candidate_depth: float = _head_penetration_depth(
        base_pose, yaw, candidate_pitch)
    if candidate_depth <= safe:
        return candidate_pitch
    # Existing contact may deepen as the support leg animates. Allow
    # ONLY motions which actually reduce the measured mesh penetration.
    if current_depth >= safe:
        return (candidate_pitch if candidate_depth < current_depth
            - HEAD_TRACK_COLLISION_STOP_SAFETY_METERS else from_pitch)
    if candidate_depth <= current_depth:
        return candidate_pitch
    var lo: float = 0.0
    var hi: float = 1.0
    for _i in range(HEAD_TRACK_COLLISION_SWEEP_STEPS):
        var mid: float = (lo + hi) * 0.5
        var candidate: float = lerpf(from_pitch, candidate_pitch, mid)
        if _head_penetration_depth(base_pose, yaw, candidate) < safe:
            lo = mid
        else:
            hi = mid
    return lerpf(from_pitch, candidate_pitch, lo)


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


## World-level neutral reference for HEAD. BODY pitch/roll is removed
## here; the yaw and independent down/up pitch are composed afterward
## in this order. This leaves HEAD with zero artificial side roll.
func _head_level_local_base_pose() -> Quaternion:
    if bittaran_head == null:
        return boss_head_default_rotation
    var parent: Node3D = bittaran_head.get_parent() as Node3D
    if parent == null:
        return boss_head_default_rotation
    var front: Vector3 = -parent.global_basis.z
    front.y = 0.0
    if front.length_squared() <= 0.000001:
        front = Vector3.FORWARD
    var flat_world: Quaternion = Basis.looking_at(
        front.normalized(), Vector3.UP).get_rotation_quaternion()
    var parent_world: Quaternion = parent.global_basis.orthonormalized(
        ).get_rotation_quaternion()
    return (parent_world.inverse() * flat_world).normalized()


## Absolute local reset prevents cumulative drift. Vertical shifting is
## reserved for actual down-anticipation and visible shin clearance;
## player elevation is tracked with head PITCH, not neck translation.
func _update_head_vertical_follow(delta: float, follow: float) -> void:
    if bittaran_head == null or player == null:
        return
    var wanted: float = 0.0
    if bittaran_foot_ik != null and bool(
            bittaran_foot_ik.call("windup_active")):
        # Preserve the existing knockdown anticipation height while
        # normal tracking now rotates the actual head toward the player.
        var windup_degrees: float = float(bittaran_foot_ik.get(
            "head_windup_pitch_degrees"))
        wanted += windup_degrees * HEAD_WINDUP_LIFT_METERS_PER_DEGREE
    var alpha: float = 1.0 - exp(
        -HEAD_VERTICAL_FILTER_PER_SECOND * maxf(delta, 0.0))
    head_vertical_offset_world = move_toward(
        head_vertical_offset_world,
        lerpf(head_vertical_offset_world, wanted, alpha),
        HEAD_VERTICAL_MAX_SPEED_MPS * maxf(delta, 0.0))
    if bittaran_foot_ik != null and bool(
            bittaran_foot_ik.call("down_pose_active")) and follow <= 0.0:
        head_visual_clearance_lift_world = move_toward(
            head_visual_clearance_lift_world, 0.0,
            HEAD_VISUAL_CLEARANCE_RELEASE_SPEED_MPS * maxf(delta, 0.0))
    bittaran_head.position = boss_head_rest_local_position
    # Include the persistent visual-leg clearance BEFORE testing yaw
    # collision, then only add an incremental new lift after final yaw.
    bittaran_head.global_position += Vector3.UP * (
        head_vertical_offset_world + head_visual_clearance_lift_world)


## The pitched head's live collision AABB can overlap a shin. After
## yaw/pitch, prevent the rendered mesh from crossing the visible leg.
## This extra clearance is upward only; it never changes rotations,
## IK foot anchors, or player aim. Upward avoidance is immediate to
## prevent tunnelling, but release is gradual to avoid a bobbing head.
func _avoid_head_visual_leg_overlap(delta: float) -> void:
    if bittaran_head == null or target_parts == null:
        return
    var head_box: AABB = (target_parts.call(
        "get_head_swing_aabb") as AABB).grow(0.05)
    var required: float = 0.0
    for id in ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]:
        var leg_box: AABB = target_parts.call(
            "get_leg_visual_aabb", id)
        if not leg_box.has_volume() or not head_box.intersects(leg_box):
            continue
        var overlap: AABB = head_box.intersection(leg_box)
        var horizontal_area: float = overlap.size.x * overlap.size.z
        if horizontal_area <= 0.00001:
            continue
        var overlap_volume: float = overlap.get_volume()
        if overlap_volume > HEAD_VISUAL_OVERLAP_MAX_VOLUME_M3:
            required = maxf(required, overlap.size.y -
                HEAD_VISUAL_OVERLAP_MAX_VOLUME_M3 / horizontal_area
                + 0.005)
    required = clampf(required, 0.0,
        HEAD_VISUAL_CLEARANCE_MAX_LIFT_METERS)
    # The previous collision lift has ALREADY been applied before yaw
    # testing: otherwise the mesh penetration solver locks the head
    # before it gets a chance to rise away from the visible shin.
    # The remaining intersection requires EXTRA positive world Y.
    var previous_lift: float = head_visual_clearance_lift_world
    head_visual_clearance_lift_world = clampf(maxf(
        previous_lift + required,
        move_toward(previous_lift, 0.0,
            HEAD_VISUAL_CLEARANCE_RELEASE_SPEED_MPS * maxf(delta, 0.0))),
        0.0, HEAD_VISUAL_CLEARANCE_MAX_LIFT_METERS)
    bittaran_head.global_position += Vector3.UP * (
        head_visual_clearance_lift_world - previous_lift)


## The yaw/pitch limit prevents new rotation-based intrusion, but a knee
## can still move INTO an already stopped head, or a low chest can bring
## the face through an arm without either HEAD angle changing. Search
## small WORLD-UP displacements only when actual mesh SAT exceeds 20cm.
## Recompute from the same absolute neck baseline on every tick; never
## accumulate IK-style corrections in the HEAD joint's local origin.
func _resolve_head_deep_leg_overlap() -> void:
    if bittaran_head == null or target_parts == null:
        return
    var depths: Dictionary = target_parts.call(
        "get_head_leg_penetration_depths")
    var current: float = 0.0
    for depth in depths.values():
        current = maxf(current, float(depth))
    var safe: float = HEAD_LEG_ALLOWED_PENETRATION_METERS - 0.002
    if current <= safe:
        return
    var original: Vector3 = bittaran_head.global_position
    var available: float = maxf(0.0,
        HEAD_VISUAL_CLEARANCE_MAX_LIFT_METERS
        - head_visual_clearance_lift_world)
    if available <= 0.001:
        return
    var best_offset: float = 0.0
    var best_depth: float = current
    # First acceptable offset wins; if none is fully safe, use the
    # candidate with least penetration, never blindly lift INTO a shin.
    for fraction in [0.06, 0.13, 0.25, 0.42, 0.63, 0.82, 1.0]:
        var offset: float = minf(float(fraction), available)
        bittaran_head.global_position = original + Vector3.UP * offset
        var candidate_depths: Dictionary = target_parts.call(
            "get_head_leg_penetration_depths")
        var candidate: float = 0.0
        for value in candidate_depths.values():
            candidate = maxf(candidate, float(value))
        if candidate < best_depth - 0.001:
            best_depth = candidate
            best_offset = offset
        if candidate <= safe:
            break
    bittaran_head.global_position = original + Vector3.UP * best_offset
    head_visual_clearance_lift_world += best_offset


func _aim_bittaran_head(delta: float) -> void:
    # v424: independent 90-degree horizontal/vertical look-at.
    # No head collision brake, knee-avoidance or stand-up tracking gate.
    if bittaran_head == null or player == null or target_hp <= 0:
        return
    bittaran_head.position = boss_head_rest_local_position
    var base_pose: Quaternion = _head_level_local_base_pose()
    var parent: Node3D = bittaran_head.get_parent() as Node3D
    if parent == null:
        return
    var world_quat: Quaternion = (
        parent.global_basis.orthonormalized().get_rotation_quaternion()
        * base_pose).normalized()
    var world_direction: Vector3 = (
        player.global_position + Vector3.UP * 0.9
        - bittaran_head.global_position)
    if world_direction.length_squared() <= 0.000001:
        return
    var direction: Vector3 = Basis(world_quat).inverse() * world_direction
    var horizontal: float = Vector2(direction.x, direction.z).length()
    var desired_yaw: float = clampf(-atan2(direction.x, -direction.z),
        -PI * 0.5, PI * 0.5)
    var desired_pitch: float = clampf(atan2(direction.y,
        maxf(horizontal, 0.00001)), -PI * 0.5, PI * 0.5)
    boss_head_yaw = move_toward(boss_head_yaw, desired_yaw,
        deg_to_rad(HEAD_TRACK_DEGREES_PER_SECOND) * maxf(delta, 0.0))
    boss_head_pitch = move_toward(boss_head_pitch, desired_pitch,
        deg_to_rad(HEAD_PITCH_TURN_DEGREES_PER_SECOND) * maxf(delta, 0.0))
    head_look_filtered_yaw = boss_head_yaw
    head_look_filtered_pitch = boss_head_pitch
    head_look_initialized = true
    bittaran_head.quaternion = _head_oriented_local_pose(
        base_pose, boss_head_yaw, boss_head_pitch)

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
    # v461: finish both diagonal pair steps before starting another
    # attack or moving the chassis. Supports stay planted while the
    # returning pair lifts and swings to its authored Wait footprint.
    # The director returns a terminal source frame and immediately
    # clears is_active(). On the very next tick source-IK has not yet
    # been told to start its two diagonal replant steps. Freeze that
    # one-frame handoff too, instead of walking the actor root while
    # capture/replant anchors are being initialized.
    var source_return_pending: bool = (
        bittaran_foot_ik != null and bittaran_attacks != null
        and not bool(bittaran_attacks.call("is_active"))
        and not str(bittaran_foot_ik.get(
            "source_ik_attacking_id")).is_empty())
    var postattack_replanting: bool = source_return_pending or (
        bittaran_foot_ik != null and bool(bittaran_foot_ik.call(
            "source_postattack_replant_active")))
    var completed_gait_steps: int = (
        int(bittaran_foot_ik.call("source_completed_walk_steps"))
        if bittaran_foot_ik != null else 0)
    var enough_walk_steps: bool = (
        completed_gait_steps >= bittaran_walk_attack_step_gate)
    # Once a legal attack begins its 3-step gate immediately rolls
    # forward for NEXT time. Keep the current source animation active
    # throughout strike/recovery rather than cancelling it next tick.
    var current_attack_active: bool = (
        bittaran_attacks != null
        and bool(bittaran_attacks.call("is_active")))
    var attack_permitted: bool = (
        (enough_walk_steps or current_attack_active)
        and target_move_enabled and target_hp > 0 and player_hp > 0
        and not generic_damage_frozen and recovered
        and not postattack_replanting
        and down_remaining <= 0.0 and training_ko_remaining <= 0.0
        and (bittaran_foot_ik == null or not bool(
            bittaran_foot_ik.call("front_height_recovery_active"))))
    var previous_front_attack: bool = (
        not bittaran_attack_frame.is_empty()
        and bool(bittaran_attack_frame.get("direct_front_test", false))
        and not bool(bittaran_attack_frame.get("original_attack_only", false))
        and not bool(bittaran_attack_frame.get("stance_prepare", false)))
    bittaran_attack_frame = (bittaran_attacks.call(
        "advance", delta, player.global_position,
        _bittaran_attack_candidates(), attack_permitted,
        player.global_position + Vector3.UP * PLAYER_COLLISION_HEIGHT,
        bittaran_foot_ik != null and bool(
            bittaran_foot_ik.call("attack_stance_is_ready")),
        target.global_position, target.rotation.y)
        if bittaran_attacks != null else {})
    var attacking: bool = not bittaran_attack_frame.is_empty()
    if attacking and not bittaran_was_attacking:
        # The next attack must follow three NEW gait pair touchdowns,
        # independently of postattack 4-foot reset/respawn.
        bittaran_walk_attack_step_gate = (
            completed_gait_steps + BITTARAN_MIN_WALK_STEPS)
    bittaran_was_attacking = attacking
    # On the LAST attack frame the director may already return {}; stage
    # the leg-home/body-rise recovery before permitting any next gait.
    var front_just_completed: bool = (
        previous_front_attack and not attacking and attack_permitted)
    var front_restoring: bool = (front_just_completed
        or (bittaran_foot_ik != null and bool(
            bittaran_foot_ik.call("front_height_recovery_active"))))
    if previous_front_attack and not attacking and not attack_permitted             and bittaran_foot_ik != null:
        # A KO, leg break, or disabled combat is interruption, not a
        # normal recovery. It must discard all temporary height state.
        bittaran_foot_ik.call("clear_attack_pose")
    if attacking and ["leg_fl", "leg_fr"].has(str(
            bittaran_attack_frame.get("id", ""))):
        bittaran_attack_frame["direct_front_test"] = true
    var preparing_stance: bool = bool(
        bittaran_attack_frame.get("stance_prepare", false))
    if bittaran_foot_ik != null and not preparing_stance and bool(
            bittaran_foot_ik.get("attack_stance_active")):
        # The first TRUE attack frame starts only AFTER all four feet
        # finish their two diagonal IK replants. Release the staging
        # metadata, keeping the new world-planted neutral anchors.
        bittaran_foot_ik.call("clear_attack_stance")
    if bittaran_rig != null:
        if attacking and not preparing_stance and not bool(
                bittaran_attack_frame.get("original_attack_only", false)):
            bittaran_rig.call("start_authored_attack",
                str(bittaran_attack_frame.get("kind", "")),
                str(bittaran_attack_frame.get("id", "")))
        else:
            # Original-only clips have no procedural start/end blend.
            bittaran_rig.call("end_authored_attack")
    if attacking and not preparing_stance and not bool(
            bittaran_attack_frame.get("direct_front_test", false)):
        # Each attack tracks SERA while drawing back, then freezes the
        # attack heading on release; no mid-swing re-aim.
        # Unlike normal Turn, this yaw belongs solely to the BODY bone:
        # target.root position and orientation never change in an attack.
        if bool(bittaran_attack_frame.get("tracking", false)):
            var player_offset: Vector3 = player.global_position - target.global_position
            player_offset.y = 0.0
            if player_offset.length_squared() > 0.0001:
                # v409: yaw the chest so the attacking leg's hip
                # corner (ATTACK_CHEST_CORNER_DEGREES) faces the
                # player, capped at ATTACK_CHEST_MAX_YAW_DEGREES.
                # Its yaw owns target tracking; IK only keeps the
                # other soles planted.
                var corner: float = deg_to_rad(float(
                    ATTACK_CHEST_CORNER_DEGREES.get(str(
                        bittaran_attack_frame.get("id", "")), 0.0)))
                var desired: float = wrapf(
                    atan2(player_offset.x, player_offset.z)
                    - target.rotation.y
                    - corner, -PI, PI)
                desired = clampf(desired,
                    -deg_to_rad(ATTACK_CHEST_MAX_YAW_DEGREES),
                    deg_to_rad(ATTACK_CHEST_MAX_YAW_DEGREES))
                bittaran_attack_body_yaw = move_toward(
                    bittaran_attack_body_yaw, desired,
                    deg_to_rad(ATTACK_CHEST_TURN_DEGREES_PER_SECOND)
                        * maxf(delta, 0.0))
        bittaran_attack_frame["body_yaw"] = bittaran_attack_body_yaw
    else:
        bittaran_attack_body_yaw = 0.0
    var frozen: bool = (
        attacking or front_restoring or postattack_replanting
        or not target_move_enabled or target_hp <= 0
        or generic_damage_frozen
        or down_remaining > 0.0 or training_ko_remaining > 0.0
        or recovery_motion_locked)
    # If the only sector-valid attack would repeat the preceding kind,
    # keep walking/orbiting/retreating until the next DIFFERENT authored
    # strike is physically available. Never stand in range looping STOMP,
    # KICK, or SWEEP; nor fake a sweep through the narrow KICK cone.
    var need_attack_variation: bool = (
        attack_permitted and not attacking
        and bittaran_attacks != null
        and bool(bittaran_attacks.call(
            "repeat_kind_blocked", player.global_position,
            target.global_position, target.rotation.y,
            _bittaran_attack_candidates())))
    # Use the normal AI branch to choose Turn, Approach, or Idle. Do not
    # substitute the v365 Idle-only recovery yaw controller here.
    var result: Dictionary = bittaran_ai.call("advance", delta,
        target.position, target.rotation.y, player.position, frozen,
        not enough_walk_steps or need_attack_variation,
        need_attack_variation,
        str(bittaran_attacks.get("last_kind"))
            if bittaran_attacks != null else "")
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
    bittaran_motion = (
        "Idle" if attacking or front_restoring or postattack_replanting
        else str(result["motion"]))
    if bittaran_rig != null:
        # The rig NEVER writes the Head quaternion while changing clips;
        # current procedural yaw persists until the tracking controller's
        # next collision-safe update at the end of this physics frame.
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


# v464: camera fit is computed from EVERY rendered Bittaran mesh, not the
# smaller training-dummy frame. Preserve margin for animated legs and cannon.
const BITTARAN_FRAME_WORLD_PADDING: float = 0.42

func _bittaran_model_world_bounds() -> AABB:
    if bittaran_rig == null:
        return AABB()
    var meshes: Dictionary = bittaran_rig.get("mesh_nodes_by_uuid")
    var found: bool = false
    var result := AABB()
    # These are all 18 imported source meshes, including the mobile
    # head, four real articulated legs/feet and the two dorsal rails.
    for raw in meshes.values():
        var part: MeshInstance3D = raw as MeshInstance3D
        if part == null or not is_instance_valid(part) or part.mesh == null:
            continue
        var box: AABB = part.get_aabb()
        for x in [box.position.x, box.end.x]:
            for y in [box.position.y, box.end.y]:
                for z in [box.position.z, box.end.z]:
                    var point: Vector3 = part.to_global(Vector3(x, y, z))
                    if not found:
                        result = AABB(point, Vector3.ZERO)
                        found = true
                    else:
                        result = result.expand(point)
    # Also keep the newly added side charge boxes visible at any barrel
    # rotation. Exclude the laser itself: its 45m ray should not zoom out.
    if bittaran_railgun != null:
        for side in ["L", "R"]:
            var box_part: MeshInstance3D = bittaran_railgun.find_child(
                "RailgunSideBox_" + side, true, false) as MeshInstance3D
            if box_part == null or box_part.mesh == null:
                continue
            var side_bounds: AABB = box_part.get_aabb()
            for x in [side_bounds.position.x, side_bounds.end.x]:
                for y in [side_bounds.position.y, side_bounds.end.y]:
                    for z in [side_bounds.position.z, side_bounds.end.z]:
                        var point: Vector3 = box_part.to_global(
                            Vector3(x, y, z))
                        if not found:
                            result = AABB(point, Vector3.ZERO)
                            found = true
                        else:
                            result = result.expand(point)
    return result.grow(BITTARAN_FRAME_WORLD_PADDING) if found else AABB()


func _bittaran_camera_bounds_corners() -> Array[Vector3]:
    var bounds: AABB = _bittaran_model_world_bounds()
    var corners: Array[Vector3] = []
    if not bounds.has_volume():
        return corners
    for x in [bounds.position.x, bounds.end.x]:
        for y in [bounds.position.y, bounds.end.y]:
            for z in [bounds.position.z, bounds.end.z]:
                corners.append(Vector3(x, y, z))
    return corners


func _minimum_boost_camera_radius() -> float:
    # Retain SERA's player/lock safety margins, then fit the actual entire
    # moving boss at every view heading and during BOOST as well.
    var safe_radius: float = super._minimum_boost_camera_radius()
    if camera == null:
        return safe_radius
    var corners: Array[Vector3] = _bittaran_camera_bounds_corners()
    if corners.is_empty():
        return safe_radius
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return safe_radius
    var aspect: float = viewport_size.x / viewport_size.y
    var tan_v: float = tan(deg_to_rad(camera.fov) * 0.5)
    var tan_h: float = tan_v * aspect
    if camera.keep_aspect == Camera3D.KEEP_WIDTH:
        tan_h = tan(deg_to_rad(camera.fov) * 0.5)
        tan_v = tan_h / aspect
    var right: Vector3 = camera.global_basis.x.normalized()
    var up: Vector3 = camera.global_basis.y.normalized()
    var outward: Vector3 = Vector3(
        sin(camera_yaw), CAMERA_ELEVATION_RATIO, cos(camera_yaw))
    var radial_scale: float = outward.length()
    outward /= radial_scale
    # Use the SAME focus and elevation as main.gd's _place_camera().
    var focus := Vector3(camera_focus_follow_xz.x,
        TARGET_BASE_HEIGHT - CAMERA_FOCUS_DROP, camera_focus_follow_xz.y)
    for point in corners:
        safe_radius = maxf(safe_radius, _camera_radius_for_safe_point(
            point, focus, right, up, outward, radial_scale, tan_h, tan_v,
            TARGET_FRAME_MARGIN_X, TARGET_FRAME_MARGIN_Y,
            TARGET_FRAME_BOTTOM))
    return safe_radius


func _target_fully_in_frame() -> bool:
    # Called by inherited fit/binary-search and release code. Never
    # substitute the training cube's smaller static ±2.35m corner set.
    if camera == null:
        return true
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return true
    for point in _bittaran_camera_bounds_corners():
        if camera.is_position_behind(point):
            return false
        var screen_pos: Vector2 = camera.unproject_position(point)
        if screen_pos.x < viewport_size.x * TARGET_FRAME_MARGIN_X or (
                screen_pos.x > viewport_size.x * (
                1.0 - TARGET_FRAME_MARGIN_X)):
            return false
        if screen_pos.y < viewport_size.y * TARGET_FRAME_MARGIN_Y or (
                screen_pos.y > viewport_size.y * TARGET_FRAME_BOTTOM):
            return false
    return true

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
    _tick_bittaran_shockwave(delta)
    _tick_bittaran_railgun(delta)
    _tick_impact_shake(delta)
    _tick_bittaran_footfalls()
    _update_bittaran_lock_permissions()

func _tick_bittaran_railgun(delta: float) -> void:
    if bittaran_railgun == null or player == null:
        return
    # An ordinary beam hit must not stop the cannon or cancel the
    # player's BOOST/STEP. On player KO keep the VISUAL beam and slow
    # pursuit running until its natural two-second end, but apply no
    # further damage. Boss death still disables the gun.
    var active: bool = target_hp > 0.0
    var boost_speed_mps: float = (
        float(part_stats.get("boost_speed", 6.09375)) *
        float(part_stats.get("boost_speed_mult", 1.0)))
    var run_speed_mps: float = float(
        part_stats.get("run_speed", 4.0625))
    var laser_pulse: bool = bool(bittaran_railgun.call(
        "advance", delta, player.global_position, active,
        boost_speed_mps, run_speed_mps))
    if laser_pulse and player_hp > 0.0 and training_ko_remaining <= 0.0:
        var incoming: Vector3 = (
            player.global_position - bittaran_railgun.global_position)
        if incoming.length_squared() < 0.000001:
            incoming = Vector3.FORWARD
        # Same HP/shield/guard costs, without normal bullet knockback:
        # continuous BOOST stays available, including after being hit.
        _on_enemy_projectile_hit(player.global_position,
            incoming.normalized(), true, 0, true)

## Read the actual world-space striking-foot mesh after source replay + IK.
## The legacy procedural attack_pose stays empty during source replay.
func _bittaran_attack_foot_bounds(leg_id: String) -> AABB:
    if bittaran_foot_ik == null:
        return AABB()
    var index: int = BittaranFootIK.LEG_PART_IDS.find(leg_id)
    var legs: Array = bittaran_foot_ik.get("legs")
    if index < 0 or index >= legs.size():
        return AABB()
    var foot: Node3D = legs[index].get("foot", null) as Node3D
    if foot == null:
        return AABB()
    var first: bool = true
    var low: Vector3 = Vector3.ZERO
    var high: Vector3 = Vector3.ZERO
    for child in foot.get_children():
        if not child is MeshInstance3D:
            continue
        var mesh_node: MeshInstance3D = child as MeshInstance3D
        if mesh_node.mesh == null:
            continue
        var bounds: AABB = mesh_node.mesh.get_aabb()
        for vertex_index in range(8):
            var vertex: Vector3 = mesh_node.to_global(
                bounds.get_endpoint(vertex_index))
            if first:
                low = vertex
                high = vertex
                first = false
            else:
                low = low.min(vertex)
                high = high.max(vertex)
    return AABB() if first else AABB(low, high - low)


func _bittaran_original_attack_contact(leg_id: String) -> Vector3:
    var bounds: AABB = _bittaran_attack_foot_bounds(leg_id)
    if not bounds.has_volume():
        return Vector3.ZERO
    var center: Vector3 = bounds.get_center()
    return Vector3(center.x, bounds.position.y, center.z)


## Sole FX anchor: sample the actual transformed mesh box corners on
## the lowest 8.5cm strip, not the CENTER of the long tilted toe AABB.
## Unlike collision, this changes only the visual emitter position.
## It works for each mirrored leg after source playback and live IK.
func _bittaran_ground_fx_contact(leg_id: String) -> Vector3:
    var bounds: AABB = _bittaran_attack_foot_bounds(leg_id)
    if not bounds.has_volume() or bittaran_foot_ik == null:
        return _bittaran_original_attack_contact(leg_id)
    var leg_index: int = BittaranFootIK.LEG_PART_IDS.find(leg_id)
    var legs: Array = bittaran_foot_ik.get("legs")
    if leg_index < 0 or leg_index >= legs.size():
        return _bittaran_original_attack_contact(leg_id)
    var foot: Node3D = legs[leg_index].get("foot", null) as Node3D
    if foot == null:
        return _bittaran_original_attack_contact(leg_id)
    var points: Array[Vector3] = []
    var lowest: float = INF
    for child in foot.get_children():
        if not child is MeshInstance3D:
            continue
        var piece: MeshInstance3D = child as MeshInstance3D
        if piece.mesh == null:
            continue
        var box: AABB = piece.mesh.get_aabb()
        for corner in range(8):
            var vertex: Vector3 = piece.to_global(box.get_endpoint(corner))
            points.append(vertex)
            lowest = minf(lowest, vertex.y)
    if points.is_empty():
        return _bittaran_original_attack_contact(leg_id)
    # A hard 8.5cm cutoff swaps discrete mesh corners as the toe
    # rotates. That snaps the emitter from one side of the foot to
    # another. Continuous soft-minimum weights preserve the ground
    # contact without a discontinuous choice of bottom vertices.
    var weighted: Vector3 = Vector3.ZERO
    var weight_total: float = 0.0
    for vertex in points:
        var height: float = maxf(vertex.y - lowest, 0.0)
        var weight: float = exp(-minf(height / 0.12, 18.0))
        weighted += vertex * weight
        weight_total += weight
    if weight_total <= 0.000001:
        return _bittaran_original_attack_contact(leg_id)
    return Vector3(weighted.x / weight_total, lowest,
        weighted.z / weight_total)


func _bittaran_striking_foot_grounded(leg_id: String) -> bool:
    var bounds: AABB = _bittaran_attack_foot_bounds(leg_id)
    if not bounds.has_volume():
        return false
    # Godot's arena floor is Y=0. A mesh is contacting ground only when
    # its actual rendered volume intersects the floor within 6 cm.
    # A foot above the floor, or one entirely buried below it, emits none.
    return (bounds.position.y <= 0.06 and bounds.end.y >= -0.02)


func _finalize_target_pose(delta: float) -> void:
    # v434 is a strict staging phase. Source animation runs on the 14-joint
    # hierarchy without ANY subsequent IK/head/body/contact correction.
    # Physics collision and lock-part synchronization remain enabled.
    if BLOCKBENCH_SOURCE_REPLAY_ONLY:
        if bittaran_rig != null and not bittaran_attack_frame.is_empty() and (
                bool(bittaran_attack_frame.get(
                    "original_attack_only", false))):
            bittaran_rig.call("apply_original_attack_only",
                bittaran_attack_frame)
    elif BLOCKBENCH_GAIT_SUPPORT_IK:
        # The source animation owns the BODY and all 4 joint chains first.
        # Then apply IK ONLY to locomotion soles or to 3 support limbs.
        # No mesh offsets, no chassis pitch/height/crouch corrections,
        # and no legacy front-attack floor solver.
        if bittaran_rig != null and not bittaran_attack_frame.is_empty() and (
                bool(bittaran_attack_frame.get(
                    "original_attack_only", false))):
            bittaran_rig.call("apply_original_attack_only",
                bittaran_attack_frame)
            if player != null:
                # Apply bounded BODY hip-corner and shoulder aim AFTER
                # authored clip replay, BEFORE all three support IK solves.
                # The authored rotations remain immutable source data.
                bittaran_rig.call("apply_source_attack_aim",
                    bittaran_attack_frame, player.global_position, delta)
        if bittaran_foot_ik != null and target != null and target_hp > 0:
            bittaran_foot_ik.call("advance_source_ground_ik",
                delta, bittaran_motion, bittaran_attack_frame)
        # Preserve actual post-IK bone locals for the NEXT rear attack.
        # This capture happens only outside source attacks so the
        # first entry pose stays fixed across all transition frames.
        if bittaran_rig != null and bittaran_attack_frame.is_empty():
            bittaran_rig.call("remember_source_grounded_attack_entry")
        # The source-IK branch previously skipped live HEAD tracking;
        # only the legacy solver's else branch called this. Restore
        # player-facing head yaw/pitch with its existing collision and
        # stand-up clearance limits on every active combat frame.
        _aim_bittaran_head(delta)
    else:
        if bittaran_foot_ik != null and target != null and target_hp > 0:
            var attack_frame: Dictionary = bittaran_attack_frame.duplicate()
            var preparing_stance: bool = bool(
                attack_frame.get("stance_prepare", false))
            if preparing_stance:
                bittaran_foot_ik.call("begin_attack_stance",
                    str(attack_frame.get("id", "")))
                attack_frame.clear()
            if not attack_frame.is_empty() and bittaran_rig != null:
                bittaran_rig.call("apply_authored_attack_pose", attack_frame)
                attack_frame["authored"] = true
            elif bittaran_rig != null and bool(bittaran_foot_ik.call(
                    "attack_down_windup_active")):
                var progress: float = clampf(
                    (float(bittaran_foot_ik.get("windup_elapsed"))
                    + maxf(delta, 0.0))
                    / BittaranFootIK.LEG_BREAK_WINDUP_SECONDS, 0.0, 1.0)
                bittaran_rig.call("apply_stomp_down_windup", progress)
            elif bittaran_rig != null and bool(bittaran_foot_ik.call(
                    "down_pose_active")):
                bittaran_rig.call("clear_stomp_down_windup")
            bittaran_foot_ik.call("set_attack_pose", attack_frame)
            bittaran_foot_ik.call("advance_ik", delta, bittaran_motion)
        _aim_bittaran_head(delta)
    # No mesh is individually moved in either branch. v433's intact
    # parent-child hierarchy is kept unchanged.
    if target_parts != null:
        target_parts.call("sync_bittaran_parts")
    _push_player_out_of_downed_body(delta)
    _check_bittaran_attack_hit()
    if bittaran_dirt_fx != null and bittaran_foot_ik != null:
        var original: bool = bool(bittaran_attack_frame.get(
            "original_attack_only", false))
        # Prepare all four ORIGINAL source-clip toe trajectories during
        # the FIRST SWEEP ENTRY (before any dust is ever emitted).
        # The renderer then reads a fixed time->position table; it
        # never chases IK foot jitter during the first ground scrape.
        if not bittaran_sweep_fx_baked and original and (
                str(bittaran_attack_frame.get("kind", "")) == "sweep"
                and str(bittaran_attack_frame.get(
                    "phase", "")) == "entry"):
            var tracks: Dictionary = (
                BittaranSweepFXTrack.bake_from_authored_clips(
                    self, bittaran_rig, target))
            if tracks.size() == BittaranAttacks.LEG_IDS.size():
                bittaran_dirt_fx.call(
                    "configure_prebaked_sweeps", tracks, target)
                bittaran_sweep_fx_baked = true
        if bittaran_attack_frame.is_empty() or bool(
                bittaran_attack_frame.get("stance_prepare", false)):
            bittaran_dirt_fx.call("advance_attack", {}, Vector3.ZERO,
                Vector3.ZERO, delta, false)
            attack_contact_initialized = false
        else:
            var leg_id: String = str(bittaran_attack_frame.get("id", ""))
            # Use the visible foot's real mesh bounds AFTER authored replay
            # and IK, not the procedural floor target or attack timer.
            # VFX-only tolerance: animated toes may hover a few
            # centimetres above the floor between physics samples.
            # Damage still uses the STRICT mesh contact check.
            var grounded: bool = _bittaran_striking_foot_grounded(leg_id)
            if not grounded:
                var fx_box: AABB = _bittaran_attack_foot_bounds(leg_id)
                grounded = fx_box.has_volume() and (
                    fx_box.position.y <= 0.12 and fx_box.end.y >= -0.05)
            var contact: Vector3 = (
                _bittaran_ground_fx_contact(leg_id) if original
                else bittaran_foot_ik.call("attack_contact_world"))
            var previous: Vector3 = (
                last_attack_contact if attack_contact_initialized else contact)
            var had_kick: bool = bool(bittaran_dirt_fx.get(
                "kicked_this_attack"))
            var had_sweep: bool = bool(bittaran_dirt_fx.get("sweep_active"))
            # The FX module prioritizes the measured horizontal
            # foot travel. Only if there was no usable motion does it
            # fall back to the direction of SERA from the contact.
            var player_dir: Vector3 = (
                player.global_position - contact
                if player != null else Vector3.ZERO)
            bittaran_dirt_fx.call("advance_attack",
                bittaran_attack_frame, contact, previous, delta,
                grounded, player_dir)
            if original and target_hp > 0:
                var kind: String = str(bittaran_attack_frame.get("kind", ""))
                var phase: String = str(
                    bittaran_attack_frame.get("phase", ""))
                # STOMP's gameplay/contact pulse is handled in
                # _check_bittaran_attack_hit() at the first true floor
                # contact. Never let FX update schedule a second or
                # late impact during recovery/slow aftermath.
                if kind == "kick" and not had_kick and bool(
                        bittaran_dirt_fx.get("kicked_this_attack")):
                    _add_impact_shake(0.16)
                    _play_bittaran_thud(contact, 1.5, -10.0)
                elif kind == "sweep" and not had_sweep and bool(
                        bittaran_dirt_fx.get("sweep_active")):
                    _add_impact_shake(0.19)
                    _play_bittaran_thud(contact, 1.25, -9.0)
            last_attack_contact = contact
            attack_contact_initialized = true
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
    var attacking_leg_at_hit: String = (str(
        bittaran_rig.get("authored_leg_id")) if bittaran_rig != null else "")
    var active_at_hit: bool = (bittaran_rig != null and not str(
        bittaran_rig.get("active_authored_attack")).is_empty()
        and not attacking_leg_at_hit.is_empty())
    var alive_before: bool = target_hp > 0
    var result: Dictionary = super._apply_target_part_damage(
        kind, raw_attack, raw_break, weak_stagger, extension)
    # A shin breaking makes its whole leg skid out; temporarily lower
    # the chassis until the HEAD comes into SERA's melee reach, then restore.
    if bool(result.get("broken", false)) and str(result.get("kind", "")) == "leg":
        if bittaran_attacks != null:
            bittaran_attacks.call("cancel")
        bittaran_attack_frame.clear()
        bittaran_attack_body_yaw = 0.0
        if bittaran_foot_ik != null:
            bittaran_foot_ik.call("clear_attack_pose")
        if bittaran_foot_ik != null and target_parts != null:
            boss_head_windup_start_yaw = boss_head_yaw
            head_collision_filtered_depth = 0.0
            head_collision_blocked = false
            head_collision_release_elapsed = 0.0
            var head_world: Vector3 = target_parts.call("get_part_aim_world", "head")
            bittaran_foot_ik.call("start_leg_break_slide", hit_id, head_world.y,
                int(result.get("broken_legs", 0)) >= 4)
            # On an INTERRUPTED attack retain the player's head tracker.
            # Shift the authored combat BODY and striking limb to the
            # real STOMP raised prepose over the existing separate 0.60s
            # down anticipation, rather than resetting to Wait instantly.
            # Non-attacking knockdowns retain their old nose-up telegraph.
            if active_at_hit and bittaran_rig != null:
                if bool(bittaran_rig.call(
                        "begin_stomp_down_windup",
                        attacking_leg_at_hit)):
                    bittaran_foot_ik.call(
                        "begin_attack_down_windup", attacking_leg_at_hit)
                    # Stop the old swing controller but do NOT reset
                    # the actual currently displayed joint angles.
                    bittaran_rig.call("end_authored_attack")
                else:
                    bittaran_rig.call("cancel_authored_attack_for_down")
            # The base training boss starts a generic 1s/3.5s animation
            # freeze on every broken limb. Bittaran's longer physical
            # knockdown replaces it entirely; otherwise 2nd+ breaks
            # remain animation-locked past the first upward recovery.
            part_break_remaining = 0.0
            stagger_remaining = 0.0
            # Weakpoints become lockable in this very hit frame.
            target_parts.call("set_down_lock_enabled", true)
    if alive_before and target_hp == 0:
        if bittaran_attacks != null:
            bittaran_attacks.call("cancel")
        bittaran_attack_frame.clear()
        if bittaran_foot_ik != null:
            bittaran_foot_ik.call("clear_attack_pose")
        if bittaran_rig != null:
            bittaran_rig.call("clear_stomp_down_windup")
        if bittaran_foot_ik != null:
            bittaran_foot_ik.call("clear_attack_down_windup")
        if active_at_hit and bittaran_rig != null and not bool(
                result.get("broken", false)):
            bittaran_rig.call("cancel_authored_attack_for_down")
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
    if bittaran_rig != null:
        bittaran_rig.call("clear_stomp_down_windup")
    if bittaran_railgun != null:
        bittaran_railgun.call("reset")
    boss_head_pitch = 0.0
    head_look_filtered_pitch = 0.0
    boss_head_windup_start_yaw = 0.0
    head_neutral_overlap.clear()
    head_neutral_component_overlap.clear()
    head_collision_filtered_depth = 0.0
    head_collision_blocked = false
    head_collision_release_elapsed = 0.0
    head_look_filtered_yaw = 0.0
    head_look_initialized = false
    head_vertical_offset_world = 0.0
    head_visual_clearance_lift_world = 0.0
    if player != null:
        head_player_rest_world_y = player.global_position.y
    if bittaran_head != null:
        bittaran_head.position = boss_head_rest_local_position
    boss_downed_escaping = false
    if boss_death_particles != null:
        boss_death_particles.emitting = false
    if bittaran_ai != null:
        bittaran_ai.call("reset")
    bittaran_walk_attack_step_gate = BITTARAN_MIN_WALK_STEPS
    bittaran_was_attacking = false
    if bittaran_attacks != null:
        bittaran_attacks.call("reset")
    # Clear last encounter's world-fixed smoke and source-sweep
    # play cursor. Immutable four-leg pre-baked templates stay loaded.
    if bittaran_dirt_fx != null:
        bittaran_dirt_fx.call("reset")
    bittaran_attack_frame.clear()
    bittaran_attack_body_yaw = 0.0
    shockwave_elapsed = -1.0
    if bittaran_shockwave != null:
        bittaran_shockwave.visible = false
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
