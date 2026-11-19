extends Node3D
## Bittaran's dorsal railgun. Its azimuth/elevation and ten-second fire
## clock are separate from locomotion, leg attacks, source clips and HEAD.
## The Body bone transports the mount; its pitch/roll never tilts the gun.
## WORLD yaw plus WORLD-relative elevation are the only allowed rotations.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const RailgunFX = preload("res://scripts/bittaran_railgun_fx.gd")

const PERIOD_SECONDS: float = 10.0
const BEAM_SECONDS: float = 2.0
# The laser is visible immediately, while its 0.65s arming window
# permits a touch-confirmed/accelerating BOOST to exit the initial ray.
const BEAM_DAMAGE_ARM_SECONDS: float = 0.65
const POST_FIRE_HOLD_SECONDS: float = 0.4
const RETURN_SECONDS: float = 0.8
const CHARGE_START: float = BEAM_SECONDS + POST_FIRE_HOLD_SECONDS + RETURN_SECONDS
# Full charge: two seconds of spherical aiming + a 0.5s confirmed
# target-acquired pause. Start the sphere earlier to retain 10s fire rate.
const FINAL_LOCK_HOLD_SECONDS: float = 0.5
const FLASH_SECONDS: float = 2.0
const FLASH_START: float = PERIOD_SECONDS - (
    FLASH_SECONDS + FINAL_LOCK_HOLD_SECONDS)
const FLASH_END: float = FLASH_START + FLASH_SECONDS
const FLASH_GROW_SECONDS: float = 0.2
const FLASH_SHRINK_SECONDS: float = 1.0
# Start one continuous, smooth turret tracking phase as soon as charge
# begins, not when the blue orb appears. No speed mode switch or snap
# at full charge, lock-hold or BEAM.
const TRACK_EASE_IN_SECONDS: float = 2.0
const TRACK_YAW_SPEED: float = 15.12
const TRACK_PITCH_SPEED: float = 11.34
const TRACK_FILTER_PER_SECOND: float = 6.0
const PRE_FIRE_YAW_SPEED: float = TRACK_YAW_SPEED
const PRE_FIRE_PITCH_SPEED: float = TRACK_PITCH_SPEED
const PRE_FIRE_FILTER_PER_SECOND: float = TRACK_FILTER_PER_SECOND
const BOOST_REFERENCE_SPEED_MPS: float = 6.09375
# At ANY distance keep target slew beneath half of SERA's actual BOOST
# angular speed; fixed deg/s caps alone fail at long range.
const BOOST_TURN_FRACTION: float = 0.50
const TRACK_START_SECONDS: float = CHARGE_START
const MAX_BEAM_RANGE_METERS: float = 45.0
const BEAM_RADIUS_METERS: float = 0.70
const PLAYER_HIT_RADIUS_METERS: float = 0.48
const BEAM_DAMAGE_TICK_SECONDS: float = 0.5
const MUZZLE_LOCAL_Z: float = -1.53
# Two authored rails, not the body, pedestal, head or either leg.
# Original mesh UUIDs, geometry, materials and Blockbench source are retained.
const RAIL_MESH_UUIDS = [
    "2ce4b10f-8a6d-72de-8b79-763d67e41b78",
    "3e2ee103-881b-8bc0-edc1-ea9e396268e9",
]

enum Phase { BEAM, HOLD, RETURN, CHARGE, FLASH, LOCK_HOLD }
var elevation: Node3D
var outer_beam: MeshInstance3D
var inner_beam: MeshInstance3D
var muzzle_flash: MeshInstance3D
var energy_fx: Node3D
var beam_local_length: float = 1.0
var charge_materials: Array[StandardMaterial3D] = []
var elapsed: float = CHARGE_START
var last_phase: int = Phase.CHARGE
var return_yaw_origin: float = 0.0
var return_pitch_origin: float = 0.0
var hit_cooldown: float = 0.0
var ready_to_fire: bool = false
var mount_body: Node3D
var mount_rig: Node3D
var aim_yaw: float = 0.0
var tracked_world_yaw: float = 0.0
var tracking_world_initialized: bool = false

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
    position = Vector3(-0.0435, 2.493, -0.4205)
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
    elevation = Node3D.new()
    elevation.name = "RailgunElevation"
    elevation.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
    add_child(elevation)
    # Preserve the authored mesh's WORLD transform while changing its parent.
    # The animated Body is still the base; only the two rails pitch and turn.
    var mesh_bind_positions: Dictionary = rig.get("mesh_base_positions_by_uuid")
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

