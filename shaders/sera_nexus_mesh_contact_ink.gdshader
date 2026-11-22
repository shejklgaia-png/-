shader_type canvas_item;
// NEXUS only: preserve the IRIS red-only architectural outlines but draw
// SERA ink ONLY between different front-most RGB mesh IDs (not empty space).
// The shared ID viewport performs hardware depth resolution before this pass.
render_mode blend_mix;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667, 0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 3.0;

vec3 id_at(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, uv).rgb;
}

bool mismatch_for_center(vec3 center_id, vec3 neighbor_id, bool sera_contact) {
    if (sera_contact) {
        // Discard hidden edges: both pixels must be actual visible SERA meshes.
        if (neighbor_id.g < 0.06) {
            return false;
        }
        vec3 diff = abs(center_id - neighbor_id);
        // 1/8 spaced IDs tolerate low-precision Compatibility color targets.
        return max(diff.r, max(diff.g, diff.b)) > 0.06;
    }
    // Preserve the working HEAD D / IRIS red-only architecture ink.
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
        float nearest_dist = 99.0;
        for (int dy = -3; dy <= 3; dy++) {
            for (int dx = -3; dx <= 3; dx++) {
                int distance_sq = dx * dx + dy * dy;
                if (distance_sq == 0 || distance_sq > 10) {
                    continue;
                }
                vec2 offset = mesh_id_texel * vec2(float(dx), float(dy));
                if (mismatch_for_center(
                        center_id, id_at(UV + offset), sera_contact)) {
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
