shader_type spatial;
// Screen-space ID ink in the TRANSPARENT 3D stage, before all authored VFX.
// Unlike CanvasLayer ink, foreground alpha smoke, sparks and light shafts
// naturally paint over these lines without an extra effect-mask viewport.
// Opaque objects and hidden parts were resolved in the ID depth pass.
render_mode unshaded, fog_disabled, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform vec4 ink_screen_bounds = vec4(0.0);
uniform float main_inside_px = 1.0;
uniform float main_outside_px = 3.0;
uniform float main_seam_px = 3.0;
// Dense BASE machinery used to flood small faces with 3px ID seams.
// Retain its 1px inside contour, but move only 2px outside, and keep
// same-screen visible component contacts to 1px.
uniform float facility_inside_px = 1.0;
uniform float facility_outside_px = 2.0;
uniform float facility_seam_px = 1.0;
uniform float clutter_inside_px = 1.0;
uniform float clutter_outside_px = 1.0;
uniform float clutter_seam_px = 2.0;

void vertex() {
    // QuadMesh defaults to a 1x1 rectangle; VERTEX.xy is -0.5..0.5.
    // POSITION bypasses camera transforms. Godot 4.3+ uses reversed Z:
    // a fullscreen near-plane quad is z=1.0, never the former z=0.0.
    // A source mesh UV is not an authoritative screen coordinate.
    POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

vec3 sample_id(vec2 pixel_uv) {
    if (pixel_uv.x < 0.0 || pixel_uv.x >= 1.0 ||
            pixel_uv.y < 0.0 || pixel_uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, pixel_uv).rgb;
}

int role_of(vec3 id_value) {
    // G encodes render class: 1=actor, 2=facility, 3=small prop,
    // 4=power GRID. R/B identify frontmost individual meshes/instances.
    if (id_value.g < 0.06) {
        return 0;
    }
    return clamp(int(floor(id_value.g * 8.0 + 0.5)), 1, 4);
}

bool same_visible_id(vec3 a, vec3 b) {
    return abs(a.g - b.g) < 0.05 && abs(a.r - b.r) < 0.0078 &&
        abs(a.b - b.b) < 0.0078;
}

bool owns_contact(vec3 a, vec3 b) {
    if (abs(a.g - b.g) > 0.05) {
        return a.g > b.g;
    }
    if (abs(a.b - b.b) > 0.0078) {
        return a.b > b.b;
    }
    return a.r > b.r + 0.0078;
}

vec2 neighbor_offset(int r, int d) {
    float n = float(r);
    if (d == 0) { return vec2(n, 0.0); }
    if (d == 1) { return vec2(-n, 0.0); }
    if (d == 2) { return vec2(0.0, n); }
    if (d == 3) { return vec2(0.0, -n); }
    if (d == 4) { return vec2(n, n); }
    if (d == 5) { return vec2(-n, n); }
    if (d == 6) { return vec2(n, -n); }
    return vec2(-n, -n);
}

float fill_px(float distance_px, float stroke) {
    return clamp((stroke + 0.5 - distance_px) / 0.5, 0.0, 1.0);
}

void fragment() {
    // Pixel coordinates must match the depth-resolved ID camera exactly.
    vec2 pixel_uv = SCREEN_UV;
    vec3 center = sample_id(pixel_uv);
    int center_role = role_of(center);
    float coverage = 0.0;
    if (center_role != 0) {
        bool small = center_role == 3;
        bool facility = center_role == 2;
        float in_px = small ? clutter_inside_px :
            (facility ? facility_inside_px : main_inside_px);
        float seam_px = small ? clutter_seam_px :
            (facility ? facility_seam_px : main_seam_px);
        float to_empty = 99.0;
        float to_contact = 99.0;
        // Sample only the reachable 3px neighborhood. No ID readback.
        for (int r = 1; r <= 3; r++) {
            if (float(r) > max(in_px, seam_px) + 0.5) {
                break;
            }
            for (int d = 0; d < 8; d++) {
                if (d >= 4 && float(r) * 1.414214 >
                        max(in_px, seam_px) + 0.5) {
                    break;
                }
                vec2 off = neighbor_offset(r, d);
                vec3 neighbor = sample_id(pixel_uv + off * mesh_id_texel);
                int next_role = role_of(neighbor);
                float distance_px = length(off);
                if (next_role == 0) {
                    to_empty = min(to_empty, distance_px);
                } else if (!same_visible_id(center, neighbor) &&
                        owns_contact(center, neighbor)) {
                    to_contact = min(to_contact, distance_px);
                }
            }
            if (to_empty <= 1.0 && to_contact <= 1.0) {
                break;
            }
        }
        coverage = max(fill_px(to_empty, in_px),
            fill_px(to_contact, seam_px));
    } else {
        // Empty ID: draw outside ink ONLY near visible marked geometry.
        // The screen bounds are conservatively projected from source AABBs.
        if (pixel_uv.x >= ink_screen_bounds.x &&
                pixel_uv.x <= ink_screen_bounds.z &&
                pixel_uv.y >= ink_screen_bounds.y &&
                pixel_uv.y <= ink_screen_bounds.w) {
            for (int r = 1; r <= 3; r++) {
                for (int d = 0; d < 8; d++) {
                    if (d >= 4 && r == 3) {
                        break;
                    }
                    vec2 off = neighbor_offset(r, d);
                    vec3 neighbor = sample_id(pixel_uv + off * mesh_id_texel);
                    int next_role = role_of(neighbor);
                    if (next_role == 0) {
                        continue;
                    }
                    float width_px = next_role == 3 ?
                        clutter_outside_px : (next_role == 2 ?
                        facility_outside_px : main_outside_px);
                    coverage = max(coverage, fill_px(length(off), width_px));
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
    // Do not send a fullscreen mesh to alpha blending for zero-ink
    // pixels. Some mobile Compatibility paths otherwise show dark fills
    // where the intended outline has no coverage at all.
    if (coverage <= 0.0) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = coverage * ink_color.a;
}
