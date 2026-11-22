shader_type spatial;
// NEXUS only: depth-validated, same-frame screen-space outline.
// The opaque SERA mesh already writes its visible front surfaces to depth.
// Reject ribbon pixels at/behind that depth and keep only unobstructed
// outside pixels. This fixes the stencil union that removed every edge
// even when the unmasked ribbon was correctly displayed on Android.
// No second camera, CPU readback, stencil, or per-frame topology rebuild.
render_mode unshaded, cull_disabled, depth_draw_never,
    depth_test_disabled, blend_mix, fog_disabled;
// No stencil read/write in this production pass.
uniform sampler2D scene_depth : hint_depth_texture,
    repeat_disable, filter_nearest;
uniform float depth_bias : hint_range(0.0, 0.001, 0.00001) = 0.00004;

uniform vec4 outline_color : source_color =
    vec4(0.043137, 0.066667, 0.094118, 1.0);
uniform float exterior_px : hint_range(0.5, 8.0) = 3.0;
varying float projected_edge_valid;

void vertex() {
    // Reuse the existing GPU ribbon convention:
    // NORMAL is the ORIGINAL local-space edge tangent.
    // UV.x is -1/+1 across the ribbon; UV.y is -1/+1 at its ends.
    vec3 eye = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 tangent_eye = normalize(
        (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec4 clip = PROJECTION_MATRIX * vec4(eye, 1.0);
    vec4 tip = PROJECTION_MATRIX * vec4(
        eye + tangent_eye * 0.1, 1.0);

    projected_edge_valid = 0.0;
    if (clip.w > 0.00001 && tip.w > 0.00001) {
        vec2 pixel_tangent = (
            (tip.xy / tip.w) - (clip.xy / clip.w)
        ) * (VIEWPORT_SIZE * 0.5);
        float pixel_length = length(pixel_tangent);
        if (pixel_length > 0.0001) {
            projected_edge_valid = 1.0;
            vec2 along_px = pixel_tangent / pixel_length;
            vec2 across_px = vec2(-along_px.y, along_px.x);
            // NDC spans 2.0 units per viewport dimension. The ribbon
            // straddles the source edge by +/-3 actual viewport pixels.
            // Fragments at or behind the opaque SERA depth are rejected
            // below. Only fragments in front of the scene depth remain.
            vec2 shifted_px = across_px * exterior_px * UV.x;
            // Short end caps bridge neighboring polygon corners.
            shifted_px += along_px * min(exterior_px, 2.5) * UV.y;
            clip.xy += shifted_px * (2.0 / VIEWPORT_SIZE) * clip.w;
        }
    }
    POSITION = clip;
}

void fragment() {
    if (projected_edge_valid < 0.5) {
        discard;
    }
    // Opaque SERA depth includes the union of ALL currently visible armor
    // and weapons, regardless of mesh boundaries. Front-facing panel edges
    // and covered/hidden edges therefore fail the depth comparison, while
    // each ribbon's visible exterior pixels remain. Sample once per pixel.
    float opaque_depth = texture(scene_depth, SCREEN_UV).r;
    float ribbon_depth = FRAGCOORD.z;
    if (CLIP_SPACE_FAR < -0.5) {
        // GL Compatibility: near = 0, far = 1.
        if (opaque_depth <= ribbon_depth + depth_bias) {
            discard;
        }
    } else {
        // Forward+/Mobile reversed-Z: near = 1, far = 0.
        if (opaque_depth >= ribbon_depth - depth_bias) {
            discard;
        }
    }
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
