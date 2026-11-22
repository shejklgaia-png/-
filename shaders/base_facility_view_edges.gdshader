shader_type spatial;
// BASE 2px dark-gray visible hard corners ONLY. The 6px exterior outline
// now uses exactly shaders/sera_view_edges.gdshader (backface inverted hull).
// Preserve the original adjacency-driven 80-degree front/front creases.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.20784, 0.20784, 0.20784, 1.0);
uniform float crease_px : hint_range(0.5, 6.0) = 2.0;
varying float edge_visible;

void vertex() {
    // COLOR.rgb packs first face normal; COLOR.a marks the >=80° edge.
    // CUSTOM0.xyz packs the neighbor face normal, w marks adjacency.
    vec3 normal_a = normalize(COLOR.rgb * 2.0 - vec3(1.0));
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mat3 normal_matrix = transpose(inverse(mat3(MODEL_MATRIX)));
    vec3 n_a = normalize(normal_matrix * normal_a);
    vec3 view_ray = normalize(CAMERA_POSITION_WORLD - world_position);
    float a_facing = dot(n_a, view_ray);
    vec3 n_b = normalize(normal_matrix * CUSTOM0.xyz);
    float b_facing = dot(n_b, view_ray);
    bool both_front = (CUSTOM0.w > 0.5)
        && (a_facing > 0.02 && b_facing > 0.02);
    edge_visible = (both_front && COLOR.a > 0.5) ? 1.0 : 0.0;

    vec3 eye_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 eye_tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    // Slight camera-side depth bias avoids z-fighting but hidden edges remain
    // occluded by the opaque model and its other solid MeshInstances.
    eye_vertex += normalize(-eye_vertex)
        * max(0.002, length(eye_vertex) * 0.0003);
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
    ALPHA = 1.0;
}
