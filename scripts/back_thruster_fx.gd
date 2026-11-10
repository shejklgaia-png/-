extends Node3D
## v219: decagonal hollow back-thruster exhaust with wobbling emissive walls.
## Authored nozzle group provides the origin; direction is limited relative to
## its actual animated/rotated Blockbench pivot. Separate from SLIDE mode.
const FLAME_SHADER = preload("res://shaders/back_thruster.gdshader")
const RIBBON_SHADER = preload("res://shaders/back_thruster_trail.gdshader")
const YAW_LIMIT_RADIANS: float = PI * 80.0 / 180.0
const PITCH_UP_LIMIT_RADIANS: float = PI * 1.0 / 180.0
const PITCH_DOWN_LIMIT_RADIANS: float = PI * 90.0 / 180.0
const TURN_TIME: float = 0.075
# Keep melee nozzles inside the outward hemisphere of the animated Chest.
# Using a positive dot leaves clearance for the 10-sided flame cross-section.
const MELEE_TORSO_CLEARANCE_DOT: float = 0.55
# v224: during normal melee the animated Chest may yaw far from the
# player root. Keep the physical nozzle near its authored back mount while
# retaining limited steering for target homing (BOOST/STEP are unchanged).
const MELEE_YAW_LIMIT_RADIANS: float = PI * 20.0 / 180.0
const MELEE_PITCH_DOWN_LIMIT_RADIANS: float = PI * 35.0 / 180.0
const EXHAUST_LENGTH: float = 0.65
# Vertex deformation needs intermediate rings: two end-caps cannot form a
# rapid flare close to the nozzle, only a linearly tapered giant triangle.
const EXHAUST_AXIAL_SEGMENTS: int = 12
# A 10-sided cross-section softens the outline without adding particles.
const EXHAUST_RADIAL_SIDES: int = 10
# Acceleration flares to 15x within the near-nozzle quarter of the jet.
const BURST_RISE_SECONDS: float = 0.05
const BURST_FALL_SECONDS: float = 0.18
const BURST_TOTAL_SECONDS: float = BURST_RISE_SECONDS + BURST_FALL_SECONDS
# During normal melee, make the *ordinary* narrow jet long enough to clear
# SERA's animated back/arms; do not fire the 15x acceleration burst again.
const MELEE_SUSTAIN_RESPONSE_SECONDS: float = 0.06
# v223: a world-fixed, camera-facing ribbon behind each moving nozzle.
# Past vertices never inherit the animated Chest/nozzle transform.
const RIBBON_LIFETIME_SECONDS: float = 0.34
const RIBBON_SAMPLE_INTERVAL_SECONDS: float = 0.026
const RIBBON_MIN_SAMPLE_DISTANCE: float = 0.035
const RIBBON_MAX_SEGMENT_DISTANCE: float = 1.35
const RIBBON_MAX_SAMPLES: int = 32
const RIBBON_START_OFFSET: float = 0.42
const RIBBON_OUTER_HALF_WIDTH: float = 0.090
const RIBBON_CORE_HALF_WIDTH: float = 0.026
var melee_sustain_amount: float = 0.0
var burst_elapsed: float = BURST_TOTAL_SECONDS
var outer_material: ShaderMaterial
var inner_material: ShaderMaterial
var current_strength: float = 0.0
var nozzle_rest_rotation: Quaternion = Quaternion.IDENTITY
var steering_yaw: float = 0.0
var steering_pitch: float = 0.0
var returning_from_screen_sector: bool = false
var ribbon_mesh: MeshInstance3D
var ribbon_points: Array[Dictionary] = []
var ribbon_clock: float = 0.0
var ribbon_was_emitting: bool = false

