extends RefCounted
## BASE physical power network. Seven local substations connect to the
## GENERATOR control terminal, then to each consumer's exterior socket.
## Placement is seeded and stable, independent of time/frame rate.
## Solid equipment and cables use the same role-3 visible-ID ink as clutter:
## inner 1px, outer 1px, contacts 1px, convex corners 1px.
## No added lights or GPU simulation.
const BaseClutter = preload("res://scripts/sera_base_clutter.gd")
const PowerBoard = preload("res://scripts/sera_base_power_board.gd")
const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")
const CrossingRamps = preload("res://scripts/sera_base_cable_crossing_ramps.gd")

const WIRE_SIDES: int = 6
const WIRE_STEP: float = 0.75
const FLOOR_WIRE_Y: float = 0.115

static func _seed_for(key: String) -> int:
    var value: int = 379
    for i in range(key.length()):
        value = posmod(value * 131 + key.unicode_at(i), 2147483647)
    return maxi(1, value)


static func _footprint(key: String) -> Vector2:
    # Half-sizes of the ACTUAL FRESH meshes after their per-site 1.55x
    # scale, not the smaller logical HUD/touch footprints.
    match key:
        "NEXUS": return Vector2(3.70, 3.38)
        "LABO": return Vector2(3.14, 3.18)
        "SCRAP_COLLECTOR": return Vector2(1.83, 1.76)
        "SMELTER": return Vector2(1.94, 1.95)
        "RECYCLER": return Vector2(1.96, 1.94)
        "GENERATOR": return Vector2(2.00, 1.88)
        "STORAGE": return Vector2(2.04, 1.85)
        "BUILD_TERMINAL": return Vector2(1.70, 1.67)
    return Vector2(2.00, 2.00)


# Approximate free foreground positions read from the supplied 658px BASE
# screenshot, inverted with the actual overhead camera orientation. These
# are WORLD X/Z targets, not guessed independent random radial positions.
# The stable random seed only jitters a candidate around each safe target.
# Screenshot centers (px): NEXUS 265,590; SMELTER 235,707; RECYCLER 393,718;
# STORAGE 207,949; GENERATOR 593,964; LABO 320,1080;
# SCRAP_COLLECTOR 262,1255; BUILD_TERMINAL 586,1267.
const SCREEN_SAFE_ANCHORS: Dictionary = {
    "NEXUS": Vector2(-11.06, -13.15),
    "SMELTER": Vector2(-6.72, -5.95),
    "RECYCLER": Vector2(-2.21, -8.44),
    "STORAGE": Vector2(2.35, 8.25),
    "GENERATOR": Vector2(13.63, 1.52),
    "LABO": Vector2(11.72, 13.46),
    "SCRAP_COLLECTOR": Vector2(17.88, 24.49),
    "BUILD_TERMINAL": Vector2(26.68, 18.79),
}

const WIRE_GRID: float = 0.82
const ROUTE_BOUNDS: Rect2i = Rect2i(-55, -50, 111, 105)


static func _xz(point: Vector3) -> Vector2:
    return Vector2(point.x, point.z)


static func _local_point(world_at: Vector2, site: Dictionary) -> Vector2:
    var site_at: Vector3 = site["at"]
    var rel := Vector3(world_at.x - site_at.x, 0.0,
        world_at.y - site_at.z)
    var unturn := Basis(Vector3.UP,
        -BaseArchitecture.facility_yaw_radians(str(site["id"])))
    var local: Vector3 = unturn * rel
    return Vector2(local.x, local.z)


static func _inside_site(world_at: Vector2,
        site: Dictionary, margin: float) -> bool:
    var local: Vector2 = _local_point(world_at, site)
    var half: Vector2 = _footprint(str(site["id"]))
    return absf(local.x) < half.x + margin and (
        absf(local.y) < half.y + margin)


static func _prop_obstacles(sites: Array[Dictionary]) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for site in sites:
        var key: String = str(site["id"])
        var origin: Vector3 = site["at"]
        for prop in BaseClutter.props_for(key):
            var spot: Vector2 = prop["at"]
            var world: Vector3 = origin + Vector3(spot.x, 0.0, spot.y)
            var size: Vector2 = BaseClutter.bounds_for(str(prop["kind"])) * (
                float(prop.get("scale", 1.0)))
            # Rotate conservatively: the occupied radius is the longest
            # footprint diagonal, not merely an unrotated axis distance.
            var radius: float = size.length() * 0.52 + 0.25
            result.append({"at": _xz(world), "radius": radius})
    return result


static func _open_location(at: Vector2, all_sites: Array[Dictionary],
        props: Array[Dictionary], placed: Array[Vector2],
        margin: float = 0.64) -> bool:
    for site in all_sites:
        if _inside_site(at, site, margin):
            return false
    for prop in props:
        var center: Vector2 = prop["at"]
        var radius: float = float(prop["radius"]) + 0.66
        if at.distance_squared_to(center) < radius * radius:
            return false
    for other in placed:
        if at.distance_squared_to(other) < 2.05 * 2.05:
            return false
    return true


