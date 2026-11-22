shader_type spatial;
// Shared SERA opaque ID/depth pass. 12-bit IDs (RGB444), background = zero.
// Viewport MSAA and filtering are disabled; this never changes source geometry.
render_mode unshaded, cull_front, depth_draw_opaque;
uniform vec3 mesh_id_rgb = vec3(0.0625, 0.0, 0.0);
void fragment() {
    ALBEDO = mesh_id_rgb;
}
