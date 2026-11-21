extends SceneTree
## One popup, compact cut-corner frame, square active preview, and vector status.
const Popup = preload("res://scripts/sera_warehouse_detail_popup.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("SERA_WAREHOUSE_DETAIL_VISUAL_FAIL: " + reason)
    quit(1)

func _run() -> void:
    root.size = Vector2i(720, 1280)
    var host := Control.new()
    root.add_child(host)
    host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var popup: Control = Popup.new()
    host.add_child(popup)
    await process_frame
    await process_frame
    var window: PanelContainer = popup.find_child(
        "WarehouseDetailWindow", true, false) as PanelContainer
    var title: Label = popup.find_child("DetailName", true, false) as Label
    var mark: Control = popup.find_child(
        "WarehouseDetailMark", true, false) as Control
    var preview: Control = popup.find_child(
        "WarehouseDetail3D", true, false) as Control
    var frame: PanelContainer = popup.find_child(
        "WarehouseDetailPreviewFrame", true, false) as PanelContainer
    var scroll: ScrollContainer = popup.find_child(
        "WarehouseDetailStatsScroll", true, false) as ScrollContainer
    var favorite: Button = popup.find_child(
        "WarehouseFavoriteToggle", true, false) as Button
    var junk: Button = popup.find_child(
        "WarehouseJunkToggle", true, false) as Button
    var close: Button = popup.find_child(
        "WarehouseDetailClose", true, false) as Button
    if window == null or title == null or mark == null or close == null or (
            preview == null or frame == null or scroll == null or (
            favorite == null or junk == null)):
        _fail("detail panel regions or actions are missing")
        return
    if close.custom_minimum_size != Vector2(48, 48) or (
            close.size_flags_vertical != Control.SIZE_SHRINK_CENTER):
        _fail("close button must use a fixed square base, not stretch with header")
        return
    popup.visible = true
    await process_frame
    await process_frame
    if absf(close.size.x - close.size.y) > 1.0:
        _fail("close button rendered rectangle instead of square")
        return
    if window.anchor_bottom > 0.90 or window.anchor_left >= 0.06:
        _fail("detail should use a compact but wide portrait composition")
        return
    if title.get_node_or_null("NameUnderline") == null:
        _fail("equipment title must keep the shared underline")
        return
    if preview.custom_minimum_size.x < 280.0 or (
            preview.custom_minimum_size.x != preview.custom_minimum_size.y):
        _fail("part preview must remain a large square")
        return
    if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
        _fail("complete stat list must still scroll on smaller devices")
        return
    if not (favorite.get_theme_stylebox("normal") is StyleBoxTexture):
        _fail("actions should have native cut-corner frames")
        return
    popup.set("item", {"favorite": true, "junk": false})
    popup.call("_refresh_actions")
    if not mark.visible or mark.get("kind") != "favorite":
        _fail("favorite should be amber vector mark in title row")
        return
    popup.set("item", {"favorite": false, "junk": true})
    popup.call("_refresh_actions")
    if not mark.visible or mark.get("kind") != "junk":
        _fail("junk should be red vector mark in title row")
        return
    popup.set("item", {"favorite": false, "junk": false})
    popup.call("_refresh_actions")
    if mark.visible or favorite.text.contains("☆"):
        _fail("unmarked item should not show a stale badge or unicode symbol")
        return
    print("SERA_WAREHOUSE_DETAIL_VISUAL_RUNTIME_PASS")
    quit(0)
