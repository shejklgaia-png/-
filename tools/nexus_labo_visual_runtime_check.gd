extends SceneTree
## Runtime: real NEXUS overlay, five destination panels, typography and controls.
const LaboTypeface = preload("res://scripts/sera_labo_round_skin.gd")
func _initialize() -> void:
    call_deferred("_run")
func _fail(why: String) -> void:
    push_error("NEXUS_LABO_VISUAL_RUNTIME_FAIL: " + why)
    quit(1)
func _run() -> void:
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    var hud: Control = nexus.get("hud") as Control
    var focus: Panel = nexus.get("focus_panel") as Panel
    var right: Panel = nexus.get("customize_right_panel") as Panel
    if hud == null or hud.theme == null or focus == null or right == null:
        _fail("NEXUS did not initialize its themed overlay")
        return
    var body: StyleBoxFlat = focus.get_theme_stylebox("panel") as StyleBoxFlat
    if body == null or body.bg_color.a < 0.90:
        _fail("3D focus menu did not get LABO's opaque matte contrast")
        return
    var title: Label = nexus.get("focus_title") as Label
    var exit_label: Label = nexus.get("explore_label") as Label
    if title.get_theme_font("font") != LaboTypeface.tracked_display_font() or (
            exit_label.get_theme_font("font") != LaboTypeface.tracked_display_font()):
        _fail("NEXUS top-level titles lack LABO's bundled display font")
        return
    var equipment: Dictionary = nexus.get("customize_equipment_rows")
    if equipment.size() != 7:
        _fail("seven existing equipment selectors must be preserved")
        return
    for slot in equipment:
        var button: Button = equipment[slot]["panel"] as Button
        if button == null:
            _fail("missing equipment row: " + str(slot))
            return
        var bg: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
        var lab_skin: StyleBoxFlat = LaboTypeface.terminal_segment_style("normal")
        if bg == null or bg.bg_color != lab_skin.bg_color or (
                bg.border_color != lab_skin.border_color):
            _fail("equipment row no longer uses the shared matte LABO palette")
            return
        if button.get_theme_font("font") != LaboTypeface.equipment_font():
            _fail("equipment-name button lacks the item font")
            return
        var expand: Button = equipment[slot]["expand"] as Button
        var underline: ColorRect = equipment[slot]["underline"] as ColorRect
        if button.alignment != HORIZONTAL_ALIGNMENT_LEFT or expand == null or (
                expand.name != "EquipmentThumbnailExpand") or (
                underline == null) or (
                underline.name != "EquipmentNameUnderline"):
            _fail("row must left-align the name and own a separate thumbnail button")
            return
        if button.get_child_count() != 2 or (
                expand.get_parent() != button) or underline.get_parent() != button:
            _fail("equipment row must contain only its expander and name underline")
            return
        if underline.color != Color("#55798a") or (
                not is_equal_approx(underline.size.y, 1.0)):
            _fail("equipment name underline must remain matte blue-grey and 1px")
            return
    # CUSTOMIZE backdrop is one translucent 3D surface behind SERA, not a
    # 2D tint drawn over the character or controls. At its preview distance it
    # must fit the complete portrait viewport on either axis.
    var backdrop: MeshInstance3D = nexus.get("customize_glow_quad") as MeshInstance3D
    var camera: Camera3D = nexus.get("cam") as Camera3D
    if backdrop == null or camera == null or not (backdrop.mesh is QuadMesh) or (
            not (backdrop.material_override is ShaderMaterial)):
        _fail("CUSTOMIZE depth-tested 3D background is missing")
        return
    var backdrop_mat: ShaderMaterial = backdrop.material_override as ShaderMaterial
    var opacity: float = float(backdrop_mat.get_shader_parameter("base_opacity"))
    if not is_equal_approx(opacity, 0.62):
        _fail("CUSTOMIZE base must have constant 0.62 semi-transparency")
        return
    var base_tint: Color = backdrop_mat.get_shader_parameter("base_tint")
    var grid_tint: Color = backdrop_mat.get_shader_parameter("grid_tint")
    if base_tint != Color("#4a6b7d") or grid_tint != Color("#213944"):
        _fail("CUSTOMIZE must use the approved matte blue-grey and dark grid colors")
        return
    if grid_tint.r >= base_tint.r or grid_tint.g >= base_tint.g or (
            grid_tint.b >= base_tint.b):
        _fail("grid RGB must be strictly darker than the uniform base")
        return
    if backdrop_mat.shader.code.contains("halo_center") or (
            backdrop_mat.shader.code.contains("soft_falloff")):
        _fail("obsolete cyan/radial effect is still in the background shader")
        return
    nexus.set("customize_preview_active", true)
    nexus.call("_update_customization_glow")
    nexus.set("customize_preview_active", false)
    var backdrop_quad: QuadMesh = backdrop.mesh as QuadMesh
    var preview_position: Vector3 = nexus.get("customize_preview_position")
    var depth: float = -preview_position.z + 1.80
    var height: float = 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5)
    var width: float = height * hud.size.x / hud.size.y
    if not is_equal_approx(backdrop_quad.size.x, width) or (
            not is_equal_approx(backdrop_quad.size.y, height)) or (
            absf(backdrop.position.x) > 0.001) or absf(backdrop.position.y) > 0.001:
        _fail("CUSTOMIZE backdrop must fill the whole portrait viewport")
        return
    var cells: Vector2 = backdrop_mat.get_shader_parameter("grid_cells")
    var spacing: float = 42.0
    if absf(cells.x - hud.size.x / spacing) > 0.01 or (
            absf(cells.y - hud.size.y / spacing) > 0.01):
        _fail("CUSTOMIZE grid spacing must be fixed in pixels on both axes")
        return
    for target in ["TRAINING", "DEPLOYMENT", "SYSTEM", "DATA ARCHIVE", "CUSTOMIZE"]:
        nexus.set("focused_target", target)
        nexus.call("_focus_arrived", target)
        await process_frame
        if not focus.visible or title.text != (
                "PART VIEW" if target == "CUSTOMIZE" else target):
            _fail("destination panel not visible: " + target)
            return
        if target == "CUSTOMIZE":
            if not right.visible:
                _fail("customization equipment panel disappeared")
                return
            for slot in equipment:
                var button: Button = equipment[slot]["panel"] as Button
                if button.position.y < 0.0 or (
                        button.position.y + button.size.y > right.size.y + 1.0):
                    _fail("name selector outside right customize window")
                    return
                if button.text.is_empty() or button.text.contains("SET"):
                    _fail("part selector must display the actual part name only")
                    return
                var expand: Button = equipment[slot]["expand"] as Button
                if expand.position.x < button.size.x * 0.60 or (
                        expand.position.x + expand.size.x > button.size.x) or (
                        expand.position.y < 0.0) or (
                        expand.position.y + expand.size.y > button.size.y):
                    _fail("thumbnail expand button overflows the equipment name row")
                    return
            var head_expand: Button = equipment["head"]["expand"] as Button
            nexus.call("_tap_equipment_control", head_expand.get_global_rect().get_center())
            var opened: Control = nexus.get("customize_part_picker") as Control
            if opened == null or not opened.visible or (
                    (nexus.get("customize_part_grid") as GridContainer).columns != 3):
                _fail("tapping the head-row thumbnail expander must open 3-column picker")
                return
            nexus.call("_close_customization_part_picker")
            var picker: Control = nexus.get("customize_part_picker") as Control
            var part_preview: Control = nexus.get("customize_single_part_preview") as Control
            if picker == null or part_preview == null:
                _fail("NEXUS missing the scrolling picker or left 3D part")
                return
        elif right.visible:
            _fail("customize panel leaked into " + target)
            return
    var slots: Array = nexus.get("system_slot_rows")
    if slots.size() != 3:
        _fail("save slot count changed")
        return
    var active_index: int = int(nexus.get("system_selected_slot")) - 1
    var selected: Panel = slots[active_index]["panel"]
    if selected.get_theme_stylebox("panel") != LaboTypeface.card_style("selected"):
        _fail("selected system save must show LABO active card")
        return
    var tabs: Array = nexus.get("archive_record_tabs")
    if tabs.size() != 4 or (
            (tabs[0]["panel"] as Panel).get_theme_stylebox("panel") !=
            LaboTypeface.terminal_segment_style("selected")):
        _fail("data archive tabs are not shared LABO segments")
        return
    var start: Panel = nexus.get("action_panel") as Panel
    if start == null or start.get_theme_stylebox("panel") == null:
        _fail("training launch action was removed")
        return
    print("NEXUS_LABO_VISUAL_RUNTIME_PASS")
    quit(0)
