shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// CUSTOMIZE matte backdrop: behind SERA, depth-tested, screen-sized.
// Keep the legacy resource path for existing scene compatibility.
// No radial emission, center highlight or position-dependent alpha.
uniform vec4 base_tint : source_color = vec4(0.290, 0.420, 0.490, 1.0);
uniform vec4 grid_tint : source_color = vec4(0.129, 0.224, 0.267, 1.0);
uniform float grid_strength : hint_range(0.0, 1.0) = 0.65;
uniform vec2 grid_cells = vec2(17.0, 30.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.62;

void fragment() {
    // Camera-fixed square grid. fwidth anti-aliases the thin dark lines.
    vec2 phase = UV * grid_cells;
    vec2 cell = fract(phase);
    vec2 edge_distance = min(cell, vec2(1.0) - cell);
    vec2 anti_alias = max(fwidth(phase), vec2(0.002));
    vec2 lines = vec2(1.0) - smoothstep(
        vec2(0.012), vec2(0.012) + anti_alias, edge_distance);
    float grid_mask = max(lines.x, lines.y);

    ALBEDO = mix(base_tint.rgb, grid_tint.rgb, grid_strength * grid_mask);
    ALPHA = base_opacity;
}
