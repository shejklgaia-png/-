shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

// A low-cost, four-sided exhaust tube. No particles/textures/physics.
// Local +Z is out of the nozzle; vertex motion grows toward the end.
uniform vec4 flame_tint : source_color = vec4(0.2, 0.76, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float tube_length = 0.65;
uniform float phase_offset = 0.0;
varying float distance_fraction;

void vertex() {
    float along = clamp(VERTEX.z / max(tube_length, 0.01), 0.0, 1.0);
    float flutter = sin(TIME * 17.0 + along * 18.0 + phase_offset);
    float flutter2 = cos(TIME * 23.0 + along * 13.0 + phase_offset * 1.7);
    VERTEX.x += along * along * 0.014 * flutter;
    VERTEX.y += along * along * 0.014 * flutter2;
    VERTEX.xy *= 1.0 + along * 0.19 * sin(TIME * 20.0 + along * 11.0);
    distance_fraction = along;
}

void fragment() {
    float pulse = 0.73 + 0.27 * sin(TIME * 25.0 + distance_fraction * 15.0 + phase_offset);
    float fade = 1.0 - smoothstep(0.20, 1.0, distance_fraction);
    float streaks = 0.86 + 0.14 * sin(TIME * 31.0 - distance_fraction * 21.0 + phase_offset);
    ALBEDO = flame_tint.rgb;
    EMISSION = flame_tint.rgb * (0.75 + 0.45 * pulse);
    ALPHA = clamp(strength * flame_tint.a * fade * pulse * streaks, 0.0, 0.8);
}
