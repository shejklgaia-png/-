shader_type spatial;
// Small batched soft elliptical patches sit above the deck but below
// buildings, props, cables and the existing facility FX.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
varying vec4 patch_tint;
void vertex() {
    patch_tint = INSTANCE_CUSTOM;
}
void fragment() {
    vec2 ellipse = UV * 2.0 - vec2(1.0);
    float r = dot(ellipse, ellipse);
    float feather = pow(max(0.0, 1.0 - smoothstep(0.04, 1.0, r)), 1.65);
    ALBEDO = patch_tint.rgb;
    ALPHA = patch_tint.a * feather;
}
