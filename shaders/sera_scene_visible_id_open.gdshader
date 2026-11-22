shader_type spatial;
// Depth-resolved visible ID for shared all-scene outline compositing.
// R/B encode 12-bit unique index; G encodes actor/facility/clutter/GRID.
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 encoded_id = vec3(0.015873, 0.125, 0.0);
void fragment() {
    ALBEDO = encoded_id;
}
