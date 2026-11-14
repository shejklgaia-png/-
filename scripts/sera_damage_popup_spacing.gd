extends RefCounted
## v344: choose stable, modest 2D offsets for simultaneous world-projected
## damage numbers. This is presentation-only: no combat state or HP logic.
## Each number is placed once at birth; never reflow during camera movement.

const APPROX_TEXT_WIDTH: float = 64.0
const APPROX_TEXT_HEIGHT: float = 40.0
const OFFSET_CHOICES = [
    Vector2.ZERO,
    Vector2(44.0, -18.0), Vector2(-44.0, -18.0),
    Vector2(44.0, 18.0), Vector2(-44.0, 18.0),
    Vector2(0.0, -32.0), Vector2(0.0, 32.0),
    Vector2(64.0, -8.0), Vector2(-64.0, -8.0),
    Vector2(64.0, 24.0), Vector2(-64.0, 24.0),
    Vector2(0.0, -53.0), Vector2(0.0, 53.0)
]


static func overlap_ratio(delta: Vector2) -> float:
    var width: float = maxf(0.0,
        APPROX_TEXT_WIDTH - absf(delta.x)) / APPROX_TEXT_WIDTH
    var height: float = maxf(0.0,
        APPROX_TEXT_HEIGHT - absf(delta.y)) / APPROX_TEXT_HEIGHT
    return width * height


static func choose_offset(anchor: Vector2,
        occupied: Array[Vector2]) -> Vector2:
    if occupied.is_empty():
        return Vector2.ZERO
    var choice: Vector2 = Vector2.ZERO
    var best_score: float = INF
    for candidate in OFFSET_CHOICES:
        var candidate_position: Vector2 = anchor + candidate
        var overlap: float = 0.0
        for old_position in occupied:
            overlap += overlap_ratio(candidate_position - old_position)
        # Visibly separate close numbers while allowing small overlap.
        # Bias modestly toward sideways motion so upward-hit animation
        # remains readable and does not blend into an older number.
        var cost: float = (
            overlap * 120.0
            + absf(candidate.x) * 0.12
            + absf(candidate.y) * 0.5)
        if cost < best_score:
            best_score = cost
            choice = candidate
    return choice
