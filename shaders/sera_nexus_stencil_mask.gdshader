shader_type spatial;
// NEXUS silhouette union: all visible opaque equipment shares stencil 17.
// Do not apply the scene's opaque depth test to the union mask. Otherwise a
// previously drawn source face can reject the stencil write at the same
// pixel, leaving gaps in the whole-body mask in GL Compatibility.
// The invisible transparent writer runs before the hull (priority -22).
render_mode unshaded, cull_disabled, depth_draw_never,
    depth_test_disabled, fog_disabled;
stencil_mode write, compare_always, 17;

void fragment() {
    // Writing ALPHA explicitly routes the pass through transparency.
    // Use a tiny alpha rather than discard so stencil fragments survive.
    ALBEDO = vec3(0.0);
    ALPHA = 0.00001;
}
