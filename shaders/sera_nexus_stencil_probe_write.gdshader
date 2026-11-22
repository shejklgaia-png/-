shader_type spatial;
// Calibration cube: isolated stencil write with ref 29, not SERA's ref 17.
// Depth is deliberately ignored so this stage measures stencil behavior.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
stencil_mode write, compare_always, 29;
void fragment() {
    ALBEDO = vec3(1.0, 0.48, 0.06);
    ALPHA = 0.18;
}
