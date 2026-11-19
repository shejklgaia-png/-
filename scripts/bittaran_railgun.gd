extends Node3D
## Bittaran's dorsal railgun. Its 10-second stationary fill and separate
## sphere/beam/return are independent of locomotion, source clips and HEAD.
## Untracked WAIT follows the animated Body's full pose (yaw, pitch, roll).
## During sphere acquisition and beam tracking, barrel yaw and elevation
## operate in WORLD space so turning the chassis never adds to aim speed.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const RailgunFX = preload("res://scripts/bittaran_railgun_fx.gd")

# v480: Creator-supplied sounds. The sustained laser is a seamless,
# offline crossfaded body of sen_mi_b_saberu, never a new burst per frame.
const CHARGE_AUDIO_PATH: String = "res://assets/bittaran_charge_v480.ogg"
const LASER_ATTACK_AUDIO_PATH: String = "res://assets/bittaran_laser_attack_v480.ogg"
const LASER_LOOP_AUDIO_PATH: String = "res://assets/bittaran_laser_sustain_loop_v480.ogg"
const LASER_LOOP_FADE_IN_SECONDS: float = 0.08
const LASER_LOOP_FADE_OUT_SECONDS: float = 0.14
const LASER_LOOP_VOLUME_DB: float = -11.0
const LASER_ATTACK_VOLUME_DB: float = -7.0
const CHARGE_VOLUME_DB: float = -5.0
const SILENT_AUDIO_DB: float = -80.0

# Hold neutral throughout the first 10 seconds of filling the charge lamps.
# The BLUE SPHERE (t=10..12) starts with one eased, unrestricted acquisition.
# At sphere SHRINK (t=11) use 0.7x capped pursuit without beam acceleration.
# At laser firing (t=12), start near-axis at 0.85x and increase up to
# 1.0x fixed RUN<chase<BOOST speed across only 0..1.5m ray separation.
# Beyond 1.5m NEVER increase the turn rate: BOOST can still escape.
# Return to the neutral pose during the 0.7s after the 2s beam.
const WAIT_SECONDS: float = 10.0
const FLASH_SECONDS: float = 2.0
const FLASH_START: float = WAIT_SECONDS
const FLASH_END: float = FLASH_START + FLASH_SECONDS
const BEAM_SECONDS: float = 2.0
const BEAM_START: float = FLASH_END
const BEAM_END: float = BEAM_START + BEAM_SECONDS
const RETURN_SECONDS: float = 0.7
const PERIOD_SECONDS: float = BEAM_END + RETURN_SECONDS
const FLASH_GROW_SECONDS: float = 0.2
const FLASH_SHRINK_SECONDS: float = 1.0
const FLASH_SHRINK_START: float = FLASH_END - FLASH_SHRINK_SECONDS
# Fast charge acquisition starts ONCE at blue-sphere appearance (t=10),
# then switches to capped 0.7x when the actual shrink starts (t=11).
# The 10s fill is stationary; slow firing track and neutral return remain.
const TRACK_BLEND_SECONDS: float = 0.7
const TRACK_EASE_IN_SECONDS: float = TRACK_BLEND_SECONDS
const TRACK_START_SECONDS: float = FLASH_START
const CHARGE_TRACK_FILTER_PER_SECOND: float = 30.0
const TRACK_FILTER_PER_SECOND: float = 10.0
# During the laser only, narrow the angular lag (keep the prefire unchanged).
const BEAM_AIM_FILTER_PER_SECOND: float = 14.0
# Sphere shrinking stays at its previous 0.7x; the fired beam starts at 0.85x.
const BEAM_TRACK_SPEED_MULTIPLIER: float = 0.70
const BEAM_ON_AXIS_SPEED_MULTIPLIER: float = 0.85
const BEAM_GROUND_GAP_METERS: float = 1.50
# 0..1.5m smoothstep blends the 0.85x firing rate to the full chase rate.
# The chase rate is always bounded between equipment RUN and BOOST speeds.
# Beyond 1.5m, there is no extra acceleration or velocity-derived spike.
const BEAM_CATCHUP_RESPONSE_PER_SECOND: float = 16.0
# Repeated contact may damage for the duration of a beam. Per-contact
# cooldown prevents one hit on every physics frame at 30/60/120Hz.
const BEAM_HIT_INTERVAL_SECONDS: float = 0.20
# 1x RUN should not outpace the continuous tracking slew, but 1.5x
# BOOST must. Interpolate the equipment's actual RUN and BOOST speeds.
# Converting linear speed to angular speed using distance retains that
# distinction at 5m, 8m, 30m, and every other combat distance.
const RUN_REFERENCE_SPEED_MPS: float = 4.0625
const BOOST_REFERENCE_SPEED_MPS: float = 6.09375
const CHASE_SPEED_BLEND: float = 0.65
const CHASE_SPEED_MPS: float = (RUN_REFERENCE_SPEED_MPS
    + (BOOST_REFERENCE_SPEED_MPS - RUN_REFERENCE_SPEED_MPS)
    * CHASE_SPEED_BLEND)
