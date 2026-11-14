extends RefCounted
## Pose-based self-contact for a falling Bittaran HEAD on a planted limb.
## Use separate actual mesh AABBs, never the artificially doubled camera
## lock volume or the giant full-leg union (which includes empty space).
const LEG_IDS: Array[String] = ["leg_fl", "leg_fr", "leg_rl", "leg_rr"]
const CONTACT_CLEARANCE_METERS: float = 0.025
const MIN_HORIZONTAL_OVERLAP_METERS: float = 0.065
const MIN_SUPPORT_TOP_WORLD_Y: float = 0.18
const APPROACH_EPSILON_METERS: float = 0.09
const MIN_SUPPORT_HEAD_HEIGHT_FRACTION: float = 0.08
# A visible leg can start inside the nose's union-AABB near its neck.
# A genuine falling contact crosses the surface in small physics steps;
# never snap the entire robot UP toward a shoulder already deep inside it.
const MAX_NEW_CONTACT_PENETRATION_METERS: float = 1.20

## Return the highest eligible real leg surface directly under HEAD's
## articulated front (not its neck and not its enormous BODY AABB).
## The surface must cross the nose's Y span: tall hip faces above the head
## are not floors, and toes on Y=0 are not unintended supports.
static func find_contact(head_nose: AABB, leg_boxes: Dictionary,
        former_leg: String = "",
        previous_nose: AABB = AABB()) -> Dictionary:
    var hit: Dictionary = {
        "leg_id": "", "penetration": 0.0, "surface_y": -INF
    }
    if not head_nose.has_volume():
        return hit
    for id in LEG_IDS:
        if not leg_boxes.has(id):
            continue
        var meshes: Array = leg_boxes[id]
        for raw_box in meshes:
            var surface: AABB = raw_box
            if not surface.has_volume():
                continue
            var overlap_x: float = minf(head_nose.end.x, surface.end.x) \
                - maxf(head_nose.position.x, surface.position.x)
            var overlap_z: float = minf(head_nose.end.z, surface.end.z) \
                - maxf(head_nose.position.z, surface.position.z)
            if overlap_x < MIN_HORIZONTAL_OVERLAP_METERS \
                    or overlap_z < MIN_HORIZONTAL_OVERLAP_METERS:
                continue
            var top_y: float = surface.end.y
            # A 0.17s heavy fall can cross the entire thickness of a thin
            # arm mesh between physics ticks. Use the previous nose bottom
            # to catch TOP-surface crossings even if the new nose is already
            # entirely below the limb (discrete AABBs would miss the hit).
            var crossed_from_above: bool = previous_nose.has_volume() \
                and previous_nose.position.y >= top_y - 0.065 \
                and head_nose.position.y < top_y + CONTACT_CLEARANCE_METERS
            if top_y < MIN_SUPPORT_TOP_WORLD_Y:
                continue
            if top_y >= head_nose.end.y - head_nose.size.y * (
                    MIN_SUPPORT_HEAD_HEIGHT_FRACTION) \
                    and not crossed_from_above and id != former_leg:
                continue
            var clearance: float = CONTACT_CLEARANCE_METERS
            var penetration: float = top_y + clearance - head_nose.position.y
            if penetration > MAX_NEW_CONTACT_PENETRATION_METERS \
                    and not crossed_from_above and id != former_leg:
                # A deep mesh union overlap was already present before
                # the fall; do not mistake it for a new support contact.
                continue
            # An already-supported head may be just above the limb; retain
            # support ownership until the head separates, then release it.
            var tolerance: float = (APPROACH_EPSILON_METERS
                if id == former_leg else CONTACT_CLEARANCE_METERS)
            if penetration < -tolerance:
                continue
            # First touch or limited tunneling while the head descends.
            # A leg higher than the nose's top was rejected above, so this
            # never treats a shoulder far ABOVE the head as support.
            if top_y > float(hit["surface_y"]):
                hit = {"leg_id": id,
                    "penetration": maxf(0.0, penetration),
                    "surface_y": top_y}
    return hit
