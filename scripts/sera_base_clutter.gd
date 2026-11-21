extends RefCounted
## Purpose-built 3D yard accessories. All pieces are appended to the existing
## opaque/instanced facility Batch; no per-prop MeshInstance nodes or simulation.
## Stable local XZ positions preserve the single-panel slab and entrance clearance.

# Ground-facing shapes are authored at real floor height (panel top is y=-0.03).
const FLOOR_OFFSET: float = -0.16
const FOOTPRINTS = {
    "antenna_case": Vector2(0.74, 0.68),
    "signal_console": Vector2(0.90, 0.78),
    "armored_bundle": Vector2(1.12, 0.76),
    "cable_reel": Vector2(0.96, 0.90),
    "cargo_box": Vector2(0.96, 0.88),
    "power_box": Vector2(0.88, 0.77),
    "sensor_tripod": Vector2(0.70, 0.70),
    "tool_cabinet": Vector2(0.88, 0.76),
    "parts_tray": Vector2(1.00, 0.80),
    "spare_arm": Vector2(1.05, 0.84),
    "armor_rack": Vector2(1.10, 0.82),
    "tool_cart": Vector2(1.10, 0.85),
    "worklight": Vector2(0.70, 0.69),
    "ingot_pallet": Vector2(1.18, 0.95),
    "slag_bin": Vector2(1.00, 0.88),
    "coolant_tank": Vector2(0.95, 0.90),
    "casting_mold": Vector2(1.00, 0.83),
    "pipe_bundle": Vector2(1.11, 0.81),
    "pressure_valve": Vector2(0.80, 0.79),
    "scrap_gears": Vector2(1.04, 0.86),
    "bent_armor": Vector2(1.09, 0.88),
    "crusher_bin": Vector2(1.03, 0.86),
    "spare_roller": Vector2(0.95, 0.87),
    "hydraulic_kit": Vector2(0.94, 0.81),
    "scrap_hopper": Vector2(1.10, 0.86),
    "wheel": Vector2(0.81, 0.82),
    "old_joint": Vector2(0.98, 0.84),
    "rack_stack": Vector2(1.08, 0.87),
    "straps": Vector2(0.92, 0.88),
    "pallet": Vector2(1.10, 0.90),
    "panel_stack": Vector2(1.12, 0.89),
    "battery": Vector2(0.92, 0.88),
    "transformer": Vector2(0.90, 0.85),
    "coil_pack": Vector2(0.91, 0.91),
    "insulator": Vector2(0.82, 0.74),
    "construction_frame": Vector2(1.08, 0.83),
    "laser_measure": Vector2(0.75, 0.73),
    "fastener_box": Vector2(0.83, 0.79),
    "calibration_stand": Vector2(0.80, 0.79),
    "building_parts": Vector2(1.08, 0.84),
}

static func _item(kind: String, x: float, z: float,
        scale_factor: float = 1.0) -> Dictionary:
    return {"kind": kind, "at": Vector2(x, z), "scale": scale_factor}

