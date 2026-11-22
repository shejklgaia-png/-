shader_type spatial;
// HEAD D only: keep two-sided visibility for the two open shell parts.
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform float mesh_id : hint_range(0.0, 1.0) = 0.125;
void fragment() {
    ALBEDO = vec3(mesh_id, 0.0, 0.0);
}
