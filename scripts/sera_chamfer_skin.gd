extends RefCounted
## Nine-sliced eight-sided frame, rendered by native Godot Button theme.
## Each corner is a true transparent 45-degree cut, not a rounded corner.
static var _styles: Dictionary = {}

static func style(background: Color, border: Color) -> StyleBoxTexture:
    var key: String = background.to_html(true) + "/" + border.to_html(true)
    if _styles.has(key):
        return _styles[key] as StyleBoxTexture
    var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    for y in range(48):
        for x in range(48):
            # A regular octagonal frame with four 45-degree corner notches.
            var outer: bool = (
                x + y >= 10 and (47 - x) + y >= 10 and
                x + (47 - y) >= 10 and (47 - x) + (47 - y) >= 10)
            if not outer:
                continue
            var inner: bool = (
                x >= 2 and x <= 45 and y >= 2 and y <= 45 and
                x + y >= 14 and (47 - x) + y >= 14 and
                x + (47 - y) >= 14 and (47 - x) + (47 - y) >= 14)
            img.set_pixel(x, y, background if inner else border)
    var frame := StyleBoxTexture.new()
    frame.texture = ImageTexture.create_from_image(img)
    for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
        frame.set_texture_margin(side, 15.0)
    frame.content_margin_left = 8.0
    frame.content_margin_right = 8.0
    frame.content_margin_top = 8.0
    frame.content_margin_bottom = 8.0
    _styles[key] = frame
    return frame