static func _terminal_gates_open(key: String, at: Vector2, yaw: float,
        sites: Array[Dictionary], props: Array[Dictionary],
        placed: Array[Vector2]) -> bool:
    var turn := Basis(Vector3.UP, yaw)
    var outward: Array[Vector3] = [
        Vector3(-0.36, 0.0, 1.40),
        Vector3(0.36, 0.0, 1.40)]
    if key == "GENERATOR":
        outward.append(Vector3(0.0, 0.0, -1.48))
    for offset in outward:
        var pos: Vector3 = Vector3(at.x, 0.0, at.y) + turn * offset
        if not _open_location(_xz(pos), sites, props, placed, 0.46):
            return false
        # A clear socket end alone is insufficient: every centimetre from
        # the face of the cabinet to the cable's floor exit must stay free.
        var port_offset: Vector3 = Vector3(offset.x, 0.0,
            0.50 if offset.z > 0.0 else -0.49)
        var port: Vector3 = Vector3(at.x, 0.0, at.y) + turn * port_offset
        if not _cable_clear_of_props(_xz(port), _xz(pos), props):
            return false
    return true


static func _height_of(key: String) -> float:
    match key:
        "NEXUS": return 6.7
        "SMELTER": return 5.7
        "LABO": return 4.6
        "GENERATOR": return 4.2
        "STORAGE": return 3.3
        "RECYCLER": return 3.6
        "SCRAP_COLLECTOR": return 3.3
        "BUILD_TERMINAL": return 3.1
    return 3.5


static func _visible_at_camera(at: Vector2, yaw: float, camera: Camera3D,
        all_sites: Array[Dictionary]) -> bool:
    if not is_instance_valid(camera):
        return true
    var view: Vector2 = camera.get_viewport().get_visible_rect().size
    # Check the actual housing volume, not just its top-center pixel.
    # A center-only check can accept a unit whose base or side clips the
    # letterbox / right-side HUD, especially near the screen margins.
    # The 1.16 x 0.96 x 0.95m bounds match _make_substation().
    var housing_basis := Basis(Vector3.UP, yaw)
    var housing_origin := Vector3(at.x, 0.0, at.y)
    for dx in [-0.58, 0.58]:
        for dz in [-0.48, 0.48]:
            for y in [0.0, 0.95]:
                var corner: Vector3 = housing_origin + housing_basis * Vector3(dx, y, dz)
                if camera.is_position_behind(corner):
                    return false
                var pixel: Vector2 = camera.unproject_position(corner)
                if pixel.x < view.x * 0.07 or pixel.x > view.x * 0.93 or (
                        pixel.y < view.y * 0.07 or pixel.y > view.y * 0.95):
                    return false
    # A ground-clear device can still be hidden by the silhouette of a tall
    # building in this oblique camera; check approximate projected roof-to-
    # base rectangles against all physically CLOSER facilities.
    var device_world := Vector3(at.x, 0.48, at.y)
    var device_distance: float = camera.global_position.distance_to(device_world)
    var middle_screen: Vector2 = camera.unproject_position(device_world)
    for site in all_sites:
        var center: Vector3 = site["at"]
        if camera.global_position.distance_to(
                center + Vector3.UP * 1.6) >= device_distance - 0.35:
            continue
        var half: Vector2 = _footprint(str(site["id"]))
        var site_basis := Basis(Vector3.UP,
            BaseArchitecture.facility_yaw_radians(str(site["id"])))
        var low := Vector2(100000.0, 100000.0)
        var high := Vector2(-100000.0, -100000.0)
        for dx in [-1.0, 1.0]:
            for dz in [-1.0, 1.0]:
                for h in [0.0, _height_of(str(site["id"]))]:
                    var corner: Vector3 = center + site_basis * Vector3(
                        dx * half.x, h, dz * half.y)
                    var screen: Vector2 = camera.unproject_position(corner)
                    low = low.min(screen)
                    high = high.max(screen)
        if Rect2(low - Vector2.ONE * 4.0,
                high - low + Vector2.ONE * 8.0).has_point(middle_screen):
            return false
    return true


static func _locate_device(key: String, all_sites: Array[Dictionary],
        props: Array[Dictionary], placed: Array[Vector2],
        camera: Camera3D, logistics: Node3D = null) -> Dictionary:
    var goal: Vector2 = SCREEN_SAFE_ANCHORS[key]
    var rng := RandomNumberGenerator.new()
    rng.seed = _seed_for("SERA_POWER_VISIBLE_" + key)
    # Front terminals face the BASE camera while preserving +-45 degrees
    # of stable per-unit random angle; ports no longer point into a wall.
    var yaw: float = deg_to_rad(37.67 + rng.randf_range(-45.0, 45.0))
    # Start at the screenshot-approved gap. Keep small random differences
    # without jumping to the roof/behind another machine.
    for attempt in range(160):
        var turn: float = rng.randf_range(-PI, PI)
        var radius: float = (
            0.0 if attempt == 0 else (
            0.25 + float(attempt / 16) * 0.38 +
            rng.randf_range(0.0, 0.48)))
        var test: Vector2 = goal + Vector2(cos(turn), sin(turn)) * radius
        if is_instance_valid(logistics) and not bool(logistics.call("power_device_clear", test)):
            continue
        if not _open_location(test, all_sites, props, placed):
            continue
        if not _terminal_gates_open(key, test, yaw,
                all_sites, props, placed):
            continue
        if not _visible_at_camera(test, yaw, camera, all_sites):
            continue
        var site: Dictionary = {}
        for entry in all_sites:
            if str(entry["id"]) == key:
                site = entry
                break
        var world := Vector3(test.x, 0.0, test.y)
        var local: Vector2 = _local_point(test, site)
        return {"at": world, "local": Vector3(local.x, 0.0, local.y),
            "yaw": yaw, "screen_center": camera.unproject_position(
                world + Vector3.UP * 0.94) if is_instance_valid(camera)
                else Vector2.ZERO}
    # Never fall back inside machinery or off screen. Search a bounded
    # expanded foreground arc; an unplaceable unit is reported, not hidden.
    for ring in range(10, 30):
        for sample in range(32):
            var phi: float = TAU * float(sample) / 32.0
            var test: Vector2 = goal + Vector2(cos(phi), sin(phi)) * (
                float(ring) * 0.33)
            if is_instance_valid(logistics) and not bool(logistics.call("power_device_clear", test)):
                continue
            if not _open_location(test, all_sites, props, placed):
                continue
            if not _terminal_gates_open(key, test, yaw,
                    all_sites, props, placed):
                continue
            if not _visible_at_camera(test, yaw, camera, all_sites):
                continue
            for site in all_sites:
                if str(site["id"]) != key:
                    continue
                var local: Vector2 = _local_point(test, site)
                return {"at": Vector3(test.x, 0.0, test.y),
                    "local": Vector3(local.x, 0.0, local.y),
                    "yaw": yaw}
    push_warning("BASE power unit cannot be placed safely for " + key)
    return {}


