shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D source_texture : source_color, filter_nearest_mipmap, repeat_disable;
uniform int grid_mode = 0;
uniform sampler2D diagnostic_selection : filter_nearest, repeat_disable, hint_default_black;
uniform vec2 atlas_dimensions = vec2(256.0);
varying flat vec2 face_diagnostic;
void vertex() {
    face_diagnostic = UV2;
}
void fragment() {
    // Binary per-triangle flags: red = cull front, green = cull back,
    // white = two-sided or a legacy atlas without flags.
    if (COLOR.b < 0.5 && ((COLOR.r > 0.5 && FRONT_FACING) ||
        (COLOR.r < 0.5 && !FRONT_FACING))) {
        discard;
    }
    // Preserve the original authored polygon normal (not triangle derivative).
    // Two-sided fragments receive the same normal direction as their front.
    vec3 n = NORMAL;
    if (!FRONT_FACING) {
        n = -n;
    }
    vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
    float lighting = clamp(dot(world_normal, normalize(vec3(-0.45, 0.65, 0.70))) * 0.5 + 0.5, 0.0, 1.0);
    float shade = mix(0.80, 1.0, floor(lighting * 7.0 + 0.5) / 7.0);
    vec3 base = texture(source_texture, UV).rgb * shade;
    if (grid_mode > 0) {
        vec2 pixel = UV * atlas_dimensions;
        vec2 distance_to_line = abs(fract(pixel + 0.5) - 0.5);
        vec2 footprint = max(fwidth(pixel), vec2(0.0001));
        vec2 lines = 1.0 - smoothstep(footprint * 0.35, footprint * 0.95, distance_to_line);
        float line = max(lines.x, lines.y) * (1.0 - smoothstep(0.55, 1.3, max(footprint.x, footprint.y)));
        if (grid_mode == 2) {
            vec3 diagnostic = face_diagnostic.x > 0.75 ? vec3(0.17, 0.65, 0.45) : (face_diagnostic.x > 0.25 ? vec3(0.92, 0.50, 0.15) : vec3(0.4, 0.5, 0.65));
            base = mix(base, diagnostic, 0.48);
            float face_id = floor(face_diagnostic.y + 0.5) - 1.0;
            vec2 mask_uv = (vec2(mod(face_id, 128.0), floor(face_id / 128.0)) + 0.5) / 128.0;
            if (face_id >= 0.0 && face_id < 16384.0 && texture(diagnostic_selection, mask_uv).r > 0.5) {
                base = mix(vec3(0.46, 0.78, 1.0), vec3(0.88, 0.97, 1.0), 0.5 + 0.5 * sin(TIME * 3.0));
            }
        }
        base = mix(base, vec3(0.04, 0.13, 0.18), line * 0.8);
    }
    ALBEDO = base;
}
