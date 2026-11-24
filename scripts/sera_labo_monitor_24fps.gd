extends MeshInstance3D
## LABO / REFINE / STORAGE native animated screen for Android GL Compatibility.
## One unshaded quad and a compact dynamic ImageTexture per monitor.
## Each visible monitor produces an actual new pixel image at 24 Hz.
## No custom spatial shader, additional Viewport, or sprite-count limit.
const FPS: float = 24.0
const WIDTH: int = 192
const BG := Color("#061821")
const PANEL := Color("#0b2633")
const GRID := Color("#12313d")
const HEADER := Color("#143947")
const CYAN := Color("#66dcec")
const BLUE := Color("#397f9a")
const WHITE := Color("#bde9ef")
const AMBER := Color("#e7bc69")
const DARK := Color("#224858")
const FONT: Dictionary = {
    "A": ["01110","10001","10001","11111","10001","10001","10001"],
    "B": ["11110","10001","10001","11110","10001","10001","11110"],
    "C": ["01111","10000","10000","10000","10000","10000","01111"],
    "D": ["11110","10001","10001","10001","10001","10001","11110"],
    "E": ["11111","10000","10000","11110","10000","10000","11111"],
    "F": ["11111","10000","10000","11110","10000","10000","10000"],
    "G": ["01111","10000","10000","10111","10001","10001","01111"],
    "H": ["10001","10001","10001","11111","10001","10001","10001"],
    "I": ["11111","00100","00100","00100","00100","00100","11111"],
    "L": ["10000","10000","10000","10000","10000","10000","11111"],
    "M": ["10001","11011","10101","10101","10001","10001","10001"],
    "N": ["10001","11001","10101","10011","10001","10001","10001"],
    "O": ["01110","10001","10001","10001","10001","10001","01110"],
    "P": ["11110","10001","10001","11110","10000","10000","10000"],
    "R": ["11110","10001","10001","11110","10100","10010","10001"],
    "S": ["01111","10000","10000","01110","00001","00001","11110"],
    "T": ["11111","00100","00100","00100","00100","00100","00100"],
    "U": ["10001","10001","10001","10001","10001","10001","01110"],
    "V": ["10001","10001","10001","10001","10001","01010","00100"],
    "W": ["10001","10001","10001","10101","10101","10101","01010"],
    "Y": ["10001","10001","01010","00100","00100","00100","00100"],
    "0": ["01110","10011","10101","10101","11001","10001","01110"],
    "1": ["00100","01100","00100","00100","00100","00100","01110"],
    "2": ["01110","10001","00001","00010","00100","01000","11111"],
    "3": ["11110","00001","00001","01110","00001","00001","11110"],
    "4": ["00010","00110","01010","10010","11111","00010","00010"],
    "5": ["11111","10000","10000","11110","00001","00001","11110"],
    "6": ["01111","10000","10000","11110","10001","10001","01110"],
    "7": ["11111","00001","00010","00100","01000","01000","01000"],
    "8": ["01110","10001","10001","01110","10001","10001","01110"],
    "9": ["01110","10001","10001","01111","00001","00001","11110"],
    "/": ["00001","00001","00010","00100","01000","10000","10000"],
    ":": ["00000","00100","00100","00000","00100","00100","00000"],
    "-": ["00000","00000","00000","11111","00000","00000","00000"],
    ".": ["00000","00000","00000","00000","00000","01100","01100"],
    "%": ["11001","11010","00100","00100","01011","10011","00000"],
    " ": ["00000","00000","00000","00000","00000","00000","00000"],
}
const LABELS: Array[String] = ["PRINT", "FLOW", "PURITY", "RECYCLE", "INVENTORY", "SCANNER"]

var _mode: int = 0
var _height: int = 128
var _clock: float = 0.0
var _tick: int = -1
var _image: Image
var _texture: ImageTexture
var _backdrop: Image
var _glyph_cache: Dictionary = {}

