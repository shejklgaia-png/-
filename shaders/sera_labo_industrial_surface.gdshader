shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D surface_map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 paint : source_color = vec4(0.5,0.57,0.64,1.0);
uniform float metres_per_tile = 2.0;
uniform float wear_amount = 0.46;
uniform float roughness_value = 0.86;
varying vec3 metre_pos;
varying vec3 part_normal;
void vertex() {
    // MODEL_MATRIX includes the MultiMesh instance and parent transform.
    // Axis lengths turn unit-mesh vertices into metre coordinates without
    // anchoring UVs to the world: moving cargo and tools keep their paint.
    vec3 dimensions = max(vec3(length(MODEL_MATRIX[0].xyz),
        length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz)),vec3(0.001));
    metre_pos = VERTEX * dimensions;
    part_normal = NORMAL / dimensions;
}
void fragment() {
    vec3 n = normalize(part_normal);
    vec3 w = pow(abs(n),vec3(6.0));
    w /= max(w.x+w.y+w.z,0.0001);
    vec3 p = metre_pos / metres_per_tile;
    // Three planar projections, blend only where normals change direction.
    // Physical tile size stays constant on long beams, slabs and round parts.
    vec3 tx = texture(surface_map,p.zy).rgb;
    vec3 ty = texture(surface_map,p.xz).rgb;
    vec3 tz = texture(surface_map,p.xy).rgb;
    vec3 tex = tx*w.x + ty*w.y + tz*w.z;
    // Weathering must modulate paint rather than replace it with near black.
    ALBEDO = paint.rgb * mix(vec3(1.0),max(tex,vec3(0.45)),wear_amount);
    ROUGHNESS = roughness_value;
    METALLIC = 0.06;
}
