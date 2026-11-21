extends RefCounted
## Reusable low-poly 3D debris. Actual pitched steel sheets and mixed salvaged
## machinery share the existing opaque cube/tube material MultiMesh batches.
## All variants are deterministic, offline, non-animated and texture-free.

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
static func panel_stack(g: Variant, at: Vector2, k: float, variant: int) -> void:
    for rail in [-1.0, 1.0]:
        g.box("Yard_panel_stack_footrail",
            _pos(at, rail * 0.29, 0.17, -0.02, k),
            Vector3(0.09, 0.09, 0.66) * k, "trim")
    g.rod("Yard_panel_stack_support",
        _pos(at, -0.35, 0.24, -0.29, k),
        _pos(at, 0.36, 0.24, -0.29, k), 0.045 * k, "edge")

    var shape_names := ["notched", "bent", "trapezoid",
        "ribbed", "short", "long"]
    var widths := [0.74, 0.74, 0.67, 0.82, 0.53, 0.88]
    var depths := [0.58, 0.62, 0.57, 0.58, 0.52, 0.39]
    var pitch_angles := [-9.0, 10.0, -4.0, 7.0, 13.0, -8.0]
    var roll_angles := [4.0, -7.0, 9.0, -4.0, 6.0, -6.0]
    var heading_angles := [7.0, -10.0, 11.0, -5.0, -13.0, 9.0]

    for layer in range(PANEL_SHAPES):
        var index: int = posmod(variant + layer, PANEL_SHAPES)
        var shape: String = shape_names[index]
        var width: float = widths[index] * k
        var depth: float = depths[index] * k
        var height: float = 0.285 + 0.058 * float(layer)
        var x_shift: float = (-0.055 + float(posmod(layer * 3 + variant, 5)) * 0.026)
        var z_shift: float = (-0.045 + float(posmod(layer + variant * 2, 4)) * 0.031)
        var center: Vector3 = _pos(at, x_shift, height, z_shift, k)
        var paint: String = COLORS[posmod(index + variant, COLORS.size())]
        var feature: String = "Yard_panel_stack_" + shape
        var pitch: float = pitch_angles[index] + float(posmod(variant, 3) - 1) * 1.5
        var roll: float = roll_angles[index]
        var yaw: float = heading_angles[index] + float(posmod(layer, 3) - 1) * 2.0
        var thickness: float = (0.038 + 0.004 * float(layer % 3)) * k
        if shape == "bent":
            # Two attached sheet halves, different pitch at the bend seam.
            _sheet(g, feature + "_rear", center + Vector3(0, 0, -depth * 0.23),
                Vector3(width, thickness, depth * 0.55), paint,
                pitch - 9.0, roll, yaw)
            _sheet(g, feature + "_front", center + Vector3(0, 0.012 * k, depth * 0.23),
                Vector3(width * 0.95, thickness, depth * 0.53), paint,
                pitch + 12.0, roll, yaw)
        elif shape == "notched":
            # Missing front corner represented by asymmetrical end tabs.
            _sheet(g, feature + "_body", center,
                Vector3(width * 0.81, thickness, depth), paint, pitch, roll, yaw)
            _sheet(g, feature + "_lug", center + Vector3(width * 0.42, 0,
                    -depth * 0.29),
                Vector3(width * 0.16, thickness, depth * 0.42), paint,
                pitch, roll, yaw)
        elif shape == "trapezoid":
            _sheet(g, feature + "_center", center,
                Vector3(width * 0.73, thickness, depth), paint, pitch, roll, yaw)
            _sheet(g, feature + "_shoulder", center + Vector3(-width * 0.40,
                    0, -depth * 0.12),
                Vector3(width * 0.21, thickness, depth * 0.66), paint,
                pitch, roll, yaw + 3.0)
        else:
            _sheet(g, feature, center, Vector3(width, thickness, depth),
                paint, pitch, roll, yaw)
        if shape == "ribbed":
            for side in [-1.0, 1.0]:
                g.rod(feature + "_stiffener",
                    center + Vector3(side * width * 0.32, thickness * 1.3,
                        -depth * 0.38),
                    center + Vector3(side * width * 0.32, thickness * 1.3,
                        depth * 0.36), 0.030 * k, "edge")
        if layer in [1, 4]:
            g.rod("Yard_panel_stack_spacer",
                center + Vector3(-width * 0.43, -0.035 * k, 0),
                center + Vector3(width * 0.42, -0.035 * k, 0),
                0.036 * k, "trim")

# A scrap pile is not a box with a rod on top: give it broken armor,
# a recognizable bearing/gear, exposed axles, tubes, loose frame bars and
# tiny detached hardware. Five arrangements mix large/medium/small pieces
# and vary their outline, center of mass, tilt and maximum height.
static func scrap_heap(g: Variant, origin: Vector3, index: int) -> void:
    var profile: int = posmod(index, SCRAP_PROFILES)
    var angle_bias: float = float(posmod(index * 7, 9) - 4)
    var tag: String = "Salvage_" + str(index) + "_"
    var p0: Vector3 = origin + Vector3(-0.23, 0.10, -0.07)
    var p1: Vector3 = origin + Vector3(0.10, 0.15, 0.19)
    var p2: Vector3 = origin + Vector3(0.25, 0.20, -0.12)
    _sheet(g, tag + "plate_A", p0,
        Vector3(0.55, 0.048, 0.48), "slate", 12.0, -8.0, 14.0 + angle_bias)
    _sheet(g, tag + "plate_B", p1,
        Vector3(0.40, 0.044, 0.32), "rust", -14.0, 13.0, -16.0)
    _sheet(g, tag + "plate_C", p2,
        Vector3(0.34, 0.052, 0.47), "armor_light", 11.0, 15.0, 31.0)
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
