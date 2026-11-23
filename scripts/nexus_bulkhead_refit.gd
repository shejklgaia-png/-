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
        return label.ends_with("3.85") or label.ends_with("5.95")
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

    # Rear wall z=-27.7. True door cutout: x=3.1..9.15, y=0..8.4.
    # The large right-side DEPLOYMENT machine can now be seen through it.
    _cast(root, "LeftRearBulkheadWithGateCutout", [
        Vector2(-10.05, -0.05), Vector2(3.04, -0.05),
        Vector2(3.04, 7.55), Vector2(2.58, 8.42),
        Vector2(-10.05, 8.42)], -28.10, -27.42, dark)
    _cast(root, "RightRearBulkheadGateReturn", [
        Vector2(9.20, -0.05), Vector2(10.05, -0.05),
        Vector2(10.05, 8.42), Vector2(9.61, 8.42),
        Vector2(9.20, 7.62)], -28.10, -27.42, dark)
    _cast(root, "DeepGateHeaderOverClearOpening", [
        Vector2(2.54, 8.42), Vector2(9.65, 8.42),
        Vector2(10.02, 9.00), Vector2(10.02, 10.22),
        Vector2(2.54, 10.22)], -28.10, -27.42, gunmetal)

    # Rebuild the RIGHT side wall as three cast sections. Its former
    # unbroken inner face ran through the gate's outer armor; recess ONLY the
    # gate bay from x=8.94 to x=9.58. The near and far wall sections retain
    # the original hangar envelope and the new right jamb provides continuity.
    _cast(root, "RightWallBehindGate", [
        Vector2(8.96, 0.0), Vector2(9.98, 0.0),
        Vector2(9.98, 9.80), Vector2(8.96, 9.80)],
        -28.50, -26.60, dark)
    _cast(root, "RightWallRecessedLaunchBay", [
        Vector2(9.58, 0.0), Vector2(9.98, 0.0),
        Vector2(9.98, 9.80), Vector2(9.58, 9.80)],
        -26.60, -19.50, gunmetal)
    _cast(root, "RightWallForwardStation", [
        Vector2(8.96, 0.0), Vector2(9.98, 0.0),
        Vector2(9.98, 9.80), Vector2(8.96, 9.80)],
        -19.50, 12.50, dark)

    # The wall's front-face vertical machinery tracks form angled chamfered
    # reveals outside, not inside, the open departure tunnel.
    _cast(root, "GateLeftMachinedDoorJamb", [
        Vector2(2.65, 0.12), Vector2(3.07, 0.12),
        Vector2(3.07, 7.42), Vector2(2.62, 8.28),
        Vector2(2.30, 8.28), Vector2(2.65, 7.28)],
        -27.37, -27.02, armor)
    _cast(root, "GateRightMachinedDoorJamb", [
        Vector2(9.25, 0.12), Vector2(9.65, 0.12),
        Vector2(9.65, 7.30), Vector2(9.87, 8.28),
        Vector2(9.53, 8.28), Vector2(9.25, 7.40)],
        -27.37, -27.02, armor)
    _cast(root, "GateLintelTriangulatedArmor", [
        Vector2(2.66, 8.65), Vector2(9.45, 8.65),
        Vector2(9.05, 9.18), Vector2(7.45, 9.35),
        Vector2(4.00, 9.35), Vector2(2.66, 9.04)],
        -27.02, -26.74, alloy)

    # Split the former enormous uninterrupted rear mezzanine bridge at z=-20
    # around the portal approach; the middle SERA tower remains untouched.
    _cast(root, "BridgeLeftAnchoredSpan", [
        Vector2(-9.96, 5.98), Vector2(2.83, 5.98),
        Vector2(2.83, 6.55), Vector2(-9.96, 6.77)],
        -20.75, -19.25, armor)
    _cast(root, "BridgeLeftUndersideTaper", [
        Vector2(-9.30, 5.78), Vector2(2.18, 5.78),
        Vector2(2.62, 6.00), Vector2(-9.30, 6.08)],
        -20.30, -19.17, gunmetal)
    _cast(root, "BridgeRightGateSafeReturn", [
        Vector2(9.45, 5.98), Vector2(9.94, 5.98),
        Vector2(9.94, 6.76), Vector2(9.52, 6.76)],
        -20.75, -19.25, armor)

    # Replace the old right-most full-height column (which was inside the gate
    # cheeks at z=-23) with a narrower, diagonal wall-coupled support.
    _cast(root, "RightLaunchBayChamberJamb", [
        Vector2(9.62, 0.12), Vector2(9.95, 0.12),
        Vector2(9.95, 8.75), Vector2(9.72, 8.75),
        Vector2(9.39, 7.92), Vector2(9.52, 2.13)],
        -24.60, -23.22, armor)
    _cast(root, "RightLaunchJambReinforcement", [
        Vector2(9.53, 2.18), Vector2(9.83, 2.18),
        Vector2(9.83, 7.02), Vector2(9.58, 7.42)],
        -23.12, -22.83, alloy)

    # Re-route the continuous right wall runner to the outside of the portal.
    # Unlike its former protruding x=7.7 face, this clears the gate opening.
    _cast(root, "RightWallHighConduit", [
        Vector2(9.53, 7.98), Vector2(9.98, 7.98),
        Vector2(9.98, 8.44), Vector2(9.64, 8.44)],
        -27.12, 11.00, gunmetal)
    _cast(root, "RightWallMezzanineShortened", [
        Vector2(9.50, 5.68), Vector2(9.94, 5.68),
        Vector2(9.94, 6.34), Vector2(9.50, 6.34)],
        -16.85, 2.00, armor)

    # The nearest (rear-most) crossing girder no longer cuts visually through
    # the top of the gate. Tapered upper returns stop at the open bay.
    _cast(root, "RearGirderLeftHaunch", [
        Vector2(-9.98, 8.76), Vector2(2.65, 8.76),
        Vector2(2.92, 9.15), Vector2(2.92, 9.55),
        Vector2(-9.98, 9.55)],
        -25.36, -24.64, gunmetal)
    _cast(root, "RearGirderRightHaunch", [
        Vector2(9.57, 8.88), Vector2(10.02, 8.88),
        Vector2(10.02, 9.55), Vector2(9.57, 9.55)],
        -25.36, -24.64, gunmetal)

    # Three intentionally different reinforcing stations interrupt the long
    # repeating girder cells. Real trapezoid/diagonal prisms, not box stacks.
    for spec in [
            {"z": -17.0, "span": 2.10, "drop": 8.60},
            {"z": -2.35, "span": 2.65, "drop": 8.39},
            {"z": 11.55, "span": 1.88, "drop": 8.67}]:
        var station: float = float(spec["z"])
        var span: float = float(spec["span"])
        var low_y: float = float(spec["drop"])
        _cast(root, "CenterGirderWedge%.1f" % station, [
            Vector2(-span, 9.22), Vector2(span, 9.22),
            Vector2(span - 0.31, low_y + 0.40),
            Vector2(0.0, low_y),
            Vector2(-span + 0.31, low_y + 0.40)],
            station - 0.33, station + 0.33, armor)
        _cast(root, "GirderMechanicalRib%.1f" % station, [
            Vector2(-0.77, 8.77), Vector2(0.77, 8.77),
            Vector2(0.51, 9.00), Vector2(-0.51, 9.00)],
            station + 0.33, station + 0.43, alloy)

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
    mat.metallic = 0.46
    mat.roughness = 0.50
    # The procedural door jambs include reversed faces; preserve Android GL.
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if emissive:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 1.18
    return mat
