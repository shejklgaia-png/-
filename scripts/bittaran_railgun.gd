extends Node3D
## Bittaran's dorsal railgun. Its azimuth/elevation and ten-second fire
## clock are separate from locomotion, leg attacks, source clips and HEAD.
## The Body bone transports the mount; its pitch/roll never tilts the gun.
## WORLD yaw plus WORLD-relative elevation are the only allowed rotations.
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
const RailgunFX = preload("res://scripts/bittaran_railgun_fx.gd")

const PERIOD_SECONDS: float = 10.0
const BEAM_SECONDS: float = 2.0
# The first laser frame locks onto the player EXACTLY, so applying
# damage on that very same frame makes an otherwise slow sweep impossible
# to avoid: the guaranteed hit also cancels BOOST via damage reaction.
# Show the full beam immediately, but arm its hit test only after SERA
# has had a short chance to move sideways/STEP out of the new ray.
const BEAM_DAMAGE_ARM_SECONDS: float = 0.40
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
const TRACK_EASE_IN_SECONDS: float = FLASH_SECONDS
# Deliberately slower than the standard 6.09375 m/s boost crossing a
# ~8 m radius (43.6 degrees/s). A boost strafe can outrun the beam.
# The two-second spherical charge also eases target acquisition from a
# stationary neutral mount. Before fire it can still catch a boosting SERA;
# only the active laser is deliberately slow enough to dodge.
const PRE_FIRE_YAW_SPEED: float = 504.0
const PRE_FIRE_PITCH_SPEED: float = 403.2
const PRE_FIRE_FILTER_PER_SECOND: float = 24.0
const TRACK_YAW_SPEED: float = 15.12
const TRACK_PITCH_SPEED: float = 11.34
const TRACK_FILTER_PER_SECOND: float = 6.0
# All three charge lamps are full at FLASH_START; only THEN may aim.
const TRACK_START_SECONDS: float = FLASH_START
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
    # 2s of smoothstep from ZERO angular velocity to full catch-up speed.
    # No sudden jump as the blue spherical glow first appears.
    var ratio: float = clampf(
        (t - TRACK_START_SECONDS) / TRACK_EASE_IN_SECONDS, 0.0, 1.0)
    return ratio * ratio * (3.0 - 2.0 * ratio)


func _track_player(delta: float, player_world: Vector3,
        fast_acquisition: bool = false, acquisition_weight: float = 1.0) -> void:
    var desired: Vector2 = _desired_player_angles(player_world)
    var yaw_rate: float = (
        PRE_FIRE_YAW_SPEED if fast_acquisition else TRACK_YAW_SPEED)
    var pitch_rate: float = (
        PRE_FIRE_PITCH_SPEED if fast_acquisition else TRACK_PITCH_SPEED)
    var filter_rate: float = (
        PRE_FIRE_FILTER_PER_SECOND if fast_acquisition
        else TRACK_FILTER_PER_SECOND)
    var weight: float = clampf(acquisition_weight, 0.0, 1.0)
    var eased: float = 1.0 - exp(-filter_rate * delta * weight)
    var yaw_step: float = angle_difference(aim_yaw, desired.x) * eased
    aim_yaw += clampf(yaw_step,
        -deg_to_rad(yaw_rate * weight) * delta,
        deg_to_rad(yaw_rate * weight) * delta)
    var pitch_step: float = (desired.y - elevation.rotation.x) * eased
    elevation.rotation.x = clampf(
        elevation.rotation.x + clampf(pitch_step,
            -deg_to_rad(pitch_rate * weight) * delta,
            deg_to_rad(pitch_rate * weight) * delta),
        deg_to_rad(-80.0), deg_to_rad(80.0))


func _lock_player_at_fire(player_world: Vector3) -> void:
    # The charge phase already brought the cannon to the predicted target
    # smoothly. Resolve remaining sub-frame angular error at the shot
    # boundary so the FIRST laser sample points exactly at the real SERA,
    # including last-moment BOOST motion. Never call this again in BEAM.
    var target: Vector2 = _desired_player_angles(player_world)
    aim_yaw = target.x
    elevation.rotation.x = target.y

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

## True only on a damage pulse; the battle scene owns the existing
## player guard/HP/knockback response. Target KO/respawn calls reset().
func advance(delta: float, player_world: Vector3, active: bool) -> bool:
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
        var ratio: float = clampf(
            (elapsed - BEAM_SECONDS - POST_FIRE_HOLD_SECONDS)
            / RETURN_SECONDS, 0.0, 1.0)
        var smooth: float = ratio * ratio * (3.0 - 2.0 * ratio)
        aim_yaw = lerp_angle(return_yaw_origin, 0.0, smooth)
        elevation.rotation.x = lerpf(return_pitch_origin, 0.0, smooth)
    elif phase == Phase.CHARGE:
        # Unfilled charge bars mean no player acquisition. Keep the gun
        # exactly at the rig-relative neutral angle despite target motion.
        aim_yaw = 0.0
        elevation.rotation.x = 0.0
    elif phase == Phase.FLASH:
        # Blue sphere and gradual tracking last the full 2s. The sphere
        # shrinks for its final 1s, then vanishes before the lock pause.
        _track_player(step, player_world, true, _prefire_ease(elapsed))
    elif phase == Phase.LOCK_HOLD:
        # The target has been acquired; delay firing for a visible 0.5s.
        # Keep the turret actively aligned to a BOOSTing player rather
        # than freezing on an outdated position during that pause.
        if last_phase != Phase.LOCK_HOLD:
            _lock_player_at_fire(player_world)
        else:
            _track_player(step, player_world, true)
    elif phase == Phase.BEAM:
        if last_phase != Phase.BEAM:
            # Match the live player position precisely on the FIRST beam
            # frame. Afterwards the aim is intentionally dodgeable.
            _lock_player_at_fire(player_world)
        else:
            _track_player(step, player_world)
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
