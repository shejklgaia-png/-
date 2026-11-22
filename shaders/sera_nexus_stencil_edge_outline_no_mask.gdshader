shader_type spatial;
// NEXUS only: a same-frame, union-masked screen-space outline.
// All source topological edges are eligible. The single stencil mask
// containing ALL visible opaque equipment removes internal pixels.
// This avoids per-face front/back decisions and smooth-hull normal signs.
render_mode unshaded, cull_disabled, depth_draw_never,
    depth_test_disabled, blend_mix, fog_disabled;
// Diagnostic mode 16: stencil compare intentionally disabled.
// Vertex expansion and fragment drawing match the production shader.

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
            // Pixels inside the full-body silhouette are rejected by
            // the shared stencil. Only the outside 0..3px remains.
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
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}