static func _device_port(items: Dictionary, color: String,
        origin: Vector3, basis: Basis, at: Vector3,
        dimensions: Vector3) -> void:
    (items[color] as Array).append(Transform3D(
        basis.scaled_local(dimensions), origin + basis * at))


static func _make_substation(items: Dictionary, world_at: Vector3,
        yaw: float, index: int) -> Dictionary:
    var turn := Basis(Vector3.UP, yaw)
    _device_port(items, "rubber", world_at, turn,
        Vector3(0.0, 0.045, 0.0), Vector3(1.16, 0.11, 0.96))
    _device_port(items, "metal", world_at, turn,
        Vector3(0.0, 0.48, 0.0), Vector3(0.91, 0.72, 0.72))
    _device_port(items, "rim", world_at, turn,
        Vector3(0.0, 0.89, 0.0), Vector3(1.04, 0.12, 0.82))
    _device_port(items, "rim", world_at, turn,
        Vector3(0.0, 0.18, 0.39), Vector3(0.94, 0.10, 0.10))
    for i in range(3):
        _device_port(items, "vent", world_at, turn,
            Vector3(-0.26 + float(i) * 0.26, 0.58, 0.375),
            Vector3(0.105, 0.28, 0.044))
    for sign in [-1.0, 1.0]:
        _device_port(items, "rim", world_at, turn,
            Vector3(sign * 0.47, 0.54, 0.075),
            Vector3(0.075, 0.35, 0.52))
    _device_port(items, "light", world_at, turn,
        Vector3(0.0, 0.78, 0.392), Vector3(0.24, 0.075, 0.031))
    _device_port(items, "light", world_at, turn,
        Vector3(0.0, 0.91, 0.0), Vector3(0.32, 0.022, 0.40))
    # The two real cable sockets point toward the power terminal and site.
    _device_port(items, "socket", world_at, turn,
        Vector3(-0.36, 0.40, 0.405), Vector3(0.20, 0.19, 0.11))
    _device_port(items, "socket", world_at, turn,
        Vector3(0.36, 0.40, 0.405), Vector3(0.20, 0.19, 0.11))
    return {
        "input": world_at + turn * Vector3(-0.36, 0.40, 0.48),
        "output": world_at + turn * Vector3(0.36, 0.40, 0.48),
        "input_gate": world_at + turn * Vector3(-0.36,
            FLOOR_WIRE_Y, 1.40),
        "output_gate": world_at + turn * Vector3(0.36,
            FLOOR_WIRE_Y, 1.40),
        "world": world_at, "index": index
    }


static func _cable_clear_of_props(from_at: Vector2,
        to_at: Vector2, props: Array[Dictionary]) -> bool:
    var segment: Vector2 = to_at - from_at
    var squared: float = segment.length_squared()
    if squared < 0.00001:
        return true
    for entry in props:
        var pos: Vector2 = entry["at"]
        var t: float = clampf((pos - from_at).dot(segment) / squared,
            0.0, 1.0)
        var nearest: Vector2 = from_at + segment * t
        var radius: float = float(entry["radius"]) + 0.23
        if nearest.distance_squared_to(pos) < radius * radius:
            return false
    return true


