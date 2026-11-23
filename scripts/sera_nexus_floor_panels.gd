extends RefCounted
## Reference-inspired COMMAND NEXUS deck. Geometry is built once and instanced
## by material: no textures, extra lights, viewports or per-frame floor updates.
## All parts are opaque, depth-tested, and occlude the shared visible-ID ink.

const ROWS: int = 13
const ROW_LENGTH: float = 3.84
const FIRST_Z: float = -25.90
const SURFACE_Y: float = 0.120

static func build(room: Node3D) -> void:
    var batches: Dictionary = {}

    # A shallow recess makes the thin real gaps readable without exposing
    # the foundation beneath the original Blockbench hangar shell.
    _box(batches, "recess", Vector3(0.0, 0.035, -0.94),
        Vector3(14.92, 0.10, 49.98))

    # Wide center panels, narrow maintenance strips, asymmetrical outer
    # service plates. Avoid a uniform grid of four identical small tiles.
    for row in range(ROWS):
        var z0: float = FIRST_Z + float(row) * ROW_LENGTH + 0.09
        var z1: float = z0 + ROW_LENGTH - 0.18
        var tone: String = "steel_a" if row % 4 < 2 else "steel_b"

        if row % 5 == 2:
            _panel(batches, -2.92, 0.32, z0, z1, tone)
            _panel(batches, 0.42, 2.92, z0, z1, "steel_c")
        else:
            _panel(batches, -2.92, 2.92, z0, z1, tone)

        _panel(batches, -4.02, -3.03, z0, z1, "steel_c", false)
        _panel(batches, 3.03, 4.02, z0, z1, "steel_c", false)

        # Offset a few secondary joints so the side fields do not form a
        # repeating checkerboard. Structural coordinates stay unchanged.
        for side_value in [-1, 1]:
            var side: float = float(side_value)
            if row % 4 == 1:
                _panel(batches, minf(side * 4.83, side * 6.02),
                    maxf(side * 4.83, side * 6.02),
                    z0, z1, "steel_b", false)
                _panel(batches, minf(side * 6.10, side * 7.45),
                    maxf(side * 6.10, side * 7.45),
                    z0, z1, "steel_a", false)
            else:
                _panel(batches, minf(side * 4.83, side * 7.45),
                    maxf(side * 4.83, side * 7.45),
                    z0, z1, "steel_b", false)

    # Dark edge channels, with individual amber diagonal safety bars instead
    # of the former continuous bright-yellow longitudinal floor slabs.
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _box(batches, "channel", Vector3(side * 4.43, 0.113, -0.92),
            Vector3(0.58, 0.022, 49.70))
        _box(batches, "rim", Vector3(side * 4.085, 0.123, -0.92),
            Vector3(0.035, 0.012, 49.70))
        _box(batches, "rim", Vector3(side * 4.775, 0.123, -0.92),
            Vector3(0.035, 0.012, 49.70))
        for i in range(18):
            var hazard_z: float = -7.0 + float(i) * 1.77
            _box(batches, "amber", Vector3(side * 4.43, 0.129, hazard_z),
                Vector3(0.38, 0.014, 0.68), deg_to_rad(side * 29.0))

        # Cool-white light bars are physically recessed in blue-grey sockets.
        # No light nodes or transparency are introduced on the deck.
        for i in range(8):
            var light_z: float = -22.25 + float(i) * 6.12
            _box(batches, "channel", Vector3(side * 6.78, 0.125, light_z),
                Vector3(0.96, 0.019, 0.44))
            _box(batches, "silver", Vector3(side * 6.78, 0.136, light_z),
                Vector3(0.87, 0.012, 0.32))
            _box(batches, "cyan", Vector3(side * 6.78, 0.144, light_z),
                Vector3(0.76, 0.012, 0.22))

    # Two crossing maintenance drains on the central approach to the stage.
    for grate_z in [5.25, 15.05]:
        _grate(batches, float(grate_z))

    # A restrained few inset service markings and worn edge strips break up
    # broad metal reflections without a noisy texture or another shader pass.
    for i in range(8):
        var service_z: float = -21.45 + float(i) * 5.55
        var service_side: float = -1.0 if i % 2 == 0 else 1.0
        _box(batches, "wear", Vector3(service_side * 1.65, 0.129, service_z),
            Vector3(1.05, 0.004, 0.018))
        _box(batches, "rim", Vector3(service_side * 2.18, 0.130, service_z + 0.19),
            Vector3(0.16, 0.005, 0.012))

    _flush(room, batches)


