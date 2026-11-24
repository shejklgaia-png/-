extends "res://scripts/sera_labo_touch_scroll.gd"
## V529 native-Button virtualized warehouse: O(visible rows) GUI nodes, not O(999).
## A reusable textured StyleBox gives the clipped four-corner rectangle,
## including blank cells, without custom PanelContainer rendering on Android.
signal entry_pressed(entry: Dictionary)
const Icons = preload("res://scripts/sera_item_icons.gd")
const Affixes = preload("res://scripts/sera_craft_affixes.gd")
const LaboSkin = preload("res://scripts/sera_labo_round_skin.gd")
const MarkIcon = preload("res://scripts/sera_mark_icon.gd")
const GAP: float = 10.0
const CARD_HEIGHT_EQUIPMENT: float = 180.0
const CARD_HEIGHT_MATERIALS: float = 120.0
const MAX_POOL_CARDS: int = 32
var entries: Array = []
var columns: int = 2
var mode: String = "equipment"
var virtual_slots: int = 2
var pool: Array = []
var canvas: Control
var _row_pitch: float = 188.0
var _card_width: float = 200.0
var _first_row: int = -1
var _font: Font
static var _skin_cache: Dictionary = {}

func _ready() -> void:
    name = "WarehouseVirtualGrid"
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    custom_minimum_size.y = 184.0
    horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    _font = LaboSkin.ui_font()
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
    # The 999-capacity hanger is virtual; only on-screen cards are pooled.
    virtual_slots = (999 if mode == "equipment" else
        maxi(columns, ceili(float(entries.size()) / float(columns)) * columns))
    _row_pitch = _card_height() + GAP
    _first_row = -1
    if is_inside_tree():
        scroll_vertical = 0
        _relayout()

func prewarm(new_mode: String, capacity: int) -> void:
    configure([], 2, new_mode)
    while pool.size() < mini(MAX_POOL_CARDS, capacity):
        _make_card()
    for card in pool:
        card.hide()

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
    # One shared matte navy/cyan four-corner frame across craft, conversion,
    # warehouse materials, equipment and their blank placeholder cells.
    return LaboSkin.card_style(kind)


