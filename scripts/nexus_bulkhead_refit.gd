extends RefCounted
## NEXUS rear bulkhead + service-bay refit.
## Build once: purpose-built polygonal shell sections replace the monolithic rear
## wall, crossbridge and interfering right-hand support. The DEPLOYMENT opening is
## left physically empty, instead of burying a decorative gate inside a wall.
## Shaped castings also break the repetitive ceiling/wall truss rhythm.
## No runtime animation, light, physics, viewport or selection ID is added.

static func suppresses_authored_part(label: String) -> bool:
    if label in [
            "Rear wall monolithic black shell",
            "Rear wall upper stepped machinery shelf",
            "Rear bridge across central tower",
            "Bridge underside armored dark channel",
            "Deep overhead girder 0",
            "Girder inset lower spine 0",
            "Heavy upper runner 1",
            "Service mezzanine horizontal duct 1",
            "Continuous enclosing bulkhead 1"]:
        return true
    if label.begins_with("Overhead electrical relay housing ") or (
            label.begins_with("Overhead electrical cyan core ")):
        # Keep left relays, remove only the ones in front of DEPLOYMENT.
        return label.ends_with(" 3.85") or label.ends_with(" 5.95")
    for replaced in [
            "Three-stage column main 1 0",
            "Column recessed mechanical inset 1 0",
            "Column cyan datum lamp 1 0",
            "Angled wall supporting elbow 1 0",
            "Bulkhead service grille 1 0"]:
        if label == replaced:
            return true
    # The rear-right vent panels previously crossed the top of the gate.
    if label.begins_with("Rear industrial upper vent panel "):
        return label.ends_with(" 2") or label.ends_with(" 3")
    if label.begins_with("Rear upper grille slit "):
        return label.begins_with("Rear upper grille slit 2-") or (
            label.begins_with("Rear upper grille slit 3-"))
    return false


static func build(room: Node3D) -> void:
    var root := Node3D.new()
    root.name = "NexusBulkheadRebuild"
    root.set_meta("FX_NO_OUTLINE", true)
    root.set_meta("sera_outline_occluder_only", true)
    room.add_child(root)

    var dark := _mat(Color("#152633"))
    var gunmetal := _mat(Color("#30495c"))
    var armor := _mat(Color("#435e71"))
    var alloy := _mat(Color("#7b92a3"))
    var glow := _mat(Color("#65d7f3"), true)

    # Independent gate: leave a rectangular clearance for the whole
    # rotated 1.35x portal, including cheeks, visor and tunnel.
    # No room-side jamb, tie, column or runner may enter this opening.
    _cast(root, "LeftRearBulkheadWithGateCutout", [
        Vector2(-10.05, -0.05), Vector2(2.70, -0.05),
        Vector2(2.70, 8.80), Vector2(-10.05, 8.80)],
        -28.10, -27.42, dark)
    _cast(root, "RightRearBulkheadGateReturn", [
        Vector2(9.85, -0.05), Vector2(10.05, -0.05),
        Vector2(10.05, 8.80), Vector2(9.85, 8.80)],
        -28.10, -27.42, dark)
    _cast(root, "DeepGateHeaderOverClearOpening", [
        Vector2(2.70, 8.80), Vector2(10.05, 8.80),
        Vector2(10.05, 10.22), Vector2(2.70, 10.22)],
        -28.10, -27.42, gunmetal)

    # The portal tunnel extends behind the rear wall. Recess the right
    # wall across the ENTIRE tunnel/arch bay, not just its front half.
    _cast(root, "RightWallRecessedLaunchBay", [
        Vector2(10.05, 0.0), Vector2(10.50, 0.0),
        Vector2(10.50, 9.80), Vector2(10.05, 9.80)],
        -31.00, -18.90, gunmetal)
    _cast(root, "RightWallForwardStation", [
        Vector2(8.96, 0.0), Vector2(10.50, 0.0),
        Vector2(10.50, 9.80), Vector2(8.96, 9.80)],
        -18.90, 12.50, dark)

    # Preserve the left bridge; stop the right bridge and structural
    # supports short of the launch bay. The gate supplies its own armor.
    _cast(root, "BridgeLeftAnchoredSpan", [
        Vector2(-9.96, 5.98), Vector2(2.60, 5.98),
        Vector2(2.60, 6.55), Vector2(-9.96, 6.77)],
        -20.75, -19.25, armor)
    _cast(root, "BridgeLeftUndersideTaper", [
        Vector2(-9.30, 5.78), Vector2(2.18, 5.78),
        Vector2(2.42, 6.00), Vector2(-9.30, 6.08)],
        -20.30, -19.17, gunmetal)
    _cast(root, "RightWallHighConduit", [
        Vector2(9.53, 7.98), Vector2(9.98, 7.98),
        Vector2(9.98, 8.44), Vector2(9.64, 8.44)],
        -18.85, 11.00, gunmetal)
    _cast(root, "RightWallMezzanineShortened", [
        Vector2(9.50, 5.68), Vector2(9.94, 5.68),
        Vector2(9.94, 6.34), Vector2(9.50, 6.34)],
        -16.85, 2.00, armor)
    _cast(root, "RearGirderLeftHaunch", [
        Vector2(-9.98, 8.76), Vector2(2.60, 8.76),
        Vector2(2.60, 9.55), Vector2(-9.98, 9.55)],
        -25.36, -24.64, gunmetal)

    # Keep the authored transverse girders continuous. The former independent
    # center wedges and ribs were not tied to a real load-bearing joint.

    # Staggered wall-side actuator rails add an identifiable mechanical
    # hierarchy to both long lateral surfaces without covering any consoles.
    # Their sections are tapered extrusions, not a row of identical cuboids.
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        for station_data in [
                {"z": -15.55, "bottom": 2.33, "top": 6.87},
                {"z": -0.60, "bottom": 3.04, "top": 7.33},
                {"z": 9.05, "bottom": 2.47, "top": 5.84}]:
            var station: float = float(station_data["z"])
            var low: float = float(station_data["bottom"])
            var high: float = float(station_data["top"])
            _cast(root, "ServiceWallHaunch%d_%.1f" % [
                    side_value, station], [
                Vector2(side * 9.12, low),
                Vector2(side * 9.53, low + 0.62),
                Vector2(side * 9.53, high - 0.46),
                Vector2(side * 9.21, high),
                Vector2(side * 8.96, high - 0.15)],
                station - 0.32, station + 0.33, armor)

    # Left wall has two major unequal access panels; their inset sloping faces
    # visibly interrupt the original near-identical service grilles.
    _cast(root, "RearLeftServiceCartridge", [
        Vector2(-8.60, 2.40), Vector2(-4.18, 2.40),
        Vector2(-3.73, 3.05), Vector2(-3.73, 6.85),
        Vector2(-8.60, 6.85)],
        -27.28, -27.08, armor)
    _cast(root, "RearLeftServiceInset", [
        Vector2(-8.10, 2.90), Vector2(-4.35, 2.90),
        Vector2(-4.04, 3.30), Vector2(-4.04, 6.32),
        Vector2(-8.10, 6.32)],
        -27.04, -26.94, gunmetal)
    _cast(root, "MiddleServiceCrown", [
        Vector2(-2.87, 6.48), Vector2(2.13, 6.48),
        Vector2(2.13, 7.18), Vector2(1.45, 7.57),
        Vector2(-2.12, 7.57)],
        -27.27, -27.01, armor)
    _cast(root, "LeftServiceIndicator", [
        Vector2(-7.78, 5.81), Vector2(-7.03, 5.81),
        Vector2(-6.90, 6.07), Vector2(-7.78, 6.07)],
        -26.93, -26.87, glow)


