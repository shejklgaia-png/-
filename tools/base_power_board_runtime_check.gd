extends SceneTree
## BASE power cable / remote 8x8 board physical navigation regression.
const Board = preload("res://scripts/sera_base_power_board.gd")
const Facilities = preload("res://scripts/base_facility_system.gd")
const SIDE: int = 8

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("SERA_BASE_POWER_BOARD_FAIL: " + message)
    quit(1)

func _run() -> void:
    var title: String = ""
    for item in Facilities.FACILITY_SPECS:
        if str(item["id"]) == "GENERATOR":
            title = str(item["name"])
            if item["at"] != Board.GENERATOR_ORIGIN:
                _fail("generator physical position changed")
                return
    if title != "電力制御施設":
        _fail("power controller not renamed")
        return
    if Board.GRID_SIDE != SIDE:
        _fail("Ver.0.9 board is not 8x8")
        return

    var source: PackedScene = load("res://scenes/base_exploration.tscn")
    if source == null:
        _fail("BASE scene missing")
        return
    var base: Node3D = source.instantiate() as Node3D
    root.add_child(base)
    for frame in range(5):
        await process_frame
    var zone: Node3D = base.get_node_or_null("PowerPuzzleZone") as Node3D
    var cable: Node3D = base.get_node_or_null(
        "PowerPuzzleZone/WindingPowerCable") as Node3D
    var grid: Node3D = base.get_node_or_null(
        "PowerPuzzleZone/PowerGrid8x8") as Node3D
    if zone == null or grid == null or cable == null:
        _fail("power world / cable / grid missing")
        return
    var outer: MeshInstance3D = cable.get_node_or_null(
        "PowerCableOuter") as MeshInstance3D
    var signal_line: MeshInstance3D = cable.get_node_or_null(
        "PowerCableSignalStripe") as MeshInstance3D
    if outer == null or signal_line == null or (
            not (outer.mesh is ArrayMesh)):
        _fail("winding cable not real 3D mesh")
        return
    if (outer.mesh as ArrayMesh).surface_get_array_len(0) < 300:
        _fail("cable has no actual curved 3D geometry")
        return
    var early: Vector3 = Board.cable_point(0.25)
    var middle: Vector3 = Board.cable_point(0.50)
    var later: Vector3 = Board.cable_point(0.75)
    if absf((middle - early).cross(later - early).y) < 0.04:
        _fail("cord is straight, expected physical winding")
        return
    for shade in range(2):
        var tiles: MultiMeshInstance3D = grid.get_node_or_null(
            "PowerTileShade%d" % shade) as MultiMeshInstance3D
        if tiles == null or tiles.multimesh.instance_count != 32:
            _fail("not all 64 grid cells are visible")
            return
    if grid.get_node_or_null("GridFoundation") == null or (
            grid.get_node_or_null("GridEdgeNorthSouth") == null):
        _fail("puzzle perimeter not physically built")
        return
    var facilities: Node3D = base.get_node_or_null(
        "BaseFacilities") as Node3D
    var lab: Node3D = base.get_node_or_null(
        "BaseFacilities/LABO") as Node3D
    if facilities == null or lab == null:
        _fail("original facilities missing")
        return
    var lab_position: Vector3 = lab.position
    var screen: Control = base.get_node_or_null(
        "BaseHUDLayer/BaseHUD") as Control
    var back: Button = base.get_node_or_null(
        "BaseHUDLayer/BaseHUD/PowerBoardBack") as Button
    var camera: Camera3D = base.get_node_or_null(
        "BaseOverheadCamera") as Camera3D
    if back == null or camera == null or screen == null:
        _fail("power back button or orthographic camera missing")
        return
    var original_position: Vector3 = camera.position
    var original_size: float = camera.size
    var original_projection: int = camera.projection
    facilities.call("open_facility", "GENERATOR")
    if not bool(base.get("power_view_active")) or not back.visible or (
            bool(facilities.call("is_menu_open"))):
        _fail("generator tap did not open physical power board")
        return
    if not base.get("power_camera_tween"):
        _fail("screen-right cable camera travel not started")
        return
    if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
        _fail("orthographic camera changed to perspective")
        return
    # Check actual projected corners, not just a nominal camera size.
    var phone_size: float = float(base.call(
        "_power_view_ortho_size", Vector2(428.0, 1000.0)))
    if phone_size < 43.0:
        _fail("narrow Android display would crop the 8x8 frame")
        return
    var ci_size: float = float(base.call("_power_view_ortho_size"))
    if ci_size <= Board.CAMERA_SIZE:
        _fail("framing did not adapt to portrait viewport")
        return
    camera.position = original_position + Board.board_focus() - Vector3(
        0.0, 0.0, -2.2)
    camera.size = ci_size
    for corner_x in [-5.95, 5.95]:
        for corner_z in [-5.95, 5.95]:
            var pixel: Vector2 = camera.unproject_position(
                Board.BOARD_CENTER + Vector3(corner_x, 0.60, corner_z))
            var viewport: Vector2 = get_viewport().get_visible_rect().size
            if pixel.x < 12.0 or pixel.x > viewport.x - 12.0:
                _fail("board border clipped in portrait")
                return
    camera.position = original_position
    camera.size = original_size
    base.call("_leave_power_board")
    if bool(base.get("power_view_active")) or back.visible:
        _fail("return button did not restore overview state")
        return
    if lab.position != lab_position or (
            camera.projection != original_projection):
        _fail("power view moved facility or changed camera mode")
        return
    if camera.position.distance_to(original_position) > 35.0 or (
            absf(camera.size - original_size) > 12.0):
        _fail("return tween leaves inconsistent camera")
        return
    print("SERA_BASE_POWER_BOARD_RUNTIME_PASS: generator tap, 8x8, cable, camera, back")
    quit(0)
