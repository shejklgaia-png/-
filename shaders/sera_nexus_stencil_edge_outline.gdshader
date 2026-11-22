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
// Ribbon width is a vertex-stage local; it never needs interpolation.

void vertex() {
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // The first face normal now comes from CUSTOM2.xyz (float32), NOT
    // from the 8-bit COLOR channel. The second stays in CUSTOM0.xyz.
    // Both use the same precision for a stable grazing-angle decision.
    // SeraRig's authored geometry is opposite Godot's clockwise front.
    mat3 normal_matrix = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 n_a = normalize(normal_matrix *
        (-normalize(CUSTOM2.xyz)));
    // All 6 ribbon vertices use ONE camera-facing classification, sampled
    // at the topology edge midpoint stored in CUSTOM1. This avoids partial
    // line disappearance along long or tilted Blockbench edges.
    vec3 edge_center_eye = (MODELVIEW_MATRIX *
        vec4(CUSTOM1.xyz, 1.0)).xyz;
    vec3 view_ray = PROJECTION_MATRIX[3][3] > 0.5 ?
        vec3(0.0, 0.0, 1.0) : normalize(-edge_center_eye);
    float a_facing = dot(n_a, view_ray);
    bool boundary = CUSTOM0.w < 0.5;
    bool contact = CUSTOM0.w > 1.5;
    bool silhouette = boundary;
    float ribbon_width_scale = 1.0;

    if (!boundary && !contact) {
        vec3 n_b = normalize(normal_matrix *
            (-normalize(CUSTOM0.xyz)));
        float b_facing = dot(n_b, view_ray);
        // Only a front/back transition may form a per-mesh silhouette.
        // A tiny tolerance avoids gaps at grazing angles.
        bool front_back = (a_facing * b_facing <= 0.00002)
            && (min(a_facing, b_facing) <= 0.0);
        // Rescue only sharp polygon corners with one face almost
        // edge-on. This is sign tolerant for Blockbench winding variants,
        // but NOT a wholesale "all sharp edges" fallback.
        // Keep recovered lines narrow so front-facing internal creases do
        // not grow into thick visible bands when the camera rotates.
        float most_grazing = min(abs(a_facing), abs(b_facing));
        float strongest_face = max(abs(a_facing), abs(b_facing));
        float face_similarity = dot(n_a, n_b);
        bool grazing = most_grazing < 0.12
            && strongest_face > 0.40
            && min(a_facing, b_facing) < -0.10
            && face_similarity < 0.55;
        // Do not confuse a visible sharp convex armor joint with the
        // *outer* silhouette: the former gets a much thinner detail ink.
        // The signed convex flag is calculated from directed face normals
        // and the original topology edge, not from screen direction.
        bool visible_convex = CUSTOM2.w > 0.5
            && a_facing < -0.07
            && b_facing < -0.07;
        silhouette = front_back || grazing || visible_convex;
        if (visible_convex && !front_back) {
            // The ribbon spans +/- exterior_px. 0.25 gives 1.5 px total
            // for these interior visible corners, versus 3 px outside.
            ribbon_width_scale = 0.25;
        } else if (grazing && !front_back) {
            ribbon_width_scale = 0.32;
        }
    }
    // Hide deep contact edges; retain thin *visible convex* seams only.
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
            vec2 offset_px = across_px * exterior_px *
                ribbon_width_scale * UV.x;
            // The cap is slightly extended on proven silhouettes. Narrow
            // fallback strokes keep shorter caps; no interior thickening.
            offset_px += along_px * min(exterior_px * 0.65, 1.95) *
                ribbon_width_scale * UV.y;
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
