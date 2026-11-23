shader_type spatial;
// Bittaran battle only: screen-space GPU silhouette ribbons and joined corners.
// All strokes inherit source transforms + the SAME Camera3D, without ID viewports.
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float silhouette_inside_px : hint_range(0.0, 6.0) = 1.0;
uniform float silhouette_outside_px : hint_range(0.0, 6.0) = 5.0;
uniform float seam_px : hint_range(0.5, 6.0) = 3.0;
// Miters longer than twice the exterior width become bevels (no dark spikes).
uniform float miter_limit : hint_range(1.0, 4.0) = 2.0;
varying float edge_visible;
varying float is_joint;

vec3 view_ray_at(vec3 p) {
    return PROJECTION_MATRIX[3][3] > 0.5
        ? vec3(0.0, 0.0, 1.0) : normalize(-p);
}

vec2 screen_point(vec4 clip) {
    return (clip.xy / max(clip.w, 0.00001)) * (VIEWPORT_SIZE * 0.5);
}

float cross_2d(vec2 a, vec2 b) {
    return a.x * b.y - a.y * b.x;
}

bool contour_visible(vec3 na, vec3 nb, bool paired, vec3 midpoint) {
    vec3 ray = view_ray_at(midpoint);
    float fa = dot(na, ray);
    if (!paired) {
        return abs(fa) > 0.035;
    }
    float fb = dot(nb, ray);
    bool front_back = (fa > 0.025 && fb < -0.025) ||
        (fb > 0.025 && fa < -0.025);
    bool grazing = min(abs(fa), abs(fb)) < 0.085 &&
        max(abs(fa), abs(fb)) > 0.20 && dot(na, nb) < 0.95;
    // Both front-facing faces are interior creases, never character ink.
    return front_back || grazing;
}

// Pixel-space outward normal based on the same face orientation as ribbons.
// `tangent` follows original triangle winding, not endpoint outgoing order.
vec2 exterior_offset(vec3 na, vec3 nb, bool paired, vec3 tangent,
        vec3 view_position, float outer_width) {
    vec4 p = PROJECTION_MATRIX * vec4(view_position, 1.0);
    vec4 tip = PROJECTION_MATRIX *
        vec4(view_position + tangent * 0.10, 1.0);
    vec2 line = screen_point(tip) - screen_point(p);
    if (dot(line, line) < 0.000001) {
        return vec2(0.0);
    }
    vec2 side = normalize(vec2(-line.y, line.x));
    vec3 ray = view_ray_at(view_position);
    vec3 inward = cross(na, tangent);
    if (paired && dot(nb, ray) > dot(na, ray)) {
        inward = -cross(nb, tangent);
    }
    if (dot(inward, inward) < 0.000000001) {
        return -side * outer_width;
    }
    vec4 projected_inside = PROJECTION_MATRIX * vec4(
        view_position + normalize(inward) * 0.10, 1.0);
    vec2 into_face = screen_point(projected_inside) - screen_point(p);
    float inward_sign = dot(into_face, side) >= 0.0 ? 1.0 : -1.0;
    return -side * inward_sign * outer_width;
}

