shader_type spatial;
// NEXUS full-body ONLY: depth-tested smooth inverted hull.
// Open/two-sided source: keep both shell sides, depth-test against source.
// The original opaque SERA materials write the depth buffer. Render the
// expanded shell afterwards, without stencil. Opaque front surfaces reject
// the shell's interior; only pixels outside the real silhouette remain.
// ALPHA routes this shell into the transparent pass, after opaque depth.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.043137, 0.066667, 0.094118, 1.0);
uniform float outline_px : hint_range(0.5, 8.0, 0.5) = 3.0;

void vertex() {
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 eye_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
    vec4 clip = PROJECTION_MATRIX * vec4(eye, 1.0);
    vec4 normal_tip = PROJECTION_MATRIX * vec4(
        eye + eye_normal * 0.1, 1.0);

    // Offset by viewport pixels, not by model units. Both the real body
    // and its hull are children of the same pose, avoiding view lag.
    if (clip.w > 0.00001 && normal_tip.w > 0.00001) {
        vec2 projected = (normal_tip.xy / normal_tip.w) -
            (clip.xy / clip.w);
        vec2 direction_pixels = projected * (VIEWPORT_SIZE * 0.5);
        float magnitude = length(direction_pixels);
        if (magnitude > 0.00001) {
            vec2 unit_pixel = direction_pixels / magnitude;
            clip.xy += unit_pixel * outline_px *
                (2.0 / VIEWPORT_SIZE) * clip.w;
        }
    }
    POSITION = clip;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
