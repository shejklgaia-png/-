shader_type spatial;
// RENDER_POLICY: DEPTH_TESTED_EMISSIVE; depth_test=on
// Depth-tested 100%-opacity ink in the post-opaque transparent pass.
// Never change the underlying character palette/material or disable depth.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.09, 0.13, 0.18, 1.0);
uniform float stroke_px : hint_range(0.5, 4.0) = 3.0;
varying float edge_visible;

void vertex() {
    // COLOR.rgb = face A normal (0..1); alpha retains the 80deg metadata.
    // Metadata does not force an ink stroke on a camera-facing corner.
    // CUSTOM0.xyz = face B normal, CUSTOM0.w = adjacent-face flag.
    // NORMAL = edge tangent and UV.x = ribbon left/right side.
    vec3 normal_a = normalize(COLOR.rgb * 2.0 - vec3(1.0));
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mat3 normal_matrix = transpose(inverse(mat3(MODEL_MATRIX)));
    vec3 n_a = normalize(normal_matrix * normal_a);
    vec3 camera_ray = normalize(CAMERA_POSITION_WORLD - world_position);
    float a_facing = dot(n_a, camera_ray);
    bool boundary = CUSTOM0.w < 0.5;
    bool visible = boundary && a_facing > 0.02;
    if (!boundary) {
        vec3 n_b = normalize(normal_matrix * CUSTOM0.xyz);
        float b_facing = dot(n_b, camera_ray);
        // Draw only the projected contour: an adjacent pair must straddle
        // the camera-facing / back-facing boundary. Even a 90-degree crease
        // is NOT inked when both faces are visible from this angle.
        // This retains the silhouette of a foreground piece as it occludes
        // a recessed part, without outlining the near corner of a cube.
        bool silhouette = (a_facing > 0.02 && b_facing < -0.02)
            || (b_facing > 0.02 && a_facing < -0.02);
        visible = silhouette;
    }
    edge_visible = visible ? 1.0 : 0.0;

    vec3 view_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 view_tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    // Bias slightly toward the camera to avoid z-fighting with the source
    // surface. The normal depth test still occludes edges behind armor.
    view_vertex += normalize(-view_vertex) * max(0.002, length(view_vertex) * 0.0003);
    vec4 clip = PROJECTION_MATRIX * vec4(view_vertex, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(view_vertex + view_tangent * 0.10, 1.0);
    vec2 delta_ndc = tip.xy / max(tip.w, 0.00001)
        - clip.xy / max(clip.w, 0.00001);
    vec2 delta_px = delta_ndc * VIEWPORT_SIZE;
    if (dot(delta_px, delta_px) < 0.0000001) {
        edge_visible = 0.0;
        delta_px = vec2(1.0, 0.0);
    }
    vec2 direction = normalize(delta_px);
    vec2 side = vec2(-direction.y, direction.x);
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