func _ready() -> void:
    # The Blockbench Thruster_L/R group pivot, not this FX child, is the hinge.
    var nozzle: Node3D = get_parent() as Node3D
    if nozzle != null:
        nozzle_rest_rotation = nozzle.quaternion
        # The default/idle posture is already down before the first frame.
        steering_pitch = PITCH_DOWN_LIMIT_RADIANS
        nozzle.quaternion = (nozzle_rest_rotation
            * Quaternion(Vector3.RIGHT, steering_pitch)).normalized()
    outer_material = _build_tube(0.058, EXHAUST_LENGTH, Color(0.17, 0.63, 0.95, 0.53), 0.0)
    inner_material = _build_tube(0.029, EXHAUST_LENGTH * 0.83,
        Color(0.66, 0.91, 1.0, 0.48), 1.7)
    # Sibling of the flame: hiding ExhaustFX must not erase its fading wake.
    # top_level prevents authored torso/nozzle rotations from dragging old
    # trail vertices around; geometry is built in world coordinates.
    if nozzle != null:
        ribbon_mesh = MeshInstance3D.new()
        ribbon_mesh.name = "WorldRibbonTrail"
        ribbon_mesh.top_level = true
        ribbon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var ribbon_material := ShaderMaterial.new()
        ribbon_material.shader = RIBBON_SHADER
        ribbon_mesh.material_override = ribbon_material
        nozzle.add_child(ribbon_mesh)
        ribbon_mesh.global_transform = Transform3D.IDENTITY
        ribbon_mesh.visible = false
    visible = false

func _build_tube(half_width: float, length: float, tint: Color,
        offset: float) -> ShaderMaterial:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Generate the 10-sided tube around +Z, keeping the same nominal
    # diameter as the previous square's flat-to-flat width (2*half_width).
    # Adjacent segments share the same circle points, so the mesh has no gaps.
    for side in range(EXHAUST_RADIAL_SIDES):
        var start_angle: float = TAU * float(side) / float(EXHAUST_RADIAL_SIDES)
        var end_angle: float = TAU * float(side + 1) / float(EXHAUST_RADIAL_SIDES)
        var a := Vector2(cos(start_angle), sin(start_angle)) * half_width
        var b := Vector2(cos(end_angle), sin(end_angle)) * half_width
        for section in range(EXHAUST_AXIAL_SEGMENTS):
            var t0: float = float(section) / float(EXHAUST_AXIAL_SEGMENTS)
            var t1: float = float(section + 1) / float(EXHAUST_AXIAL_SEGMENTS)
            var z0: float = length * t0
            var z1: float = length * t1
            var vertices := [
                Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0),
                Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)
            ]
            var uvs := [Vector2(0.0, t0), Vector2(1.0, t0),
                Vector2(1.0, t1), Vector2(0.0, t1)]
            for corner_index in [0, 1, 2, 0, 2, 3]:
                tool.set_uv(uvs[corner_index])
                tool.set_normal(Vector3.BACK)
                tool.add_vertex(vertices[corner_index])
    var instance := MeshInstance3D.new()
    instance.name = "DecagonalExhaustCore" if offset > 0.0 else "DecagonalExhaustShell"
    instance.mesh = tool.commit()
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Keep transparent shader on its own instances, not on the shared SERA mesh.
    var material := ShaderMaterial.new()
    material.shader = FLAME_SHADER
    material.set_shader_parameter("flame_tint", tint)
    material.set_shader_parameter("tube_length", length)
    material.set_shader_parameter("phase_offset", offset)
    material.set_shader_parameter("strength", 0.0)
    material.set_shader_parameter("burst", 0.0)
    material.set_shader_parameter("melee_sustain", 0.0)
    instance.material_override = material
    add_child(instance)
    return material


# Sample each final physically steered nozzle in world space AFTER melee safety.
# The trail is a history of exhaust-tip positions, not a duplicate of the
# moving decagonal flame. No particles or GPU history textures are required.
func _update_ribbon_trail(emitting: bool, delta: float) -> void:
    if ribbon_mesh == null:
        return
    ribbon_clock += maxf(delta, 0.0)
    while not ribbon_points.is_empty():
        if ribbon_clock - float(ribbon_points[0]["time"]) <= RIBBON_LIFETIME_SECONDS:
            break
        ribbon_points.pop_front()
    if emitting:
        var tip: Vector3 = global_position + (
            global_transform.basis * Vector3.BACK).normalized() * RIBBON_START_OFFSET
        var should_append: bool = ribbon_points.is_empty() or not ribbon_was_emitting
        var is_new_streak: bool = not ribbon_was_emitting
        if not ribbon_points.is_empty():
            var previous: Dictionary = ribbon_points[ribbon_points.size() - 1]
            var distance: float = tip.distance_to(previous["position"])
            var elapsed: float = ribbon_clock - float(previous["time"])
            is_new_streak = is_new_streak or distance > RIBBON_MAX_SEGMENT_DISTANCE
            should_append = should_append or is_new_streak
            should_append = should_append or distance >= RIBBON_MIN_SAMPLE_DISTANCE
            should_append = should_append or elapsed >= RIBBON_SAMPLE_INTERVAL_SECONDS
        if should_append:
            ribbon_points.append({
                "position": tip,
                "time": ribbon_clock,
                "break": is_new_streak
            })
            if ribbon_points.size() > RIBBON_MAX_SAMPLES:
                ribbon_points.pop_front()
    ribbon_was_emitting = emitting
    _rebuild_ribbon_trail()