const MAX_BEAM_RANGE_METERS: float = 45.0
const BEAM_RADIUS_METERS: float = 0.70
const PLAYER_HIT_RADIUS_METERS: float = 0.48
const MUZZLE_LOCAL_Z: float = -1.53
# The authored barrel pivot is measured in the animated Body's coordinates.
# Keep its POSITION attached while its rotation lives in WORLD space.
const MOUNT_LOCAL_OFFSET: Vector3 = Vector3(-0.0435, 2.493, -0.4205)
# Only the idle rejoin after a moving-chassis return uses this cap.
# It must not snap the turret or affect the active beam tracking speed.
const PARK_REACQUIRE_DEG_PER_SECOND: float = 180.0
# Rejoin the latest Body attitude smoothly after the world-locked return.
# The same 0.7s eases away a FROZEN idle-pose offset when aiming begins.
const IDLE_POSE_REJOIN_SECONDS: float = 0.7
# Two authored rails, not the body, pedestal, head or either leg.
# The separate upper vertical shaft turns with the CHASSIS yaw, never with
# the barrel's independent world-space targeting yaw.
# Original mesh UUIDs, geometry, materials and Blockbench source are retained.
const CHASSIS_AXIS_MESH_UUID: String = "4b184c7d-480e-cd99-3dca-596928ffd5cd"
const RAIL_MESH_UUIDS = [
    "2ce4b10f-8a6d-72de-8b79-763d67e41b78",
    "3e2ee103-881b-8bc0-edc1-ea9e396268e9",
]

enum Phase { WAIT, FLASH, BEAM, RETURN }
var elevation: Node3D
var outer_beam: MeshInstance3D
var inner_beam: MeshInstance3D
var muzzle_flash: MeshInstance3D
var energy_fx: Node3D
var charge_audio: AudioStreamPlayer
var laser_attack_audio: AudioStreamPlayer
var laser_loop_audio: AudioStreamPlayer
var laser_loop_gain: float = 0.0
var laser_loop_starts: int = 0
var laser_attack_starts: int = 0
var charge_starts: int = 0
var beam_local_length: float = 1.0
var charge_materials: Array[StandardMaterial3D] = []
var elapsed: float = 0.0
var last_phase: int = Phase.WAIT
var return_yaw_origin: float = 0.0
var return_pitch_origin: float = 0.0
var return_world_yaw_origin: float = 0.0
var return_neutral_world_yaw: float = 0.0
# Laser damage can repeat while there is real overlap, with no hit-count cap.
var beam_hit_cooldown: float = 0.0
# Continuous beam pursuit eases toward a bounded angular rate when the
# player leaves the projected ground ray.
var beam_turn_rate_deg_per_sec: float = 0.0
var beam_ground_gap_meters: float = 0.0
var beam_ground_point: Vector3 = Vector3.ZERO
var ready_to_fire: bool = false
var mount_body: Node3D
var mount_rig: Node3D
var chassis_axis: Node3D
var aim_yaw: float = 0.0
var tracked_world_yaw: float = 0.0
var tracking_world_initialized: bool = false
var idle_pose_blend: float = 1.0
var charge_entry_pose_offset: Quaternion = Quaternion.IDENTITY

func setup(rig: Node3D) -> bool:
    var body: Node3D = rig.find_child("Body", true, false) as Node3D
    if body == null or get_parent() != body:
        push_error("Bittaran railgun must be a child of the animated Body bone")
        return false
    mount_body = body
    mount_rig = rig
    var model_meshes: Dictionary = rig.get("mesh_nodes_by_uuid")
    for uid in RAIL_MESH_UUIDS:
        if not model_meshes.has(uid) or not is_instance_valid(model_meshes[uid]):
            push_error("Bittaran railgun: authored barrel is missing: " + uid)
            return false
    # Pivot is the measured neutral center of the two imported long rails.
    # The rig's Body origin is [0.3,3.7,-1.4] in Blockbench coordinates.
    position = MOUNT_LOCAL_OFFSET
    # A child under the turning chassis can inherit yaw between physics
    # updates even when its tracked WORLD yaw is compensated every tick.
    # Keep the Body parent for ownership, but decouple the world transform.
    var original_world_mount: Transform3D = global_transform
    top_level = true
    global_transform = original_world_mount
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
    elevation = Node3D.new()
    elevation.name = "RailgunElevation"
    elevation.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
    add_child(elevation)
    # The tall original shaft above the pedestal is NOT an aiming barrel.
    # Its pivot stays attached to the authored Body position, but faces only
    # the boss chassis' horizontal heading, even during Body pitch/roll.
    # This prevents aim_yaw from twisting the shaft away from the chassis.
    var mesh_bind_positions: Dictionary = rig.get("mesh_base_positions_by_uuid")
    var shaft: MeshInstance3D = model_meshes.get(
        CHASSIS_AXIS_MESH_UUID) as MeshInstance3D
    if shaft == null or shaft.get_parent() != mount_body:
        push_error("Bittaran railgun: upper connection shaft is missing")
        return false
    chassis_axis = Node3D.new()
    chassis_axis.name = "RailgunChassisAxis"
    chassis_axis.physics_interpolation_mode = (
        Node.PHYSICS_INTERPOLATION_MODE_ON)
    chassis_axis.position = shaft.position
    mount_body.add_child(chassis_axis)
    shaft.reparent(chassis_axis, false)
    shaft.position = Vector3.ZERO
    shaft.quaternion = Quaternion.IDENTITY
    mesh_bind_positions[CHASSIS_AXIS_MESH_UUID] = shaft.position

    # Preserve both actual rail meshes' WORLD transforms when reparenting:
    # only the twin barrels pitch and aim; the shaft tracks the chassis.
    for uid in RAIL_MESH_UUIDS:
        var rail: MeshInstance3D = model_meshes[uid] as MeshInstance3D
        rail.reparent(elevation, true)
        # Diagnostic and skeleton regression checks measure neutral LOCAL
        # placement against this runtime parent, not the historical Body.
        mesh_bind_positions[uid] = rail.position
    rig.set("mesh_base_positions_by_uuid", mesh_bind_positions)
    _build_charge_boxes()
    _build_beam()
    _build_muzzle_flash()
    energy_fx = RailgunFX.new()
    energy_fx.name = "RailgunEnergyFX"
    elevation.add_child(energy_fx)
    energy_fx.call("setup", MUZZLE_LOCAL_Z, beam_local_length)
    _build_railgun_audio()
    reset()
    ready_to_fire = true
    return true

