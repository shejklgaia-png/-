shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

// Vertex colors are authored per frame from world-space positions and age.
// Keep ordinary depth testing so the ribbon remains behind solid geometry.
void fragment() {
    ALBEDO = COLOR.rgb * 0.3;
    EMISSION = COLOR.rgb * 0.9;
    ALPHA = COLOR.a;
}
