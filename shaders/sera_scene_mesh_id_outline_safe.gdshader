shader_type canvas_item;
// Scene-wide outline: isolated new shader resource to avoid reusing a
// potentially stale GL Compatibility shader cache entry.
// The branch and 3px disk match the proven HEAD D / IRIS path.
render_mode blend_mix;
uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(1.0 / 720.0, 1.0 / 1280.0);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 3.0;

// Encode the *displayed* RGB444 values as one scalar for IRIS-style
// comparison. Channel weighting is lexicographic even after sRGB remap.
// The encoded float stays below 521 rather than the previous 11000+.
// Background ID 0 must remain transparent.
float id_at(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return 0.0;
    }
    vec3 rgb = texture(mesh_id_texture, uv).rgb;
    if (max(rgb.r, max(rgb.g, rgb.b)) < 0.02) {
        return 0.0;
    }
    return 1.0 + rgb.r * 512.0 + rgb.g * 8.0 + rgb.b * 0.125;
}

bool mismatched_id(float center_id, float neighbor_id) {
    if (neighbor_id < 0.5) {
        return true; // Silhouette ink stays inside the visible surface.
    }
    return neighbor_id + 0.001 < center_id;
}

void fragment() {
    float id = id_at(UV);
    float coverage = 0.0;
    if (id >= 0.5) {
        float nearest_dist = 99.0;
        for (int dy = -3; dy <= 3; dy++) {
            for (int dx = -3; dx <= 3; dx++) {
                int distance_sq = dx * dx + dy * dy;
                if (distance_sq == 0 || distance_sq > 10) {
                    continue;
                }
                vec2 offset = mesh_id_texel * vec2(float(dx), float(dy));
                if (mismatched_id(id, id_at(UV + offset))) {
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
        coverage = clamp((stroke_px + 0.5 - nearest_dist) / 0.5, 0.0, 1.0);
    }
    COLOR = vec4(ink_color.rgb, ink_color.a * coverage);
}
