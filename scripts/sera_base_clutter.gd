extends RefCounted
const JunkGeometry = preload("res://scripts/sera_base_junk_geometry.gd")
## Purpose-built 3D yard accessories. All pieces are appended to the existing
## opaque/instanced facility Batch; no per-prop MeshInstance nodes or simulation.
## Stable local XZ positions preserve the single-panel slab and entrance clearance.

# Ground-facing shapes are authored at real floor height (panel top is y=-0.03).
const FLOOR_OFFSET: float = -0.16
# Matches the BASE camera azimuth atan2(21, 27.2) ~= 37.7 degrees.
# Keep each item locally rotated rather than rotating all yard positions.
const VIEW_AZIMUTH_DEGREES: float = 38.0
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
    "sealed_canister": Vector2(0.44, 0.44),
    "beacon_spares": Vector2(0.44, 0.44),
    "micro_servo": Vector2(0.44, 0.44),
    "welding_mask": Vector2(0.42, 0.44),
    "slag_sample": Vector2(0.44, 0.44),
    "heat_shield": Vector2(0.36, 0.42),
    "gear_pin": Vector2(0.44, 0.44),
    "cutter_tooth": Vector2(0.44, 0.44),
    "servo_joint": Vector2(0.44, 0.44),
    "grip_fingers": Vector2(0.44, 0.44),
    "packing_wedges": Vector2(0.44, 0.44),
    "folded_tarp": Vector2(0.44, 0.44),
    "ceramic_fuse": Vector2(0.44, 0.44),
    "busbar_kit": Vector2(0.44, 0.44),
    "blueprint_tube": Vector2(0.44, 0.44),
    "locator_beacon": Vector2(0.44, 0.44),
}

# A tier is an actual translated set of meshes, not a label or oversized box.
static func _item(kind: String, x: float, z: float,
        scale_factor: float = 1.0, stack_count: int = 1) -> Dictionary:
    return {"kind": kind, "at": Vector2(x, z),
        "scale": scale_factor, "stack": stack_count}

# Compact extras are visually adjacent to their large industrial prop cluster.
# They do not change the main four-beat composition or its open walkway.
static func _accent(kind: String, x: float, z: float) -> Dictionary:
    var item: Dictionary = _item(kind, x, z)
    item["accent"] = true
    return item

const COMPACT_KINDS = [
    "sealed_canister",
    "beacon_spares",
    "micro_servo",
    "welding_mask",
    "slag_sample",
    "heat_shield",
    "gear_pin",
    "cutter_tooth",
    "servo_joint",
    "grip_fingers",
    "packing_wedges",
    "folded_tarp",
    "ceramic_fuse",
    "busbar_kit",
    "blueprint_tube",
    "locator_beacon",
]

# Rhythmic site plan: a compact run of four near one edge, a generous
# opposing empty band, and a smaller isolated accent. Dense sides alternate
# between facilities; the central walkway remains clear. Keep this authored,
# not randomized, to preserve navigation and phone-sized visual hierarchy.
# Scene construction is deterministic; randomized counts differ by site/type but
# never re-roll on every frame or device restart.
static func _stable_seed(key: String, kind: String, index: int) -> int:
    var h: int = 17
    var value: String = key + "/" + kind
    for i in range(value.length()):
        h = posmod(h * 131 + value.unicode_at(i), 2147483647)
    return posmod(h + index * 104729, 2147483647)

static func is_stack_container(kind: String) -> bool:
    return kind in ["cargo_box", "fastener_box", "power_box", "battery"]

static func stack_count_for(key: String, kind: String, index: int) -> int:
    var seed: int = _stable_seed(key, kind, index)
    if is_stack_container(kind):
        return 1 + posmod(seed + int(seed / 7), 4)
    return 1 + posmod(seed, 3)

# Evaluate each rotated footprint against the existing device/door clear zone
# and other complete prop clusters. Never move authored coordinates, and never
# apply a different angle to boxes in the same supported container stack.
static func _yaw_rect(item: Dictionary, degrees: float) -> Rect2:
    var size: Vector2 = bounds_for(str(item["kind"])) * float(item["scale"])
    var theta: float = deg_to_rad(degrees)
    var c: float = absf(cos(theta))
    var q: float = absf(sin(theta))
    var rotated := Vector2(size.x * c + size.y * q,
        size.x * q + size.y * c)
    return Rect2((item["at"] as Vector2) - rotated * 0.5, rotated)

