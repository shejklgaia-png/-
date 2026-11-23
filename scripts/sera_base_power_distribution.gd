extends RefCounted
## BASE physical power network. Seven local substations connect to the
## GENERATOR control terminal, then to each consumer's exterior socket.
## Placement is seeded and stable, independent of time/frame rate.
## Solid equipment and cables use the same role-3 visible-ID ink as clutter:
## inner 1px, outer 1px, contacts 1px, convex corners 1px.
## No added lights or GPU simulation.
const BaseClutter = preload("res://scripts/sera_base_clutter.gd")
const BaseFacilityInk = preload("res://scripts/sera_base_facility_outlines.gd")
const PowerBoard = preload("res://scripts/sera_base_power_board.gd")
const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")

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
        var spin := Basis(Vector3.UP,
            BaseArchitecture.facility_yaw_radians(key))
        for prop in BaseClutter.props_for(key):
            var spot: Vector2 = prop["at"]
            var world: Vector3 = origin + spin * Vector3(spot.x, 0.0, spot.y)
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


static func _visible_at_camera(at: Vector2, camera: Camera3D,
        all_sites: Array[Dictionary]) -> bool:
    if not is_instance_valid(camera):
        return true
    var top := Vector3(at.x, 0.94, at.y)
    if camera.is_position_behind(top):
        return false
    var pixel: Vector2 = camera.unproject_position(top)
    var view: Vector2 = camera.get_viewport().get_visible_rect().size
    # Reserve a small on-screen margin for the entire 1.16m housing. The
    # screenshot has black top/bottom bars and right-side HUD buttons.
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
        var yaw := Basis(Vector3.UP,
            BaseArchitecture.facility_yaw_radians(str(site["id"])))
        var low := Vector2(100000.0, 100000.0)
        var high := Vector2(-100000.0, -100000.0)
        for dx in [-1.0, 1.0]:
            for dz in [-1.0, 1.0]:
                for h in [0.0, _height_of(str(site["id"]))]:
                    var corner: Vector3 = center + yaw * Vector3(
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
        camera: Camera3D) -> Dictionary:
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
        if not _open_location(test, all_sites, props, placed):
            continue
        if not _visible_at_camera(test, camera, all_sites):
            continue
        var site: Dictionary = {}
        for entry in all_sites:
            if str(entry["id"]) == key:
                site = entry
                break
        var center: Vector3 = site["at"]
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
            if not _open_location(test, all_sites, props, placed):
                continue
            if not _visible_at_camera(test, camera, all_sites):
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


