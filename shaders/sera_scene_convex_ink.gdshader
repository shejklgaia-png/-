shader_type spatial;
// Companion to SERA's one canonical visible-RGB12-ID outline shader.
// Both concave and convex front/front building hard corners share this 1px
// overlay. Clutter uses convex-only geometry. Exterior silhouettes,
// open edges and inter-mesh ID boundaries remain handled elsewhere.
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 ink_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Total requested full-width line in final display pixels, not half-width.
uniform float corner_width_px : hint_range(0.0, 8.0) = 1.0;
uniform vec2 output_px_per_render_pixel = vec2(1.0);
uniform bool outlines_enabled = true;
uniform sampler2D emissive_id_texture : filter_nearest, repeat_disable;
uniform vec2 emissive_id_texel = vec2(0.001);
uniform bool protect_emission = false;
varying float edge_visible;

void vertex() {
    vec3 normal_a = normalize(COLOR.rgb * 2.0 - vec3(1.0));
    vec3 normal_b = normalize(CUSTOM0.xyz);
    vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    mat3 normal_matrix = transpose(inverse(mat3(MODEL_MATRIX)));
    vec3 na = normalize(normal_matrix * normal_a);
    vec3 nb = normalize(normal_matrix * normal_b);
    vec3 view_ray = normalize(CAMERA_POSITION_WORLD - world_position);
    float fa = dot(na, view_ray);
    float fb = dot(nb, view_ray);
    edge_visible = (fa > 0.02 && fb > 0.02 && COLOR.a > 0.5) ? 1.0 : 0.0;

    vec3 eye_vertex = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 eye_tangent = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    eye_vertex += normalize(-eye_vertex) *
        max(0.002, length(eye_vertex) * 0.0003);
    vec4 clip = PROJECTION_MATRIX * vec4(eye_vertex, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(eye_vertex + eye_tangent * 0.10, 1.0);
    vec2 delta_ndc = tip.xy / max(tip.w, 0.00001)
        - clip.xy / max(clip.w, 0.00001);
    vec2 tangent_px = delta_ndc * VIEWPORT_SIZE;
    if (dot(tangent_px, tangent_px) < 0.0000001) {
        edge_visible = 0.0;
        tangent_px = vec2(1.0, 0.0);
    }
    vec2 side = normalize(vec2(-tangent_px.y, tangent_px.x));
    float scale = max(0.125, min(
        output_px_per_render_pixel.x, output_px_per_render_pixel.y));
    // Quantize at one internal raster pixel when the requested physical
    // thickness would otherwise disappear. GPU/ID draw at the same source px.
    float width_px = max(1.0, corner_width_px / scale);
    // The NDC-to-pixel factor (viewport_size / 2) already halves each
    // signed offset. With UV.x=+-1 this produces width_px TOTAL screen px.
    clip.xy += side * vec2(1.0 / VIEWPORT_SIZE.x,
        1.0 / VIEWPORT_SIZE.y) * width_px * clip.w * UV.x;
    POSITION = clip;
}

void fragment() {
    if (!outlines_enabled || edge_visible < 0.5) {
        discard;
    }
    float alpha = ink_color.a;
    if (protect_emission) {
        vec3 id_value = texture(emissive_id_texture, SCREEN_UV).rgb;
        if (int(floor(id_value.g * 8.0 + 0.5)) == 7) {
            alpha *= 0.45;
        }
    }
    ALBEDO = ink_color.rgb;
    ALPHA = alpha;
}
