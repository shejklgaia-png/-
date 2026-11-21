extends RefCounted
## Reference-style armored deck: panel seams, bolts, gutters, hazard routing,
## drainage grates and laid power cables. Opaque MultiMeshes, no floor textures.
const PALETTE = {
    # Detail must support silhouette separation; bright blue-gray seams are distracting.
    "seam": "#11171b", "edge": "#40474a", "bolt": "#596267",
    "grate": "#0b1114", "grille": "#353c40", "caution": "#d7a951",
    "cable": "#0f171b", "pipe": "#60594a", "mark": "#67614b",
    "site_edge": "#555751"
}
const DETAIL_RADIUS: int = 13
const PANEL_STEP: float = 3.0

static func _put(groups: Dictionary, feature: String, at: Vector3,
        size: Vector3, tint: String, yaw: float = 0.0) -> void:
    var key: String = feature + "|" + tint
    if not groups.has(key):
        groups[key] = []
    (groups[key] as Array).append(Transform3D(
        Basis(Vector3.UP, yaw).scaled_local(size), at))

static func _line(groups: Dictionary, feature: String, a: Vector3,
        b: Vector3, width: float, color: String) -> void:
    var direction: Vector3 = b - a
    if direction.length_squared() < 0.000001:
        return
    var basis := Basis(Quaternion(Vector3.UP, direction.normalized()))
    # Use the same unit cube as the other meshes; local Y is the segment axis.
    basis = basis.scaled_local(Vector3(width, direction.length(), width))
    var key: String = feature + "|" + color
    if not groups.has(key):
        groups[key] = []
    (groups[key] as Array).append(Transform3D(basis, (a + b) * 0.5))