func reset() -> void:
    elapsed = CHARGE_START
    last_phase = Phase.CHARGE
    return_yaw_origin = 0.0
    return_pitch_origin = 0.0
    hit_cooldown = 0.0
    aim_yaw = 0.0
    tracking_world_initialized = false
    tracked_world_yaw = 0.0
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
    if t < BEAM_SECONDS:
        return Phase.BEAM
    if t < BEAM_SECONDS + POST_FIRE_HOLD_SECONDS:
        return Phase.HOLD
    if t < CHARGE_START:
        return Phase.RETURN
    if t < FLASH_START:
        return Phase.CHARGE
    if t < FLASH_END:
        return Phase.FLASH
    return Phase.LOCK_HOLD

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


func _level_mount() -> void:
    if mount_body == null:
        return
    # The gun is still POSITIONALLY attached to Body (including animated
    # recoil/height), but its world orientation has exactly zero roll/pitch.
    # Reapply after each authored pose/IK tick to cancel inherited tilt.
    var scale_world: Vector3 = mount_body.global_basis.get_scale()
    global_basis = Basis(
        Quaternion(Vector3.UP, _neutral_world_yaw() + aim_yaw)
    ).scaled(scale_world)


func _desired_player_angles(player_world: Vector3) -> Vector2:
    # World-UP heading remains independent of the animated Body pitch/roll.
    var to_player: Vector3 = (
        player_world + Vector3.UP * 0.92 - global_position)
    if to_player.length_squared() <= 0.0001:
        return Vector2(aim_yaw, elevation.rotation.x)
    var desired_world_yaw: float = atan2(-to_player.x, -to_player.z)
    var relative_yaw: float = angle_difference(
        _neutral_world_yaw(), desired_world_yaw)
    var flat: float = Vector2(to_player.x, to_player.z).length()
    var pitch: float = clampf(
        atan2(to_player.y, maxf(flat, 0.12)),
        deg_to_rad(-80.0), deg_to_rad(80.0))
    return Vector2(relative_yaw, pitch)


func _prefire_ease(t: float) -> float:
    # Continuous 2s smoothstep from initial CHARGE, then full allowed
    # (still boost-evadable) rate through FLASH, LOCK_HOLD and BEAM.
    var ratio: float = clampf(
        (t - TRACK_START_SECONDS) / TRACK_EASE_IN_SECONDS, 0.0, 1.0)
    return ratio * ratio * (3.0 - 2.0 * ratio)


func _boost_safe_turn_rate(player_world: Vector3,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS) -> float:
    # Convert real world-space transverse BOOST displacement into the
    # maximum angular rate a dodging SERA can make from this cannon.
    var to_player: Vector3 = player_world + Vector3.UP * 0.92 - global_position
    var planar_distance: float = Vector2(to_player.x, to_player.z).length()
    var radius: float = maxf(planar_distance, 1.0)
    return rad_to_deg(maxf(0.0, boost_speed_mps) / radius) * (
        BOOST_TURN_FRACTION)