static func _clear_zone(key: String) -> Rect2:
    if key == "NEXUS":
        return Rect2(Vector2(-3.38, -2.85), Vector2(6.76, 6.60))
    if key == "LABO":
        return Rect2(Vector2(-2.18, -1.98), Vector2(4.36, 4.98))
    return Rect2(Vector2(-1.37, -1.37), Vector2(2.74, 2.86))

static func _safe_prop_yaw(key: String, items: Array[Dictionary],
        index: int, degrees: float) -> bool:
    var candidate: Rect2 = _yaw_rect(items[index], degrees)
    if candidate.intersects(_clear_zone(key)):
        return false
    for j in range(items.size()):
        if j == index:
            continue
        # Earlier clusters use their committed angle, later clusters reserve
        # the unchanged physical footprint; no newly introduced overlaps.
        var other: Dictionary = items[j]
        var angle: float = float(other.get("yaw_deg", 0.0)) if j < index else 0.0
        if candidate.intersects(_yaw_rect(other, angle)):
            return false
    return true

# Each prop remains at its authored location. Grow only while its complete
# conservative footprint clears the machine/entrance zone and all other props.
# Check both zero-yaw and real yaw so the fixed slab, stack and old Godot
# unrotated-footprint collision tests stay valid. Setup-only, no frame work.
# Grow without moving a cluster off its original station. Nearby machinery,
# door corridors and other cargo remain open in both neutral and final yaw.
# If the original slant will intersect an enlarged neighbor, gently reduce
# that slant but preserve at least 15 degrees toward the viewer.
static func _best_enlarged_yaw(key: String, items: Array[Dictionary],
        index: int, multiplier: float) -> float:
    var candidate: Dictionary = items[index].duplicate()
    candidate["scale"] = float(candidate["scale"]) * multiplier
    var straight: Rect2 = _yaw_rect(candidate, 0.0)
    var restricted: Rect2 = _clear_zone(key)
    if straight.intersects(restricted):
        return -1.0
    for j in range(items.size()):
        if j != index and straight.intersects(_yaw_rect(items[j], 0.0)):
            return -1.0
    var authored_yaw: float = float(candidate.get("yaw_deg", 0.0))
    for fraction in [1.0, 0.8, 0.6, 0.4, 0.2]:
        var desired_yaw: float = authored_yaw * float(fraction)
        if desired_yaw < 15.0:
            continue
        var rotated: Rect2 = _yaw_rect(candidate, desired_yaw)
        if rotated.intersects(restricted):
            continue
        var blocked: bool = false
        for j in range(items.size()):
            if j == index:
                continue
            var other: Dictionary = items[j]
            if rotated.intersects(_yaw_rect(other,
                    float(other.get("yaw_deg", 0.0)))):
                blocked = true
                break
        if not blocked:
            return desired_yaw
    return -1.0


static func _enlarge_dressing(key: String, items: Array[Dictionary]) -> void:
    # Free-standing objects: up to 26%. Close clusters, upper-tier loads,
    # mini accessories: up to 18%. Preserve each supported stack as one
    # proportional assembly; no per-frame scaling or extra MeshInstances.
    for i in range(items.size()):
        var item: Dictionary = items[i]
        var limit: float = 1.26
        if bool(item.get("accent", false)):
            limit = 1.18
        elif int(item.get("stack", 1)) > 1:
            limit = 1.18
        for step in range(13, 0, -1):
            var candidate: float = 1.0 + float(step) * 0.02
            if candidate > limit + 0.001:
                continue
            var yaw: float = _best_enlarged_yaw(key, items, i, candidate)
            if yaw >= 0.0:
                item["scale"] = float(item["scale"]) * candidate
                item["yaw_deg"] = yaw
                items[i] = item
                break

