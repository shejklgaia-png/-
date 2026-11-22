shader_type spatial;
// Depth-resolved visible ID for shared all-scene outline compositing.
// R/B encode 12-bit unique index; G encodes actor/facility/clutter/GRID.
render_mode unshaded, cull_front, depth_draw_opaque;

uniform int mesh_id_base = 1;
uniform int role_code = 1;
uniform bool use_instance_roles = false;
varying vec3 encoded_id;
void vertex() {
    int index = (mesh_id_base + INSTANCE_ID) % 4096;
    int category = use_instance_roles ?
        clamp(int(floor(INSTANCE_CUSTOM.r * 8.0 + 0.5)), 1, 4) :
        role_code;
    encoded_id = vec3(
        float(index % 64) / 63.0,
        float(category) / 8.0,
        float((index / 64) % 64) / 63.0);
}
void fragment() {
    ALBEDO = encoded_id;
}
