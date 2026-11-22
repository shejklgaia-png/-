shader_type spatial;
// Each MultiMesh INSTANCE_ID gets a separate mesh ID, without duplicating
// the source MultiMesh or allocating custom per-instance color buffers.
render_mode unshaded, cull_back, depth_draw_opaque;
uniform int mesh_id_base = 1;
varying vec3 encoded_id;

void vertex() {
    int label = mesh_id_base + INSTANCE_ID;
    encoded_id = vec3(
        float((label >> 8) & 15) / 15.0,
        float((label >> 4) & 15) / 15.0,
        float(label & 15) / 15.0
    );
}
void fragment() {
    ALBEDO = encoded_id;
}