func _track_player(delta: float, player_world: Vector3,
        acquisition_weight: float = 1.0,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS) -> void:
    var desired: Vector2 = _desired_player_angles(player_world)
    var rate_limit: float = _boost_safe_turn_rate(
        player_world, boost_speed_mps)
    var yaw_rate: float = minf(TRACK_YAW_SPEED, rate_limit)
    var pitch_rate: float = minf(TRACK_PITCH_SPEED, rate_limit)
    var weight: float = clampf(acquisition_weight, 0.0, 1.0)
    var eased: float = 1.0 - exp(-TRACK_FILTER_PER_SECOND * delta * weight)

    # Measure rotation in WORLD space: if Bittaran itself turns, applying
    # the cap to the *relative* yaw lets the body rotate the cannon for
    # free, potentially faster than BOOST. Keep the world aim independent
    # from changing Body/root yaw for the entire charge-to-beam phase.
    var neutral_yaw: float = _neutral_world_yaw()
    if not tracking_world_initialized:
        tracked_world_yaw = neutral_yaw + aim_yaw
        tracking_world_initialized = true
    var desired_world_yaw: float = neutral_yaw + desired.x
    var world_step: float = angle_difference(
        tracked_world_yaw, desired_world_yaw) * eased
    tracked_world_yaw += clampf(world_step,
        -deg_to_rad(yaw_rate * weight) * delta,
        deg_to_rad(yaw_rate * weight) * delta)
    aim_yaw = angle_difference(neutral_yaw, tracked_world_yaw)

    var pitch_step: float = (desired.y - elevation.rotation.x) * eased
    elevation.rotation.x = clampf(
        elevation.rotation.x + clampf(pitch_step,
            -deg_to_rad(pitch_rate * weight) * delta,
            deg_to_rad(pitch_rate * weight) * delta),
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

## True only on a damage pulse. The battle scene applies HP/guard without
## laser-hit knockback so that BOOST remains usable during the entire beam.
func advance(delta: float, player_world: Vector3, active: bool,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS) -> bool:
    if not ready_to_fire or not active:
        reset()
        return false
    var step: float = maxf(delta, 0.0)
    elapsed = fposmod(elapsed + step, PERIOD_SECONDS)
    hit_cooldown = maxf(0.0, hit_cooldown - step)
    var phase: int = _phase_at(elapsed)
    if phase == Phase.RETURN and last_phase != Phase.RETURN:
        return_yaw_origin = aim_yaw
        return_pitch_origin = elevation.rotation.x
    if phase == Phase.RETURN:
        tracking_world_initialized = false
        var ratio: float = clampf(
            (elapsed - BEAM_SECONDS - POST_FIRE_HOLD_SECONDS)
            / RETURN_SECONDS, 0.0, 1.0)
        var smooth: float = ratio * ratio * (3.0 - 2.0 * ratio)
        aim_yaw = lerp_angle(return_yaw_origin, 0.0, smooth)
        elevation.rotation.x = lerpf(return_pitch_origin, 0.0, smooth)
    elif phase == Phase.CHARGE or phase == Phase.FLASH or (
            phase == Phase.LOCK_HOLD) or phase == Phase.BEAM:
        # One uninterrupted, world-locked, boost-evadable aim controller
        # through CHARGE -> blue FLASH -> 0.5s LOCK_HOLD -> BEAM.
        # No instantaneous relock or tracking-speed jump at transitions.
        _track_player(step, player_world, _prefire_ease(elapsed)
            if phase == Phase.CHARGE else 1.0, boost_speed_mps)
    # Hold the FINAL firing orientation for 0.4 seconds after firing,
    # ease home over 0.8 seconds, then remain neutral while recharging.
    _show_charge(clampf(
        (elapsed - CHARGE_START) / (FLASH_START - CHARGE_START),
        0.0, 1.0) if phase == Phase.CHARGE or (
            phase == Phase.FLASH or phase == Phase.LOCK_HOLD) else 0.0)
    _level_mount()
    var firing: bool = phase == Phase.BEAM
    outer_beam.visible = firing
    inner_beam.visible = firing
    if phase == Phase.FLASH:
        # Remain visible for the 2s charge, rising during the first
        # 0.2s and shrinking over the last 1s. The resulting 0.5s
        # pause occurs AFTER this sphere disappears, BEFORE the beam.
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
    last_phase = phase
    if firing and elapsed >= BEAM_DAMAGE_ARM_SECONDS and (
            hit_cooldown <= 0.0) and _beam_overlaps_player(player_world):
        # The launch frame is never an unavoidable registered hit. After
        # the startup grace, damage still uses the original narrow
        # world-space beam/player intersection and 0.5s repeat cadence.
        hit_cooldown = BEAM_DAMAGE_TICK_SECONDS
        return true
    return false
