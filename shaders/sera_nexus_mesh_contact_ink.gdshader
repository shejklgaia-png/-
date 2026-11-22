shader_type canvas_item;
// NEXUS only: one depth-resolved RGB-ID pass for SERA contours and room ink.
// The SERA outline draws INSIDE the front-most visible mesh, never X-ray.
// At a SERA-to-SERA contact only the higher RGB ID side owns the 3px stroke.
// SERA needs up to 20 sparse neighbor samples at 3px; room ink stays at 2px.
// Background ID 0 is rejected after one lookup.
render_mode blend_mix;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667, 0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
// Legacy 2px room ink stays unchanged; only NEXUS display-SERA is 3px.
uniform float stroke_px : hint_range(1.0, 3.0) = 2.0;
uniform float sera_stroke_px : hint_range(1.0, 3.0) = 3.0;

vec3 id_at(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, uv).rgb;
}

bool mismatch_for_center(vec3 center_id, vec3 neighbor_id, bool sera_contact) {
    bool neighbor_sera = neighbor_id.g >= 0.06;
    if (sera_contact) {
        if (!neighbor_sera) {
            // ID zero or an architectural surface is outside this visible
            // SERA mesh, so this pixel contributes its missing outer contour.
            return true;
        }
        // RGB digits are spaced 1/8 apart. Lexicographic ordering makes a
        // seam one-sided, avoiding the previous 2px+2px double stroke.
        if (abs(center_id.b - neighbor_id.b) > 0.06) {
            return center_id.b > neighbor_id.b;
        }
        if (abs(center_id.g - neighbor_id.g) > 0.06) {
            return center_id.g > neighbor_id.g;
        }
        return center_id.r > neighbor_id.r + 0.06;
    }
    // Keep the IRIS red-only architectural behavior while preventing room
    // ink from doubling the SERA-owned contact/outer stroke.
    if (neighbor_sera) {
        return false;
    }
    if (neighbor_id.r < 0.06) {
        return true;
    }
    return neighbor_id.r + 0.05 < center_id.r;
}

void fragment() {
    vec3 center_id = id_at(UV);
    bool sera_contact = center_id.g >= 0.06;
    float coverage = 0.0;
    if (sera_contact || center_id.r >= 0.06) {
        float width_px = sera_contact ? sera_stroke_px : stroke_px;
        float nearest_dist = 99.0;
        // Four compass rays at 1, 2, 3 and 4px, plus diagonals at 1,
        // sqrt(8) and sqrt(18)px. No full 9x9 neighborhood scan.
        // A 2px room stroke stops after its 12 nearest candidates.
        for (int radius = 1; radius <= 4; radius++) {
            float axial_dist = float(radius);
            if (axial_dist > width_px + 0.5) {
                break;
            }
            for (int direction = 0; direction < 8; direction++) {
                if (direction >= 4 && float(radius) * 1.41421356 >
                        width_px + 0.5) {
                    break;
                }
                vec2 offset = vec2(0.0);
                float step_px = float(radius);
                if (direction == 0) {
                    offset = vec2(step_px, 0.0);
                } else if (direction == 1) {
                    offset = vec2(-step_px, 0.0);
                } else if (direction == 2) {
                    offset = vec2(0.0, step_px);
                } else if (direction == 3) {
                    offset = vec2(0.0, -step_px);
                } else if (direction == 4) {
                    offset = vec2(step_px, step_px);
                } else if (direction == 5) {
                    offset = vec2(-step_px, step_px);
                } else if (direction == 6) {
                    offset = vec2(step_px, -step_px);
                } else {
                    offset = vec2(-step_px, -step_px);
                }
                if (mismatch_for_center(
                        center_id, id_at(UV + mesh_id_texel * offset),
                        sera_contact)) {
                    nearest_dist = min(nearest_dist, length(offset));
                    break;
                }
            }
            if (nearest_dist < width_px) {
                break;
            }
        }
        coverage = clamp((width_px + 0.5 - nearest_dist) / 0.5, 0.0, 1.0);
    }
    COLOR = vec4(ink_color.rgb, ink_color.a * coverage);
}
