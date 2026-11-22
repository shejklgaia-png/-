shader_type spatial;
// NEXUS SERA: edge ribbons follow the exact source MeshInstance3D hierarchy.
// No secondary camera, ID texture, screen capture or previous-frame pose.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float silhouette_px : hint_range(1.0, 6.0) = 4.0;
uniform float boundary_px : hint_range(1.0, 6.0) = 3.0;

varying float draw_edge;

void vertex() {
    // NORMAL = first face normal; COLOR.rgb = second normal encoded to 0..1.
    // COLOR.a = 0 for an open mesh boundary, 1 for two adjacent faces.
    // TANGENT = local edge direction; UV.x = +/- extrusion side.
    vec3 world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 eye = normalize(CAMERA_POSITION_WORLD - world_point);
    vec3 first_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
    vec3 second_normal = normalize(mat3(MODEL_MATRIX) *
        (COLOR.rgb * 2.0 - vec3(1.0)));
    float first_facing = dot(first_normal, eye);
    float second_facing = dot(second_normal, eye);
    bool boundary = COLOR.a < 0.5;
    // Only view-dependent silhouette transitions, never arbitrary sharp
    // angles or the internal diagonals from a triangulated authored quad.
    draw_edge = boundary ? 1.0 :
        ((first_facing * second_facing < -0.00001) ? 1.0 : 0.0);

    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec4 next_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX *
        vec4(VERTEX + TANGENT * 0.1, 1.0);
    if (clip.w <= 0.0 || next_clip.w <= 0.0) {
        draw_edge = 0.0;
        POSITION = vec4(2.0, 2.0, 0.0, 1.0);
        return;
    }
    vec2 pixel_direction = (next_clip.xy / next_clip.w -
        clip.xy / clip.w) * VIEWPORT_SIZE;
    float direction_length = length(pixel_direction);
    if (direction_length < 0.00001) {
        draw_edge = 0.0;
        POSITION = vec4(2.0, 2.0, 0.0, 1.0);
        return;
    }
    vec2 perpendicular = vec2(
        -pixel_direction.y, pixel_direction.x) / direction_length;
    float stroke = boundary ? boundary_px : silhouette_px;
    clip.xy += perpendicular * (UV.x * stroke / VIEWPORT_SIZE) * clip.w;
    // Godot 4 uses reversed Z. A minuscule forward bias avoids z-fighting
    // against the face which owns this physical edge; scene depth still
    // occludes ribbons behind nearer body parts.
    clip.z += 0.00002 * clip.w;
    POSITION = clip;
}

void fragment() {
    if (draw_edge < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
