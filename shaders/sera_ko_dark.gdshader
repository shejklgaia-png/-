shader_type spatial;
// KO darkening uses the authored palette on each mesh, including B's red tint.
// This material is an overlay only while KO; originals are never modified.
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D sera_palette : source_color, filter_nearest, repeat_disable;
uniform vec3 set_tint = vec3(1.0, 1.0, 1.0);
uniform float ko_brightness : hint_range(0.0, 1.0) = 0.23;
void fragment() {
    vec4 color = texture(sera_palette, UV);
    ALBEDO = color.rgb * set_tint * ko_brightness;
}
