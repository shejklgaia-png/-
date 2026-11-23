shader_type spatial;
// Bittaran battle: GPU ribbons draw silhouettes and separate-mesh borders ONLY.
// The source mesh and ribbon share parent transforms and the SAME Camera3D.
// Hardware depth occludes hidden edges; never needs ID framebuffer / camera.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float silhouette_px : hint_range(0.5, 6.0) = 3.0;
uniform float seam_px : hint_range(0.5, 6.0) = 3.0;
varying float edge_visible;

void vertex() {
    vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mat3 nmat = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 normal_a = normalize(nmat * (COLOR.rgb * 2.0 - vec3(1.0)));
    vec3 view_ray = PROJECTION_MATRIX[3][3] > 0.5
        ? vec3(0.0, 0.0, 1.0) : normalize(-view_position);
    float facing_a = dot(normal_a, view_ray);
    bool paired = CUSTOM0.w >= 0.5;
    float width_px = silhouette_px;
    bool visible = false;

    if (!paired) {
        // Real open mesh boundaries, including separate plate/wing meshes.
        visible = abs(facing_a) > 0.035;
        width_px = seam_px;
    } else {
        vec3 normal_b = normalize(nmat * CUSTOM0.xyz);
        float facing_b = dot(normal_b, view_ray);
        float strongest = max(abs(facing_a), abs(facing_b));
        bool front_back = (facing_a > 0.025 && facing_b < -0.025) ||
            (facing_b > 0.025 && facing_a < -0.025);
        // A face precisely tangent to the camera changes facing sign within
        // a tiny rotation; keep the same silhouette edge rather than flicker.
        bool grazing = min(abs(facing_a), abs(facing_b)) < 0.085 &&
            strongest > 0.20 && dot(normal_a, normal_b) < 0.95;
        // Both faces facing the camera is an internal convex corner.
        // Never emit it for SERA, any enemy or CRATE.
        visible = front_back || grazing;
        width_px = silhouette_px;
    }
    edge_visible = visible ? 1.0 : 0.0;

    // Fixed screen-pixel width for both perspective and ortho projection.
    // The small view-space bias prevents coincident faces from z-fighting.
    vec3 tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    view_position += view_ray * max(0.0015, length(view_position) * 0.00015);
    vec4 clip = PROJECTION_MATRIX * vec4(view_position, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(view_position + tangent * 0.10, 1.0);
    vec2 line_vec = (tip.xy / max(tip.w, 0.00001)
        - clip.xy / max(clip.w, 0.00001)) * VIEWPORT_SIZE;
    if (clip.w <= 0.0 || dot(line_vec, line_vec) < 0.000001) {
        edge_visible = 0.0;
        line_vec = vec2(1.0, 0.0);
    }
    vec2 side = normalize(vec2(-line_vec.y, line_vec.x));
    clip.xy += side * vec2(1.0 / VIEWPORT_SIZE.x,
        1.0 / VIEWPORT_SIZE.y) * width_px * clip.w * UV.x;
    POSITION = clip;
}

void fragment() {
    if (edge_visible < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