func _add_ribbon_quad(surface: SurfaceTool, a: Vector3, b: Vector3,
        side: Vector3, half_width_a: float, half_width_b: float,
        color_a: Color, color_b: Color) -> void:
    var vertices := [
        a - side * half_width_a, a + side * half_width_a,
        b + side * half_width_b, b - side * half_width_b
    ]
    var colors := [color_a, color_a, color_b, color_b]
    for index in [0, 1, 2, 0, 2, 3]:
        surface.set_color(colors[index])
        surface.add_vertex(vertices[index])

func _rebuild_ribbon_trail() -> void:
    if ribbon_points.size() < 2:
        ribbon_mesh.mesh = null
        ribbon_mesh.visible = false
        return
    var camera: Camera3D = get_viewport().get_camera_3d()
    var camera_position: Vector3 = camera.global_position if camera != null else Vector3.ZERO
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var segment_count: int = 0
    for i in range(1, ribbon_points.size()):
        var previous: Dictionary = ribbon_points[i - 1]
        var current: Dictionary = ribbon_points[i]
        if bool(current["break"]):
            continue
        var a: Vector3 = previous["position"]
        var b: Vector3 = current["position"]
        var direction: Vector3 = b - a
        if direction.length_squared() < 0.000009:
            continue
        direction = direction.normalized()
        # Face the actual training camera so the flat band stays visible
        # during quick turns, with a stable fallback for edge-on viewpoints.
        var view: Vector3 = camera_position - (a + b) * 0.5
        if view.length_squared() < 0.000001:
            view = Vector3.UP
        var side: Vector3 = direction.cross(view.normalized())
        if side.length_squared() < 0.000001:
            side = direction.cross(Vector3.UP)
        if side.length_squared() < 0.000001:
            side = direction.cross(Vector3.RIGHT)
        side = side.normalized()
        var fade_a: float = clampf(
            1.0 - (ribbon_clock - float(previous["time"])) / RIBBON_LIFETIME_SECONDS,
            0.0, 1.0)
        var fade_b: float = clampf(
            1.0 - (ribbon_clock - float(current["time"])) / RIBBON_LIFETIME_SECONDS,
            0.0, 1.0)
        var width_a: float = 0.20 + 0.80 * fade_a
        var width_b: float = 0.20 + 0.80 * fade_b
        _add_ribbon_quad(surface, a, b, side,
            RIBBON_OUTER_HALF_WIDTH * width_a,
            RIBBON_OUTER_HALF_WIDTH * width_b,
            Color(0.14, 0.64, 1.0, 0.63 * pow(fade_a, 1.5)),
            Color(0.14, 0.64, 1.0, 0.63 * pow(fade_b, 1.5)))
        _add_ribbon_quad(surface, a, b, side,
            RIBBON_CORE_HALF_WIDTH * width_a,
            RIBBON_CORE_HALF_WIDTH * width_b,
            Color(0.74, 0.94, 1.0, 0.74 * pow(fade_a, 1.7)),
            Color(0.74, 0.94, 1.0, 0.74 * pow(fade_b, 1.7)))
        segment_count += 1
    if segment_count == 0:
        ribbon_mesh.mesh = null
        ribbon_mesh.visible = false
        return
    ribbon_mesh.mesh = surface.commit()
    ribbon_mesh.visible = true

