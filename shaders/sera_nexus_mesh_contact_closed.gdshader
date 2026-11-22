shader_type spatial;
// NEXUS full-body SERA: depth-resolved RGB ID for solid closed armor.
// Match the IRIS culling convention; do not draw rear or hidden surfaces.
render_mode unshaded, cull_front, depth_draw_opaque;
uniform vec3 contact_id = vec3(0.125, 0.125, 0.125);
void fragment() {
    ALBEDO = contact_id;
}
