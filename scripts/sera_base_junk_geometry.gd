extends RefCounted
## Reusable low-poly 3D debris. Actual pitched steel sheets and mixed salvaged
## machinery share the existing opaque cube/tube material MultiMesh batches.
## All variants are deterministic, offline, non-animated and texture-free.

const PileModels = preload("res://scripts/sera_base_pile_models.gd")
const PANEL_SHAPES = 6
const SCRAP_PROFILES = 5
const FLOOR_OFFSET: float = -0.16
const COLORS = ["slate", "armor_light", "rust", "edge", "trim"]

# Some older geometry-capture test doubles expose box/rod/ring but not
# box_tilt. Their call record is preserved; the real Batch always pitches.
static func _sheet(g: Variant, feature: String, at: Vector3, size: Vector3,
        tint: String, pitch_deg: float, roll_deg: float,
        yaw_deg: float = 0.0) -> void:
    if g.has_method("box_tilt"):
        g.box_tilt(feature, at, size, tint,
            Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg),
                deg_to_rad(roll_deg)))
    else:
        g.box(feature, at, size, tint, deg_to_rad(yaw_deg))

static func _pos(at: Vector2, dx: float, y: float, dz: float,
        scale_factor: float) -> Vector3:
    return Vector3(at.x + dx * scale_factor,
        FLOOR_OFFSET + y * scale_factor, at.y + dz * scale_factor)

# Six visible material-panel silhouettes, used in different orders in every
# stack: notched, bent, trapezoid, ribbed, short, long. Real angles are around
# local X and Z, not merely cosmetic yaw. Even the smallest one is a thin
# metal SHEET rather than a chunky rectangular storage box.
static func panel_stack(g: Variant, at: Vector2, k: float, variant: int,
        stack_count: int = 6, pattern: int = -1) -> void:
    # Four layout templates: wide flat foundations, narrow 2nd/3rd rows,
    # a few last sheets on top. Count denotes actual primary steel sheets.
    var style: int = posmod(variant, PileModels.PATTERNS) if pattern < 0 else (
        posmod(pattern, PileModels.PATTERNS))
    # The old raised U-shaped rack swallowed the narrow steel faces when
    # seen from the BASE camera. Keep only a low, unobtrusive ground contact.
    # The panels themselves, not visible rails, must define the silhouette.
    g.box("Yard_panel_stack_ground_contact",
        _pos(at, 0.0, 0.107, 0.0, k),
        Vector3(0.62, 0.018, 0.43) * k, "dark")
    var pieces: Array[Dictionary] = PileModels.model_for(stack_count, style)
    for n in range(pieces.size()):
        var part: Dictionary = pieces[n]
        var xy: Vector2 = part["position"]
        var normalized_size: Vector2 = part["size"]
        # Existing normalized row positions already fit the dedicated slab;
        # broaden each sheet until neighboring sheets overlap like salvaged
        # armor plates. Compress the orthogonal row axis for Z-oriented piles.
        var surface_width: float = minf(normalized_size.x * 1.65, 0.95)
        var surface_depth: float = minf(normalized_size.y * 1.15, 0.68)
        var size := Vector3(surface_width * k,
            (0.034 + float(n % 3) * 0.005) * k,
            surface_depth * k)
        var center: Vector3 = _pos(at, xy.x * 1.07,
            0.154 + float(part["tier"]) * 0.057 +
                float((n + style) % 3) * 0.004,
            xy.y * 0.68, k)
        var form: String = str(part["form"])
        var name: String = "Yard_panel_stack_" + form
        # Main faces must contrast with the slate floor; use restrained
        # alternating metallic surfaces rather than near-black outlines.
        var steel_tones := ["armor_light", "slate", "edge", "rust"]
        var tint: String = steel_tones[posmod(n + variant + style,
            steel_tones.size())]
        var pitch: float = float(part["pitch_deg"])
        var roll: float = float(part["roll_deg"])
        var yaw: float = float(part["yaw_deg"])
        if form == "bent":
            # One sheet consisting of two touching folded metal halves.
            _sheet(g, name + "_rear", center + Vector3(0, 0, -size.z * 0.23),
                Vector3(size.x, size.y, size.z * 0.53),
                tint, pitch - 9.0, roll, yaw)
            _sheet(g, name + "_front", center + Vector3(
                0, 0.009 * k, size.z * 0.23),
                Vector3(size.x * 0.94, size.y, size.z * 0.53),
                tint, pitch + 12.0, roll, yaw)
        elif form == "notched":
            _sheet(g, name + "_body", center,
                Vector3(size.x * 0.87, size.y, size.z),
                tint, pitch, roll, yaw)
            _sheet(g, name + "_lug", center + Vector3(
                size.x * 0.40, 0, -size.z * 0.29),
                Vector3(size.x * 0.17, size.y, size.z * 0.42),
                tint, pitch, roll, yaw)
        elif form == "trapezoid":
            _sheet(g, name + "_center", center,
                Vector3(size.x * 0.72, size.y, size.z),
                tint, pitch, roll, yaw)
            _sheet(g, name + "_shoulder", center + Vector3(
                -size.x * 0.38, 0, -size.z * 0.12),
                Vector3(size.x * 0.22, size.y, size.z * 0.63),
                tint, pitch, roll, yaw + 2.0)
        else:
            _sheet(g, name, center, size, tint, pitch, roll, yaw)
        if form == "ribbed":
            for side in [-1.0, 1.0]:
                g.rod(name + "_stiffener",
                    center + Vector3(side * size.x * 0.34, size.y, -size.z * 0.38),
                    center + Vector3(side * size.x * 0.34, size.y, size.z * 0.38),
                    0.028 * k, "edge")
        if n % 3 == 1:
            g.rod("Yard_panel_stack_spacer",
                center + Vector3(-size.x * 0.37, -0.035 * k, 0),
                center + Vector3(size.x * 0.37, -0.035 * k, 0),
                0.032 * k, "trim")


