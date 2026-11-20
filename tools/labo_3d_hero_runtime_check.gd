extends SceneTree
## New 3D view must be real geometry, persist across tabs, and stop when hidden.
func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("SERA_LABO_3D_HERO_FAIL: " + why)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    if fac.get("hero_stage") != null:
        _fail("the 3D hero should be lazy; no allocations on base free roam")
        return
    fac.call("open_facility", "LABO")
    await process_frame
    await process_frame
    var host: SubViewportContainer = fac.get("hero_host") as SubViewportContainer
    var viewport: SubViewport = fac.get("hero_viewport") as SubViewport
    var stage: Node3D = fac.get("hero_stage") as Node3D
    if host == null or viewport == null or stage == null or not host.is_visible_in_tree():
        _fail("LABO must show a live 3D hero rather than a static image")
        return
    if viewport.get_child_count() != 1 or viewport.get_child(0) != stage or not viewport.own_world_3d:
        _fail("each LABO must have exactly one isolated stage")
        return
    var ratio: float = host.size.y / fac.get_viewport().get_visible_rect().size.y
    if ratio < 0.28 or ratio > 0.32:
        _fail("LABO hero must reserve top 30% of the screen: " + str(ratio))
        return
    var crate: Node3D = stage.get_node_or_null("CRATE") as Node3D
    var nozzle: Node3D = stage.get_node_or_null("PrinterScene/Printer/PrinterNozzle") as Node3D
    var printed: Node3D = stage.get_node_or_null("PrinterScene/Printer/PrintedPart") as Node3D
    var terminal: Node3D = stage.get_node_or_null("PrinterScene/PrinterInspectionStation/TerminalScreen") as Node3D
    if crate == null or nozzle == null or printed == null or terminal == null:
        _fail("low-poly Crate, working 3D printer, printed part and workstation must be real geometry")
        return
    var origin: Vector3 = crate.position
    var nozzle_origin: Vector3 = nozzle.position
    stage.call("_process", 2.4)
    if origin.distance_to(crate.position) < 0.15:
        _fail("Crate is not physically travelling between its stations")
        return
    if nozzle_origin.distance_to(nozzle.position) < 0.01:
        _fail("3D printer nozzle is not physically operating")
        return
    var state_before: String = str(stage.get("work_state"))
    for i in range(9):
        stage.call("_process", 1.0)
    if str(stage.get("work_state")) == state_before:
        _fail("Crate is stuck and does not change work states")
        return
    var first_id: int = stage.get_instance_id()
    for section in ["materials", "warehouse", "craft"]:
        fac.call("_switch_section", section)
        await process_frame
        if not host.visible or stage.get_instance_id() != first_id:
            _fail("3D stage was re-created when tabs changed: " + section)
            return
    # Warehouse materials are read-only, but their blue-grey border must
    # still have enough contrast to remain visibly rendered on Android.
    fac.call("_switch_section", "warehouse")
    await process_frame
    var disabled_card: Button = (fac.get("item_layer") as Control).find_child(
        "MaterialIcon_scrap_low", true, false) as Button
    if disabled_card == null or not disabled_card.is_visible_in_tree():
        _fail("native virtual material card must be visible")
        return
    var disabled_style: StyleBoxTexture = disabled_card.get_theme_stylebox("disabled") as StyleBoxTexture
    if disabled_style == null or disabled_style.texture == null or (
            (disabled_card.get_node("ItemArt") as TextureRect).texture == null):
        _fail("read-only material needs four cut corners, contrast border, and real icon")
        return
    fac.call("_switch_section", "craft")
    await process_frame
    var craft_tab: Button = (fac.get("section_tabs") as HBoxContainer).get_node("TabCraft") as Button
    var normal_style: StyleBoxFlat = craft_tab.get_theme_stylebox("normal") as StyleBoxFlat
    if normal_style == null or normal_style.corner_radius_top_left < 4:
        _fail("all LABO navigation buttons need rounded blue-grey native styles")
        return
    var card: Button = (fac.get("item_layer") as Control).find_child(
        "PrototypeIcon_H01", true, false) as Button
    if card == null or card.get_theme_stylebox("normal") is not StyleBoxTexture:
        _fail("craft cards must be rounded and retain native Android buttons")
        return
    fac.call("close_menu")
    if host.visible or stage.is_processing() or viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
        _fail("closing LABO must suspend 3D updates and actor movement")
        return
    fac.call("open_facility", "STORAGE")
    if stage.get_instance_id() != first_id or not stage.is_processing():
        _fail("reopening warehouse must resume the same 3D stage")
        return
    print("SERA_LABO_3D_HERO_RUNTIME_PASS: 30%, moving Crate/printer, one viewport, rounded buttons, paused while closed")
    quit(0)
