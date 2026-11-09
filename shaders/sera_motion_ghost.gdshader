shader_type spatial;
// v77: Three motion snapshots in one MultiMesh per character part.
// INSTANCE_ID selects the snapshot's fade. Positions/poses are frozen when
// emitted by Godot; no live-bone offset or screen-space blur is used.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D sera_palette : source_color, filter_nearest, repeat_disable;
uniform vec3 set_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 trail_alphas = vec3(0.0);
varying float afterimage_slot;
void vertex() {
    afterimage_slot = float(INSTANCE_ID);
}
void fragment() {
    vec4 authored_color = texture(sera_palette, UV);
    ALBEDO = authored_color.rgb * set_tint;
    float fade = trail_alphas.x;
    if (afterimage_slot > 1.5) {
        fade = trail_alphas.z;
    } else if (afterimage_slot > 0.5) {
        fade = trail_alphas.y;
    }
    ALPHA = authored_color.a * fade;
}