static func props_for(key: String) -> Array[Dictionary]:
    var items: Array[Dictionary] = _authored_props_for(key)
    for index in range(items.size()):
        var item: Dictionary = items[index]
        var kind: String = str(item["kind"])
        if int(item["stack"]) > 1:
            var count: int = stack_count_for(key, kind, index)
            item["stack"] = count
            items[index] = item
    for index in range(items.size()):
        var item: Dictionary = items[index]
        var kind: String = str(item["kind"])
        var seed: int = _stable_seed(key, kind, index)
        # Orient most visual piles toward the viewer, with side-to-side
        # variety instead of parallel rows. Safety has priority at tight gaps.
        var direction: float = -1.0 if index % 2 == 0 else 1.0
        var desired: float = VIEW_AZIMUTH_DEGREES + direction * (
            10.0 + float(posmod(seed, 10)))
        var chosen: float = 0.0
        for fraction in [1.0, 0.85, 0.70, 0.55, 0.40]:
            var candidate: float = lerpf(VIEW_AZIMUTH_DEGREES, desired, fraction)
            if _safe_prop_yaw(key, items, index, candidate):
                chosen = candidate
                break
        # A crowded corner can keep a smaller, still purposeful turn.
        if chosen == 0.0:
            for fraction in [0.75, 0.50, 0.25]:
                var candidate: float = VIEW_AZIMUTH_DEGREES * fraction
                if _safe_prop_yaw(key, items, index, candidate):
                    chosen = candidate
                    break
        item["yaw_deg"] = chosen
        items[index] = item
    _enlarge_dressing(key, items)
    return items

static func _authored_props_for(key: String) -> Array[Dictionary]:
    match key:
        "NEXUS":
            return [
                _item("antenna_case", -4.30, -5.02),
                _item("signal_console", 4.30, -4.54),
                _item("armored_bundle", -4.20, -3.93, 1.00, 2),
                _item("cable_reel", -4.37, -2.84),
                _item("cargo_box", -4.23, -1.69, 1.00, 3),
                _item("power_box", 4.40, 2.19, 1.00, 2),
                _item("sensor_tripod", 4.26, 3.24, 0.80),
                _item("tool_cart", -4.18, 4.18),
                _accent("sealed_canister", -3.66, -5.03),
                _accent("beacon_spares", -4.96, -5.03),
            ]
        "LABO":
            return [
                _item("tool_cabinet", -3.15, -2.40),
                _item("parts_tray", 3.17, -2.42),
                _item("spare_arm", -3.00, -1.24),
                _item("armor_rack", -3.17, -0.06, 1.00, 2),
                _item("tool_cart", -3.02, 1.04),
                _item("cable_reel", 3.13, 1.61),
                _item("cargo_box", -3.16, 2.66, 1.00, 2),
                _item("worklight", 3.24, 2.76, 0.80),
                _accent("micro_servo", -3.21, -3.03),
                _accent("welding_mask", -3.88, 2.69),
            ]
        "SMELTER":
            return [
                _item("ingot_pallet", -2.12, -2.04, 1.00, 3),
                _item("slag_bin", -2.02, -0.94),
                _item("coolant_tank", -2.18, 0.16),
                _item("casting_mold", -2.06, 1.26),
                _item("pipe_bundle", 2.10, -2.02),
                _item("pressure_valve", 2.18, 1.95, 0.80),
                _accent("slag_sample", -2.02, 1.98),
                _accent("heat_shield", -2.91, -2.05),
            ]
        "RECYCLER":
            return [
                _item("scrap_gears", -2.08, -2.02),
                _item("bent_armor", 2.09, -1.95, 1.00, 2),
                _item("crusher_bin", 2.04, -0.87),
                _item("spare_roller", 2.20, 0.18, 0.82),
                _item("hydraulic_kit", -2.12, 2.04),
                _item("scrap_hopper", 2.06, 1.35),
                _accent("gear_pin", 2.06, -2.62),
                _accent("cutter_tooth", 2.06, 2.06),
            ]
        "SCRAP_COLLECTOR":
            return [
                _item("scrap_hopper", -2.08, -2.03),
                _item("wheel", 2.14, -1.98, 0.83),
                _item("old_joint", -2.15, -0.91),
                _item("bent_armor", -2.04, 0.21, 1.00, 2),
                _item("cargo_box", -2.15, 1.32, 1.00, 3),
                _item("hydraulic_kit", 2.14, 1.92),
                _accent("servo_joint", -2.21, 2.08),
                _accent("grip_fingers", -1.30, -2.08),
            ]
        "STORAGE":
            return [
                _item("rack_stack", -2.10, -1.96, 1.00, 2),
                _item("cargo_box", 2.08, -1.98, 1.00, 3),
                _item("straps", 2.15, -0.90, 0.84),
                _item("pipe_bundle", 2.02, 0.24),
                _item("pallet", -2.14, 2.02, 1.00, 3),
                _item("panel_stack", 2.12, 1.37, 1.00, 2),
                _accent("packing_wedges", 2.13, 2.06),
                _accent("folded_tarp", 1.35, -1.97),
            ]
        "GENERATOR":
            return [
                _item("battery", -2.13, -2.04, 1.00, 2),
                _item("transformer", 2.12, -2.00, 1.00, 2),
                _item("coil_pack", -2.04, -0.92),
                _item("insulator", 2.16, 1.96, 0.80),
                _item("cable_reel", -2.18, 0.16),
                _item("power_box", -2.06, 1.29, 1.00, 2),
                _accent("ceramic_fuse", -2.19, -2.71),
                _accent("busbar_kit", -2.06, 1.97),
            ]
        "BUILD_TERMINAL":
            return [
                _item("construction_frame", 2.06, 1.34),
                _item("panel_stack", 2.12, -1.99, 1.00, 2),
                _item("laser_measure", -2.10, -2.00, 0.82),
                _item("fastener_box", 2.06, -0.88, 1.00, 3),
                _item("calibration_stand", -2.11, 1.96),
                _item("building_parts", 2.13, 0.22, 1.00, 2),
                _accent("blueprint_tube", 2.02, 1.99),
                _accent("locator_beacon", 2.15, -2.69),
            ]
        _:
            return []

