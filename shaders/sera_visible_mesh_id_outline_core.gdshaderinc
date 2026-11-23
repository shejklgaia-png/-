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
// 0=shared/default, 1=Bittaran, 2=NEXUS, 3=training.
// These are NUMERIC presets; the ID extraction algorithm is identical.
uniform int scene_profile = 0;
// Actual DISPLAY pixels occupied by one ID render-target pixel (X/Y).
// Computed from Viewport.get_screen_transform() at runtime. Each declared
// width below is a desired final/display pixel radius, not a texture radius.
uniform vec2 output_px_per_id_pixel = vec2(1.0);
// The legacy set_stroke_px() explicitly adjusts actor OUTSIDE width alone,
// never automatically replacing seam/inside or other-role presets.
uniform float actor_inside_override_px = -1.0;
uniform float actor_outside_override_px = -1.0;
uniform float actor_seam_override_px = -1.0;
// Each scene's actor profile is independently configurable, not hardcoded.
uniform float bittaran_inside_px = 0.0;
uniform float bittaran_outside_px = 3.0;
uniform float bittaran_seam_px = 1.0;
uniform float nexus_actor_inside_px = 1.0;
uniform float nexus_actor_outside_px = 2.0;
uniform float nexus_actor_seam_px = 2.0;
uniform float training_inside_px = 1.0;
uniform float training_outside_px = 3.0;
uniform float training_seam_px = 1.0;
uniform float nexus_facility_outside_px = 2.0;
uniform float nexus_facility_seam_px = 2.0;
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
    // Sample the exact integer ID texel. Spatial SCREEN_UV and CanvasItem
    // UV can have slightly different fractional centers after scaling, and
    // float UV/nearest sampling around a mesh seam can switch between two
    // IDs at different boundaries. texelFetch has no filtering, mip or
    // half-texel sampling ambiguity and uses the target's TRUE dimensions.
    ivec2 id_size = textureSize(mesh_id_texture, 0);
    ivec2 pixel = clamp(ivec2(floor(uv * vec2(id_size))),
        ivec2(0), id_size - ivec2(1));
    return texelFetch(mesh_id_texture, pixel, 0).rgb;
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

// Nearest-neighbor ID rendering has a finite pixel footprint. A requested
// width smaller than one displayed ID texel is snapped to one such texel,
// instead of silently disappearing. Perfect 1 physical-pixel output would
// additionally require a full-resolution physical display render target.
float sera_min_output_scale() {
    return max(0.125, min(output_px_per_id_pixel.x, output_px_per_id_pixel.y));
}

int sera_search_radius(float desired_display_px) {
    if (desired_display_px < 0.001) { return 0; }
    return clamp(int(ceil(desired_display_px /
        sera_min_output_scale())), 1, 16);
}

bool sera_in_disk(int dx, int dy, float desired_display_px) {
    if (desired_display_px < 0.001) { return false; }
    vec2 pixel_scale = min(output_px_per_id_pixel,
        vec2(desired_display_px));
    vec2 offset_px = vec2(float(dx), float(dy)) * pixel_scale;
    return dot(offset_px, offset_px) <=
        desired_display_px * desired_display_px + 0.001;
}

float sera_inner_width(int role) {
    if (role == 1 && actor_inside_override_px >= 0.0) {
        return actor_inside_override_px;
    }
    if (role == 2) { return facility_inside_px; }
    if (role == 3) { return clutter_inside_px; }
    if (role == 5) { return crate_inside_px; }
    if (role == 6) { return part_inside_px; }
    if (role == 1 && scene_profile == 1) { return bittaran_inside_px; }
    if (role == 1 && scene_profile == 2) { return nexus_actor_inside_px; }
    if (role == 1 && scene_profile == 3) { return training_inside_px; }
    return main_inside_px;
}

float sera_outer_width(int role) {
    if (role == 1 && actor_outside_override_px >= 0.0) {
        return actor_outside_override_px;
    }
    if (role == 2) {
        if (scene_profile == 2) { return nexus_facility_outside_px; }
        return facility_outside_px;
    }
    if (role == 3) { return clutter_outside_px; }
    if (role == 5) { return crate_outside_px; }
    if (role == 6) { return part_outside_px; }
    if (role == 1 && scene_profile == 1) { return bittaran_outside_px; }
    if (role == 1 && scene_profile == 2) { return nexus_actor_outside_px; }
    if (role == 1 && scene_profile == 3) { return training_outside_px; }
    return main_outside_px;
}

float sera_seam_width(int role) {
    if (role == 1 && actor_seam_override_px >= 0.0) {
        return actor_seam_override_px;
    }
    if (role == 2) {
        if (scene_profile == 2) { return nexus_facility_seam_px; }
        return facility_seam_px;
    }
    if (role == 3) { return clutter_seam_px; }
    if (role == 5) { return crate_seam_px; }
    if (role == 6) { return part_seam_px; }
    if (role == 1 && scene_profile == 1) { return bittaran_seam_px; }
    if (role == 1 && scene_profile == 2) { return nexus_actor_seam_px; }
    if (role == 1 && scene_profile == 3) { return training_seam_px; }
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
        int search_radius = sera_search_radius(max(inner_px, seam_px));
        for (int dy = -search_radius; dy <= search_radius; dy++) {
            for (int dx = -search_radius; dx <= search_radius; dx++) {
                if ((dx == 0 && dy == 0) ||
                        !sera_in_disk(dx, dy, max(inner_px, seam_px))) {
                    continue;
                }
                vec3 neighbor = sera_sample_visible_id(uv +
                    vec2(float(dx), float(dy)) * mesh_id_texel);
                int other_role = sera_role_of(neighbor);
                if (other_role == 0 &&
                        sera_in_disk(dx, dy, inner_px)) {
                    draw_ink = true;
                    break;
                }
                if (other_role > 0 && other_role != 7 &&
                        !sera_same_visible_id(center, neighbor) &&
                        sera_owns_contact(center, neighbor) &&
                        sera_in_disk(dx, dy, seam_px)) {
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
        float largest_outer_px = max(max(max(main_outside_px,
            bittaran_outside_px), max(nexus_actor_outside_px,
            training_outside_px)), max(max(facility_outside_px,
            nexus_facility_outside_px), max(max(clutter_outside_px,
            crate_outside_px), max(part_outside_px,
            actor_outside_override_px))));
        int outer_search = sera_search_radius(largest_outer_px);
        for (int dy = -outer_search; dy <= outer_search; dy++) {
            for (int dx = -outer_search; dx <= outer_search; dx++) {
                if ((dx == 0 && dy == 0) ||
                        !sera_in_disk(dx, dy, largest_outer_px)) {
                    continue;
                }
                vec3 neighbor = sera_sample_visible_id(uv +
                    vec2(float(dx), float(dy)) * mesh_id_texel);
                int other_role = sera_role_of(neighbor);
                if (other_role != 0 && other_role != 7 &&
                        sera_in_disk(dx, dy, sera_outer_width(other_role))) {
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
        int emission_search = sera_search_radius(2.0);
        for (int dy = -emission_search; dy <= emission_search; dy++) {
            for (int dx = -emission_search; dx <= emission_search; dx++) {
                if (!sera_in_disk(dx, dy, 2.0)) {
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
