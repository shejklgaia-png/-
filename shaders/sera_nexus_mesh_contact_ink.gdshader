shader_type canvas_item;
// NEXUS: shared depth-resolved ID ink. SERA silhouette is 4px total:
// 1px inside the visible mesh + 3px outside, enclosing bright mesh edges.
// Visible mesh-to-mesh contact seams are 3px.
// No obscured contours or camera-facing geometric convex creases are drawn.
// Outside pixels are sampled only within the projected SERA screen bounds.
render_mode blend_mix;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667, 0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 2.0; // NEXUS architecture
uniform float sera_stroke_px : hint_range(1.0, 4.0) = 4.0;
uniform float sera_seam_px : hint_range(0.5, 3.0) = 3.0;
// xmin, ymin, xmax, ymax in viewport UV; zero-sized when SERA absent.
uniform vec4 sera_screen_bounds = vec4(0.0);

vec3 id_at(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, uv).rgb;
}

bool is_sera(vec3 mesh_id) {
    return mesh_id.g >= 0.06;
}

// One-sided ordering keeps a 3px contact seam on only one mesh.
bool owns_contact(vec3 center_id, vec3 neighbor_id) {
    if (abs(center_id.b - neighbor_id.b) > 0.06) {
        return center_id.b > neighbor_id.b;
    }
    if (abs(center_id.g - neighbor_id.g) > 0.06) {
        return center_id.g > neighbor_id.g;
    }
    return center_id.r > neighbor_id.r + 0.06;
}

bool room_mismatch(vec3 center_id, vec3 neighbor_id) {
    if (is_sera(neighbor_id)) {
        return false;
    }
    if (neighbor_id.r < 0.06) {
        return true;
    }
    return neighbor_id.r + 0.05 < center_id.r;
}

vec2 sample_offset(int radius, int direction) {
    float d = float(radius);
    if (direction == 0) {
        return vec2(d, 0.0);
    }
    if (direction == 1) {
        return vec2(-d, 0.0);
    }
    if (direction == 2) {
        return vec2(0.0, d);
    }
    if (direction == 3) {
        return vec2(0.0, -d);
    }
    if (direction == 4) {
        return vec2(d, d);
    }
    if (direction == 5) {
        return vec2(-d, d);
    }
    if (direction == 6) {
        return vec2(d, -d);
    }
    return vec2(-d, -d);
}

float solid_coverage(float distance_px, float width_px) {
    return clamp((width_px + 0.5 - distance_px) / 0.5, 0.0, 1.0);
}

void fragment() {
    vec3 center_id = id_at(UV);
    bool center_sera = is_sera(center_id);
    float coverage = 0.0;

    if (center_sera) {
        float inner_width = 1.0;
        float outer_distance = 99.0;
        float seam_distance = 99.0;
        // One-pixel inward silhouette plus a three-pixel contact seam.
        // Sparse axial/diagonal sampling, up to 20 neighbor samples.
        for (int radius = 1; radius <= 3; radius++) {
            for (int direction = 0; direction < 8; direction++) {
                vec2 offset = sample_offset(radius, direction);
                float distance_px = length(offset);
                if (distance_px > max(inner_width, sera_seam_px) + 0.5) {
                    continue;
                }
                vec3 neighbor_id = id_at(UV + offset * mesh_id_texel);
                if (!is_sera(neighbor_id)) {
                    outer_distance = min(outer_distance, distance_px);
                } else if (distance_px <= sera_seam_px + 0.5 &&
                        owns_contact(center_id, neighbor_id)) {
                    seam_distance = min(seam_distance, distance_px);
                }
            }
            if (outer_distance <= 1.0 && seam_distance <= 1.0) {
                break;
            }
        }
        coverage = max(solid_coverage(outer_distance, inner_width),
            solid_coverage(seam_distance, sera_seam_px));
    } else {
        // Three exterior pixels belong to the projected SERA boundary only.
        // Skip extra sampling outside the projected SERA screen bounds.
        bool near_sera = UV.x >= sera_screen_bounds.x &&
            UV.y >= sera_screen_bounds.y &&
            UV.x <= sera_screen_bounds.z &&
            UV.y <= sera_screen_bounds.w;
        bool room = center_id.r >= 0.06;
        if (near_sera || room) {
            float outside_width = max(1.0, sera_stroke_px - 1.0);
            float outside_distance = 99.0;
            float room_distance = 99.0;
            for (int radius = 1; radius <= 3; radius++) {
                // Architecture alone never needs more than the original 2px.
                if (radius > 2 && !near_sera) {
                    break;
                }
                for (int direction = 0; direction < 8; direction++) {
                    vec2 offset = sample_offset(radius, direction);
                    float distance_px = length(offset);
                    if (distance_px > max(stroke_px, outside_width) + 0.5) {
                        continue;
                    }
                    // Radius-2 diagonals complete the 3px exterior curve.
                    // Radius-3 diagonals are beyond 3px and never sampled.
                    if (direction >= 4 && (radius > 2 || !near_sera &&
                            radius > 1)) {
                        continue;
                    }
                    vec3 neighbor_id = id_at(UV + offset * mesh_id_texel);
                    if (near_sera && is_sera(neighbor_id)) {
                        outside_distance = min(outside_distance, distance_px);
                    }
                    if (room && room_mismatch(center_id, neighbor_id)) {
                        room_distance = min(room_distance, distance_px);
                    }
                }
                if (room_distance <= 1.0 && (!near_sera ||
                        outside_distance <= 1.0)) {
                    break;
                }
            }
            coverage = max(solid_coverage(room_distance, stroke_px),
                solid_coverage(outside_distance, outside_width));
        }
    }
    COLOR = vec4(ink_color.rgb, ink_color.a * coverage);
}
