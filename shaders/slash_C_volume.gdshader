shader_type spatial;
// v34: slash draws over the target. Player is re-drawn AFTER all slash passes
// using a dedicated foreground material overlay (priority 126).
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;
uniform sampler2D sprite_sheet : source_color, filter_linear, repeat_disable;
uniform int frame_index : hint_range(0, 7) = 0;
uniform float shell_opacity : hint_range(0.0, 1.0) = 0.42;
uniform float shell_emission : hint_range(0.0, 2.0) = 0.8;

// v34: object-specific target silhouette, independent of framebuffer depth.
// Fragment VERTEX is in view space, so reconstruct the world-space ray.
uniform bool target_mask_enabled = true;
uniform vec3 target_box_center = vec3(0.0, 1.53, -8.0);
uniform vec3 target_box_half_extent = vec3(1.0, 1.0, 1.0);
uniform float target_overlap_opacity : hint_range(0.0, 1.0) = 0.58;
uniform float silhouette_feather_m : hint_range(0.001, 0.5) = 0.08;

float target_silhouette_coverage() {
    if (!target_mask_enabled) { return 0.0; }
    vec3 camera_world = INV_VIEW_MATRIX[3].xyz;
    vec3 world_fragment = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 ray_dir = normalize(world_fragment - camera_world);
    // Keep zero ray directions finite and preserve their sign.
    vec3 safe_dir = vec3(
        abs(ray_dir.x) < 0.00001 ? (ray_dir.x < 0.0 ? -0.00001 : 0.00001) : ray_dir.x,
        abs(ray_dir.y) < 0.00001 ? (ray_dir.y < 0.0 ? -0.00001 : 0.00001) : ray_dir.y,
        abs(ray_dir.z) < 0.00001 ? (ray_dir.z < 0.0 ? -0.00001 : 0.00001) : ray_dir.z
    );
    vec3 near_t = (target_box_center - target_box_half_extent - camera_world) / safe_dir;
    vec3 far_t = (target_box_center + target_box_half_extent - camera_world) / safe_dir;
    vec3 lo = min(near_t, far_t);
    vec3 hi = max(near_t, far_t);
    float entry = max(max(lo.x, lo.y), lo.z);
    float exit = min(min(hi.x, hi.y), hi.z);
    float through = exit - max(entry, 0.0);
    // Soft silhouette at the cube boundary; outside the target => exactly 1x opacity.
    return smoothstep(0.0, max(0.001, silhouette_feather_m), max(through, 0.0));
}

float target_overlap_factor() {
    return mix(1.0, target_overlap_opacity, target_silhouette_coverage());
}

void fragment() {
    vec2 uv = clamp(UV, vec2(0.002), vec2(0.998));
    vec2 grid = vec2(float(frame_index % 4), float(frame_index / 4));
    vec4 ink = texture(sprite_sheet, (uv + grid) * vec2(0.25, 0.5));
    // v33 gave even nearly-transparent texels an opaque 0.27 floor,
    // making overlapping rear triangles look like a flat white polygon.
    // In v34 the shell opacity is *strictly proportional to texture alpha*.
    if (ink.a < 0.065) { discard; }
    float coverage = pow(ink.a, 1.25) * shell_opacity;
    if (coverage < 0.005) { discard; }
    ALBEDO = ink.rgb;
    EMISSION = ink.rgb * shell_emission;
    ALPHA = coverage * target_overlap_factor();
}
