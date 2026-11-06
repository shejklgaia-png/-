shader_type spatial;
// Single pre-rendered, alpha-masked 3D crescent on a rigid QuadMesh.
// The grayscale timing image reveals its pixels from the real sword's swing
// start to the end of its striking pass. No procedural ribbon geometry.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform sampler2D ink_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D reveal_texture : filter_linear, repeat_disable;
uniform vec3 ink_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float ink_brightness : hint_range(0.0, 3.0) = 1.0;
uniform float reveal_amount : hint_range(0.0, 1.0) = 0.0;
uniform float effect_opacity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 ink = texture(ink_texture, UV);
    float time_at_pixel = texture(reveal_texture, UV).r;
    float reveal = smoothstep(time_at_pixel - 0.005, time_at_pixel + 0.005, reveal_amount);
    float a = ink.a * reveal * effect_opacity;
    if (a < 0.008) {
        discard;
    }
    ALBEDO = ink.rgb * ink_tint * ink_brightness;
    ALPHA = clamp(a, 0.0, 1.0);
}