func _metal_box(parent: Node3D, node_name: String, box_size: Vector3,
        offset: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = box_size
    var part := MeshInstance3D.new()
    part.name = node_name
    part.mesh = mesh
    part.position = offset
    part.material_override = mat
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(part)
    return part

func _build_charge_boxes() -> void:
    var case_material := StandardMaterial3D.new()
    case_material.albedo_color = Color("#394a62")
    case_material.metallic = 0.55
    case_material.roughness = 0.36
    for side in [-1, 1]:
        var suffix: String = "L" if side < 0 else "R"
        _metal_box(elevation, "RailgunSideBox_" + suffix,
            Vector3(0.13, 0.26, 0.76), Vector3(float(side) * 0.33, 0.02, -0.24),
            case_material)
        for segment in range(3):
            var glow := StandardMaterial3D.new()
            glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            glow.emission_enabled = true
            glow.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
            charge_materials.append(glow)
            _metal_box(elevation, "ChargeBar_%s_%d" % [suffix, segment + 1],
                Vector3(0.018, 0.062, 0.16),
                Vector3(float(side) * 0.406, 0.055,
                    0.0 - float(segment) * 0.23), glow)

func _beam_material(color: Color, energy: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = Color("#b9f3ff")
    mat.emission_energy_multiplier = energy
    mat.render_priority = RENDER_ORDER.DEPTH_TESTED_EMISSIVE
    # StandardMaterial3D keeps depth testing enabled: the weapon cannot
    # shine through Bittaran's armor or SERA.
    return mat

func _cylinder_beam(node_name: String, radius: float,
        mat: StandardMaterial3D) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = 1.0
    shape.radial_segments = 12
    var part := MeshInstance3D.new()
    part.name = node_name
    part.mesh = shape
    part.material_override = mat
    part.rotation.x = -PI * 0.5
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    part.visible = false
    elevation.add_child(part)
    return part

func _build_beam() -> void:
    outer_beam = _cylinder_beam("RailgunLaserHalo", 0.35,
        _beam_material(Color(0.23, 0.75, 1.0, 0.32), 2.6))
    inner_beam = _cylinder_beam("RailgunLaserCore", 0.20,
        _beam_material(Color(0.94, 0.98, 1.0, 0.94), 3.6))
    # The Bittaran target root is scaled x2; convert desired WORLD range
    # back to the muzzle's local length, without doubling beam range.
    var local_length: float = (
        MAX_BEAM_RANGE_METERS / maxf(elevation.global_basis.z.length(), 0.01))
    beam_local_length = local_length
    for part in [outer_beam, inner_beam]:
        part.scale = Vector3(1.0, local_length, 1.0)
        part.position.z = MUZZLE_LOCAL_Z - local_length * 0.5

func _build_muzzle_flash() -> void:
    var sphere := SphereMesh.new()
    sphere.radius = 0.58
    sphere.height = 1.16
    sphere.radial_segments = 16
    sphere.rings = 8
    muzzle_flash = MeshInstance3D.new()
    muzzle_flash.name = "RailgunMuzzleFlash"
    muzzle_flash.mesh = sphere
    muzzle_flash.position.z = MUZZLE_LOCAL_Z
    muzzle_flash.material_override = _beam_material(
        Color(0.79, 0.96, 1.0, 0.90), 4.5)
    muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle_flash.visible = false
    elevation.add_child(muzzle_flash)

# Imported Ogg is preferred, but a GitSynced raw source can be decoded
# before Godot has created the .godot import cache on Android.
func _load_railgun_ogg(path: String) -> AudioStreamOggVorbis:
    var stream: AudioStreamOggVorbis = null
    if ResourceLoader.exists(path):
        stream = ResourceLoader.load(path) as AudioStreamOggVorbis
    if stream == null and FileAccess.file_exists(path):
        var source_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
        if not source_bytes.is_empty():
            stream = AudioStreamOggVorbis.load_from_buffer(source_bytes)
    if stream == null:
        var alternate: String = "user://" + path.get_file()
        if FileAccess.file_exists(alternate):
            stream = AudioStreamOggVorbis.load_from_file(alternate)
    if stream == null:
        push_warning("BITTARAN_RAILGUN_SFX_MISSING: " + path)
    return stream


func _build_railgun_audio() -> void:
    charge_audio = AudioStreamPlayer.new()
    charge_audio.name = "BittaranSphereChargeSound"
    charge_audio.stream = _load_railgun_ogg(CHARGE_AUDIO_PATH)
    charge_audio.volume_db = CHARGE_VOLUME_DB
    charge_audio.max_polyphony = 1
    add_child(charge_audio)
    laser_attack_audio = AudioStreamPlayer.new()
    laser_attack_audio.name = "BittaranLaserAttackSound"
    laser_attack_audio.stream = _load_railgun_ogg(LASER_ATTACK_AUDIO_PATH)
    laser_attack_audio.volume_db = LASER_ATTACK_VOLUME_DB
    laser_attack_audio.max_polyphony = 1
    add_child(laser_attack_audio)
    laser_loop_audio = AudioStreamPlayer.new()
    laser_loop_audio.name = "BittaranLaserSustainLoop"
    laser_loop_audio.stream = _load_railgun_ogg(LASER_LOOP_AUDIO_PATH)
    laser_loop_audio.volume_db = SILENT_AUDIO_DB
    laser_loop_audio.max_polyphony = 1
    if laser_loop_audio.stream is AudioStreamOggVorbis:
        var loop_source: AudioStreamOggVorbis = laser_loop_audio.stream
        loop_source.loop = true
        loop_source.loop_offset = 0.0
    add_child(laser_loop_audio)


func _tick_railgun_audio(delta: float, phase: int) -> void:
    if charge_audio == null or laser_attack_audio == null or (
            laser_loop_audio == null):
        return
    # Only the actual BLUE SPHERE starts the charge clip. The lamp fill
    # does not play it and sphere shrink does not trigger it again.
    if phase == Phase.FLASH and last_phase != Phase.FLASH and (
            charge_audio.stream != null):
        charge_audio.play()
        charge_starts += 1
    elif phase != Phase.FLASH and charge_audio.playing:
        charge_audio.stop()

    if phase == Phase.BEAM and last_phase != Phase.BEAM:
        if laser_attack_audio.stream != null:
            laser_attack_audio.play()
            laser_attack_starts += 1
        if laser_loop_audio.stream != null:
            laser_loop_audio.volume_db = SILENT_AUDIO_DB
            laser_loop_audio.play()
            laser_loop_starts += 1
        laser_loop_gain = 0.0
    if phase != Phase.BEAM and laser_attack_audio.playing:
        laser_attack_audio.stop()
    if laser_loop_audio.playing:
        var active: bool = phase == Phase.BEAM
        laser_loop_gain = move_toward(
            laser_loop_gain, (1.0 if active else 0.0),
            maxf(delta, 0.0) / (
                LASER_LOOP_FADE_IN_SECONDS if active
                else LASER_LOOP_FADE_OUT_SECONDS))
        laser_loop_audio.volume_db = (
            LASER_LOOP_VOLUME_DB +
            linear_to_db(maxf(laser_loop_gain, 0.0001)))
        if not active and laser_loop_gain <= 0.00001:
            laser_loop_audio.stop()
            laser_loop_audio.volume_db = SILENT_AUDIO_DB


func reset() -> void:
    if charge_audio != null:
        charge_audio.stop()
    if laser_attack_audio != null:
        laser_attack_audio.stop()
    if laser_loop_audio != null:
        laser_loop_audio.stop()
        laser_loop_audio.volume_db = SILENT_AUDIO_DB
    laser_loop_gain = 0.0
    elapsed = 0.0
    last_phase = Phase.WAIT
    return_yaw_origin = 0.0
    return_pitch_origin = 0.0
    return_world_yaw_origin = 0.0
    return_neutral_world_yaw = 0.0
    beam_hit_cooldown = 0.0
    beam_turn_rate_deg_per_sec = 0.0
    beam_ground_gap_meters = 0.0
    beam_ground_point = Vector3.ZERO
    aim_yaw = 0.0
    tracking_world_initialized = false
    tracked_world_yaw = 0.0
    idle_pose_blend = 1.0
    charge_entry_pose_offset = Quaternion.IDENTITY
    if elevation != null:
        elevation.rotation.x = 0.0
    if outer_beam != null:
        outer_beam.visible = false
    if inner_beam != null:
        inner_beam.visible = false
    if muzzle_flash != null:
        muzzle_flash.visible = false
    _show_charge(0.0)
    if energy_fx != null:
        energy_fx.call("reset_fx")
    _level_mount()

func _phase_at(t: float) -> int:
    if t < FLASH_START:
        return Phase.WAIT
    if t < FLASH_END:
        return Phase.FLASH
    if t < BEAM_END:
        return Phase.BEAM
    return Phase.RETURN

func _neutral_world_yaw() -> float:
    # The authored rig faces -Z at rest. Use only its horizontal heading,
    # never the animated Body bone's pitch or roll.
    if mount_rig == null:
        return 0.0
    var forward: Vector3 = -mount_rig.global_basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.000001:
        return 0.0
    return atan2(-forward.x, -forward.z)


func _sync_mount_position() -> void:
    # The chassis and authored BODY bones are finalized before the railgun
    # ticks. Update the pivot BEFORE calculating the desired world heading:
    # sampling the last frame's pivot creates a phantom chassis-dependent
    # aim correction even when the motor itself is world-locked.
    if mount_body != null:
        global_position = mount_body.to_global(MOUNT_LOCAL_OFFSET)


func _level_mount() -> void:
    if mount_body == null:
        return
    # The gun is still POSITIONALLY attached to Body (including animated
    # recoil/height), but its world orientation has exactly zero roll/pitch.
    # Reapply after each authored pose/IK tick to cancel inherited tilt.
    var scale_world: Vector3 = mount_body.global_basis.get_scale()
    var chassis_yaw: float = _neutral_world_yaw()
    # The top-level gun does not inherit the Body transform; resample
    # only its attachment POSITION after every authored/IK pose tick.
    _sync_mount_position()
    if chassis_axis != null:
        # The original upper shaft follows the chassis, not gun targeting.
        chassis_axis.global_basis = Basis(
            Quaternion(Vector3.UP, chassis_yaw)
        ).scaled(scale_world)
    var world_yaw: float = (
        tracked_world_yaw if tracking_world_initialized else chassis_yaw)
    var stabilized: Quaternion = Quaternion(Vector3.UP, world_yaw)
    var pose: Quaternion = stabilized
    var phase: int = _phase_at(elapsed)
    if phase == Phase.WAIT and idle_pose_blend > 0.0:
        # At rest, the entire cannon rides the animated BODY, not just
        # the chassis' horizontal heading. Blend only after return, when
        # independent world-yaw reacquisition is already completed.
        var body_pose: Quaternion = (
            mount_body.global_basis.orthonormalized().get_rotation_quaternion())
        pose = stabilized.slerp(body_pose, idle_pose_blend)
    elif phase == Phase.FLASH and (
            elapsed < FLASH_START + TRACK_BLEND_SECONDS):
        # The pose offset was captured ONCE at the instant guidance began.
        # New chassis turns cannot add to the railgun motor's world yaw.
        var ratio: float = clampf(
            (elapsed - FLASH_START) / TRACK_BLEND_SECONDS, 0.0, 1.0)
        var eased: float = ratio * ratio * (3.0 - 2.0 * ratio)
        pose = stabilized * charge_entry_pose_offset.slerp(
            Quaternion.IDENTITY, eased)
    global_basis = Basis(pose.normalized()).scaled(scale_world)


func _desired_player_world_angles(player_world: Vector3) -> Vector2:
    # The motor target is an ABSOLUTE world heading. Do not derive it by
    # adding the chassis yaw to a local yaw offset: that cancellation is
    # mathematically equivalent in normal cases, but unnecessarily couples
    # the targeting path to a turning chassis.
    var to_player: Vector3 = (
        player_world + Vector3.UP * 0.92 - global_position)
    if to_player.length_squared() <= 0.0001:
        return Vector2(
            tracked_world_yaw if tracking_world_initialized
            else _neutral_world_yaw() + aim_yaw,
            elevation.rotation.x)
    var desired_world_yaw: float = atan2(-to_player.x, -to_player.z)
    var flat: float = Vector2(to_player.x, to_player.z).length()
    var pitch: float = clampf(
        atan2(to_player.y, maxf(flat, 0.12)),
        deg_to_rad(-80.0), deg_to_rad(80.0))
    return Vector2(desired_world_yaw, pitch)


func _desired_player_angles(player_world: Vector3) -> Vector2:
    # Compatibility for diagnostics that report yaw relative to the chassis.
    # The motor itself uses _desired_player_world_angles exclusively.
    var world_angles: Vector2 = _desired_player_world_angles(player_world)
    return Vector2(angle_difference(
        _neutral_world_yaw(), world_angles.x), world_angles.y)


func _prefire_ease(t: float) -> float:
    # Acquisition begins with the blue sphere, not during the 10s fill.
    # Ease in only once; never restart when the sphere starts shrinking.
    var ratio: float = clampf(
        (t - TRACK_START_SECONDS) / TRACK_EASE_IN_SECONDS, 0.0, 1.0)
    return ratio * ratio * (3.0 - 2.0 * ratio)


func _tracking_turn_rate(player_world: Vector3,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS,
        run_speed_mps: float = RUN_REFERENCE_SPEED_MPS) -> float:
    # The pre-v478 tracking speed used for the laser baseline.
    # During the beam, ground-ray offset 0..1.5m eases toward this cap.
    # Use the actual part stats so upgrades do not break the contract.
    var to_player: Vector3 = player_world + Vector3.UP * 0.92 - global_position
    var flat: float = Vector2(to_player.x, to_player.z).length()
    var radius: float = maxf(flat, 1.0)
    var run_mps: float = maxf(run_speed_mps, 0.0)
    var boost_mps: float = maxf(boost_speed_mps, 0.0)
    var chase_mps: float = lerpf(
        run_mps, boost_mps, CHASE_SPEED_BLEND)
    return rad_to_deg(chase_mps / radius)


func _ground_ray_gap(player_world: Vector3) -> float:
    # The laser's visible axis projected to ground Y=0 at the player's
    # forward depth; do not mistake player height for a horizontal miss.
    # This also handles a nearly horizontal ray without distant-ground
    # intersection false positives.
    var origin: Vector3 = elevation.to_global(
        Vector3(0.0, 0.0, MUZZLE_LOCAL_Z))
    var forward: Vector3 = -elevation.global_basis.z.normalized()
    var ground_forward := Vector2(forward.x, forward.z)
    var ground_to_player := Vector2(
        player_world.x - origin.x, player_world.z - origin.z)
    var flat_squared: float = ground_forward.length_squared()
    var depth: float = 0.0
    if flat_squared > 0.00001:
        depth = clampf(ground_to_player.dot(ground_forward) /
            flat_squared, 0.0, MAX_BEAM_RANGE_METERS)
    var on_ray: Vector2 = Vector2(origin.x, origin.z) + (
        ground_forward * depth)
    beam_ground_point = Vector3(on_ray.x, 0.0, on_ray.y)
    beam_ground_gap_meters = ground_to_player.distance_to(
        on_ray - Vector2(origin.x, origin.z))
    return beam_ground_gap_meters


func _beam_catchup_weight(gap_meters: float) -> float:
    # 0m = beam 0.85x; 1.5m = full bounded RUN<chase<BOOST tracking.
    # Smoothstep has zero slope at both ends, avoiding a 1.5m snap.
    var t: float = clampf(
        gap_meters / BEAM_GROUND_GAP_METERS, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


func _beam_target_turn_rate(gap_meters: float, baseline: float,
        full_rate: float) -> float:
    # At 1.5m the motor reaches its fixed chase speed; it NEVER increases
    # beyond that threshold, even for instant teleports or a fast BOOST.
    # The selected chase speed is strictly between RUN and BOOST, so
    # RUN eventually enters the beam but BOOST can outrun it laterally.
    var weight: float = _beam_catchup_weight(gap_meters)
    return lerpf(baseline, maxf(full_rate, baseline), weight)


func _beam_turn_rate(delta: float, player_world: Vector3,
        base_rate: float) -> float:
    var baseline: float = base_rate * BEAM_ON_AXIS_SPEED_MULTIPLIER
    var gap: float = _ground_ray_gap(player_world)
    var target_rate: float = _beam_target_turn_rate(
        gap, baseline, base_rate)
    if beam_turn_rate_deg_per_sec <= 0.0:
        beam_turn_rate_deg_per_sec = baseline
    # Frame-rate-independent smoothing on the speed command.
    var blend: float = 1.0 - exp(
        -BEAM_CATCHUP_RESPONSE_PER_SECOND * maxf(delta, 0.0))
    # When the player suddenly moves farther away the angular cap may drop.
    # Clamp the *current* command as well, never only the target command.
    beam_turn_rate_deg_per_sec = minf(
        lerpf(beam_turn_rate_deg_per_sec, target_rate, blend), base_rate)
    return beam_turn_rate_deg_per_sec

func _track_player(delta: float, player_world: Vector3,
        acquisition_weight: float = 1.0,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS,
        run_speed_mps: float = RUN_REFERENCE_SPEED_MPS,
        fast_charge_tracking: bool = false,
        live_beam_tracking: bool = true) -> void:
    var desired: Vector2 = _desired_player_world_angles(player_world)
    var angular_rate: float = _tracking_turn_rate(
        player_world, boost_speed_mps, run_speed_mps)
    if not fast_charge_tracking:
        if live_beam_tracking:
            angular_rate = _beam_turn_rate(delta, player_world, angular_rate)
        else:
            # The sphere is shrinking but the laser is not firing:
            # use the 0.7x firing baseline WITHOUT ground-gap catch-up.
            angular_rate *= BEAM_TRACK_SPEED_MULTIPLIER
    var weight: float = clampf(acquisition_weight, 0.0, 1.0)
    var aim_filter: float = (
        BEAM_AIM_FILTER_PER_SECOND
        if live_beam_tracking and not fast_charge_tracking
        else TRACK_FILTER_PER_SECOND)
    var eased: float = 1.0 - exp(-aim_filter * delta)

    # Keep the turret yaw WORLD-locked even as the animated boss changes
    # heading; a body turn may not bypass the booster-based speed cap.
    var neutral_yaw: float = _neutral_world_yaw()
    if not tracking_world_initialized:
        tracked_world_yaw = neutral_yaw + aim_yaw
        tracking_world_initialized = true
    var angle_error := Vector2(
        angle_difference(tracked_world_yaw, desired.x),
        desired.y - elevation.rotation.x)
    # Constrain COMBINED yaw+pitch, not each independently, so diagonal
    # rotation cannot exceed the speed a BOOSTing player can escape.
    var actual: Vector2
    if fast_charge_tracking:
        # Pre-fire: no fixed angular cap, including against BOOST. Ramp up
        # responsiveness smoothly, then match the live target on every
        # frame, regardless of the player's angular speed or direction.
        var charge_response: float = 1.0 - exp(
            -CHARGE_TRACK_FILTER_PER_SECOND * delta * weight)
        actual = angle_error * (charge_response if weight < 1.0 else 1.0)
    else:
        # Once the beam appears, preserve the previous RUN-vs-BOOST
        # pursuit speed. A root rotation cannot circumvent this cap.
        var requested: Vector2 = angle_error * eased
        var allowed_radians: float = deg_to_rad(
            angular_rate * weight) * delta
        actual = requested.limit_length(allowed_radians)
    tracked_world_yaw += actual.x
    aim_yaw = angle_difference(neutral_yaw, tracked_world_yaw)
    elevation.rotation.x = clampf(
        elevation.rotation.x + actual.y,
        deg_to_rad(-80.0), deg_to_rad(80.0))

func _show_charge(progress: float) -> void:
    for index in range(charge_materials.size()):
        var lit: float = clampf(progress * 3.0 - float(index % 3), 0.0, 1.0)
        var mat: StandardMaterial3D = charge_materials[index]
        mat.albedo_color = Color("#223449").lerp(Color("#c8faff"), lit)
        mat.emission = Color("#182d47").lerp(Color("#a8eeff"), lit)
        mat.emission_energy_multiplier = 0.22 + lit * 3.8

func _beam_overlaps_player(player_world: Vector3) -> bool:
    var origin: Vector3 = elevation.to_global(
        Vector3(0.0, 0.0, MUZZLE_LOCAL_Z))
    var forward: Vector3 = -elevation.global_basis.z.normalized()
    var toward: Vector3 = player_world + Vector3.UP * 0.92 - origin
    var along: float = toward.dot(forward)
    if along < 0.0 or along > MAX_BEAM_RANGE_METERS:
        return false
    var closest: Vector3 = origin + forward * along
    var distance_squared: float = (
        (player_world + Vector3.UP * 0.92 - closest).length_squared())
    return distance_squared <= pow(
        BEAM_RADIUS_METERS + PLAYER_HIT_RADIUS_METERS, 2.0)

## True for any real beam overlap when its 0.20s repeat-hit timer permits.
## There is no per-shot maximum hit count.
func advance(delta: float, player_world: Vector3, active: bool,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS,
        run_speed_mps: float = RUN_REFERENCE_SPEED_MPS) -> bool:
    if not ready_to_fire or not active:
        reset()
        return false
    # After the boss pose/IK tick, use the CURRENT mount for both pursuit
    # and ray-gap calculations, not the previous physics-frame position.
    _sync_mount_position()
    var step: float = maxf(delta, 0.0)
    elapsed = fposmod(elapsed + step, PERIOD_SECONDS)
    var phase: int = _phase_at(elapsed)
    if phase != Phase.BEAM:
        # The next shot begins with a fresh per-contact interval and speed.
        beam_hit_cooldown = 0.0
        beam_turn_rate_deg_per_sec = 0.0
        beam_ground_gap_meters = 0.0
    else:
        beam_hit_cooldown = maxf(0.0, beam_hit_cooldown - step)
    if phase == Phase.FLASH and last_phase == Phase.WAIT:
        # Freeze the idle Body-to-world orientation at acquisition start.
        # This is a visual pose unwind, never live chassis rotation mixed
        # into the turret's independent tracked yaw.
        var neutral_pose: Quaternion = Quaternion(
            Vector3.UP, _neutral_world_yaw())
        var idle_world_pose: Quaternion = (
            global_basis.orthonormalized().get_rotation_quaternion())
        charge_entry_pose_offset = (
            neutral_pose.inverse() * idle_world_pose).normalized()
        idle_pose_blend = 0.0
    if phase == Phase.RETURN and last_phase != Phase.RETURN:
        # Keep the FIRST post-beam orientation and neutral destination in
        # WORLD space. Returning relative yaw to zero would add/subtract
        # chassis rotation on every frame (and create a speed spike).
        return_yaw_origin = aim_yaw
        return_pitch_origin = elevation.rotation.x
        return_world_yaw_origin = (
            tracked_world_yaw if tracking_world_initialized
            else _neutral_world_yaw() + aim_yaw)
        return_neutral_world_yaw = _neutral_world_yaw()
        tracking_world_initialized = true
    if phase == Phase.WAIT:
        # Once the world-space return has ended, smoothly rejoin a chassis
        # that turned during the 0.7s release. Never snap at the cycle
        # boundary, nor add its rotation to the independent turret motor.
        if tracking_world_initialized:
            var neutral_yaw: float = _neutral_world_yaw()
            tracked_world_yaw = rotate_toward(
                tracked_world_yaw, neutral_yaw,
                deg_to_rad(PARK_REACQUIRE_DEG_PER_SECOND) * step)
            aim_yaw = angle_difference(neutral_yaw, tracked_world_yaw)
            if absf(aim_yaw) <= 0.0005:
                tracking_world_initialized = false
                aim_yaw = 0.0
        else:
            aim_yaw = 0.0
        if not tracking_world_initialized:
            idle_pose_blend = move_toward(
                idle_pose_blend, 1.0,
                step / IDLE_POSE_REJOIN_SECONDS)
        elevation.rotation.x = 0.0
    elif phase == Phase.FLASH:
        if elapsed < FLASH_SHRINK_START:
            # The sphere is still growing/full: unlimited tracking after
            # its initial 0.7s smooth acquisition.
            _track_player(step, player_world, _prefire_ease(elapsed),
                boost_speed_mps, run_speed_mps, true)
        else:
            # Shrink begins at t=11: immediately cap the slew at the
            # same 0.7x baseline used by the firing beam. Do NOT run
            # laser ground-gap catch-up before laser emission.
            _track_player(step, player_world, 1.0,
                boost_speed_mps, run_speed_mps, false, false)
    elif phase == Phase.BEAM:
        # Firing begins at 0.85x on-axis. The 0..1.5m smoothstep
        # blends up to the same fixed RUN<chase<BOOST cap, then plateaus.
        _track_player(step, player_world, 1.0,
            boost_speed_mps, run_speed_mps)
    elif phase == Phase.RETURN:
        var ratio: float = clampf(
            (elapsed - BEAM_END) / RETURN_SECONDS, 0.0, 1.0)
        var smooth: float = ratio * ratio * (3.0 - 2.0 * ratio)
        tracked_world_yaw = lerp_angle(
            return_world_yaw_origin, return_neutral_world_yaw, smooth)
        # aim_yaw remains diagnostic/local; it does not drive gun rotation.
        aim_yaw = angle_difference(
            _neutral_world_yaw(), tracked_world_yaw)
        elevation.rotation.x = lerpf(return_pitch_origin, 0.0, smooth)
    # Charge lamps fill while the gun is stationary for 10s;
    # they remain full during the 2s tracking orb.
    _show_charge(clampf(elapsed / WAIT_SECONDS, 0.0, 1.0)
        if phase == Phase.WAIT or phase == Phase.FLASH else 0.0)
    _level_mount()
    var firing: bool = phase == Phase.BEAM
    outer_beam.visible = firing
    inner_beam.visible = firing
    if phase == Phase.FLASH:
        # Appear exactly at 10s, grow for 0.2s and shrink over the
        # final second; BEAM starts at 12s with no gap or delay.
        var age: float = elapsed - FLASH_START
        var grow: float = clampf(age / FLASH_GROW_SECONDS, 0.0, 1.0)
        var grow_eased: float = grow * grow * (3.0 - 2.0 * grow)
        var end_remaining: float = FLASH_END - elapsed
        var shrink: float = clampf(
            end_remaining / FLASH_SHRINK_SECONDS, 0.0, 1.0)
        var shrink_eased: float = shrink * shrink * (3.0 - 2.0 * shrink)
        muzzle_flash.scale = Vector3.ONE * maxf(
            0.01, (0.18 + 0.82 * grow_eased) * shrink_eased)
        muzzle_flash.visible = true
    else:
        muzzle_flash.visible = false
    # Only the visual FX layer pulses; collision, beam axis and authored
    # Blockbench rail mesh remain intact. Reset hides every extra effect.
    if energy_fx != null:
        energy_fx.call("tick", elapsed, phase == Phase.FLASH,
            firing, muzzle_flash.scale.x)
    if firing:
        var pulse: float = 1.0 + 0.07 * sin(elapsed * 43.0)
        outer_beam.scale.x = pulse
        outer_beam.scale.z = pulse
        inner_beam.scale.x = 1.0 + 0.035 * sin(elapsed * 57.0)
        inner_beam.scale.z = inner_beam.scale.x
    _tick_railgun_audio(step, phase)
    last_phase = phase
    if firing and beam_hit_cooldown <= 0.0 and (
            _beam_overlaps_player(player_world)):
        # No maximum count per beam: contact may hit repeatedly if SERA
        # remains in or re-enters the beam after the next pulse interval.
        beam_hit_cooldown = BEAM_HIT_INTERVAL_SECONDS
        return true
    return false