static func bounds_for(kind: String) -> Vector2:
    return FOOTPRINTS.get(kind, Vector2.ZERO)

# A bottom supported by two neighbors is a real 2+1 pyramid, not a tall
# box drawn over a flat one. Units below are physical meters before site scale.
static func _container_piece(at: Vector2, size: Vector3, bottom: float,
        supporting: Array[int] = []) -> Dictionary:
    var supports: Array[int] = supporting.duplicate()
    return {"at": at, "size": size, "bottom": bottom,
        "supports": supports}

static func container_plan_for(key: String, kind: String,
        index: int) -> Array[Dictionary]:
    var plan: Array[Dictionary] = []
    if not is_stack_container(kind):
        return plan
    var count: int = stack_count_for(key, kind, index)
    var seed: int = _stable_seed(key, kind, index)
    var footprint: Vector2 = bounds_for(kind)
    # Normalized stack geometry never exceeds the conservative old footprint.
    var wx: float = footprint.x / 0.96
    var wz: float = footprint.y / 0.88
    var variation: float = 0.96 + float(posmod(seed, 3)) * 0.02
    if count == 1:
        plan.append(_container_piece(Vector2.ZERO,
            Vector3(0.67 * wx * variation, 0.54, 0.62 * wz * variation), 0.0))
    elif count == 2:
        # A medium-large base and a clearly smaller container on top.
        plan.append(_container_piece(Vector2.ZERO,
            Vector3(0.70 * wx, 0.54, 0.64 * wz), 0.0))
        plan.append(_container_piece(Vector2(0.045 * wx, -0.025 * wz),
            Vector3(0.35 * wx, 0.32, 0.37 * wz), 0.54, [0]))
    elif count == 3:
        # Two aligned bottom containers with a small third bridging both.
        plan.append(_container_piece(Vector2(-0.213 * wx, 0.0),
            Vector3(0.405 * wx, 0.47, 0.57 * wz), 0.0))
        plan.append(_container_piece(Vector2(0.213 * wx, 0.0),
            Vector3(0.405 * wx, 0.47, 0.57 * wz), 0.0))
        plan.append(_container_piece(Vector2(0.0, 0.0),
            Vector3(0.35 * wx, 0.32, 0.41 * wz), 0.47, [0, 1]))
    else:
        # Two at ground level, two smaller ones above their respective base.
        for side in [-1.0, 1.0]:
            plan.append(_container_piece(Vector2(side * 0.213 * wx, 0.0),
                Vector3(0.405 * wx, 0.47, 0.57 * wz), 0.0))
        for side in [-1.0, 1.0]:
            var base_index: int = 0 if side < 0.0 else 1
            plan.append(_container_piece(Vector2(side * 0.213 * wx, 0.0),
                Vector3(0.29 * wx, 0.31, 0.37 * wz), 0.47,
                [base_index]))
    return plan

