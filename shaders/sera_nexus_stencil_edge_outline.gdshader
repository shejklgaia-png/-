shader_type spatial;
// NEXUS GPU contour ribbons: hardware depth test always rejects hidden edges.
// An adjacent-front/back transition is the primary silhouette classifier.
// For incomplete / duplicated Blockbench topology, rescue a missed contour
// only when the opaque scene depth jumps from the armor to a distant surface
// across the projected edge. No stencil, second viewport or CPU readback.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 outline_color : source_color =
    vec4(0.043137, 0.066667, 0.094118, 1.0);
uniform float exterior_px : hint_range(0.5, 8.0) = 3.0;
uniform sampler2D scene_depth : hint_depth_texture,
    filter_nearest, repeat_disable;
uniform float depth_gap_ratio : hint_range(0.002, 0.08, 0.001) = 0.015;
uniform float depth_gap_floor : hint_range(0.005, 0.15, 0.005) = 0.035;

varying float projected_edge_valid;
varying float face_contour;
varying float depth_fallback_allowed;
varying vec2 edge_normal_px;
varying float edge_eye_depth;

float _sample_eye_depth(vec2 screen_pos) {
    vec2 uv = clamp(screen_pos, vec2(0.0001), vec2(0.9999));
    float raw_depth = texture(scene_depth, uv).r;
    // Compatibility has OpenGL [-1,+1] clip Z; Forward+/Mobile [0,+1].
    float ndc_z = CLIP_SPACE_FAR < -0.5 ?
        raw_depth * 2.0 - 1.0 : raw_depth;
    vec4 eye_pos = INV_PROJECTION_MATRIX * vec4(
        uv * 2.0 - 1.0, ndc_z, 1.0);
    return abs(eye_pos.z / max(abs(eye_pos.w), 0.00001));
}

void vertex() {
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mat3 normal_matrix = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 n_a = normalize(normal_matrix *
        (-normalize(COLOR.rgb * 2.0 - vec3(1.0))));
    vec3 view_ray = PROJECTION_MATRIX[3][3] > 0.5 ?
        vec3(0.0, 0.0, 1.0) : normalize(-eye);
    float a_facing = dot(n_a, view_ray);
    bool boundary = CUSTOM0.w < 0.5;
    bool contact = CUSTOM0.w > 1.5;
    bool silhouette = boundary;
    if (!boundary && !contact) {
        vec3 n_b = normalize(normal_matrix *
            (-normalize(CUSTOM0.xyz)));
        float b_facing = dot(n_b, view_ray);
        silhouette = (a_facing * b_facing <= 0.00002)
            && (min(a_facing, b_facing) <= 0.0);
    }
    face_contour = (silhouette && !contact) ? 1.0 : 0.0;
    depth_fallback_allowed = contact ? 0.0 : 1.0;
    projected_edge_valid = 0.0;
    edge_normal_px = vec2(0.0, 1.0);

    // A smaller eye-facing bias than the previous implementation reduces
    // excessive dark lines on the interior, while outside-of-body ribbons
    // still pass the native GPU depth test.
    eye += normalize(-eye) * max(0.0005, length(eye) * 0.0001);
    edge_eye_depth = abs(eye.z);
    vec3 tangent_eye = normalize(
        (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec4 clip = PROJECTION_MATRIX * vec4(eye, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(
        eye + tangent_eye * 0.1, 1.0);
    if (clip.w > 0.00001 && tip.w > 0.00001) {
        vec2 pixel_tangent = (
            (tip.xy / tip.w) - (clip.xy / clip.w)
        ) * (VIEWPORT_SIZE * 0.5);
        float tangent_length = length(pixel_tangent);
        if (tangent_length > 0.0001) {
            projected_edge_valid = 1.0;
            vec2 along_px = pixel_tangent / tangent_length;
            edge_normal_px = vec2(-along_px.y, along_px.x);
            vec2 offset_px = edge_normal_px * exterior_px * UV.x;
            offset_px += along_px * min(exterior_px * 0.65, 2.0) * UV.y;
            clip.xy += offset_px * (2.0 / VIEWPORT_SIZE) * clip.w;
        }
    }
    POSITION = clip;
}

void fragment() {
    if (projected_edge_valid < 0.5) {
        discard;
    }
    if (face_contour < 0.5) {
        if (depth_fallback_allowed < 0.5) {
            discard;
        }
        // Test opposite sides of the SAME projected topology edge. Only a
        // transition between armor depth and significantly farther scene
        // depth is rescued. Hardware depth already rejects hidden edges.
        vec2 step_uv = normalize(edge_normal_px) *
            (exterior_px + 1.25) / VIEWPORT_SIZE;
        float d_a = _sample_eye_depth(SCREEN_UV + step_uv);
        float d_b = _sample_eye_depth(SCREEN_UV - step_uv);
        float tolerance = max(depth_gap_floor,
            edge_eye_depth * depth_gap_ratio);
        bool a_near = abs(d_a - edge_eye_depth) <= tolerance;
        bool b_near = abs(d_b - edge_eye_depth) <= tolerance;
        bool a_far = d_a > edge_eye_depth + tolerance;
        bool b_far = d_b > edge_eye_depth + tolerance;
        if (!((a_near && b_far) || (b_near && a_far))) {
            discard;
        }
    }
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
