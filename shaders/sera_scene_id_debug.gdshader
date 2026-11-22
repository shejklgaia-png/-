shader_type canvas_item;
// NEXUS debug-only: visualize the *actual* offscreen mesh-ID buffer.
// The source IDs are mostly dark near zero, so amplify RGB for screenshots.
// This shader never runs in normal gameplay or the normal outline compositor.
render_mode unshaded, blend_mix;
void fragment() {
    vec3 raw_id = texture(TEXTURE, UV).rgb;
    float present = step(0.025, max(raw_id.r, max(raw_id.g, raw_id.b)));
    COLOR = vec4(clamp(raw_id * 5.0, vec3(0.0), vec3(1.0)), present);
    // A nonzero alpha is needed to distinguish empty IDs from a missing
    // TextureRect. The panel behind is always an opaque dark blue.
}