static func props_for(key: String) -> Array[Dictionary]:
    match key:
        "NEXUS":
            return [
                _item("antenna_case", -4.28, -4.95),
                _item("signal_console", 4.30, -4.60),
                _item("armored_bundle", -4.26, -2.38),
                _item("cable_reel", 4.35, -2.35),
                _item("cargo_box", 4.40, 0.15),
                _item("power_box", -4.27, 0.15),
                _item("sensor_tripod", 4.32, 2.60),
                _item("tool_cart", -4.25, 4.10),
            ]
        "LABO":
            return [
                _item("tool_cabinet", -3.12, -2.42),
                _item("parts_tray", 3.17, -2.35),
                _item("spare_arm", -3.10, -0.75),
                _item("armor_rack", 3.16, -0.70),
                _item("tool_cart", -3.14, 1.12),
                _item("cable_reel", 3.15, 1.15),
                _item("cargo_box", -3.13, 2.75),
                _item("worklight", 3.18, 2.74),
            ]
        "SMELTER":
            return [
                _item("ingot_pallet", -2.09, -1.93),
                _item("slag_bin", 2.10, -1.89),
                _item("coolant_tank", -2.10, 0.05),
                _item("casting_mold", 2.10, 0.08),
                _item("pipe_bundle", -2.07, 1.95),
                _item("pressure_valve", 2.10, 1.97),
            ]
        "RECYCLER":
            return [
                _item("scrap_gears", -2.10, -1.93),
                _item("bent_armor", 2.10, -1.88),
                _item("crusher_bin", -2.10, 0.03),
                _item("spare_roller", 2.08, 0.06),
                _item("hydraulic_kit", -2.08, 1.96),
                _item("scrap_hopper", 2.10, 1.94),
            ]
        "SCRAP_COLLECTOR":
            return [
                _item("scrap_hopper", -2.07, -1.90),
                _item("wheel", 2.10, -1.91),
                _item("old_joint", -2.09, 0.04),
                _item("bent_armor", 2.09, 0.06),
                _item("cargo_box", -2.10, 1.94),
                _item("hydraulic_kit", 2.11, 1.98),
            ]
        "STORAGE":
            return [
                _item("rack_stack", -2.10, -1.92),
                _item("cargo_box", 2.10, -1.89),
                _item("straps", -2.09, 0.02),
                _item("pipe_bundle", 2.08, 0.05),
                _item("pallet", -2.10, 1.99),
                _item("panel_stack", 2.08, 1.98),
            ]
        "GENERATOR":
            return [
                _item("battery", -2.10, -1.90),
                _item("transformer", 2.10, -1.91),
                _item("coil_pack", -2.08, 0.04),
                _item("insulator", 2.10, 0.06),
                _item("cable_reel", -2.12, 1.95),
                _item("power_box", 2.10, 1.97),
            ]
        "BUILD_TERMINAL":
            return [
                _item("construction_frame", -2.09, -1.90),
                _item("panel_stack", 2.09, -1.92),
                _item("laser_measure", -2.08, 0.04),
                _item("fastener_box", 2.11, 0.06),
                _item("calibration_stand", -2.08, 1.95),
                _item("building_parts", 2.09, 1.95),
            ]
        _:
            return []

static func bounds_for(kind: String) -> Vector2:
    return FOOTPRINTS.get(kind, Vector2.ZERO)

# Author props in the facility's local coordinates, never a translated
# world-space duplicate. Accessories use preexisting material names only.
static func _box(g: Variant, name: String, at: Vector2, k: float,
        offset: Vector3, size: Vector3, tint: String,
        angle: float = 0.0) -> void:
    g.box("Yard_" + name,
        Vector3(at.x + offset.x * k, offset.y * k + FLOOR_OFFSET, at.y + offset.z * k),
        size * k, tint, angle)

static func _rod(g: Variant, name: String, at: Vector2, k: float,
        a: Vector3, b: Vector3, thickness: float, tint: String) -> void:
    g.rod("Yard_" + name,
        Vector3(at.x + a.x * k, a.y * k + FLOOR_OFFSET, at.y + a.z * k),
        Vector3(at.x + b.x * k, b.y * k + FLOOR_OFFSET, at.y + b.z * k),
        thickness * k, tint)

static func _ring(g: Variant, name: String, at: Vector2, k: float,
        offset: Vector3, radius: float, tint: String,
        axis: String = "y") -> void:
    g.ring("Yard_" + name,
        Vector3(at.x + offset.x * k, offset.y * k, at.y + offset.z * k),
        radius * k, tint, axis)