# Facility salvage pile: one main plate/chunk per stack item, with several
# shape families and independently pitched panels. No new MeshInstance nodes.
static func loose_scrap_pile(g: Variant, at: Vector2, k: float,
        variant: int, stack_count: int, pattern: int, kind: String) -> void:
    var parts: Array[Dictionary] = PileModels.model_for(stack_count, pattern)
    g.box("Yard_" + kind + "_skid", Vector3(at.x, -0.006, at.y),
        Vector3(0.67, 0.045, 0.48) * k, "rubber")
    for i in range(parts.size()):
        var part: Dictionary = parts[i]
        var off: Vector2 = part["position"]
        var ratio: Vector2 = part["size"]
        var position: Vector3 = _pos(at, off.x * 1.02,
            float(part["height"]), off.y * 0.79, k)
        var plate_size := Vector3(ratio.x * 1.03 * k,
            (0.046 + float((variant + i) % 3) * 0.015) * k,
            ratio.y * 0.79 * k)
        var feature: String = "YardLooseMain_" + kind + "_" + str(i)
        var tint: String = COLORS[posmod(i + variant + pattern, COLORS.size())]
        var pitch: float = float(part["pitch_deg"])
        var roll: float = float(part["roll_deg"])
        var yaw: float = float(part["yaw_deg"])
        var variant_type: int = posmod(i + variant * 3 + pattern, 5)
        if variant_type == 0:
            _sheet(g, feature + "_armor_plate", position,
                plate_size, tint, pitch, roll, yaw)
        elif variant_type == 1:
            # Compound torn body, not merely one scaled cube.
            _sheet(g, feature + "_broken_A", position +
                Vector3(-plate_size.x * 0.10, 0, 0),
                Vector3(plate_size.x * 0.72, plate_size.y, plate_size.z),
                tint, pitch - 8.0, roll, yaw)
            _sheet(g, feature + "_broken_B", position +
                Vector3(plate_size.x * 0.28, 0.015 * k, 0),
                Vector3(plate_size.x * 0.27, plate_size.y * 1.2,
                    plate_size.z * 0.64),
                tint, pitch + 13.0, roll, yaw)
        elif variant_type == 2:
            g.box(feature + "_housing", position,
                Vector3(plate_size.x * 0.72, 0.15 * k,
                    plate_size.z * 0.76), "armor_light")
            g.rod(feature + "_broken_axle",
                position + Vector3(-plate_size.x * 0.42, 0.07 * k, 0),
                position + Vector3(plate_size.x * 0.43, 0.11 * k,
                    plate_size.z * 0.24), 0.047 * k, "rust")
        elif variant_type == 3:
            g.ring(feature + "_bearing", position,
                minf(plate_size.x, plate_size.z) * 0.39, "edge", "z")
            g.rod(feature + "_axle",
                position + Vector3(-plate_size.x * 0.45, 0, 0),
                position + Vector3(plate_size.x * 0.45, 0.04 * k, 0),
                0.07 * k, "trim")
        else:
            _sheet(g, feature + "_curved_guard", position,
                plate_size, tint, pitch, roll, yaw)
            g.rod(feature + "_brace",
                position + Vector3(-plate_size.x * 0.30, 0, -plate_size.z * 0.22),
                position + Vector3(plate_size.x * 0.32, 0.10 * k,
                    plate_size.z * 0.26), 0.041 * k, "edge")


