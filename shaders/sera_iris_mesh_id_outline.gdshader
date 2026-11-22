shader_type canvas_item;
// NEXUS HEAD D single-part preview only. TextureRect's TEXTURE is the
// depth-tested per-mesh ID SubViewport. No triangle angle tests, no hull.
// Draw inside the currently visible surface: 3px total per border, never
// a black filled polygon, and no contours of hidden/invisible meshes.
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 4.0) = 3.0;

// IDs are separated by 1/8 red-channel steps; 0 is the background.
bool mismatched_id(float center_id, float neighbor_id) {
    if (center_id < 0.06) {
        return false;
    }
    // Entire outer outline lives inside the mesh silhouette (3px).
    if (neighbor_id < 0.06) {
        return true;
    }
    // Only one side of an inter-mesh seam is inked, to avoid 6px seams.
    return neighbor_id + 0.05 < center_id;
}

void fragment() {
    float id = texture(TEXTURE, UV).r;
    if (id < 0.06) {
        COLOR = vec4(0.0);
        return;
    }
    vec2 texel = TEXTURE_PIXEL_SIZE;
    bool edge = false;
    // Four depth-tested ID neighbors at each 1..3 pixel distance.
    for (int r = 1; r <= 3; r++) {
        float radius = float(r);
        if (radius > stroke_px) {
            break;
        }
        vec2 d = texel * radius;
        edge = edge ||
            mismatched_id(id, texture(TEXTURE, UV + vec2(d.x, 0.0)).r) ||
            mismatched_id(id, texture(TEXTURE, UV - vec2(d.x, 0.0)).r) ||
            mismatched_id(id, texture(TEXTURE, UV + vec2(0.0, d.y)).r) ||
            mismatched_id(id, texture(TEXTURE, UV - vec2(0.0, d.y)).r);
    }
    COLOR = edge ? ink_color : vec4(0.0);
}
