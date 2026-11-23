shader_type spatial;
// NEXUS full-body ONLY: two-sided/ambiguous source geometry.
// Do not render both sides of its expanded outline: that caused black
// interior polygons in PR #814. Draw only back-facing source triangles
// and keep the hull behind the opaque source surface in view-space depth.
// No stencil, screen-space XY offset, SubViewport or depth texture.
render_mode unshaded, cull_back, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 outline_color : source_color =
    vec4(0.043137, 0.066667, 0.094118, 1.0);
uniform float outline_px : hint_range(0.5, 8.0, 0.5) = 3.0;

void vertex() {
    vec3 unit_normal = normalize(NORMAL);
    vec3 view_position = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

    float perspective_depth = max(-view_position.z, 0.01);
    float is_orthographic = step(0.5, PROJECTION_MATRIX[3][3]);
    float effective_depth = mix(perspective_depth, 1.0, is_orthographic);
    float view_units_per_pixel = (2.0 * effective_depth) /
        max(abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y, 0.00001);
    float view_normal_scale = max(length(
        (MODELVIEW_MATRIX * vec4(unit_normal, 0.0)).xyz), 0.00001);
    float local_growth = outline_px * view_units_per_pixel /
        view_normal_scale;

    // The growth is REAL 3D geometry, not a clip-space XY translation.
    vec3 grown_vertex = VERTEX + unit_normal * local_growth;
    vec3 grown_view = (MODELVIEW_MATRIX *
        vec4(grown_vertex, 1.0)).xyz;

    // Open faces have no enclosed rear shell. Without this conservative
    // rear depth shift, an expanded visible face can turn completely black.
    // A slight view-space push backward lets the original opaque material
    // hide the interior, leaving only growth beyond its original borders.
    grown_view.z -= outline_px * view_units_per_pixel * 1.25;
    POSITION = PROJECTION_MATRIX * vec4(grown_view, 1.0);
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
