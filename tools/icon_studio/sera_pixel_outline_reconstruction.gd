extends RefCounted
## Production-only deterministic pixel contour reconstruction for equipment PNGs.
## The live shaders, model sources and runtime icon caches are not changed.
const INK: Color = Color("#17212f")
const SAMPLE_GRID: int = 3

static func reconstruct(base_render: Image, ink_render: Image,
        id_render: Image, side: int, auto_fit: float,
        profile: Dictionary) -> Image:
    if base_render == null or ink_render == null or id_render == null:
        return null
    if side <= 0 or base_render.is_empty() or ink_render.is_empty() or id_render.is_empty():
        return null
    if base_render.get_size() != ink_render.get_size() or (
            base_render.get_size() != id_render.get_size()):
        return null
    if base_render.get_width() % side != 0 or base_render.get_height() % side != 0:
        return null

    # Shade and material are supersampled; ID labels are discrete data and
    # therefore reduced by per-pixel votes, never by filtered RGB interpolation.
    var shade: Image = base_render.duplicate()
    var painted: Image = ink_render.duplicate()
    shade.resize(side, side, Image.INTERPOLATE_LANCZOS)
    painted.resize(side, side, Image.INTERPOLATE_LANCZOS)
    var ids: Image = _reduce_visible_ids(id_render, side)

    var bounds: Rect2i = _subject_bounds(ids)
    if bounds.size.x < 1 or bounds.size.y < 1:
        return null
    # Apply the approved 76% fit BEFORE drawing final-pixel outlines.
    # Resizing after inking used to create irregular staircase thickness.
    var target_side: int = clampi(roundi(float(side) * auto_fit), 1, side - 2)
    var scale: float = minf(
        float(target_side) / float(bounds.size.x),
        float(target_side) / float(bounds.size.y))
    var fit_width: int = clampi(roundi(float(bounds.size.x) * scale), 1, target_side)
    var fit_height: int = clampi(roundi(float(bounds.size.y) * scale), 1, target_side)
    shade = _fit_image(shade, bounds, fit_width, fit_height, side, false)
    painted = _fit_image(painted, bounds, fit_width, fit_height, side, false)
    ids = _fit_image(ids, bounds, fit_width, fit_height, side, true)

    var owners := PackedInt32Array()
    owners.resize(side * side)
    for y in range(side):
        for x in range(side):
            owners[y * side + x] = _owner(ids.get_pixel(x, y))

    var result := Image.create(side, side, false, Image.FORMAT_RGBA8)
    result.fill(Color.TRANSPARENT)
    var inner_radius: float = maxf(0.0, float(profile.get("inner", 1.0)))
    var outer_radius: float = maxf(0.0, float(profile.get("outer", 1.0)))
    var seam_radius: float = maxf(0.0, float(profile.get("seam", 1.0)))
    var radius: int = ceili(maxf(outer_radius, maxf(inner_radius, seam_radius)))
    for y in range(side):
        for x in range(side):
            var center: int = owners[y * side + x]
            var draw_ink: bool = false
            for dy in range(-radius, radius + 1):
                if draw_ink:
                    break
                var ny: int = y + dy
                if ny < 0 or ny >= side:
                    continue
                for dx in range(-radius, radius + 1):
                    if dx == 0 and dy == 0:
                        continue
                    var nx: int = x + dx
                    if nx < 0 or nx >= side:
                        continue
                    var dist_sq: float = float(dx * dx + dy * dy)
                    var other: int = owners[ny * side + nx]
                    if center == 0:
                        if other != 0 and dist_sq <= outer_radius * outer_radius + 0.001:
                            draw_ink = true
                    elif other == 0:
                        if dist_sq <= inner_radius * inner_radius + 0.001:
                            draw_ink = true
                    elif other != center and dist_sq <= seam_radius * seam_radius + 0.001:
                        # A seam belongs to exactly one visible mesh; painting
                        # both neighbors doubled narrow contact strokes.
                        if _owns_contact(center, other):
                            draw_ink = true
                    if draw_ink:
                        break
            if center != 0 and not draw_ink:
                # Preserve the source mesh's visible convex ribbon ink, but
                # snap its coverage to this final output pixel grid.
                var clean: Color = shade.get_pixel(x, y)
                var outlined: Color = painted.get_pixel(x, y)
                var decrease: float = (
                    clean.r - outlined.r + clean.g - outlined.g +
                    clean.b - outlined.b) / 3.0
                if clean.a > 0.15 and outlined.a > 0.15 and decrease > 0.10 and (
                        outlined.r < clean.r - 0.055 or
                        outlined.g < clean.g - 0.055):
                    draw_ink = true
            if draw_ink:
                result.set_pixel(x, y, INK)
            elif center != 0:
                var filled: Color = shade.get_pixel(x, y)
                # Alpha is a binary pixel mask; no gray fringing at the edges.
                filled.a = 1.0
                result.set_pixel(x, y, filled)
    return result


