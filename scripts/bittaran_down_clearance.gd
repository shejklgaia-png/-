extends RefCounted
## Bittaran-only, planar, deterministic clearance for a falling BODY.
## The arena floor is visual; never resolve a torso overlap by pushing SERA
## vertically through Y=0. Prefer an open nearest side, then skirt a shin.
const CLEARANCE: float = 0.08

static func _point_xz(point: Vector3) -> Vector2:
    return Vector2(point.x, point.z)

static func _box_xz(box: AABB, radius: float) -> Rect2:
    return Rect2(Vector2(box.position.x - radius, box.position.z - radius),
        Vector2(box.size.x + radius * 2.0, box.size.z + radius * 2.0))

static func _hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
    # Exact 2D slab intersection (unlike endpoint-only tests, this also
    # catches a thin foot that lies halfway along a movement sweep).
    var low: Vector2 = rect.position
    var high: Vector2 = rect.end
    var d: Vector2 = b - a
    var enter: float = 0.0
    var leave: float = 1.0
    for axis in range(2):
        var origin: float = a.x if axis == 0 else a.y
        var v: float = d.x if axis == 0 else d.y
        var mn: float = low.x if axis == 0 else low.y
        var mx: float = high.x if axis == 0 else high.y
        if absf(v) < 0.00001:
            if origin < mn or origin > mx:
                return false
        else:
            var t1: float = (mn - origin) / v
            var t2: float = (mx - origin) / v
            if t1 > t2:
                var tmp: float = t1
                t1 = t2
                t2 = tmp
            enter = maxf(enter, t1)
            leave = minf(leave, t2)
            if enter > leave:
                return false
    return true

static func _first_obstacle(from_pos: Vector2, destination: Vector2,
        feet: Array[AABB], radius: float) -> int:
    for i in range(feet.size()):
        if _hits_rect(from_pos, destination, _box_xz(feet[i], radius)):
            return i
    return -1

static func _escape_choices(position: Vector2, body: Rect2,
        forward: Vector2) -> Array[Vector2]:
    # Four shortest axis-aligned exits from the real BODY mesh footprint.
    # The tie-breaker is the boss's forward direction, never a random side.
    var distance: float = 0.05
    var result: Array[Vector2] = [
        Vector2(body.position.x - distance, position.y),
        Vector2(body.end.x + distance, position.y),
        Vector2(position.x, body.position.y - distance),
        Vector2(position.x, body.end.y + distance)
    ]
    result.sort_custom(func(a: Vector2, b: Vector2) -> bool:
        var ca: float = a.distance_to(position)
        var cb: float = b.distance_to(position)
        if absf(ca - cb) < 0.01:
            return (a - position).dot(forward) > (b - position).dot(forward)
        return ca < cb)
    return result

static func escape_waypoint(player_world: Vector3, body_box: AABB,
        foot_boxes: Array[AABB], actor_radius: float,
        boss_forward: Vector3) -> Dictionary:
    var margin: float = actor_radius + CLEARANCE
    var body: Rect2 = _box_xz(body_box, margin)
    var p: Vector2 = _point_xz(player_world)
    var inside: bool = body.has_point(p)
    var touching_foot: bool = false
    for foot in foot_boxes:
        if _box_xz(foot, margin).has_point(p):
            touching_foot = true
    if not inside and not touching_foot:
        return {"active": false, "waypoint": player_world, "foot_detour": false}
    var forward: Vector2 = Vector2(boss_forward.x, boss_forward.z).normalized()
    if forward.length_squared() < 0.001:
        forward = Vector2.UP

    # If already touching a foot, exit toward its NEAREST horizontal side.
    # Never choose a vertical collision response or push the player under it.
    if touching_foot:
        var best: Vector2 = p
        var best_cost: float = INF
        for foot in foot_boxes:
            var rect: Rect2 = _box_xz(foot, margin)
            if not rect.has_point(p):
                continue
            for v in [
                Vector2(rect.position.x - CLEARANCE, p.y),
                Vector2(rect.end.x + CLEARANCE, p.y),
                Vector2(p.x, rect.position.y - CLEARANCE),
                Vector2(p.x, rect.end.y + CLEARANCE)]:
                var cost: float = p.distance_to(v)
                if body.has_point(v):
                    cost += 1.0
                if cost < best_cost:
                    best = v
                    best_cost = cost
        return {"active": true, "waypoint": Vector3(best.x,
            player_world.y, best.y), "foot_detour": true}

    # Select an exit that does not intersect any enlarged shin collider.
    # If the nearest door is occupied by a leg, route around its side instead.
    var options: Array[Vector2] = _escape_choices(p, body, forward)
    for choice in options:
        if _first_obstacle(p, choice, foot_boxes, margin) == -1:
            return {"active": true, "waypoint": Vector3(choice.x,
                player_world.y, choice.y), "foot_detour": false}
    # All four exits blocked: take the nearest leg's horizontal flank.
    var first: int = _first_obstacle(p, options[0], foot_boxes, margin)
    if first >= 0:
        var obstacle: Rect2 = _box_xz(foot_boxes[first], margin)
        var flank: Array[Vector2] = [
            Vector2(obstacle.position.x - CLEARANCE, p.y),
            Vector2(obstacle.end.x + CLEARANCE, p.y),
            Vector2(p.x, obstacle.position.y - CLEARANCE),
            Vector2(p.x, obstacle.end.y + CLEARANCE)]
        flank.sort_custom(func(a: Vector2, b: Vector2) -> bool:
            return p.distance_to(a) < p.distance_to(b))
        return {"active": true, "waypoint": Vector3(flank[0].x,
            player_world.y, flank[0].y), "foot_detour": true}
    return {"active": true, "waypoint": Vector3(options[0].x,
        player_world.y, options[0].y), "foot_detour": false}

static func safe_advance(start: Vector3, wanted: Vector3,
        foot_boxes: Array[AABB], actor_radius: float) -> Vector3:
    var margin: float = actor_radius + CLEARANCE
    var a: Vector2 = _point_xz(start)
    var b: Vector2 = _point_xz(wanted)
    var obstacle: int = _first_obstacle(a, b, foot_boxes, margin)
    if obstacle < 0:
        return wanted
    var rect: Rect2 = _box_xz(foot_boxes[obstacle], margin)
    if rect.has_point(a):
        # Depenetration route supplied by escape_waypoint() may leave a foot.
        return wanted
    var motion: Vector2 = b - a
    if motion.length_squared() < 0.00001:
        return start
    var normal: Vector2 = Vector2(-motion.y, motion.x).normalized()
    var foot_mid: Vector2 = rect.get_center()
    var side: float = signf((a - foot_mid).dot(normal))
    if absf(side) < 0.01:
        side = 1.0
    var tangent: Vector2 = normal * side
    var candidate: Vector2 = a + tangent * motion.length()
    if _first_obstacle(a, candidate, foot_boxes, margin) >= 0:
        candidate = a - tangent * motion.length()
    if _first_obstacle(a, candidate, foot_boxes, margin) >= 0:
        return start
    return Vector3(candidate.x, wanted.y, candidate.y)
