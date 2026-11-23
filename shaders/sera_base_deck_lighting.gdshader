shader_type spatial;
// Dedicated BASE floor pass. Matches the existing 8-band unshaded armor
// treatment; only the deck gets low-frequency world-fixed illumination.
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform vec2 texture_uv_scale = vec2(1.0);
uniform vec2 texture_uv_offset = vec2(0.0);
// Stronger floor-only framing. These are screen-position effects, not a
// fullscreen overlay: buildings, cables, VFX and UI never receive the tint.
uniform float top_edge_darkness : hint_range(0.0, 0.50, 0.01) = 0.40;
uniform float lower_corner_darkness : hint_range(0.0, 0.50, 0.01) = 0.40;
varying vec2 floor_world_xz;

void vertex() {
    // MODEL_MATRIX includes each MultiMesh instance transform, so pools
    // remain anchored to world space through camera moves and GRID zoom.
    floor_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec3 authored = texture(source_texture,
        UV * texture_uv_scale + texture_uv_offset).rgb *
        source_tint.rgb * COLOR.rgb;
    vec3 world_normal = normalize((INV_VIEW_MATRIX *
        vec4(normalize(NORMAL), 0.0)).xyz);
    float illumination = clamp(dot(world_normal,
        normalize(vec3(-0.45, 0.65, 0.70))) * 0.5 + 0.5, 0.0, 1.0);
    float level = floor(clamp(illumination + 0.5 - 0.65,
        0.0, 0.99999) * 8.0);
    float directional_band = mix(0.55, 1.05, level / 7.0);

    // Broad, overlapping illumination pockets. No textures, random updates,
    // real-time shadow maps or extra viewport are used for this variation.
    vec2 p = floor_world_xz;
    float field_a = sin(p.x * 0.082 + p.y * 0.034 +
        0.54 * sin(p.y * 0.052));
    float field_b = cos(p.y * 0.096 - p.x * 0.046 +
        0.36 * sin(p.x * 0.044));
    float field_c = sin((p.x + p.y * 0.63) * 0.047 + 1.6);
    float light_variation = clamp(
        0.955 + 0.083 * field_a * field_b +
        0.063 * field_c, 0.82, 1.095);
    float coolness = clamp(0.5 + 0.5 * field_b, 0.0, 1.0);
    vec3 temperature = mix(vec3(1.016, 1.0, 0.973),
        vec3(0.978, 1.0, 1.022), coolness);
    // Restrict the vignette to the deck material. Top-edge darkness spreads
    // across the width; bottom darkening is concentrated in the two corners.
    // SCREEN_UV makes the fade stay at the displayed screen edges when the
    // camera moves, while the broad floor lighting stays world-anchored.
    float top_fade = 1.0 - smoothstep(0.0, 0.34, SCREEN_UV.y);
    vec2 left_pos = (SCREEN_UV - vec2(-0.08, 1.10)) /
        vec2(0.56, 0.56);
    vec2 right_pos = (SCREEN_UV - vec2(1.08, 1.10)) /
        vec2(0.56, 0.56);
    float left_corner = 1.0 - smoothstep(0.05, 1.0,
        dot(left_pos, left_pos));
    float right_corner = 1.0 - smoothstep(0.05, 1.0,
        dot(right_pos, right_pos));
    float corner_fade = max(left_corner, right_corner);
    float screen_vignette = clamp(top_edge_darkness * top_fade +
        lower_corner_darkness * corner_fade, 0.0, 0.50);
    ALBEDO = clamp(authored * directional_band *
        light_variation * temperature * (1.0 - screen_vignette),
        vec3(0.0), vec3(1.0));
}