static func decorate(floor: Node3D, panels: Array[Dictionary]) -> void:
    var root := Node3D.new()
    root.name = "DeckDetailGeometry"
    floor.add_child(root)
    var groups: Dictionary = {}
    # One source of truth: follow each actual panel outline rather than
    # drawing ghost seams on the old uniform 3m lattice.
    for panel in panels:
        var center: Vector2 = panel["center"]
        var size: Vector2 = panel["size"]
        var cx: float = center.x
        var cz: float = center.y
        if absf(cx) > DETAIL_RADIUS * PANEL_STEP + 5.0 or (
                absf(cz) > DETAIL_RADIUS * PANEL_STEP + 5.0):
            continue
        var edge_x: float = size.x * 0.5 - 0.085
        var edge_z: float = size.y * 0.5 - 0.085
        var wear: int = posmod(int(panel["style"]), 7)
        var site_id: String = str(panel["site"])
        var edge_tint: String = (
            "site_edge" if not site_id.is_empty() else
            "edge" if wear in [0, 1] else "seam")
        for side in [-1.0, 1.0]:
            _put(groups, "PanelSeams",
                Vector3(cx + side * edge_x, -0.016, cz),
                Vector3(0.026, 0.023, maxf(0.45, size.y - 0.20)), edge_tint)
            _put(groups, "PanelSeams",
                Vector3(cx, -0.014, cz + side * edge_z),
                Vector3(maxf(0.45, size.x - 0.20), 0.023, 0.026), edge_tint)
            for corner in [-1.0, 1.0]:
                _put(groups, "DeckBolts",
                    Vector3(cx + side * (edge_x - 0.12), 0.008,
                        cz + corner * (edge_z - 0.12)),
                    Vector3(0.095, 0.045, 0.095), "bolt")
        if site_id.is_empty():
            # Small recessed access grooves sit inside the large armor plates.
            if wear in [1, 3, 6] and size.x >= 2.8 and size.y >= 2.8:
                _put(groups, "AccessPanelJoints",
                    Vector3(cx - 0.28, -0.006, cz),
                    Vector3(0.025, 0.025, 1.30), "seam")
                _put(groups, "AccessPanelJoints",
                    Vector3(cx + 0.28, -0.006, cz + 0.65),
                    Vector3(1.10, 0.023, 0.028), "edge")
            # Actual grilles / hatches scale to the available slab footprint.
            if wear == 2 and size.x >= 2.8 and size.y >= 2.8:
                var grate_x: float = minf(size.x * 0.64, 1.68)
                var grate_z: float = minf(size.y * 0.62, 1.12)
                _put(groups, "DrainGrates", Vector3(cx, 0.004, cz),
                    Vector3(grate_x, 0.028, grate_z), "grate")
                for slit in range(8):
                    _put(groups, "DrainGrates",
                        Vector3(cx - grate_x * 0.42 + float(slit) * grate_x * 0.12,
                            0.026, cz),
                        Vector3(0.070, 0.025, grate_z * 0.90), "grille")
            elif wear == 4 and size.x >= 2.8 and size.y >= 2.8:
                _put(groups, "MaintenanceHatches",
                    Vector3(cx + 0.20, 0.007, cz - 0.10),
                    Vector3(1.36, 0.025, 0.88), "seam")
                for row in range(4):
                    _put(groups, "MaintenanceHatches",
                        Vector3(cx - 0.32 + float(row) * 0.35, 0.024, cz - 0.10),
                        Vector3(0.045, 0.017, 0.72), "edge")
        else:
            # Large one-piece foundations are deliberately uninterrupted:
            # no central grates, hatches, repair seams or division marks.
            # Additional perimeter fasteners emphasize a single steel slab.
            for ix in range(1, maxi(1, floori(size.x / 1.50))):
                var at_x: float = cx - size.x * 0.5 + float(ix) * 1.50
                for side in [-1.0, 1.0]:
                    _put(groups, "FacilityPanelBolts",
                        Vector3(at_x, 0.009, cz + side * edge_z),
                        Vector3(0.105, 0.046, 0.105), "bolt")
            for iz in range(1, maxi(1, floori(size.y / 1.50))):
                var at_z: float = cz - size.y * 0.5 + float(iz) * 1.50
                for side in [-1.0, 1.0]:
                    _put(groups, "FacilityPanelBolts",
                        Vector3(cx + side * edge_x, 0.009, at_z),
                        Vector3(0.105, 0.046, 0.105), "bolt")
    # Independently routed diagonal industrial safety lanes and short dashes.
    for i in range(-15, 16):
        var p: float = float(i) * 1.05
        _put(groups, "CautionStripes", Vector3(-4.95, 0.020, p),
            Vector3(0.13, 0.028, 0.58), "caution", -0.06)
        _put(groups, "CautionStripes", Vector3(5.12, 0.020, p + 0.25),
            Vector3(0.13, 0.028, 0.58), "caution", 0.05)
    for i in range(17):
        var x: float = -17.0 + float(i) * 2.0
        _put(groups, "CautionStripes", Vector3(x, 0.022, 5.90),
            Vector3(0.88, 0.025, 0.10), "caution")
        _put(groups, "CautionStripes", Vector3(x, 0.022, -7.70),
            Vector3(0.88, 0.025, 0.10), "caution")
    # Conduits follow the deck edges; keep the LABO and CRATE central lane clear.
    for side in [-1.0, 1.0]:
        var x: float = side * 10.20
        _line(groups, "PowerConduits", Vector3(x, 0.08, -18.0),
            Vector3(x, 0.08, 16.0), 0.105, "cable")
        _line(groups, "PowerConduits", Vector3(x + side * 0.20, 0.08, -18.0),
            Vector3(x + side * 0.20, 0.08, 16.0), 0.075, "pipe")
        for j in range(-9, 10):
            _put(groups, "ConduitClamps", Vector3(x + side * 0.10,
                0.086, float(j) * 1.72), Vector3(0.42, 0.09, 0.14), "bolt")
    # Stencil stencil-like deck insignia formed of flat strips.
    for side in [-1.0, 1.0]:
        _line(groups, "DeckMarkings", Vector3(side * 0.16, 0.028, 9.1),
            Vector3(side * 0.85, 0.028, 9.8), 0.08, "mark")
        _line(groups, "DeckMarkings", Vector3(side * 0.85, 0.028, 9.8),
            Vector3(side * 0.16, 0.028, 10.4), 0.08, "mark")
    for key_variant in groups.keys():
        var key: String = str(key_variant)
        var fields: PackedStringArray = key.split("|")
        var poses: Array = groups[key]
        var mesh := BoxMesh.new()
        mesh.size = Vector3.ONE
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = mesh
        multi.custom_aabb = AABB(Vector3(-45, -0.3, -45),
            Vector3(90, 1.2, 90))
        multi.instance_count = poses.size()
        for i in range(poses.size()):
            multi.set_instance_transform(i, poses[i])
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(PALETTE[fields[1]])
        material.metallic = 0.25
        material.roughness = 0.83
        var draw := MultiMeshInstance3D.new()
        draw.name = fields[0] + "_" + fields[1]
        draw.multimesh = multi
        draw.material_override = material
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(draw)
