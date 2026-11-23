shader_type spatial;
// Offline 512px equipment-icon ONLY. Never substitute for the runtime NEXUS ink.
// One depth-resolved RGB mesh-ID pass supplies the 1px inner silhouette,
// 4px outer silhouette, and 2px one-sided mesh-contact seams.
render_mode unshaded, fog_disabled, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.001953125);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float sera_inner_px : hint_range(0.0, 3.0) = 1.0;
uniform float sera_outer_px : hint_range(0.0, 8.0) = 4.0;
uniform float sera_seam_px : hint_range(0.5, 3.0) = 2.0;
// The live compositor projects bounds padded by 3px. Allow an additional
// 4px in the capture shader so the new 4px exterior is never clipped.
uniform vec4 sera_screen_bounds = vec4(0.0);

void vertex() {
    POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec3 visible_id(vec2 uv) {
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, uv).rgb;
}

bool is_part(vec3 id_value) {
    return id_value.g >= 0.06;
}

bool owns_contact(vec3 center_id, vec3 other_id) {
    if (abs(center_id.b - other_id.b) > 0.06) {
        return center_id.b > other_id.b;
    }
    if (abs(center_id.g - other_id.g) > 0.06) {
        return center_id.g > other_id.g;
    }
    return center_id.r > other_id.r + 0.06;
}

bool within_disk(int dx, int dy, float radius) {
    return float(dx * dx + dy * dy) <= radius * radius + 0.001;
}

void fragment() {
    vec3 center = visible_id(SCREEN_UV);
    bool center_part = is_part(center);
    float coverage = 0.0;

    if (center_part) {
        for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
                if ((dx == 0 && dy == 0) ||
                        !within_disk(dx, dy, max(sera_inner_px, sera_seam_px))) {
                    continue;
                }
                vec3 other = visible_id(SCREEN_UV +
                    vec2(float(dx), float(dy)) * mesh_id_texel);
                if (!is_part(other)) {
                    if (within_disk(dx, dy, sera_inner_px)) {
                        coverage = 1.0;
                    }
                } else if (owns_contact(center, other) &&
                        within_disk(dx, dy, sera_seam_px)) {
                    coverage = 1.0;
                }
                if (coverage > 0.5) {
                    break;
                }
            }
            if (coverage > 0.5) {
                break;
            }
        }
    } else if (center.r < 0.06 && center.g < 0.06 && center.b < 0.06) {
        // Do not draw ink through non-part depth-mask objects.
        vec2 margin = 4.0 * mesh_id_texel;
        bool near_part =
            SCREEN_UV.x >= sera_screen_bounds.x - margin.x &&
            SCREEN_UV.y >= sera_screen_bounds.y - margin.y &&
            SCREEN_UV.x <= sera_screen_bounds.z + margin.x &&
            SCREEN_UV.y <= sera_screen_bounds.w + margin.y;
        if (near_part) {
            for (int dy = -4; dy <= 4; dy++) {
                for (int dx = -4; dx <= 4; dx++) {
                    if ((dx == 0 && dy == 0) ||
                            !within_disk(dx, dy, sera_outer_px)) {
                        continue;
                    }
                    vec3 other = visible_id(SCREEN_UV +
                        vec2(float(dx), float(dy)) * mesh_id_texel);
                    if (is_part(other)) {
                        coverage = 1.0;
                        break;
                    }
                }
                if (coverage > 0.5) {
                    break;
                }
            }
        }
    }

    if (coverage < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