func _make_card() -> Button:
    # One pooled native Button, with square artwork and independent labels.
    # No textures, visual styles or controls are allocated during scrolling.
    var card := Button.new()
    card.clip_contents = true
    card.focus_mode = Control.FOCUS_NONE
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    card.text = ""
    for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
        card.add_theme_stylebox_override(kind, _skin("normal" if kind == "focus" else kind))
    canvas.add_child(card)
    var marker := ColorRect.new()
    marker.name = "TierMarker"
    marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(marker)
    var art := TextureRect.new()
    art.name = "ItemArt"
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.clip_contents = true
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    card.add_child(art)
    var meta := Label.new()
    meta.name = "ItemMeta"
    meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
    meta.clip_text = true
    meta.add_theme_font_override("font", LaboSkin.tracked_data_font())
    meta.add_theme_font_size_override("font_size", 12)
    meta.add_theme_color_override("font_color", Color("#9abfcb"))
    card.add_child(meta)
    var title := Label.new()
    title.name = "ItemTitle"
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title.add_theme_color_override("font_color", Color("#dde8ea"))
    title.add_theme_font_override("font", (
        LaboSkin.control_font() if mode == "materials" else LaboSkin.equipment_font()))
    title.add_theme_font_size_override("font_size", 20)
    title.autowrap_mode = TextServer.AUTOWRAP_OFF
    title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    title.clip_text = true
    card.add_child(title)
    LaboSkin.attach_name_underline(title)
    var effects := Label.new()
    effects.name = "ItemEffects"
    effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
    effects.add_theme_color_override("font_color", Color("#b2ced3"))
    effects.add_theme_font_override("font", LaboSkin.stats_font())
    effects.add_theme_font_size_override("font_size", 16)
    effects.add_theme_constant_override("line_spacing", 1)
    effects.autowrap_mode = TextServer.AUTOWRAP_OFF
    effects.clip_text = true
    card.add_child(effects)
    # Build the second column and its inset separator only once per
    # pooled card. Scrolling updates text and geometry, never allocates UI.
    var effects_right := Label.new()
    effects_right.name = "ItemEffectsRight"
    effects_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
    effects_right.add_theme_color_override("font_color", Color("#b2ced3"))
    effects_right.add_theme_font_override("font", LaboSkin.stats_font())
    effects_right.add_theme_font_size_override("font_size", 14)
    effects_right.add_theme_constant_override("line_spacing", 1)
    effects_right.autowrap_mode = TextServer.AUTOWRAP_OFF
    effects_right.clip_text = true
    effects_right.visible = false
    card.add_child(effects_right)
    var center_rule := ColorRect.new()
    center_rule.name = "EffectCenterDivider"
    center_rule.color = Color("#55798a")
    center_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center_rule.visible = false
    card.add_child(center_rule)
    var rule := ColorRect.new()
    rule.name = "DetailDivider"
    rule.color = Color("#31505c")
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(rule)
    var top_trace := ColorRect.new()
    top_trace.name = "TopTrace"
    top_trace.color = Color("#83b9c3")
    top_trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(top_trace)
    var empty := Label.new()
    empty.name = "EmptySlotLabel"
    empty.text = "—  EMPTY HANGER  —"
    empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    empty.add_theme_font_override("font", LaboSkin.tracked_display_font())
    empty.add_theme_font_size_override("font_size", 17)
    empty.add_theme_color_override("font_color", Color("#7697a4"))
    empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(empty)
    # A viewport-recycled address plate makes empty hangers feel like real slots.
    var slot_address := Label.new()
    slot_address.name = "SlotAddress"
    slot_address.mouse_filter = Control.MOUSE_FILTER_IGNORE
    slot_address.add_theme_font_override("font", LaboSkin.tracked_data_font())
    slot_address.add_theme_font_size_override("font_size", 12)
    slot_address.add_theme_color_override("font_color", Color("#708f9d"))
    slot_address.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    card.add_child(slot_address)
    var empty_beacon := ColorRect.new()
    empty_beacon.name = "EmptyBeacon"
    empty_beacon.color = Color("#4c8f9a")
    empty_beacon.size = Vector2(6.0, 6.0)
    empty_beacon.position = Vector2(15.0, 14.0)
    empty_beacon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(empty_beacon)
    # Marker controls are pooled like the cards; no Unicode-symbol fallback.
    for marker_kind in ["favorite", "junk"]:
        var mark_icon: Control = MarkIcon.new()
        mark_icon.name = ("FavoriteMarkIcon" if marker_kind == "favorite"
            else "JunkMarkIcon")
        mark_icon.set("kind", "favorite" if marker_kind == "favorite" else "junk")
        mark_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mark_icon.visible = false
        card.add_child(mark_icon)
    card.pressed.connect(_card_pressed.bind(card))
    pool.append(card)
    return card