# A scrap pile is not a box with a rod on top: give it broken armor,
# a recognizable bearing/gear, exposed axles, tubes, loose frame bars and
# tiny detached hardware. Five arrangements mix large/medium/small pieces
# and vary their outline, center of mass, tilt and maximum height.
static func scrap_heap(g: Variant, origin: Vector3, index: int,
        stack_count: int = -1, pattern: int = -1) -> void:
    var profile: int = posmod(index, SCRAP_PROFILES)
    var count: int = 1 + posmod(index, PileModels.MAX_PIECES) if (
        stack_count < 1) else clampi(stack_count, 1, PileModels.MAX_PIECES)
    var style: int = posmod(index * 3 + 1, PileModels.PATTERNS) if (
        pattern < 0) else posmod(pattern, PileModels.PATTERNS)
    var tag: String = "Salvage_" + str(index) + "_"
    # The eight count variants form the load; bearings and cables below are
    # secondary fittings, not extra phantom major scrap pieces.
    loose_scrap_pile(g, Vector2(origin.x, origin.z), 1.0,
        index, count, style, "salvage")
    # A detached gearbox or joint is visibly circular, not a cubic lump.
    var hub: Vector3 = origin + Vector3(-0.24 + profile * 0.07,
        0.31 + float(index % 3) * 0.045, 0.14)
    g.ring(tag + "gear_outer", hub, 0.18, "edge", "z")
    g.rod(tag + "axle", hub + Vector3(-0.21, 0, 0),
        hub + Vector3(0.18, -0.07, 0.10), 0.085, "rust")
    for arm in range(4):
        var phi: float = TAU * float(arm) / 4.0
        g.rod(tag + "gear_spoke", hub,
            hub + Vector3(cos(phi) * 0.15, sin(phi) * 0.15, 0),
            0.036, "trim")
    # Loose kinked conduit / cable pieces, never perfectly parallel.
    var a: Vector3 = origin + Vector3(-0.48, 0.20, -0.21)
    var b: Vector3 = origin + Vector3(-0.21, 0.39, -0.28)
    var c: Vector3 = origin + Vector3(0.34, 0.19, -0.31)
    g.rod(tag + "tube_kink_1", a, b, 0.071, "edge")
    g.rod(tag + "tube_kink_2", b, c, 0.071, "edge")

    match profile:
        0:
            # Broken transmission: exposed cylinder and crossed bent frame.
            g.box(tag + "housing", origin + Vector3(0.28, 0.30, 0.10),
                Vector3(0.30, 0.29, 0.29), "trim")
            g.rod(tag + "frame_A", origin + Vector3(-0.46, 0.17, 0.27),
                origin + Vector3(0.32, 0.54, 0.23), 0.075, "armor_light")
            g.rod(tag + "frame_B", origin + Vector3(0.37, 0.54, 0.25),
                origin + Vector3(0.47, 0.16, -0.19), 0.060, "rust")
        1:
            # Bracket stack with a visibly open, crooked angle.
            _sheet(g, tag + "notched_plate", origin + Vector3(0.08, 0.48, -0.04),
                Vector3(0.45, 0.038, 0.28), "armor_light", -25.0, 20.0, 30.0)
            g.rod(tag + "frame_upright", origin + Vector3(0.12, 0.11, -0.30),
                origin + Vector3(0.38, 0.70, -0.14), 0.065, "rust")
            g.rod(tag + "frame_cross", origin + Vector3(-0.35, 0.45, -0.16),
                origin + Vector3(0.30, 0.31, 0.29), 0.059, "edge")
        2:
            # Half-ruined motor with an extra asymmetric bearing rim.
            g.box(tag + "motor_housing", origin + Vector3(0.27, 0.27, -0.13),
                Vector3(0.29, 0.25, 0.31), "armor_light")
            g.ring(tag + "bearing", origin + Vector3(0.29, 0.43, -0.16),
                0.13, "trim", "z")
            g.rod(tag + "bent_shaft", origin + Vector3(0.48, 0.36, -0.22),
                origin + Vector3(0.39, 0.12, 0.33), 0.07, "edge")
        3:
            # Crushed canister and tangled hydraulic remains.
            g.rod(tag + "hydraulic_body", origin + Vector3(0.25, 0.16, 0.25),
                origin + Vector3(-0.08, 0.58, 0.10), 0.19, "armor_light")
            g.rod(tag + "piston", origin + Vector3(-0.08, 0.57, 0.10),
                origin + Vector3(-0.29, 0.70, -0.12), 0.078, "edge")
            g.rod(tag + "broken_tube", origin + Vector3(0.35, 0.32, 0.18),
                origin + Vector3(0.48, 0.18, -0.26), 0.065, "rust")
        _:
            # Bent L-frame with loose armored cladding and wheel rim.
            _sheet(g, tag + "armor_shard", origin + Vector3(-0.08, 0.51, 0.16),
                Vector3(0.48, 0.045, 0.29), "rust", 24.0, -11.0, -19.0)
            g.rod(tag + "frame_base", origin + Vector3(-0.44, 0.13, 0.26),
                origin + Vector3(0.20, 0.13, 0.30), 0.069, "trim")
            g.rod(tag + "frame_post", origin + Vector3(0.20, 0.13, 0.30),
                origin + Vector3(0.35, 0.62, 0.14), 0.069, "trim")
    # Distinct small bolts at uneven heights (deterministic, no RNG).
    for bolt in range(4):
        var x: float = -0.37 + float(posmod(bolt * 7 + index * 3, 10)) * 0.082
        var z: float = -0.26 + float(posmod(bolt * 5 + index, 9)) * 0.067
        var y: float = 0.095 + 0.035 * float(bolt % 3)
        g.rod(tag + "small_bolt", origin + Vector3(x, y, z),
            origin + Vector3(x + 0.08, y + 0.01, z - 0.025),
            0.035, "rust" if bolt % 2 == 0 else "edge")
