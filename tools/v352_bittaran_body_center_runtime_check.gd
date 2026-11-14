extends SceneTree
## v352: Bittaran's horizontal lock target is the BODY mesh AABB center,
## not the target root. Height always comes from SERA, even while down.
const EPS: float = 0.0002
const SIX_SHINS_AND_HEAD: int = 6

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("V352_BITTARAN_BODY_CENTER_FAIL: " + reason)
    quit(1)

func _assert_body_center(pts: PackedVector3Array, sera: Vector3,
        body: Vector3) -> bool:
    if pts.size() != 4:
        _fail("two parallel lines require four endpoints")
        return false
    for p in pts:
        if absf(p.y - sera.y) > EPS:
            _fail("line Y must equal SERA Y even for high BODY")
            return false
    var start: Vector3 = (pts[0] + pts[2]) * 0.5
    var finish: Vector3 = (pts[1] + pts[3]) * 0.5
    var expected: Vector3 = Vector3(body.x, sera.y, body.z)
    if start.distance_to(sera) > EPS:
        _fail("line start did not stay at SERA horizontal origin")
        return false
    if finish.distance_to(expected) > EPS:
        _fail("line ends at boss root or unrelated target: "
            + str(finish) + " expected " + str(expected))
        return false
    if absf((pts[2] - pts[0]).length() - 0.5) > EPS or absf(
            (pts[3] - pts[1]).length() - 0.5) > EPS:
        _fail("parallel lock line separation is not 0.5m")
        return false
    var a: Vector3 = (pts[1] - pts[0]).normalized()
    var b: Vector3 = (pts[3] - pts[2]).normalized()
    if a.distance_to(b) > EPS or absf(a.y) > EPS:
        _fail("two lock lines sloped or diverged")
        return false
    return true

func _assert_visual(battle: Node3D, pts: PackedVector3Array,
        sera: Vector3, decoy_root: Vector3) -> bool:
    battle.set("lock_lines_visible", true)
    battle.set("camera_player_render_position", sera)
    battle.set("camera_target_render_position", decoy_root)
    battle.call("_update_lock_line_visuals")
    var beams: Array = battle.get("lock_line_meshes")
    if beams.size() != 2:
        _fail("common visualizer must show two lock beams")
        return false
    for index in range(2):
        var mesh: MeshInstance3D = beams[index]
        var expected_mid: Vector3 = (pts[index * 2]
            + pts[index * 2 + 1]) * 0.5
        if mesh.global_position.distance_to(expected_mid) > EPS:
            _fail("visible ray disagrees with actual BODY-centered selection")
            return false
        if absf(mesh.global_basis.y.normalized().y) > EPS:
            _fail("visible ray became non-horizontal")
            return false
    return true

func _run() -> void:
    var scene: PackedScene = load("res://scenes/bittaran_battle.tscn")
    if scene == null:
        _fail("battle scene load")
        return
    var battle: Node3D = scene.instantiate()
    root.add_child(battle)
    var parts: Node3D = battle.get("target_parts")
    var target: Node3D = battle.get("target")
    var rig: Node3D = battle.get("bittaran_rig")
    var ik: RefCounted = battle.get("bittaran_foot_ik")
    if parts == null or target == null or rig == null or ik == null:
        _fail("Bittaran model, body, or lock manager missing")
        return
    var sera := Vector3(4.9, 1.53, -13.0)
    var decoy_root := Vector3(-120.0, 55.0, 160.0)
    var body_mesh: Vector3 = (
        parts.call("get_body_hit_aabb") as AABB).get_center()
    if body_mesh.distance_to(target.global_position) < 0.05:
        _fail("test cannot distinguish mesh center from root pivot")
        return
    var first: PackedVector3Array = parts.call(
        "get_actor_parallel_lock_segments", sera, decoy_root)
    if not _assert_body_center(first, sera, body_mesh):
        return
    if not _assert_visual(battle, first, sera, decoy_root):
        return
    # Root arg is passed by original game as target.global_position and
    # visualizer as camera_target_render_position, but neither should change
    # the actual BODY-centered scan.
    for bogus in [
        Vector3(40.0, -20.0, 70.0), Vector3(-25.0, 150.0, -70.0),
        Vector3(0.0, 0.0, 0.0), target.global_position]:
        var candidate: PackedVector3Array = parts.call(
            "get_actor_parallel_lock_segments", sera, bogus)
        if not _assert_body_center(candidate, sera, body_mesh):
            return
        for i in range(4):
            if candidate[i].distance_to(first[i]) > EPS:
                _fail("lock endpoint changed with fake root coordinate")
                return
    var moved_horizontal: bool = false
    for frame in range(65):
        var dt: float = 1.0 / 60.0
        target.position += Vector3(0.019, 0.04, 0.015)
        target.rotation.y += 0.003
        rig.call("set_motion", "Turn", dt)
        ik.call("advance_ik", dt, "Turn")
        parts.call("sync_bittaran_parts")
        var actual: Vector3 = (parts.call("get_body_hit_aabb") as AABB).get_center()
        var new_lines: PackedVector3Array = parts.call(
            "get_actor_parallel_lock_segments", sera, target.global_position)
        if not _assert_body_center(new_lines, sera, actual):
            _fail("during frame " + str(frame))
            return
        moved_horizontal = moved_horizontal or Vector2(
            actual.x - body_mesh.x, actual.z - body_mesh.z).length() > 0.2
    if not moved_horizontal:
        _fail("moving/rotating actual body did not update line direction")
        return
    var body_before_break: Vector3 = (
        parts.call("get_body_hit_aabb") as AABB).get_center()
    var head_y: float = (
        parts.call("get_part_aim_world", "head") as Vector3).y
    ik.call("start_leg_break_slide", "leg_fl", head_y)
    for step in range(75):
        var dt: float = 1.0 / 60.0
        rig.call("set_motion", "Idle", dt)
        ik.call("advance_ik", dt, "Idle")
        parts.call("sync_bittaran_parts")
        var fallen_body: Vector3 = (
            parts.call("get_body_hit_aabb") as AABB).get_center()
        var pts: PackedVector3Array = parts.call(
            "get_actor_parallel_lock_segments", sera, target.global_position)
        if not _assert_body_center(pts, sera, fallen_body):
            _fail("during leg-break fall " + str(step))
            return
    var body_after_break: Vector3 = (
        parts.call("get_body_hit_aabb") as AABB).get_center()
    if body_after_break.distance_to(body_before_break) > 0.2:
        _fail("break reaction did not recover original BODY position")
        return
    # Original generic training room target geometry retains its own root
    # and Y behavior and has not inherited this Bittaran-specific override.
    var generic: Node3D = load("res://scripts/target_parts.gd").new()
    var generic_pts: PackedVector3Array = generic.call(
        "get_actor_parallel_lock_segments", sera, decoy_root)
    if absf(generic_pts[1].y - decoy_root.y) > EPS or absf(
            generic_pts[3].y - decoy_root.y) > EPS:
        _fail("shared training room rays modified")
        return
    generic.free()
    print("GODOT_V352_BITTARAN_BODY_CENTER_PASS: BODY mesh XZ endpoint, "
        + "SERA Y horizontal, 0.5m spacing, moving/pitched target, "
        + "debug lines, training room unchanged")
    quit(0)
