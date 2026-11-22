shader_type spatial;
// Expect GREEN within the orange calibration cube when ref=29 was written.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
stencil_mode read, compare_equal, 29;
void fragment() {
    ALBEDO = vec3(0.11, 0.98, 0.31);
    ALPHA = 0.92;
}