static func _facility_socket(items: Dictionary, key: String,
        origin: Vector3, device_local: Vector3,
        props: Array[Dictionary]) -> Dictionary:
    var half: Vector2 = _footprint(key)
    var near := Vector3(
        clampf(device_local.x, -half.x, half.x), 0.60,
        clampf(device_local.z, -half.y, half.y))
    # The chosen side is nearest the new device, but its actual receiver
    # point slides ALONG that wall to stay out of nearby loose scrap.
    var panel_angle: float = 0.0
    var side_on_x: bool = (absf(device_local.x / half.x) >
        absf(device_local.z / half.y))
    if side_on_x:
        near.x = signf(device_local.x) * (half.x + 0.20)
        panel_angle = PI * 0.5 * signf(device_local.x)
    else:
        near.z = signf(device_local.z) * (half.y + 0.20)
        if device_local.z < 0.0:
            panel_angle = PI
    var body_yaw := Basis(Vector3.UP,
        BaseArchitecture.facility_yaw_radians(key))
    var panel_basis := Basis(Vector3.UP,
        BaseArchitecture.facility_yaw_radians(key) + panel_angle)
    var normal: Vector3 = panel_basis * Vector3(0.0, 0.0, 1.0)
    var chosen_world: Vector3 = origin + body_yaw * near
    var chosen_gate: Vector3 = chosen_world + normal * 1.50
    chosen_gate.y = FLOOR_WIRE_Y
    for drift in [0.0, 0.46, -0.46, 0.92, -0.92, 1.33, -1.33]:
        var sample: Vector3 = near
        var shifted: float = float(drift)
        if side_on_x:
            sample.z = clampf(near.z + shifted,
                -half.y + 0.25, half.y - 0.25)
        else:
            sample.x = clampf(near.x + shifted,
                -half.x + 0.25, half.x - 0.25)
        var world_at: Vector3 = origin + body_yaw * sample
        var gate: Vector3 = world_at + normal * 1.50
        gate.y = FLOOR_WIRE_Y
        if not _cable_clear_of_props(_xz(world_at),
                _xz(gate), props):
            continue
        chosen_world = world_at
        chosen_gate = gate
        break
    _device_port(items, "socket", chosen_world, panel_basis,
        Vector3.ZERO, Vector3(0.29, 0.28, 0.18))
    _device_port(items, "light", chosen_world, panel_basis,
        Vector3(0.0, 0.085, 0.096), Vector3(0.16, 0.055, 0.023))
    return {
        "port": chosen_world + normal * 0.12,
        "gate": chosen_gate
    }


static func _material(tint: Color, luminous: bool = false) -> StandardMaterial3D:
    var surface := StandardMaterial3D.new()
    surface.albedo_color = tint
    surface.metallic = 0.20 if luminous else 0.32
    surface.roughness = 0.75
    if luminous:
        surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        surface.emission_enabled = true
        surface.emission = tint
        surface.emission_energy_multiplier = 2.10
    return surface


static func _build_devices(parent: Node3D, items: Dictionary) -> void:
    var colors: Dictionary = {
        "rubber": Color("#24303a"),
        "metal": Color("#506476"),
        "rim": Color("#758592"),
        "vent": Color("#263743"),
        "socket": Color("#3d6071"),
        "light": Color("#a7eaff")
    }
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    # Each opaque device and plug uses the SAME RGB-ID role 3 as all other
    # clutter. No second convex-angle ribbon pass is generated.
    for palette in colors.keys():
        var transforms: Array = items[palette]
        if transforms.is_empty():
            continue
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = cube
        multi.instance_count = transforms.size()
        var low := Vector3(10000.0, 10000.0, 10000.0)
        var high := Vector3(-10000.0, -10000.0, -10000.0)
        for i in range(transforms.size()):
            var pose: Transform3D = transforms[i]
            multi.set_instance_transform(i, pose)
            low = low.min(pose.origin - Vector3(1.2, 1.2, 1.2))
            high = high.max(pose.origin + Vector3(1.2, 1.2, 1.2))
        multi.custom_aabb = AABB(low, high - low)
        var draw := MultiMeshInstance3D.new()
        draw.name = "PowerDistributor_" + str(palette)
        draw.multimesh = multi
        draw.material_override = _material(
            colors[palette], palette == "light")
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        draw.set_meta("sera_outline_role", "clutter")
        # Native StandardMaterial3D is needed for the shared visible-ID
        # compositor to classify each solid instanced device as role 3.
        draw.set_meta("sera_preserve_authored_material", true)
        if palette == "light":
            # Light cores are physically opaque and keep role 7 so a black
            # clutter outline cannot cover their tiny luminous surface.
            draw.set_meta("sera_outline_occluder_only", true)
            draw.set_meta("sera_outline_emissive_protect", true)
        parent.add_child(draw)


# Pathfinding uses one temporary lightweight AStarGrid2D at scene build
# time. Closed model footprints, every clutter group and each new substation
# are rasterized once. All final cables remain ordinary static ArrayMesh.
static func _cell_of(pos: Vector2) -> Vector2i:
    return Vector2i(roundi(pos.x / WIRE_GRID),
        roundi(pos.y / WIRE_GRID))


static func _point_of(id: Vector2i) -> Vector3:
    return Vector3(float(id.x) * WIRE_GRID, FLOOR_WIRE_Y,
        float(id.y) * WIRE_GRID)


static func _mark_site(grid: AStarGrid2D, site: Dictionary) -> void:
    var center: Vector3 = site["at"]
    var half: Vector2 = _footprint(str(site["id"]))
    var full_radius: float = half.length() + 0.65
    var lower: Vector2i = _cell_of(
        Vector2(center.x - full_radius, center.z - full_radius))
    var upper: Vector2i = _cell_of(
        Vector2(center.x + full_radius, center.z + full_radius))
    for x in range(lower.x, upper.x + 1):
        for z in range(lower.y, upper.y + 1):
            var id := Vector2i(x, z)
            if not ROUTE_BOUNDS.has_point(id):
                continue
            if _inside_site(Vector2(float(x) * WIRE_GRID,
                    float(z) * WIRE_GRID), site, 0.48):
                grid.set_point_solid(id, true)


