// Shared, canonical visible-mesh RGB-ID contour algorithm.
// Included verbatim by the spatial and preview-canvas presentation shaders.
// No topology, convex-angle detection, extra mask or separate IRIS palette.
// All scenes sample the SAME depth-resolved RGB12 visible IDs at 1:1 pixels;
// the only differences are numeric widths/profile and drawing stage.
uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform vec4 ink_screen_bounds = vec4(0.0);
uniform float emissive_contact_alpha : hint_range(0.0, 1.0) = 1.0;
// 0=BASE/training/part, 1=Bittaran, 2=NEXUS. All share the same algorithm.
uniform int scene_profile = 0;
// Existing per-element settings. None of these change the ID processing path.
uniform float main_inside_px = 1.0;
uniform float main_outside_px = 3.0;
uniform float main_seam_px = 3.0;
uniform float facility_inside_px = 0.0;
uniform float facility_outside_px = 3.0;
uniform float facility_seam_px = 2.0;
uniform float clutter_inside_px = 0.0;
uniform float clutter_outside_px = 1.0;
uniform float clutter_seam_px = 1.0;
uniform float crate_inside_px = 1.0;
uniform float crate_outside_px = 1.0;
uniform float crate_seam_px = 1.0;
uniform float part_inside_px = 1.0;
uniform float part_outside_px = 2.0;
uniform float part_seam_px = 2.0;

vec3 sera_sample_visible_id(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) {
        return vec3(0.0);
    }
    return texture(mesh_id_texture, uv).rgb;
}

int sera_role_of(vec3 id_value) {
    if (id_value.g < 0.06) {
        return 0;
    }
    return clamp(int(floor(id_value.g * 8.0 + 0.5)), 1, 7);
}

bool sera_same_visible_id(vec3 a, vec3 b) {
    return abs(a.g - b.g) < 0.05 &&
        abs(a.r - b.r) < 0.0078 && abs(a.b - b.b) < 0.0078;
}

bool sera_owns_contact(vec3 a, vec3 b) {
    // The Bittaran single-role rule is unchanged (blue, then red).
    // For multi-role scenes the green role is the stable first key.
    if (abs(a.g - b.g) > 0.05) {
        return a.g > b.g;
    }
    if (abs(a.b - b.b) > 0.0078) {
        return a.b > b.b;
    }
    return a.r > b.r + 0.0078;
}

bool sera_in_disk(int distance_squared, float width_px) {
    return float(distance_squared) <= width_px * width_px + 0.001;
}

float sera_inner_width(int role) {
    if (role == 2) { return facility_inside_px; }
    if (role == 3) { return clutter_inside_px; }
    if (role == 5) { return crate_inside_px; }
    if (role == 6) { return part_inside_px; }
    if (role == 1 && scene_profile == 1) { return 0.0; }
    if (role == 1 && scene_profile == 2) { return 1.0; }
    return main_inside_px;
}

float sera_outer_width(int role) {
    if (role == 2) {
        return scene_profile == 2 ? 2.0 : facility_outside_px;
    }
    if (role == 3) { return clutter_outside_px; }
    if (role == 5) { return crate_outside_px; }
    if (role == 6) { return part_outside_px; }
    if (role == 1 && scene_profile == 2) { return 2.0; }
    return main_outside_px;
}

float sera_seam_width(int role) {
    if (role == 2) {
        return scene_profile == 2 ? 2.0 : facility_seam_px;
    }
    if (role == 3) { return clutter_seam_px; }
    if (role == 5) { return crate_seam_px; }
    if (role == 6) { return part_seam_px; }
    if (role == 1 && scene_profile == 1) { return 1.0; }
    if (role == 1 && scene_profile == 2) { return 2.0; }
    return main_seam_px;
}

// Bittaran's full Euclidean-disk search, one-sided contact ownership,
// background-only outer ring and solid rasterized output are identical for
// every render role. Return the ink alpha, or 0 for discard.
float sera_visible_id_ink_alpha(vec2 uv) {
    vec3 center = sera_sample_visible_id(uv);
    int role = sera_role_of(center);
    if (role == 7) {
        return 0.0;
    }
    bool draw_ink = false;
    if (role != 0) {
        float inner_px = sera_inner_width(role);
        float seam_px = sera_seam_width(role);
        // The Bittaran pass uses a 1px 4-neighbor disk for its contacts,
        // but wider scene-specific contacts use the SAME disk predicate.
        int search_radius = int(ceil(max(inner_px, seam_px)));
        for (int dy = -search_radius; dy <= search_radius; dy++) {
            for (int dx = -search_radius; dx <= search_radius; dx++) {
                int d2 = dx * dx + dy * dy;
                if (d2 == 0 ||
                        !sera_in_disk(d2, max(inner_px, seam_px))) {
                    continue;
                }
                vec3 neighbor = sera_sample_visible_id(uv +
                    vec2(float(dx), float(dy)) * mesh_id_texel);
                int other_role = sera_role_of(neighbor);
                if (other_role == 0 &&
                        sera_in_disk(d2, inner_px)) {
                    draw_ink = true;
                    break;
                }
                if (other_role > 0 && other_role != 7 &&
                        !sera_same_visible_id(center, neighbor) &&
                        sera_owns_contact(center, neighbor) &&
                        sera_in_disk(d2, seam_px)) {
                    draw_ink = true;
                    break;
                }
            }
            if (draw_ink) { break; }
        }
    } else {
        // As in Bittaran, only the projected bounds of styled geometry can
        // receive outer ink; floors/hidden actors remain role-zero occluders.
        if (ink_screen_bounds.z <= ink_screen_bounds.x ||
                ink_screen_bounds.w <= ink_screen_bounds.y ||
                uv.x < ink_screen_bounds.x || uv.x > ink_screen_bounds.z ||
                uv.y < ink_screen_bounds.y || uv.y > ink_screen_bounds.w) {
            return 0.0;
        }
        for (int dy = -3; dy <= 3; dy++) {
            for (int dx = -3; dx <= 3; dx++) {
                int d2 = dx * dx + dy * dy;
                if (d2 == 0 || !sera_in_disk(d2, 3.0)) {
                    continue;
                }
                vec3 neighbor = sera_sample_visible_id(uv +
                    vec2(float(dx), float(dy)) * mesh_id_texel);
                int other_role = sera_role_of(neighbor);
                if (other_role != 0 && other_role != 7 &&
                        sera_in_disk(d2, sera_outer_width(other_role))) {
                    draw_ink = true;
                    break;
                }
            }
            if (draw_ink) { break; }
        }
    }
    if (!draw_ink) {
        return 0.0;
    }
    float alpha = ink_color.a;
    // BASE's existing emissive protection is an opacity SETTING only.
    // It does not alter ID visibility, depth resolution or line ownership.
    if (emissive_contact_alpha < 0.999) {
        bool adjacent_emission = false;
        for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
                if (!sera_in_disk(dx * dx + dy * dy, 2.0)) {
                    continue;
                }
                vec2 offset = vec2(float(dx), float(dy));
                if (sera_role_of(sera_sample_visible_id(
                        uv + offset * mesh_id_texel)) == 7) {
                    adjacent_emission = true;
                    break;
                }
            }
            if (adjacent_emission) { break; }
        }
        if (adjacent_emission) {
            alpha *= emissive_contact_alpha;
        }
    }
    return alpha;
}
