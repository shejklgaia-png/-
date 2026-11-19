extends Node3D
## Bittaran's dorsal railgun. Its 10-second idle charge and separate
## sphere/beam/return are independent of locomotion, source clips and HEAD.
## The Body bone transports the mount; its pitch/roll never tilts the gun.
## WORLD yaw plus WORLD-relative elevation are the only allowed rotations.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const RailgunFX = preload("res://scripts/bittaran_railgun_fx.gd")

# Track the player once per charge cycle from the start of charging.
# The 0.7s eased-in acquisition is speed-unrestricted; keep that precise
# tracking until the blue sphere finishes shrinking at the 12s beam start.
# Only the firing beam uses the existing RUN/BOOST-aware angular limit.
# After 2s of firing, return smoothly to neutral in precisely 0.7s.
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
# Charge acquisition begins once at t=0 with a 0.7s smooth acceleration.
# The instantaneous target solve AFTER the ramp has no speed ceiling.
# After firing, the existing slow tracking and 0.7s neutral return remain.
const TRACK_BLEND_SECONDS: float = 0.7
const TRACK_EASE_IN_SECONDS: float = TRACK_BLEND_SECONDS
const TRACK_START_SECONDS: float = 0.0
const CHARGE_TRACK_FILTER_PER_SECOND: float = 30.0
const TRACK_FILTER_PER_SECOND: float = 10.0
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
# Two authored rails, not the body, pedestal, head or either leg.
# Original mesh UUIDs, geometry, materials and Blockbench source are retained.
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
var beam_local_length: float = 1.0
var charge_materials: Array[StandardMaterial3D] = []
var elapsed: float = 0.0
var last_phase: int = Phase.WAIT
var return_yaw_origin: float = 0.0
var return_pitch_origin: float = 0.0
# Exactly one registered damage event per visible laser shot. A real
# beam/player overlap is required for that one event; further overlaps
# while the laser remains visible must never cause follow-up hits.
var beam_hit_registered: bool = false
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
    elapsed = 0.0
    last_phase = Phase.WAIT
    return_yaw_origin = 0.0
    return_pitch_origin = 0.0
    beam_hit_registered = false
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
    # Charge begins tracking with eased acceleration. The acquisition
    # ramp happens only once per charge cycle, never at sphere/beam changes.
    var ratio: float = clampf(
        (t - TRACK_START_SECONDS) / TRACK_EASE_IN_SECONDS, 0.0, 1.0)
    return ratio * ratio * (3.0 - 2.0 * ratio)


func _tracking_turn_rate(player_world: Vector3,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS,
        run_speed_mps: float = RUN_REFERENCE_SPEED_MPS) -> float:
    # The same speed rule applies to sphere and beam. A RUN-speed orbit
    # must remain trackable; a sustained BOOST-speed orbit must escape.
    # Use the actual part stats so upgrades do not break the contract.
    var to_player: Vector3 = player_world + Vector3.UP * 0.92 - global_position
    var flat: float = Vector2(to_player.x, to_player.z).length()
    var radius: float = maxf(flat, 1.0)
    var run_mps: float = maxf(run_speed_mps, 0.0)
    var boost_mps: float = maxf(boost_speed_mps, 0.0)
    var chase_mps: float = lerpf(
        run_mps, boost_mps, CHASE_SPEED_BLEND)
    return rad_to_deg(chase_mps / radius)


func _track_player(delta: float, player_world: Vector3,
        acquisition_weight: float = 1.0,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS,
        run_speed_mps: float = RUN_REFERENCE_SPEED_MPS,
        fast_charge_tracking: bool = false) -> void:
    var desired: Vector2 = _desired_player_angles(player_world)
    var angular_rate: float = _tracking_turn_rate(
        player_world, boost_speed_mps, run_speed_mps)
    var weight: float = clampf(acquisition_weight, 0.0, 1.0)
    var eased: float = 1.0 - exp(-TRACK_FILTER_PER_SECOND * delta)

    # Keep the turret yaw WORLD-locked even as the animated boss changes
    # heading; a body turn may not bypass the booster-based speed cap.
    var neutral_yaw: float = _neutral_world_yaw()
    if not tracking_world_initialized:
        tracked_world_yaw = neutral_yaw + aim_yaw
        tracking_world_initialized = true
    var desired_world_yaw: float = neutral_yaw + desired.x
    var angle_error := Vector2(
        angle_difference(tracked_world_yaw, desired_world_yaw),
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

## True only for the FIRST physically registered hit in this laser shot.
## Subsequent beam intersections must not damage or restart knockback.
func advance(delta: float, player_world: Vector3, active: bool,
        boost_speed_mps: float = BOOST_REFERENCE_SPEED_MPS,
        run_speed_mps: float = RUN_REFERENCE_SPEED_MPS) -> bool:
    if not ready_to_fire or not active:
        reset()
        return false
    var step: float = maxf(delta, 0.0)
    elapsed = fposmod(elapsed + step, PERIOD_SECONDS)
    var phase: int = _phase_at(elapsed)
    if phase != Phase.BEAM:
        # Re-arm only after the current beam actually ends. A new shot
        # needs a fresh physical collision to cause its one hit.
        beam_hit_registered = false
    if phase == Phase.RETURN and last_phase != Phase.RETURN:
        # Start return on the FIRST frame after beam ends (no hold).
        return_yaw_origin = aim_yaw
        return_pitch_origin = elevation.rotation.x
    if phase == Phase.WAIT or phase == Phase.FLASH:
        # One speed-unrestricted acquisition from charge start until
        # the sphere is fully gone. Neither t=10 nor sphere shrink
        # restarts the eased entry or lowers the tracking rate.
        _track_player(step, player_world, _prefire_ease(elapsed),
            boost_speed_mps, run_speed_mps, true)
    elif phase == Phase.BEAM:
        # Only while firing: return immediately to the existing angular
        # slew limit so BOOST can outrun the active laser.
        _track_player(step, player_world, 1.0,
            boost_speed_mps, run_speed_mps)
    elif phase == Phase.RETURN:
        tracking_world_initialized = false
        var ratio: float = clampf(
            (elapsed - BEAM_END) / RETURN_SECONDS, 0.0, 1.0)
        var smooth: float = ratio * ratio * (3.0 - 2.0 * ratio)
        aim_yaw = lerp_angle(return_yaw_origin, 0.0, smooth)
        elevation.rotation.x = lerpf(return_pitch_origin, 0.0, smooth)
    # All three charge bars fill over the 10s tracking charge
    # and stay full during the 2s blue orb. Fire directly after the orb.
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
    last_phase = phase
    if firing and not beam_hit_registered and (
            _beam_overlaps_player(player_world)):
        # The FIRST real overlap causes knockback. All later samples in
        # this same 2-second beam are ignored (even if it intersects again).
        beam_hit_registered = true
        return true
    return false
