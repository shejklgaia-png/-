shader_type spatial;
// v34: transparent overlay pass on Sera's original meshes; after sword FX.
// Keep the full authored palette color and UV (no billboard/silhouette proxy).
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;
uniform sampler2D sera_palette : source_color, filter_nearest, repeat_disable;
void fragment() {
    vec4 color = texture(sera_palette, UV);
    ALBEDO = color.rgb;
    // Alpha use forces the transparent draw queue; 0.999 is visually solid.
    ALPHA = 0.999;
}
