shader_type spatial;
// Blockbench SERA sealed mesh triangles have reversed winding: source uses CULL_FRONT, so the hull must use CULL_BACK to draw the opposite faces.
// Inverted hull: draw outward-expanded faces behind the source silhouette.
// The opaque SERA body must NOT depth-reject the back faces: stencil 17
// alone clips every pixel within the union of visible body parts.
// With the ordinary depth test, almost every correct back face disappears.
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled,
    blend_mix, fog_disabled;
stencil_mode read, compare_not_equal, 17;

uniform vec4 outline_color : source_color = vec4(0.0431, 0.0667, 0.0941, 1.0);
uniform float outline_px : hint_range(0.5, 8.0) = 3.0;

void vertex() {
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 normal_eye = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
    vec4 clip = PROJECTION_MATRIX * vec4(eye, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(eye + normal_eye * 0.1, 1.0);

    // Work in true viewport pixels, not normalized device coordinates:
    // an NDC vector is anisotropic on a tall mobile screen. A 3px target
    // therefore stays directionally stable under portrait aspect ratios.
    if (clip.w > 0.00001 && tip.w > 0.00001) {
        vec2 ndc = (tip.xy / tip.w) - (clip.xy / clip.w);
        vec2 pixel_delta = ndc * VIEWPORT_SIZE;
        float magnitude = length(pixel_delta);
        if (magnitude > 0.00001) {
            vec2 pixel_direction = pixel_delta / magnitude;
            clip.xy += (pixel_direction * vec2(2.0 / VIEWPORT_SIZE.x,
                2.0 / VIEWPORT_SIZE.y)) * outline_px * clip.w;
        }
    }
    POSITION = clip;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
