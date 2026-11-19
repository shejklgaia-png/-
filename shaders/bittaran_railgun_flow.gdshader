// RENDER_POLICY: DEPTH_TESTED_EMISSIVE; depth_test=on
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Moving plasma turbulence on the THIRD beam shell (the original inner
// and outer beam remain intact and depth-tested).
uniform vec4 plasma_blue : source_color = vec4(0.18, 0.71, 1.0, 0.55);
uniform float flow_speed = 10.0;

void fragment() {
    float running = UV.y * 66.0 + TIME * flow_speed;
    float shear = sin(UV.x * 37.0 + TIME * 19.0) * 0.85;
    float bands = 0.5 + 0.5 * sin(running + shear);
    float ripples = 0.5 + 0.5 * sin(running * 1.9 - UV.x * 47.0);
    float crackle = pow(bands, 6.0) * (0.5 + ripples);
    float pulse = 0.78 + 0.22 * sin(TIME * 31.0);
    float glow = (0.21 + 0.40 * bands + 0.70 * crackle) * pulse;
    ALBEDO = plasma_blue.rgb;
    EMISSION = plasma_blue.rgb * (2.0 + 4.0 * crackle) * glow;
    ALPHA = clamp(plasma_blue.a * glow, 0.0, 0.95);
}
