extends RefCounted
## v344: stable, compact spacing for world-projected damage numbers.
## Do not separate hits into far-off labels: mild overlap is intentional.
## A chosen offset is stored with each popup for its whole lifetime.

const APPROX_TEXT_WIDTH: float = 64.0
const APPROX_TEXT_HEIGHT: float = 40.0
const MAX_ACCEPTABLE_OVERLAP: float = 0.29
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
    # Already-readable slight overlap is fine: do not create jitter or
    # make distant hits jump away from their actual impact projection.
    var crowded: bool = false
    for old_position in occupied:
        if overlap_ratio(anchor - old_position) > MAX_ACCEPTABLE_OVERLAP:
            crowded = true
            break
    if not crowded:
        return Vector2.ZERO

    var best_offset: Vector2 = Vector2.ZERO
    var best_score: float = INF
    for candidate in OFFSET_CHOICES:
        if candidate == Vector2.ZERO:
            continue
        var next_position: Vector2 = anchor + candidate
        var worst_overlap: float = 0.0
        var sum_overlap: float = 0.0
        for old_position in occupied:
            var overlap: float = overlap_ratio(next_position - old_position)
            worst_overlap = maxf(worst_overlap, overlap)
            sum_overlap += overlap
        # First compact choice with only mild overlap wins. Do not prefer
        # a far-away zero-overlap position to a close readable one.
        if worst_overlap <= MAX_ACCEPTABLE_OVERLAP:
            return candidate
        var score: float = sum_overlap * 100.0 + candidate.length() * 0.2
        if score < best_score:
            best_score = score
            best_offset = candidate
    # On a saturated 6-hit cluster choose the least crowded available
    # offset; an occasional extra overlap is better than a huge jump.
    return best_offset