static func _panel(batches: Dictionary, x0: float, x1: float,
        z0: float, z1: float, tint: String, fasteners: bool = true) -> void:
    var center: Vector3 = Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
    var width: float = x1 - x0
    var length: float = z1 - z0
    # Raised underside and a slightly inset top form a subtle steel bevel;
    # leave actual dark seams between distinct plates.
    _box(batches, "underplate", Vector3(center.x, 0.090, center.z),
        Vector3(width, 0.045, length))
    _box(batches, tint, Vector3(center.x, 0.112, center.z),
        Vector3(width - 0.095, 0.017, length - 0.095))
    if fasteners and width > 1.5:
        for x in [x0 + 0.19, x1 - 0.19]:
            for z in [z0 + 0.19, z1 - 0.19]:
                _fastener(batches, Vector3(float(x), SURFACE_Y, float(z)))


static func _fastener(batches: Dictionary, at: Vector3) -> void:
    _disc(batches, "bolt_socket", at + Vector3(0.0, 0.004, 0.0),
        Vector3(0.112, 0.010, 0.112))
    _disc(batches, "bolt_head", at + Vector3(0.0, 0.012, 0.0),
        Vector3(0.065, 0.012, 0.065))


static func _grate(batches: Dictionary, z: float) -> void:
    _box(batches, "channel", Vector3(0.0, 0.130, z),
        Vector3(4.84, 0.018, 0.82))
    for side_value in [-1, 1]:
        var side: float = float(side_value)
        _box(batches, "silver", Vector3(0.0, 0.142, z + side * 0.37),
            Vector3(4.94, 0.016, 0.075))
        _box(batches, "rim", Vector3(side * 2.43, 0.144, z),
            Vector3(0.085, 0.014, 0.78))
    for i in range(23):
        var x: float = -2.20 + float(i) * 0.20
        _box(batches, "grate_bar", Vector3(x, 0.145, z),
            Vector3(0.068, 0.014, 0.65))
        if i % 3 == 0:
            _box(batches, "grate_highlight", Vector3(x + 0.020, 0.153, z),
                Vector3(0.018, 0.004, 0.55))


static func _box(batches: Dictionary, kind: String,
        center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
    var entry: Array = batches.get(kind, [])
    entry.append(Transform3D(Basis(Vector3.UP, yaw).scaled_local(size), center))
    batches[kind] = entry


static func _disc(batches: Dictionary, kind: String,
        center: Vector3, size: Vector3) -> void:
    var key: String = "disc_" + kind
    var entry: Array = batches.get(key, [])
    entry.append(Transform3D(Basis().scaled_local(size), center))
    batches[key] = entry


static func _flush(room: Node3D, batches: Dictionary) -> void:
    var node := Node3D.new()
    node.name = "ReferenceDeckPanels"
    room.add_child(node)
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    var disc := CylinderMesh.new()
    disc.top_radius = 0.5
    disc.bottom_radius = 0.5
    disc.height = 1.0
    disc.radial_segments = 8
    for key_value in batches.keys():
        var kind: String = String(key_value)
        var transforms: Array = batches[kind]
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = disc if kind.begins_with("disc_") else box
        multi.instance_count = transforms.size()
        for i in range(transforms.size()):
            multi.set_instance_transform(i, transforms[i])
        var draw := MultiMeshInstance3D.new()
        draw.name = "Deck_" + kind
        draw.multimesh = multi
        draw.material_override = _material(kind.trim_prefix("disc_"))
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # The floor blocks ink from behind but never generates its own thick
        # object outline around small rivets, drainage bars or panel joints.
        draw.set_meta("sera_outline_occluder_only", true)
        draw.set_meta("FX_NO_OUTLINE", true)
        node.add_child(draw)


static func _material(kind: String) -> StandardMaterial3D:
    var colors: Dictionary = {
        "recess": Color("#111b25"),
        "underplate": Color("#1b2a37"),
        "steel_a": Color("#33495c"),
        "steel_b": Color("#293e50"),
        "steel_c": Color("#405466"),
        "channel": Color("#0d1722"),
        "rim": Color("#4b6575"),
        "silver": Color("#69889a"),
        "amber": Color("#dca925"),
        "cyan": Color("#96eaff"),
        "bolt_socket": Color("#142431"),
        "bolt_head": Color("#7891a0"),
        "grate_bar": Color("#455c69"),
        "grate_highlight": Color("#7b9bad"),
        "wear": Color("#4a6070")
    }
    var mat := StandardMaterial3D.new()
    var color: Color = colors.get(kind, Color("#34485a"))
    mat.albedo_color = color
    mat.metallic = 0.44 if kind.begins_with("steel_") else 0.27
    mat.roughness = 0.38 if kind.begins_with("steel_") else 0.62
    mat.metallic_specular = 0.43
    if kind == "cyan":
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 2.0
    return mat
