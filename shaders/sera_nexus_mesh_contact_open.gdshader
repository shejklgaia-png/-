shader_type spatial;
// NEXUS full-body SERA: two-sided ID for open authored armor meshes.
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec3 contact_id = vec3(0.125, 0.125, 0.125);
void fragment() {
    ALBEDO = contact_id;
}
