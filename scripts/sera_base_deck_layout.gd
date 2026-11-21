extends RefCounted
## Single-source rectangular partition for all outdoor BASE steel flooring.
## Dedicated site plates are installed FIRST; fillers never cut across them.
## A 1.5m half-cell lattice allows 6cm seams with no overlapping surfaces.
const GAP: float = 0.06

static func facility_sites(nexus_origin: Vector3, specs: Array) -> Array[Dictionary]:
    # Physical sizes represent visible equipment, not just the collider.
    # Every pad reserves generous empty walking/maintenance area around it.
    var sites: Array[Dictionary] = [{
        "id": "NEXUS",
        "at": Vector2(nexus_origin.x, nexus_origin.z),
        "minimum": Vector2(10.5, 10.5),
        "physical": Vector2(7.0, 7.6),
    }]
    for spec in specs:
        var key: String = str(spec["id"])
        var at: Vector3 = spec["at"]
        var size: Vector3 = spec["size"]
        var minimum := Vector2(maxf(size.x + 3.0, 5.8),
            maxf(size.z + 3.0, 5.8))
        var physical := Vector2(size.x, size.z)
        if key == "LABO":
            minimum = Vector2(7.0, 7.0)
            physical = Vector2(4.2, 5.0)
        sites.append({
            "id": key,
            "at": Vector2(at.x, at.z),
            "minimum": minimum,
            "physical": physical,
        })
    return sites

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
        ix: float, iz: float, wide: float, long: float, seed: int,
        site_id: String = "") -> void:
    # ix/iz/width are measured in 3m base cells; 0.5 enables 1.5m joins.
    var center := Vector2(
        (ix + wide * 0.5 - float(radius) - 0.5) * step,
        (iz + long * 0.5 - float(radius) - 0.5) * step)
    var full_size := Vector2(wide * step, long * step)
    output.append({
        "center": center,
        "size": full_size - Vector2(GAP, GAP),
        "cells": Rect2(Vector2(ix, iz), Vector2(wide, long)),
        "tint": 5 if not site_id.is_empty() else posmod(
            seed * 7 + roundi(ix * 2.0) * 11 + roundi(iz * 2.0) * 17, 6),
        "style": seed,
        "site": site_id,
    })

static func generate(radius: int, step: float,
        sites: Array[Dictionary] = []) -> Array[Dictionary]:
    var output: Array[Dictionary] = []
    if radius < 1 or step <= GAP:
        return output
    var side: int = (radius * 2 + 1) * 2
    var cell_step: float = step * 0.5
    var start: float = -(float(radius) + 0.5) * step
    var site_occupancy := PackedByteArray()
    site_occupancy.resize(side * side)

    # Every station is ONE large atomic rectangle. Reserve it before any
    # smaller panels are packed; thus no secondary seam can pass under it.
    for site in sites:
        var at: Vector2 = site["at"]
        var minimum: Vector2 = site["minimum"]
        var x0: int = clampi(floori(
            (at.x - minimum.x * 0.5 - start) / cell_step), 0, side)
        var x1: int = clampi(ceili(
            (at.x + minimum.x * 0.5 - start) / cell_step), 0, side)
        var z0: int = clampi(floori(
            (at.y - minimum.y * 0.5 - start) / cell_step), 0, side)
        var z1: int = clampi(ceili(
            (at.y + minimum.y * 0.5 - start) / cell_step), 0, side)
        if x1 <= x0 or z1 <= z0:
            push_error("Invalid single-panel station reservation: " +
                str(site["id"]))
            return []
        for z in range(z0, z1):
            for x in range(x0, x1):
                var addr: int = z * side + x
                if site_occupancy[addr] != 0:
                    push_error("Facility site slabs overlap: " + str(site["id"]))
                    return []
                site_occupancy[addr] = 1
        _panel(output, radius, step,
            float(x0) * 0.5, float(z0) * 0.5,
            float(x1 - x0) * 0.5, float(z1 - z0) * 0.5,
            sites.size(), str(site["id"]))

    var occupied: PackedByteArray = site_occupancy.duplicate()
    # Outside facility pads, keep the lively salvage-yard mix of small,
    # medium, long and wide sheets. Logical cells are 1.5m square.
    for iz in range(side):
        for ix in range(side):
            if occupied[iz * side + ix] != 0:
                continue
            var seed: int = posmod((ix + 17) * 92821 +
                (iz + 31) * 68917 + (ix + 3) * (iz + 5) * 137, 100)
            var preferred := Vector2i(2, 2)
            if seed < 13:
                preferred = Vector2i(4, 4)
            elif seed < 30:
                preferred = Vector2i(4, 2)
            elif seed < 47:
                preferred = Vector2i(2, 4)
            elif seed < 55:
                preferred = Vector2i(6, 2)
            elif seed < 63:
                preferred = Vector2i(2, 6)
            elif seed < 86:
                preferred = Vector2i(2, 2)
            elif seed < 92:
                preferred = Vector2i(2, 1)
            elif seed < 97:
                preferred = Vector2i(1, 2)
            else:
                preferred = Vector2i(1, 1)
            var candidates: Array[Vector2i] = [
                preferred, Vector2i(4, 2), Vector2i(2, 4),
                Vector2i(2, 2), Vector2i(2, 1),
                Vector2i(1, 2), Vector2i(1, 1),
            ]
            var chosen := Vector2i(1, 1)
            for candidate in candidates:
                if _can_occupy(occupied, side, ix, iz,
                        candidate.x, candidate.y):
                    chosen = candidate
                    break
            for z in range(iz, iz + chosen.y):
                for x in range(ix, ix + chosen.x):
                    occupied[z * side + x] = 1
            _panel(output, radius, step, float(ix) * 0.5,
                float(iz) * 0.5, float(chosen.x) * 0.5,
                float(chosen.y) * 0.5, seed)
    return output
