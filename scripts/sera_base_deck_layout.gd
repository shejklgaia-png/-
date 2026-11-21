extends RefCounted
## Deterministic rectangular partition of the full outdoor BASE floor.
## Rectangles occupy the entire logical deck once, with deliberate 6cm joints.
## No runtime random calls: editor/Android and decorative outlines use the same layout.
const GAP: float = 0.06

static func _can_occupy(occupied: PackedByteArray, side: int,
        ix: int, iz: int, wide: int, long: int) -> bool:
    if ix < 0 or iz < 0 or ix + wide > side or iz + long > side:
        return false
    for z in range(iz, iz + long):
        for x in range(ix, ix + wide):
            if occupied[z * side + x] != 0:
                return false
    return true

static func _panel(output: Array[Dictionary], radius: int, step: float,
        ix: float, iz: float, wide: float, long: float, seed: int) -> void:
    var center := Vector2(
        (ix + wide * 0.5 - float(radius) - 0.5) * step,
        (iz + long * 0.5 - float(radius) - 0.5) * step)
    var full_size := Vector2(wide * step, long * step)
    # Keep the underlying ground visible as the only seam between panels.
    output.append({
        "center": center,
        "size": full_size - Vector2(GAP, GAP),
        "cells": Rect2(Vector2(ix, iz), Vector2(wide, long)),
        "tint": posmod(seed * 7 + roundi(ix * 2.0) * 11 +
            roundi(iz * 2.0) * 17, 6),
        "style": seed,
    })

static func generate(radius: int, step: float) -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    if radius < 1 or step <= GAP:
        return output
    var side: int = radius * 2 + 1
    var occupied := PackedByteArray()
    occupied.resize(side * side)
    # Mixed spans: 1.5m to 9m on a 3m logical cell lattice.
    # Greedy row-first packing deliberately breaks the regular square grid.
    for iz in range(side):
        for ix in range(side):
            if occupied[iz * side + ix] != 0:
                continue
            var seed: int = posmod((ix + 17) * 92821 +
                (iz + 31) * 68917 + (ix + 3) * (iz + 5) * 137, 100)
            var wide: int = 1
            var long: int = 1
            if seed < 11:
                wide = 2
                long = 2
            elif seed < 30:
                wide = 2
            elif seed < 49:
                long = 2
            elif seed < 56:
                wide = 3
            elif seed < 63:
                long = 3
            if not _can_occupy(occupied, side, ix, iz, wide, long):
                # Try a secondary span before using a single fallback cell.
                if seed % 2 == 0 and _can_occupy(occupied, side, ix, iz, 2, 1):
                    wide = 2
                    long = 1
                elif _can_occupy(occupied, side, ix, iz, 1, 2):
                    wide = 1
                    long = 2
                else:
                    wide = 1
                    long = 1
            for z in range(iz, iz + long):
                for x in range(ix, ix + wide):
                    occupied[z * side + x] = 1
            # Small repair inserts on selected 3m squares (not fake overlays).
            if wide == 1 and long == 1 and seed > 84:
                if seed % 11 == 0:
                    for dz in range(2):
                        for dx in range(2):
                            _panel(output, radius, step,
                                float(ix) + float(dx) * 0.5,
                                float(iz) + float(dz) * 0.5,
                                0.5, 0.5, seed + dx + dz * 7)
                elif seed % 2 == 0:
                    _panel(output, radius, step, float(ix), float(iz),
                        0.5, 1.0, seed)
                    _panel(output, radius, step, float(ix) + 0.5,
                        float(iz), 0.5, 1.0, seed + 1)
                else:
                    _panel(output, radius, step, float(ix), float(iz),
                        1.0, 0.5, seed)
                    _panel(output, radius, step, float(ix),
                        float(iz) + 0.5, 1.0, 0.5, seed + 1)
            else:
                _panel(output, radius, step, float(ix), float(iz),
                    float(wide), float(long), seed)
    return output
