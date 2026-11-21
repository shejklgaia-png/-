extends RefCounted
## Shared deterministic 1–8-piece models for scrap and metal sheets.
## "stack" counts major pieces; secondary ribs, bolts, axles are decoration.
## Everything remains within the parent prop's conservative local footprint.
const MAX_PIECES: int = 8
const PATTERNS: int = 4
const FORMS: Array[String] = [
    "notched", "bent", "trapezoid", "ribbed", "short", "long",
]


static func rows_for(count: int, pattern: int) -> Array[int]:
    var amount: int = clampi(count, 1, MAX_PIECES)
    var style: int = posmod(pattern, PATTERNS)
    match amount:
        1:
            return [1]
        2:
            return [1, 1] if style == 3 else [2]
        3:
            return [2, 1]
        4:
            return [2, 2] if style % 2 == 1 else [3, 1]
        5:
            return [4, 1] if style % 2 == 1 else [3, 2]
        6:
            return [3, 2, 1] if style % 2 == 1 else [4, 2]
        7:
            return [5, 2] if style == 3 else [4, 2, 1]
        8:
            return [4, 3, 1] if style % 2 == 1 else [5, 2, 1]
    return [1]


static func model_for(count: int, pattern: int) -> Array[Dictionary]:
    var style: int = posmod(pattern, PATTERNS)
    var rows: Array[int] = rows_for(count, style)
    var pieces: Array[Dictionary] = []
    for tier in range(rows.size()):
        var n: int = rows[tier]
        for i in range(n):
            var center: float = (float(i) - float(n - 1) * 0.5)
            var step: float = (
                0.19 if n == 5 else 0.21 if n == 4 else
                0.24 if n == 3 else 0.35 if n == 2 else 0.0)
            var axis: Vector2 = Vector2.RIGHT if style % 2 == 0 else Vector2.DOWN
            # Broad, level base; tighter displaced middle; one sparse peak.
            var sideways: Vector2 = Vector2(-axis.y, axis.x)
            var along: float = center * step * (1.0 if tier == 0 else 0.72)
            var drift: float = float(posmod(i * 7 + style * 3 + tier, 5) - 2) * (
                0.027 if tier == 0 else 0.035)
            var offset: Vector2 = axis * along + sideways * drift
            if tier > 0:
                offset += Vector2(
                    float(posmod(style * 3 + tier, 5) - 2) * 0.025,
                    float(posmod(style + tier * 2, 5) - 2) * 0.022)
            var width: float = (
                0.71 if n == 1 else 0.41 if n == 2 else
                0.32 if n == 3 else 0.26 if n == 4 else 0.22)
            var depth: float = (
                0.58 if n <= 2 else 0.52 if n == 3 else
                0.43 if n == 4 else 0.39)
            # Real variation in length/shape, not merely palette or yaw.
            width *= 0.91 + float(posmod(style + i * 3 + tier, 5)) * 0.035
            depth *= 0.88 + float(posmod(i + style * 2, 4)) * 0.045
            var rotated_yaw: float = float(posmod(i * 11 + style * 13 +
                tier * 7, 17) - 8)
            var pitch: float = float(posmod(i * 5 + style * 3, 13) - 6)
            var roll: float = float(posmod(i * 7 + style + tier * 4, 13) - 6)
            if tier > 0:
                pitch *= 1.4
                roll *= 1.4
            pieces.append({
                "tier": tier,
                "position": offset,
                "height": 0.245 + float(tier) * 0.085 +
                    float(posmod(style + i, 3)) * 0.006,
                "size": Vector2(width, depth),
                "yaw_deg": rotated_yaw,
                "pitch_deg": pitch,
                "roll_deg": roll,
                "form": FORMS[posmod(i + style * 2 + tier * 3, FORMS.size())],
            })
    return pieces