static func _make(g: Variant, kind: String, at: Vector2, k: float,
        order: int) -> void:
    var tint: String = (
        "rust" if order % 7 == 2 else
        "armor_light" if order % 4 == 0 else "slate")
    # A thin skid sits flush against the physical floor, independent of size.
    var footprint: Vector2 = bounds_for(kind) * k
    g.box("Yard_" + kind + "_skid", Vector3(at.x, -0.006, at.y),
        Vector3(footprint.x * 0.75, 0.05, footprint.y * 0.74), "rubber")
    # Every kind has a distinct functional silhouette; repeats use subtly
    # different patina while staying inside the authored conservative bounds.
    match kind:
        "cargo_box":
            g.crate(Vector3(at.x, 0.38 * k + FLOOR_OFFSET, at.y),
                Vector3(0.69, 0.55, 0.62) * k, order)
            _box(g, kind, at, k, Vector3(0, 0.72, 0),
                Vector3(0.40, 0.06, 0.42), "gold")
        "power_box", "tool_cabinet", "battery", "transformer", "fastener_box":
            var tall: float = 0.86 if kind in ["tool_cabinet", "transformer"] else 0.52
            _box(g, kind, at, k, Vector3(0, 0.19 + tall * 0.5, 0),
                Vector3(0.64, tall, 0.58), tint)
            _box(g, kind + "_top", at, k, Vector3(0, 0.23 + tall, 0),
                Vector3(0.70, 0.075, 0.62), "edge")
            for j in range(3):
                _box(g, kind + "_grille", at, k,
                    Vector3(-0.17 + j * 0.17, 0.31 + tall * 0.26, 0.308),
                    Vector3(0.08, 0.11, 0.035), "dark")
            _box(g, kind + "_indicator", at, k, Vector3(0.16, 0.29 + tall * 0.46, 0.314),
                Vector3(0.09, 0.07, 0.04),
                "blue_light" if kind in ["power_box", "battery"] else "gold")
        "signal_console", "laser_measure", "calibration_stand":
            _box(g, kind + "_stand", at, k, Vector3(0, 0.40, 0),
                Vector3(0.50, 0.70, 0.43), "trim")
            _box(g, kind + "_glass", at, k, Vector3(0, 0.84, 0.23),
                Vector3(0.54, 0.46, 0.08), "blue")
            for j in range(3):
                _box(g, kind + "_glyph", at, k, Vector3(-0.13, 0.76 + j*0.12, 0.275),
                    Vector3(0.24, 0.025, 0.015), "blue_light")
            _rod(g, kind + "_sensor", at, k,
                Vector3(0.25, 0.50, -0.13), Vector3(0.25, 1.30, -0.13),
                0.045, "edge")
        "antenna_case", "sensor_tripod", "worklight":
            _box(g, kind + "_base", at, k, Vector3(0, 0.25, 0),
                Vector3(0.45, 0.40, 0.45), "trim")
            _rod(g, kind + "_mast", at, k,
                Vector3(0, 0.42, 0), Vector3(0, 1.55, 0),
                0.075, "edge")
            for arm in [-1.0, 1.0]:
                _rod(g, kind + "_leg", at, k,
                    Vector3(0, 0.51, 0), Vector3(arm * 0.25, 0.18, 0.14),
                    0.055, "armor_light")
            _box(g, kind + "_lamp", at, k, Vector3(0, 1.58, 0.05),
                Vector3(0.31, 0.18, 0.16),
                "amber_light" if kind == "worklight" else "blue_light")
        "cable_reel", "coil_pack", "wheel", "spare_roller":
            _rod(g, kind + "_axle", at, k,
                Vector3(0, 0.39, -0.30), Vector3(0, 0.39, 0.30),
                0.23, "trim")
            for side in [-1.0, 1.0]:
                _ring(g, kind + "_rim", at, k,
                    Vector3(0, 0.42, side * 0.26), 0.32,
                    "gold" if kind == "cable_reel" else "edge", "z")
            for j in range(4):
                _box(g, kind + "_winding", at, k,
                    Vector3(-0.21 + 0.14*j, 0.41, 0),
                    Vector3(0.052, 0.60, 0.38),
                    "blue" if kind == "coil_pack" else "rubber")
        "armored_bundle", "armor_rack", "bent_armor", "panel_stack", "building_parts":
            _box(g, kind + "_rack", at, k, Vector3(0, 0.19, 0),
                Vector3(0.78, 0.16, 0.60), "trim")
            for j in range(4):
                _box(g, kind + "_plate", at, k,
                    Vector3(-0.22 + j * 0.14, 0.36 + j * 0.13, 0),
                    Vector3(0.58, 0.075, 0.52), tint, 0.07 * j)
                _box(g, kind + "_reinforcement", at, k,
                    Vector3(-0.20 + j * 0.14, 0.43 + j * 0.13, -0.13),
                    Vector3(0.45, 0.04, 0.07), "edge")
        "parts_tray", "tool_cart", "hydraulic_kit", "old_joint":
            _box(g, kind + "_tray", at, k, Vector3(0, 0.34, 0),
                Vector3(0.80, 0.17, 0.62), "armor")
            if kind == "tool_cart":
                for side in [-1.0, 1.0]:
                    _ring(g, kind + "_castor", at, k,
                        Vector3(side * 0.28, 0.16, 0.18), 0.14, "rubber", "z")
            for j in range(5):
                _rod(g, kind + "_tool", at, k,
                    Vector3(-0.30 + j * 0.15, 0.48, -0.20),
                    Vector3(-0.23 + j * 0.15, 0.48 + (j % 2) * 0.08, 0.20),
                    0.063, "gold" if j % 3 == 0 else "edge")
            if kind in ["old_joint", "hydraulic_kit"]:
                _rod(g, kind + "_piston", at, k,
                    Vector3(-0.20, 0.55, 0), Vector3(0.26, 0.90, 0),
                    0.14, "rust")
        "casting_mold":
            _box(g, kind + "_outer", at, k, Vector3(0, 0.35, 0),
                Vector3(0.81, 0.37, 0.63), "rust")
            _box(g, kind + "_inner", at, k, Vector3(0, 0.56, 0),
                Vector3(0.56, 0.055, 0.40), "dark")
            for side in [-1.0, 1.0]:
                _box(g, kind + "_rim", at, k,
                    Vector3(side * 0.38, 0.57, 0),
                    Vector3(0.07, 0.08, 0.66), "edge")
        "straps":
            _box(g, kind + "_load", at, k, Vector3(0, 0.30, 0),
                Vector3(0.73, 0.39, 0.58), "crate")
            for side in [-1.0, 1.0]:
                _box(g, kind + "_tie", at, k,
                    Vector3(side * 0.21, 0.52, 0),
                    Vector3(0.085, 0.055, 0.61), "gold")
                _box(g, kind + "_buckle", at, k,
                    Vector3(side * 0.21, 0.43, 0.32),
                    Vector3(0.14, 0.16, 0.048), "edge")
        "spare_arm", "pressure_valve", "insulator", "construction_frame":
            _box(g, kind + "_support", at, k, Vector3(0, 0.25, 0),
                Vector3(0.62, 0.18, 0.55), "trim")
            for side in [-1.0, 1.0]:
                _rod(g, kind + "_frame", at, k,
                    Vector3(side * 0.20, 0.31, -0.20),
                    Vector3(side * 0.18, 1.12, -0.16), 0.07, "armor_light")
            _rod(g, kind + "_piston", at, k,
                Vector3(-0.19, 1.10, -0.15), Vector3(0.26, 0.60, 0.20),
                0.18, "gold")
            _ring(g, kind + "_joint", at, k, Vector3(0.06, 0.89, 0.0),
                0.19, "edge", "z")
            if kind == "construction_frame":
                _rod(g, kind + "_crossbar", at, k,
                    Vector3(-0.26, 1.12, 0.16), Vector3(0.24, 1.12, 0.16),
                    0.09, "gold")
            elif kind == "spare_arm":
                for side in [-1.0, 1.0]:
                    _rod(g, kind + "_finger", at, k,
                        Vector3(0.25, 0.61, 0.17),
                        Vector3(0.29 + side * 0.15, 0.47, 0.25),
                        0.07, "edge")
            elif kind == "pressure_valve":
                _ring(g, kind + "_wheel", at, k,
                    Vector3(0.07, 1.22, 0.0), 0.23, "gold")
            elif kind == "insulator":
                for row in range(3):
                    _ring(g, kind + "_ceramic", at, k,
                        Vector3(0.07, 0.49 + 0.19 * row, 0),
                        0.23, "white")
        "ingot_pallet", "pallet", "rack_stack":
            _box(g, kind + "_pallet", at, k, Vector3(0, 0.20, 0),
                Vector3(0.93, 0.16, 0.70), "rust")
            if kind == "pallet":
                for j in range(3):
                    _box(g, kind + "_slat", at, k,
                        Vector3(-0.27 + 0.27 * j, 0.31, 0),
                        Vector3(0.19, 0.08, 0.67), "edge")
            else:
                for j in range(6):
                    var xx: float = -0.28 + float(j % 3) * 0.28
                    var zz: float = -0.18 + float(j / 3) * 0.35
                    _box(g, kind + "_load", at, k,
                        Vector3(xx, 0.38 + float(j % 2) * 0.11, zz),
                        Vector3(0.23, 0.24, 0.24),
                        "armor_light" if j % 3 == 0 else "slate")
                if kind == "rack_stack":
                    for side in [-1.0, 1.0]:
                        _rod(g, kind + "_rack_post", at, k,
                            Vector3(side * 0.43, 0.28, -0.30),
                            Vector3(side * 0.43, 1.04, -0.30),
                            0.08, "gold")
        "slag_bin", "crusher_bin", "scrap_hopper":
            _box(g, kind + "_hopper", at, k, Vector3(0, 0.40, 0),
                Vector3(0.79, 0.56, 0.68), "trim")
            _box(g, kind + "_rim", at, k, Vector3(0, 0.73, 0),
                Vector3(0.87, 0.10, 0.74), "edge")
            for j in range(4):
                _box(g, kind + "_waste", at, k,
                    Vector3(-0.22 + j * 0.15, 0.80 + float(j % 2) * 0.10, 0),
                    Vector3(0.15, 0.17, 0.25),
                    "rust" if kind == "slag_bin" else "armor_light")
        "coolant_tank":
            _rod(g, kind + "_vessel", at, k,
                Vector3(0, 0.27, 0), Vector3(0, 1.10, 0), 0.50, "slate")
            for y in [0.30, 0.98]:
                _ring(g, kind + "_clamp", at, k,
                    Vector3(0, y, 0), 0.28, "edge")
            _rod(g, kind + "_hose", at, k,
                Vector3(0, 0.90, 0.25), Vector3(0.26, 0.57, 0.27),
                0.08, "rubber")
        "pipe_bundle":
            for j in range(4):
                _rod(g, kind + "_pipes", at, k,
                    Vector3(-0.31 + j * 0.20, 0.25, -0.34),
                    Vector3(-0.31 + j * 0.20, 0.25, 0.34),
                    0.12, "armor_light" if j % 2 else "rust")
            for z in [-0.22, 0.22]:
                _box(g, kind + "_band", at, k,
                    Vector3(0, 0.34, z), Vector3(0.88, 0.06, 0.07), "gold")
        "scrap_gears":
            for j in range(3):
                var ox: float = -0.22 + float(j)*0.22
                _ring(g, kind + "_gear", at, k,
                    Vector3(ox, 0.39 + float(j % 2)*0.22, 0),
                    0.18, "edge")
                _rod(g, kind + "_hub", at, k,
                    Vector3(ox, 0.19, 0), Vector3(ox, 0.51, 0), 0.11, "rust")
        _:
            _box(g, "misc_" + kind, at, k, Vector3(0, 0.32, 0),
                Vector3(0.65, 0.34, 0.59), tint)

static func decorate(g: Variant, key: String) -> void:
    var props: Array[Dictionary] = props_for(key)
    for index in range(props.size()):
        var p: Dictionary = props[index]
        _make(g, str(p["kind"]), p["at"] as Vector2, float(p["scale"]), index)
    # The renderer is a material-batched procedural model; this metadata lets
    # independent runtime tests verify actual scene construction.
    g.host.set_meta("clutter_props", props)