static func _mark_circle(grid: AStarGrid2D, center: Vector2,
        radius: float) -> void:
    var lower: Vector2i = _cell_of(center - Vector2.ONE * radius)
    var upper: Vector2i = _cell_of(center + Vector2.ONE * radius)
    var r2: float = radius * radius
    for x in range(lower.x, upper.x + 1):
        for z in range(lower.y, upper.y + 1):
            var id := Vector2i(x, z)
            if not ROUTE_BOUNDS.has_point(id):
                continue
            if Vector2(float(x) * WIRE_GRID,
                    float(z) * WIRE_GRID).distance_squared_to(center) < r2:
                grid.set_point_solid(id, true)


static func _obstacle_grid(sites: Array[Dictionary],
        props: Array[Dictionary], devices: Array[Vector2]) -> AStarGrid2D:
    var grid := AStarGrid2D.new()
    grid.region = ROUTE_BOUNDS
    grid.cell_size = Vector2.ONE * WIRE_GRID
    grid.diagonal_mode = (
        AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES)
    grid.update()
    for site in sites:
        _mark_site(grid, site)
    for prop in props:
        _mark_circle(grid, prop["at"], float(prop["radius"]) + 0.21)
    for device in devices:
        _mark_circle(grid, device, 0.83)
    return grid


static func _segment_open(grid: AStarGrid2D, a: Vector3,
        b: Vector3) -> bool:
    var distance: float = a.distance_to(b)
    var samples: int = maxi(1, ceili(distance / (WIRE_GRID * 0.28)))
    for i in range(samples + 1):
        var point: Vector3 = a.lerp(b, float(i) / float(samples))
        var id: Vector2i = _cell_of(_xz(point))
        if not ROUTE_BOUNDS.has_point(id) or grid.is_point_solid(id):
            return false
    return true


static func _nearest_open(grid: AStarGrid2D,
        point: Vector3) -> Vector2i:
    var wanted: Vector2i = _cell_of(_xz(point))
    if ROUTE_BOUNDS.has_point(wanted) and not grid.is_point_solid(wanted):
        return wanted
    var best := Vector2i(100000, 100000)
    var best_dist: float = INF
    for radius in range(1, 13):
        for x in range(wanted.x - radius, wanted.x + radius + 1):
            for z in range(wanted.y - radius, wanted.y + radius + 1):
                var cell := Vector2i(x, z)
                if maxi(abs(cell.x - wanted.x),
                        abs(cell.y - wanted.y)) != radius:
                    continue
                if not ROUTE_BOUNDS.has_point(cell) or (
                        grid.is_point_solid(cell)):
                    continue
                var position: Vector3 = _point_of(cell)
                if not _segment_open(grid, point, position):
                    continue
                var dist: float = point.distance_squared_to(position)
                if dist < best_dist:
                    best = cell
                    best_dist = dist
        if best_dist < INF:
            return best
    return wanted


static func _push_path_point(result: PackedVector3Array,
        point: Vector3) -> void:
    if result.is_empty() or result[result.size() - 1].distance_to(point) > 0.045:
        result.append(point)


# Keep the ENTIRE cable tube inside the A* free corridor, not just
# its centre line. The same clearance gate is applied to every smooth
# segment and to every possible bend before a curve is accepted.
static func _cable_segment_clear(grid: AStarGrid2D,
        a: Vector3, b: Vector3) -> bool:
    if not _segment_open(grid, a, b):
        return false
    var movement: Vector3 = b - a
    movement.y = 0.0
    if movement.length_squared() < 0.0001:
        return true
    var side: Vector3 = Vector3(-movement.z, 0.0,
        movement.x).normalized() * 0.14
    return _segment_open(grid, a + side, b + side) and (
        _segment_open(grid, a - side, b - side))


# Power cords are installed along short, deliberate paths. Do not impose
# alternating sideways waves on every clear section: the previous bell
# displacement made cables look like suspended snakes across the yard.
# Only actual A* route corners receive a modest, collision-gated bend.
static func _smooth_floor_route(grid: AStarGrid2D,
        waypoints: PackedVector3Array, _label: String) -> PackedVector3Array:
    if waypoints.size() < 3:
        return waypoints
    var result := PackedVector3Array()
    _push_path_point(result, waypoints[0])
    for i in range(1, waypoints.size() - 1):
        var previous: Vector3 = waypoints[i - 1]
        var corner: Vector3 = waypoints[i]
        var following: Vector3 = waypoints[i + 1]
        var incoming: Vector3 = corner - previous
        var outgoing: Vector3 = following - corner
        var in_length: float = incoming.length()
        var out_length: float = outgoing.length()
        if in_length < 0.22 or out_length < 0.22:
            _push_path_point(result, corner)
            continue
        incoming /= in_length
        outgoing /= out_length
        var alignment: float = incoming.dot(outgoing)
        # A sufficiently straight run should actually remain straight.
        if alignment > 0.985 or alignment < -0.90:
            _push_path_point(result, corner)
            continue
        var maximum: float = minf(0.92,
            minf(in_length, out_length) * 0.36)
        var rounded: bool = false
        # The arc is strictly inside the original corner's neighbouring
        # route segments. Try a smaller radius in narrow machine aisles.
        for factor in [1.0, 0.67, 0.38]:
            var radius: float = maximum * float(factor)
            if radius < 0.11:
                continue
            var entry: Vector3 = corner - incoming * radius
            var exit: Vector3 = corner + outgoing * radius
            var current: Vector3 = result[result.size() - 1]
            if not _cable_segment_clear(grid, current, entry):
                continue
            var curve := PackedVector3Array()
            curve.append(entry)
            var segments: int = maxi(5, ceili(radius * 2.0 / 0.21))
            var safe: bool = true
            for j in range(1, segments + 1):
                var t: float = float(j) / float(segments)
                var u: float = 1.0 - t
                var point: Vector3 = entry * (u * u) + (
                    corner * (2.0 * u * t)) + exit * (t * t)
                if not _cable_segment_clear(
                        grid, curve[curve.size() - 1], point):
                    safe = false
                    break
                curve.append(point)
            if not safe:
                continue
            _push_path_point(result, entry)
            for j in range(1, curve.size()):
                _push_path_point(result, curve[j])
            rounded = true
            break
        if not rounded:
            # Keep the proven non-penetrating A* waypoint in a tight gap.
            _push_path_point(result, corner)
    _push_path_point(result, waypoints[waypoints.size() - 1])
    return result


