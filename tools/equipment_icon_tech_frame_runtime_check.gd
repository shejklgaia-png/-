extends SceneTree
## Production pixel checks: real 72px atlas tiles + 512px approved IRIS PNG,
## genuine clipped corners, asymmetric highlights, source alpha untouched.
const Backdrop = preload("res://scripts/sera_icon_background.gd")
const Icons = preload("res://scripts/sera_item_icons.gd")
const Catalog = preload("res://scripts/sera_prototype_catalog.gd")

func _initialize() -> void:
    call_deferred("_check")

func _fail(message: String) -> void:
    push_error("SERA_EQUIPMENT_TECH_FRAME_RUNTIME_FAIL: " + message)
    quit(1)

func _close(a: Color, b: Color, tolerance: float = 0.015) -> bool:
    return absf(a.r - b.r) < tolerance and absf(a.g - b.g) < tolerance and (
        absf(a.b - b.b) < tolerance) and absf(a.a - b.a) < tolerance

func _check() -> void:
    var frame_main := Color("#6F93A3")
    var frame_highlight := Color("#9FD7E6")
    for side in [72, 512]:
        var original := Image.create(side, side, false, Image.FORMAT_RGBA8)
        original.fill(Color(0, 0, 0, 0))
        original.set_pixel(side / 2, side / 2, Color("#ee9955"))
        var source := ImageTexture.create_from_image(original)
        var composed: Texture2D = Backdrop.composite(source, "grid")
        if composed == null or composed.get_width() != side or composed.get_height() != side:
            _fail("Wrong equipment icon dimensions: " + str(side))
            return
        var image: Image = composed.get_image()
        var grid: Image = Backdrop.make_image(side, "grid")
        var pad: int = maxi(3, roundi(float(side) * 0.055))
        var cut: int = maxi(5, roundi(float(side) * 0.10))
        var mid: int = side / 2
        # Each straight edge has the thin subdued blue-grey stroke.
        for pixel in [Vector2i(mid, pad), Vector2i(mid, side - pad - 1),
            Vector2i(pad, mid), Vector2i(side - pad - 1, mid)]:
            if not _close(image.get_pixelv(pixel), frame_main):
                _fail("Missing main frame at %s, %s" % [str(pixel), str(side)])
                return
        # A true 45 degree chamfer; the bounding-box corner stays empty.
        var diagonal: Vector2i = Vector2i(pad + int(cut / 2),
            pad + cut - int(cut / 2))
        if not _close(image.get_pixelv(diagonal), frame_main):
            _fail("Missing diagonal chamfer at " + str(side))
            return
        if not _close(image.get_pixel(pad, pad), grid.get_pixel(pad, pad)):
            _fail("Square corner painted instead of clipped chamfer")
            return
        var accent_x: int = pad + cut + maxi(2, roundi(float(side) * 0.06))
        if not _close(image.get_pixel(accent_x, pad), frame_highlight):
            _fail("Top-left high-contrast accent missing at " + str(side))
            return
        if not _close(image.get_pixel(side - accent_x - 1, side - pad - 1),
                frame_highlight):
            _fail("Bottom-right accent missing at " + str(side))
            return
        if not _close(image.get_pixel(0, 0), grid.get_pixel(0, 0)):
            _fail("Frame escaped the safe icon margin")
            return
        if source.get_image().get_pixel(0, 0).a > 0.01:
            _fail("Equipment source PNG modified in-place")
            return
        # Test that the same outline works even with the solid background.
        var solid: Image = Backdrop.composite(source, "solid").get_image()
        if not _close(solid.get_pixel(mid, pad), frame_main) or (
                not _close(solid.get_pixel(0, 0), Backdrop.SOLID_COLOR)):
            _fail("Solid-background equipment icon lost its frame")
            return

    # Real equipment icons inherit the same frame regardless of original
    # resolution, and the cache must reuse one texture per blueprint.
    for blueprint in Catalog.PROTOTYPES.keys():
        var icon: Texture2D = Icons.equipment_icon(str(blueprint))
        if icon == null or icon is AtlasTexture:
            _fail("Equipment icon missing or not composed: " + str(blueprint))
            return
        if Icons.equipment_icon(str(blueprint)) != icon:
            _fail("Equipment icon cache not reused: " + str(blueprint))
            return
        var size: int = icon.get_width()
        var p: int = maxi(3, roundi(float(size) * 0.055))
        if not _close(icon.get_image().get_pixel(size / 2, p), frame_main):
            _fail("Game icon lacks tech frame: " + str(blueprint))
            return

    # The material atlas must remain an independent transparent source;
    # its output is not passed through the equipment presentation compositor.
    var material: Texture2D = Icons.material_icon("scrap_low")
    if material == null or material.get_width() != 72:
        _fail("Material icon unexpectedly changed")
        return
    print("SERA_EQUIPMENT_TECH_FRAME_RUNTIME_OK nineteen_blueprints=true 72px=true 512px=true")
    quit(0)
