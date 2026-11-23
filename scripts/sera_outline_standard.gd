extends RefCounted
## Single authoritative SERA-wide outline measurements, in final display px.
## Keep shader fallback defaults aligned with these values. The common
## rendering compositor explicitly binds the values at material creation.
const ACTOR_INSIDE_PX: float = 0.0
const ACTOR_OUTSIDE_PX: float = 6.0
const ACTOR_SEAM_PX: float = 1.0

const BASE_FACILITY_INSIDE_PX: float = 0.0
const BASE_FACILITY_OUTSIDE_PX: float = 4.0
const BASE_FACILITY_SEAM_PX: float = 3.0
const BASE_FACILITY_CONVEX_PX: float = 2.0

const BASE_CLUTTER_INSIDE_PX: float = 0.0
const BASE_CLUTTER_OUTSIDE_PX: float = 3.0
const BASE_CLUTTER_SEAM_PX: float = 1.0
const BASE_CLUTTER_CONVEX_PX: float = 1.0

const NEXUS_INSIDE_PX: float = 0.0
const NEXUS_OUTSIDE_PX: float = 3.0
const NEXUS_SEAM_PX: float = 2.0
const NEXUS_CONVEX_PX: float = 1.0

static func apply_id_widths(material: ShaderMaterial) -> void:
    if material == null:
        return
    # No shader fork: character profiles, CRATE, live single-part views,
    # facility/clutter/GRID, and the NEXUS architecture all use these values.
    var widths: Dictionary = {
        "main_inside_px": ACTOR_INSIDE_PX,
        "main_outside_px": ACTOR_OUTSIDE_PX,
        "main_seam_px": ACTOR_SEAM_PX,
        "bittaran_inside_px": ACTOR_INSIDE_PX,
        "bittaran_outside_px": ACTOR_OUTSIDE_PX,
        "bittaran_seam_px": ACTOR_SEAM_PX,
        "nexus_actor_inside_px": ACTOR_INSIDE_PX,
        "nexus_actor_outside_px": ACTOR_OUTSIDE_PX,
        "nexus_actor_seam_px": ACTOR_SEAM_PX,
        "training_inside_px": ACTOR_INSIDE_PX,
        "training_outside_px": ACTOR_OUTSIDE_PX,
        "training_seam_px": ACTOR_SEAM_PX,
        "crate_inside_px": ACTOR_INSIDE_PX,
        "crate_outside_px": ACTOR_OUTSIDE_PX,
        "crate_seam_px": ACTOR_SEAM_PX,
        "part_inside_px": ACTOR_INSIDE_PX,
        "part_outside_px": ACTOR_OUTSIDE_PX,
        "part_seam_px": ACTOR_SEAM_PX,
        "facility_inside_px": BASE_FACILITY_INSIDE_PX,
        "facility_outside_px": BASE_FACILITY_OUTSIDE_PX,
        "facility_seam_px": BASE_FACILITY_SEAM_PX,
        "clutter_inside_px": BASE_CLUTTER_INSIDE_PX,
        "clutter_outside_px": BASE_CLUTTER_OUTSIDE_PX,
        "clutter_seam_px": BASE_CLUTTER_SEAM_PX,
        "nexus_facility_outside_px": NEXUS_OUTSIDE_PX,
        "nexus_facility_seam_px": NEXUS_SEAM_PX
    }
    for key in widths.keys():
        material.set_shader_parameter(str(key), widths[key])
