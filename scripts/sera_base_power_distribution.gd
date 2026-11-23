extends RefCounted
## BASE physical power network. Seven local substations connect to the
## GENERATOR control terminal, then to each consumer's exterior socket.
## Placement is seeded and stable, independent of time/frame rate.
## Solid equipment and cables use the same role-3 visible-ID ink as clutter:
## inner 1px, outer 1px, contacts 2px. No added lights or GPU simulation.
const BaseClutter = preload("res://scripts/sera_base_clutter.gd")
const PowerBoard = preload("res://scripts/sera_base_power_board.gd")
const BaseArchitecture = preload("res://scripts/sera_base_architecture.gd")

const CONSUMERS: Array[String] = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "STORAGE", "BUILD_TERMINAL"]
const WIRE_SIDES: int = 6
const WIRE_STEP: float = 0.75
const FLOOR_WIRE_Y: float = 0.115

static func _seed_for(key: String) -> int:
    var value: int = 379
    for i in range(key.length()):
        value = posmod(value * 131 + key.unicode_at(i), 2147483647)
    return maxi(1, value)


static func _footprint(key: String) -> Vector2:
    if key == "NEXUS":
        return Vector2(3.70, 3.38)
    if key == "LABO":
        return Vector2(3.14, 3.18)
    return Vector2(2.23, 2.23)


static func _locate_device(key: String, origin: Vector3,
        all_sites: Array[Dictionary]) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = _seed_for("SERA_POWER_" + key)
    var yaw: float = rng.randf_range(-PI, PI)
    var half: Vector2 = _footprint(key)
    # Keep the main door/active work area in local +Z open.
    var props: Array[Dictionary] = BaseClutter.props_for(key)
    var body_yaw := Basis(Vector3.UP, BaseArchitecture.facility_yaw_radians(key))
    for attempt in range(96):
        var phi: float = rng.randf_range(-PI, PI)
        var rx: float = half.x + rng.randf_range(0.95, 2.30)
        var rz: float = half.y + rng.randf_range(0.90, 2.00)
        var local := Vector3(cos(phi) * rx, 0.0, sin(phi) * rz)
        # The 1.05m substation must stand clear of the physical building.
        if absf(local.x) < half.x + 0.65 and (
                absf(local.z) < half.y + 0.65):
            continue
        if local.z > half.y - 0.15 and absf(local.x) < 2.05:
            continue
        var blocked: bool = false
        for prop in props:
            var p: Vector2 = prop["at"]
            var dims: Vector2 = BaseClutter.bounds_for(str(prop["kind"]))
            var pad: float = 0.82 + maxf(dims.x, dims.y) * (
                float(prop.get("scale", 1.0)) * 0.70)
            if Vector2(local.x, local.z).distance_to(p) < pad:
                blocked = true
                break
        if blocked:
            continue
        var world_at: Vector3 = origin + body_yaw * local
        for site in all_sites:
            if str(site["id"]) == key:
                continue
            var other: Vector3 = site["at"]
            var other_half: Vector2 = _footprint(str(site["id"]))
            var minimum: float = maxf(other_half.x, other_half.y) + 1.45
            if Vector2(world_at.x, world_at.z).distance_to(
                    Vector2(other.x, other.z)) < minimum:
                blocked = true
                break
        if blocked:
            continue
        return {"at": world_at, "local": local, "yaw": yaw}
    # Deterministic fallback beside the rear wall, never the front doorway.
    var fallback := Vector3(-half.x - 1.20, 0.0, -half.y * 0.45)
    return {"at": origin + body_yaw * fallback,
        "local": fallback, "yaw": yaw}


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
        "world": world_at, "index": index
    }


static func _facility_socket(items: Dictionary, key: String,
        origin: Vector3, device_local: Vector3) -> Vector3:
    var half: Vector2 = _footprint(key)
    var near := Vector3(
        clampf(device_local.x, -half.x, half.x),
        0.60, clampf(device_local.z, -half.y, half.y))
    # Place the receiving socket on the actual nearest side of the building.
    if absf(device_local.x / half.x) > absf(device_local.z / half.y):
        near.x = signf(device_local.x) * half.x
    else:
        near.z = signf(device_local.z) * half.y
    var yaw := Basis(Vector3.UP, BaseArchitecture.facility_yaw_radians(key))
    var world_at: Vector3 = origin + yaw * near
    _device_port(items, "socket", world_at, yaw,
        Vector3.ZERO, Vector3(0.29, 0.28, 0.18))
    _device_port(items, "light", world_at, yaw,
        Vector3(0.0, 0.085, 0.096), Vector3(0.16, 0.055, 0.023))
    return world_at + yaw * Vector3(0.0, 0.0, 0.12)


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
        if palette == "light":
            # Light cores are physically opaque and keep role 7 so a black
            # clutter outline cannot cover their tiny luminous surface.
            draw.set_meta("sera_outline_occluder_only", true)
            draw.set_meta("sera_outline_emissive_protect", true)
        parent.add_child(draw)


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
