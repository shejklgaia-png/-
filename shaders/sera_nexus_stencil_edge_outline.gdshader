shader_type spatial;
// NEXUS full-body outline: stable PR #806 GPU-depth contour with
// narrowly bounded grazing-face recovery. No depth texture sampling.
// Previous shader disabled depth testing and sampled scene depth instead:
// on Android, the result still drew hidden/backside edges across the armor.
// Use the GPU depth test for occlusion, and per-edge adjacent face normals
// to reject ordinary interior panel edges. No CPU silhouette update or
// additional viewport, same-frame source mesh transform.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 outline_color : source_color =
    vec4(0.043137, 0.066667, 0.094118, 1.0);
uniform float exterior_px : hint_range(0.5, 8.0) = 3.0;
varying float projected_edge_valid;

void vertex() {
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Existing GPU ribbons encode the normals of the two incident faces.
    // Face winding was inverted when Blockbench surfaces were built, so
    // match the conversion used by sera_live_mesh_edges.gdshader.
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
        // Only a front/back transition may form a per-mesh silhouette.
        // A tiny tolerance avoids gaps at grazing angles.
        bool front_back = (a_facing * b_facing <= 0.00002)
            && (min(a_facing, b_facing) <= 0.0);
        // Camera-grazing faces on duplicated/low-poly armor can have
        // the same tiny sign due to precision/face orientation. Only
        // admit that near-grazing transition; the GPU depth test still
        // rejects edges behind the visible armor.
        bool grazing = min(abs(a_facing), abs(b_facing)) < 0.05
            && max(a_facing, b_facing) > 0.10
            && min(a_facing, b_facing) < 0.06;
        silhouette = front_back || grazing;
    }
    // Contact/interior and both-front edges are not the full-body outline.
    projected_edge_valid = (silhouette && !contact) ? 1.0 : 0.0;

    // The mesh NORMAL stores the *edge tangent*, not a surface normal.
    vec3 tangent_eye = normalize(
        (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    // Small bias prevents near-equal self-depth flicker. Hardware depth
    // still discards edges hidden behind nearer opaque armor.
    eye += normalize(-eye) * max(0.0015, length(eye) * 0.0003);
    vec4 clip = PROJECTION_MATRIX * vec4(eye, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(
        eye + tangent_eye * 0.1, 1.0);

    if (clip.w > 0.00001 && tip.w > 0.00001) {
        vec2 pixel_tangent = (
            (tip.xy / tip.w) - (clip.xy / clip.w)
        ) * (VIEWPORT_SIZE * 0.5);
        float pixel_length = length(pixel_tangent);
        if (pixel_length > 0.0001) {
            vec2 along_px = pixel_tangent / pixel_length;
            vec2 across_px = vec2(-along_px.y, along_px.x);
            vec2 offset_px = across_px * exterior_px * UV.x;
            // A short projected end cap joins adjacent low-poly contours.
            offset_px += along_px * min(exterior_px * 0.55, 1.65) * UV.y;
            clip.xy += offset_px * (2.0 / VIEWPORT_SIZE) * clip.w;
        } else {
            projected_edge_valid = 0.0;
        }
    } else {
        projected_edge_valid = 0.0;
    }
    POSITION = clip;
}

void fragment() {
    if (projected_edge_valid < 0.5) {
        discard;
    }
    // Opaque source depth handles occlusion by other body parts. No manual
    // depth-texture comparison: previously it left back-facing lines visible.
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
