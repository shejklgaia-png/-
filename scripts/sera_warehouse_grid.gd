extends ScrollContainer
## V529 native-Button virtualized warehouse: O(visible rows) GUI nodes, not O(999).
## A reusable textured StyleBox gives the clipped four-corner rectangle,
## including blank cells, without custom PanelContainer rendering on Android.
signal entry_pressed(entry: Dictionary)
const Icons = preload("res://scripts/sera_item_icons.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")
const GAP: float = 8.0
const CARD_HEIGHT_EQUIPMENT: float = 156.0
const CARD_HEIGHT_MATERIALS: float = 108.0
const MAX_POOL_CARDS: int = 32
var entries: Array = []
var columns: int = 2
var mode: String = "equipment"
var virtual_slots: int = 2
var pool: Array = []
var canvas: Control
var _row_pitch: float = 164.0
var _card_width: float = 200.0
var _first_row: int = -1
var _font: Font
static var _skin_cache: Dictionary = {}

func _ready() -> void:
    name = "WarehouseVirtualGrid"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    custom_minimum_size.y = 168.0
    horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    _font = SystemFont.new()
    (_font as SystemFont).font_names = PackedStringArray([
        "M PLUS 1 Code", "Noto Sans Mono CJK JP", "Noto Sans JP", "monospace"
    ])
    canvas = Control.new()
    canvas.name = "VirtualCanvas"
    canvas.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(canvas)
    get_v_scroll_bar().value_changed.connect(_on_scroll)
    resized.connect(_on_resized)
    call_deferred("_relayout")

func configure(data: Array, new_columns: int, new_mode: String) -> void:
    entries = data.duplicate(true)
    columns = 3 if new_columns == 3 else 2
    mode = "materials" if new_mode == "materials" else "equipment"
    virtual_slots = maxi(columns, ceili(float(entries.size()) / float(columns)) * columns)
    _row_pitch = _card_height() + GAP
    _first_row = -1
    if is_inside_tree():
        scroll_vertical = 0
        _relayout()

func _card_height() -> float:
    return CARD_HEIGHT_MATERIALS if mode == "materials" else CARD_HEIGHT_EQUIPMENT

func _on_resized() -> void:
    if is_inside_tree() and canvas != null:
        _relayout()

func _on_scroll(_value: float) -> void:
    _refresh_visible()

func _relayout() -> void:
    if canvas == null or not is_inside_tree() or size.x <= 0.0:
        return
    # Reserve native scrollbar space: do not allow the right column to clip.
    var usable_width: float = maxf(100.0, size.x - 18.0)
    _card_width = maxf(45.0, (usable_width - GAP * float(columns - 1)) / float(columns))
    var rows: int = maxi(1, ceili(float(virtual_slots) / float(columns)))
    canvas.custom_minimum_size = Vector2(usable_width, float(rows) * _row_pitch)
    canvas.size = canvas.custom_minimum_size
    _first_row = -1
    _refresh_visible(true)

func _skin(kind: String) -> StyleBoxTexture:
    if _skin_cache.has(kind):
        return _skin_cache[kind] as StyleBoxTexture
    var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    var background: Color = Color("#142430")
    var border: Color = Color("#65bed2")
    if kind == "pressed":
        background = Color("#29495c")
        border = Color("#dbf5ff")
    elif kind == "hover":
        background = Color("#203c50")
        border = Color("#9fcbdc")
    elif kind == "disabled":
        border = Color("#65bed2")
    for y in range(32):
        for x in range(32):
            var a: int = x + y
            var b: int = (31 - x) + y
            var c: int = x + (31 - y)
            var d: int = (31 - x) + (31 - y)
            var nearest: int = mini(mini(a, b), mini(c, d))
            if nearest < 7:
                image.set_pixel(x, y, Color.TRANSPARENT)
            elif x <= 1 or x >= 30 or y <= 1 or y >= 30 or nearest <= 9:
                image.set_pixel(x, y, border)
            else:
                image.set_pixel(x, y, background)
    var box := StyleBoxTexture.new()
    box.texture = ImageTexture.create_from_image(image)
    box.set_texture_margin_all(10.0)
    _skin_cache[kind] = box
    return box

