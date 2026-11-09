extends RefCounted
## v178 moving training boss dummy. Motion is ground-plane only; all existing
## melee, camera, hitbox and warning systems continue to follow the target node.
const MOVE_SPEED: float = 1.55
const NEAR_DISTANCE: float = 3.4
const FAR_DISTANCE: float = 7.3
const TETHER_RADIUS: float = 10.0
const MIN_BOX_CLEARANCE: float = 0.55
const START_POINT: Vector2 = Vector2(0.0, -8.0)
var phase: float = 0.0

func advance(delta: float, current: Vector3, player_pos: Vector3,
        frozen: bool) -> Vector3:
    if frozen or delta <= 0.0:
        return current
    phase += delta
    var to_player: Vector3 = player_pos - current
    to_player.y = 0.0
    var distance: float = to_player.length()
    var forward: Vector3 = to_player.normalized() if distance > 0.00001 else Vector3.FORWARD
    var lateral_side: float = 1.0 if fposmod(phase, 7.2) < 3.6 else -1.0
    var tangent: Vector3 = Vector3(-forward.z, 0.0, forward.x) * lateral_side
    var direction: Vector3 = tangent
    if distance < NEAR_DISTANCE:
        # Retreat when approached, but do not abruptly teleport out of range.
        direction -= forward * 1.4
    elif distance > FAR_DISTANCE:
        direction += forward * 0.85
    var tether: Vector2 = Vector2(current.x, current.z) - START_POINT
    if tether.length() > TETHER_RADIUS * 0.78:
        direction += Vector3(-tether.x, 0.0, -tether.y).normalized() * 2.0
    if direction.length_squared() < 0.00001:
        return current
    var wanted: Vector3 = current + direction.normalized() * MOVE_SPEED * delta
    var flat: Vector2 = Vector2(wanted.x, wanted.z) - START_POINT
    if flat.length() > TETHER_RADIUS:
        flat = flat.limit_length(TETHER_RADIUS)
        wanted.x = START_POINT.x + flat.x
        wanted.z = START_POINT.y + flat.y
    # The cube's half-extents are 1m, player's capsule radius 0.4m.
    # Reject any movement that newly pushes the cube through the player.
    var dx: float = maxf(absf(player_pos.x - wanted.x) - 1.0, 0.0)
    var dz: float = maxf(absf(player_pos.z - wanted.z) - 1.0, 0.0)
    if Vector2(dx, dz).length() < MIN_BOX_CLEARANCE:
        var current_dx: float = maxf(absf(player_pos.x - current.x) - 1.0, 0.0)
        var current_dz: float = maxf(absf(player_pos.z - current.z) - 1.0, 0.0)
        if Vector2(current_dx, current_dz).length() >= MIN_BOX_CLEARANCE:
            return current
    wanted.y = current.y
    return wanted