func _card_pressed(card: Button) -> void:
    if touch_drag_consumed():
        return
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
    var marker: ColorRect = card.get_node("TierMarker") as ColorRect
    var meta: Label = card.get_node("ItemMeta") as Label
    var title: Label = card.get_node("ItemTitle") as Label
    var effects: Label = card.get_node("ItemEffects") as Label
    var effects_right: Label = card.get_node("ItemEffectsRight") as Label
    var center_rule: ColorRect = card.get_node("EffectCenterDivider") as ColorRect
    var empty: Label = card.get_node("EmptySlotLabel") as Label
    var divider: ColorRect = card.get_node("DetailDivider") as ColorRect
    var trace: ColorRect = card.get_node("TopTrace") as ColorRect
    var slot_address: Label = card.get_node("SlotAddress") as Label
    var empty_beacon: ColorRect = card.get_node("EmptyBeacon") as ColorRect
    var favorite_mark: Control = card.get_node("FavoriteMarkIcon") as Control
    var junk_mark: Control = card.get_node("JunkMarkIcon") as Control
    favorite_mark.visible = false
    junk_mark.visible = false
    slot_address.visible = blank and mode == "equipment"
    slot_address.text = "SLOT %03d / 999" % (index + 1)
    slot_address.position = Vector2(maxf(8.0, _card_width - 152.0), 11.0)
    slot_address.size = Vector2(minf(139.0, _card_width - 14.0), 18.0)
    empty_beacon.visible = blank and mode == "equipment"
    empty.visible = blank
    empty.position = Vector2(10.0, 12.0)
    empty.size = Vector2(maxf(10.0, _card_width - 20.0), _card_height() - 24.0)
    divider.visible = not blank and mode == "equipment"
    divider.position = Vector2(14.0, 96.0)
    divider.size = Vector2(maxf(10.0, _card_width - 28.0), 1.0)
    trace.visible = not blank
    trace.position = Vector2(13.0, 2.0)
    trace.size = Vector2(minf(52.0, _card_width * 0.34), 2.0)
    art.visible = not blank
    marker.visible = not blank
    meta.visible = not blank
    title.visible = not blank
    effects.visible = not blank
    effects_right.visible = false
    effects_right.text = ""
    center_rule.visible = false
    marker.position = Vector2(4.0, 14.0)
    marker.size = Vector2(3.0, _card_height() - 28.0)
    title.autowrap_mode = TextServer.AUTOWRAP_OFF
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    effects.autowrap_mode = TextServer.AUTOWRAP_OFF
    effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    if blank:
        art.texture = null
        meta.text = ""
        title.text = ""
        LaboSkin.refresh_name_underline(title)
        effects.text = ""
        marker.color = Color.TRANSPARENT
        return

    if mode == "materials":
        var id: String = str(entry.get("id", ""))
        var tier: int = 0
        if id.ends_with("_mid"):
            tier = 1
        elif id.ends_with("_high"):
            tier = 2
        marker.color = Color("#79b6c2")
        trace.color = marker.color
        art.texture = Icons.material_icon(id)
        art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        var compact: bool = _card_width < 244.0
        var side: float = minf(80.0, _card_height() - 24.0)
        if compact:
            # On narrow phones give long Japanese names the entire card width,
            # instead of forcing them into a thin text column beside the icon.
            side = minf(57.0, _card_width * 0.36)
            art.position = Vector2((_card_width - side) * 0.5, 7.0)
            art.size = Vector2(side, side)
            meta.visible = false
            title.position = Vector2(8.0, 68.0)
            title.size = Vector2(_card_width - 16.0, 26.0)
            title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            title.add_theme_font_size_override("font_size", 17)
            effects.position = Vector2(8.0, 97.0)
            effects.size = Vector2(_card_width - 16.0, 19.0)
            effects.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        else:
            art.position = Vector2(14.0, (_card_height() - side) * 0.5)
            art.size = Vector2(side, side)
            var text_left: float = art.position.x + side + 13.0
            var text_width: float = maxf(1.0, _card_width - text_left - 10.0)
            meta.position = Vector2(text_left, 17.0)
            meta.size = Vector2(text_width, 19.0)
            title.position = Vector2(text_left, 41.0)
            title.size = Vector2(text_width, 30.0)
            title.add_theme_font_size_override("font_size",
                clampi(int(_card_width / 16.0), 16, 19))
            effects.position = Vector2(text_left, 82.0)
            effects.size = Vector2(text_width, 26.0)
        meta.text = "MATERIAL / GRADE %02d" % (tier + 1)
        title.text = str(entry.get("name", ""))
        effects.text = "所持  %d" % int(entry.get("count", 0))
        effects.add_theme_font_size_override("font_size", 16)
    else:
        marker.color = Color("#68bec8")
        trace.color = Color("#a2e3e7")
        art.texture = Icons.equipment_icon(str(entry.get("blueprint", "")), "warehouse")
        art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        var equipment_side: float = minf(82.0, minf(_card_width * 0.36, 86.0))
        art.position = Vector2(12.0, 10.0)
        art.size = Vector2(equipment_side, equipment_side)
        var text_left: float = art.position.x + equipment_side + 10.0
        var text_width: float = maxf(1.0, _card_width - text_left - 9.0)
        meta.position = Vector2(text_left, 11.0)
        meta.size = Vector2(text_width, 19.0)
        title.position = Vector2(text_left, 34.0)
        title.size = Vector2(text_width, 49.0)
        title.add_theme_font_size_override("font_size", 20)
        title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        # Three effects on the left, two on the right. Both columns share
        # equal readable line heights below the card's horizontal divider.
        var clean_effects: Array = Affixes.sanitize(entry.get("affixes", []))
        var middle_x: float = _card_width * 0.5
        effects.position = Vector2(22.0, 101.0)
        effects.size = Vector2(maxf(32.0, middle_x - 30.0),
            _card_height() - 111.0)
        effects_right.position = Vector2(middle_x + 14.0, 101.0)
        effects_right.size = Vector2(maxf(32.0, _card_width - middle_x - 30.0),
            _card_height() - 111.0)
        effects.add_theme_font_size_override("font_size",
            13 if _card_width < 260.0 else 14)
        effects_right.add_theme_font_size_override("font_size",
            13 if _card_width < 260.0 else 14)
        effects.autowrap_mode = TextServer.AUTOWRAP_OFF
        effects_right.autowrap_mode = TextServer.AUTOWRAP_OFF
        center_rule.position = Vector2(middle_x - 1.0, 106.0)
        center_rule.size = Vector2(2.0, _card_height() - 118.0)
        center_rule.visible = clean_effects.size() > 3
        effects_right.visible = clean_effects.size() > 3
        var left_labels: PackedStringArray = []
        var right_labels: PackedStringArray = []
        for i in range(clean_effects.size()):
            if i < 3:
                left_labels.append(Affixes.label(clean_effects[i]))
            else:
                right_labels.append(Affixes.label(clean_effects[i]))
        var is_favorite: bool = bool(entry.get("favorite", false))
        var is_junk: bool = bool(entry.get("junk", false))
        var marked_count: int = int(is_favorite) + int(is_junk)
        # Markers sit immediately after the rendered equipment name, never
        # against the fixed right card edge. Measure text once per recycled
        # card binding; scrolling allocates no new nodes or textures.
        var inline_mark_size: float = clampf(_card_width * 0.09, 20.0, 28.0)
        var inline_mark_gap: float = 5.0
        var name_to_mark_gap: float = 7.0 if marked_count > 0 else 0.0
        var reserved_width: float = (float(marked_count) * inline_mark_size
            + float(maxi(0, marked_count - 1)) * inline_mark_gap)
        var available_name: float = maxf(0.0,
            text_width - reserved_width - name_to_mark_gap)
        var label_font: Font = title.get_theme_font("font")
        var item_name_text: String = str(entry.get("name", ""))
        # Keep the full Japanese name when possible without pushing the
        # larger marker off-card; 17px is the lower legibility boundary.
        var font_px: int = 20
        var name_width: float = label_font.get_string_size(
            item_name_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px).x
        while marked_count > 0 and font_px > 17 and name_width > available_name:
            font_px -= 1
            name_width = label_font.get_string_size(
                item_name_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px).x
        title.add_theme_font_size_override("font_size", font_px)
        title.size.x = (minf(available_name, name_width + 4.0)
            if marked_count > 0 else text_width)
        title.autowrap_mode = (TextServer.AUTOWRAP_OFF if marked_count > 0
            else TextServer.AUTOWRAP_WORD_SMART)
        var marker_x: float = title.position.x + title.size.x + name_to_mark_gap
        var mark_y: float = title.position.y + 1.0
        favorite_mark.visible = is_favorite
        junk_mark.visible = is_junk
        favorite_mark.size = Vector2(inline_mark_size, inline_mark_size)
        junk_mark.size = Vector2(inline_mark_size, inline_mark_size)
        if is_favorite:
            favorite_mark.position = Vector2(marker_x, mark_y)
            marker_x += inline_mark_size + inline_mark_gap
        if is_junk:
            junk_mark.position = Vector2(marker_x, mark_y)
        meta.text = "GEAR / " + str(entry.get("uid", ""))
        title.text = str(entry.get("name", ""))
        effects.text = ("\n".join(left_labels) if not clean_effects.is_empty() else
            Affixes.describe(entry.get("affixes", [])))
        effects_right.text = "\n".join(right_labels)
        if clean_effects.is_empty():
            # Legacy items have no rolled effects; do not truncate that
            # single fallback label into half of the card.
            effects.size.x = maxf(32.0, _card_width - 35.0)
    # One recycled bar follows each newly bound name; blank cards stay clean.
    LaboSkin.refresh_name_underline(title)
