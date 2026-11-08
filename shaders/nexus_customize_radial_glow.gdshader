shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// Use the same cyan as the Nexus selection outline. The torso-sized core
// stays uniformly colored; outside it, the original soft halo fades away.
uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 0.98, 1.0);
uniform float core_radius : hint_range(0.0, 1.0) = 0.24;
uniform float core_opacity : hint_range(0.0, 1.0) = 0.72;
uniform float outer_radius : hint_range(0.0, 1.5) = 0.95;
uniform float outer_opacity : hint_range(0.0, 1.0) = 0.30;

void fragment() {
    vec2 centered_uv = (UV - vec2(0.5)) * 2.0;
    float radius = length(centered_uv);

    // A uniform inner color with a short softened boundary.
    float core = 1.0 - smoothstep(core_radius - 0.03, core_radius + 0.03, radius);

    // Preserve the existing smooth radial falloff outside the core.
    float outer = 1.0 - smoothstep(core_radius, outer_radius, radius);
    outer = pow(max(outer, 0.0), 1.35);

    float alpha = max(core * core_opacity, outer * outer_opacity);
    ALBEDO = glow_color.rgb;
    ALPHA = glow_color.a * alpha;
}
