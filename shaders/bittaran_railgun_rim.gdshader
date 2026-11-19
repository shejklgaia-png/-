shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// A camera-facing Fresnel outline; the spherical charge stays pale inside
// and electric blue ONLY at its edge. TIME creates irregular flicker.
uniform vec4 rim_blue : source_color = vec4(0.12, 0.61, 1.0, 0.82);
uniform float rim_power : hint_range(0.5, 6.0) = 2.5;
uniform float flicker_speed = 46.0;

void fragment() {
    float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
    float edge = pow(1.0 - facing, rim_power);
    float irregular = 0.5 + 0.5 * sin(
        UV.x * 91.0 + TIME * flicker_speed +
        0.65 * sin(UV.y * 73.0 - TIME * 29.0));
    float spark = pow(irregular, 5.0);
    float flicker = 0.76 + 0.25 * sin(TIME * 38.0) +
        0.29 * spark;
    ALBEDO = rim_blue.rgb;
    EMISSION = rim_blue.rgb * (2.5 + 2.5 * spark) * flicker * edge;
    ALPHA = clamp(rim_blue.a * edge * flicker, 0.0, 1.0);
}
