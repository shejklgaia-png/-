extends SceneTree
## v524: real ImmediateMesh seam/scale checks and one-color decelerating fragments.
const FX = preload("res://scripts/enemy_shield_hit_fx.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("V524_SHIELD_SHARDS_FAILED: " + why)
    quit(1)

func _run() -> void:
    if not is_equal_approx(FX.VISUAL_SIZE_MULTIPLIER, 0.30):
        _fail("visual effects must be 70% smaller (30% of former size)")
        return
    # Ease-out must leave a positive outward movement that slows over time.
    var first: float = FX.shard_distance_px(0.1, 1.0) - FX.shard_distance_px(0.0, 1.0)
    var last: float = FX.shard_distance_px(0.65, 1.0) - FX.shard_distance_px(0.55, 1.0)
    if first <= 0.0 or last <= 0.0 or first <= last * 2.0:
        _fail("shards must move outward and decelerate before fading")
        return
    var camera := Camera3D.new()
    root.add_child(camera)
    camera.make_current()
    var fx: Node3D = FX.new()
    root.add_child(fx)
    fx.set("view_camera", camera)
    var hit := Vector3(0, 0, -6)
    fx.call("start_impact", hit, 0.96, false)
    fx.call("advance", 0.25)
    var mesh: ImmediateMesh = fx.get("mesh")
    if mesh.get_surface_count() != 1:
        _fail("shield should have visible polygon geometry")
        return
    var arrays: Array = mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
    if vertices.size() != 312 or colors.size() != 312:
        _fail("six contiguous 8-sided bands and filled core are required")
        return
    # Mesh geometry must literally reuse the prior layer's outer boundary.
    # Matching only approximate radius constants can conceal visible gaps.
    for side in range(8):
        if vertices[side * 3 + 1].distance_to(vertices[24 + side * 6]) > 0.0001:
            _fail("the central octagon must meet the innermost band")
            return
    for layer in range(1, 6):
        for side in range(8):
            var old_outer: Vector3 = vertices[24 + (layer - 1) * 48 + side * 6 + 1]
            var new_inner: Vector3 = vertices[24 + layer * 48 + side * 6]
            if old_outer.distance_to(new_inner) > 0.0001:
                _fail("adjacent octagons leave a gap at layer " + str(layer))
                return
    fx.call("reset")
    fx.call("start_impact", hit, 0.0, true)
    var impacts: Array = fx.get("impacts")
    if impacts.size() != 1 or (impacts[0]["shards"] as Array).size() != 14:
        _fail("a break must store exactly fourteen stable shard descriptors")
        return
    var shards: Array = impacts[0]["shards"]
    for shard in shards:
        if not shard.has("spawn") or not shard.has("notch") or not shard.has("tip_bias") or (
                float(shard["speed"]) <= 0.0):
            _fail("missing randomized position, speed or irregular shape")
            return
    fx.call("advance", 0.40)
    arrays = mesh.surface_get_arrays(0)
    vertices = arrays[Mesh.ARRAY_VERTEX]
    colors = arrays[Mesh.ARRAY_COLOR]
    if colors.size() != 6 * 14:
        _fail("after the crack fades, all fourteen shards need two triangles")
        return
    var tint: Color = colors[0]
    for color in colors:
        if absf(color.r - tint.r) > 0.0001 or (
                absf(color.g - tint.g) > 0.0001) or (
                absf(color.b - tint.b) > 0.0001) or (
                absf(color.a - tint.a) > 0.0001):
            _fail("shards must be a single flat color, not two-tone facets")
            return
    fx.call("advance", 0.30)
    if mesh.get_surface_count() != 0:
        _fail("fragments must disappear by effect expiry")
        return
    fx.queue_free()
    camera.queue_free()
    print("GODOT_V524_SEAMLESS_COMPACT_SINGLE_COLOR_SHARDS_PASS")
    quit(0)