# A power cable should exit its socket HORIZONTALLY before sinking onto the
# floor. The old vertical-at-port segment visibly pierced the machine base,
# then snapped through a sharp right angle to the ground cable. This shallow
# cubic drop is fixed to the actual socket/gate coordinates.
static func _socket_drop(port: Vector3,
        gate: Vector3) -> PackedVector3Array:
    var curve := PackedVector3Array()
    var ground_direction: Vector3 = gate - port
    ground_direction.y = 0.0
    var length: float = ground_direction.length()
    var controls_a: Vector3 = port + ground_direction * 0.28
    controls_a.y = port.y + 0.025
    var controls_b: Vector3 = gate - ground_direction * 0.26
    controls_b.y = FLOOR_WIRE_Y + 0.035
    var steps: int = maxi(6, ceili(length / 0.23))
    for j in range(steps + 1):
        var t: float = float(j) / float(steps)
        var u: float = 1.0 - t
        curve.append(port * (u * u * u) +
            controls_a * (3.0 * u * u * t) +
            controls_b * (3.0 * u * t * t) +
            gate * (t * t * t))
    return curve


# Preserve weighted avoidance when removing intermediate grid points.
# A straight shortcut must not replace a short transverse crossing with
# a long cable run down the logistics road.
static func _shortcut_cost(grid: AStarGrid2D, a: Vector3, b: Vector3) -> float:
    var distance: float = a.distance_to(b)
    var count: int = maxi(1, ceili(distance / (WIRE_GRID * 0.4)))
    var cost: float = 0.0
    for i in range(count):
        var p: Vector3 = a.lerp(b, (float(i) + 0.5) / float(count))
        var cell: Vector2i = _cell_of(_xz(p))
        if not ROUTE_BOUNDS.has_point(cell) or grid.is_point_solid(cell):
            return INF
        cost += grid.get_point_weight_scale(cell) * distance / float(count)
    return cost


static func _routed_cable(grid: AStarGrid2D, from_at: Vector3,
        from_gate: Vector3, to_gate: Vector3,
        to_at: Vector3, label: String) -> PackedVector3Array:
    var begin: Vector2i = _nearest_open(grid, from_gate)
    var finish: Vector2i = _nearest_open(grid, to_gate)
    if not ROUTE_BOUNDS.has_point(begin) or (
            not ROUTE_BOUNDS.has_point(finish)):
        push_warning("BASE power cable out of route bounds: " + label)
        return PackedVector3Array()
    if grid.is_point_solid(begin) or grid.is_point_solid(finish):
        push_warning("BASE power cable gate blocked: " + label)
        return PackedVector3Array()
    var ids: Array[Vector2i] = grid.get_id_path(begin, finish)
    if ids.is_empty():
        push_warning("BASE power cable route blocked: " + label)
        return PackedVector3Array()
    # End sockets and their vertical exits stay exact; the safe ground
    # path between the two outward-facing gates can bend and curve.
    var floor_waypoints := PackedVector3Array()
    _push_path_point(floor_waypoints, from_gate)
    _push_path_point(floor_waypoints, _point_of(begin))
    # Retain the original obstacle-aware line-of-sight simplification. Do
    # not smooth raw A* cells into an unconstrained spline.
    var cumulative: Array[float] = [0.0]
    for j in range(1, ids.size()):
        cumulative.append(cumulative[-1] + _point_of(ids[j - 1]).distance_to(_point_of(ids[j])) * (grid.get_point_weight_scale(ids[j - 1]) + grid.get_point_weight_scale(ids[j])) * 0.5)
    var index: int = 0
    while index < ids.size() - 1:
        var next: int = ids.size() - 1
        while next > index + 1:
            if _segment_open(grid, _point_of(ids[index]), _point_of(ids[next])) and _shortcut_cost(grid, _point_of(ids[index]), _point_of(ids[next])) <= (cumulative[next] - cumulative[index]) * 1.06:
                break
            next -= 1
        _push_path_point(floor_waypoints, _point_of(ids[next]))
        index = next
    _push_path_point(floor_waypoints, to_gate)
    var curved: PackedVector3Array = _smooth_floor_route(
        grid, floor_waypoints, label)
    var points := PackedVector3Array()
    # Start/end in the actual sockets; shallow, outward-curving drops are
    # never deformed by the floor cable's obstacle-routing simplification.
    for point in _socket_drop(from_at, from_gate):
        _push_path_point(points, point)
    for point in curved:
        _push_path_point(points, point)
    var landing: PackedVector3Array = _socket_drop(to_at, to_gate)
    for j in range(landing.size() - 1, -1, -1):
        _push_path_point(points, landing[j])
    # A nonzero cell weight discourages later power lines from lying
    # directly atop the same geometric cable (but permits intersections).
    for id in ids:
        if ROUTE_BOUNDS.has_point(id) and not grid.is_point_solid(id):
            grid.set_point_weight_scale(id, 1.65)
    return points


