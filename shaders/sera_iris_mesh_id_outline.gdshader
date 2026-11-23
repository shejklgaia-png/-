shader_type canvas_item;
// HEAD D: same depth-resolved visible-ID contour law as NEXUS full-body.
// Six authored meshes retain their dedicated one-viewport red-ID pass.
// 1px inside / 2px outside / 2px one-sided contacts, all fully opaque.
render_mode blend_mix;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667, 0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 3.0; // Legacy caller compatibility
uniform float iris_inner_px : hint_range(0.0, 3.0) = 1.0;
uniform float iris_outer_px : hint_range(0.0, 3.0) = 2.0;
uniform float iris_seam_px : hint_range(0.0, 3.0) = 2.0;

float id_at(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return 0.0;
    }
    return texture(mesh_id_texture, uv).r;
}

bool solid_radius(int d2, float width_px) {
    return float(d2) <= width_px * width_px + 0.001;
}

void fragment() {
    float center = id_at(UV);
    bool inside = center >= 0.06;
    bool stroke = false;
    if (inside) {
        bool inner_hit = false;
        bool seam_hit = false;
        for (int ring = 1; ring <= 2; ring++) {
            float active_width = max(iris_inner_px, iris_seam_px);
            if (float(ring) > active_width + 0.001) {
                break;
            }
            for (int dy = -ring; dy <= ring; dy++) {
                for (int dx = -ring; dx <= ring; dx++) {
                    if (max(abs(dx), abs(dy)) != ring) {
                        continue;
                    }
                    int d2 = dx * dx + dy * dy;
                    if (!solid_radius(d2, active_width)) {
                        continue;
                    }
                    vec2 offset = vec2(float(dx), float(dy)) * mesh_id_texel;
                    float neighbor = id_at(UV + offset);
                    if (neighbor < 0.06) {
                        if (solid_radius(d2, iris_inner_px)) {
                            inner_hit = true;
                        }
                    } else if (neighbor + 0.05 < center &&
                            solid_radius(d2, iris_seam_px)) {
                        // Only the higher-ID mesh owns the shared seam.
                        seam_hit = true;
                    }
                    if (inner_hit && seam_hit) {
                        break;
                    }
                }
                if (inner_hit && seam_hit) {
                    break;
                }
            }
            if (inner_hit && seam_hit) {
                break;
            }
        }
        stroke = inner_hit || seam_hit;
    } else {
        for (int ring = 1; ring <= 2; ring++) {
            if (float(ring) > iris_outer_px + 0.001) {
                break;
            }
            for (int dy = -ring; dy <= ring; dy++) {
                for (int dx = -ring; dx <= ring; dx++) {
                    if (max(abs(dx), abs(dy)) != ring) {
                        continue;
                    }
                    int d2 = dx * dx + dy * dy;
                    if (!solid_radius(d2, iris_outer_px)) {
                        continue;
                    }
                    vec2 offset = vec2(float(dx), float(dy)) * mesh_id_texel;
                    if (id_at(UV + offset) >= 0.06) {
                        stroke = true;
                        break;
                    }
                }
                if (stroke) {
                    break;
                }
            }
            if (stroke) {
                break;
            }
        }
    }
    COLOR = vec4(ink_color.rgb, stroke ? ink_color.a : 0.0);
}