void vertex() {
    is_joint = COLOR.a > 0.5 ? 1.0 : 0.0;
    mat3 nmat = transpose(inverse(mat3(MODELVIEW_MATRIX)));
    vec3 na = normalize(nmat * (COLOR.rgb * 2.0 - vec3(1.0)));
    bool paired = CUSTOM0.w > 0.5;
    vec3 nb = paired ? normalize(nmat * CUSTOM0.xyz) : vec3(0.0);
    vec3 tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    if (is_joint > 0.5) {
        // Every candidate joint is cached with its two real incident edges.
        // The GPU draws it only when BOTH are silhouette edges for this view.
        bool paired_b = CUSTOM2.w > 0.5;
        vec3 na_b = normalize(nmat * CUSTOM2.xyz);
        vec3 nb_b = paired_b ? normalize(nmat * CUSTOM3.xyz) : vec3(0.0);
        vec3 tangent_b = normalize(
            (MODELVIEW_MATRIX * vec4(CUSTOM1.xyz, 0.0)).xyz);
        vec3 delta_a = tangent * CUSTOM1.w; // signed endpoint->other end
        vec3 delta_b = tangent_b * CUSTOM3.w;
        bool first_visible = contour_visible(
            na, nb, paired, view_position + delta_a * 0.5);
        bool second_visible = contour_visible(
            na_b, nb_b, paired_b, view_position + delta_b * 0.5);
        edge_visible = (first_visible && second_visible) ? 1.0 : 0.0;
        vec4 p = PROJECTION_MATRIX * vec4(view_position, 1.0);
        vec4 q1 = PROJECTION_MATRIX * vec4(view_position + delta_a, 1.0);
        vec4 q2 = PROJECTION_MATRIX * vec4(view_position + delta_b, 1.0);
        vec2 first_px = screen_point(q1) - screen_point(p);
        vec2 second_px = screen_point(q2) - screen_point(p);
        if (p.w <= 0.0 || q1.w <= 0.0 || q2.w <= 0.0 ||
                length(first_px) < 0.001 || length(second_px) < 0.001) {
            edge_visible = 0.0;
            first_px = vec2(1.0, 0.0);
            second_px = vec2(0.0, 1.0);
        }
        vec2 d1 = normalize(first_px);
        vec2 d2 = normalize(second_px);
        float width_a = paired ? silhouette_outside_px : seam_px;
        float width_b = paired_b ? silhouette_outside_px : seam_px;
        vec2 outer_a = exterior_offset(na, nb, paired, tangent,
            view_position, width_a);
        vec2 outer_b = exterior_offset(na_b, nb_b, paired_b, tangent_b,
            view_position, width_b);
        float denom = cross_2d(d1, d2);
        float along_a = 0.0;
        float along_b = 0.0;
        if (abs(denom) < 0.001) {
            edge_visible = 0.0;
        } else {
            along_a = cross_2d(outer_b - outer_a, d2) / denom;
            along_b = cross_2d(outer_b - outer_a, d1) / denom;
            // Only the outside wedge has an actual gap. Concave corners
            // already overlap as ribbons; joining them would make black blobs.
            if (along_a >= -0.01 || along_b >= -0.01) {
                edge_visible = 0.0;
            }
        }
        vec2 meeting = outer_a + d1 * along_a;
        if (length(meeting) > miter_limit * max(width_a, width_b)) {
            // Replace the long pointed miter with a short straight bevel.
            meeting = (outer_a + outer_b) * 0.5;
        }
        // UV coordinates encode the vertex of the join quad:
        // (0,0)=endpoint; (1,0)=outerA; (1,1)=miter;
        // (0,1)=outerB. Two triangles, no extra material/draw call.
        vec2 shift = vec2(0.0);
        if (UV.x > 0.5 && UV.y < 0.5) {
            shift = outer_a;
        } else if (UV.x > 0.5 && UV.y > 0.5) {
            shift = meeting;
        } else if (UV.y > 0.5) {
            shift = outer_b;
        }
        vec3 ray = view_ray_at(view_position);
        view_position += ray *
            max(0.0015, length(view_position) * 0.00015);
        vec4 clip = PROJECTION_MATRIX * vec4(view_position, 1.0);
        clip.xy += shift * vec2(2.0 / VIEWPORT_SIZE.x,
            2.0 / VIEWPORT_SIZE.y) * clip.w;
        POSITION = clip;
        return;
    }

    // Uniform decision at the edge midpoint prevents one end disappearing.
    vec3 mid_view = (MODELVIEW_MATRIX * vec4(CUSTOM1.xyz, 1.0)).xyz;
    edge_visible = contour_visible(na, nb, paired, mid_view) ? 1.0 : 0.0;
    float inner_px = silhouette_inside_px;
    float outer_px = paired ? silhouette_outside_px : seam_px;

    vec3 ray = view_ray_at(mid_view);
    view_position += ray * max(0.0015, length(view_position) * 0.00015);
    vec4 clip = PROJECTION_MATRIX * vec4(view_position, 1.0);
    vec4 tip = PROJECTION_MATRIX *
        vec4(view_position + tangent * 0.10, 1.0);
    vec2 line_vec = screen_point(tip) - screen_point(clip);
    if (clip.w <= 0.0 || dot(line_vec, line_vec) < 0.000001) {
        edge_visible = 0.0;
        line_vec = vec2(1.0, 0.0);
    }
    vec2 side = normalize(vec2(-line_vec.y, line_vec.x));

    vec3 inward = cross(na, tangent);
    if (paired && dot(nb, ray) > dot(na, ray)) {
        inward = -cross(nb, tangent);
    }
    float inward_sign = 1.0;
    if (length(inward) > 0.00001) {
        vec4 inside_tip = PROJECTION_MATRIX *
            vec4(view_position + normalize(inward) * 0.10, 1.0);
        vec2 projected_inside = screen_point(inside_tip) -
            screen_point(clip);
        if (dot(projected_inside, projected_inside) > 0.000001) {
            inward_sign = dot(projected_inside, side) >= 0.0 ? 1.0 : -1.0;
        }
    }
    float signed_offset_px = UV.x * (
        UV.x * inward_sign > 0.0 ? inner_px : outer_px);
    clip.xy += side * vec2(2.0 / VIEWPORT_SIZE.x,
        2.0 / VIEWPORT_SIZE.y) * signed_offset_px * clip.w;
    // No square end extension: cached join patches close true visible corners.
    POSITION = clip;
}

void fragment() {
    if (edge_visible < 0.5) {
        discard;
    }
    // Single-pixel analytic coverage. Keep the stroke crisp, but blend the
    // final pixel at sloped boundaries rather than leaving staircase jaggies.
    float coverage;
    if (is_joint > 0.5) {
        // Join quads map to [0,1]^2. Only the two OUTER edges are softened;
        // the other two meet the ribbons without transparent seams.
        float aa_x = max(fwidth(UV.x), 0.00001);
        float aa_y = max(fwidth(UV.y), 0.00001);
        coverage = min(
            clamp((1.0 - UV.x) / aa_x + 0.5, 0.0, 1.0),
            clamp((1.0 - UV.y) / aa_y + 0.5, 0.0, 1.0));
    } else {
        float aa = max(fwidth(UV.x), 0.00001);
        coverage = clamp((1.0 - abs(UV.x)) / aa + 0.5, 0.0, 1.0);
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a * coverage;
}
