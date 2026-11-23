shader_type canvas_item;
// NEXUS: 1px inner / 2px outer, fully opaque, depth-resolved silhouette.
// Use an exact Euclidean pixel radius; no fractional grey anti-alias fringe.
// Visible mesh-to-mesh contact seams use a 2px hard Euclidean radius, on one mesh only.
// No obscured contours or camera-facing geometric convex creases are drawn.
// Outside pixels are sampled only within the projected SERA screen bounds.
render_mode blend_mix;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667, 0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 2.0; // NEXUS architecture
uniform float sera_inner_px : hint_range(0.0, 3.0) = 1.0;
uniform float sera_outer_px : hint_range(0.0, 8.0) = 2.0;
uniform float sera_seam_px : hint_range(0.5, 3.0) = 2.0;
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

// A blue-only ID is a solid room panel that hides contours but creates none.
// Unlike empty background, it must never receive a dilated SERA stroke.
bool is_room_depth_mask(vec3 mesh_id) {
    return mesh_id.b > 0.96 && mesh_id.g < 0.06 && mesh_id.r < 0.06;
}

// One-sided ordering keeps the 2px contact seam on only one mesh.
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

// SERA ink is binary, including diagonal pixels. A hard Euclidean radius
// avoids grey halos and 1px seams that thicken at diagonal corners.
float sera_coverage(float distance_px, float width_px) {
    return distance_px <= width_px + 0.001 ? 1.0 : 0.0;
}

void fragment() {
    vec3 center_id = id_at(UV);
    bool center_sera = is_sera(center_id);
    float coverage = 0.0;

    if (center_sera) {
        float inner_distance = 99.0;
        float seam_distance = 99.0;
        // Inner silhouette stays 1px. Contact seams extend to a 2px
        // radius, requiring two sample rings with no alpha/grey fringe.
        for (int radius = 1; radius <= 2; radius++) {
            for (int direction = 0; direction < 8; direction++) {
                vec2 offset = sample_offset(radius, direction);
                float distance_px = length(offset);
                if (distance_px > max(sera_inner_px, sera_seam_px) + 0.001) {
                    continue;
                }
                vec3 neighbor_id = id_at(UV + offset * mesh_id_texel);
                if (!is_sera(neighbor_id)) {
                    inner_distance = min(inner_distance, distance_px);
                } else if (distance_px <= sera_seam_px + 0.001 &&
                        owns_contact(center_id, neighbor_id)) {
                    seam_distance = min(seam_distance, distance_px);
                }
            }
            if (inner_distance <= 1.0 && seam_distance <= 1.0) {
                break;
            }
        }
        coverage = max(sera_coverage(inner_distance, sera_inner_px),
            sera_coverage(seam_distance, sera_seam_px));
    } else {
        // Render architecture borders at 2px when a room ID is present.
        // The room also covers the wall BEHIND SERA, so room ID must not
        // prevent the nearby 2px SERA silhouette from being drawn.
        bool room = center_id.r >= 0.06;
        if (room) {
            float room_distance = 99.0;
            for (int radius = 1; radius <= 2; radius++) {
                for (int direction = 0; direction < 8; direction++) {
                    vec2 offset = sample_offset(radius, direction);
                    float distance_px = length(offset);
                    if (distance_px > stroke_px + 0.001) {
                        continue;
                    }
                    vec3 neighbor_id = id_at(UV + offset * mesh_id_texel);
                    if (room_mismatch(center_id, neighbor_id)) {
                        room_distance = min(room_distance, distance_px);
                    }
                }
                if (room_distance <= 1.0) {
                    break;
                }
            }
            coverage = solid_coverage(room_distance, stroke_px);
        }
        // Only extend the SERA outside silhouette onto actual background.
        // Never stamp it on a visible NEXUS room surface: that makes ink
        // appear to pass through floor panels, walls and stage geometry.
        if (coverage < 1.0 && !room && !is_room_depth_mask(center_id)) {
            // The 2px SERA outline is an exact opaque Euclidean disk.
            // Sample both mixed directions (1,2), (3,4), etc. Previous
            // eight-direction-only sampling can make a thick stroke uneven.
            // Work only inside the projected and padded SERA bounds.
            bool near_sera = UV.x >= sera_screen_bounds.x &&
                UV.y >= sera_screen_bounds.y &&
                UV.x <= sera_screen_bounds.z &&
                UV.y <= sera_screen_bounds.w;
            if (near_sera) {
                float radius_squared = sera_outer_px * sera_outer_px;
                // Search nearest neighborhoods first and stop on the first
                // visible SERA ID; all outside pixels are fully opaque.
                for (int ring = 1; ring <= 2; ring++) {
                    if (float(ring - 1) >= sera_outer_px) {
                        break;
                    }
                    for (int dy = -ring; dy <= ring; dy++) {
                        for (int dx = -ring; dx <= ring; dx++) {
                            if (max(abs(dx), abs(dy)) != ring) {
                                continue;
                            }
                            int distance_squared = dx * dx + dy * dy;
                            if (float(distance_squared) > radius_squared + 0.001) {
                                continue;
                            }
                            vec2 offset = vec2(float(dx), float(dy));
                            if (is_sera(id_at(UV + offset * mesh_id_texel))) {
                                coverage = 1.0;
                                break;
                            }
                        }
                        if (coverage >= 1.0) {
                            break;
                        }
                    }
                    if (coverage >= 1.0) {
                        break;
                    }
                }
            }
        }
    }
    COLOR = vec4(ink_color.rgb, ink_color.a * coverage);
}
