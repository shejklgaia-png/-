shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float fps = 4.0;

void fragment() {
    float frame = mod(floor(TIME * fps), 8.0);
    vec2 grid = vec2(4.0, 2.0);
    vec2 origin = vec2(mod(frame, 4.0), floor(frame / 4.0));
    vec2 inset = 0.5 * grid / vec2(textureSize(atlas, 0));
    vec2 coord = (origin + mix(inset, vec2(1.0) - inset, UV)) / grid;
    ALBEDO = texture(atlas, coord).rgb;
}
