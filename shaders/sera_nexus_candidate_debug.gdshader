shader_type spatial;
// Diagnostics only: show the 3D surfaces selected for the contour pipeline.
// This pass deliberately has NO stencil operations.
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
void fragment() {
    ALBEDO = vec3(0.09, 0.90, 0.38);
    ALPHA = 0.48;
}
