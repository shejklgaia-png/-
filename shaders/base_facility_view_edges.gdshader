shader_type spatial;
// BASE's previous front/front 2px crease shader is intentionally retained.
// OUTER SILHOUETTES NOW USE THE LATEST SERA INVERTED HULL IN A SEPARATE PASS.
// This pass renders only the original 80-degree foreground corner lines.
// Solid building geometry only: FX/smoke/lamps never receive ink batches.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.3333, 0.4745, 0.5412, 1.0);
uniform float crease_px : hint_range(0.5, 6.0) = 2.0;
varying float edge_visible;

void vertex() {
    // Identical SERA topology encoding: COLOR.rgb = face A normal,
    // COLOR.a = 80-degree hard crease. CUSTOM0.xyz = face B normal;
    // CUSTOM0.w = whether an adjacent triangle exists.
    vec3 normal_a = normalize(COLOR.rgb * 2.0 - vec3(1.0));
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mat3 normal_matrix = transpose(inverse(mat3(MODEL_MATRIX)));
    vec3 n_a = normalize(normal_matrix * normal_a);
    vec3 view_ray = normalize(CAMERA_POSITION_WORLD - world_position);
    float a_facing = dot(n_a, view_ray);
    bool boundary = CUSTOM0.w < 0.5;
    bool contour = boundary && a_facing > 0.02;
    bool both_front = false;
    if (!boundary) {
        vec3 n_b = normalize(normal_matrix * CUSTOM0.xyz);
        float b_facing = dot(n_b, view_ray);
        contour = (a_facing > 0.02 && b_facing < -0.02)
            || (b_facing > 0.02 && a_facing < -0.02);
        both_front = (a_facing > 0.02 && b_facing > 0.02);
    }
    // Retain the old front/front >=80-degree criterion verbatim.
    // Contour segments are now exclusively drawn by SERA's real rear hull.
    bool foreground_crease = both_front && COLOR.a > 0.5;
    bool visible = foreground_crease;
    edge_visible = visible ? 1.0 : 0.0;
    float width = crease_px;

    vec3 eye_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 eye_tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    // Exactly as SERA: slight near-camera bias avoids self z-fighting.
    // Conventional depth testing still hides lines behind opaque surfaces.
    eye_vertex += normalize(-eye_vertex) *
        max(0.002, length(eye_vertex) * 0.0003);
    vec4 clip = PROJECTION_MATRIX * vec4(eye_vertex, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(eye_vertex + eye_tangent * 0.10, 1.0);
    vec2 delta_ndc = tip.xy / max(tip.w, 0.00001)
        - clip.xy / max(clip.w, 0.00001);
    vec2 delta_px = delta_ndc * VIEWPORT_SIZE;
    if (dot(delta_px, delta_px) < 0.0000001) {
        edge_visible = 0.0;
        delta_px = vec2(1.0, 0.0);
    }
    vec2 side = normalize(vec2(-delta_px.y, delta_px.x));
    clip.xy += side * vec2(1.0 / VIEWPORT_SIZE.x,
        1.0 / VIEWPORT_SIZE.y) * width * clip.w * UV.x;
    POSITION = clip;
}

void fragment() {
    if (edge_visible < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = 1.0;
}