# Every melee frame is checked against the actual animated Chest, NOT the
# fixed player facing: the authored torso pitches/rolls during the 3 swings.
# Restrict the final, physically rendered nozzle +Z direction to point outward
# from its hinge rather than into SERA. This is a per-nozzle geometric guard.
func _avoid_melee_body_penetration(nozzle: Node3D, nozzle_parent: Node3D) -> void:
    # Blockbench groups are Chest -> BOOSTER -> Thruster_L/R -> ExhaustFX.
    var chest: Node3D = nozzle_parent.get_parent() as Node3D
    if chest == null:
        return
    var outward: Vector3 = nozzle.global_position - chest.global_position
    if outward.length_squared() < 0.000001:
        return
    outward = outward.normalized()
    var jet_axis: Vector3 = (
        nozzle.global_transform.basis * Vector3.BACK).normalized()
    var outward_dot: float = jet_axis.dot(outward)
    if outward_dot >= MELEE_TORSO_CLEARANCE_DOT:
        return
    # Project the current jet onto the closest safe outward cone. Preserve
    # the intended tangential direction as much as possible, but never allow
    # any transient inward-facing flame while the animated Chest rotates.
    var tangent: Vector3 = jet_axis - outward * outward_dot
    var safe_axis: Vector3 = outward
    if tangent.length_squared() > 0.000001:
        safe_axis = (outward * MELEE_TORSO_CLEARANCE_DOT
            + tangent.normalized() * sqrt(
                1.0 - MELEE_TORSO_CLEARANCE_DOT * MELEE_TORSO_CLEARANCE_DOT)).normalized()
    var rest_basis: Basis = (nozzle_parent.global_transform.basis
        * Basis(nozzle_rest_rotation)).orthonormalized()
    var local_safe: Vector3 = (rest_basis.inverse() * safe_axis).normalized()
    nozzle.quaternion = (nozzle_rest_rotation
        * Quaternion(Vector3.BACK, local_safe)).normalized()

