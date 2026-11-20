extends SceneTree
## Check the exact 72x72 crop, per-icon isolation, and material card bounds.
const Icons = preload("res://scripts/sera_item_icons.gd")
const Materials = preload("res://scripts/sera_base_materials.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(reason: String) -> void:
    push_error("SERA_V530_ICON_BOUNDS_FAIL: " + reason)
    quit(1)

func _check_image(source: Image, index: int, icon: Texture2D) -> bool:
    if icon == null or icon is AtlasTexture or icon.get_width() != 72 or icon.get_height() != 72:
        _fail("material icon is not its own 72x72 texture: " + str(index))
        return false
    var actual: Image = icon.get_image()
    if actual == null or actual.get_width() != 72 or actual.get_height() != 72:
        _fail("material crop cannot be read: " + str(index))
        return false
    var origin: Vector2i = Vector2i(index % 3 * 72, int(index / 3) * 72)
    # New transparent 72x72 sprites must have at least two clear pixels
    # on every edge, so even tiny scaled cards cannot sample their neighbour.
    var opaque_count: int = 0
    for y in range(72):
        for x in range(72):
            var expected: Color = source.get_pixel(origin.x + x, origin.y + y)
            if expected.a > 0.10:
                opaque_count += 1
            if (x < 2 or x >= 70 or y < 2 or y >= 70) and expected.a > 0.0:
                _fail("nontransparent material tile border: " + str(index)
                    + " at " + str(Vector2i(x, y)))
                return false
            if actual.get_pixel(x, y) != expected:
                _fail("sprite pixels leak from neighbouring cell: " + str(index)
                    + " at " + str(Vector2i(x, y)))
                return false
    if opaque_count < 100:
        _fail("material icon is unexpectedly empty: " + str(index))
        return false
    return true

func _check_material_grid(grid: ScrollContainer) -> bool:
    if grid == null or grid.get("entries").size() != 12:
        _fail("material virtual grid is missing")
        return false
    for node in grid.get("pool"):
        var card: Button = node as Button
        if card == null or not card.visible:
            continue
        var art: TextureRect = card.get_node("ItemArt") as TextureRect
        if art == null or art.texture == null or not art.clip_contents or not card.clip_contents:
            _fail("material card/art missing or not clipped")
            return false
        if art.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
            _fail("material card deforms the icon")
            return false
        if absf(art.size.x - art.size.y) > 0.01 or (
                art.position.x < 0 or art.position.y < 0 or (
                art.position + art.size).x > card.size.x + 0.01 or (
                art.position + art.size).y > card.size.y + 0.01):
            _fail("material icon square exceeds its native card bounds")
            return false
        var text: Label = card.get_node("ItemTitle") as Label
        if art.position.x + art.size.x + 2.0 > text.position.x:
            _fail("material image overlaps its label area")
            return false
    return true

func _run() -> void:
    var source := Image.new()
    if source.load_webp_from_buffer(
            FileAccess.get_file_as_bytes(Icons.MATERIAL_ATLAS_PATH)) != OK:
        _fail("pixel source unavailable")
        return
    if source.get_width() != 216 or source.get_height() != 288:
        _fail("material atlas size changed")
        return
    var identities: Dictionary = {}
    for index in range(Materials.all_ids().size()):
        var id: String = str(Materials.all_ids()[index])
        # all_ids() iterates family then tier, exactly the sprite-sheet order
        var texture: Texture2D = Icons.material_icon(id)
        if not _check_image(source, index, texture):
            return
        if identities.has(texture.get_instance_id()):
            _fail("two material IDs share the same crop")
            return
        identities[texture.get_instance_id()] = true
        if Icons.material_icon(id) != texture:
            _fail("material cache must return the same texture")
            return
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("open_facility", "STORAGE")
    await process_frame
    await process_frame
    var w: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if not _check_material_grid(w):
        return
    # Material family controls continue to use native Buttons on Android.
    fac.call("_switch_section", "materials")
    await process_frame
    for id in Materials.all_ids():
        var button: Button = (fac.get("item_layer") as Control).find_child(
            "MaterialIcon_" + str(id), true, false) as Button
        if button == null or not button.clip_contents or button.icon != null:
            _fail("material native root must clip without drawing Button.icon: " + str(id))
            return
        var art: TextureRect = button.find_child("ItemArt", true, false) as TextureRect
        if art == null or art.texture == null or not art.clip_contents or (
                art.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED):
            _fail("material TextureRect missing/uncropped: " + str(id))
            return
        if art.texture.get_width() != art.texture.get_height() or (
                not button.get_global_rect().grow(1).encloses(art.get_global_rect())):
            _fail("material thumbnail outside native card: " + str(id))
            return
    fac.call("open_facility", "SMELTER")
    fac.call("_select_conversion_family", "organic")
    await process_frame
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    for rank in [0, 1]:
        var button: Button = actions.find_child(
            "ConvertRank_" + str(rank), true, false) as Button
        if button == null:
            _fail("conversion row absent: " + str(rank))
            return
        for part in ["ConvertInputIcon_", "ConvertOutputIcon_"]:
            var art: TextureRect = button.find_child(
                part + str(rank), true, false) as TextureRect
            if art == null or not art.clip_contents or (
                    art.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED):
                _fail("conversion icon not clipped and proportional: " + part)
                return
    print("SERA_V530_MATERIAL_ICON_BOUNDS_RUNTIME_PASS")
    quit(0)
