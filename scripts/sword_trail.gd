extends Node3D
const RENDER_ORDER = preload("res://scripts/render_order_policy.gd")
## v85 SERA sword-effect method (3D volume + scatter particles).
## Restore proven-in-source v35 cutout/convex shell/particles, applying all 8
## frames to each of the three v84 hand-positioned Swordeffect plates.
## The 4-vertex Blockbench plate is ONLY an animated spatial reference;
## the actual rendered shape is alpha-clipped geometry, not a full rectangle.
## No 0.55m forward correction, billboarding, camera or sword tracking.
const WHITE_FRAMES = [
    preload("res://assets/v35_cutout_frames/white_0.png"),
    preload("res://assets/v35_cutout_frames/white_1.png"),
    preload("res://assets/v35_cutout_frames/white_2.png"),
    preload("res://assets/v35_cutout_frames/white_3.png"),
    preload("res://assets/v35_cutout_frames/white_4.png"),
    preload("res://assets/v35_cutout_frames/white_5.png"),
    preload("res://assets/v35_cutout_frames/white_6.png"),
    preload("res://assets/v35_cutout_frames/white_7.png")
]
const RED_FRAMES = [
    preload("res://assets/v35_cutout_frames/red_0.png"),
    preload("res://assets/v35_cutout_frames/red_1.png"),
    preload("res://assets/v35_cutout_frames/red_2.png"),
    preload("res://assets/v35_cutout_frames/red_3.png"),
    preload("res://assets/v35_cutout_frames/red_4.png"),
    preload("res://assets/v35_cutout_frames/red_5.png"),
    preload("res://assets/v35_cutout_frames/red_6.png"),
    preload("res://assets/v35_cutout_frames/red_7.png")
]
const VOLUME_PATH = "res://assets/slash_C_volume_geometry.json"
const CUTOUT_PATH = "res://assets/v35_cutout_tiles.json"
const START_TIME: float = 0.075
const END_TIME: float = 0.485
const MAX_PARTICLES: int = 32
const SIDE_LENGTH: float = 1.04 # Exact authored 16 Blockbench units * 0.065 meters; never autoscale.
@export_range(0.0, 1.0, 0.05) var flat_layer_opacity: float = 1.0
@export_range(0.0, 1.0, 0.05) var volume_opacity: float = 0.34
@export_range(0.0, 1.0, 0.05) var target_overlap_opacity: float = 0.58
@export_range(0, 120, 1) var particle_rate: int = 54
@export var show_lens: bool = true
@export var enable_target_fade: bool = true
var view_camera: Camera3D
var target_node: Node3D
var player_node: Node3D
var rig_node: Node3D
var source_plane: MeshInstance3D
var effect_root: Node3D
var flat_mesh: MeshInstance3D
var lens_mesh: MeshInstance3D
var particles_mesh: MeshInstance3D
var flat_material: StandardMaterial3D
var lens_material: StandardMaterial3D
var particle_material: StandardMaterial3D
var cutout_tiles: Array = []
var volume_frames: Array = []
var frame_emitters: Array = []
var sparks: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var swing_running: bool = false
var last_clip_time: float = 0.0
var strike_trail_offset: float = 0.0
var last_frame: int = -1
var use_red_palette: bool = false
var emitter_remainder: float = 0.0

