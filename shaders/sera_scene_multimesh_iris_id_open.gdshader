shader_type spatial;
// Shared-scene MultiMesh adaptation of the ORIGINAL IRIS red-only ID pass.
// The only addition is per-instance indexing; pixel encoding is identical.
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform int mesh_id_base = 1;
varying float mesh_id;
void vertex() {
    int palette_index = ((mesh_id_base + INSTANCE_ID - 1) % 7) + 1;
    mesh_id = float(palette_index) / 8.0;
}
void fragment() {
    ALBEDO = vec3(mesh_id, 0.0, 0.0);
}
