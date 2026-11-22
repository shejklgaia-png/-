shader_type spatial;
// BASE physical mesh contour ink. Only silhouette edge ribbons (one face
// camera-facing and its adjacent face facing away) survive. Both visible
// faces are NEVER outlined with 4px; those are handled by the 2px pass.
// No opaque surface polygons, no depth-texture probe, no FX/smoke/light.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float stroke_px : hint_range(0.5, 9.0) = 4.0;
uniform bool force_all_edges = false; // diagnostic only, reset on exit
varying float edge_visible;

void vertex() {
    // COLOR.rgb = face A (encoded -1..1), CUSTOM0.xyz = face B;
    // CUSTOM0.w = 1 for paired faces, 0 for a physical open edge.
    // BASE polygon mesh winding is clockwise in Godot, so the CPU's
    // right-hand cross is inward. Correct the sign only for BASE ink.
    vec3 normal_a = -normalize(COLOR.rgb * 2.0 - vec3(1.0));
    vec3 eye_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mat3 normal_matrix = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 n_a = normalize(normal_matrix * normal_a);
    // Orthographic rays are parallel even far from the camera's world
    // position; the previous world-to-camera ray distorted side faces.
    vec3 view_ray = PROJECTION_MATRIX[3][3] > 0.5 ?
        vec3(0.0, 0.0, 1.0) : normalize(-eye_vertex);
    float a_facing = dot(n_a, view_ray);
    bool boundary = CUSTOM0.w < 0.5;
    bool contour = boundary && a_facing > 0.02;
    if (!boundary) {
        vec3 n_b = normalize(normal_matrix * (-normalize(CUSTOM0.xyz)));
        float b_facing = dot(n_b, view_ray);
        contour = (a_facing > 0.02 && b_facing < -0.02)
            || (b_facing > 0.02 && a_facing < -0.02);
    }
    // Diagnostic exposes all physical edges, never a giant surface fill.
    bool visible = contour || force_all_edges;
    edge_visible = visible ? 1.0 : 0.0;

    // The ribbon is six vertices per topological edge. Vertices initially
    // coincide; inflate in clip space perpendicular to the projected edge.
    // Keep normal hardware depth testing to reject hidden line segments.
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
        1.0 / VIEWPORT_SIZE.y) * stroke_px * clip.w * UV.x;
    POSITION = clip;
}

void fragment() {
    if (edge_visible < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = 1.0;
}