func _make_card() -> Button:
    var card := Button.new()
    card.clip_contents = true
    card.focus_mode = Control.FOCUS_NONE
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.text = ""
    for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
        card.add_theme_stylebox_override(kind, _skin("normal" if kind == "focus" else kind))
    canvas.add_child(card)
    var art := TextureRect.new()
    art.name = "ItemArt"
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    card.add_child(art)
    var title := Label.new()
    title.name = "ItemTitle"
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title.add_theme_color_override("font_color", Color("#f4faff"))
    title.add_theme_font_override("font", _font)
    title.add_theme_font_size_override("font_size", 12)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.clip_text = true
    card.add_child(title)
    var effects := Label.new()
    effects.name = "ItemEffects"
    effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
    effects.add_theme_color_override("font_color", Color("#ecf5fc"))
    effects.add_theme_font_override("font", _font)
    effects.add_theme_font_size_override("font_size", 12)
    effects.autowrap_mode = TextServer.AUTOWRAP_OFF
    effects.clip_text = true
    card.add_child(effects)
    card.pressed.connect(_card_pressed.bind(card))
    pool.append(card)
    return card

func _card_pressed(card: Button) -> void:
    if card.disabled:
        return
    var entry: Dictionary = card.get_meta("entry", {})
    if not entry.is_empty():
        entry_pressed.emit(entry)

func _refresh_visible(force: bool = false) -> void:
    if canvas == null or not is_inside_tree() or size.x <= 0.0:
        return
    var row_count: int = maxi(1, ceili(float(virtual_slots) / float(columns)))
    var first: int = clampi(int(floor(float(scroll_vertical) / _row_pitch)) - 1, 0, row_count - 1)
    if first == _first_row and not force:
        return
    _first_row = first
    var visible_rows: int = maxi(1, ceili(size.y / _row_pitch)) + 3
    var needed: int = mini(MAX_POOL_CARDS, visible_rows * columns)
    while pool.size() < needed:
        _make_card()
    for index in range(pool.size()):
        var card: Button = pool[index] as Button
        var row: int = first + int(index / columns)
        var column: int = index % columns
        var virtual_index: int = row * columns + column
        if virtual_index >= virtual_slots:
            card.visible = false
            continue
        card.visible = true
        card.position = Vector2(float(column) * (_card_width + GAP),
            float(row) * _row_pitch)
        card.size = Vector2(_card_width, _card_height())
        _bind_card(card, virtual_index)

func _bind_card(card: Button, index: int) -> void:
    var blank: bool = index >= entries.size()
    var entry: Dictionary = {} if blank else entries[index]
    card.set_meta("entry", entry)
    card.disabled = blank or mode == "materials"
    card.name = ("WarehouseEmpty_%d" % index if blank else
        "MaterialIcon_" + str(entry.get("id", "")) if mode == "materials" else
        "WarehouseItem_" + str(entry.get("uid", "")))
    var art: TextureRect = card.get_node("ItemArt") as TextureRect
    var title: Label = card.get_node("ItemTitle") as Label
    var effects: Label = card.get_node("ItemEffects") as Label
    var side: float = _card_height() - 14.0
    art.position = Vector2(7.0, 7.0)
    art.size = Vector2(side, side)
    var text_left: float = side + 14.0
    var text_width: float = maxf(1.0, _card_width - text_left - 6.0)
    title.position = Vector2(text_left, 6.0)
    title.size = Vector2(text_width, 34.0 if mode == "equipment" else 86.0)
    effects.position = Vector2(text_left, 42.0)
    effects.size = Vector2(text_width, _card_height() - 47.0)
    title.visible = not blank
    effects.visible = not blank and mode == "equipment"
    art.visible = not blank
    if blank:
        art.texture = null
        title.text = ""
        effects.text = ""
    elif mode == "materials":
        var id: String = str(entry.get("id", ""))
        title.text = str(entry.get("name", "")) + "\n所持 " + str(entry.get("count", 0))
        effects.text = ""
        art.texture = Icons.material_icon(id)
    else:
        var blueprint: String = str(entry.get("blueprint", ""))
        title.text = str(entry.get("name", "")) + "\n" + str(entry.get("uid", ""))
        effects.text = Affixes.describe(entry.get("affixes", []))
        art.texture = Icons.equipment_icon(blueprint)
