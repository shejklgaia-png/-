shader_type spatial;
// NEXUS SERA-only silhouette: RGB visible-mesh IDs, resolved by one
// existing SERA viewport. Room, floor and pad have blue-only occluder IDs
// in that SAME depth pass but never emit any pixel ink.
// Room 2px polygon edges are now drawn on original 3D surfaces, not here.
render_mode unshaded, fog_disabled, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 2.0; // Legacy API compatibility.
uniform float sera_inner_px : hint_range(0.0, 3.0) = 1.0;
uniform float sera_outer_px : hint_range(0.0, 8.0) = 2.0;
uniform float sera_seam_px : hint_range(0.5, 3.0) = 2.0;
uniform vec4 sera_screen_bounds = vec4(0.0);

void vertex() {
    // Align with the displayed 3D view; foreground VFX still draw afterward.
    POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec3 visible_id(vec2 uv) {
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, uv).rgb;
}

bool is_sera(vec3 id_value) {
    // SERA's RGB contact IDs have G >= 1/8. No room surface does.
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
    bool center_sera = is_sera(center);
    float coverage = 0.0;

    if (center_sera) {
        // Inside silhouette is 1px, visible independent mesh contacts 2px.
        // The single ID depth pass already removed all hidden mesh contacts.
        for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
                if ((dx == 0 && dy == 0) ||
                        !within_disk(dx, dy, max(sera_inner_px, sera_seam_px))) {
                    continue;
                }
                vec3 other = visible_id(SCREEN_UV +
                    vec2(float(dx), float(dy)) * mesh_id_texel);
                if (!is_sera(other)) {
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
        // Exterior 2px is only allowed on actual empty ID background.
        // Opaque architectural ID (0,0,1) NEVER receives an outside stroke.
        bool near_sera = SCREEN_UV.x >= sera_screen_bounds.x &&
            SCREEN_UV.y >= sera_screen_bounds.y &&
            SCREEN_UV.x <= sera_screen_bounds.z &&
            SCREEN_UV.y <= sera_screen_bounds.w;
        if (near_sera) {
            for (int dy = -2; dy <= 2; dy++) {
                for (int dx = -2; dx <= 2; dx++) {
                    if ((dx == 0 && dy == 0) ||
                            !within_disk(dx, dy, sera_outer_px)) {
                        continue;
                    }
                    vec3 other = visible_id(SCREEN_UV +
                        vec2(float(dx), float(dy)) * mesh_id_texel);
                    if (is_sera(other)) {
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

    // Avoid a transparent fullscreen tint in Compatibility rendering.
    if (coverage < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
