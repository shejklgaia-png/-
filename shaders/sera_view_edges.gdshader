shader_type spatial;
// RENDER_POLICY: DEPTH_TESTED_EMISSIVE; depth_test=on
// Ink only where a separately visible opaque mesh ends. Inverted hull
// triangles may have reversed winding on Blockbench's double-sided meshes:
// NEVER allow their interior to fill with the dark outline color.
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.09, 0.13, 0.18, 1.0);
uniform float stroke_px : hint_range(0.5, 8.0) = 3.0;
uniform sampler2D opaque_depth : hint_depth_texture, filter_nearest, repeat_disable;
varying float source_depth;

float opaque_depth_at(vec2 uv) {
    float z = textureLod(opaque_depth, clamp(uv, vec2(0.0), vec2(1.0)), 0.0).r;
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(uv, z) * 2.0 - vec3(1.0);
    #else
    vec3 ndc = vec3(uv * 2.0 - vec2(1.0), z);
    #endif
    vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    if (abs(view.w) < 0.000001) {
        return 1e12;
    }
    return -view.z / view.w;
}

void vertex() {
    vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    source_depth = -view_position.z;
    vec3 view_normal = normalize(
        transpose(inverse(mat3(MODELVIEW_MATRIX))) * NORMAL);
    vec4 clip = PROJECTION_MATRIX * vec4(view_position, 1.0);
    vec2 normal_ndc = vec2(
        view_normal.x * PROJECTION_MATRIX[0][0],
        view_normal.y * PROJECTION_MATRIX[1][1]);
    vec2 normal_px = normal_ndc * VIEWPORT_SIZE;
    if (dot(normal_px, normal_px) > 0.0000001) {
        vec2 pixel_direction = normalize(normal_px);
        clip.xy += pixel_direction
            * (vec2(2.0 * stroke_px) / VIEWPORT_SIZE) * clip.w;
    }
    POSITION = clip;
}

void fragment() {
    // The center depth is from the actual opaque scene, not the ink pass.
    // Suppress any hull fragment overlying its own real surface.
    float opaque_center = opaque_depth_at(SCREEN_UV);
    float near_epsilon = max(0.03, 3.5 * fwidth(source_depth));
    if (abs(opaque_center - source_depth) <= near_epsilon) {
        discard;
    }

    // Only keep the narrow strip touching visible source geometry.
    // An incorrectly wound/recessed rear polygon can cover a large area,
    // but it has no opaque surface at the same depth in this 3px vicinity.
    // Four depth fetches are only evaluated after the center depth reject.
    // A 6px contour diagonal projects only 4.24px onto each axis.
    // A 6px axial probe therefore misses the source completely; use
    // a 1.5x offset for BASE strokes, without changing SERA's 3px mask.
    float depth_probe_px = stroke_px > 4.0 ? stroke_px * 1.5 : stroke_px;
    vec2 pixel_step = vec2(depth_probe_px) / VIEWPORT_SIZE;
    float neighbor_epsilon = max(near_epsilon * 1.2, 0.055);
    bool near_surface =
        abs(opaque_depth_at(SCREEN_UV + vec2(pixel_step.x, 0.0)) - source_depth) <= neighbor_epsilon ||
        abs(opaque_depth_at(SCREEN_UV - vec2(pixel_step.x, 0.0)) - source_depth) <= neighbor_epsilon ||
        abs(opaque_depth_at(SCREEN_UV + vec2(0.0, pixel_step.y)) - source_depth) <= neighbor_epsilon ||
        abs(opaque_depth_at(SCREEN_UV - vec2(0.0, pixel_step.y)) - source_depth) <= neighbor_epsilon;
    if (!near_surface) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = 1.0;
}
