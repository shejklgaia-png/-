shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Short EN-empty warning on visible SERA surfaces. This is a material_overlay,
// not a replacement for authored part materials or the existing hit/KO shader.
void fragment() {
    ALBEDO = vec3(1.0, 0.035, 0.055);
    EMISSION = vec3(0.55, 0.015, 0.025);
    ALPHA = 0.86;
}