static func _append_tube(mesh_arrays: Dictionary, points: PackedVector3Array,
        radius: float, y_lift: float) -> void:
    if points.size() < 2:
        return
    var vertices: PackedVector3Array = mesh_arrays["vertices"]
    var normals: PackedVector3Array = mesh_arrays["normals"]
    var indices: PackedInt32Array = mesh_arrays["indices"]
    var first: int = vertices.size()
    for i in range(points.size()):
        var before: Vector3 = points[maxi(0, i - 1)]
        var after: Vector3 = points[mini(points.size() - 1, i + 1)]
        var tangent: Vector3 = (after - before).normalized()
        if tangent.length_squared() < 0.001:
            tangent = Vector3.FORWARD
        var across: Vector3 = tangent.cross(Vector3.UP)
        if across.length_squared() < 0.001:
            across = tangent.cross(Vector3.FORWARD)
        across = across.normalized()
        var above: Vector3 = across.cross(tangent).normalized()
        for side in range(WIRE_SIDES):
            var theta: float = TAU * float(side) / float(WIRE_SIDES)
            var normal: Vector3 = across * cos(theta) + above * sin(theta)
            vertices.append(points[i] + Vector3.UP * y_lift + normal * radius)
            normals.append(normal)
    for i in range(points.size() - 1):
        for side in range(WIRE_SIDES):
            var a: int = first + i * WIRE_SIDES + side
            var b: int = first + i * WIRE_SIDES + (side + 1) % WIRE_SIDES
            var c: int = a + WIRE_SIDES
            var d: int = b + WIRE_SIDES
            indices.append(a)
            indices.append(b)
            indices.append(c)
            indices.append(b)
            indices.append(d)
            indices.append(c)
    mesh_arrays["vertices"] = vertices
    mesh_arrays["normals"] = normals
    mesh_arrays["indices"] = indices


static func _finish_cables(parent: Node3D,
        main_wires: Dictionary, stripes: Dictionary) -> void:
    var body_vertices: PackedVector3Array = main_wires["vertices"]
    if body_vertices.is_empty():
        return
    var mesh := ArrayMesh.new()
    for record in [
            {"data": main_wires, "color": Color("#36434d")},
            {"data": stripes, "color": Color("#648c9f")}]:
        var data: Dictionary = record["data"]
        var arrays: Array = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
        arrays[Mesh.ARRAY_NORMAL] = data["normals"]
        arrays[Mesh.ARRAY_INDEX] = data["indices"]
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        var index: int = mesh.get_surface_count() - 1
        mesh.surface_set_material(index, _material(record["color"]))
    var cables := MeshInstance3D.new()
    cables.name = "DistributionPowerCords"
    cables.mesh = mesh
    cables.set_meta("sera_outline_role", "clutter")
    cables.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(cables)


static func _wire_data() -> Dictionary:
    return {"vertices": PackedVector3Array(),
        "normals": PackedVector3Array(), "indices": PackedInt32Array()}


