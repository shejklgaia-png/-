extends SceneTree
## Android portrait LABO: readable 3D signs and named UI underline semantics.
const Skin = preload("res://scripts/sera_labo_round_skin.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_LABO_NAMES_SIGNS_FAIL: " + reason)
    quit(1)

func _has_name_rule(label: Label, required_visible: bool = true) -> bool:
    if label == null:
        return false
    var rule: ColorRect = label.get_node_or_null("NameUnderline") as ColorRect
    if rule == null or rule.color != Skin.NAME_UNDERLINE_COLOR or (
            rule.mouse_filter != Control.MOUSE_FILTER_IGNORE):
        return false
    if not required_visible:
        return not rule.visible
    return rule.visible and rule.size.y <= 2.0 and (
        rule.size.x > 4.0 and rule.size.x <= label.size.x + 1.0)

func _run() -> void:
    root.size = Vector2i(720, 1280)
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    await process_frame
    var header: Label = fac.get("modal_title") as Label
    if not _has_name_rule(header):
        _fail("LABO main heading has no slim blue-grey underline")
        return
    var craft: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    if craft == null or not _has_name_rule(
            craft.find_child("ItemTitle", true, false) as Label):
        _fail("manufactured equipment names must be underlined")
        return
    var locked: Button = (fac.get("item_layer") as Control).find_child(
        "LockedCraftSlot_02", true, false) as Button
    if locked == null or (locked.find_child(
            "ItemTitle", true, false) as Label).has_node("NameUnderline"):
        _fail("LOCKED SLOT placeholder is not a name")
        return
    var host: SubViewportContainer = fac.get("hero_host") as SubViewportContainer
    var stage: Node3D = fac.get("hero_stage") as Node3D
    var printer: Label3D = stage.find_child(
        "IndustrialSign_3D_PRINTER", true, false) as Label3D
    var sera: Label3D = stage.find_child(
        "IndustrialSign_SERA", true, false) as Label3D
    if host.stretch_shrink != 1 or printer == null or sera == null:
        _fail("3D stage sign or full-resolution presentation missing")
        return
    if printer.font != Skin.display_font() or (
            sera.font != Skin.display_font()) or (
            printer.outline_size != 2):
        _fail("3D signs must use crisp bundled Latin glyphs with dark stroke")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    await process_frame
    var material: Button = (fac.get("item_layer") as Control).find_child(
        "MaterialIcon_scrap_low", true, false) as Button
    if material == null or not _has_name_rule(
            material.find_child("ItemTitle", true, false) as Label):
        _fail("two-line material names need underlines")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    await process_frame
    var grid: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if grid == null or (grid.get("pool") as Array).is_empty():
        _fail("warehouse card pool is unavailable")
        return
    var empty: Label = ((grid.get("pool") as Array)[0] as Button).get_node(
        "ItemTitle") as Label
    if not _has_name_rule(empty, false):
        _fail("unused pooled warehouse names must hide underlines")
        return
    var probe := Label.new()
    probe.add_theme_font_override("font", Skin.ui_font())
    probe.add_theme_font_size_override("font_size", 20)
    probe.text = "ランナーレッグ"
    probe.size = Vector2(210.0, 42.0)
    root.add_child(probe)
    Skin.attach_name_underline(probe)
    await process_frame
    if not _has_name_rule(probe):
        _fail("runtime custom name underline was not sized")
        return
    probe.text = ""
    Skin.refresh_name_underline(probe)
    if not _has_name_rule(probe, false):
        _fail("empty name underline was not hidden")
        return
    print("SERA_LABO_NAME_UNDERLINES_SIGNS_RUNTIME_PASS")
    quit(0)
