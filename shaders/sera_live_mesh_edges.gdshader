shader_type spatial;
// NEXUS SERA: same-frame screen-pixel edge ribbons in the actual 3D scene.
// Use the already adopted BASE SurfaceTool ribbon data convention:
//   NORMAL = local edge tangent (NOT the face normal)
//   COLOR.rgb = first face normal encoded into 0..1
//   CUSTOM0.xyz = second face normal, CUSTOM0.w = 0 open, 1 paired,
//   CUSTOM0.w = 2 for explicit mesh/mesh contact.
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float silhouette_px : hint_range(1.0, 6.0) = 3.0;
uniform float boundary_px : hint_range(0.5, 6.0) = 1.0;
varying float edge_visible;

void vertex() {
    vec3 eye_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // The source SurfaceTool polygons use Godot's clockwise front faces.
    // Their right-hand geometric cross is reversed for the visible side.
    mat3 normal_matrix = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 a_normal = -normalize(COLOR.rgb * 2.0 - vec3(1.0));
    vec3 n_a = normalize(normal_matrix * a_normal);
    vec3 view_ray = PROJECTION_MATRIX[3][3] > 0.5 ?
        vec3(0.0, 0.0, 1.0) : normalize(-eye_vertex);
    float a_facing = dot(n_a, view_ray);
    bool contact = CUSTOM0.w > 1.5;
    bool boundary = CUSTOM0.w < 0.5;
    bool contour = false;
    if (boundary) {
        // Open geometric boundaries receive the thin 1px detail stroke.
        // Unlike the 3px silhouette, these are not automatically the
        // exterior edge of the assembled character.
        contour = true;
    } else if (!contact) {
        vec3 n_b = normalize(normal_matrix * (-normalize(CUSTOM0.xyz)));
        float b_facing = dot(n_b, view_ray);
        // A nonzero facing threshold on both sides of the edge created
        // short gaps at tangent angles as the model was rotated.
        // Small numerical slack keeps a front/back transition continuous
        // without enabling ordinary front/front convex creases.
        float facing_product = a_facing * b_facing;
        contour = (facing_product <= 0.00002)
            && (min(a_facing, b_facing) <= 0.0);
    }
    edge_visible = (contact || contour) ? 1.0 : 0.0;

    // Use the established BASE projected-ribbon calculation verbatim.
    // This avoids the unreliable tangent/color repacking that caused
    // all NEXUS SERA strokes to disappear in the previous implementation.
    vec3 eye_tangent = normalize((MODELVIEW_MATRIX *
        vec4(NORMAL, 0.0)).xyz);
    // A slightly stronger view-space offset keeps thin lines in front of
    // their own face on Android GL Compatibility. Hardware depth testing
    // still rejects segments hidden behind the other solid parts.
    eye_vertex += normalize(-eye_vertex) *
        max(0.003, length(eye_vertex) * 0.0004);
    vec4 clip = PROJECTION_MATRIX * vec4(eye_vertex, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(
        eye_vertex + eye_tangent * 0.10, 1.0);
    vec2 delta_ndc = tip.xy / max(tip.w, 0.00001)
        - clip.xy / max(clip.w, 0.00001);
    vec2 delta_px = delta_ndc * VIEWPORT_SIZE;
    if (dot(delta_px, delta_px) < 0.0000001) {
        edge_visible = 0.0;
        delta_px = vec2(1.0, 0.0);
    }
    vec2 side = normalize(vec2(-delta_px.y, delta_px.x));
    // Three pixels for a real view silhouette; one pixel for open
    // boundaries and intersecting/disconnected mesh contact lines.
    // Both-front convex edges are explicitly excluded above.
    float width = (contact || boundary) ? boundary_px : silhouette_px;
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
