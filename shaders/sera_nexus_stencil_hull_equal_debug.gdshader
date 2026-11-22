shader_type spatial;
// NEXUS: draw only the outside of the complete shared stencil mask.
// NORMAL contains baked/welded contour normals, never source flat normals.
render_mode unshaded, cull_front, depth_draw_never, blend_mix, fog_disabled;
stencil_mode read, compare_equal, 17;

uniform vec4 outline_color : source_color = vec4(0.15, 0.94, 0.35, 1.0);
uniform float outline_px : hint_range(0.5, 8.0) = 3.0;

void vertex() {
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 direction = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
    vec4 position = PROJECTION_MATRIX * vec4(eye, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(eye + direction * 0.1, 1.0);
    vec2 projected = ((tip.xy / max(tip.w, 0.00001)) -
        (position.xy / max(position.w, 0.00001))) * VIEWPORT_SIZE;
    float mag = length(projected);
    if (mag > 0.00001 && position.w > 0.00001) {
        vec2 screen_dir = projected / mag;
        position.xy += screen_dir * vec2(2.0 / VIEWPORT_SIZE.x,
            2.0 / VIEWPORT_SIZE.y) * outline_px * position.w;
    }
    POSITION = position;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
