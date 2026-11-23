extends RefCounted
## NEXUS industrial deck — structural redesign based on the supplied concept.
##
## Seven interlocking plate lanes, physically recessed access grilles, beveled
## armor, bolts and optical accents. Unlike the old 3-column floor this uses
## offset plate joints and a real 8-corner top profile, not giant flat boxes.
## Opaque static MultiMeshes, depth testing ON, no extra viewports or lights.
## The original Blockbench foundation/props/camera/input stay in place.

const DECK_BACK: float = -27.25
const DECK_FRONT: float = 24.35
const DECK_MIDDLE: float = (DECK_BACK + DECK_FRONT) * 0.5
const PLATE_TOP: float = 0.159
const GRILLE_OPENINGS: Array = [
    Vector2(-2.10, -1.62),
    Vector2(3.73, 4.17)
]
# Coordinates in meters; left to right, with the center walking lane clearly
# broader than side service panels. The unfilled +/-3.6..4.3 intervals are
# true recessed warning gutters, not yellow overlays on top of the plates.
const LANES: Array = [
    [-7.45, -5.68], [-5.64, -4.31], [-3.57, -1.82],
    [-1.80, 1.80],
    [1.82, 3.57], [4.31, 5.64], [5.68, 7.45]
]
const LANE_OFFSETS: Array = [0.22, -0.48, 0.35, 0.00, -0.14, 0.58, -0.39]


static func build(room: Node3D) -> void:
    var batches: Dictionary = {}
    # The support shell ends at y=-0.015. This dark solid underdeck is visible
    # only through joints and the two genuinely open maintenance cutouts.
    _cube(batches, "underdeck", Vector3(0.0, 0.023, DECK_MIDDLE),
        Vector3(15.15, 0.124, DECK_FRONT - DECK_BACK))

    # Independent row rhythms form T-joints instead of long parallel lines.
    # Nearer panels are shorter, reproducing the complex reference foreground.
    for lane in range(LANES.size()):
        var bounds: Array = LANES[lane]
        var x0: float = float(bounds[0])
        var x1: float = float(bounds[1])
        var z: float = DECK_BACK + float(LANE_OFFSETS[lane])
        var index: int = 0
        while z < DECK_FRONT - 0.24:
            # Compress the near/middle deck rhythm so the portrait view does
            # not read as a long empty runway between the stage and terminals.
            var pitch: float = 2.56 if z < -12.0 else 1.82
            if z > -5.0:
                pitch = 1.48
            if z > 1.5:
                pitch = 1.28
            if z > 9.0:
                pitch = 1.38
            pitch += float((index * 3 + lane * 5) % 4) * 0.08
            var a: float = maxf(z + 0.025, DECK_BACK + 0.06)
            var b: float = minf(z + pitch - 0.025, DECK_FRONT - 0.06)
            if b > a + 0.50:
                var shade: String = _plate_finish(lane, index)
                if lane == 3:
                    _center_panel_with_drains(batches, x0, x1, a, b, shade, index)
                else:
                    _armor_panel(batches, x0, x1, a, b, shade, lane, index)
            z += pitch
            index += 1

    # Yellow/black warning paint belongs only within actual dark trenches.
    # The reference shows these on the foreground approach, not as bright
    # all-room length yellow ribbons.
    for sign_value in [-1, 1]:
        var side: float = float(sign_value)
        _cube(batches, "gutter", Vector3(side * 3.94, 0.103, DECK_MIDDLE),
            Vector3(0.54, 0.027, DECK_FRONT - DECK_BACK - 0.30))
        for x_edge in [3.65, 4.23]:
            _cube(batches, "guard_edge",
                Vector3(side * float(x_edge), 0.139, DECK_MIDDLE),
                Vector3(0.027, 0.020, DECK_FRONT - DECK_BACK - 0.42))
        for i in range(34):
            var warning_z: float = 7.30 + float(i) * 0.46
            if warning_z > DECK_FRONT - 0.34:
                break
            _cube(batches, "hazard_yellow",
                Vector3(side * 3.94, 0.131, warning_z),
                Vector3(0.19, 0.013, 0.34), deg_to_rad(side * 38.0))

        # Flush, framed fixtures. Foreground placement avoids the occlusion
        # from the equipment consoles, while a few illuminate the distance.
        for light_z in [-10.3, -2.8, 4.0, 11.1, 18.3]:
            _light(batches, side * 6.62, float(light_z), 0.95)
        for light_z in [-5.6, 2.4, 10.7, 18.1]:
            _light(batches, side * 2.85, float(light_z), 0.49)
        # Short reference-style guidance lights break up the empty approach.
        for light_z in [-1.0, 6.8, 13.6]:
            _light(batches, side * 3.12, float(light_z), 0.38)

        # Thin flush reinforcement rails interrupt the monotone side fields.
        for rail_z in [-8.0, 1.2, 12.1]:
            _service_lid(batches, side * 5.08, float(rail_z))

    # Retain fitted metal shoulders on either side of each drainage slot.
    # The underlying center-row opening spans the lane width for clipping,
    # but only the narrow grille itself must remain visibly recessed.
    _drain_shoulder(batches, -2.10, -1.62, 2.48)
    _drain_shoulder(batches, 3.73, 4.17, 2.28)
    _maintenance_grille(batches, -1.86, 2.48, 0.43)
    _maintenance_grille(batches, 3.95, 2.28, 0.39)

    # Low-profile inspection bays and offset reinforcement cleats bring
    # industrial density into the long gap between the SERA pad and monitors.
    # Keep the stage's central 1.37m radius completely unobstructed.
    for z_value in [-3.30, -0.35, 2.30, 6.25, 9.45]:
        var z: float = float(z_value)
        for sign_value in [-1, 1]:
            var side: float = float(sign_value)
            _inspection_bay(batches, side * 2.50, z + side * 0.36)
    for z_value in [-1.10, 1.85, 7.70]:
        _cross_reinforcement(batches, float(z_value))

    _submit(room, batches)


