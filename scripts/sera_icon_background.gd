extends RefCounted
## Canonical static backdrop for equipment portraits, editor single-part view
## and the LABO craft confirmation. No shader, per-frame draw or 3D per card.
const SOLID_COLOR := Color("#111e28")
const GRID_COLOR := Color("#55798A")
const GRID_OPACITY: float = 0.36
const GRID_DIVISIONS: int = 8
const DEFAULT_MODE: String = "grid"
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

static func composite(source: Texture2D, mode: String = DEFAULT_MODE) -> Texture2D:
    if source == null:
        return texture(72, mode)
    var art: Image = source.get_image()
    if art == null or art.is_empty():
        return source
    if art.is_compressed() and art.decompress() != OK:
        return source
    art.convert(Image.FORMAT_RGBA8)
    # Cache at source resolution in the caller; preserve authored pixel art.
    var side: int = maxi(art.get_width(), art.get_height())
    if art.get_width() != side or art.get_height() != side:
        art.resize(side, side, Image.INTERPOLATE_NEAREST)
    var bg: Image = make_image(side, mode)
    bg.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i.ZERO)
    return ImageTexture.create_from_image(bg)
