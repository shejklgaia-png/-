extends RefCounted
## NEXUS rear bulkhead + service-bay refit.
## Build once: purpose-built polygonal shell sections replace the monolithic rear
## wall, crossbridge and interfering right-hand support. The DEPLOYMENT opening is
## left physically empty, instead of burying a decorative gate inside a wall.
## Shaped castings also break the repetitive ceiling/wall truss rhythm.
## No runtime animation, light, physics, viewport or selection ID is added.

static func suppresses_authored_part(label: String) -> bool:
    # Replace the old transverse box-beam system, not its practical lights.
    if label.begins_with("Deep overhead girder ") or label.begins_with("Girder inset lower spine ") or label.begins_with("Background girder "):
        return true
    if label in ["Roof undercoffer armor expanse", "Central brand face main armor",
            "Central face long raised inset"]:
        return true
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


    _build_industrial_services(root)
    _build_command_spine(root)


# The old narrow front plate is replaced by a sculpted central structural
# shield. All new geometry remains behind the room logo at z=-11.32.
static func _build_command_spine(root: Node3D) -> void:
    var armor := SurfaceTool.new()
    var channel := SurfaceTool.new()
    for tool in [armor, channel]:
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        tool.set_smooth_group(-1)
    # Column root is the retained structural core, centered z=-12.42.
    _service_sweep(armor, [Vector3(0.0,1.85,-12.05),
        Vector3(0.0,3.05,-12.05), Vector3(0.0,5.85,-12.05),
        Vector3(0.0,6.82,-12.05)], Vector3.RIGHT,
        _service_section(0.82,0.49,0.19))
    # Broad angled shoulders, linked into the original head and feet.
    for side in [-1.0,1.0]:
        _service_sweep(channel, [Vector3(side*0.70,1.20,-12.03),
            Vector3(side*1.14,2.35,-12.03),
            Vector3(side*1.14,3.22,-12.03),
            Vector3(side*0.76,3.84,-12.03)], Vector3.BACK,
            _service_section(0.37,0.16,0.10))
        _service_sweep(channel, [Vector3(side*0.68,5.78,-12.10),
            Vector3(side*1.08,6.46,-12.10),
            Vector3(side*0.74,7.12,-12.10)], Vector3.BACK,
            _service_section(0.32,0.18,0.10))
    # A horizontal machined joint separates the lower service cover from
    # the upper logo-bearing structural panel.
    _service_sweep(channel, [Vector3(-0.68,3.35,-11.62),
        Vector3(0.68,3.35,-11.62)], Vector3.BACK,
        _service_section(0.10,0.12,0.06))
    _service_submit(root, "WallCommandSpineArmor", armor, Color("#647d91"), _service_texture(0))
    _service_submit(root, "WallCommandSpineChannel", channel, Color("#889296"), _service_texture(1))


