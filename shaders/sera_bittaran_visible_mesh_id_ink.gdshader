shader_type spatial;
// Bittaran-only depth-resolved visible mesh-ID ink. Every visible
// MeshInstance3D receives ONE RGB identity in the existing shared ID pass.
// Only a change of visible mesh identity can ink. Background never does.
// Geometry face bends and convex corners within one mesh NEVER produce ink.
render_mode unshaded, fog_disabled, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
// Bittaran-only mesh contact radius, in actual ID viewport pixels.
uniform float main_seam_px = 2.0;

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

// Only one side of an ID-to-ID contact paints two pixels.
// Without an owner, two neighboring 2px bands would overlap.
bool owns_contact(vec3 a, vec3 b) {
    if (abs(a.b - b.b) > 0.0078) {
        return a.b > b.b;
    }
    return a.r > b.r + 0.0078;
}

bool in_disk(int squared_distance, float width_px) {
    return float(squared_distance) <= width_px * width_px + 0.001;
}

// Dedicated ID contact pass: NO background/outer silhouette sampling.
// GPU ribbons own the silhouette; this only resolves visible mesh contacts.
// One-sided 2px ownership prevents an 8px double band at adjacent IDs.
void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 center = sample_id(uv);
    if (role_of(center) != 1) {
        discard;
    }

    bool draw_ink = false;
    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
            int distance_squared = dx * dx + dy * dy;
            if (distance_squared == 0 ||
                    !in_disk(distance_squared, main_seam_px)) {
                continue;
            }
            vec3 neighbor = sample_id(uv +
                vec2(float(dx), float(dy)) * mesh_id_texel);
            if (role_of(neighbor) == 1 &&
                    !same_id(center, neighbor) &&
                    owns_contact(center, neighbor)) {
                draw_ink = true;
                break;
            }
        }
        if (draw_ink) {
            break;
        }
    }
    if (!draw_ink) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
