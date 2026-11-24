shader_type spatial;
// The *same* visible-ID outline algorithm as Bittaran is shared by BASE,
// NEXUS architecture/full-body, CRATE, part previews and ordinary combat.
// Only the numeric, per-element width profile differs.
render_mode unshaded, fog_disabled, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;
#include "res://shaders/sera_visible_mesh_id_outline_core.gdshaderinc"

void vertex() {
    // Exactly the established Bittaran clip-space fullscreen quad.
    POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

// BASE-only overlay. Role 2 is visible facility geometry, not a bounding
// shape; mesh IDs within one role are intentionally ignored for selection.
uniform bool facility_selection_enabled = false;
uniform vec4 facility_selection_color : source_color = vec4(1.0);
uniform float facility_selection_width = 4.5;

float facility_selection_coverage(vec2 uv, float black_alpha) {
    int role = sera_role_of(sera_sample_visible_id(uv));
    bool inside = role == 2;
    // Do not paint on foreground props, CRATE or protected emissive cores.
    // Outside pixels can only receive the line in the existing ink halo.
    if (!inside && (role != 0 || black_alpha < 0.001)) {
        return 0.0;
    }
    // Center the 4.5 display-pixel stroke on the actual visible boundary.
    float half_width = facility_selection_width * 0.5;
    int radius = sera_search_radius(half_width + 0.5);
    float nearest = half_width + 1.0;
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            if (dx == 0 && dy == 0) { continue; }
            vec2 offset = vec2(float(dx), float(dy));
            float distance_px = length(offset * output_px_per_id_pixel);
            if (distance_px >= nearest) { continue; }
            int other = sera_role_of(sera_sample_visible_id(
                uv + offset * mesh_id_texel));
            // Protected emission is not a hole in the facility surface.
            if (other == 7) { continue; }
            if ((other == 2) != inside) {
                nearest = distance_px;
            }
        }
    }
    return clamp(half_width + 1.0 - nearest, 0.0, 1.0);
}

void fragment() {
    float alpha = sera_visible_id_ink_alpha(SCREEN_UV);
    float selection = 0.0;
    if (facility_selection_enabled) {
        selection = facility_selection_coverage(SCREEN_UV, alpha) *
            facility_selection_color.a;
    }
    // Composite the colored stroke over existing black ink in the same
    // draw; keep ordinary seams, scene profiles and foreground VFX intact.
    float combined = selection + alpha * (1.0 - selection);
    if (combined < 0.001) {
        discard;
    }
    ALBEDO = (facility_selection_color.rgb * selection +
        ink_color.rgb * alpha * (1.0 - selection)) / combined;
    ALPHA = combined;
}