static func _plate_finish(lane: int, index: int) -> String:
    var mix: int = (lane * 7 + index * 3) % 11
    if lane == 3:
        return "deck_mid" if mix < 6 else "deck_deep"
    if lane == 1 or lane == 5:
        return "deck_side" if mix < 8 else "deck_light"
    if mix < 3:
        return "deck_light"
    if mix < 7:
        return "deck_mid"
    return "deck_deep"


static func _center_panel_with_drains(batches: Dictionary,
        x0: float, x1: float, z0: float, z1: float,
        finish: String, index: int) -> void:
    var portions: Array = [Vector2(z0, z1)]
    for opening in GRILLE_OPENINGS:
        var next_portions: Array = []
        for portion_value in portions:
            var portion: Vector2 = portion_value
            if portion.y <= opening.x or portion.x >= opening.y:
                next_portions.append(portion)
                continue
            if opening.x - portion.x > 0.25:
                next_portions.append(Vector2(portion.x, opening.x - 0.008))
            if portion.y - opening.y > 0.25:
                next_portions.append(Vector2(opening.y + 0.008, portion.y))
        portions = next_portions
    for portion_value in portions:
        var piece: Vector2 = portion_value
        if piece.y - piece.x > 0.34:
            # Split most center slabs into two fabricated panels, but keep
            # occasional uninterrupted main plates to avoid a rigid grid.
            if index % 4 != 0:
                _armor_panel(batches, x0, -0.032,
                    piece.x, piece.y, finish, 3, index)
                _armor_panel(batches, 0.032, x1,
                    piece.x, piece.y, _plate_finish(3, index + 2), 3, index + 1)
            else:
                _armor_panel(batches, x0, x1,
                    piece.x, piece.y, finish, 3, index)