func set_exhaust(enabled: bool, world_exhaust_direction: Vector3,
        delta: float, backstroke_weight: float = 0.0,
        left_sector_world: Vector3 = Vector3.ZERO,
        acceleration_burst: bool = false,
        melee_sustain: bool = false) -> void:
    if outer_material == null or inner_material == null:
        return
    var nozzle: Node3D = get_parent() as Node3D
    if nozzle == null or not (nozzle.get_parent() is Node3D):
        return
    # Rotate the authored 3D nozzle itself, carrying its exhaust lip along.
    var yaw: float = 0.0
    var pitch: float = PITCH_DOWN_LIMIT_RADIANS
    if enabled and world_exhaust_direction.length_squared() > 0.000001:
        # Use the authored REST axes; using the rotating nozzle basis feeds the
        # steering angle back into itself and can cause oscillation.
        var nozzle_parent: Node3D = nozzle.get_parent() as Node3D
        var rest_basis: Basis = (
            nozzle_parent.global_transform.basis * Basis(nozzle_rest_rotation)).orthonormalized()
        var local_dir: Vector3 = (
            rest_basis.inverse() * world_exhaust_direction.normalized()).normalized()
        var rear_denominator: float = (maxf(local_dir.z, 0.0)
            + 2.0 * maxf(-local_dir.z, 0.0) + 0.02)
        var requested_yaw: float = atan2(local_dir.x, rear_denominator)
        yaw = clampf(requested_yaw, -YAW_LIMIT_RADIANS, YAW_LIMIT_RADIANS)
        var horizontal: float = sqrt(local_dir.x * local_dir.x + local_dir.z * local_dir.z)
        pitch = clampf(-atan2(local_dir.y, horizontal),
            -PITCH_UP_LIMIT_RADIANS, PITCH_DOWN_LIMIT_RADIANS)
        # Reverse BOOST and reverse STEP deliberately point the real nozzles
        # DOWN instead of flipping the jets forward: backstroke-like travel.
        # At 100% rearward, yaw=0 and pitch=+90 degrees around each authored
        # Thruster_L/R pivot. Rear diagonals interpolate without snapping.
        var backstroke: float = clampf(backstroke_weight, 0.0, 1.0)
        yaw = lerpf(yaw, 0.0, backstroke)
        pitch = lerpf(pitch, PITCH_DOWN_LIMIT_RADIANS, backstroke)
    # Melee2 begins with a strongly rotated Torso/Chest. Unrestricted
    # world-rear steering previously twisted the visible metal nozzle as far
    # as 80 degrees relative to the pack, moving its lip and attached jet
    # across the character during the Melee1 -> Melee2 transition.
    # Limit ONLY normal melee nozzle articulation: actual homing/acceleration
    # and its burst remain untouched, and the jet still follows the nozzle.
    if enabled and melee_sustain:
        yaw = clampf(yaw, -MELEE_YAW_LIMIT_RADIANS, MELEE_YAW_LIMIT_RADIANS)
        pitch = clampf(pitch, -PITCH_UP_LIMIT_RADIANS, MELEE_PITCH_DOWN_LIMIT_RADIANS)
    # Inactive nozzle softly returns to a downward default, using the same
    # 3D nozzle pivot. Exhaust geometry remains attached to that pivot.
    var ease: float = 1.0 - exp(-maxf(delta, 0.0) / TURN_TIME)
    steering_yaw = lerp_angle(steering_yaw, yaw, ease)
    steering_pitch = lerp_angle(steering_pitch, pitch, ease)
    var normal_quaternion: Quaternion = (nozzle_rest_rotation
        * Quaternion(Vector3.UP, steering_yaw)
        * Quaternion(Vector3.RIGHT, steering_pitch)).normalized()
    if enabled and left_sector_world.length_squared() > 0.000001:
        # The special LEFT motion is bounded by the screen's DOWN->RIGHT
        # quadrant, rather than yaw/pitch angles relative to the moving Chest.
        # Convert the screen-space jet to the authored REST nozzle axes.
        # This rotates the actual 3D metal nozzle AND its child jet together.
        var nozzle_parent: Node3D = nozzle.get_parent() as Node3D
        var rest_basis: Basis = (
            nozzle_parent.global_transform.basis * Basis(nozzle_rest_rotation)).orthonormalized()
        var local_sector_direction: Vector3 = (
            rest_basis.inverse() * left_sector_world.normalized()).normalized()
        var screen_sector_quaternion: Quaternion = (nozzle_rest_rotation
            * Quaternion(Vector3.BACK, local_sector_direction)).normalized()
        nozzle.quaternion = nozzle.quaternion.slerp(
            screen_sector_quaternion, ease).normalized()
        returning_from_screen_sector = true
    elif returning_from_screen_sector:
        # Exit the special quadrant without snapping to the standard yaw/
        # pitch servo. Outside this transition normal steering is unchanged.
        nozzle.quaternion = nozzle.quaternion.slerp(
            normal_quaternion, ease).normalized()
        if nozzle.quaternion.angle_to(normal_quaternion) < deg_to_rad(0.5):
            returning_from_screen_sector = false
    else:
        nozzle.quaternion = normal_quaternion
    # Applying this AFTER the regular yaw/pitch or left-screen-sector servo
    # also protects the transition frames where the animated Chest rolls.
    # Other actions retain their original exact steering behavior.
    if enabled and melee_sustain:
        _avoid_melee_body_penetration(nozzle, nozzle.get_parent() as Node3D)
    # A world-space wake must be updated even after the jet turns off,
    # otherwise the last ribbon would remain frozen instead of fading.
    _update_ribbon_trail(enabled, delta)
    visible = enabled
    if not enabled:
        current_strength = 0.0
        melee_sustain_amount = 0.0
        burst_elapsed = BURST_TOTAL_SECONDS
        outer_material.set_shader_parameter("burst", 0.0)
        inner_material.set_shader_parameter("burst", 0.0)
        outer_material.set_shader_parameter("melee_sustain", 0.0)
        inner_material.set_shader_parameter("melee_sustain", 0.0)
        return
    var sustain_target: float = 1.0 if melee_sustain else 0.0
    melee_sustain_amount = lerpf(melee_sustain_amount, sustain_target,
        1.0 - exp(-maxf(delta, 0.0) / MELEE_SUSTAIN_RESPONSE_SECONDS))
    if acceleration_burst:
        burst_elapsed = 0.0
    burst_elapsed = minf(BURST_TOTAL_SECONDS, burst_elapsed + maxf(delta, 0.0))
    var burst: float = 0.0
    if burst_elapsed < BURST_RISE_SECONDS:
        # The flare opens outward over the first 0.05s, reaching its widest tip.
        burst = burst_elapsed / BURST_RISE_SECONDS
    elif burst_elapsed < BURST_TOTAL_SECONDS:
        # Ease smoothly back to the ordinary narrow exhaust over 0.18s.
        var fall: float = clampf(
            (burst_elapsed - BURST_RISE_SECONDS) / BURST_FALL_SECONDS, 0.0, 1.0)
        burst = 1.0 - fall * fall * (3.0 - 2.0 * fall)
    current_strength = lerpf(current_strength, 1.0,
        1.0 - exp(-maxf(delta, 0.0) / 0.045))
    outer_material.set_shader_parameter("strength", current_strength)
    inner_material.set_shader_parameter("strength", current_strength)
    outer_material.set_shader_parameter("burst", burst)
    inner_material.set_shader_parameter("burst", burst)
    outer_material.set_shader_parameter("melee_sustain", melee_sustain_amount)
    inner_material.set_shader_parameter("melee_sustain", melee_sustain_amount)