static func _cast(root: Node3D, label: String,
        perimeter: Array, back_z: float, front_z: float,
        material: Material) -> void:
    # Extrude arbitrary profiled XY section through Z; proper planar faces and
    # side bevels are generated once using a single ArrayMesh per casting.
    var geo := SurfaceTool.new()
    geo.begin(Mesh.PRIMITIVE_TRIANGLES)
    var count: int = perimeter.size()
    for i in range(1, count - 1):
        _tri(geo, _v(perimeter[0], back_z),
            _v(perimeter[i], back_z),
            _v(perimeter[i + 1], back_z))
        _tri(geo, _v(perimeter[0], front_z),
            _v(perimeter[i + 1], front_z),
            _v(perimeter[i], front_z))
    for i in range(count):
        var j: int = (i + 1) % count
        var back_a: Vector3 = _v(perimeter[i], back_z)
        var back_b: Vector3 = _v(perimeter[j], back_z)
        var front_a: Vector3 = _v(perimeter[i], front_z)
        var front_b: Vector3 = _v(perimeter[j], front_z)
        _tri(geo, back_a, back_b, front_b)
        _tri(geo, back_a, front_b, front_a)
    geo.generate_normals()
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = geo.commit()
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh.set_meta("FX_NO_OUTLINE", true)
    mesh.set_meta("sera_outline_occluder_only", true)
    root.add_child(mesh)


static func _v(point: Vector2, z: float) -> Vector3:
    return Vector3(point.x, point.y, z)


static func _tri(geo: SurfaceTool, a: Vector3,
        b: Vector3, c: Vector3) -> void:
    geo.add_vertex(a)
    geo.add_vertex(b)
    geo.add_vertex(c)


static func _mat(tint: Color, emissive: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    # These are large background walls, bridge spans and girder surfaces, not
    # polished foreground machinery. Their former metallic=0.46/roughness=0.50
    # created a broad silver specular hotspot resembling a blur/fog patch
    # behind the central NEXUS pillar. Keep diffuse directional shading and
    # crisp facet boundaries but suppress specular/reflected highlights.
    mat.metallic = 0.0
    mat.metallic_specular = 0.0
    mat.roughness = 1.0
    # The procedural door jambs include reversed faces; preserve Android GL.
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if emissive:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 1.18
    return mat
