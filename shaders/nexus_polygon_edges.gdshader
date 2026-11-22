shader_type spatial;
// RENDER_POLICY: NEXUS_SURFACE_EDGES; depth_test=on
// NEXUS-only, camera-pixel-aligned polygon corners drawn as a second pass.
// Keep the original opaque material/shading and all light/glow materials intact.
render_mode unshaded, blend_mix, cull_back, depth_draw_never;

uniform vec4 edge_tint : source_color = vec4(0.494, 0.522, 0.557, 1.0);
uniform float width_px = 2.0;
uniform int geometry_mode = 0; // 0: BoxMesh unit cubes, 1: 12-sided central pad
uniform float cylinder_facets = 12.0;
uniform float cylinder_half_height = 0.08;
uniform float cylinder_top_radius = 1.29;
uniform float cylinder_bottom_radius = 1.37;

varying vec3 local_position;
varying vec3 local_normal;
varying vec2 local_uv;

void vertex() {
    // MultiMesh instance transforms must NOT be baked into these coordinates:
    // the cube remains [-0.5,+0.5] for every scaled/rotated Blockbench part.
    local_position = VERTEX;
    local_normal = NORMAL;
    local_uv = UV;
}

float pixel_edge(float distance_from_edge, float derivative) {
    float pixel = max(derivative, 0.000001);
    // Solid first pixel, antialias toward the second: ~2 screen pixels.
    return 1.0 - smoothstep(width_px * 0.5 * pixel,
                           width_px * pixel,
                           max(distance_from_edge, 0.0));
}

void fragment() {
    float outline = 0.0;
    if (geometry_mode == 0) {
        vec3 distance_to_cube_side = vec3(0.5) - abs(local_position);
        vec3 pixel = max(fwidth(local_position), vec3(0.000001));
        vec3 near_face = vec3(
            pixel_edge(distance_to_cube_side.x, pixel.x),
            pixel_edge(distance_to_cube_side.y, pixel.y),
            pixel_edge(distance_to_cube_side.z, pixel.z));
        // Two perpendicular cube planes meet at every real polygon edge.
        // A single plane is not an edge (otherwise an entire face goes gray).
        outline = max(near_face.x * near_face.y,
                  max(near_face.y * near_face.z, near_face.z * near_face.x));
    } else {
        // The separately authored center platform is a true 12-sided cylinder,
        // not a unit cube. Its side facet seams + top/bottom rim are its edges.
        float is_side = 1.0 - step(0.5, abs(local_normal.y));
        float sector = local_uv.x * cylinder_facets;
        float sector_distance = min(fract(sector), 1.0 - fract(sector));
        float facet_line = pixel_edge(sector_distance, fwidth(sector));
        float lip_distance = cylinder_half_height - abs(local_position.y);
        float lip_line = pixel_edge(lip_distance, fwidth(local_position.y));
        float radius = mix(cylinder_bottom_radius, cylinder_top_radius,
                           step(0.0, local_position.y));
        float cap_distance = radius - length(local_position.xz);
        float cap_line = pixel_edge(cap_distance, fwidth(cap_distance));
        outline = mix(cap_line, max(facet_line, lip_line), is_side);
    }
    if (outline <= 0.001) {
        discard;
    }
    // Depth-tested overlay on original surfaces, before HUD/selection glows.
    ALBEDO = edge_tint.rgb;
    ALPHA = clamp(outline * edge_tint.a, 0.0, 1.0);
}
