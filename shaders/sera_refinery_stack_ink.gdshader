shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

// Only the two close-up refinery stacks use this small local fallback.
// Expand the existing hollow sleeve by one render-target pixel, not metres.
void vertex() {
    vec3 radial = normalize(vec3(VERTEX.x, NORMAL.y * 0.35, VERTEX.z));
    vec3 direction = normalize(MODELVIEW_NORMAL_MATRIX * radial);
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec2 projected = (PROJECTION_MATRIX * vec4(direction, 0.0)).xy * VIEWPORT_SIZE;
    float magnitude = length(projected);
    if (magnitude > 0.0001 && clip.w > 0.0) {
        clip.xy += projected / magnitude * (2.0 / VIEWPORT_SIZE) * clip.w;
    }
    POSITION = clip;
}

void fragment() {
    ALBEDO = vec3(0.0);
}
