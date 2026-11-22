shader_type canvas_item;
// Standalone GL Compatibility probe: no uniforms, no external textures,
// no loops, no conditional, no ID buffer. Only used inside NEXUS debug.
void fragment() {
    COLOR = vec4(1.0, 0.0, 1.0, 1.0);
}
