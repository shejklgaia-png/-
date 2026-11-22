shader_type spatial;
// NEXUS-only debug extrusion. THIS SHADER HAS NO STENCIL OPERATIONS.
// The two materials use +8px and -8px along the SAME baked smooth
// vertex normal used by the production hull. The color overlay makes the
// projected displacement inspectable over the unmodified original armor.
// Culling and depth checks are disabled intentionally: these two controls
// cannot suppress the result while diagnosing the normal sign.
render_mode unshaded, cull_disabled, depth_draw_never,
    depth_test_disabled, blend_mix, fog_disabled;

uniform vec4 probe_color : source_color = vec4(0.98, 0.24, 0.83, 0.30);
uniform float signed_offset_px : hint_range(-12.0, 12.0, 0.5) = 8.0;

void vertex() {
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 normal_eye = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
    vec4 clip = PROJECTION_MATRIX * vec4(eye, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(
        eye + normal_eye * 0.1, 1.0);
    if (clip.w > 0.00001 && tip.w > 0.00001) {
        vec2 pixel_delta = ((tip.xy / tip.w) -
            (clip.xy / clip.w)) * VIEWPORT_SIZE;
        float distance_px = length(pixel_delta);
        if (distance_px > 0.00001) {
            vec2 axis_px = pixel_delta / distance_px;
            clip.xy += axis_px * vec2(
                2.0 / VIEWPORT_SIZE.x,
                2.0 / VIEWPORT_SIZE.y) * signed_offset_px * clip.w;
        }
    }
    POSITION = clip;
}

void fragment() {
    ALBEDO = probe_color.rgb;
    ALPHA = probe_color.a;
}
