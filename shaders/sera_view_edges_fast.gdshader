shader_type spatial;
// RENDER_POLICY: DEPTH_TESTED_EMISSIVE; depth_test=on
// Fast 3px visible outline for guaranteed outward-wound closed opaque shells.
// NO depth-texture fetch: the original opaque source mesh and the hardware
// depth buffer occlude enlarged rear faces automatically.
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 ink_color : source_color = vec4(0.09, 0.13, 0.18, 1.0);
uniform float stroke_px : hint_range(0.5, 6.0) = 3.0;

void vertex() {
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
            * (vec2(2.0 * stroke_px) / VIEWPORT_SIZE) * clip.w;
    }
    POSITION = clip;
}

void fragment() {
    ALBEDO = ink_color.rgb;
    ALPHA = 1.0;
}
