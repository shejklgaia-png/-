shader_type canvas_item;
// Independent forced-solid probe with the same sampler/uniform declaration
// footprint as the production compositor. No loops or ID comparisons.
// If BASIC works but this does not, inspect the sampler/render path.
render_mode blend_mix;
uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(1.0 / 720.0, 1.0 / 1280.0);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 3.0) = 3.0;
void fragment() {
    COLOR = vec4(1.0, 0.0, 1.0, 1.0);
}
