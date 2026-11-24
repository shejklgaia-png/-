shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
varying vec3 world_normal;

void vertex() {
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 n = normalize(world_normal);
    float face = 0.82 + 0.18 * max(dot(n, normalize(vec3(-0.55, 0.85, 0.4))), 0.0);
    // COLOR carries each MultiMesh instance's authored atmospheric palette.
    vec3 tint = COLOR.rgb * face;
    float haze = smoothstep(65.0, 215.0, length(VERTEX)) * 0.66;
    ALBEDO = mix(tint, vec3(0.376, 0.490, 0.561), haze);
}
