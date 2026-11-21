extends RefCounted
## Temporary, user-driven BASE art-layout explorer.
## Generator output contains the entire reproducible state, not just a seed.
const Clutter = preload("res://scripts/sera_base_clutter.gd")
const Deck = preload("res://scripts/sera_base_deck_layout.gd")
const FORMAT: String = "SERA_BASE_PROP_LAYOUT_V1"
const KEYS = [
    "NEXUS", "LABO", "SCRAP_COLLECTOR", "SMELTER",
    "RECYCLER", "GENERATOR", "STORAGE", "BUILD_TERMINAL",
]
const SCRAP_COUNT: int = 16


static func site_slab(key: String, nexus_origin: Vector3,
        specs: Array) -> Rect2:
    var sites: Array[Dictionary] = Deck.facility_sites(nexus_origin, specs)
    var panels: Array[Dictionary] = Deck.generate(42, 3.0, sites)
    for panel in panels:
        if str(panel["site"]) != key:
            continue
        var origin: Vector2 = Vector2(nexus_origin.x, nexus_origin.z)
        for site in sites:
            if str(site["id"]) == key:
                origin = site["at"]
                break
        var center: Vector2 = panel["center"]
        var size: Vector2 = panel["size"]
        return Rect2(center - origin - size * 0.5, size)
    return Rect2()


static func prop_envelope(part: Dictionary) -> Rect2:
    var footprint: Vector2 = Clutter.bounds_for(str(part["kind"])) * (
        float(part["scale"]))
    var anchor: Vector2 = part["at"]
    var square := Rect2(anchor - footprint * 0.5, footprint)
    var rad: float = deg_to_rad(float(part.get("yaw_deg", 0.0)))
    var c: float = absf(cos(rad))
    var s: float = absf(sin(rad))
    var rotated := Vector2(footprint.x * c + footprint.y * s,
        footprint.x * s + footprint.y * c)
    return square.merge(Rect2(anchor - rotated * 0.5, rotated))


static func _generate_site(key: String, slab: Rect2,
        rng: RandomNumberGenerator) -> Array[Dictionary]:
    var approved: Array[Dictionary] = Clutter.default_props_for(key)
    if approved.is_empty() or slab.size.x < 1.0:
        return []
    # Reject complete arrangements that do not fit, rather than overlap,
    # shrink or delete an object. Large cargo goes first to avoid starvation.
    var order: Array[int] = []
    for i in range(approved.size()):
        order.append(i)
    order.sort_custom(func(a: int, b: int) -> bool:
        var size_a: Vector2 = Clutter.bounds_for(str(approved[a]["kind"])) * (
            float(approved[a]["scale"]))
        var size_b: Vector2 = Clutter.bounds_for(str(approved[b]["kind"])) * (
            float(approved[b]["scale"]))
        return size_a.x * size_a.y > size_b.x * size_b.y)
    var usable: Rect2 = slab.grow(-0.18)
    var prohibited: Rect2 = Clutter._clear_zone(key).grow(0.09)
    for trial in range(9):
        var output: Array[Dictionary] = approved.duplicate(true)
        var occupied: Array[Rect2] = []
        var valid: bool = true
        for index in order:
            var part: Dictionary = output[index]
            if Clutter.is_loose_pile(str(part["kind"])):
                part["stack"] = rng.randi_range(1, Clutter.PILE_MAX_COUNT)
                part["pattern"] = rng.randi_range(0, Clutter.PILE_PATTERN_COUNT - 1)
            var accepted: bool = false
            for n in range(160):
                # Some samples stay close to familiar prop clusters, others
                # explore the whole available perimeter of the single slab.
                var anchor: Vector2
                if n < 22:
                    var original: Vector2 = approved[index]["at"]
                    anchor = original + Vector2(
                        rng.randf_range(-1.55, 1.55),
                        rng.randf_range(-1.40, 1.40))
                else:
                    anchor = Vector2(
                        rng.randf_range(usable.position.x, usable.end.x),
                        rng.randf_range(usable.position.y, usable.end.y))
                part["at"] = anchor
                part["yaw_deg"] = snappedf(rng.randf_range(15.0, 65.0), 0.1)
                var rect: Rect2 = prop_envelope(part)
                if not usable.encloses(rect) or rect.intersects(prohibited):
                    continue
                var blocked: bool = false
                for placed in occupied:
                    if rect.grow(0.035).intersects(placed):
                        blocked = true
                        break
                if blocked:
                    continue
                output[index] = part
                occupied.append(rect)
                accepted = true
                break
            if not accepted:
                valid = false
                break
        if valid:
            return output
    return []


