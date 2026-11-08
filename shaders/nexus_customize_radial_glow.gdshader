shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// v136: uniform cyan core, then one continuously smooth outer falloff.
// Replaces max(core, outer), whose junction created an obvious hard ring.
uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 0.98, 1.0);
uniform float core_radius : hint_range(0.0, 1.0) = 0.34;
uniform float core_opacity : hint_range(0.0, 1.0) = 0.91;
uniform float falloff_power : hint_range(0.5, 3.0) = 1.15;

void fragment() {
    vec2 centered_uv = (UV - vec2(0.5)) * 2.0;
    float radius = length(centered_uv);
    float soft_falloff = 1.0 - smoothstep(core_radius, 1.0, radius);
    ALBEDO = glow_color.rgb;
    ALPHA = glow_color.a * core_opacity * pow(max(soft_falloff, 0.0), falloff_power);
}
