shader_type spatial;
// NEXUS HEAD D (H02) surface preview only. The 3px visible-mesh-ID contour
// remains a separate CanvasItem pass. No source model or gameplay material edits.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform int shade_levels : hint_range(2, 4) = 4;
uniform float panel_bias : hint_range(-0.1, 0.1) = 0.0;

void fragment() {
    vec3 base = texture(source_texture, UV).rgb * source_tint.rgb;
    // The IRIS cyan lens must keep its original RGB rather than being dimmed
    // by the armor face shading. Dark blue-grey frame pixels are not excluded.
    bool eye_pixel = base.b > 0.17 && base.g > base.r * 1.25
        && base.b > base.r * 1.6 && base.g > base.b * 0.45;
    // Reconstruct the true screen-space geometric face normal. This avoids
    // smooth interpolated vertex normals hiding individual polygon planes.
    vec3 face = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
    if (dot(face, NORMAL) < 0.0) {
        face = -face;
    }
    float illumination = clamp(dot(face, normalize(vec3(-0.45, 0.65, 0.70)))
        * 0.5 + 0.5, 0.0, 1.0);
    float brightness = 1.0;
    if (shade_levels == 2) {
        brightness = illumination < 0.52 ? 0.62 : 1.05;
    } else if (shade_levels == 3) {
        brightness = illumination < 0.38 ? 0.60 :
            (illumination < 0.72 ? 0.82 : 1.05);
    } else {
        brightness = illumination < 0.30 ? 0.55 :
            (illumination < 0.52 ? 0.70 :
            (illumination < 0.77 ? 0.88 : 1.05));
    }
    ALBEDO = eye_pixel ? base : clamp(base *
        brightness * (1.0 + panel_bias), vec3(0.0), vec3(1.0));
}
