shader_type spatial;
// NEXUS H02 IRIS single-part preview ONLY. Exact authored face normals,
// existing 3px visible-mesh-ID outline and source textures remain untouched.
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform float panel_bias : hint_range(-0.1, 0.1) = 0.0;
uniform int armor_levels : hint_range(0, 8) = 4;
uniform int dark_levels : hint_range(0, 8) = 4;
uniform int lens_levels : hint_range(0, 8) = 0;
uniform float armor_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float dark_threshold : hint_range(0.0, 1.0) = 0.60;
uniform float lens_threshold : hint_range(0.0, 1.0) = 0.25;
uniform bool lens_emissive = false;
uniform int flash_material = -1;
uniform float flash_power : hint_range(0.0, 1.0) = 0.0;

float shade_brightness(int levels, float threshold, float illumination) {
    if (levels < 2) {
        return 1.0;
    }
    // For two bands the boundary is exactly threshold. More bands shift
    // together, keeping an even staircase and preserving quad-flat normals.
    float shifted = clamp(illumination + 0.5 - threshold, 0.0, 0.99999);
    float band = floor(shifted * float(levels));
    return mix(0.55, 1.05, band / float(levels - 1));
}

void fragment() {
    vec3 texel = texture(source_texture, UV).rgb;
    vec3 base = texel * source_tint.rgb;
    // Exact colors of the 16x16 authored IRIS texture (nearest filtering).
    // Light grey #b8bec4; dark mechanism #353637 and #5d5f60;
    // cyan lens #2b8dad. Derive material from texel, not mesh, because
    // each of the six meshes can contain multiple material-colored faces.
    bool is_cyan = distance(texel,
        vec3(43.0, 141.0, 173.0) / 255.0) < 0.055;
    bool is_armor = distance(texel,
        vec3(184.0, 190.0, 196.0) / 255.0) < 0.055;
    int material_id = is_cyan ? (lens_emissive ? 3 : 2) :
        (is_armor ? 0 : 1);
    // One face normal for both authored triangles: no internal diagonal.
    vec3 face = normalize(NORMAL);
    float illumination = clamp(dot(face, normalize(vec3(-0.45, 0.65, 0.70)))
        * 0.5 + 0.5, 0.0, 1.0);
    int levels = material_id == 0 ? armor_levels :
        (material_id == 1 ? dark_levels : lens_levels);
    float threshold = material_id == 0 ? armor_threshold :
        (material_id == 1 ? dark_threshold : lens_threshold);
    float brightness = shade_brightness(levels, threshold, illumination);
    float bias = levels >= 2 ? (1.0 + panel_bias) : 1.0;
    vec3 shaded = clamp(base * brightness * bias, vec3(0.0), vec3(1.0));
    if (is_cyan && lens_emissive) {
        // Preview-only bright cyan. Not applied to gameplay or other parts.
        shaded = mix(base, vec3(0.30, 0.82, 1.0), 0.67);
        EMISSION = vec3(0.09, 0.29, 0.43);
    }
    // Material-name tap is a single blue-white pulse over the selected
    // colored pixels; it never swaps source materials or adds draw passes.
    bool flash_target = material_id == flash_material ||
        (is_cyan && flash_material == 3);
    if (flash_target && flash_power > 0.0) {
        shaded = mix(shaded, vec3(0.74, 0.94, 1.0), flash_power);
        EMISSION += vec3(0.12, 0.36, 0.50) * flash_power;
    }
    ALBEDO = shaded;
}
