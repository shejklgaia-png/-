shader_type canvas_item;
// Present the exact same Bittaran visible-ID pixels inside native UI
// SubViewports. All ID encoding, ownership, width and sampling run through
// the identical shared include; only the required CanvasItem output differs.
render_mode blend_mix;
#include "res://shaders/sera_visible_mesh_id_outline_core.gdshaderinc"

void fragment() {
    float alpha = sera_visible_id_ink_alpha(UV);
    if (alpha < 0.001) {
        discard;
    }
    COLOR = vec4(ink_color.rgb, alpha);
}