# Background-only, fixed architectural paths. Each material group is one
# opaque mesh, including its collars, returns and support connections.
static func _build_industrial_services(root: Node3D) -> void:
    var duct := SurfaceTool.new()
    var steel := SurfaceTool.new()
    var fins := SurfaceTool.new()
    var wall_steel := SurfaceTool.new()
    var wall_duct := SurfaceTool.new()
    for tool in [duct, steel, fins, wall_steel, wall_duct]:
        tool.begin(Mesh.PRIMITIVE_TRIANGLES)
        tool.set_smooth_group(-1)

    # New vault: broad faceted haunches instead of repeated box girders.
    # At the rear launch bay the right half remains completely open.
    var ribs := SurfaceTool.new()
    ribs.begin(Mesh.PRIMITIVE_TRIANGLES)
    ribs.set_smooth_group(-1)
    for station in [-17.55, -10.10, -2.65, 4.80, 12.25]:
        var z: float = float(station)
        var broad: bool = z == -2.65 or z == 4.80
        _service_sweep(ribs, [Vector3(-9.10,7.65,z),
            Vector3(-7.45,7.65,z), Vector3(-5.70,8.88,z),
            Vector3(-3.80,9.19,z), Vector3(3.80,9.19,z),
            Vector3(5.70,8.88,z), Vector3(7.45,7.65,z),
            Vector3(9.10,7.65,z)], Vector3.BACK,
            _service_section(0.43 if broad else 0.25,0.32,0.12))
        # Integrated outer buttress collars, not detached decoration.
        for side in [-1.0,1.0]:
            _service_sweep(steel, [Vector3(side*8.95,7.65,z),
                Vector3(side*7.55,7.65,z)], Vector3.BACK,
                _service_section(0.49 if broad else 0.32,0.40,0.10))
    # Longitudinal center coffer mounts to the retained roof and divides
    # the vault into unequal functional sections. No roof-hanging pipes
    # close to the maintenance canopy silhouette.
    _service_sweep(duct, [Vector3(0.0,9.42,-27.0),
        Vector3(0.0,9.42,12.35)], Vector3.RIGHT,
        _service_section(2.20,0.25,0.22))
    # Narrow dark service rails sit at the roof shoulder; existing lamps
    # retain their true source positions and project below this cladding.
    for side in [-1.0,1.0]:
        _service_sweep(duct, [Vector3(side*8.52,9.32,-18.7),
            Vector3(side*8.52,9.32,12.35)], Vector3.RIGHT,
            _service_section(1.0,0.32,0.23))
    # The retained practical lamp sockets originally met the removed
    # undercoffer. A slim roof-mounted rail now provides that attachment.
    for side in [-1.0,1.0]:
        _service_sweep(duct, [Vector3(side*5.58,9.59,-27.0),
            Vector3(side*5.58,9.59,12.35)], Vector3.RIGHT,
            _service_section(0.56,0.13,0.08))
    # Separate near-field access bay with visible layered channel and endcaps.
    _service_sweep(steel, [Vector3(-1.32,9.04,-2.65),
        Vector3(-1.32,9.04,4.80), Vector3(-1.32,9.04,12.25)],
        Vector3.RIGHT, _service_section(0.24,0.14,0.08))
    _service_sweep(steel, [Vector3(1.32,9.04,-2.65),
        Vector3(1.32,9.04,4.80), Vector3(1.32,9.04,12.25)],
        Vector3.RIGHT, _service_section(0.24,0.14,0.08))
    _service_submit(root, "CeilingVaultRibs", ribs, Color("#74828d"), _service_texture(0))

    # Rear-left wall heat exchanger: fins seat in the existing inset face.
    # Keep the cyan indicator above it and the central mark unobstructed.
    _service_sweep(fins, [Vector3(-7.65, 3.50, -26.88),
        Vector3(-4.55, 3.50, -26.88)], Vector3.UP,
        _service_section(0.23, 0.24, 0.07))
    _service_sweep(fins, [Vector3(-7.65, 5.20, -26.88),
        Vector3(-4.55, 5.20, -26.88)], Vector3.UP,
        _service_section(0.23, 0.24, 0.07))
    for i in range(12):
        var x: float = -7.55 + float(i)*0.26
        _service_sweep(fins, [Vector3(x, 3.47, -26.81),
            Vector3(x, 5.23, -26.81)], Vector3.RIGHT,
            _service_section(0.075, 0.29, 0.05))
    # Bent metal return is continuous from the rear shell into the manifold.
    _service_sweep(wall_steel, [Vector3(-4.63, 5.42, -26.89),
        Vector3(-4.27, 5.42, -26.89), Vector3(-4.06, 5.63, -26.89),
        Vector3(-4.06, 6.30, -26.89), Vector3(-3.83, 6.53, -26.89),
        Vector3(-3.38, 6.53, -26.89)],
        Vector3.BACK, _service_round(0.15, 8))
    _service_sweep(wall_steel, [Vector3(-3.38, 6.53, -26.80),
        Vector3(-3.38, 6.53, -27.47)], Vector3.RIGHT, _service_round(0.15, 8))

    # Right forward wall only: no mesh in the protected rear gate bay.
    # Two unequal wall-mounted conduits are rooted inside the forward shell.
    _service_sweep(wall_steel, [Vector3(8.82, 7.68, -15.80),
        Vector3(8.82, 7.38, -15.50),
        Vector3(8.82, 5.95, -14.08), Vector3(8.82, 5.95, -8.70)], Vector3.RIGHT,
        _service_round(0.21, 8))
    for end_point in [Vector3(8.82,7.68,-15.80), Vector3(8.82,5.95,-8.70)]:
        _service_sweep(wall_steel, [end_point-Vector3(0.07,0,0),
            end_point+Vector3(0.31,0,0)], Vector3.UP, _service_round(0.23,8))
    _service_sweep(wall_duct, [Vector3(8.91, 4.76, -14.70),
        Vector3(8.91, 4.76, -8.40)], Vector3.RIGHT,
        _service_section(0.25, 0.38, 0.09))
    # Left forward wall manifold projects out of the existing enclosing
    # wall (inner face x=-8.94). Keep its lower edge above the floor.
    _service_sweep(wall_duct, [Vector3(-8.86,2.10,-6.5),
        Vector3(-8.86,4.72,-6.5), Vector3(-8.86,5.35,-7.3),
        Vector3(-8.86,5.35,-11.5)], Vector3.RIGHT,
        _service_section(0.43,0.52,0.14))
    _service_sweep(wall_steel, [Vector3(-8.80,2.15,-7.65),
        Vector3(-8.80,4.50,-7.65), Vector3(-8.80,5.06,-8.22),
        Vector3(-8.80,5.06,-12.2)], Vector3.RIGHT,
        _service_round(0.18,8))
    var coated: ImageTexture = _service_texture(0)
    var pipe_finish: ImageTexture = _service_texture(1)
    _service_submit(root, "CeilingDuctMesh", duct, Color("#52616b"), coated)
    _service_submit(root, "CeilingPipeMesh", steel, Color("#777970"), pipe_finish)
    _service_submit(root, "WallDuctMesh", wall_duct, Color("#65727b"), coated)
    _service_submit(root, "WallPipeMesh", wall_steel, Color("#8a8980"), pipe_finish)
    _service_submit(root, "RearHeatExchangerMesh", fins, Color("#60727b"), _service_texture(2))