static func _armor_panel(batches: Dictionary, x0: float, x1: float,
        z0: float, z1: float, finish: String, lane: int, index: int) -> void:
    var width: float = x1 - x0
    var length: float = z1 - z0
    var cx: float = (x0 + x1) * 0.5
    var cz: float = (z0 + z1) * 0.5

    # Actual notch-at-corners topography: the polygon mesh is shared by every
    # panel, with steel sidewalls behind the beveled upper armor shell.
    _cube(batches, "plate_skirt", Vector3(cx, 0.099, cz),
        Vector3(width - 0.018, 0.044, length - 0.018))
    _beveled_plate(batches, finish, Vector3(cx, 0.0, cz),
        Vector3(width - 0.026, 1.0, length - 0.026))

    if length > 1.0:
        # Tiny dark bolt sockets followed by a silver screw head. Their pitch
        # reflects the plate construction, not a noisy rivet grid.
        for x in [x0 + 0.15, x1 - 0.15]:
            for z in [z0 + 0.16, z1 - 0.16]:
                _bolt(batches, float(x), float(z))

    # Narrow inset tooling lines, two-stage panel labels and locking ribs.
    # Keep the interior clear: the bevel and seams should carry the detail.
    if length > 1.12 and (index + lane) % 3 == 0:
        _cube(batches, "edge_engraving",
            Vector3(cx, PLATE_TOP + 0.007, z0 + 0.17),
            Vector3(minf(0.44, width * 0.32), 0.003, 0.011))
        _cube(batches, "edge_engraving",
            Vector3(x0 + 0.13, PLATE_TOP + 0.007, z0 + 0.27),
            Vector3(0.012, 0.003, 0.14))
    if length > 1.12 and (index + lane) % 4 == 1:
        # A parallel retaining bar creates real fabricated edges without
        # drawing a thick black screen-space contour on the whole tile.
        _cube(batches, "pinstripe",
            Vector3(x1 - 0.16, PLATE_TOP + 0.006, cz),
            Vector3(0.016, 0.003, length * 0.49))

    # The old bright short center dashes looked like paint, not reflected
    # light. The steel now relies on its rough metal material and bevel
    # normals; only a low-contrast brushed streak survives on rare plates.
    if lane == 3 and length > 1.25 and index % 5 == 0:
        _cube(batches, "reflection_fringe",
            Vector3(cx + width * 0.18, PLATE_TOP + 0.005, cz),
            Vector3(0.026, 0.003, length * 0.58))

    if lane in [1, 5] and length > 1.9 and (index + lane) % 5 == 2:
        _service_lid(batches, cx, cz)


static func _beveled_plate(batches: Dictionary, finish: String,
        center: Vector3, size: Vector3) -> void:
    var key: String = "armor_" + finish
    _append(batches, key, Transform3D(
        Basis().scaled_local(size), center))


static func _bolt(batches: Dictionary, x: float, z: float) -> void:
    _disc(batches, "bolt_socket", Vector3(x, PLATE_TOP + 0.003, z),
        Vector3(0.082, 0.006, 0.082))
    _disc(batches, "bolt_metal", Vector3(x, PLATE_TOP + 0.010, z),
        Vector3(0.042, 0.006, 0.042))


static func _service_lid(batches: Dictionary, x: float, z: float) -> void:
    _cube(batches, "lid_shadow", Vector3(x, PLATE_TOP + 0.004, z),
        Vector3(0.69, 0.009, 0.42))
    _cube(batches, "lid_steel", Vector3(x, PLATE_TOP + 0.013, z),
        Vector3(0.59, 0.010, 0.34))
    for sign_value in [-1, 1]:
        _cube(batches, "bolt_metal",
            Vector3(x + float(sign_value) * 0.20,
                PLATE_TOP + 0.021, z),
            Vector3(0.040, 0.004, 0.040))


