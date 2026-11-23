shader_type spatial;
// Offline equipment-icon ONLY: camera-visible 3px convex polygon corners.
// Reuse the game's physical edge ribbons (face normals + signed edge tangent).
// The RGB depth pass draws silhouettes/contacts independently; do not repeat
// those edges here and do not draw hidden geometry through real surfaces.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float crease_px : hint_range(0.5, 6.0) = 3.0;
varying float edge_visible;

void vertex() {
    // The shared ribbon layout encodes inward Blockbench face normals.
    // Adjacent faces are wound consistently and NORMAL is edge A -> B.
    vec3 raw_a = normalize(COLOR.rgb * 2.0 - vec3(1.0));
    vec3 raw_b = normalize(CUSTOM0.xyz);
    vec3 tangent_local = normalize(NORMAL);
    // For inward-wound SERA model faces, negative signed dihedral is convex.
    // This rejects concave corners and visible internal triangle diagonals.
    bool convex = dot(cross(raw_a, raw_b), tangent_local) < -0.001;
    mat3 normal_matrix = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 a_outward = normalize(normal_matrix * -raw_a);
    vec3 b_outward = normalize(normal_matrix * -raw_b);
    vec3 eye_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 view_ray = PROJECTION_MATRIX[3][3] > 0.5 ?
        vec3(0.0, 0.0, 1.0) : normalize(-eye_vertex);
    bool both_front = dot(a_outward, view_ray) > 0.02 &&
        dot(b_outward, view_ray) > 0.02;
    // COLOR.a = >=80 degree hard crease; CUSTOM0.w = adjacent face present.
    edge_visible = convex && both_front && COLOR.a > 0.5 &&
        CUSTOM0.w > 0.5 ? 1.0 : 0.0;

    vec3 eye_tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
        1.0 / VIEWPORT_SIZE.y) * crease_px * clip.w * UV.x;
    POSITION = clip;
}

void fragment() {
    if (edge_visible < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
