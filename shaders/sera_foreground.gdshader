shader_type spatial;
// RENDER_POLICY: CHARACTER_FOREGROUND; depth_test=off
// v34: transparent overlay pass on Sera's original meshes; after sword FX.
// Keep the full authored palette color and UV (no billboard/silhouette proxy).
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D sera_palette : source_color, filter_nearest, repeat_disable;
uniform vec3 set_tint = vec3(1.0, 1.0, 1.0);
void fragment() {
    vec4 color = texture(sera_palette, UV);
    ALBEDO = color.rgb * set_tint;
    // Alpha use forces the transparent draw queue; 0.999 is visually solid.
    ALPHA = 0.999;
}
