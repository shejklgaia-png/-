extends SceneTree
## Real Godot mobile portrait layout constraints and equipment preview interaction.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_LABO_SQUARE_CONFIRM_RUNTIME_FAIL: " + message)
    quit(1)

func _run() -> void:
    var hub: Node3D = load("res://scenes/base_exploration.tscn").instantiate()
    root.add_child(hub)
    await process_frame
    await process_frame
    var fac: Node3D = hub.get_node("BaseFacilities") as Node3D
    fac.call("_switch_section","craft")
    fac.call("_select_prototype","H02")
    await process_frame
    await process_frame
    var overlay: Control = fac.get("confirmation_overlay") as Control
    var panel: PanelContainer = overlay.find_child(
        "LaboConfirmPanel",true,false) as PanelContainer
    var square: AspectRatioContainer = overlay.find_child(
        "LaboConfirmSquarePreview",true,false) as AspectRatioContainer
    var placeholder: TextureRect = fac.get("confirmation_item_icon") as TextureRect
    var preview: SubViewportContainer = fac.get("confirmation_preview_host") as SubViewportContainer
    var card: PanelContainer = fac.get("confirmation_craft_card") as PanelContainer
    var heading: Label = fac.get("confirmation_title") as Label
    var stats: Label = fac.get("confirmation_item_stats") as Label
    var question: Label = fac.get("confirmation_prompt") as Label
    var rail: ColorRect = overlay.find_child("LaboConfirmAccentRail", true, false) as ColorRect
    var stats_rows: VBoxContainer = overlay.find_child("LaboConfirmStatRows", true, false) as VBoxContainer
    var tech_frame: Control = overlay.find_child("LaboConfirmPreviewTechFrame", true, false) as Control
    var confirm_button: Button = fac.get("confirmation_accept_button") as Button
    var cancel_button: Button = overlay.find_child(
        "LaboConfirmCancel",true,false) as Button
    if not overlay.visible or panel == null or square == null or (
            card == null or not card.visible or placeholder == null or (
            preview == null or heading == null or stats == null or (
            question == null or confirm_button == null or cancel_button == null or (
            rail == null or stats_rows == null or tech_frame == null)))):
        _fail("Missing square-first confirmation UI")
        return
    if rail.color != Color("#55798a") or stats_rows.get_child_count() < 3 or (
            stats.visible or not tech_frame.visible):

        _fail("shared name/value technical rows and chamfered preview border missing")
        return
    if absf(square.ratio-1.0)>0.0001 or (
            square.size.x<275.0 or square.size.y<275.0) or (
            absf(square.size.x-square.size.y)>1.2):
        _fail("Equipment preview is not a prominent real square: " + str(square.size))
        return
    var preview_frame: PanelContainer = overlay.find_child(
        "LaboConfirmPreviewFrame", true, false) as PanelContainer
    if preview_frame == null:
        _fail("square border is absent")
        return
    var frame_skin: StyleBoxFlat = preview_frame.get_theme_stylebox("panel") as StyleBoxFlat
    if frame_skin == null or frame_skin.border_width_left != 1 or (
            frame_skin.content_margin_left != 0.0 or (
            frame_skin.content_margin_right != 0.0 or (
            frame_skin.content_margin_top != 0.0 or (
            frame_skin.content_margin_bottom != 0.0)):
        _fail("double-inset square border returned")
        return
    var stage_rect: Rect2 = square.get_global_rect()
    var card_rect: Rect2 = card.get_global_rect()
    var panel_rect: Rect2 = panel.get_global_rect()
    var screen: Rect2 = overlay.get_global_rect()
    if panel_rect.size.y<700.0 or (
            panel_rect.position.y<screen.position.y+5.0 or (
            panel_rect.end.y>screen.end.y-5.0)):
        _fail("Tall confirmation panel clipped from phone viewport")
        return
    if not card_rect.encloses(stage_rect):
        _fail("Square viewport escapes the equipment card")
        return
    if not (heading.get_global_rect().end.y<stage_rect.position.y and
            stage_rect.end.y<=stats_rows.get_global_rect().position.y and (
            stats_rows.get_global_rect().end.y<question.get_global_rect().position.y) and (
            question.get_global_rect().end.y<confirm_button.get_global_rect().position.y)):
        _fail("Vertical hierarchy is not title -> square -> specs -> decision -> actions")
        return
    var first_row: HBoxContainer = stats_rows.get_child(0) as HBoxContainer
    var first_label: Label = first_row.get_child(0) as Label
    var first_value: Label = first_row.get_child(1) as Label
    if first_label.text.is_empty() or first_value.text.is_empty() or (
            first_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_LEFT or (
            first_value.horizontal_alignment != HORIZONTAL_ALIGNMENT_LEFT)):
        _fail("LABO stat label/value must be independently left aligned")
        return
    if absf(confirm_button.size.y-cancel_button.size.y)>1.0 or (
            confirm_button.size.y<65.0):
        _fail("Action buttons are undersized or unbalanced")
        return
    if placeholder.visible == preview.visible or (
            placeholder.visible and placeholder.texture == null):
        _fail("Exactly one of fallback icon and interactive 3D must occupy the square")
        return
    if preview.get_parent() != placeholder.get_parent():
        _fail("Fallback and interactive 3D do not share one square viewport")
        return
    var old_rect: Rect2 = square.get_global_rect()
    fac.call("_layout_craft_confirmation")
    await process_frame
    if square.get_global_rect().size.distance_to(old_rect.size)>1.0:
        _fail("Square layout is unstable across repeated sizing")
        return
    fac.call("_dismiss_confirmation")
    if overlay.visible or (
            (fac.get("confirmation_preview_viewport") is SubViewport) and
            (fac.get("confirmation_preview_viewport") as SubViewport).render_target_update_mode !=
                SubViewport.UPDATE_DISABLED):
        _fail("Cancel did not stop the 3D preview")
        return
    print("SERA_LABO_SQUARE_CONFIRM_RUNTIME_OK preview=1:1 layout=portrait actions=reachable")
    quit(0)
