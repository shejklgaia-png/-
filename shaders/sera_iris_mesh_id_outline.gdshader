shader_type canvas_item;
// HEAD D / NEXUS only. Never display the raw mesh ID buffer: the displayed
// TextureRect uses a transparent 1x1 placeholder for safe shader failure.
render_mode blend_mix;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667, 0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 3.0;

bool mismatched_id(float center_id, float neighbor_id) {
    if (neighbor_id < 0.06) {
        return true; // Outside silhouette: ink stays INSIDE this mesh.
    }
    // Keep only the higher ID side of a contact seam. Two 3px outlines
    // on opposite sides would create a misleading 6px band.
    return neighbor_id + 0.05 < center_id;
}

float id_at(vec2 uv) {
    // Outside the viewport is background, not the repeated last ID texel.
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return 0.0;
    }
    return texture(mesh_id_texture, uv).r;
}

void fragment() {
    float id = id_at(UV);
    float coverage = 0.0;
    if (id >= 0.06) {
        // Screen-space Euclidean disk, not Manhattan (four-axis) dilation.
        // The 3px solid footprint stays 3 pixels even at diagonal outlines.
        // sqrt(10) neighbors supply only a subpixel alpha fringe to join
        // staircase corners without resampling or blurring distinct IDs.
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
                    // Coverage is already exactly 1.0: no further fetches.
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
    // One composite pass, never double-blend connected part seams.
    // No fragment() early return: a shader failure cannot expose debug IDs.
    COLOR = vec4(ink_color.rgb, ink_color.a * coverage);
}
