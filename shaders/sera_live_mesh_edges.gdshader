shader_type spatial;
// NEXUS SERA: current-frame outlines, drawn in the source 3D viewport.
// Source child ribbons share the authored mesh and bone transform; no ID pass.
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float silhouette_px : hint_range(1.0, 6.0) = 4.0;
uniform float boundary_px : hint_range(1.0, 6.0) = 3.0;

varying float ribbon_visible;

void vertex() {
    // The original mesh is NOT moved. A source child contains two triangles
    // for every eligible edge, with a local-space tangent along the edge.
    // COLOR.rgb stores the second face normal, COLOR.a is 0 for an open
    // border/mesh intersection, 1 for a shared edge.
    vec3 source_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 edge_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 to_eye = normalize(CAMERA_POSITION_WORLD - edge_world);
    vec3 first = normalize(MODEL_NORMAL_MATRIX * NORMAL);
    vec3 second = normalize(MODEL_NORMAL_MATRIX *
        (COLOR.rgb * 2.0 - vec3(1.0)));
    float first_dot = dot(first, to_eye);
    float second_dot = dot(second, to_eye);
    float open_border = 1.0 - step(0.5, COLOR.a);
    // A crossing of front and rear facing polygons is a silhouette. Small
    // tolerance retains an exact-on-edge contour on low-poly SERA geometry.
    float crosses_view = step(first_dot * second_dot, 0.001);
    ribbon_visible = max(open_border, crosses_view);

    vec3 direction = normalize(TANGENT);
    vec3 next_view = (MODELVIEW_MATRIX *
        vec4(VERTEX + direction * 0.1, 1.0)).xyz;
    // Move both endpoints slightly toward the camera BEFORE projection:
    // at equal depth a transparent line can otherwise fail the opaque
    // depth test and disappear on Android GL Compatibility.
    float bias = 0.003;
    source_view.z += bias;
    next_view.z += bias;
    vec4 clip = PROJECTION_MATRIX * vec4(source_view, 1.0);
    vec4 next_clip = PROJECTION_MATRIX * vec4(next_view, 1.0);
    if (clip.w <= 0.00001 || next_clip.w <= 0.00001) {
        ribbon_visible = 0.0;
        POSITION = vec4(2.0, 2.0, 0.0, 1.0);
    } else {
        vec2 direction_px = ((next_clip.xy / next_clip.w) -
            (clip.xy / clip.w)) * VIEWPORT_SIZE;
        float direction_size = length(direction_px);
        if (direction_size < 0.00001) {
            ribbon_visible = 0.0;
            POSITION = vec4(2.0, 2.0, 0.0, 1.0);
        } else {
            vec2 across = vec2(-direction_px.y, direction_px.x) /
                direction_size;
            // UV.x is -1 or +1 on opposite sides of the quad.
            float half_width = mix(silhouette_px, boundary_px, open_border) * 0.5;
            clip.xy += across * (2.0 * half_width * UV.x /
                VIEWPORT_SIZE) * clip.w;
            POSITION = clip;
        }
    }
}

void fragment() {
    if (ribbon_visible < 0.5) {
        discard;
    }
    ALBEDO = ink_color.rgb;
    ALPHA = ink_color.a;
}
