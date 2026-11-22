shader_type spatial;
// RENDER_POLICY: DEPTH_TESTED_EMISSIVE; depth_test=on
// Fast 3px silhouette for CCW outward-authored shells (Godot uses CW front).
// NO depth-texture fetch: the original opaque source mesh and the hardware
// depth buffer occlude enlarged inward faces automatically.
// The source surface uses CULL_FRONT, so this ink must use CULL_BACK.
render_mode unshaded, cull_back, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.09, 0.13, 0.18, 1.0);
uniform float stroke_px : hint_range(0.5, 6.0) = 3.0;


 // The HEAD D single-part ID contour is 3px on a 384px reference.
 // Scale the 3D inverted-hull contour by the shorter rendering viewport
 // dimension, keeping the same fraction of the screen across full-size
 // 720x1280 and square single-part views. Never shrink small previews.
float effective_stroke_px(vec2 viewport_size, float base_stroke_px) {
    // Built-ins such as VIEWPORT_SIZE are scoped to vertex()/fragment().
    // Custom functions only receive their values as explicit arguments.
    float short_side_px = min(viewport_size.x, viewport_size.y);
    return base_stroke_px * max(1.0, short_side_px / 384.0);
}

void vertex() {
    float scaled_stroke_px = effective_stroke_px(VIEWPORT_SIZE, stroke_px);
    vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
            * (vec2(2.0 * scaled_stroke_px) / VIEWPORT_SIZE) * clip.w;
    }
    POSITION = clip;
}

void fragment() {
    ALBEDO = ink_color.rgb;
    ALPHA = 1.0;
}
