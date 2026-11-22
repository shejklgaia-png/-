shader_type spatial;
// Shared opaque model shading across SERA (combat, previews), BITTARAN,
// BASE, NEXUS and LAB/Warehouse rooms. Preserve authored UV, vertex paint,
// special effects and outlines. No additional surface draw pass.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform int material_hint = 0; // 1 external shell, 2 joint/mechanism
uniform bool iris_palette = false; // HEAD D's authored 16x16 multicolor atlas
uniform bool force_armor = false; // any single-color source is armor ONLY
uniform bool baked_palette = false; // dampen secondary shade on baked 96x32
uniform int armor_levels : hint_range(0, 8) = 8;
uniform float armor_threshold : hint_range(0.0, 1.0) = 0.65;
uniform int dark_levels : hint_range(0, 8) = 2;
uniform float dark_threshold : hint_range(0.0, 1.0) = 0.70;
uniform int lens_levels : hint_range(0, 8) = 3;
uniform float lens_threshold : hint_range(0.0, 1.0) = 0.10;
uniform bool lens_emissive = false;
uniform vec3 fx_emission : source_color = vec3(0.0);
uniform vec2 texture_uv_scale = vec2(1.0);
uniform vec2 texture_uv_offset = vec2(0.0);
uniform bool use_vertex_color = false;
// Only BASE NEXUS uses a raised face-brightness minimum; all other scenes
// retain the existing physical/look grading without an added draw pass.
uniform float scene_min_brightness : hint_range(0.0, 1.0) = 0.0;

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
    vec3 pixel_color = texture(source_texture,
        UV * texture_uv_scale + texture_uv_offset).rgb;
    vec3 original = pixel_color * source_tint.rgb;
    if (use_vertex_color) {
        original *= COLOR.rgb;
    }
    // Provisional visual material selection from authored palette plus part
    // location/name hint. Compare BEFORE red-tint, preserving authored B paint.
    vec3 classify_color = iris_palette ? pixel_color : original;
    float high = max(classify_color.r,
        max(classify_color.g, classify_color.b));
    float low = min(classify_color.r,
        min(classify_color.g, classify_color.b));
    float grayness = high - low;
    bool iris_cyan = iris_palette && distance(pixel_color,
        vec3(43.0, 141.0, 173.0) / 255.0) < 0.075;
    // Do not call blue/grey SOLID armor a lens based on its hue. The lens
    // preset applies only to the authored multi-color iris or tagged optics.
    bool cyan = iris_cyan || (material_hint == 3 &&
        classify_color.b > classify_color.r * 1.38 &&
        classify_color.g > classify_color.r * 1.26 &&
        classify_color.g > 0.18 && classify_color.b > 0.23);
    // UV colors are baked directional tones; mid/dark atlas pixels may be
    // shadow-facing ARMOR, not separate mechanism. Prefer authored position
    // or mesh naming for standard 96x32 equipment. On IRIS' standalone
    // 16x16 atlas, light-grey shell vs two dark-grey frame tones are distinct.
    // This works with both sRGB and linear GL color sampling.
    bool dark_pixel = iris_palette ? (high < 0.45 && !cyan) :
        (material_hint == 2 && high < 0.70 && grayness < 0.24);
    int kind = force_armor ? 0 : (cyan ? 2 : (dark_pixel ? 1 : 0));
    int levels = kind == 2 ? lens_levels : (
        kind == 1 ? dark_levels : armor_levels);
    float threshold = kind == 2 ? lens_threshold : (
        kind == 1 ? dark_threshold : armor_threshold);
    // In fragment(), NORMAL is in VIEW space. Convert to WORLD space before
    // comparing against the fixed world light, so orbiting the preview
    // camera cannot change which authored side is in shadow.
    vec3 world_normal = normalize((INV_VIEW_MATRIX *
        vec4(normalize(NORMAL), 0.0)).xyz);
    float illumination = clamp(
        dot(world_normal, normalize(vec3(-0.45, 0.65, 0.70)))
        * 0.5 + 0.5, 0.0, 1.0);
    float multiplier = sera_band_brightness(levels, threshold, illumination);
    // The 96x32 atlas already has a direction-based three-tone paint job;
    // apply only half the additional shadow difference to avoid double
    // darkening while keeping the requested 8/2/3-step threshold positions.
    if (baked_palette) {
        multiplier = mix(1.0, multiplier, 0.50);
    }
    multiplier = max(multiplier, scene_min_brightness);
    vec3 shaded = original * multiplier;
    EMISSION = fx_emission;
    if (kind == 2 && lens_emissive) {
        // Not active for the user-supplied preset (lens_lit=false).
        shaded = mix(original, vec3(0.30, 0.82, 1.0), 0.67);
        EMISSION += vec3(0.09, 0.29, 0.43);
    }
    ALBEDO = clamp(shaded, vec3(0.0), vec3(1.0));
}
