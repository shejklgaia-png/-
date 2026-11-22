shader_type canvas_item;
// Global version of the IRIS 3px visible-mesh-ID contour.
// Each actual visible mesh owns an RGB444 ID, up to 4095 meshes per viewport.
// Mesh intersections are depth-tested by the ID viewport. No inverted hull.
render_mode blend_mix;
uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(1.0 / 720.0, 1.0 / 1280.0);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 3.0;
// Only for the small NEXUS debug probe. The production ink stays in mode 0.
uniform int diagnostic_mode : hint_range(0, 1) = 0;

vec3 id_at(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, uv).rgb;
}

bool is_background(vec3 rgb) {
    return max(rgb.r, max(rgb.g, rgb.b)) < 0.02;
}

bool neighbor_has_lower_id(vec3 center, vec3 neighbor) {
    // Compare ID colors directly rather than quantizing their displayed
    // values: Compatibility sRGB output can nonlinearly remap RGB444 codes.
    const float eps = 0.009;
    if (is_background(neighbor)) {
        return true;
    }
    if (abs(neighbor.r - center.r) > eps) {
        return neighbor.r < center.r;
    }
    if (abs(neighbor.g - center.g) > eps) {
        return neighbor.g < center.g;
    }
    return neighbor.b < center.b - eps;
}

void fragment() {
    vec3 center_id = id_at(UV);
    float nearest_dist = 99.0;
    if (!is_background(center_id)) {
        // Same symmetric 3px disk and one-sided seam rule as HEAD D.
        for (int dy = -3; dy <= 3; dy++) {
            for (int dx = -3; dx <= 3; dx++) {
                int distance_sq = dx * dx + dy * dy;
                if (distance_sq == 0 || distance_sq > 10) {
                    continue;
                }
                vec3 neighbor = id_at(UV + mesh_id_texel *
                    vec2(float(dx), float(dy)));
                if (neighbor_has_lower_id(center_id, neighbor)) {
                    nearest_dist = min(nearest_dist, sqrt(float(distance_sq)));
                    if (nearest_dist <= stroke_px) {
                        break;
                    }
                }
            }
            if (nearest_dist <= stroke_px) {
                break;
            }
        }
    }
    float coverage = clamp((stroke_px + 0.5 - nearest_dist) / 0.5, 0.0, 1.0);
    COLOR = vec4(ink_color.rgb, ink_color.a * coverage);
    // The magenta probe distinguishes an executed fragment from a raw white
    // ColorRect fallback. It never runs on the normal viewport-wide ink.
    if (diagnostic_mode == 1) {
        COLOR = vec4(1.0, 0.0, 1.0, 1.0);
    }
}
