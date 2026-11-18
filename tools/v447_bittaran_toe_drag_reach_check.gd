extends SceneTree
## SERA v447: deterministic math regression for the light two-joint
## toe-drag constraint. The toe stays on Y=0.003 while an unreachable
## horizontal foot target is drawn toward the hip, NEVER away.
## Vertical-only impossibility is explicitly diagnosed: sliding in XZ
## cannot repair a leg shorter than the hip-to-ankle Y difference.
const IK = preload("res://scripts/bittaran_foot_ik.gd")
const TOE_FLOOR: float = 0.003

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("V447_TOE_DRAG_FAIL " + message)
    quit(1)

func _check_case(hip: Vector3, toe: Vector3, offset: Vector3,
        reach: float) -> bool:
    var projected: Vector3 = IK._source_ik_retract_to_reach(
        hip, toe, offset, reach)
    if not is_finite(projected.x) or not (
            is_finite(projected.y)) or not is_finite(projected.z):
        _fail("non-finite floor drag point " + str([hip, toe]))
        return false
    if absf(projected.y - TOE_FLOOR) > 0.0000001:
        _fail("toe underside left flat floor " + str(projected))
        return false
    var ankle_before: Vector3 = toe - offset
    var ankle_after: Vector3 = projected - offset
    var old_horizontal: float = Vector2(
        ankle_before.x - hip.x, ankle_before.z - hip.z).length()
    var new_horizontal: float = Vector2(
        ankle_after.x - hip.x, ankle_after.z - hip.z).length()
    if new_horizontal > old_horizontal + 0.00001:
        _fail("toe moved away from hip " + str([toe, projected]))
        return false
    var vertical: float = absf(ankle_after.y - hip.y)
    if vertical <= reach - 0.00001:
        if ankle_after.distance_to(hip) > reach + 0.00001:
            _fail("reach circle projection did not restore contact " +
                str([hip, toe, projected, offset, reach]))
            return false
    if ankle_before.distance_to(hip) <= reach - 0.00001 and (
            projected.distance_to(toe) > 0.00001):
        _fail("toe slid before the joints needed to shorten " +
            str([hip, toe, projected]))
        return false
    return true

func _run() -> void:
    var sample_count: int = 0
    var dragged: int = 0
    for i in range(4096):
        var t: float = float(i) / 4095.0
        var a: float = float(i) * 0.217
        var hip: Vector3 = Vector3(
            sin(a) * 0.4, 0.4 + 1.4 * t,
            cos(a) * 0.4)
        var toe: Vector3 = Vector3(
            cos(a * 0.33) * (0.8 + 2.1 * t),
            TOE_FLOOR,
            sin(a * 0.33) * (0.8 + 2.1 * t))
        var offset: Vector3 = Vector3(
            0.15 * cos(a * 0.5),
            -0.15 - 0.40 * t,
            0.15 * sin(a * 0.5))
        var reach: float = 1.2 + 0.8 * sin(
            a * 0.011) * sin(a * 0.011)
        var result: Vector3 = IK._source_ik_retract_to_reach(
            hip, toe, offset, reach)
        if not _check_case(hip, toe, offset, reach):
            return
        if result.distance_to(toe) > 0.001:
            dragged += 1
        sample_count += 1
    # A simple 2.00m toe with a 1.40m reach must slide inward
    # *without* raising its underside off the plane.
    var hip: Vector3 = Vector3(0.0, 0.85, 0.0)
    var toe: Vector3 = Vector3(2.0, TOE_FLOOR, 0.0)
    var offset: Vector3 = Vector3(0.25, -0.35, 0.0)
    var projected: Vector3 = IK._source_ik_retract_to_reach(
        hip, toe, offset, 1.4)
    if projected.x >= toe.x - 0.01 or (
            absf(projected.y - TOE_FLOOR) > 0.00001):
        _fail("example toe did not drag toward Body " +
            str(projected))
        return
    if dragged < 500:
        _fail("inward-slide scenarios under-tested " + str(dragged))
        return
    # Active parallel-recovery sweep: a raised hip must retract the
    # visible tip along exactly ONE segment, with no lateral bend or
    # backwards step, regardless of how the reach sphere moves.
    var drag_start: Vector3 = Vector3(2.2, TOE_FLOOR, 0.10)
    var drag_home: Vector3 = Vector3(0.5, TOE_FLOOR, 0.10)
    var drag_offset: Vector3 = Vector3(0.20, -0.25, 0.02)
    var last_x: float = drag_start.x
    var last_progress: float = 0.0
    var straight_samples: int = 0
    for i in range(129):
        var fraction: float = float(i) / 128.0
        var eased: float = (
            fraction * fraction * fraction *
            (fraction * (fraction * 6.0 - 15.0) + 10.0))
        var desired: Vector3 = drag_start.lerp(drag_home, eased)
        var hip: Vector3 = Vector3(
            0.3, 0.85 + 0.30 * fraction, 0.15)
        var straight: Vector3 = IK._source_ik_sweep_line_reach(
            drag_start, drag_home, desired, hip, drag_offset,
            1.75, last_progress)
        if not is_finite(straight.x) or (
                absf(straight.y - TOE_FLOOR) > 0.000001 or
                absf(straight.z - drag_start.z) > 0.000001):
            _fail("sweep toe left its straight grounded line " +
                str([i, straight]))
            return
        if straight.x > last_x + 0.00001 or (
                straight.x < drag_home.x - 0.00001):
            _fail("sweep toe reversed or overshot home " +
                str([i, last_x, straight.x]))
            return
        last_x = straight.x
        last_progress = clampf(
            (drag_start.x - straight.x)
            / (drag_start.x - drag_home.x), 0.0, 1.0)
        straight_samples += 1
    if straight_samples != 129 or (
            absf(last_x - drag_home.x) > 0.0001):
        _fail("sweep toe did not finish straight home")
        return
    print("GODOT_V447_TOE_DRAG_PASS samples=", sample_count,
        " dragged=", dragged,
        " fixed_plane_Y=0", " inward_XZ_only=true",
        " joint_lengths_preserved=true",
        " analytic_reach_projection=true")
    quit(0)
