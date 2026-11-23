shader_type spatial;
// NEXUS full-body ONLY: true 3D smoothed inverted hull, hardware depth test.
// Sealed SERA Blockbench armor uses CULL_FRONT to show its authored outside;
// the hull renders the opposite faces (cull_back), expanded in real 3D.
// No screen-XY-only displacement, stencil, depth texture or extra viewport.
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 outline_color : source_color =
    vec4(0.043137, 0.066667, 0.094118, 1.0);
uniform float outline_px : hint_range(0.5, 8.0, 0.5) = 3.0;

void vertex() {
    vec3 unit_normal = normalize(NORMAL);
    vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    // Screen-pixel thickness converted into view-space distance.
    // Orthographic cameras use one scale across all depths; perspective
    // cameras scale linearly with their positive camera-space Z distance.
    float perspective_depth = max(-view_position.z, 0.01);
    float is_orthographic = step(0.5, PROJECTION_MATRIX[3][3]);
    float effective_depth = mix(perspective_depth, 1.0, is_orthographic);
    float view_units_per_pixel = (2.0 * effective_depth) /
        max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y, 0.00001);

    // Convert view-space units back to local along the actual smoothed
    // normal. Preserve the source mesh transform, including NEXUS scaling.
    float view_normal_scale = max(length(
        (MODELVIEW_MATRIX * vec4(unit_normal, 0.0)).xyz), 0.00001);
    float local_growth = outline_px * view_units_per_pixel /
        view_normal_scale;
    VERTEX += unit_normal * local_growth;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    // Transparent pass after source opaque depth has been written.
    ALPHA = outline_color.a;
}