static func _light(batches: Dictionary, x: float, z: float, width: float) -> void:
    _cube(batches, "lamp_socket", Vector3(x, PLATE_TOP + 0.006, z),
        Vector3(width + 0.17, 0.009, 0.39))
    _cube(batches, "lamp_metal", Vector3(x, PLATE_TOP + 0.012, z),
        Vector3(width + 0.10, 0.009, 0.29))
    _cube(batches, "lamp_glass", Vector3(x, PLATE_TOP + 0.019, z),
        Vector3(width, 0.007, 0.15))
    # Short glint below the long lens makes it visibly embedded in steel.
    _cube(batches, "lamp_glint", Vector3(x, PLATE_TOP + 0.024, z - 0.04),
        Vector3(width * 0.83, 0.004, 0.025))



static func _inspection_bay(batches: Dictionary,
        x: float, z: float) -> void:
    # Dark gasket + inset cover + hardware; each element sits close to the
    # plate top, without the tall step of an independent equipment pedestal.
    _cube(batches, "bay_gasket", Vector3(x, PLATE_TOP + 0.003, z),
        Vector3(0.61, 0.006, 0.34))
    _cube(batches, "bay_metal", Vector3(x, PLATE_TOP + 0.009, z),
        Vector3(0.52, 0.006, 0.25))
    _cube(batches, "bay_slot", Vector3(x, PLATE_TOP + 0.013, z),
        Vector3(0.26, 0.003, 0.025))
    for side_value in [-1, 1]:
        _cube(batches, "bolt_metal",
            Vector3(x + float(side_value) * 0.20, PLATE_TOP + 0.016, z),
            Vector3(0.028, 0.004, 0.028))


static func _cross_reinforcement(batches: Dictionary, z: float) -> void:
    # Bracketed steel ties are short and flush; they interrupt the direction
    # of the long seams without a full-width horizontal bar.
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _cube(batches, "tie_recess",
            Vector3(side * 1.33, PLATE_TOP + 0.004, z),
            Vector3(0.55, 0.006, 0.092))
        _cube(batches, "tie_metal",
            Vector3(side * 1.33, PLATE_TOP + 0.009, z),
            Vector3(0.47, 0.005, 0.038))


static func _drain_shoulder(batches: Dictionary,
        z0: float, z1: float, grille_width: float) -> void:
    # Restrict the aperture to the actual framed equipment rather than
    # leaving a black full-lane opening around a much narrower grating.
    var half_grille: float = grille_width * 0.5 + 0.07
    _armor_panel(batches, -1.80, -half_grille,
        z0, z1, "deck_mid", 3, 100)
    _armor_panel(batches, half_grille, 1.80,
        z0, z1, "deck_deep", 3, 100)


static func _maintenance_grille(batches: Dictionary,
        center_z: float, width: float, depth: float) -> void:
    # The plate generator leaves this area physically open. The dark bottom
    # and bars are below the steel face to read as a recessed drain.
    _cube(batches, "drain_black", Vector3(0.0, 0.112, center_z),
        Vector3(width, 0.025, depth))
    for sign_value in [-1, 1]:
        var side: float = float(sign_value)
        _cube(batches, "drain_frame",
            Vector3(0.0, 0.145, center_z + side * depth * 0.49),
            Vector3(width + 0.14, 0.018, 0.067))
        _cube(batches, "drain_frame",
            Vector3(side * (width * 0.5 + 0.04), 0.145, center_z),
            Vector3(0.065, 0.018, depth + 0.08))
    var bar_count: int = int(width / 0.16)
    var spacing: float = width / float(bar_count)
    for i in range(bar_count):
        var px: float = -width * 0.5 + spacing * (float(i) + 0.5)
        _cube(batches, "drain_rib", Vector3(px, 0.140, center_z),
            Vector3(0.063, 0.014, depth - 0.07))
        if i % 3 == 1:
            _cube(batches, "drain_rib_glint",
                Vector3(px + 0.016, 0.150, center_z),
                Vector3(0.010, 0.004, depth - 0.15))
    # Cross bars/fasteners reinforce the frame without making a giant ladder.
    for dz in [-0.125, -0.045, 0.045, 0.125]:
        _cube(batches, "drain_cross",
            Vector3(0.0, 0.139, center_z + float(dz)),
            Vector3(width - 0.18, 0.012, 0.026))
    for x in [-width * 0.5 - 0.07, width * 0.5 + 0.07]:
        for z in [center_z - depth * 0.5, center_z + depth * 0.5]:
            _disc(batches, "bolt_socket", Vector3(float(x), 0.156, float(z)),
                Vector3(0.09, 0.009, 0.09))
            _disc(batches, "bolt_metal", Vector3(float(x), 0.164, float(z)),
                Vector3(0.043, 0.007, 0.043))