static func _generate_scrap(sites: Array[Dictionary],
        rng: RandomNumberGenerator) -> Array[Dictionary]:
    var scraps: Array[Dictionary] = []
    for index in range(SCRAP_COUNT):
        var placed: bool = false
        for trial in range(280):
            var point := Vector2(rng.randf_range(-21.0, 22.0),
                rng.randf_range(-20.0, 21.0))
            var occupied := Rect2(point - Vector2.ONE * 0.95,
                Vector2.ONE * 1.90)
            # Protect the CRATE's service lane as well as every entire pad.
            if occupied.intersects(Rect2(-4.4, -7.7, 8.8, 13.7)):
                continue
            var nearest: float = INF
            var obstructs: bool = false
            for site in sites:
                var at: Vector2 = site["at"]
                var half_size: Vector2 = site["minimum"] * 0.5
                var pad: Rect2 = Rect2(at - half_size, half_size * 2.0)
                if occupied.intersects(pad.grow(0.85)):
                    obstructs = true
                    break
                nearest = minf(nearest, point.distance_to(at))
            if obstructs:
                continue
            for other in scraps:
                var earlier := Vector2(float(other["x"]), float(other["z"]))
                if point.distance_to(earlier) < 2.55:
                    obstructs = true
                    break
            if obstructs:
                continue
            var zoom: float = 1.26
            if nearest < 6.0:
                zoom = 1.12
            elif nearest < 9.0:
                zoom = 1.20
            scraps.append({
                "index": index, "x": point.x, "z": point.y,
                "yaw_deg": snappedf(rng.randf_range(-28.0, 28.0), 0.1),
                "scale": zoom, "profile": index % 5,
                "stack": rng.randi_range(1, Clutter.PILE_MAX_COUNT),
                "pattern": rng.randi_range(0, Clutter.PILE_PATTERN_COUNT - 1),
            })
            placed = true
            break
        if not placed:
            return []
    return scraps


static func generate(nexus_origin: Vector3, specs: Array,
        rng: RandomNumberGenerator) -> Dictionary:
    var sites: Array[Dictionary] = Deck.facility_sites(nexus_origin, specs)
    var panels: Array[Dictionary] = Deck.generate(42, 3.0, sites)
    var slabs: Dictionary = {}
    for panel in panels:
        var key: String = str(panel["site"])
        if key.is_empty():
            continue
        for site in sites:
            if str(site["id"]) == key:
                var panel_center: Vector2 = panel["center"]
                var size: Vector2 = panel["size"]
                var at: Vector2 = site["at"]
                slabs[key] = Rect2(panel_center - at - size * 0.5, size)
                break
    var layouts: Dictionary = {}
    for key in KEYS:
        if not slabs.has(key):
            return {}
        var result: Array[Dictionary] = _generate_site(key, slabs[key], rng)
        if result.is_empty():
            return {}
        layouts[key] = result
    var scrap: Array[Dictionary] = _generate_scrap(sites, rng)
    if scrap.size() != SCRAP_COUNT:
        return {}
    return {"sites": layouts, "scrap": scrap, "seed": rng.seed}


static func export_text(layouts: Dictionary, scrap: Array[Dictionary],
        rerolls: int, seed: int) -> String:
    var site_rows: Array[Dictionary] = []
    for key in KEYS:
        var items: Array[Dictionary] = []
        var data: Array[Dictionary] = layouts[key]
        for i in range(data.size()):
            var source: Dictionary = data[i]
            var position: Vector2 = source["at"]
            items.append({
                "index": i, "kind": str(source["kind"]),
                "x": position.x, "z": position.y,
                "scale": float(source["scale"]),
                "yaw_deg": float(source.get("yaw_deg", 0.0)),
                "stack": int(source["stack"]),
                "pattern": int(source.get("pattern", -1)),
                "accent": bool(source.get("accent", false)),
            })
        site_rows.append({"site": key, "items": items})
    return JSON.stringify({
        "format": FORMAT, "version": 1,
        "status": "PREVIEW_NOT_COMMITTED",
        "seed": seed, "reroll": rerolls,
        "sites": site_rows, "scrap": scrap,
    }, "  ", false)
