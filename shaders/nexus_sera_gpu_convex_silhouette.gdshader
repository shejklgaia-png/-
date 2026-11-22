shader_type spatial;
// NEXUS display SERA ONLY. Camera-dependent visible convex creases from one
// static topological edge ribbon per source MeshInstance3D.
// Outer silhouette and mesh contacts use the shared depth-resolved ID pass.
// COLOR.rgb: outward normal A encoded 0..1. COLOR.a: convex/usable flag.
// CUSTOM0.xyz: outward normal B. CUSTOM0.w: paired-face flag.
// NORMAL: original edge tangent. UV.x: ribbon side (-1 / +1).
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 4.0) = 4.0;
varying float edge_visible;

void vertex() {
    vec3 eye_point = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mat3 normal_transform = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 normal_a = normalize(normal_transform * (COLOR.rgb * 2.0 - vec3(1.0)));
    vec3 view_ray = PROJECTION_MATRIX[3][3] > 0.5
        ? vec3(0.0, 0.0, 1.0) : normalize(-eye_point);
    float facing_a = dot(normal_a, view_ray);
    bool paired_faces = CUSTOM0.w >= 0.5;
    // The ID image now owns the full outer silhouette AND separate-mesh seams.
    // Only render convex creases whose two source faces are both camera-facing.
    // This avoids a second ribbon over the same outer silhouette (thick ink).
    bool visible_crease = false;
    if (paired_faces) {
        vec3 normal_b = normalize(normal_transform * CUSTOM0.xyz);
        float facing_b = dot(normal_b, view_ray);
        visible_crease = facing_a > 0.02 && facing_b > 0.02;
    }
    edge_visible = (visible_crease && COLOR.a > 0.5) ? 1.0 : 0.0;

    // Pixel-constant ribbon width on perspective AND orthographic cameras.
    // A tiny bias avoids z-fighting while hardware depth rejects hidden
    // segments (including those occluded by separate armor plates).
    vec3 tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    eye_point += view_ray * max(0.0015, length(eye_point) * 0.00015);
    vec4 clip = PROJECTION_MATRIX * vec4(eye_point, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(eye_point + tangent * 0.10, 1.0);
    vec2 projected_edge = (tip.xy / max(tip.w, 0.00001)
        - clip.xy / max(clip.w, 0.00001)) * VIEWPORT_SIZE;
    if (dot(projected_edge, projected_edge) < 0.000001 || clip.w <= 0.0) {
        edge_visible = 0.0;
        projected_edge = vec2(1.0, 0.0);
    }
    vec2 side = normalize(vec2(-projected_edge.y, projected_edge.x));
    clip.xy += side * vec2(1.0 / VIEWPORT_SIZE.x,
        1.0 / VIEWPORT_SIZE.y) * stroke_px * clip.w * UV.x;
    POSITION = clip;
}

void fragment() {
    if (edge_visible < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