func configure(screen_size: Vector2, display_mode: int) -> void:
    _mode = clampi(display_mode, 0, 5)
    _height = clampi(int(round(float(WIDTH) * screen_size.y / maxf(screen_size.x, 0.01))), 96, 144)
    var quad := QuadMesh.new()
    quad.size = screen_size
    mesh = quad
    _image = Image.create(WIDTH, _height, false, Image.FORMAT_RGBA8)
    _glyph_cache.clear()
    _build_backdrop()
    _backdrop = _image.duplicate() as Image
    # Spread the REFINE screen updates across different 24 Hz phases.
    # Low render FPS may still cause overlap; the animation rate is unchanged.
    _clock = float(_mode % 3) / (3.0 * FPS)
    _tick = 0
    _draw_frame(0, 0.0)
    _texture = ImageTexture.create_from_image(_image)
    var surface := StandardMaterial3D.new()
    surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    surface.cull_mode = BaseMaterial3D.CULL_DISABLED
    surface.albedo_color = Color.WHITE
    surface.albedo_texture = _texture
    surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material_override = surface
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    set_meta("FX_NO_OUTLINE", true)
    set_meta("sera_no_view_edges", true)
    set_meta("sera_outline_occluder_only", true)
    set_meta("sera_preserve_authored_material", true)
    set_meta("labo_display_mode", _mode)
    set_meta("monitor_fps", FPS)

func _process(delta: float) -> void:
    if _texture == null or not is_visible_in_tree():
        return
    _clock += delta
    var next_tick: int = int(floor(_clock * FPS))
    if next_tick == _tick:
        return
    _tick = next_tick
    _draw_frame(_tick, float(_tick) / FPS)
    _texture.update(_image)

func _rect(x: int, y: int, w: int, h: int, color: Color) -> void:
    if w <= 0 or h <= 0:
        return
    var bounded := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, WIDTH, _height))
    if bounded.has_area():
        _image.fill_rect(bounded, color)

func _pixel(x: int, y: int, color: Color) -> void:
    if x >= 0 and x < WIDTH and y >= 0 and y < _height:
        _image.set_pixel(x, y, color)

func _line(x1: int, y1: int, x2: int, y2: int, color: Color, thick: int = 1) -> void:
    var dx: int = absi(x2 - x1)
    var dy: int = -absi(y2 - y1)
    var sx: int = 1 if x1 < x2 else -1
    var sy: int = 1 if y1 < y2 else -1
    var err: int = dx + dy
    var x: int = x1
    var y: int = y1
    while true:
        if thick > 1:
            _rect(x - thick / 2, y - thick / 2, thick, thick, color)
        else:
            _pixel(x, y, color)
        if x == x2 and y == y2:
            break
        var twice: int = err * 2
        if twice >= dy:
            err += dy
            x += sx
        if twice <= dx:
            err += dx
            y += sy

func _text(message: String, x: int, y: int, tint: Color) -> void:
    # Bounded glyph/palette cache; preserve the original 5x7 pixels.
    var color_key: String = tint.to_html()
    for i in range(message.length()):
        var letter: String = message.substr(i, 1).to_upper()
        if letter == " " or not FONT.has(letter):
            continue
        var key: String = letter + color_key
        var stamp: Image = _glyph_cache.get(key) as Image
        if stamp == null:
            stamp = Image.create(5, 7, false, Image.FORMAT_RGBA8)
            stamp.fill(Color.TRANSPARENT)
            var glyph: Array = FONT[letter]
            for row in range(7):
                var bits: String = str(glyph[row])
                for col in range(5):
                    if bits[col] == "1":
                        stamp.set_pixel(col, row, tint)
            _glyph_cache[key] = stamp
        var at := Vector2i(x + i * 6, y)
        var clipped := Rect2i(at, Vector2i(5, 7)).intersection(
            Rect2i(0, 0, WIDTH, _height))
        if clipped.has_area():
            _image.blend_rect(stamp,
                Rect2i(clipped.position - at, clipped.size), clipped.position)

