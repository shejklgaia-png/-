shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// A stationary cyber-blue panel with a cyan radial halo and fine square grid.
// The grid uses exactly the halo's alpha mask: it disappears at the same edge.
uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 0.98, 1.0);
uniform vec3 cyber_blue : source_color = vec3(0.025, 0.083, 0.160);
uniform vec3 grid_color : source_color = vec3(0.16, 0.42, 0.58);
uniform float grid_strength : hint_range(0.0, 1.0) = 0.34;
uniform vec2 grid_cells = vec2(12.0, 14.0);
uniform float core_radius : hint_range(0.0, 1.0) = 0.34;
uniform float core_opacity : hint_range(0.0, 1.0) = 0.91;
uniform float falloff_power : hint_range(0.5, 3.0) = 1.15;

void fragment() {
    vec2 centered_uv = (UV - vec2(0.5)) * 2.0;
    float radius = length(centered_uv);
    float soft_falloff = 1.0 - smoothstep(core_radius, 1.0, radius);

    // One fixed grid, scaled to about half the head width at preview entry.
    // fwidth gives one-pixel anti-aliasing in Godot's Compatibility renderer.
    vec2 phase = UV * grid_cells;
    vec2 cell = fract(phase);
    vec2 edge_distance = min(cell, vec2(1.0) - cell);
    vec2 anti_alias = max(fwidth(phase), vec2(0.002));
    vec2 lines = vec2(1.0) - smoothstep(
        vec2(0.012), vec2(0.012) + anti_alias, edge_distance);
    float grid_mask = max(lines.x, lines.y);

    vec3 background = mix(cyber_blue, glow_color.rgb, 0.28 * soft_falloff);
    ALBEDO = mix(background, grid_color, grid_strength * grid_mask);
    ALPHA = glow_color.a * core_opacity * pow(max(soft_falloff, 0.0), falloff_power);
}
