extends RefCounted
## Shared bright blue-grey backdrop, lighter than SERA/NEXUS shader ink,\n## for equipment portraits, editor single-part view
## and the LABO craft confirmation. No shader, per-frame draw or 3D per card.
const SOLID_COLOR := Color("#A9BBC7")
const GRID_COLOR := Color("#8299A8")
const GRID_OPACITY: float = 0.36
const GRID_DIVISIONS: int = 8
const DEFAULT_MODE: String = "grid"
# Equipment-only overlay; leave the portrait source and material icons alone.
const FRAME_MAIN := Color("#6F93A3")
const FRAME_HIGHLIGHT := Color("#9FD7E6")
const FRAME_SUB_OPACITY: float = 0.36
static var _backdrops: Dictionary = {}

static func make_image(side: int, mode: String = DEFAULT_MODE) -> Image:
    var size: int = clampi(side, 16, 1024)
    var pixels := Image.create(size, size, false, Image.FORMAT_RGBA8)
    pixels.fill(SOLID_COLOR)
    if mode == "solid":
        return pixels
    var step: int = maxi(8, int(round(float(size) / float(GRID_DIVISIONS))))
    var line_color: Color = SOLID_COLOR.lerp(GRID_COLOR, GRID_OPACITY)
    var center_color: Color = SOLID_COLOR.lerp(GRID_COLOR, GRID_OPACITY * 1.4)
    for x in range(0, size, step):
        var ink: Color = center_color if x == step * 4 else line_color
        for y in range(size):
            pixels.set_pixel(x, y, ink)
    for y in range(0, size, step):
        var ink: Color = center_color if y == step * 4 else line_color
        for x in range(size):
            pixels.set_pixel(x, y, ink)
    return pixels

static func texture(side: int, mode: String = DEFAULT_MODE) -> Texture2D:
    var key: String = "%d:%s" % [side, mode]
    if not _backdrops.has(key):
        _backdrops[key] = ImageTexture.create_from_image(make_image(side, mode))
    return _backdrops[key] as Texture2D

static func _stroke_frame_segment(image: Image, a: Vector2i, b: Vector2i,
        thickness: int, tint: Color) -> void:
    # Rasterized 2D segments; no texture masks, per-card shaders or viewports.
    # Direct writes preserve the already-composited opaque background.
    var steps: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
    var half: int = int(floor(float(thickness - 1) * 0.5))
    for step in range(steps + 1):
        var t: float = float(step) / float(maxi(steps, 1))
        var x: int = roundi(lerpf(float(a.x), float(b.x), t))
        var y: int = roundi(lerpf(float(a.y), float(b.y), t))
        for py in range(y - half, y - half + thickness):
            if py < 0 or py >= image.get_height():
                continue
            for px in range(x - half, x - half + thickness):
                if px < 0 or px >= image.get_width():
                    continue
                if tint.a > 0.999:
                    image.set_pixel(px, py, tint)
                else:
                    var old: Color = image.get_pixel(px, py)
                    image.set_pixel(px, py, Color(
                        lerpf(old.r, tint.r, tint.a),
                        lerpf(old.g, tint.g, tint.a),
                        lerpf(old.b, tint.b, tint.a), old.a))