# Emit box, fastener and battery bodies into the same opaque material batches.
# No new MeshInstance3D per box, and no floating ground skids on upper tiers.
static func _make_container_stack(g: Variant, key: String, kind: String,
        index: int, at: Vector2, k: float) -> void:
    var plan: Array[Dictionary] = container_plan_for(key, kind, index)
    var nominal: Vector2 = bounds_for(kind) * k
    g.box("Yard_" + kind + "_skid",
        Vector3(at.x, -0.006, at.y),
        Vector3(nominal.x * 0.78, 0.05, nominal.y * 0.72), "rubber")
    for tier_index in range(plan.size()):
        var tier: Dictionary = plan[tier_index]
        var shift: Vector2 = tier["at"]
        var size: Vector3 = (tier["size"] as Vector3) * k
        var bottom: float = float(tier["bottom"])
        var position := Vector3(at.x + shift.x * k,
            -0.03 + bottom * k + size.y * 0.5,
            at.y + shift.y * k)
        if kind == "cargo_box":
            g.crate(position, size, index + tier_index)
        else:
            g.box("YardContainer_" + kind + "_body", position, size,
                "armor_light" if tier_index % 3 == 0 else
                "crate" if tier_index % 3 == 1 else "slate")
            g.box("YardContainer_" + kind + "_lid",
                position + Vector3(0, size.y * 0.48, 0),
                Vector3(size.x * 1.03, 0.045 * k, size.z * 1.03),
                "edge")
            for side in [-1.0, 1.0]:
                g.box("YardContainer_" + kind + "_brace",
                    position + Vector3(side * size.x * 0.43, 0,
                        size.z * 0.47),
                    Vector3(0.05 * k, size.y * 0.94, 0.045 * k),
                    "trim")
            g.box("YardContainer_" + kind + "_marker",
                position + Vector3(0, size.y * 0.12, size.z * 0.51),
                Vector3(size.x * 0.36, 0.055 * k, 0.018 * k),
                "blue_light" if kind in ["power_box", "battery"] else "gold")


# Vertical pitches match the actual authored mesh heights so tiers touch.
# Machines, tripods and consoles are deliberately NOT stackable.
static func stack_pitch_for(kind: String) -> float:
    match kind:
        "cargo_box":
            return 0.64
        "fastener_box", "power_box", "battery":
            return 0.60
        "transformer", "tool_cabinet":
            return 0.94
        "pallet":
            return 0.25
        "ingot_pallet":
            return 0.50
        "rack_stack":
            return 0.98
        "panel_stack":
            # Layered thin sheets touch a thinner metal pallet than armor boxes.
            return 0.36
        "armored_bundle", "armor_rack", "bent_armor", "building_parts":
            return 0.73
        _:
            return 0.0

# Small, authored shifts keep the load believable without crossing the
# conservative physical footprint or creating horizontal overlap.
static func layer_offset(layer: int) -> Vector2:
    match layer:
        1:
            return Vector2(0.035, -0.026)
        2:
            return Vector2(-0.020, 0.042)
        _:
            return Vector2.ZERO

