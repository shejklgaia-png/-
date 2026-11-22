shader_type spatial;
// NEXUS full-body SILHOUETTE only.
// Project the original opaque equipment faces in eight screen directions.
// A shared stencil mask (ref 17, written first) erases ALL pixels covered
// by the unshifted complete character. No edge/facing/normal calculation.
// MultiMesh INSTANCE_ID selects the direction without eight Mesh nodes.
render_mode unshaded, cull_disabled, depth_draw_never,
    depth_test_disabled, blend_mix, fog_disabled;
stencil_mode read, compare_not_equal, 17;

uniform vec4 outline_color : source_color =
    vec4(0.043137, 0.066667, 0.094118, 1.0);
uniform float outline_px : hint_range(1.0, 8.0, 0.5) = 3.0;
// Only used for skeletal/fallback MeshInstance3D copies.
uniform int override_direction : hint_range(-1, 7) = -1;

void vertex() {
    vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX *
        vec4(VERTEX, 1.0));
    int direction = override_direction >= 0 ?
        override_direction : (INSTANCE_ID % 8);
    // Directions are equally spaced at 45 degrees, each EXACTLY
    // outline_px long in viewport pixel coordinates (including diagonals).
    vec2 offset_dir = vec2(0.0);
    if (direction == 0) {
        offset_dir = vec2(1.0, 0.0);
    } else if (direction == 1) {
        offset_dir = vec2(-1.0, 0.0);
    } else if (direction == 2) {
        offset_dir = vec2(0.0, 1.0);
    } else if (direction == 3) {
        offset_dir = vec2(0.0, -1.0);
    } else if (direction == 4) {
        offset_dir = vec2(0.70710678, 0.70710678);
    } else if (direction == 5) {
        offset_dir = vec2(-0.70710678, 0.70710678);
    } else if (direction == 6) {
        offset_dir = vec2(0.70710678, -0.70710678);
    } else {
        offset_dir = vec2(-0.70710678, -0.70710678);
    }

    if (clip.w > 0.00001) {
        clip.xy += outline_px * offset_dir *
            (2.0 / VIEWPORT_SIZE) * clip.w;
    }
    POSITION = clip;
}

void fragment() {
    ALBEDO = outline_color.rgb;
    // ALPHA forces the transparent pass needed for stencil reads.
    ALPHA = outline_color.a;
}