static func draw_tech_frame(image: Image) -> void:
    # True chamfered octagon; corner space stays transparent of frame ink.
    # 72px legacy and 512px IRIS proportions are identical.
    var side: int = mini(image.get_width(), image.get_height())
    if side < 16:
        return
    var pad: int = maxi(3, roundi(float(side) * 0.055))
    var cut: int = maxi(5, roundi(float(side) * 0.10))
    var thickness: int = maxi(1, roundi(float(side) * 0.012))
    var left: int = pad
    var top: int = pad
    var right: int = side - pad - 1
    var bottom: int = side - pad - 1
    var corners: Array[Vector2i] = [
        Vector2i(left + cut, top),
        Vector2i(right - cut, top),
        Vector2i(right, top + cut),
        Vector2i(right, bottom - cut),
        Vector2i(right - cut, bottom),
        Vector2i(left + cut, bottom),
        Vector2i(left, bottom - cut),
        Vector2i(left, top + cut)
    ]
    for index in range(corners.size()):
        _stroke_frame_segment(image, corners[index],
            corners[(index + 1) % corners.size()], thickness, FRAME_MAIN)

    # A purposeful asymmetry: bright, short L-like marks at top-left
    # and bottom-right, rather than neon glow around the entire border.
    var start_gap: int = maxi(2, roundi(float(side) * 0.018))
    var accent_extent: int = maxi(8, roundi(float(side) * 0.14))
    _stroke_frame_segment(image,
        Vector2i(left + cut + start_gap, top),
        Vector2i(left + cut + accent_extent, top), thickness, FRAME_HIGHLIGHT)
    _stroke_frame_segment(image,
        Vector2i(left, top + cut + start_gap),
        Vector2i(left, top + cut + accent_extent), thickness, FRAME_HIGHLIGHT)
    _stroke_frame_segment(image,
        Vector2i(right - cut - accent_extent, bottom),
        Vector2i(right - cut - start_gap, bottom), thickness, FRAME_HIGHLIGHT)
    _stroke_frame_segment(image,
        Vector2i(right, bottom - cut - accent_extent),
        Vector2i(right, bottom - cut - start_gap), thickness, FRAME_HIGHLIGHT)

    # Two deliberately partial, translucent inner guides; no full double box.
    var inset: int = maxi(2, roundi(float(side) * 0.024))
    var guide: Color = FRAME_MAIN
    guide.a = FRAME_SUB_OPACITY
    _stroke_frame_segment(image,
        Vector2i(right - cut - accent_extent, top + inset),
        Vector2i(right - cut - start_gap, top + inset), 1, guide)
    _stroke_frame_segment(image,
        Vector2i(left + inset, bottom - cut - accent_extent),
        Vector2i(left + inset, bottom - cut - start_gap), 1, guide)


static func composite(source: Texture2D, mode: String = DEFAULT_MODE) -> Texture2D:
    if source == null:
        return texture(72, mode)
    var art: Image
    if source is AtlasTexture:
        # AtlasTexture.get_image() can be backend-dependent: crop the exact
        # 72px source rectangle ourselves, never the whole 4x5 sprite sheet.
        var atlas_texture: AtlasTexture = source as AtlasTexture
        if atlas_texture.atlas == null:
            return source
        art = atlas_texture.atlas.get_image()
        if art == null or art.is_empty():
            return source
        if art.is_compressed() and art.decompress() != OK:
            return source
        var region: Rect2 = atlas_texture.region
        art = art.get_region(Rect2i(
            Vector2i(roundi(region.position.x), roundi(region.position.y)),
            Vector2i(roundi(region.size.x), roundi(region.size.y))))
    else:
        art = source.get_image()
    if art == null or art.is_empty():
        return source
    if art.is_compressed() and art.decompress() != OK:
        return source
    # ImageTexture.get_image() may share an Image buffer with the source.
    # Resize must never change that original between grid and solid views.
    art = art.duplicate() as Image
    art.convert(Image.FORMAT_RGBA8)
    # Cache at source resolution in the caller; preserve authored pixel art.
    var side: int = maxi(art.get_width(), art.get_height())
    if art.get_width() != side or art.get_height() != side:
        art.resize(side, side, Image.INTERPOLATE_NEAREST)
    # The source atlas may be fully opaque: reserve a visible grid margin.
    # Approved transparent portraits still keep their original color/geometry.
    var inset: int = maxi(1, int(round(float(side) * 0.075)))
    var content_side: int = maxi(1, side - inset * 2)
    art.resize(content_side, content_side, Image.INTERPOLATE_NEAREST)
    var bg: Image = make_image(side, mode)
    bg.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()),
        Vector2i(inset, inset))
    # Frames are overlaid LAST, so icons retain the same exact contour in
    # LABO, Warehouse and NEXUS even when the source screenshot is opaque.
    draw_tech_frame(bg)
    return ImageTexture.create_from_image(bg)
