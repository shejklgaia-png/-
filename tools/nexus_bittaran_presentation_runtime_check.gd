extends SceneTree
## Live model and UI regression: selected mesh overlay, scene-specific entry, HUD spacing.
const BOSS_HUD = preload("res://scripts/sera_clean_training_hud.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("NEXUS_BITTARAN_PRESENTATION_FAIL: " + message)
    quit(1)

func _run() -> void:
    var nexus: Node3D = load("res://scenes/command_nexus.tscn").instantiate()
    root.add_child(nexus)
    await process_frame
    await process_frame
    var rig: Node3D = nexus.get("sera_display_rig") as Node3D
    if rig == null or not bool(rig.get("loading_ok")):
        _fail("live NEXUS display rig failed to load")
        return
    nexus.set("focused_target", "CUSTOMIZE")
    nexus.set("customize_preview_active", true)
    nexus.call("_inspect_customization_part", "head")
    var head: Array = rig.call("get_equipment_visible_meshes", "head")
    var arms: Array = rig.call("get_equipment_visible_meshes", "arms")
    var selected_material: Material = nexus.get("customize_selection_material") as Material
    if head.is_empty() or arms.is_empty() or selected_material == null:
        _fail("no selected head/arm geometry or emission material")
        return
    for raw_piece in head:
        var piece: MeshInstance3D = raw_piece as MeshInstance3D
        if piece == null or not piece.visible or piece.material_overlay != selected_material:
            _fail("head must glow on the visible authored model")
            return
    for raw_piece in arms:
        if (raw_piece as MeshInstance3D).material_overlay == selected_material:
            _fail("nonselected arm must not glow")
            return
    # One clear blink cycle: fade-free OFF then ON, with no extra meshes.
    var rows: Dictionary = nexus.get("customize_equipment_rows") as Dictionary
    var head_button: Button = rows["head"]["panel"] as Button
    var arm_button: Button = rows["arms"]["panel"] as Button
    var head_style: StyleBoxFlat = head_button.get_theme_stylebox("normal") as StyleBoxFlat
    var arm_style: StyleBoxFlat = arm_button.get_theme_stylebox("normal") as StyleBoxFlat
    if head_style == null or arm_style == null or (
            head_style.bg_color.get_luminance() <= arm_style.bg_color.get_luminance()):
        _fail("inspected HEAD row must be brighter than the inactive ARMS row")
        return
    nexus.call("_update_customization_part_blink", 0.70)
    for raw_piece in head:
        if (raw_piece as MeshInstance3D).material_overlay != null:
            _fail("highlight should fully turn off during the blink gap")
            return
    nexus.call("_update_customization_part_blink", 0.31)
    for raw_piece in head:
        if (raw_piece as MeshInstance3D).material_overlay != selected_material:
            _fail("highlight should turn back on at the start of each cycle")
            return
    nexus.call("_inspect_customization_part", "arms")
    head_style = head_button.get_theme_stylebox("normal") as StyleBoxFlat
    arm_style = arm_button.get_theme_stylebox("normal") as StyleBoxFlat
    if arm_style.bg_color.get_luminance() <= head_style.bg_color.get_luminance():
        _fail("selected-row brightness did not follow the inspected ARMS slot")
        return
    for raw_piece in head:
        if (raw_piece as MeshInstance3D).material_overlay == selected_material:
            _fail("previous head overlay was not cleared")
            return
    for raw_piece in arms:
        if (raw_piece as MeshInstance3D).material_overlay != selected_material:
            _fail("selected arms must glow")
            return
    nexus.call("_restore_customization_preview")
    for raw_piece in arms:
        if (raw_piece as MeshInstance3D).material_overlay == selected_material:
            _fail("customize exit leaked selected material to overview")
            return
    nexus.queue_free()
    await process_frame

    var battle: Node3D = load("res://scenes/bittaran_battle.tscn").instantiate()
    root.add_child(battle)
    await process_frame
    var player: Node3D = battle.get("player") as Node3D
    var target: Node3D = battle.get("target") as Node3D
    var floor_mark: Node3D = battle.get("target_floor_mark") as Node3D
    var name_label: Label = battle.get("boss_name_label") as Label
    var victory_label: Label = battle.get("victory_label") as Label
    if player == null or target == null or floor_mark == null or (
            name_label == null or victory_label == null):
        _fail("Bittaran battle scene omitted player, boss or HUD label")
        return
    var starting_gap: float = player.global_position.distance_to(target.global_position)
    if absf(starting_gap - 12.0) > 0.3 or (
            absf(floor_mark.position.z - target.position.z) > 0.01):
        _fail("Bittaran entry separation / floor marker is not 12m")
        return
    var safe_top: float = BOSS_HUD.PART_ROW_TOP + 8.0 + 7.0 + 12.0
    if name_label.offset_top < safe_top or (
            victory_label.offset_top < name_label.offset_bottom + 8.0):
        _fail("boss name or victory title overlaps lock bar / other title")
        return
    target.position.z = -4.0
    battle.call("_reset_target_after_respawn")
    if absf(target.position.z + 12.0) > 0.01:
        _fail("battle respawn must restore the expanded start distance")
        return
    battle.queue_free()
    await process_frame
    print("NEXUS_BITTARAN_PRESENTATION_RUNTIME_PASS")
    quit(0)
