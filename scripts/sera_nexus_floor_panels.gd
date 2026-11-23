extends RefCounted
## NEXUS hangar deck rebuilt from zero against the interior reference.
## Static opaque steel: one MultiMesh per finish, no new lights/viewports,
## no extra outline pass, and no runtime floor updates.
##
## Coordinates match the existing 15.5m-wide Blockbench hangar foundation.
## The foundation, stage, consoles, gate, camera and input targets remain intact.

const MIN_Z: float = -27.0
const MAX_Z: float = 24.6
const DECK_LENGTH: float = MAX_Z - MIN_Z
const DECK_CENTER_Z: float = (MIN_Z + MAX_Z) * 0.5
const PANEL_START_Z: float = -26.75
const PANEL_PITCH: float = 3.15
const PANEL_ROWS: int = 16
const PANEL_TOP_Y: float = 0.118

static func build(room: Node3D) -> void:
    var batches: Dictionary = {}

    # Continuous dark substrate hides the structural foundation under the
    # physical seams. Individual plate thicknesses supply bevels and shadow.
    _cube(batches, "recess", Vector3(0.0, 0.023, DECK_CENTER_Z),
        Vector3(15.10, 0.10, DECK_LENGTH))

    # Three major lanes on the central approach, with offset-length side
    # fields. This intentionally replaces the previous huge uniform slab.
    for row in range(PANEL_ROWS):
        var z0: float = PANEL_START_Z + float(row) * PANEL_PITCH + 0.055
        var z1: float = z0 + PANEL_PITCH - 0.11
        var steel: String = "steel_dark" if row % 4 == 1 else "steel_mid"
        var left: String = "steel_light" if row % 5 == 3 else steel
        var center: String = "steel_mid" if row % 3 == 0 else "steel_dark"
        var right: String = "steel_dark" if row % 4 == 2 else steel

        _plate(batches, -3.75, -1.10, z0, z1, left, true)
        # The narrow center field gives the visual rhythm of a heavy
        # interlocking industrial deck without a tiny checkerboard pattern.
        _plate(batches, -1.03, 1.03, z0, z1, center, row % 2 == 0)
        _plate(batches, 1.10, 3.75, z0, z1, right, true)

        for sign_value in [-1, 1]:
            var side: float = float(sign_value)
            if row % 3 == 2:
                _plate(batches, minf(side * 4.24, side * 5.63),
                    maxf(side * 4.24, side * 5.63),
                    z0, z1, "steel_side", false)
                _plate(batches, minf(side * 5.72, side * 7.45),
                    maxf(side * 5.72, side * 7.45),
                    z0, z1, "steel_dark", false)
            else:
                _plate(batches, minf(side * 4.24, side * 7.45),
                    maxf(side * 4.24, side * 7.45),
                    z0, z1, "steel_side", false)

        # Thin service hatch, not a large overlay that erases panel seams.
        if row % 5 == 1:
            var hatch_side: float = -1.0 if row % 2 == 1 else 1.0
            _hatch(batches, hatch_side * 5.55, (z0 + z1) * 0.5)

    # The warning tracks are narrow recessed strips alongside the main
    # walkway. Keep the yellow marks only on the front approach, as in the
    # reference, not one solid yellow plate along the full room.
    for sign_value in [-1, 1]:
        var side: float = float(sign_value)
        _cube(batches, "channel", Vector3(side * 3.985, 0.107, DECK_CENTER_Z),
            Vector3(0.34, 0.012, DECK_LENGTH - 0.20))
        _cube(batches, "bevel", Vector3(side * 3.797, 0.114, DECK_CENTER_Z),
            Vector3(0.025, 0.012, DECK_LENGTH - 0.25))
        _cube(batches, "bevel", Vector3(side * 4.170, 0.114, DECK_CENTER_Z),
            Vector3(0.025, 0.012, DECK_LENGTH - 0.25))

        # Short, diagonal bars float just above the bottom of the recess.
        # Their rotated footprint stays inside the 0.34m channel.
        for i in range(14):
            var z: float = -3.55 + float(i) * 0.90
            _cube(batches, "hazard", Vector3(side * 3.985, 0.123, z),
                Vector3(0.12, 0.012, 0.31), deg_to_rad(side * 28.0))

        # Inset cyan-white light bars with dark bezels at spaced intervals.
        # These emit light visually, without adding dynamic light sources.
        for i in range(9):
            var z: float = -23.3 + float(i) * 5.30
            _light_slot(batches, side * 6.55, z, 0.88)
        for z_value in [-8.0, 7.15]:
            _light_slot(batches, side * 2.99, float(z_value), 0.52)

    # Short drainage grilles entirely within the walkway. In the prior
    # floor the near grille was too close/wide and occupied the whole screen.
    _grille(batches, -1.95, 2.80)
    _grille(batches, 3.15, 3.45)

    # Restrained metal engraving, recessed panel catches, and subtle scuffs.
    # Kept sparse so the room remains legible at portrait Android resolution.
    for row in range(PANEL_ROWS):
        if row % 2 != 0:
            continue
        var z: float = PANEL_START_Z + float(row) * PANEL_PITCH + 1.36
        var x: float = -2.7 if row % 4 == 0 else 2.7
        _cube(batches, "scratch", Vector3(x, 0.127, z),
            Vector3(0.50, 0.003, 0.012))
        _cube(batches, "edge", Vector3(x - 0.19, 0.128, z + 0.12),
            Vector3(0.10, 0.004, 0.013))

    _submit(room, batches)


