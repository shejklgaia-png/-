extends RefCounted
## Stateless lock selection/projection extracted from the v317 main.gd.
## State/attack suppression and render-frame sample ownership stay in main.
## BODY remains the empty-string ID; target_parts supplies authored hitboxes.

static func select_auto_part(parts: Node3D,
        actor_origin: Vector3, target_center: Vector3) -> String:
    # AUTO uses the SAME pair-line actor-origin test, with no debounce.
    return str(parts.call(
        "select_actor_parallel_lines_part", actor_origin, target_center))


static func target_facing_direction(player_world: Vector3,
        boss_center: Vector3, parts: Node3D, part_id: String) -> Vector3:
    # Broken part retained during a combo still uses its authored aim point.
    var point: Vector3 = boss_center
    if parts != null and not part_id.is_empty():
        point = parts.call("get_part_aim_world", part_id)
    # Yaw only: never tilt SERA's collision root to a head or low leg.
    return Vector3(
        point.x - player_world.x, 0.0,
        point.z - player_world.z)


static func manual_screen_neighbor(direction: int, current_id: String,
        viewport_size: Vector2, view: Camera3D, parts: Node3D,
        boss_body: AABB) -> String:
    # The public main.gd wrapper guards mode, health and combo retention.
    var reference_x: float = viewport_size.x * 0.5
    if not current_id.is_empty() and bool(parts.call(
            "is_targetable", current_id)):
        var current_aim: Vector3 = parts.call(
            "get_part_aim_world", current_id)
        if not view.is_position_behind(current_aim):
            reference_x = view.unproject_position(current_aim).x

    # v291: screen-X sort with edge wrap; do not reject a part because
    # another body's hitbox crosses the camera ray. Offscreen X is valid.
    var candidates: Array = parts.call("get_visible_part_ids",
        view.global_position, boss_body)
    var forward_id: String = ""
    var forward_gap: float = INF
    var wrapped_id: String = ""
    var wrapped_x: float = INF if direction > 0 else -INF
    for raw_candidate in candidates:
        var id: String = str(raw_candidate)
        if id == current_id:
            continue
        var aim: Vector3 = parts.call("get_part_aim_world", id)
        if view.is_position_behind(aim):
            continue
        var projected: Vector2 = view.unproject_position(aim)
        var gap: float = (projected.x - reference_x) * float(direction)
        if gap > 3.0 and gap < forward_gap:
            forward_gap = gap
            forward_id = id
        if (direction > 0 and projected.x < wrapped_x) or (
                direction < 0 and projected.x > wrapped_x):
            wrapped_x = projected.x
            wrapped_id = id
    return forward_id if not forward_id.is_empty() else wrapped_id


static func reticle_projection(view: Camera3D, target_world: Vector3,
        viewport_size: Vector2) -> Dictionary:
    # The marker uses the frozen interpolated render target supplied by main.
    # Camera focus remains on the stable boss center. A valid offscreen lock
    # must show an amber EDGE marker; only the indicator is clamped.
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 \
            or view.is_position_behind(target_world):
        return {"position": Vector2.ZERO, "visible": false,
                "offscreen": false}
    var screen_position: Vector2 = view.unproject_position(target_world)
    var is_offscreen: bool = (
        screen_position.x < 0.0 or screen_position.x > viewport_size.x
        or screen_position.y < 0.0 or screen_position.y > viewport_size.y)
    var edge_margin: float = 42.0
    var safe_screen: Vector2 = Vector2(
        clampf(screen_position.x, edge_margin,
            maxf(edge_margin, viewport_size.x - edge_margin)),
        clampf(screen_position.y, edge_margin,
            maxf(edge_margin, viewport_size.y - edge_margin)))
    return {"position": safe_screen, "visible": true,
            "offscreen": is_offscreen}