func _outline(x: int, y: int, w: int, h: int, color: Color) -> void:
    _rect(x, y, w, 1, color)
    _rect(x, y + h - 1, w, 1, color)
    _rect(x, y, 1, h, color)
    _rect(x + w - 1, y, 1, h, color)

func _build_backdrop() -> void:
    _image.fill(BG)
    for x in range(8, WIDTH - 8, 16):
        _rect(x, 8, 1, _height - 16, GRID)
    for y in range(8, _height - 8, 12):
        _rect(8, y, WIDTH - 16, 1, GRID)
    _outline(4, 4, WIDTH - 8, _height - 8, BLUE)
    _rect(7, 7, WIDTH - 14, 20, HEADER)
    _rect(9, 28, WIDTH - 18, 1, CYAN)
    _text("SERA / " + LABELS[_mode], 12, 14, WHITE)
    _text("24", WIDTH - 32, 14, AMBER)
    _rect(7, _height - 20, WIDTH - 14, 13, PANEL)
    _text("24HZ", WIDTH - 40, _height - 17, WHITE)

func _draw_frame(frame: int, time: float) -> void:
    _image.blit_rect(_backdrop, Rect2i(0, 0, WIDTH, _height), Vector2i.ZERO)
    _text("FRAME " + str(posmod(frame, 1000)), 12, _height - 17, CYAN)
    match _mode:
        0:
            _draw_print(time)
        1:
            _draw_flow(time)
        2:
            _draw_purity(time)
        3:
            _draw_recycle(time)
        4:
            _draw_inventory(time)
        _:
            _draw_scanner(frame, time)

func _draw_print(time: float) -> void:
    var progress: float = fposmod(time / 8.0, 1.0)
    var center: int = WIDTH / 2
    var floor_y: int = _height - 36
    var top_y: int = floor_y - int(46.0 * progress)
    _outline(43, 35, 106, floor_y - 32, DARK)
    for y in range(top_y, floor_y):
        var radius: int = maxi(13, 31 - int(absf(float(y - (floor_y + top_y) / 2)) * 0.18))
        _rect(center - radius, y, radius * 2, 1,
            CYAN if y % 5 == 0 else BLUE)
    var nozzle_x: int = center + int(sin(time * 2.7) * 35.0)
    _rect(nozzle_x - 8, maxi(33, top_y - 16), 16, 7, AMBER)
    _line(nozzle_x, maxi(40, top_y - 9), nozzle_x, top_y, WHITE, 2)
    _rect(34, _height - 30, 124, 5, DARK)
    _rect(34, _height - 30, int(progress * 124.0), 5, CYAN)
    _text(str(int(progress * 100.0)) + "%", 151, 37, AMBER)

func _draw_flow(time: float) -> void:
    for channel in range(3):
        var y_base: int = 46 + channel * 17
        _rect(19, y_base - 5, WIDTH - 38, 12, PANEL)
        _text("F" + str(channel + 1), 23, y_base - 2, AMBER)
        var px: int = 44
        var py: int = y_base
        for x in range(46, WIDTH - 16, 2):
            var yy: int = y_base + int(sin(float(x) * 0.12 - time * (1.8 + channel * 0.5)) * 3.0)
            _line(px, py, x, yy, CYAN)
            px = x
            py = yy
        var packet: int = 46 + int(fposmod(time * (22.0 + 5.0 * channel), float(WIDTH - 64)))
        _rect(packet - 3, y_base - 3, 7, 7, AMBER)
    _text("TRANSFER", 50, _height - 31, WHITE)

