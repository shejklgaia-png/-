extends SceneTree
## BASE <> GRID UI shell with selectable 8x8 cells, visual-only 11 nodes
## and back/forward camera flow. Does not perform resource simulation.
const Board = preload("res://scripts/sera_base_power_board.gd")
const Ui = preload("res://scripts/sera_base_grid_ui.gd")

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("SERA_GRID_PRESENTATION_FAIL: " + message)
    quit(1)


func _run() -> void:
    var source: PackedScene = load("res://scenes/base_exploration.tscn")
    if source == null:
        _fail("BASE scene missing")
        return
    var hub: Node3D = source.instantiate() as Node3D
    root.add_child(hub)
    for i in range(6):
        await process_frame
    var cam: Camera3D = hub.get_node_or_null("BaseOverheadCamera") as Camera3D
    var shell: Control = hub.get_node_or_null(
        "BaseHUDLayer/BaseHUD/BaseGridPresentation") as Control
    var back: Button = hub.get_node_or_null(
        "BaseHUDLayer/BaseHUD/PowerBoardBack") as Button
    var facilities: Node3D = hub.get_node_or_null(
        "BaseFacilities") as Node3D
    if cam == null or shell == null or back == null or facilities == null:
        _fail("BASE UI/camera/facility nodes missing")
        return
    var base_plate: Control = shell.get_node_or_null(
        "ModePlateBASE") as Control
    var grid_plate: Control = shell.get_node_or_null(
        "ModePlateGRID") as Control
    var tray: Panel = shell.get_node_or_null(
        "GridModuleTray") as Panel
    var rail: Control = shell.get_node_or_null(
        "GridOperationRail") as Control
    if base_plate == null or grid_plate == null or tray == null or rail == null:
        _fail("cut plates / bottom tray / right icons missing")
        return
    if base_plate.size.y < 74.0 or base_plate.size.x < 220.0 or (
            base_plate.position.x < 0.0):
        _fail("large BASE cut header not initially visible")
        return
    if tray.visible or rail.visible:
        _fail("placement palette leaks into BASE world")
        return
    if (shell.get_node("GridModuleTray/NodeListScroll/NodeRow") as Node
            ).get_child_count() != 11:
        _fail("eleven known G/H/K/P/C/D/R/X/Y/T/O placeholders absent")
        return
    for mode in ["PLACE", "MOVE", "ROTATE"]:
        if rail.get_node_or_null("Operation_" + mode) == null:
            _fail("missing unboxed operation switch " + mode)
            return
    var original_position: Vector3 = cam.position
    var original_rotation: Vector3 = cam.rotation
    var original_size: float = cam.size
    facilities.call("open_facility", "GENERATOR")
    if not bool(hub.get("power_view_active")) or not bool(shell.get("grid_open")):
        _fail("GENERATOR did not animate BASE plate to GRID")
        return
    if not back.visible or bool(shell.get("editing")):
        _fail("GRID overview must have Back but not node palette")
        return

    var travel: Tween = hub.get("power_camera_tween") as Tween
    if travel != null:
        travel.kill()
    cam.position = original_position + (
        Board.board_focus() - Vector3(0, 0, -2.2))
    cam.size = float(hub.call("_power_view_ortho_size"))
    hub.set("power_transition_busy", false)
    var middle: Vector2 = cam.unproject_position(
        Board.BOARD_CENTER + Vector3(0.0, 0.46, 0.0))
    var chosen: Vector2i = hub.call("_grid_cell_from_pixel", middle)
    if chosen != Vector2i(4, 4) and chosen != Vector2i(3, 3):
        _fail("cannot screen-pick visible 8x8 board cell: " + str(chosen))
        return
    hub.call("_grid_touch", middle)
    if not bool(hub.get("grid_placement_active")) or not (
            bool(shell.get("editing"))):
        _fail("cell tap did not enter top-down placement")
        return
    if not tray.visible or not rail.visible:
        _fail("palette and right-side transparent tools did not appear")
        return
    var selection: MeshInstance3D = hub.get_node_or_null(
        "PowerPuzzleZone/SelectedGridCellPreview") as MeshInstance3D
    if selection == null or not selection.visible:
        _fail("picked cell lacks preview-only highlight")
        return
    var overlay_tween: Tween = hub.get("power_camera_tween") as Tween
    if overlay_tween != null:
        overlay_tween.kill()
    cam.position = Board.board_focus() + Vector3(0, 34, 0.01)
    cam.rotation = Vector3(-PI * 0.5, 0, 0)
    cam.size = float(hub.call("_grid_edit_ortho_size"))
    hub.set("power_transition_busy", false)
    if absf(cam.rotation.x + PI * 0.5) > 0.001:
        _fail("editing view is not straight down")
        return
    var picked_top: Vector2i = hub.call("_grid_cell_from_pixel",
        cam.unproject_position(Board.BOARD_CENTER +
            Vector3(1.28, 0.46, 1.28)))
    if picked_top.x < 0 or picked_top.y < 0:
        _fail("orthographic top-down board cannot pick cells")
        return
    shell.call("_choose_node", "K")
    shell.call("_choose_operation", "ROTATE")
    if str(shell.get("selected_code")) != "K" or str(
            shell.get("selected_operation")) != "ROTATE":
        _fail("visual-only node/mode selection not responsive")
        return
    if not shell.call("is_interface_hit", tray.position + Vector2(35, 35)):
        _fail("tray clicks would mistakenly reach the physical grid")
        return
    hub.call("_power_back_pressed")
    if bool(hub.get("grid_placement_active")) or bool(shell.get("editing")):
        _fail("first Back should leave placement for GRID overview")
        return
    if not bool(hub.get("power_view_active")):
        _fail("first Back incorrectly left GRID entirely")
        return
    hub.call("_power_back_pressed")
    if bool(hub.get("power_view_active")) or bool(shell.get("grid_open")):
        _fail("second Back should restore BASE")
        return
    if not back.visible and cam.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("camera projection changed when returning to BASE")
        return
    var last_tween: Tween = hub.get("power_camera_tween") as Tween
    if last_tween != null:
        last_tween.kill()
    cam.position = original_position
    cam.rotation = original_rotation
    cam.size = original_size
    hub.call("_power_camera_return_finished")
    print("SERA_GRID_PRESENTATION_RUNTIME_PASS: plates, modes, top-down, 11 modules, two-stage Back")
    quit(0)
