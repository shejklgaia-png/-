shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// RENDER_POLICY: translucent depth-tested SERA portrait background; depth_test=on
// A single screen-sized blue-grey sheet lives behind SERA's opaque 3D rig.
// The cyan radial highlight is anchored to SERA's frozen front-pose projection.
// The square grid stays fixed in screen space and extends over the wider sheet.
uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 0.98, 1.0);
uniform vec3 cyber_blue : source_color = vec3(0.18, 0.28, 0.34);
uniform vec3 grid_color : source_color = vec3(0.24, 0.41, 0.50);
uniform float grid_strength : hint_range(0.0, 1.0) = 0.34;
uniform vec2 grid_cells = vec2(12.0, 14.0);
uniform vec2 halo_center = vec2(0.73, 0.50);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.34;
uniform float core_radius : hint_range(0.0, 1.0) = 0.34;
uniform float core_opacity : hint_range(0.0, 1.0) = 0.91;
uniform float falloff_power : hint_range(0.5, 3.0) = 1.15;

void fragment() {
    vec2 centered_uv = (UV - halo_center) * 2.0;
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
    ALBEDO = mix(background, grid_color,
        grid_strength * grid_mask * (0.50 + 0.50 * soft_falloff));
    // The translucent blue-grey base remains visible outside the radial halo
    // instead of collapsing to zero alpha at the old small-quad boundary.
    ALPHA = glow_color.a * mix(base_opacity, core_opacity,
        pow(max(soft_falloff, 0.0), falloff_power));
}
