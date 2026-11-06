shader_type spatial;
// v75 - Three-tap directional background streak. GL Compatibility friendly.
// Applied only to ground surfaces and scenery explicitly opted into the group.
// The plane is depth-tested, so solid near objects and the enemy occlude it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 player_world = vec3(0.0);
uniform float far_begin = 7.0;
uniform float far_full = 11.0;
uniform vec2 blur_direction = vec2(0.0, 1.0);
uniform float blur_px = 4.0;
uniform float blur_opacity = 0.8;
varying vec3 fragment_world;
void vertex() {
    fragment_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    // 2D horizontal distance is stable even with the low-pitch camera.
    float range_xz = distance(fragment_world.xz, player_world.xz);
    if (range_xz <= far_begin) { discard; }
    float fade = smoothstep(far_begin, far_full, range_xz);
    vec2 displacement = blur_direction * (blur_px / VIEWPORT_SIZE);
    vec2 uv_a = clamp(SCREEN_UV - displacement, vec2(0.001), vec2(0.999));
    vec2 uv_b = clamp(SCREEN_UV + displacement, vec2(0.001), vec2(0.999));
    vec3 near_sample = texture(screen_texture, uv_a).rgb;
    vec3 center_sample = texture(screen_texture, SCREEN_UV).rgb;
    vec3 far_sample = texture(screen_texture, uv_b).rgb;
    ALBEDO = near_sample * 0.25 + center_sample * 0.50 + far_sample * 0.25;
    ALPHA = fade * blur_opacity;
}