static func _append(batches: Dictionary,
        finish: String, transform: Transform3D) -> void:
    var entries: Array = batches.get(finish, [])
    entries.append(transform)
    batches[finish] = entries


static func _cube(batches: Dictionary, finish: String,
        at: Vector3, size: Vector3, yaw: float = 0.0) -> void:
    _append(batches, finish, Transform3D(
        Basis(Vector3.UP, yaw).scaled_local(size), at))


static func _disc(batches: Dictionary, finish: String,
        at: Vector3, size: Vector3) -> void:
    _append(batches, "disc_" + finish,
        Transform3D(Basis().scaled_local(size), at))


static func _chamfered_armor_mesh() -> ArrayMesh:
    # One normalized octagonal plate is instanced at arbitrary dimensions.
    # Flat top, sharply beveled perimeter, four visibly clipped corners.
    var outside: Array = [
        Vector2(-0.479, -0.500), Vector2(0.479, -0.500),
        Vector2(0.500, -0.479), Vector2(0.500, 0.479),
        Vector2(0.479, 0.500), Vector2(-0.479, 0.500),
        Vector2(-0.500, 0.479), Vector2(-0.500, -0.479)
    ]
    var inside: Array = [
        Vector2(-0.461, -0.479), Vector2(0.461, -0.479),
        Vector2(0.479, -0.461), Vector2(0.479, 0.461),
        Vector2(0.461, 0.479), Vector2(-0.461, 0.479),
        Vector2(-0.479, 0.461), Vector2(-0.479, -0.461)
    ]
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var face_color := Color(1.0, 1.0, 1.0)
    var bevel_dark := Color(0.79, 0.83, 0.87)
    var bevel_light := Color(0.96, 0.97, 1.0)
    for i in range(outside.size()):
        var j: int = (i + 1) % outside.size()
        var ti: Vector3 = Vector3(inside[i].x, PLATE_TOP, inside[i].y)
        var tj: Vector3 = Vector3(inside[j].x, PLATE_TOP, inside[j].y)
        _mesh_triangle(vertices, normals, colors,
            Vector3(0.0, PLATE_TOP, 0.0), ti, tj,
            face_color, face_color, face_color, true)
        var oi: Vector3 = Vector3(outside[i].x, 0.121, outside[i].y)
        var oj: Vector3 = Vector3(outside[j].x, 0.121, outside[j].y)
        _mesh_triangle(vertices, normals, colors, oi, ti, tj,
            bevel_dark, bevel_light, bevel_light)
        _mesh_triangle(vertices, normals, colors, oi, tj, oj,
            bevel_dark, bevel_light, bevel_dark)

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    var output := ArrayMesh.new()
    output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return output


static func _mesh_triangle(vertices: PackedVector3Array,
        normals: PackedVector3Array, colors: PackedColorArray,
        a: Vector3, b: Vector3, c: Vector3,
        col_a: Color, col_b: Color, col_c: Color,
        flat_top: bool = false) -> void:
    var normal: Vector3 = (b - a).cross(c - a).normalized()
    if flat_top:
        normal = Vector3.UP
    elif normal.y < 0.0:
        normal = -normal
    vertices.append(a)
    vertices.append(b)
    vertices.append(c)
    for i in range(3):
        normals.append(normal)
    colors.append(col_a)
    colors.append(col_b)
    colors.append(col_c)