func attach_to_rig(rig_ref: Node3D) -> void:
    rig_node = rig_ref
    if rig_node == null:
        push_error("v85: no rig")
        return
    source_plane = rig_node.call("get_sword_effect_mesh") as MeshInstance3D
    if source_plane == null or source_plane.mesh == null:
        push_error("v85: authored Swordeffect not found")
        return
    # Honor the exact authored board: same parent bone, local transform and
    # 1.04-meter local UV extent; animations move the shared parent bone.
    source_plane.visible = false
    source_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    effect_root = Node3D.new()
    effect_root.name = "V85_3DSlash_AuthoredBoard_3Stage"
    source_plane.get_parent().add_child(effect_root)
    effect_root.transform = source_plane.transform
    flat_mesh = MeshInstance3D.new()
    flat_mesh.name = "AlphaClippedMainArc"
    effect_root.add_child(flat_mesh)
    lens_mesh = MeshInstance3D.new()
    lens_mesh.name = "ConvexTwoSided3DArc"
    effect_root.add_child(lens_mesh)
    particles_mesh = MeshInstance3D.new()
    particles_mesh.name = "ScatteredSlashMicroParticles"
    effect_root.add_child(particles_mesh)
    flat_material = _make_material(RENDER_ORDER.SLASH_SURFACE, BaseMaterial3D.CULL_DISABLED, flat_layer_opacity)
    lens_material = _make_material(RENDER_ORDER.SLASH_VOLUME, BaseMaterial3D.CULL_FRONT, volume_opacity)
    particle_material = _make_material(RENDER_ORDER.SLASH_PARTICLES, BaseMaterial3D.CULL_DISABLED, 1.0)
    flat_mesh.material_override = flat_material
    lens_mesh.material_override = lens_material
    particles_mesh.material_override = particle_material
    for piece in [flat_mesh, lens_mesh, particles_mesh]:
        piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _load_geometry()
    rng.randomize()
    effect_root.visible = false