static func _plate(batches: Dictionary, x0: float, x1: float,
        z0: float, z1: float, finish: String, with_bolts: bool) -> void:
    var x: float = (x0 + x1) * 0.5
    var z: float = (z0 + z1) * 0.5
    var width: float = x1 - x0
    var length: float = z1 - z0

    # Physical bevel consists of a dark wider foot and a slightly smaller
    # upper armor piece. Every seam reveals only the opaque substrate.
    _cube(batches, "skirt", Vector3(x, 0.081, z),
        Vector3(width - 0.025, 0.043, length - 0.025))
    _cube(batches, finish, Vector3(x, 0.108, z),
        Vector3(width - 0.093, 0.020, length - 0.093))

    if with_bolts:
        for xx in [x0 + 0.16, x1 - 0.16]:
            for zz in [z0 + 0.16, z1 - 0.16]:
                _bolt(batches, float(xx), float(zz))


static func _bolt(batches: Dictionary, x: float, z: float) -> void:
    _cylinder(batches, "bolt_socket", Vector3(x, PANEL_TOP_Y + 0.003, z),
        Vector3(0.13, 0.007, 0.13))
    _cylinder(batches, "bolt", Vector3(x, PANEL_TOP_Y + 0.010, z),
        Vector3(0.078, 0.007, 0.078))


static func _hatch(batches: Dictionary, x: float, z: float) -> void:
    _cube(batches, "hatch_recess", Vector3(x, 0.122, z),
        Vector3(0.76, 0.011, 0.46))
    _cube(batches, "hatch_face", Vector3(x, 0.132, z),
        Vector3(0.67, 0.010, 0.37))
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _cube(batches, "bolt", Vector3(x + side * 0.24, 0.139, z),
            Vector3(0.048, 0.006, 0.045))


static func _light_slot(batches: Dictionary, x: float,
        z: float, width: float) -> void:
    _cube(batches, "channel", Vector3(x, 0.119, z),
        Vector3(width + 0.13, 0.013, 0.37))
    _cube(batches, "light_rim", Vector3(x, 0.128, z),
        Vector3(width + 0.06, 0.012, 0.28))
    _cube(batches, "cyan", Vector3(x, 0.137, z),
        Vector3(width, 0.012, 0.16))