static func build(parent: Node3D, nexus_origin: Vector3,
        specs: Array, camera: Camera3D = null, logistics: Node3D = null) -> Node3D:
    var network := Node3D.new()
    network.name = "BasePowerDistribution"
    network.set_meta("sera_outline_role", "clutter")
    parent.add_child(network)
    var items: Dictionary = {
        "rubber": [], "metal": [], "rim": [],
        "vent": [], "socket": [], "light": []}
    var wires: Dictionary = _wire_data()
    var traces: Dictionary = _wire_data()
    var all_sites: Array[Dictionary] = [{
        "id": "NEXUS", "at": nexus_origin}]
    all_sites.append_array(specs)
    var props: Array[Dictionary] = _prop_obstacles(all_sites)
    for child in parent.get_children():
        if child is Node3D and str(child.name).begins_with("ScrapPile_"):
            var pile: Node3D = child
            props.append({"at": _xz(pile.position), "radius": 1.15 * float(pile.get_meta("visual_scale", 1.26))})
    if is_instance_valid(logistics):
        props.append_array(logistics.call("cable_dock_obstacles"))
    var cable_paths: Array[Dictionary] = []
    var board_path := PackedVector3Array()
    for i in range(PowerBoard.CABLE_SEGMENTS + 1):
        board_path.append(PowerBoard.cable_point(float(i) / float(PowerBoard.CABLE_SEGMENTS)))
    cable_paths.append({"points": board_path, "radius": 0.145})
    var placed: Array[Vector2] = []
    # In the screenshot, the old GRID plug was behind the generator housing.
    # Move the visible seven-port manifold to the foreground gap, then
    # route one short exposed lead FROM that original live cable endpoint.
    var hub_pose: Dictionary = _locate_device(
        "GENERATOR", all_sites, props, placed, camera, logistics)
    if hub_pose.is_empty():
        _build_crossing_ramps(network, cable_paths, logistics)
        return network
    var hub: Vector3 = hub_pose["at"]
    var hub_turn := Basis(Vector3.UP, float(hub_pose["yaw"]))
    placed.append(_xz(hub))
    _device_port(items, "rubber", hub, hub_turn,
        Vector3(0.0, 0.04, 0.0), Vector3(1.46, 0.12, 0.82))
    _device_port(items, "metal", hub, hub_turn,
        Vector3(0.0, 0.36, 0.0), Vector3(1.38, 0.62, 0.70))
    _device_port(items, "rim", hub, hub_turn,
        Vector3(0.0, 0.70, 0.0), Vector3(1.48, 0.10, 0.76))
    _device_port(items, "socket", hub, hub_turn,
        Vector3(0.0, 0.36, -0.405), Vector3(0.23, 0.19, 0.12))
    for i in range(7):
        _device_port(items, "socket", hub, hub_turn,
            Vector3((float(i) - 3.0) * 0.18, 0.32, 0.405),
            Vector3(0.15, 0.18, 0.09))
    _device_port(items, "light", hub, hub_turn,
        Vector3(0.0, 0.77, 0.0), Vector3(0.60, 0.025, 0.38))
    var endpoints: Array[Dictionary] = []
    for site in all_sites:
        var key: String = str(site["id"])
        if key == "GENERATOR":
            continue
        var origin: Vector3 = site["at"]
        var pose: Dictionary = _locate_device(
            key, all_sites, props, placed, camera, logistics)
        if pose.is_empty():
            continue
        var world_at: Vector3 = pose["at"]
        placed.append(_xz(world_at))
        var device: Dictionary = _make_substation(items,
            world_at, float(pose["yaw"]), endpoints.size())
        var receiver: Dictionary = _facility_socket(
            items, key, origin, pose["local"], props)
        endpoints.append({"key": key, "device": device,
            "socket": receiver})
    # All assets now exist in world space and the route grid reserves the
    # rotated facilities, existing clutter AND new small power stations.
    var route_grid: AStarGrid2D = _obstacle_grid(
        all_sites, props, placed)
    if is_instance_valid(logistics):
        # Route cables outside the vehicle corridor wherever feasible;
        # short transverse crossings remain possible.
        for x in range(ROUTE_BOUNDS.position.x, ROUTE_BOUNDS.end.x):
            for z in range(ROUTE_BOUNDS.position.y, ROUTE_BOUNDS.end.y):
                var c := Vector2i(x, z)
                if not route_grid.is_point_solid(c) and bool(logistics.call("road_at", _xz(_point_of(c)))):
                    route_grid.set_point_weight_scale(c, 4.5)
    var old_plug: Vector3 = PowerBoard.cable_point(0.0)
    var board_gate: Vector3 = old_plug + Vector3(1.10, 0.0, 0.05)
    board_gate.y = FLOOR_WIRE_Y
    var hub_in: Vector3 = hub + hub_turn * Vector3(
        0.0, 0.36, -0.49)
    var hub_in_gate: Vector3 = hub + hub_turn * Vector3(
        0.0, FLOOR_WIRE_Y, -1.48)
    var junction: PackedVector3Array = _routed_cable(
        route_grid, old_plug, board_gate, hub_in_gate,
        hub_in, "GENERATOR TO MANIFOLD")
    cable_paths.append({"points": junction, "radius": 0.070})
    _append_tube(wires, junction, 0.070, 0.0)
    _append_tube(traces, junction, 0.019, 0.051)
    for i in range(endpoints.size()):
        var record: Dictionary = endpoints[i]
        var key: String = str(record["key"])
        var device: Dictionary = record["device"]
        var receiver: Dictionary = record["socket"]
        var offset: float = (float(i) - 3.0) * 0.18
        var feed_at: Vector3 = hub + hub_turn * Vector3(
            offset, 0.32, 0.50)
        var feed_gate: Vector3 = hub + hub_turn * Vector3(
            offset, FLOOR_WIRE_Y, 1.48)
        var feed: PackedVector3Array = _routed_cable(
            route_grid, feed_at, feed_gate, device["input_gate"],
            device["input"], key + " FEED")
        var delivery: PackedVector3Array = _routed_cable(
            route_grid, device["output"], device["output_gate"],
            receiver["gate"], receiver["port"], key + " DELIVERY")
        for cable in [feed, delivery]:
            cable_paths.append({"points": cable, "radius": 0.070})
            _append_tube(wires, cable, 0.070, 0.0)
            _append_tube(traces, cable, 0.019, 0.051)
    # Stable occupied power-device centers for the outdoor logistics grid.
    network.set_meta("logistics_obstacles", placed.duplicate())
    _build_devices(network, items)
    _finish_cables(network, wires, traces)
    _build_crossing_ramps(network, cable_paths, logistics)
    # Recomputed only at scene construction / user-requested layout reset:
    # no pathfinding or coordinate randomization in the render loop.
    return network


static func _build_crossing_ramps(network: Node3D, paths: Array[Dictionary], logistics: Node3D) -> void:
    if not is_instance_valid(logistics):
        return
    var ramps := CrossingRamps.new()
    ramps.name = "CableCrossingRamps"
    network.add_child(ramps)
    ramps.build(paths, logistics)