static func _facility_socket(items: Dictionary, key: String,
        origin: Vector3, device_local: Vector3) -> Dictionary:
    var half: Vector2 = _footprint(key)
    var near := Vector3(
        clampf(device_local.x, -half.x, half.x),
        0.60, clampf(device_local.z, -half.y, half.y))
    # Place the receiving socket on the actual nearest side of the building.
    var panel_angle: float = 0.0
    if absf(device_local.x / half.x) > absf(device_local.z / half.y):
        near.x = signf(device_local.x) * half.x
        panel_angle = PI * 0.5 * signf(device_local.x)
    else:
        near.z = signf(device_local.z) * half.y
        if device_local.z < 0.0:
            panel_angle = PI
    var body_yaw := Basis(Vector3.UP,
        BaseArchitecture.facility_yaw_radians(key))
    var panel_basis := Basis(Vector3.UP,
        BaseArchitecture.facility_yaw_radians(key) + panel_angle)
    var world_at: Vector3 = origin + body_yaw * near
    _device_port(items, "socket", world_at, panel_basis,
        Vector3.ZERO, Vector3(0.29, 0.28, 0.18))
    _device_port(items, "light", world_at, panel_basis,
        Vector3(0.0, 0.085, 0.096), Vector3(0.16, 0.055, 0.023))
    var normal: Vector3 = panel_basis * Vector3(0.0, 0.0, 1.0)
    var gate: Vector3 = world_at + normal * 1.35
    gate.y = FLOOR_WIRE_Y
    return {
        "port": world_at + normal * 0.12,
        "gate": gate
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
    # A single 1px convex-angle pass across all non-emissive substation
    # housings, plugs and breaker modules; no per-box overlay meshes.
    var solid_crease_poses: Array = []
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
            if palette != "light":
                solid_crease_poses.append(pose)
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
    var corner_mesh: ArrayMesh = BaseFacilityInk.crease_for("cube", cube)
    if corner_mesh != null and not solid_crease_poses.is_empty():
        var corners := MultiMesh.new()
        corners.transform_format = MultiMesh.TRANSFORM_3D
        corners.mesh = corner_mesh
        corners.instance_count = solid_crease_poses.size()
        for i in range(solid_crease_poses.size()):
            corners.set_instance_transform(i, solid_crease_poses[i])
        var ink := MultiMeshInstance3D.new()
        ink.name = "PowerDistributorConvex1px"
        ink.multimesh = corners
        ink.material_override = BaseFacilityInk.clutter_crease_material()
        ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        ink.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
        ink.extra_cull_margin = 0.20
        ink.set_meta("FX_NO_OUTLINE", true)
        parent.add_child(ink)


static func _cable_curve(from_at: Vector3, to_at: Vector3,
        seed: int, long_feed: bool) -> PackedVector3Array:
    var delta := Vector3(to_at.x - from_at.x, 0.0, to_at.z - from_at.z)
    var length: float = delta.length()
    var direction: Vector3 = (
        delta / length if length > 0.001 else Vector3.FORWARD)
    var side := Vector3(-direction.z, 0.0, direction.x)
    var bend: float = (1.0 if seed % 2 == 0 else -1.0) * (
        minf(1.65, length * 0.10) if long_feed else minf(0.32, length * 0.11))
    var near_start: Vector3 = Vector3(from_at.x, FLOOR_WIRE_Y, from_at.z) + (
        direction * minf(0.90, length * 0.18))
    var near_end: Vector3 = Vector3(to_at.x, FLOOR_WIRE_Y, to_at.z) - (
        direction * minf(0.70, length * 0.15))
    var middle: Vector3 = near_start.lerp(near_end, 0.5) + side * bend
    var controls: Array[Vector3] = [
        from_at, near_start, middle, near_end, to_at]
    var output := PackedVector3Array()
    for seg in range(controls.size() - 1):
        var a: Vector3 = controls[maxi(0, seg - 1)]
        var b: Vector3 = controls[seg]
        var c: Vector3 = controls[seg + 1]
        var d: Vector3 = controls[mini(controls.size() - 1, seg + 2)]
        var steps: int = maxi(3, ceili(b.distance_to(c) / WIRE_STEP))
        for index in range(steps):
            var t: float = float(index) / float(steps)
            var t2: float = t * t
            var t3: float = t2 * t
            var p: Vector3 = 0.5 * ((2.0 * b) + (-a + c) * t +
                (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 +
                (-a + 3.0 * b - 3.0 * c + d) * t3)
            # Keep low external cable spans above the patchwork deck.
            if seg > 0 and seg < controls.size() - 2:
                p.y = maxf(FLOOR_WIRE_Y, p.y)
            output.append(p)
    output.append(to_at)
    return output


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
        specs: Array) -> Node3D:
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
    # Reuse the GENERATOR->GRID input plug instead of inventing a second
    # unrelated power supply. The control panel feeds one visible manifold.
    var hub: Vector3 = PowerBoard.cable_point(0.0)
    # Existing board cable connects at y=0.23. Seat the new manifold on
    # the metal deck, while its distribution plugs remain at that height.
    hub.y = 0.0
    var zero := Basis.IDENTITY
    _device_port(items, "rubber", hub, zero,
        Vector3(0.0, -0.10, 0.0), Vector3(1.46, 0.12, 0.82))
    _device_port(items, "metal", hub, zero,
        Vector3(0.0, 0.28, 0.0), Vector3(1.38, 0.62, 0.70))
    _device_port(items, "rim", hub, zero,
        Vector3(0.0, 0.62, 0.0), Vector3(1.48, 0.10, 0.76))
    for i in range(7):
        _device_port(items, "socket", hub, zero,
            Vector3((float(i) - 3.0) * 0.18, 0.26, 0.397),
            Vector3(0.15, 0.18, 0.08))
    _device_port(items, "light", hub, zero,
        Vector3(0.0, 0.68, 0.0), Vector3(0.60, 0.025, 0.38))
    var serial: int = 0
    for site in all_sites:
        var key: String = str(site["id"])
        if key == "GENERATOR":
            continue
        var origin: Vector3 = site["at"]
        var pose: Dictionary = _locate_device(key, origin, all_sites)
        var device: Dictionary = _make_substation(items,
            pose["at"], float(pose["yaw"]), serial)
        var terminal: Vector3 = _facility_socket(items, key, origin,
            pose["local"])
        var feed_start: Vector3 = hub + Vector3(
            (float(serial) - 3.0) * 0.18, 0.26, 0.47)
        var feed: PackedVector3Array = _cable_curve(
            feed_start, device["input"], _seed_for(key), true)
        var delivery: PackedVector3Array = _cable_curve(
            device["output"], terminal, _seed_for(key) + 1, false)
        for route in [feed, delivery]:
            _append_tube(wires, route, 0.087, 0.0)
            _append_tube(traces, route, 0.026, 0.069)
        serial += 1
    _build_devices(network, items)
    _finish_cables(network, wires, traces)
    # No physics/cable simulation; positions and tubes are built only on load
    # (or when the user explicitly requests a clutter layout reshuffle).
    return network
