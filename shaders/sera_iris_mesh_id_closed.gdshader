shader_type spatial;
// HEAD D only: one unlit ID per closed solid mesh.
// SERA authored normals are outward while Godot's front winding is clockwise.
render_mode unshaded, cull_front, depth_draw_opaque;
uniform float mesh_id : hint_range(0.0, 1.0) = 0.125;
void fragment() {
    ALBEDO = vec3(mesh_id, 0.0, 0.0);
}
