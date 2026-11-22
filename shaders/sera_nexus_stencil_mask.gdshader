shader_type spatial;
// NEXUS: write one shared character stencil value for ALL opaque parts.
// Separate geometry means the authored material/UV/shading is untouched.
// Transparent pass is mandatory for stencil interactions in Godot 4.7.
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
stencil_mode write, compare_always, 17;

void vertex() {
    // Position is unchanged in screen X/Y: register the real physical
    // footprint. Tiny view-space offset avoids equality precision failures
    // against the opaque source itself on Compatibility/OpenGL.
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    eye += normalize(-eye) * max(0.001, length(eye) * 0.00010);
    POSITION = PROJECTION_MATRIX * vec4(eye, 1.0);
}

void fragment() {
    // Output no visible color. Stencil write still occurs per surviving
    // fragment; do not discard or use alpha scissors.
    ALBEDO = vec3(0.0);
    ALPHA = 0.0;
}