static func _grille(batches: Dictionary, z: float, width: float) -> void:
    # A single deep, almost-black trough with slim metal framing is less
    # visually dominant than a full-screen row of bright vertical bars.
    _cube(batches, "drain", Vector3(0.0, 0.123, z),
        Vector3(width, 0.015, 0.48))
    for sign_value in [-1, 1]:
        var side: float = float(sign_value)
        _cube(batches, "light_rim", Vector3(0.0, 0.135, z + side * 0.228),
            Vector3(width + 0.045, 0.015, 0.045))
        _cube(batches, "edge", Vector3(side * (width * 0.5 - 0.030), 0.135, z),
            Vector3(0.055, 0.015, 0.50))
    var bars: int = int(floor(width / 0.145))
    for i in range(bars):
        var x: float = -width * 0.5 + 0.12 + float(i) * 0.145
        _cube(batches, "grille_bar", Vector3(x, 0.138, z),
            Vector3(0.045, 0.010, 0.39))
        if i % 4 == 0:
            _cube(batches, "grille_shine", Vector3(x + 0.010, 0.145, z),
                Vector3(0.013, 0.003, 0.34))


static func _cube(batches: Dictionary, finish: String,
        position: Vector3, size: Vector3, yaw: float = 0.0) -> void:
    var transforms: Array = batches.get(finish, [])
    transforms.append(Transform3D(
        Basis(Vector3.UP, yaw).scaled_local(size), position))
    batches[finish] = transforms


static func _cylinder(batches: Dictionary, finish: String,
        position: Vector3, size: Vector3) -> void:
    var key: String = "round_" + finish
    var transforms: Array = batches.get(key, [])
    transforms.append(Transform3D(Basis().scaled_local(size), position))
    batches[key] = transforms


static func _submit(room: Node3D, batches: Dictionary) -> void:
    var root := Node3D.new()
    root.name = "NexusIndustrialDeck"
    room.add_child(root)
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    var round_mesh := CylinderMesh.new()
    round_mesh.top_radius = 0.5
    round_mesh.bottom_radius = 0.5
    round_mesh.height = 1.0
    round_mesh.radial_segments = 8

    for key_value in batches.keys():
        var key: String = String(key_value)
        var transforms: Array = batches[key]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = round_mesh if key.begins_with("round_") else box
        multi.instance_count = transforms.size()
        for i in range(transforms.size()):
            multi.set_instance_transform(i, transforms[i])
        var mesh := MultiMeshInstance3D.new()
        mesh.name = "Steel_" + key
        mesh.multimesh = multi
        mesh.material_override = _finish(key.trim_prefix("round_"))
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # Opaque floor geometry occludes the player/room depth-ID outlines,
        # but neither bolts nor grates generate extraneous external strokes.
        mesh.set_meta("sera_outline_occluder_only", true)
        mesh.set_meta("FX_NO_OUTLINE", true)
        root.add_child(mesh)


static func _finish(key: String) -> StandardMaterial3D:
    var palette: Dictionary = {
        "recess": Color("#111d28"),
        "skirt": Color("#1a2a38"),
        "steel_mid": Color("#304457"),
        "steel_dark": Color("#293c4e"),
        "steel_light": Color("#34495b"),
        "steel_side": Color("#263948"),
        "edge": Color("#465d6b"),
        "scratch": Color("#496070"),
        "channel": Color("#111b25"),
        "hazard": Color("#d7a82c"),
        "drain": Color("#09141d"),
        "light_rim": Color("#526a79"),
        "cyan": Color("#9ce9ff"),
        "grille_bar": Color("#435b69"),
        "grille_shine": Color("#7996a6"),
        "hatch_recess": Color("#182633"),
        "hatch_face": Color("#344e60"),
        "bolt_socket": Color("#14232f"),
        "bolt": Color("#6e8795")
    }
    var mat := StandardMaterial3D.new()
    var tint: Color = palette.get(key, Color("#304457"))
    mat.albedo_color = tint
    mat.metallic = 0.34 if key.begins_with("steel_") else 0.22
    mat.roughness = 0.52 if key.begins_with("steel_") else 0.64
    mat.metallic_specular = 0.46
    if key == "cyan":
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = 1.75
    return mat