static func _service_section(w: float, h: float, bevel: float) -> Array:
    return [Vector2(-w+bevel,-h), Vector2(w-bevel,-h),
        Vector2(w,-h+bevel), Vector2(w,h-bevel), Vector2(w-bevel,h),
        Vector2(-w+bevel,h), Vector2(-w,h-bevel), Vector2(-w,-h+bevel)]


static func _service_round(radius: float, sides: int) -> Array:
    var points: Array = []
    for i in range(sides):
        var a: float = TAU*float(i)/float(sides)
        points.append(Vector2(cos(a),sin(a))*radius)
    return points


static func _service_sweep(tool: SurfaceTool, path: Array, side_axis: Vector3,
        section: Array) -> void:
    # Use one continuous ring per path joint. Face UVs are perimeter/travel
    # in meters, so long ducts do not stretch a single small panel image.
    var rings: Array = []
    var distances: Array[float] = [0.0]
    for i in range(path.size()):
        var center: Vector3 = path[i]
        var before: Vector3 = center - Vector3(path[maxi(0,i-1)])
        var after: Vector3 = Vector3(path[mini(path.size()-1,i+1)]) - center
        var tangent: Vector3 = (before.normalized()+after.normalized()).normalized()
        var right: Vector3 = (side_axis-tangent*side_axis.dot(tangent)).normalized()
        var up: Vector3 = tangent.cross(right).normalized()
        var ring: Array[Vector3] = []
        for value in section:
            var p: Vector2 = value
            ring.append(center+right*p.x+up*p.y)
        rings.append(ring)
        if i > 0:
            distances.append(distances[i-1]+before.length())
    var around: float = 0.0
    for j in range(section.size()):
        var k: int = (j+1)%section.size()
        var edge: float = Vector2(section[j]).distance_to(Vector2(section[k]))
        for i in range(path.size()-1):
            var a: Vector3 = rings[i][j]
            var b: Vector3 = rings[i][k]
            var c: Vector3 = rings[i+1][k]
            var d: Vector3 = rings[i+1][j]
            var uv0 := Vector2(around,distances[i])
            var uv1 := Vector2(around+edge,distances[i])
            var uv2 := Vector2(around+edge,distances[i+1])
            var uv3 := Vector2(around,distances[i+1])
            _service_triangle(tool,a,c,b,uv0,uv2,uv1)
            _service_triangle(tool,a,d,c,uv0,uv3,uv2)
        around += edge
    # Closed ends have their own planar metric UVs.
    var last: int = path.size()-1
    for j in range(1,section.size()-1):
        _service_triangle(tool,rings[0][0],rings[0][j],rings[0][j+1],
            section[0],section[j],section[j+1])
        _service_triangle(tool,rings[last][0],rings[last][j+1],rings[last][j],
            section[0],section[j+1],section[j])


static func _service_triangle(tool: SurfaceTool, a: Vector3, b: Vector3,
        c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
    var normal: Vector3 = (c-a).cross(b-a).normalized()
    tool.set_normal(normal)
    tool.set_uv(ua/1.20)
    tool.add_vertex(a)
    tool.set_uv(ub/1.20)
    tool.add_vertex(b)
    tool.set_uv(uc/1.20)
    tool.add_vertex(c)


static func _service_submit(root: Node3D, label: String, tool: SurfaceTool,
        tint: Color, finish: Texture2D) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = tool.commit()
    var material := _mat(tint)
    material.albedo_texture = finish
    material.texture_repeat = true
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh.set_meta("FX_NO_OUTLINE", true)
    mesh.set_meta("sera_outline_occluder_only", true)
    root.add_child(mesh)


static func _service_texture(finish: int) -> ImageTexture:
    # Three neutral pixel finishes multiply the restrained material colors.
    # Integer-pixel tooling marks and joints; never large camouflage bands.
    var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
    image.fill(Color("#e4e4e4"))
    for y in range(64):
        for x in range(64):
            var value: int = 226 + ((x*13+y*7+x*y*3)%9)-4
            if finish == 0:
                if y == 0 or y == 1:
                    value = 138
                elif y == 2:
                    value = 248
                elif (x == 5 or x == 58) and (y == 6 or y == 57):
                    value = 105
                elif (x*17+y*11)%113 == 0:
                    value = 196
            elif finish == 1:
                if y == 0 or y == 32:
                    value = 160
                elif y == 1 or y == 33:
                    value = 250
                elif x%9 == 0 and y%7 < 3:
                    value = 204
            else:
                if x%16 == 0:
                    value = 170
                elif x%16 == 1:
                    value = 245
                elif y%11 == 0 and x%5 < 3:
                    value = 200
            var tone: float = float(value)/255.0
            image.set_pixel(x,y,Color(tone,tone,tone,1.0))
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)


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
