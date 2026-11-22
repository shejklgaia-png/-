shader_type spatial;
// Diagnostics only: visible tint on the REAL stencil-writing pass.
// The tint proves rasterization, NOT necessarily that stencil writes work.
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
stencil_mode write, compare_always, 17;

void vertex() {
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    eye += normalize(-eye) * max(0.001, length(eye) * 0.00010);
    POSITION = PROJECTION_MATRIX * vec4(eye, 1.0);
}
void fragment() {
    ALBEDO = vec3(0.96, 0.52, 0.12);
    ALPHA = 0.42;
}