func _make_material(priority: int, cull: int, opacity: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = cull
    mat.no_depth_test = true
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    mat.vertex_color_use_as_albedo = true
    mat.albedo_color = Color(1, 1, 1, opacity)
    mat.render_priority = priority
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    return mat

func _load_geometry() -> void:
    var raw_tiles: Variant = JSON.parse_string(FileAccess.get_file_as_string(CUTOUT_PATH))
    var raw_lens: Variant = JSON.parse_string(FileAccess.get_file_as_string(VOLUME_PATH))
    if raw_tiles is Dictionary:
        cutout_tiles = raw_tiles.get("frames", [])
    if raw_lens is Dictionary:
        volume_frames = raw_lens.get("frames", [])
    if cutout_tiles.size() != 8 or volume_frames.size() != 8:
        push_error("v85: expected 8 slash frame geometries")
        return
    for frame in volume_frames:
        frame_emitters.append(frame.get("emitters", []))

func _texture(frame: int) -> Texture2D:
    return RED_FRAMES[frame] if use_red_palette else WHITE_FRAMES[frame]

func set_red_palette(enabled: bool) -> void:
    use_red_palette = enabled
    if last_frame >= 0:
        flat_material.albedo_texture = _texture(last_frame)
        lens_material.albedo_texture = _texture(last_frame)

func _set_player_foreground(enabled: bool) -> void:
    if rig_node != null and rig_node.has_method("set_slash_player_foreground"):
        rig_node.call("set_slash_player_foreground", enabled)

func begin_swing(clip_offset: float = 0.0) -> void:
    strike_trail_offset = clip_offset
    swing_running = true
    last_clip_time = 0.0
    last_frame = -1
    sparks.clear()
    emitter_remainder = 0.0
    if effect_root != null: effect_root.visible = false
    _set_player_foreground(false)

func stop_swing() -> void:
    swing_running = false
    sparks.clear()
    last_frame = -1
    emitter_remainder = 0.0
    _set_player_foreground(false)
    if effect_root != null: effect_root.visible = false
    if particles_mesh != null: particles_mesh.mesh = null

func on_hit(_world_hit: Vector3) -> void:
    pass

func sample_swing(_base: Vector3, _tip: Vector3, clip_time: float, _delta: float) -> void:
    if swing_running: last_clip_time = maxf(0.0, clip_time - strike_trail_offset)

func _frame_index(t: float) -> int:
    if t >= 0.375: return 7
    if t >= 0.315: return 6
    if t >= 0.255: return 5
    if t >= 0.205: return 4
    if t >= 0.165: return 3
    if t >= 0.130: return 2
    if t >= 0.105: return 1
    return 0

func advance(delta: float, paused_for_hit_stop: bool) -> void:
    if effect_root == null or flat_material == null:
        return
    # This assertion prevents future edits from accidentally restoring the board.
    source_plane.visible = false
    if not swing_running or last_clip_time < START_TIME or last_clip_time >= END_TIME:
        effect_root.visible = false
        _set_player_foreground(false)
        sparks.clear()
        particles_mesh.mesh = null
        return
    var frame: int = _frame_index(last_clip_time)
    if frame != last_frame:
        _show_frame(frame)
        last_frame = frame
    flat_material.albedo_color = Color(1, 1, 1, flat_layer_opacity)
    lens_material.albedo_color = Color(1, 1, 1, volume_opacity)
    effect_root.visible = true
    lens_mesh.visible = show_lens
    _set_player_foreground(true)
    if not paused_for_hit_stop: _step_particles(delta, frame)

func _show_frame(frame: int) -> void:
    flat_material.albedo_texture = _texture(frame)
    lens_material.albedo_texture = _texture(frame)
    flat_mesh.mesh = _build_flat(frame)
    lens_mesh.mesh = _build_lens(frame)

func _local_to_uv(u: float, v: float, height: float = 0.0) -> Vector3:
    return Vector3((u - 0.5) * SIDE_LENGTH, height, (v - 0.5) * SIDE_LENGTH)

func _target_visibility(local: Vector3) -> float:
    if not enable_target_fade or view_camera == null or target_node == null or effect_root == null:
        return 1.0
    # Transform the camera ray into the actual target mesh's rotated/bobbing
    # local frame, so only pixels overlapping its 2x2x2 cube are attenuated.
    var marker: Node3D = target_node.get_node_or_null("FloatingBox") as Node3D
    var box: Node3D = marker if marker != null else target_node
    var ray_start: Vector3 = box.to_local(view_camera.global_position)
    var ray_end: Vector3 = box.to_local(effect_root.to_global(local))
    if _ray_box_intersects(ray_start, ray_end, 0.94):
        return target_overlap_opacity
    if _ray_box_intersects(ray_start, ray_end, 1.06):
        return lerpf(target_overlap_opacity, 1.0, 0.65)
    return 1.0

func _ray_box_intersects(start: Vector3, to_point: Vector3, half_size: float) -> bool:
    # Ray-box silhouette test; no comparison to the fragment's depth, because
    # slash remains in front of the target even when physically embedded.
    var d: Vector3 = to_point - start
    if d.length_squared() < 0.0000001: return false
    var near_t: float = 0.0
    var far_t: float = 1.0e9
    for axis in range(3):
        var o: float = start[axis]
        var dir: float = d[axis]
        if absf(dir) < 0.000001:
            if o < -half_size or o > half_size: return false
        else:
            var ta: float = (-half_size - o) / dir
            var tb: float = (half_size - o) / dir
            near_t = maxf(near_t, minf(ta, tb))
            far_t = minf(far_t, maxf(ta, tb))
            if far_t < near_t: return false
    return far_t > 0.0

func _build_flat(frame: int) -> ArrayMesh:
    var mesh := ArrayMesh.new()
    if frame >= cutout_tiles.size(): return mesh
    var verts := PackedVector3Array()
    var uvs := PackedVector2Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    # Each 8x8px tile exists only where the source PNG contains ink alpha.
    # Even total shader/material failure cannot produce a full-screen board.
    for cell in cutout_tiles[frame]:
        var u0: float = float(cell[0]) / 64.0
        var v0: float = float(cell[1]) / 64.0
        var u1: float = (float(cell[0]) + 1.0) / 64.0
        var v1: float = (float(cell[1]) + 1.0) / 64.0
        var base: int = verts.size()
        for uv in [Vector2(u0,v0),Vector2(u1,v0),Vector2(u1,v1),Vector2(u0,v1)]:
            var p := _local_to_uv(uv.x, uv.y)
            verts.append(p)
            uvs.append(uv)
            colors.append(Color(1,1,1,_target_visibility(p)))
        indices.append_array(PackedInt32Array([base,base+2,base+1,base,base+3,base+2]))
    if indices.is_empty(): return mesh
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _build_lens(frame: int) -> ArrayMesh:
    var mesh := ArrayMesh.new()
    if frame >= volume_frames.size(): return mesh
    var geom: Dictionary = volume_frames[frame]
    var points: Array = geom.get("points", [])
    var triangles: Array = geom.get("triangles", [])
    if points.size() < 3 or triangles.is_empty(): return mesh
    var verts := PackedVector3Array()
    var uvs := PackedVector2Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    for side in [1.0, -1.0]:
        for p in points:
            var uv := Vector2(float(p[0]),float(p[1]))
            var v := _local_to_uv(uv.x, uv.y, float(p[2]) * side)
            verts.append(v)
            uvs.append(uv)
            colors.append(Color(1,1,1,_target_visibility(v)))
    var n: int = points.size()
    for t in triangles:
        var a: int = int(t[0]); var b: int = int(t[1]); var c: int = int(t[2])
        if a >= n or b >= n or c >= n: continue
        indices.append_array(PackedInt32Array([a,c,b,a+n,b+n,c+n]))
    if indices.is_empty(): return mesh
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _step_particles(delta: float, frame: int) -> void:
    emitter_remainder += float(particle_rate) * delta
    var count: int = mini(int(emitter_remainder), 8)
    emitter_remainder -= float(count)
    for _i in range(count):
        if sparks.size() < MAX_PARTICLES: _spawn_particle(frame)
    var alive: Array[Dictionary] = []
    for spark in sparks:
        var s: Dictionary = spark
        s["age"] = float(s["age"]) + delta
        if float(s["age"]) < float(s["life"]):
            s["pos"] = (s["pos"] as Vector3) + (s["vel"] as Vector3) * delta
            alive.append(s)
    sparks = alive
    _draw_particles()

func _spawn_particle(frame: int) -> void:
    if frame >= frame_emitters.size(): return
    var pool: Array = frame_emitters[frame]
    if pool.is_empty(): return
    var uv: Array = pool[rng.randi_range(0,pool.size()-1)]
    var p := _local_to_uv(float(uv[0]),float(uv[1]),rng.randf_range(-0.018,0.018))
    var velocity := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.5,0.5),rng.randf_range(-1,1)).normalized()
    sparks.append({"pos":p,"vel":velocity * rng.randf_range(0.16,0.60),
        "age":0.0,"life":rng.randf_range(0.17,0.40),"size":rng.randf_range(0.016,0.034)})

func _draw_particles() -> void:
    if sparks.is_empty():
        particles_mesh.mesh = null
        return
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for spark in sparks:
        var p: Vector3 = spark["pos"]
        var v: Vector3 = spark["vel"]
        var size: float = float(spark["size"])
        var alpha: float = pow(1.0-float(spark["age"])/float(spark["life"]),1.3)
        var col := Color(1.0,0.25,0.25,alpha) if use_red_palette else Color(1,1,1,alpha)
        col.a *= _target_visibility(p)
        var half: float = size*0.5
        var p0 := p+Vector3(-half,0,-half)
        var p1 := p+Vector3(half,0,-half)
        var p2 := p+Vector3(half,0,half)
        var p3 := p+Vector3(-half,0,half)
        _tri(tool,p0,p1,p2,col)
        _tri(tool,p0,p2,p3,col)
        var tail: Vector3 = p-v.normalized()*size*2.0
        _tri(tool,p0,p3,tail,Color(col.r,col.g,col.b,col.a*0.25))
    particles_mesh.mesh = tool.commit()

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
    st.set_color(color); st.add_vertex(a)
    st.set_color(color); st.add_vertex(b)
    st.set_color(color); st.add_vertex(c)