func _draw_purity(time: float) -> void:
    var base_y: int = _height - 34
    for i in range(5):
        var value: float = 0.18 + 0.78 * (0.5 + 0.5 * sin(time * 1.7 + i * 1.15))
        var height: int = 9 + int(48.0 * value)
        var x: int = 23 + i * 32
        _rect(x, base_y - height, 20, height, AMBER if i >= 3 else CYAN)
        _rect(x + 3, base_y - height + 4, 14, maxi(1, height - 8), PANEL)
        _rect(x, base_y - height, 20, 3, WHITE)
        _text(str(i + 1), x + 6, base_y + 3, BLUE)
    var sweep: int = 17 + int(fposmod(time * 15.0, float(WIDTH - 33)))
    _rect(sweep, 33, 2, base_y - 31, AMBER)

func _draw_recycle(time: float) -> void:
    var cx: int = 95
    var cy: int = (_height + 28) / 2
    var radius: float = 31.0
    var previous_x: int = cx + int(radius)
    var previous_y: int = cy
    for i in range(1, 65):
        var a: float = float(i) * TAU / 64.0
        var nx: int = cx + int(radius * cos(a))
        var ny: int = cy + int(radius * sin(a))
        _line(previous_x, previous_y, nx, ny, BLUE, 2)
        previous_x = nx
        previous_y = ny
    for arm in range(6):
        var angle: float = time * 1.7 + float(arm) * TAU / 6.0
        var tx: int = cx + int(cos(angle) * radius * 0.85)
        var ty: int = cy + int(sin(angle) * radius * 0.85)
        _line(cx, cy, tx, ty, CYAN, 3)
        _rect(tx - 2, ty - 2, 5, 5, WHITE)
    _rect(cx - 5, cy - 5, 10, 10, AMBER)
    _text("RECLAIM", 18, _height - 35, WHITE)
    var fill: float = fposmod(time / 6.0, 1.0)
    _rect(97, _height - 35, 72, 6, DARK)
    _rect(97, _height - 35, int(fill * 72.0), 6, CYAN)

func _draw_inventory(time: float) -> void:
    var scroll: float = fposmod(time * 0.85, 1.0)
    var first: int = int(floor(time * 0.85))
    var labels: Array[String] = ["SCR", "MTC", "ELE", "ORG", "CORE", "ALL"]
    for i in range(7):
        var y: int = 31 + i * 11 - int(scroll * 11.0)
        if y < 31 or y > _height - 35:
            continue
        var index: int = posmod(first + i, labels.size())
        var selected: bool = index == posmod(int(floor(time * 0.60)), labels.size())
        _rect(18, y, WIDTH - 37, 9, HEADER if selected else PANEL)
        _text(labels[index], 21, y + 1, AMBER if selected else WHITE)
        var amount: float = 0.30 + 0.61 * absf(sin(float(index) * 2.17 + floor(time * 0.5)))
        _rect(75, y + 2, 89, 5, DARK)
        _rect(75, y + 2, int(amount * 89.0), 5, CYAN if selected else BLUE)

func _draw_scanner(frame: int, time: float) -> void:
    var center_x: int = WIDTH / 2 + int(sin(time * 0.73) * 30.0)
    var center_y: int = (_height + 28) / 2 + int(cos(time * 0.91) * 12.0)
    _outline(24, 35, WIDTH - 48, _height - 73, BLUE)
    for i in range(34):
        var x: int = 29 + posmod(i * 59 + frame * 3, WIDTH - 59)
        var y: int = 40 + posmod(i * 31 + frame, maxi(1, _height - 85))
        _pixel(x, y, BLUE)
    var sweep: int = 28 + int(fposmod(time * 36.0, float(WIDTH - 55)))
    _rect(sweep, 36, 3, _height - 76, CYAN)
    _line(center_x - 16, center_y, center_x - 5, center_y, AMBER, 2)
    _line(center_x + 5, center_y, center_x + 16, center_y, AMBER, 2)
    _line(center_x, center_y - 16, center_x, center_y - 5, AMBER, 2)
    _line(center_x, center_y + 5, center_x, center_y + 16, AMBER, 2)
    _rect(center_x - 2, center_y - 2, 5, 5, WHITE)
