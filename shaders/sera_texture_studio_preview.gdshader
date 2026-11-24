shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D source_texture : source_color, filter_nearest_mipmap, repeat_disable;
void fragment() {
    // Red stores a constant culling flag per triangle, not paint color.
    // 0 = cull front, 0.5 = cull back, 1 = two-sided / legacy.
    if ((COLOR.r < 0.25 && FRONT_FACING) ||
        (COLOR.r >= 0.25 && COLOR.r < 0.75 && !FRONT_FACING)) {
        discard;
    }
    // Preserve the original authored polygon normal (not triangle derivative).
    // Two-sided fragments receive the same normal direction as their front.
    vec3 n = NORMAL;
    if (!FRONT_FACING) {
        n = -n;
    }
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
    float lighting = clamp(dot(world_normal, normalize(vec3(-0.45, 0.65, 0.70))) * 0.5 + 0.5, 0.0, 1.0);
    float shade = mix(0.80, 1.0, floor(lighting * 7.0 + 0.5) / 7.0);
    ALBEDO = texture(source_texture, UV).rgb * shade;
}
