extends SceneTree
## Measured real Godot ImmediateMesh triangles: six seamless eight-sided uniform-alpha
## octagon bands; no soft radial gradient; fast edge-tapered crack and shards.
const FX = preload("res://scripts/enemy_shield_hit_fx.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V516_OCTAGON_SHIELD_FAILED: " + message)
    quit(1)

func _run() -> void:
    if FX.FRAME_COUNT != 6 or FX.FRAME_SIDES != 8:
        _fail("must use exactly 6 eight-sided frames")
        return
    if not is_equal_approx(FX.EXPAND_SECONDS, 0.20) or (
            not is_equal_approx(FX.HOLD_SECONDS, 0.20)) or (
            not is_equal_approx(FX.FADE_SECONDS, 0.20)) or (
            not is_equal_approx(FX.IMPACT_SECONDS, 0.60)):
        _fail("hit animation phases must be 0.2 expansion, hold and fade")
        return
    for sample in [
        [0.015, 1],
        [0.050, 2],
        [0.100, 4],
        [0.180, 6],
        [0.250, 6],
        [0.390, 6],
        [0.600, 0],
    ]:
        if FX.visible_frame_count(float(sample[0])) != int(sample[1]):
            _fail("frame emergence order wrong at t=" + str(sample[0]))
            return
    for i in range(5):
        if FX.frame_alpha(i, 0.30) <= FX.frame_alpha(i + 1, 0.30):
            _fail("outer octagons must be successively more transparent")
            return
    if FX.frame_alpha(0, 0.45) >= FX.frame_alpha(0, 0.30) or (
            FX.frame_alpha(0, 0.60) > 0.0001):
        _fail("the last 0.2s must fade with no lingering octagon")
        return
    if FX.CRACK_EXTEND_SECONDS > 0.07 or FX.CRACK_FADE_END_SECONDS > 0.18:
        _fail("shatter crack must be much faster than v515")
        return
    if FX.crack_tip_opacity(0.0) < 0.99 or (
            FX.crack_tip_opacity(0.83) >= 1.0) or (
            FX.crack_tip_opacity(1.0) > 0.0001):
        _fail("crack must fade along its horizontal outer tips")
        return

    var camera := Camera3D.new()
    root.add_child(camera)
    camera.make_current()
    var fx: Node3D = FX.new()
    root.add_child(fx)
    fx.set("view_camera", camera)
    var hit := Vector3(0, 0, -6)
    var center := camera.unproject_position(hit)
    fx.call("start_impact", hit, 0.96, false)
    fx.call("advance", 0.25)
    var mesh: ImmediateMesh = fx.get("mesh")
    if mesh.get_surface_count() != 1:
        _fail("fully expanded frames must produce a mesh surface")
        return
    var arrays: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
    # 8 triangles for filled innermost octagon (24 vertices) and
    # 6 gapless octagon bands x 8 sides x 2 triangles x 3 vertices = 288.
    if vertices.size() != 312 or colors.size() != 312:
        _fail("expected six eight-sided thick frames and a solid center: " +
            str(vertices.size()))
        return
    var center_alpha: float = 0.0
    var outer_radius: float = 0.0
    # v519: the same 6 rings and central panel become 15% wider in screen
    # space, with unchanged height, thickness count and elapsed time.
    var max_x: float = 0.0
    var max_y: float = 0.0
    for i in range(vertices.size()):
        var d: float = camera.unproject_position(vertices[i]).distance_to(center)
        if d < 0.5:
            center_alpha = maxf(center_alpha, colors[i].a)
        outer_radius = maxf(outer_radius, d)
        var screen_pos: Vector2 = camera.unproject_position(vertices[i])
        max_x = maxf(max_x, absf(screen_pos.x - center.x))
        max_y = maxf(max_y, absf(screen_pos.y - center.y))
    if max_y < 1.0 or absf(max_x / max_y - 1.15) > 0.015:
        _fail("the shield octagons must be exactly ~15% wider, height unchanged: " +
            str(max_x / maxf(max_y, 1.0)))
        return
    if center_alpha < 0.70 or outer_radius < 45.0 or outer_radius > 150.0:
        _fail("solid core missing or 30%-size octagon scale outside the expected range")
        return
    # Every corner vertex shares a flat alpha with its neighboring vertices
    # in the frame, rather than being a blurred radial wedge.
    for frame in range(6):
        var base_idx: int = 24 + frame * 48
        var first_alpha: float = colors[base_idx].a
        for i in range(base_idx, base_idx + 48):
            if absf(colors[i].a - first_alpha) > 0.001:
                _fail("octagon frame has a blurred/gradient edge")
                return

    fx.call("reset")
    fx.call("start_impact", hit, 0.0, true)
    var entries: Array = fx.get("impacts")
    if entries.size() != 1 or (
            (entries[0]["shards"] as Array).size() != FX.GLASS_SHARD_COUNT):
        _fail("shatter must generate 14 reusable randomized glass fragments")
        return
    fx.call("advance", 0.40)
    if mesh.get_surface_count() != 1:
        _fail("large glass fragments must remain at t=0.4")
        return
    arrays = mesh.surface_get_arrays(0)
    vertices = arrays[Mesh.ARRAY_VERTEX]
    colors = arrays[Mesh.ARRAY_COLOR]
    if vertices.size() < 6 * FX.GLASS_SHARD_COUNT:
        _fail("glass burst contains too few polygons")
        return
    for i in range(vertices.size()):
        var d: float = camera.unproject_position(vertices[i]).distance_to(center)
        if d < 16.0 and colors[i].a > 0.01:
            _fail("broken shield must have a clear center after the crack")
            return
    var sound: AudioStreamPlayer = fx.get("break_audio")
    if sound == null or sound.stream == null:
        _fail("glass shatter lost the existing sound")
        return
    fx.call("advance", 0.30)
    if mesh.get_surface_count() != 0:
        _fail("shards must be removed after the break effect")
        return
    fx.queue_free()
    camera.queue_free()
    print("GODOT_V516_SIX_OCTAGONS_AND_GLASS_PASS")
    quit(0)