static func _submit(room: Node3D, batches: Dictionary) -> void:
    var root := Node3D.new()
    root.name = "NexusDeckReferenceV3"
    room.add_child(root)

    var simple_cube := BoxMesh.new()
    simple_cube.size = Vector3.ONE
    var armor := _chamfered_armor_mesh()
    var disc := CylinderMesh.new()
    disc.top_radius = 0.5
    disc.bottom_radius = 0.5
    disc.height = 1.0
    disc.radial_segments = 8

    for finish_value in batches.keys():
        var key: String = String(finish_value)
        var transforms: Array = batches[key]
        var mesh_data: Mesh = simple_cube
        var material_key: String = key
        if key.begins_with("armor_"):
            mesh_data = armor
            material_key = key.trim_prefix("armor_")
        elif key.begins_with("disc_"):
            mesh_data = disc
            material_key = key.trim_prefix("disc_")
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = mesh_data
        multimesh.instance_count = transforms.size()
        for i in range(transforms.size()):
            multimesh.set_instance_transform(i, transforms[i])
        var instance := MultiMeshInstance3D.new()
        instance.name = "Deck_" + key
        instance.multimesh = multimesh
        instance.material_override = _material(material_key,
            key.begins_with("armor_"))
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        instance.set_meta("sera_outline_occluder_only", true)
        instance.set_meta("FX_NO_OUTLINE", true)
        root.add_child(instance)


static func _material(finish: String, vertex_color: bool) -> StandardMaterial3D:
    var palette: Dictionary = {
        "underdeck": Color("#1b2b38"),
        "plate_skirt": Color("#293d4d"),
        "deck_mid": Color("#425b6e"),
        "deck_deep": Color("#374e60"),
        "deck_light": Color("#4c6476"),
        "deck_side": Color("#344c5d"),
        "edge_engraving": Color("#607987"),
        "pinstripe": Color("#4a6675"),
        "reflection_fringe": Color("#476575"),
        "gutter": Color("#111b25"),
        "guard_edge": Color("#586e79"),
        "hazard_yellow": Color("#dfa926"),
        "lid_shadow": Color("#14222d"),
        "lid_steel": Color("#445d6c"),
        "bolt_socket": Color("#182834"),
        "bolt_metal": Color("#8298a4"),
        "lamp_socket": Color("#0e1b25"),
        "lamp_metal": Color("#536e7b"),
        "lamp_glass": Color("#84deff"),
        "lamp_glint": Color("#c9f6ff"),
        "drain_black": Color("#0c1a25"),
        "drain_frame": Color("#536b79"),
        "drain_rib": Color("#304c5c"),
        "drain_rib_glint": Color("#6c899a"),
        "drain_cross": Color("#223644"),
        "bay_gasket": Color("#1c303e"),
        "bay_metal": Color("#405b6b"),
        "bay_slot": Color("#1a3240"),
        "tie_recess": Color("#294252"),
        "tie_metal": Color("#637d8c")
    }
    var mat := StandardMaterial3D.new()
    var tint: Color = palette.get(finish, Color("#354858"))
    mat.albedo_color = tint
    mat.vertex_color_use_as_albedo = vertex_color
    mat.metallic = 0.56 if finish.begins_with("deck_") else 0.27
    mat.roughness = 0.36 if finish.begins_with("deck_") else 0.54
    mat.metallic_specular = 0.64 if finish.begins_with("deck_") else 0.50
    if finish.begins_with("deck_"):
        mat.clearcoat_enabled = true
        mat.clearcoat = 0.32
        mat.clearcoat_roughness = 0.19
        # The top mesh uses intentional face/bevel normals; visibility must
        # not depend on its triangle winding in Android GL Compatibility.
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    if finish in ["lamp_glass", "lamp_glint"]:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 1.7 if finish == "lamp_glass" else 1.15
    return mat
