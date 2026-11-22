shader_type spatial;
// Diagnostic only. Color the same depth-independent mask writer used in
// production; an orange pixel alone does not prove the stencil write succeeded.
render_mode unshaded, cull_disabled, depth_draw_never,
    depth_test_disabled, fog_disabled;
stencil_mode write, compare_always, 17;
void fragment() {
    ALBEDO = vec3(0.96, 0.52, 0.12);
    ALPHA = 0.42;
}
