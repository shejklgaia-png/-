shader_type spatial;
// Bittaran-only depth-resolved visible mesh-ID ink. Every visible
// MeshInstance3D receives ONE RGB identity in the existing shared ID pass.
// Only a change of visible mesh identity or object/background can ink.
// Geometry face bends and convex corners within one mesh NEVER produce ink.
render_mode unshaded, fog_disabled, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform vec4 ink_screen_bounds = vec4(0.0);
// Kept separate from all shared BASE/NEXUS/training defaults.
uniform float main_inside_px = 1.0;
uniform float main_outside_px = 5.0;
uniform float main_seam_px = 4.0;

void vertex() {
    // Same depth-independent full-screen quad used by the established
    // shared 3D ID compositor. It is placed before translucent battle FX.
    POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec3 sample_id(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, uv).rgb;
}

int role_of(vec3 value) {
    if (value.g < 0.06) {
        return 0;
    }
    return clamp(int(floor(value.g * 8.0 + 0.5)), 1, 7);
}

bool same_id(vec3 a, vec3 b) {
    return abs(a.g - b.g) < 0.05 &&
        abs(a.r - b.r) < 0.0078 &&
        abs(a.b - b.b) < 0.0078;
}

// Only one side of an ID-to-ID contact paints four pixels.
// Without an owner, two neighboring four-pixel bands become 8px thick.
bool owns_contact(vec3 a, vec3 b) {
    if (abs(a.b - b.b) > 0.0078) {
        return a.b > b.b;
    }
    return a.r > b.r + 0.0078;
}

bool in_disk(int squared_distance, float width_px) {
    return float(squared_distance) <= width_px * width_px + 0.001;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 center = sample_id(uv);
    int role = role_of(center);
    // Only visible actors and their empty background contribute to ink.
    // Do not introduce convex lines or ink on scenery/emissive VFX.
    if (role != 0 && role != 1) {
        discard;
    }

    bool draw_ink = false;
    if (role == 1) {
        // Inner silhouette: 1px. Contact: 4px owned by just one
        // mesh identity. The ID pass resolves depth and overlaps first.
        for (int dy = -4; dy <= 4; dy++) {
            for (int dx = -4; dx <= 4; dx++) {
                int distance_squared = dx * dx + dy * dy;
                if (distance_squared == 0 ||
                        !in_disk(distance_squared, max(main_inside_px, main_seam_px))) {
                    continue;
                }
                vec3 neighbor = sample_id(uv +
                    vec2(float(dx), float(dy)) * mesh_id_texel);
                int neighbor_role = role_of(neighbor);
                if (neighbor_role == 0 &&
                        in_disk(distance_squared, main_inside_px)) {
                    draw_ink = true;
                    break;
                }
                if (neighbor_role == 1 &&
                        !same_id(center, neighbor) &&
                        owns_contact(center, neighbor) &&
                        in_disk(distance_squared, main_seam_px)) {
                    draw_ink = true;
                    break;
                }
            }
            if (draw_ink) {
                break;
            }
        }
    } else {
        // 5px outside the visible silhouette, bounded to projected actors.
        // No full-screen background dilation on large mobile viewports.
        if (ink_screen_bounds.z <= ink_screen_bounds.x ||
                ink_screen_bounds.w <= ink_screen_bounds.y ||
                uv.x < ink_screen_bounds.x || uv.x > ink_screen_bounds.z ||
                uv.y < ink_screen_bounds.y || uv.y > ink_screen_bounds.w) {
            discard;
        }
        for (int dy = -5; dy <= 5; dy++) {
            for (int dx = -5; dx <= 5; dx++) {
                int distance_squared = dx * dx + dy * dy;
                if (distance_squared == 0 ||
                        !in_disk(distance_squared, main_outside_px)) {
                    continue;
                }
                vec3 neighbor = sample_id(uv +
                    vec2(float(dx), float(dy)) * mesh_id_texel);
                if (role_of(neighbor) == 1) {
                    draw_ink = true;
                    break;
                }
            }
            if (draw_ink) {
                break;
            }
        }
    }

    if (!draw_ink) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
