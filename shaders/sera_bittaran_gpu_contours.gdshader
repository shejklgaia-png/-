shader_type spatial;
// Bittaran hybrid: GPU ribbons draw external front/back silhouettes only.
// The existing ID texture/shader owns the separate-mesh contact borders.
// The source mesh and ribbon share parent transforms and the SAME Camera3D.
// Hardware depth occludes hidden edges; never needs ID framebuffer / camera.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
// On-screen pixel distances measured from the actual mesh contour.
uniform float silhouette_inside_px : hint_range(0.0, 6.0) = 1.0;
uniform float silhouette_outside_px : hint_range(0.0, 6.0) = 5.0;
// Open edges are also the boundaries of separately authored mesh parts.
uniform float seam_px : hint_range(0.5, 6.0) = 4.0;
// Disables open-mesh boundaries and both-front grazing ridges in hybrid mode.
// Geometry generation also omits open edges to lower GPU vertex traffic.
uniform bool silhouette_only = false;
// Extend each screen-space edge to close gaps where two thick ribbons meet.
uniform float corner_cap_px : hint_range(0.0, 6.0) = 5.0;
varying float edge_visible;

void vertex() {
    vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // Using each vertex to decide front/back made visible ink taper or
    // disappear at one end of a long edge. CUSTOM1 stores one identical
    // midpoint for all six vertices of that edge.
    vec3 mid_view = (MODELVIEW_MATRIX * vec4(CUSTOM1.xyz, 1.0)).xyz;
    mat3 nmat = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 normal_a = normalize(nmat * (COLOR.rgb * 2.0 - vec3(1.0)));
    vec3 view_ray = PROJECTION_MATRIX[3][3] > 0.5
        ? vec3(0.0, 0.0, 1.0) : normalize(-mid_view);
    float facing_a = dot(normal_a, view_ray);
    bool paired = CUSTOM0.w >= 0.5;
    float inner_px = silhouette_inside_px;
    float outer_px = silhouette_outside_px;
    bool visible = false;
    float facing_b = -1.0;

    if (!paired) {
        // Real open mesh boundaries, including separate plate/wing meshes.
        visible = not silhouette_only && abs(facing_a) > 0.035;
        // An open boundary may also be the outer silhouette of a plate:
        // use the 1px inward / 3px outward profile on its visible rim.
        outer_px = seam_px;
    } else {
        vec3 normal_b = normalize(nmat * CUSTOM0.xyz);
        facing_b = dot(normal_b, view_ray);
        float strongest = max(abs(facing_a), abs(facing_b));
        bool front_back = (facing_a > 0.025 && facing_b < -0.025) ||
            (facing_b > 0.025 && facing_a < -0.025);
        // A face precisely tangent to the camera changes facing sign within
        // a tiny rotation; keep the same silhouette edge rather than flicker.
        bool grazing = min(abs(facing_a), abs(facing_b)) < 0.085 &&
            strongest > 0.20 && dot(normal_a, normal_b) < 0.95 &&
            (not silhouette_only || facing_a * facing_b <= 0.0);
        // Both faces facing the camera are internal corners.
        // Do not draw them even if this legacy GPU path is restored.
        visible = front_back || grazing;
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

    // Find which screen-space half-plane lies INSIDE the source polygon.
    // The first edge tangent follows the original triangle winding:
    // cross(face_a, tangent) points into face A. Face B uses the reversed
    // tangent around the shared edge. This avoids a screen-center heuristic
    // that fails for limbs, rotated armor and camera shake.
    vec3 inward = cross(normal_a, tangent);
    if (paired && facing_b > facing_a) {
        vec3 normal_b = normalize(nmat * CUSTOM0.xyz);
        inward = -cross(normal_b, tangent);
    }
    float inward_length = length(inward);
    float inward_sign = 1.0;
    if (inward_length > 0.00001) {
        vec4 inside_tip = PROJECTION_MATRIX *
            vec4(view_position + inward / inward_length * 0.10, 1.0);
        vec2 projected_inside = (inside_tip.xy /
            max(inside_tip.w, 0.00001) -
            clip.xy / max(clip.w, 0.00001)) * VIEWPORT_SIZE;
        if (dot(projected_inside, projected_inside) > 0.000001) {
            inward_sign = dot(projected_inside, side) >= 0.0 ? 1.0 : -1.0;
        }
    }

    // UV.x chooses one of the two edges of the ribbon. The half heading
    // into the opaque mesh covers 1 real screen pixel; the opposite half
    // extends 3 real pixels into the background. Clip space spans -1..+1,
    // so an offset of one DISPLAY pixel needs the factor 2.0 here.
    float signed_offset_px = UV.x * (
        UV.x * inward_sign > 0.0 ? inner_px : outer_px);
    clip.xy += side * vec2(2.0 / VIEWPORT_SIZE.x,
        2.0 / VIEWPORT_SIZE.y) * signed_offset_px * clip.w;
    // Adjacent ribbons were separate open-ended rectangles; their external
    // 5px stroke left triangular pinholes at sharp polygon corners. A short
    // square end cap overlaps those ends on the GPU in the SAME camera pass.
    // UV.y keeps the signed 3D-cap fallback from PR #875.
    // CUSTOM2.xyz contains one genuine face-connected neighbor, selected
    // once when the cached ribbon was built. Only the extension changes:
    // width, facing decision, depth, six vertices and GPU follow are intact.
    vec2 edge_dir = normalize(line_vec);
    float cap_length = min(corner_cap_px, outer_px);
    float cap_scale = abs(UV.y);
    if (CUSTOM2.w > 0.5 && clip.w > 0.0) {
        vec3 neighbor_direction =
            (MODELVIEW_MATRIX * vec4(CUSTOM2.xyz, 0.0)).xyz;
        vec4 neighbor_tip = PROJECTION_MATRIX *
            vec4(view_position + neighbor_direction * 0.10, 1.0);
        if (neighbor_tip.w > 0.0) {
            vec2 neighbor_vec = (neighbor_tip.xy /
                max(neighbor_tip.w, 0.00001) -
                clip.xy / max(clip.w, 0.00001)) * VIEWPORT_SIZE;
            if (dot(neighbor_vec, neighbor_vec) > 0.000001) {
                vec2 outgoing = UV.y < 0.0 ? edge_dir : -edge_dir;
                float screen_cosine = clamp(
                    dot(outgoing, normalize(neighbor_vec)), -1.0, 1.0);
                if (screen_cosine < 0.0) {
                    // Projected obtuse joints need less overlap. Keep a
                    // conservative floor to avoid subpixel corner pinholes.
                    cap_scale = clamp(sqrt(max(0.0,
                        (1.0 + screen_cosine) /
                        max(1.0 - screen_cosine, 0.0001))), 0.35, 1.0);
                } else {
                    // Foreshortening made the screen-space corner acute:
                    // restore the known-good full cap to prevent gaps.
                    cap_scale = 1.0;
                }
            }
        }
    }
    // The outside of a connected contour needs its full cap to cover
    // polygon corners; the INSIDE does not. Extending both sides equally
    // creates thick black tabs where adjacent ribbons overlap on armor.
    // Keep a subpixel inside overlap for raster stability. Unconnected end
    // caps remain square, so isolated/open boundaries cannot lose their rim.
    float endpoint_extension_px = cap_scale * cap_length;
    // All face-connected corners (CUSTOM2.w = 0.5 or 1) share the same
    // source MeshInstance3D. Keep the outer cap untouched; eliminate most
    // interior overlap from the two incoming ribbons at their common tip.
    // CUSTOM2.w = 0 is an isolated tip, which keeps its square cap.
    if (CUSTOM2.w > 0.25 && UV.x * inward_sign > 0.0) {
        endpoint_extension_px = min(endpoint_extension_px, 0.35);
    }
    clip.xy += edge_dir * vec2(2.0 / VIEWPORT_SIZE.x,
        2.0 / VIEWPORT_SIZE.y) * (sign(UV.y) *
        endpoint_extension_px) * clip.w;
    POSITION = clip;
}

void fragment() {
    if (edge_visible < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
