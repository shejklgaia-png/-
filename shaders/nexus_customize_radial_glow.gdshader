shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// Matches the cyan selectable contour, but fades smoothly to transparent.
// No textures, particles, bloom or additional renderer passes are required.
uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 0.98, 1.0);
uniform float glow_opacity : hint_range(0.0, 1.0) = 0.30;

void fragment() {
    vec2 centered_uv = (UV - vec2(0.5)) * 2.0;
    float radius = length(centered_uv);
    float fade = 1.0 - smoothstep(0.0, 1.0, radius);
    fade = pow(max(fade, 0.0), 1.25);
    ALBEDO = glow_color.rgb;
    ALPHA = glow_color.a * glow_opacity * fade;
}
