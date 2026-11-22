shader_type spatial;
// SERA full-body NEXUS exhibition only: all currently installed AND
// switchable body-part/weapon MeshInstances. Source meshes, UV and rim outlines
// stay unchanged; no transparent FX or second surface pass is added.
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform int material_hint = 0; // 0 palette, 1 armor, 2 internal mechanism
uniform int armor_levels : hint_range(0, 8) = 8;
uniform float armor_threshold : hint_range(0.0, 1.0) = 0.65;
uniform int dark_levels : hint_range(0, 8) = 2;
uniform float dark_threshold : hint_range(0.0, 1.0) = 0.70;
uniform int lens_levels : hint_range(0, 8) = 3;
uniform float lens_threshold : hint_range(0.0, 1.0) = 0.10;
uniform bool lens_emissive = false;

float sera_band_brightness(int levels, float threshold, float lighting) {
    if (levels < 2) {
        return 1.0;
    }
    // This is the IRIS material shader's step/threshold quantizer.
    float shifted = clamp(lighting + 0.5 - threshold, 0.0, 0.99999);
    float band = floor(shifted * float(levels));
    return mix(0.55, 1.05, band / float(levels - 1));
}

void fragment() {
    vec3 pixel_color = texture(source_texture, UV).rgb;
    vec3 original = pixel_color * source_tint.rgb;
    // Provisional visual material selection from authored palette plus part
    // location/name hint. Compare BEFORE red-tint, preserving authored B paint.
    float high = max(pixel_color.r, max(pixel_color.g, pixel_color.b));
    float low = min(pixel_color.r, min(pixel_color.g, pixel_color.b));
    float grayness = high - low;
    bool iris_cyan = distance(pixel_color,
        vec3(43.0, 141.0, 173.0) / 255.0) < 0.075;
    bool cyan = iris_cyan || (pixel_color.b > pixel_color.r * 1.38
        && pixel_color.g > pixel_color.r * 1.26
        && pixel_color.g > 0.18 && pixel_color.b > 0.23);
    // Dark mechanism includes joints and shadowed framing; light armor is
    // the default. Colored armor remains armor even under a red set tint.
    bool dark_pixel = high < 0.34 || (
        material_hint == 2 && high < 0.70 && grayness < 0.24);
    int kind = cyan ? 2 : (dark_pixel ? 1 : 0);
    int levels = kind == 2 ? lens_levels : (
        kind == 1 ? dark_levels : armor_levels);
    float threshold = kind == 2 ? lens_threshold : (
        kind == 1 ? dark_threshold : armor_threshold);
    // Face normals have been unified across each authored Blockbench polygon,
    // not across the separate face boundaries or diagonal triangles.
    float illumination = clamp(
        dot(normalize(NORMAL), normalize(vec3(-0.45, 0.65, 0.70)))
        * 0.5 + 0.5, 0.0, 1.0);
    float multiplier = sera_band_brightness(levels, threshold, illumination);
    vec3 shaded = original * multiplier;
    if (kind == 2 && lens_emissive) {
        // Not active for the user-supplied preset (lens_lit=false).
        shaded = mix(original, vec3(0.30, 0.82, 1.0), 0.67);
        EMISSION = vec3(0.09, 0.29, 0.43);
    }
    ALBEDO = clamp(shaded, vec3(0.0), vec3(1.0));
}
