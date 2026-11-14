extends SceneTree
## v351: Bittaran's common two-ray geometry is horizontal at SERA's Y.
## Boss root height, animation bob and falling HEAD must never pitch the rays.
const EPS: float = 0.0001

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V351_BITTARAN_HORIZONTAL_LOCK_FAIL: " + reason)
    quit(1)

func _assert_horizontal(segments: PackedVector3Array, origin: Vector3,
        destination: Vector3) -> bool:
    if segments.size() != 4:
        _fail("two lock beams must have four endpoints")
        return false
    for point in segments:
        if absf(point.y - origin.y) > EPS:
            _fail("lock line followed enemy Y instead of SERA's Y: " + str(point))
            return false
    var left: Vector3 = segments[1] - segments[0]
    var right: Vector3 = segments[3] - segments[2]
    if left.length_squared() <= EPS or right.length_squared() <= EPS:
        _fail("zero-length lock line")
        return false
    if left.normalized().distance_to(right.normalized()) > EPS:
        _fail("lock beams are not parallel")
        return false
    if absf((segments[2] - segments[0]).length() - 0.5) > EPS or absf(
            (segments[3] - segments[1]).length() - 0.5) > EPS:
        _fail("0.50m parallel-ray spacing changed")
        return false
    var center_start: Vector3 = (segments[0] + segments[2]) * 0.5
    var center_end: Vector3 = (segments[1] + segments[3]) * 0.5
    if center_start.distance_to(origin) > EPS or absf(
            center_end.x - destination.x) > EPS or absf(
            center_end.z - destination.z) > EPS:
        _fail("target horizontal X/Z or SERA origin changed")
        return false
    return true

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("battle scene not loadable")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var parts: Node3D = battle.get("target_parts")
    if parts == null or not bool(parts.get("installed")):
        _fail("Bittaran parts not installed")
        return
    var sera := Vector3(4.2, 1.53, -12.0)
    var boss := Vector3(-3.4, 7.8, 2.0)
    var horizontal: PackedVector3Array = parts.call(
        "get_actor_parallel_lock_segments", sera, boss)
    if not _assert_horizontal(horizontal, sera, boss):
        return
    for changed_y in [-20.0, -5.0, 0.0, 1.53, 12.0, 55.0]:
        var moved := Vector3(boss.x, changed_y, boss.z)
        var next: PackedVector3Array = parts.call(
            "get_actor_parallel_lock_segments", sera, moved)
        if not _assert_horizontal(next, sera, moved):
            return
        for index in range(4):
            if (next[index] as Vector3).distance_to(horizontal[index]) > EPS:
                _fail("Bittaran body vertical motion pitched/shifted lock beams")
                return
    var higher_sera := sera + Vector3.UP * 1.17
    var higher: PackedVector3Array = parts.call(
        "get_actor_parallel_lock_segments", higher_sera, boss)
    if not _assert_horizontal(higher, higher_sera, boss):
        return
    if absf(higher[0].y - (sera.y + 1.17)) > EPS:
        _fail("line height not sourced from SERA")
        return

    # Training room still uses the *inherited* SERA->BODY sloped lines.
    var generic: Node3D = load("res://scripts/target_parts.gd").new()
    var original: PackedVector3Array = generic.call(
        "get_actor_parallel_lock_segments", sera, boss)
    if absf(original[1].y - boss.y) > EPS or absf(
            original[3].y - boss.y) > EPS:
        _fail("shared training-room lock geometry unexpectedly modified")
        return
    generic.free()

    # The debug beam renderer in main.gd invokes the SAME virtual method on
    # target_parts. Check that both actual visual meshes stay horizontal, too.
    var beam_root: Node3D = battle.get("lock_line_root")
    var beams: Array = battle.get("lock_line_meshes")
    if beam_root == null or beams.size() != 2:
        _fail("shared lock-ray visualizer not available")
        return
    battle.set("lock_lines_visible", true)
    battle.set("camera_player_render_position", sera)
    battle.set("camera_target_render_position", boss)
    battle.call("_update_lock_line_visuals")
    for side in range(2):
        var mesh: MeshInstance3D = beams[side]
        var midpoint: Vector3 = (horizontal[side * 2] + horizontal[side * 2 + 1]) * 0.5
        if mesh.global_position.distance_to(midpoint) > EPS:
            _fail("visual line does not match collision line " + str(side))
            return
        var beam_direction: Vector3 = mesh.global_basis.y.normalized()
        if absf(beam_direction.y) > EPS:
            _fail("visible lock line slopes while selection line is horizontal")
            return
    print("GODOT_V351_BITTARAN_HORIZONTAL_LOCK_PASS: 2 level lines from SERA "
        + "Y, 0.5m separation, unchanged by Bittaran vertical motion, "
        + "visual/debug same as selection, training-room untouched")
    quit(0)