# A lightweight transform proxy: forwards into the SAME material Batch.
# Thus three stacked boxes do not create three additional scene draw nodes.
class LiftedBatch:
    var target: Variant
    var delta: Vector3

    func _init(base: Variant, shift: Vector3) -> void:
        target = base
        delta = shift

    func box(feature: String, at: Vector3, size: Vector3,
            tint: String = "armor", yaw: float = 0.0) -> void:
        target.box(feature, at + delta, size, tint, yaw)

    # Forward true pitch/roll as well as lift; the legacy fixture still has
    # a yaw-only box method and uses that fallback for recording.
    func box_tilt(feature: String, at: Vector3, size: Vector3,
            tint: String = "armor", angles: Vector3 = Vector3.ZERO) -> void:
        if target.has_method("box_tilt"):
            target.box_tilt(feature, at + delta, size, tint, angles)
        else:
            target.box(feature, at + delta, size, tint, angles.y)

    func rod(feature: String, a: Vector3, b: Vector3, diameter: float,
            tint: String = "trim") -> void:
        target.rod(feature, a + delta, b + delta, diameter, tint)

    func ring(feature: String, center: Vector3, radius: float,
            tint: String, axis: String = "y") -> void:
        target.ring(feature, center + delta, radius, tint, axis)

    func crate(at: Vector3, size: Vector3, index: int = 0) -> void:
        target.crate(at + delta, size, index)

static func _make_stacked(g: Variant, kind: String, at: Vector2, k: float,
        order: int, stack_count: int) -> void:
    var layers: int = clampi(stack_count, 1, 3)
    var pitch: float = stack_pitch_for(kind)
    # Keep unsafe/unstackable device types as one floor item.
    if pitch <= 0.0:
        layers = 1
    for layer in range(layers):
        if layer == 0:
            _make(g, kind, at, k, order, true)
        else:
            var wobble: Vector2 = layer_offset(layer) * k
            var lifted := LiftedBatch.new(g, Vector3(
                wobble.x, pitch * k * float(layer), wobble.y))
            _make(lifted, kind, at, k, order + layer, false)

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


