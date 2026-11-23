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

void fragment() {
    float alpha = sera_visible_id_ink_alpha(SCREEN_UV);
    if (alpha < 0.001) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = alpha;
}
