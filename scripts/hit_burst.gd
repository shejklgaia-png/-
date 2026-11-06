extends Node3D
## v19: independent square-pixel sparks with thin, curved motion trails.
## Each square has a sub-pixel dark-red BORDER around a light core; the border
## shade is unchanged from v18's sparks. Geometries are non-alpha 3D triangles.

const DURATION: float = 0.380
const SPARK_COUNT: int = 27
const FRONT_OFFSET: float = 1.52
const SPAWN_JITTER_HORIZONTAL: float = 0.125
const SPAWN_JITTER_VERTICAL: float = 0.105
const TRAIL_LAG: float = 0.083

var view_camera: Camera3D
var target_node: Node3D
var mesh: ImmediateMesh
var instance: MeshInstance3D
var material: StandardMaterial3D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var origin: Vector3 = Vector3.ZERO
var elapsed: float = DURATION
var spark_dirs: Array[Vector2] = []
var spark_origins: Array[Vector3] = []
var spark_speeds: Array[float] = []
var spark_sizes: Array[float] = []
var spark_lives: Array[float] = []
var spark_gravities: Array[float] = []
var spark_drifts: Array[float] = []
var spark_colors: Array[Color] = []
var spark_borders: Array[Color] = []

func _ready() -> void:
    rng.randomize()
    mesh = ImmediateMesh.new()
    instance = MeshInstance3D.new()
    instance.name = "Random_Square_Sparks_Thin_Motion_Streaks"
    instance.mesh = mesh
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)
    material = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.no_depth_test = false  # v32: Sera can occlude hit sparks, unlike v31
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    material.render_priority = 120
    material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

func _reset_sparks() -> void:
    spark_dirs.clear()
    spark_origins.clear()
    spark_speeds.clear()
    spark_sizes.clear()
    spark_lives.clear()
    spark_gravities.clear()
    spark_drifts.clear()
    spark_colors.clear()
    spark_borders.clear()

func start_burst(world_hit: Vector3, blade_sweep: Vector3) -> void:
    origin = world_hit
    elapsed = 0.0
    _reset_sparks()
    var right: Vector3 = view_camera.global_basis.x if view_camera != null else Vector3.RIGHT
    var up: Vector3 = view_camera.global_basis.y if view_camera != null else Vector3.UP
    var axis: Vector2 = Vector2(blade_sweep.dot(right), -blade_sweep.dot(up))
    if axis.length_squared() < 0.00001:
        axis = Vector2(0.91, -0.42)
    axis = axis.normalized()
    var tones: Array[Color] = [Color("fffef4"), Color("fff0ae"), Color("ffd274"), Color("ff9b55")]
    var border_tones: Array[Color] = [Color("994029"), Color("a74a2d"), Color("b54b2f")]
    for i in range(SPARK_COUNT):
        var angle: float = rng.randf_range(-1.65, 1.65)
        if i % 4 == 0:
            angle = rng.randf_range(-PI, PI)
        elif i % 7 == 0:
            angle += PI
        spark_dirs.append(axis.rotated(angle))
        spark_origins.append(world_hit + right * rng.randf_range(-SPAWN_JITTER_HORIZONTAL, SPAWN_JITTER_HORIZONTAL) + up * rng.randf_range(-SPAWN_JITTER_VERTICAL, SPAWN_JITTER_VERTICAL))
        spark_speeds.append(rng.randf_range(190.0, 520.0))
        spark_sizes.append(rng.randf_range(4.8, 9.4))
        spark_lives.append(rng.randf_range(0.18, DURATION))
        spark_gravities.append(rng.randf_range(95.0, 245.0))
        spark_drifts.append(rng.randf_range(-95.0, 95.0))
        spark_colors.append(tones[rng.randi_range(0, tones.size() - 1)])
        spark_borders.append(border_tones[rng.randi_range(0, border_tones.size() - 1)])
    _redraw()

func advance(delta: float) -> void:
    if elapsed >= DURATION:
        return
    elapsed = minf(DURATION, elapsed + delta)
    _redraw()

func _tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color, depth: float) -> void:
    mesh.surface_set_color(ca)
    mesh.surface_add_vertex(view_camera.project_position(a, depth))
    mesh.surface_set_color(cb)
    mesh.surface_add_vertex(view_camera.project_position(b, depth))
    mesh.surface_set_color(cc)
    mesh.surface_add_vertex(view_camera.project_position(c, depth))