# Sixteen compact functional silhouettes; each emits multiple actual 3D
# primitives into the existing facility material MultiMesh. Designed to fit
# within their own conservative 0.36–0.44m footprint, with no collisions.
static func _make_micro(g: Variant, kind: String, at: Vector2, k: float,
        order: int) -> void:
    match kind:
        "sealed_canister":
            _rod(g, kind + "_body", at, k,
                Vector3(0, 0.18, 0), Vector3(0, 0.64, 0), 0.23, "slate")
            _ring(g, kind + "_seal", at, k, Vector3(0, 0.59, 0), 0.12, "gold")
            _box(g, kind + "_valve", at, k, Vector3(0, 0.75, 0),
                Vector3(0.12, 0.12, 0.12), "edge")
        "beacon_spares":
            _box(g, kind + "_rack", at, k, Vector3(0, 0.15, 0),
                Vector3(0.34, 0.12, 0.32), "trim")
            for i in range(3):
                var x: float = float(i - 1) * 0.10
                _rod(g, kind + "_aerial", at, k,
                    Vector3(x, 0.18, -0.10), Vector3(x + 0.03, 0.85, 0.08),
                    0.037, "edge")
            _box(g, kind + "_tie", at, k, Vector3(0, 0.37, 0),
                Vector3(0.33, 0.045, 0.08), "gold")
        "micro_servo":
            _box(g, kind + "_motor", at, k, Vector3(0, 0.27, 0),
                Vector3(0.30, 0.24, 0.27), "armor_light")
            _ring(g, kind + "_joint", at, k, Vector3(0.08, 0.43, 0),
                0.12, "gold", "z")
            _rod(g, kind + "_piston", at, k,
                Vector3(0.08, 0.43, 0), Vector3(-0.14, 0.68, 0.02),
                0.065, "edge")
            _box(g, kind + "_terminal", at, k, Vector3(-0.13, 0.72, 0),
                Vector3(0.12, 0.12, 0.12), "blue")
        "welding_mask":
            _box(g, kind + "_shell", at, k, Vector3(0, 0.30, 0),
                Vector3(0.32, 0.37, 0.23), "dark", 0.15)
            _box(g, kind + "_visor", at, k, Vector3(0, 0.38, 0.14),
                Vector3(0.25, 0.095, 0.04), "blue")
            _rod(g, kind + "_band", at, k,
                Vector3(-0.14, 0.42, -0.10), Vector3(0.14, 0.42, -0.10),
                0.035, "gold")
        "slag_sample":
            for i in range(3):
                _box(g, kind + "_fragment", at, k,
                    Vector3(-0.11 + float(i) * 0.11, 0.20 + float(i % 2) * 0.06, 0),
                    Vector3(0.13, 0.17, 0.25),
                    "rust" if i == 0 else "slate", 0.18 * float(i))
            _rod(g, kind + "_core", at, k,
                Vector3(0, 0.30, 0), Vector3(0.08, 0.50, 0),
                0.06, "amber")
        "heat_shield":
            _box(g, kind + "_plate", at, k, Vector3(0, 0.45, 0),
                Vector3(0.29, 0.63, 0.065), "armor_light", 0.16)
            for side in [-1.0, 1.0]:
                _rod(g, kind + "_brace", at, k,
                    Vector3(side * 0.11, 0.19, 0.11),
                    Vector3(side * 0.11, 0.66, -0.05), 0.035, "gold")
            _box(g, kind + "_scorch", at, k, Vector3(0.02, 0.54, 0.045),
                Vector3(0.13, 0.26, 0.028), "rust")
        "gear_pin":
            _rod(g, kind + "_shaft", at, k,
                Vector3(-0.15, 0.29, 0), Vector3(0.15, 0.29, 0),
                0.085, "armor_light")
            for side in [-1.0, 1.0]:
                _ring(g, kind + "_washer", at, k,
                    Vector3(side * 0.11, 0.29, 0), 0.12, "edge", "x")
            _box(g, kind + "_tab", at, k, Vector3(0, 0.21, 0.12),
                Vector3(0.18, 0.12, 0.06), "gold")
        "cutter_tooth":
            _box(g, kind + "_base", at, k, Vector3(0, 0.19, 0),
                Vector3(0.34, 0.11, 0.30), "trim")
            for i in range(3):
                _box(g, kind + "_blade", at, k,
                    Vector3(float(i - 1) * 0.105, 0.42, 0),
                    Vector3(0.064, 0.39, 0.17), "armor_light", 0.12 * float(i))
            _box(g, kind + "_rivets", at, k, Vector3(0, 0.25, 0.16),
                Vector3(0.28, 0.045, 0.04), "gold")
        "servo_joint":
            _ring(g, kind + "_bearing", at, k, Vector3(0, 0.34, 0),
                0.15, "armor_light", "z")
            _rod(g, kind + "_axle", at, k,
                Vector3(-0.15, 0.34, 0), Vector3(0.15, 0.34, 0),
                0.09, "gold")
            _box(g, kind + "_cover", at, k, Vector3(0, 0.50, 0),
                Vector3(0.23, 0.11, 0.24), "slate")
        "grip_fingers":
            _box(g, kind + "_hub", at, k, Vector3(0, 0.22, 0),
                Vector3(0.29, 0.13, 0.27), "trim")
            for i in range(3):
                var x: float = float(i - 1) * 0.12
                _rod(g, kind + "_finger", at, k,
                    Vector3(x, 0.26, -0.11), Vector3(x * 1.22, 0.56, 0.12),
                    0.055, "armor_light")
                _box(g, kind + "_tip", at, k,
                    Vector3(x * 1.22, 0.60, 0.13),
                    Vector3(0.065, 0.075, 0.07), "gold")
        "packing_wedges":
            for i in range(3):
                var x: float = float(i - 1) * 0.11
                _box(g, kind + "_chock", at, k,
                    Vector3(x, 0.22 + float(i % 2) * 0.06, 0),
                    Vector3(0.095, 0.23, 0.30), "rust",
                    float(i - 1) * 0.23)
            _box(g, kind + "_strap", at, k, Vector3(0, 0.40, 0),
                Vector3(0.33, 0.05, 0.09), "gold")
        "folded_tarp":
            for i in range(3):
                _box(g, kind + "_fold", at, k,
                    Vector3(0.0, 0.19 + float(i) * 0.085, 0),
                    Vector3(0.35 - float(i) * 0.035, 0.085, 0.30),
                    "cloth")
            _box(g, kind + "_tie", at, k, Vector3(0, 0.49, 0),
                Vector3(0.062, 0.05, 0.34), "gold")
        "ceramic_fuse":
            _box(g, kind + "_mount", at, k, Vector3(0, 0.18, 0),
                Vector3(0.33, 0.11, 0.31), "trim")
            for i in range(3):
                var x: float = float(i - 1) * 0.105
                _rod(g, kind + "_ceramic", at, k,
                    Vector3(x, 0.26, 0), Vector3(x, 0.63, 0),
                    0.075, "white")
                _ring(g, kind + "_contact", at, k,
                    Vector3(x, 0.64, 0), 0.046, "gold")
        "busbar_kit":
            for i in range(4):
                _box(g, kind + "_bar", at, k,
                    Vector3(float(i - 1.5) * 0.075, 0.26 + float(i % 2) * 0.07, 0),
                    Vector3(0.055, 0.12, 0.34), "gold")
            for z in [-0.13, 0.13]:
                _box(g, kind + "_clamp", at, k,
                    Vector3(0, 0.34, z), Vector3(0.34, 0.06, 0.045), "edge")
        "blueprint_tube":
            for i in range(3):
                _rod(g, kind + "_rolled_sheet", at, k,
                    Vector3(float(i - 1) * 0.105, 0.24, -0.15),
                    Vector3(float(i - 1) * 0.105, 0.24, 0.15),
                    0.083, "blue" if i == 0 else "slate")
            for z in [-0.10, 0.10]:
                _box(g, kind + "_binding", at, k,
                    Vector3(0, 0.32, z),
                    Vector3(0.33, 0.045, 0.035), "gold")
        "locator_beacon":
            _box(g, kind + "_pedestal", at, k,
                Vector3(0, 0.22, 0), Vector3(0.30, 0.18, 0.30), "trim")
            _rod(g, kind + "_mast", at, k,
                Vector3(0, 0.30, 0), Vector3(0, 0.79, 0), 0.065, "edge")
            _box(g, kind + "_lamp", at, k,
                Vector3(0, 0.83, 0), Vector3(0.18, 0.15, 0.18), "blue_light")
            _ring(g, kind + "_guard", at, k,
                Vector3(0, 0.82, 0), 0.12, "gold")

