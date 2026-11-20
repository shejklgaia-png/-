extends SceneTree
## On-demand native Button creation: no temporary fillers, no retained card pool.
func _initialize() -> void:
    call_deferred("_run")

func _fail(msg: String) -> void:
    push_error("SERA_LABO_MINIMAL_ALLOCATION_FAIL: " + msg)
    quit(1)

func _verify(fac: Node, grid_name: String, expected: int, fillers: int) -> bool:
    var layer: VBoxContainer = fac.get("item_layer") as VBoxContainer
    var grid: VBoxContainer = layer.find_child(grid_name, true, false) as VBoxContainer
    var columns: int = 1 if grid_name == "PrototypeGrid" else 3
    var rows: Array = [] if grid == null else grid.get_children().filter(
        func(child: Node) -> bool: return child is HBoxContainer)
    if grid == null or rows.size() != ceili(float(expected)/float(columns)):
        _fail("grid missing or wrong row count: " + grid_name)
        return false
    var seen: int = 0
    var spare: int = 0
    var first_width: float = -1.0
    var last_width: float = -1.0
    for row in rows:
        if not row is HBoxContainer or row.get_child_count() != columns:
            _fail("row must retain three equal-width cells: " + grid_name)
            return false
        for child in row.get_children():
            if child is Button:
                var card: Button = child as Button
                if not card.is_visible_in_tree() or card.get_theme_stylebox("normal") is not StyleBoxTexture:
                    _fail("native rounded card disappeared: " + card.name)
                    return false
                seen += 1
                if first_width < 0:
                    first_width = card.size.x
                last_width = card.size.x
            else:
                spare += 1
    if seen != expected or spare != fillers:
        _fail("unnecessary permanent fillers or missing cards: "+grid_name+" "+str(seen)+"/"+str(spare))
        return false
    if absf(first_width-last_width) > 1.5:
        _fail("incomplete last row stretches instead of matching regular card width")
        return false
    return true

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node = hub.get_node("BaseFacilities")
    fac.call("_switch_section", "craft")
    await process_frame
    await process_frame
    if not _verify(fac, "PrototypeGrid", 1, 0):
        return
    var diag_before: String = str(fac.get("diag_stage"))
    fac.call("_diag_step", "disabled-test-probe")
    if str(fac.get("diag_stage")) != diag_before:
        _fail("closed developer mode must not record per-card diagnostic stages")
        return
    fac.call("_switch_section", "materials")
    await process_frame
    await process_frame
    if not _verify(fac, "MaterialFamilyGrid", 12, 0):
        return
    fac.call("_switch_section", "warehouse")
    await process_frame
    await process_frame
    var list: ScrollContainer = (fac.get("item_layer") as Control).find_child(
        "WarehouseMaterials", true, false) as ScrollContainer
    if list == null or (list.get("entries") as Array).size() != 12 or (
            (list.get("pool") as Array).size() > 32):
        _fail("twelve material records must use a bounded visible card pool")
        return
    var actions: VBoxContainer = fac.get("modal_actions") as VBoxContainer
    (actions.get_node("WarehouseCategoryTabs/WarehouseEquipmentTab") as Button).pressed.emit()
    await process_frame
    await process_frame
    list = (fac.get("item_layer") as Control).find_child(
        "WarehouseEquipment", true, false) as ScrollContainer
    if list == null or (list.get("entries") as Array).size() != 0 or (
            int(list.get("virtual_slots")) != 2) or (
            (list.get("pool") as Array).size() > 32):
        _fail("empty hanger must show two reusable native blank cards")
        return
    # Debugger can still record the exact checkpoint when explicitly enabled.
    var title: Label = fac.get("modal_title") as Label
    var tap := InputEventMouseButton.new()
    tap.button_index = MOUSE_BUTTON_LEFT
    tap.pressed = true
    for i in range(5):
        title.gui_input.emit(tap)
    fac.call("_diag_step", "enabled-test-probe")
    if str(fac.get("diag_stage")) != "enabled-test-probe":
        _fail("developer mode lost its error-tracing functionality")
        return
    print("SERA_LABO_MINIMAL_ALLOCATION_RUNTIME_PASS: 7/12 standard cards plus bounded 3/2-col virtual warehouse, debug on-demand")
    quit(0)