func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color, depth: float) -> void:
    _tri(a, b, c, color, color, color, depth)
    _tri(a, c, d, color, color, color, depth)

func _rect(center: Vector2, half: float, color: Color, depth: float) -> void:
    var ext: Vector2 = Vector2.ONE * half
    _quad(center - ext, center + Vector2(half, -half), center + ext, center + Vector2(-half, half), color, depth)

func _point_at(i: int, t: float, center: Vector2, scale_factor: float) -> Vector2:
    var direction: Vector2 = spark_dirs[i]
    var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
    var travel: float = spark_speeds[i] * t * (1.0 - 0.22 * t / spark_lives[i])
    var gravity: Vector2 = Vector2(0.0, spark_gravities[i] * t * t)
    var drift: Vector2 = perpendicular * spark_drifts[i] * t * t
    return center + (direction * travel + gravity + drift) * scale_factor

func _streak_segment(start: Vector2, finish: Vector2, width: float, tint: Color, depth: float) -> void:
    var segment: Vector2 = finish - start
    if segment.length_squared() < 0.01:
        return
    var normal: Vector2 = Vector2(-segment.y, segment.x).normalized() * width * 0.5
    _quad(start - normal, finish - normal, finish + normal, start + normal, tint, depth)

func _spark(i: int, center: Vector2, depth: float, scale_factor: float) -> void:
    var t: float = elapsed / spark_lives[i]
    if t >= 1.0:
        return
    var life_left: float = 1.0 - t
    var head: Vector2 = _point_at(i, elapsed, center, scale_factor)
    var halfway: Vector2 = _point_at(i, maxf(0.0, elapsed - TRAIL_LAG * 0.48), center, scale_factor)
    var back: Vector2 = _point_at(i, maxf(0.0, elapsed - TRAIL_LAG), center, scale_factor)
    var square_width: float = spark_sizes[i] * scale_factor * (0.62 + 0.38 * life_left)
    var red: Color = spark_borders[i]
    # Trail is a much thinner line (not a tapered polygon or long triangle).
    # Two path samples follow the spark's actual parabolic/deviating motion.
    if elapsed > 0.018:
        _streak_segment(back, halfway, 0.80 * scale_factor * life_left, red.darkened(0.24), depth + 0.005)
        _streak_segment(halfway, head, 1.22 * scale_factor * life_left, red, depth + 0.004)
        _streak_segment(halfway, head, 0.45 * scale_factor * life_left, spark_colors[i], depth + 0.002)
    # Screen-aligned pixel QUADS.  The red frame is ONLY about 0.9 px thick;
    # retain v18's dark red palette, but let the bright square dominate.
    _rect(head, square_width * 0.5, red, depth)
    var border_px: float = minf(0.95 * scale_factor, square_width * 0.16)
    _rect(head, maxf(0.25, square_width * 0.5 - border_px), spark_colors[i], depth - 0.003)

func _redraw() -> void:
    mesh.clear_surfaces()
    if elapsed >= DURATION or view_camera == null or view_camera.is_position_behind(origin):
        return
    var center_world: Vector3 = target_node.global_position if target_node != null else origin
    var target_depth: float = (center_world - view_camera.global_position).dot(-view_camera.global_basis.z)
    var depth: float = maxf(0.9, target_depth - FRONT_OFFSET)
    var scale_factor: float = 1.0
    if target_node != null:
        var top: Vector2 = view_camera.unproject_position(center_world + Vector3.UP)
        var bottom: Vector2 = view_camera.unproject_position(center_world - Vector3.UP)
        scale_factor = clampf(top.distance_to(bottom) / 300.0, 0.66, 1.55)
    mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
    # Subtle square contact flash, no prominent angular starburst.
    if elapsed < 0.075:
        var moment: float = 1.0 - elapsed / 0.075
        var flash_px: float = (2.4 + 4.1 * moment) * scale_factor
        _rect(view_camera.unproject_position(origin), flash_px, Color("ffb85e"), depth + 0.004)
        _rect(view_camera.unproject_position(origin), flash_px * 0.55, Color("fffdf3"), depth - 0.002)
    for i in range(spark_dirs.size()):
        var spawn: Vector2 = view_camera.unproject_position(spark_origins[i])
        _spark(i, spawn, depth, scale_factor)
    mesh.surface_end()
