extends SceneTree
## Runtime: all seven hanger buttons fit, five affixes are readable in two columns,
## craft stat font is stronger, and the stat table has one flat background.
const Affixes = preload("res://scripts/sera_craft_affixes.gd")
const TableBuilder = preload("res://scripts/sera_warehouse_stats_table.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_WAREHOUSE_AFFIX_GRID_VISUAL_FAIL: " + reason)
    quit(1)

func _run() -> void:
    root.size = Vector2i(720, 1280)
    var base: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(base)
    await process_frame
    await process_frame
    var fac: Node3D = base.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    var card: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    var locked: Button = (fac.get("item_layer") as Control).find_child(
        "LockedCraftSlot_02", true, false) as Button
    if card == null or locked == null:
        _fail("manufacturing cards missing")
        return
    var info: Label = card.find_child("ItemInfo", true, false) as Label
    var locked_info: Label = locked.find_child("ItemInfo", true, false) as Label
    if info == null or info.get_theme_font_size("font_size") != 20 or (
            locked_info == null or locked_info.get_theme_font_size("font_size") != 17) or (
            info.text.contains("基礎:") or not info.text.contains("最大HP")):
        _fail("craft stats must be prominent, with no base prefix")
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    await process_frame
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    var hanger: HBoxContainer = actions.find_child(
        "WarehouseHangerTabs", true, false) as HBoxContainer
    if hanger == null or hanger.get_child_count() != 7:
        _fail("warehouse must have exactly seven hanger tabs")
        return
    for node in hanger.get_children():
        var tab: Button = node as Button
        var caption: Label = tab.get_node_or_null("HangerCaption") as Label
        if caption == null or caption.text.is_empty() or not tab.text.is_empty():
            _fail("hanger tab caption must not force native minimum width")
            return
        if tab.position.x < -1.0 or tab.position.x + tab.size.x > hanger.size.x + 1.0:
            _fail("warehouse hanger buttons overflow the fixed non-scrollable row")
            return
    var list: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if list == null:
        _fail("warehouse virtual equipment list missing")
        return
    var sample: Array = [
        {"id":"guard","value":5},
        {"id":"energy_recovery","value":4},
        {"id":"attack","value":5},
        {"id":"stagger","value":2},
        {"id":"defense","value":3}
    ]
    if not Affixes.valid(sample):
        _fail("five fixture effects are invalid")
        return
    list.call("configure", [{
        "uid":"H01-0001","blueprint":"H01",
        "name":"スカウトバイザー", "affixes":sample,
        "favorite":false,"junk":false
    }], 2, "equipment")
    await process_frame
    var pool: Array = list.get("pool")
    if pool.is_empty() or pool.size() > 32:
        _fail("virtual pool must remain bounded")
        return
    var first: Button = pool[0] as Button
    var left: Label = first.get_node("ItemEffects") as Label
    var right: Label = first.get_node("ItemEffectsRight") as Label
    var separator: ColorRect = first.get_node("EffectCenterDivider") as ColorRect
    if left.text.split("\n").size() != 3 or right.text.split("\n").size() != 2:
        _fail("five affixes must split 3 on the left and 2 on the right")
        return
    if not separator.visible or separator.color != Color("#55798a") or (
            separator.position.y <= 2.0) or (
            separator.position.y + separator.size.y >= first.size.y - 2.0):
        _fail("blue-gray center separator must not meet card boundaries")
        return
    for effect: Dictionary in sample:
        if not (left.text + "\n" + right.text).contains(Affixes.label(effect)):
            _fail("visible affix missing: " + str(effect["id"]))
            return
    list.call("configure", [], 2, "equipment")
    await process_frame
    if right.visible or separator.visible:
        _fail("recycled blank warehouse cards must hide both effects and separator")
        return
    var table: GridContainer = TableBuilder.build("H01", sample, 720.0)
    root.add_child(table)
    await process_frame
    var bg: Color = Color("#152e3a")
    for node in table.get_children():
        var panel: Panel = node as Panel
        var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
        if style == null or style.bg_color != bg:
            _fail("warehouse status table uses multiple background colors")
            return
    var total: Label = table.get_node("Stat_total_hp/Content") as Label
    var math: Label = table.get_node("Stat_formula_hp/Content") as Label
    if total.get_theme_font_size("font_size") < 23 or (
            total.get_theme_font_size("font_size") <= math.get_theme_font_size("font_size")):
        _fail("total stat values need larger type than the expression")
        return
    print("SERA_WAREHOUSE_AFFIX_GRID_VISUAL_RUNTIME_PASS")
    quit(0)