static func _owner(color: Color) -> int:
    if color.g < 0.06:
        return 0
    var r: int = clampi(roundi(color.r * 255.0), 0, 255)
    var g: int = clampi(roundi(color.g * 255.0), 0, 255)
    var b: int = clampi(roundi(color.b * 255.0), 0, 255)
    return (r << 16) | (g << 8) | b


static func _owner_color(owner: int) -> Color:
    return Color8((owner >> 16) & 255, (owner >> 8) & 255,
        owner & 255, 255)


static func _owns_contact(center: int, other: int) -> bool:
    var blue_a: int = center & 255
    var blue_b: int = other & 255
    if abs(blue_a - blue_b) > 15:
        return blue_a > blue_b
    var green_a: int = (center >> 8) & 255
    var green_b: int = (other >> 8) & 255
    if abs(green_a - green_b) > 15:
        return green_a > green_b
    return (center >> 16) > (other >> 16) + 15


static func _reduce_visible_ids(source: Image, side: int) -> Image:
    var reduced := Image.create(side, side, false, Image.FORMAT_RGBA8)
    reduced.fill(Color.BLACK)
    var factor: int = source.get_width() / side
    for y in range(side):
        for x in range(side):
            var votes: Dictionary = {}
            var best: int = 0
            var best_votes: int = 0
            for sy in range(SAMPLE_GRID):
                for sx in range(SAMPLE_GRID):
                    var px: int = x * factor + mini(
                        (2 * sx + 1) * factor / (2 * SAMPLE_GRID), factor - 1)
                    var py: int = y * factor + mini(
                        (2 * sy + 1) * factor / (2 * SAMPLE_GRID), factor - 1)
                    var index: int = _owner(source.get_pixel(px, py))
                    if index == 0:
                        continue
                    var count: int = int(votes.get(index, 0)) + 1
                    votes[index] = count
                    if count > best_votes:
                        best_votes = count
                        best = index
            # 3/9 protects thin features but discards isolated subpixel noise.
            if best_votes >= 3:
                reduced.set_pixel(x, y, _owner_color(best))
    return reduced


static func _subject_bounds(ids: Image) -> Rect2i:
    var left: int = ids.get_width()
    var top: int = ids.get_height()
    var right: int = -1
    var bottom: int = -1
    for y in range(ids.get_height()):
        for x in range(ids.get_width()):
            if _owner(ids.get_pixel(x, y)) == 0:
                continue
            left = mini(left, x)
            right = maxi(right, x)
            top = mini(top, y)
            bottom = maxi(bottom, y)
    if right < left or bottom < top:
        return Rect2i()
    return Rect2i(left, top, right - left + 1, bottom - top + 1)


static func _fit_image(source: Image, region: Rect2i,
        width: int, height: int, side: int, nearest: bool) -> Image:
    var crop: Image = source.get_region(region)
    crop.resize(width, height,
        Image.INTERPOLATE_NEAREST if nearest else Image.INTERPOLATE_LANCZOS)
    var output := Image.create(side, side, false, Image.FORMAT_RGBA8)
    output.fill(Color.BLACK if nearest else Color.TRANSPARENT)
    output.blit_rect(crop, Rect2i(0, 0, width, height),
        Vector2i((side - width) / 2, (side - height) / 2))
    return output
