shader_type spatial;
// Expect MAGENTA outside the ref=29 cube, not its center.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
stencil_mode read, compare_not_equal, 29;
void fragment() {
    ALBEDO = vec3(1.0, 0.13, 0.87);
    ALPHA = 0.92;
}