static func _make(g: Variant, kind: String, at: Vector2, k: float,
        order: int, ground_skid: bool = true) -> void:
    var tint: String = (
        "rust" if order % 7 == 2 else
        "armor_light" if order % 4 == 0 else "slate")
    # A thin skid sits flush against the physical floor, independent of size.
    if ground_skid:
        var footprint: Vector2 = bounds_for(kind) * k
        g.box("Yard_" + kind + "_skid", Vector3(at.x, -0.006, at.y),
            Vector3(footprint.x * 0.75, 0.05, footprint.y * 0.74), "rubber")
    if kind in COMPACT_KINDS:
        _make_micro(g, kind, at, k, order)
        return
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
        "panel_stack":
            # Each two-tier pile consists of 12 actual thin plates, six
            # independently modeled silhouettes and different X/Z slopes.
            JunkGeometry.panel_stack(g, at, k, order)
        "armored_bundle", "armor_rack", "bent_armor", "building_parts":
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
    # Legacy geometry-capture renderers implement box/rod/ring/crate only.
    # Only the real MultiMesh Batch exposes a transform pivot. Preserve
    # the capture interface and the existing authored-part test fixtures.
    var supports_yaw: bool = false
    for property in g.get_property_list():
        if str(property.get("name", "")) == "yaw":
            supports_yaw = true
            break
    var original_yaw: float = 0.0
    var original_pivot: Vector3 = Vector3.ZERO
    if supports_yaw:
        original_yaw = float(g.yaw)
        original_pivot = g.pivot
    for index in range(props.size()):
        var p: Dictionary = props[index]
        var kind: String = str(p["kind"])
        var anchor: Vector2 = p["at"]
        if supports_yaw:
            g.pivot = Vector3(anchor.x, 0.0, anchor.y)
            g.yaw = deg_to_rad(float(p.get("yaw_deg", 0.0)))
        if is_stack_container(kind) and int(p.get("stack", 1)) > 0:
            _make_container_stack(g, key, kind, index,
                p["at"] as Vector2, float(p["scale"]))
        else:
            _make_stacked(g, kind, p["at"] as Vector2,
                float(p["scale"]), index, int(p.get("stack", 1)))
    if supports_yaw:
        g.yaw = original_yaw
        g.pivot = original_pivot
    # The renderer is a material-batched procedural model; this metadata lets
    # independent runtime tests verify actual scene construction.
    g.host.set_meta("clutter_props", props)
