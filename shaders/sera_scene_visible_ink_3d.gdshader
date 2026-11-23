shader_type spatial;
// Screen-space ID ink in the TRANSPARENT 3D stage, before all authored VFX.
// Unlike CanvasLayer ink, foreground alpha smoke, sparks and light shafts
// naturally paint over these lines without an extra effect-mask viewport.
// Opaque objects and hidden parts were resolved in the ID depth pass.
render_mode unshaded, fog_disabled, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
// BASE only: soften opaque black strokes within 2 screen pixels of a real
// emissive ID=7 surface. Other scenes retain completely opaque strokes.
uniform float emissive_contact_alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ink_screen_bounds = vec4(0.0);
// All shared-scene outer contours fit in a 3px Euclidean disk.
uniform float main_inside_px = 1.0;
uniform float main_outside_px = 3.0;
uniform float main_seam_px = 3.0;
// Dense BASE machinery used to flood small faces with 3px ID seams.
// Facility contour: 1px inside and 3px outside with 1px contacts.
// Clutter keeps its dedicated 1px inside/1px outside style.
uniform float facility_inside_px = 1.0;
uniform float facility_outside_px = 3.0;
uniform float facility_seam_px = 1.0;
uniform float clutter_inside_px = 1.0;
uniform float clutter_outside_px = 1.0;
uniform float clutter_seam_px = 2.0;
// CRATE has its own 1px interior/1px exterior/1px contact ink.
uniform float crate_inside_px = 1.0;
uniform float crate_outside_px = 1.0;
uniform float crate_seam_px = 1.0;
// Live 3D equipment previews share the NEXUS 1/2/2 rule, distinct from
// battle actor defaults. IRIS uses its own equivalent six-ID canvas pass.
uniform float part_inside_px = 1.0;
uniform float part_outside_px = 2.0;
uniform float part_seam_px = 2.0;

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
    // 4=GRID, 5=CRATE, 6=part preview; 7=emissive protection.
    // The reserved role 7 is a visible depth surface but NEVER ink.
    if (id_value.g < 0.06) {
        return 0;
    }
    return clamp(int(floor(id_value.g * 8.0 + 0.5)), 1, 7);
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

// Use the same hard Euclidean pixel disk as NEXUS. Fractional alpha was
// responsible for grey fringes, and eight-axis-only samples cause bulges.
// A full disk is needed for 3px actor seams and facility silhouettes.
bool inside_radius(int distance_squared, float width_px) {
    return float(distance_squared) <= width_px * width_px + 0.001;
}

void fragment() {
    vec2 pixel_uv = SCREEN_UV;
    vec3 center = sample_id(pixel_uv);
    int center_role = role_of(center);
    // Architectural emission and physical glowing lamp glass are opaque,
    // but their ID pixels must not be blackened by neighboring facility borders.
    // Keep them in the same depth-resolved ID buffer; no extra viewport.
    if (center_role == 7) {
        discard;
    }
    float coverage = 0.0;

    if (center_role != 0) {
        bool facility = center_role == 2;
        bool clutter = center_role == 3;
        bool crate = center_role == 5;
        bool part = center_role == 6;
        float inner_width = part ? part_inside_px :
            (crate ? crate_inside_px :
            (clutter ? clutter_inside_px :
            (facility ? facility_inside_px : main_inside_px)));
        float seam_width = part ? part_seam_px :
            (crate ? crate_seam_px :
            (clutter ? clutter_seam_px :
            (facility ? facility_seam_px : main_seam_px)));

        bool inner_hit = false;
        bool seam_hit = false;
        float max_width = max(inner_width, seam_width);
        for (int ring = 1; ring <= 3; ring++) {
            if (float(ring) > max_width + 0.001) {
                break;
            }
            for (int dy = -ring; dy <= ring; dy++) {
                for (int dx = -ring; dx <= ring; dx++) {
                    if (max(abs(dx), abs(dy)) != ring) {
                        continue;
                    }
                    int d2 = dx * dx + dy * dy;
                    if (!inside_radius(d2, max_width)) {
                        continue;
                    }
                    vec2 offset = vec2(float(dx), float(dy));
                    vec3 other = sample_id(pixel_uv + offset * mesh_id_texel);
                    int other_role = role_of(other);
                    if (other_role == 0) {
                        if (inside_radius(d2, inner_width)) {
                            inner_hit = true;
                        }
                    } else if (other_role != 7 &&
                            !same_visible_id(center, other) &&
                            owns_contact(center, other) &&
                            inside_radius(d2, seam_width)) {
                        // One owner per visible contact: no double-thick seam.
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
        coverage = (inner_hit || seam_hit) ? 1.0 : 0.0;
    } else {
        // The ground, backdrop and non-ink objects still write depth with
        // role zero, so hidden actors do not emit ink through the floor.
        // All outside ink stays near the projected screen bounds; no
        // fullscreen ID dilation when the object is far off-screen.
        bool near_visible = ink_screen_bounds.z > ink_screen_bounds.x &&
            ink_screen_bounds.w > ink_screen_bounds.y &&
            pixel_uv.x >= ink_screen_bounds.x &&
            pixel_uv.x <= ink_screen_bounds.z &&
            pixel_uv.y >= ink_screen_bounds.y &&
            pixel_uv.y <= ink_screen_bounds.w;
        if (near_visible) {
            // 3px is the maximum outside width in every shared scene.
            // No additional fourth ring or facility-only bounds pass.
            for (int ring = 1; ring <= 3; ring++) {
                for (int dy = -ring; dy <= ring; dy++) {
                    for (int dx = -ring; dx <= ring; dx++) {
                        if (max(abs(dx), abs(dy)) != ring) {
                            continue;
                        }
                        int d2 = dx * dx + dy * dy;
                        vec2 offset = vec2(float(dx), float(dy));
                        int neighbor_role = role_of(sample_id(pixel_uv +
                            offset * mesh_id_texel));
                        if (neighbor_role == 0 || neighbor_role == 7) {
                            continue;
                        }
                        float outer_width = neighbor_role == 6 ?
                            part_outside_px : (neighbor_role == 5 ?
                            crate_outside_px : (neighbor_role == 3 ?
                            clutter_outside_px : (neighbor_role == 2 ?
                            facility_outside_px : main_outside_px)));
                        if (inside_radius(d2, outer_width)) {
                            coverage = 1.0;
                            break;
                        }
                    }
                    if (coverage > 0.0) {
                        break;
                    }
                }
                if (coverage > 0.0) {
                    break;
                }
            }
        }
    }

    // A 0-alpha transparent fullscreen quad caused dark tinted screens on
    // Compatibility devices. Never submit empty ink fragments for blending.
    if (coverage < 0.5) {
        discard;
    }
    float ink_alpha = ink_color.a;
    if (emissive_contact_alpha < 0.999) {
        // Sample only pixels that ALREADY have ink. Do not blur the full
        // screen or dim ink on buildings that have no adjacent emitters.
        bool next_to_emitter = false;
        for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
                if (dx * dx + dy * dy > 4) {
                    continue;
                }
                vec2 shift = vec2(float(dx), float(dy));
                if (role_of(sample_id(pixel_uv + shift * mesh_id_texel)) == 7) {
                    next_to_emitter = true;
                    break;
                }
            }
            if (next_to_emitter) {
                break;
            }
        }
        if (next_to_emitter) {
            ink_alpha *= emissive_contact_alpha;
        }
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_alpha;
}
