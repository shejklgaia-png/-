shader_type canvas_item;
// HEAD D / NEXUS only. The drawing TextureRect uses a transparent 1x1
// PLACEHOLDER, never the raw red/black ID render target. The color IDs
// are read through a dedicated sampler. If this shader cannot compile,
// the stock TextureRect is fully transparent, not a debug-ID takeover.
render_mode blend_mix;

uniform sampler2D mesh_id_texture : filter_nearest, repeat_disable;
uniform vec2 mesh_id_texel = vec2(0.0026041667, 0.0026041667);
uniform vec4 ink_color : source_color = vec4(0.090196, 0.129412, 0.184314, 1.0);
uniform float stroke_px : hint_range(1.0, 4.0) = 3.0;

bool mismatched_id(float center_id, float neighbor_id) {
    if (neighbor_id < 0.06) {
        return true; // Mesh silhouette, drawn 3px INSIDE the visible mesh.
    }
    // Only the higher-ID side of a pair of touching pieces draws the seam.
    // Otherwise two 3px bands would merge into a 6px inter-mesh line.
    return neighbor_id + 0.05 < center_id;
}

float id_at(vec2 uv) {
    // Pixels outside the ID image must be treated as BACKGROUND rather
    // than clamped to the terminal mesh color.
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return 0.0;
    }
    return texture(mesh_id_texture, uv).r;
}

void fragment() {
    float id = id_at(UV);
    bool edge = false;
    if (id >= 0.06) {
        // Four neighbors for each radius. The ID scene depth buffer already
        // removes hidden parts; there is no normal/angle/crease comparison.
        for (int r = 1; r <= 3; r++) {
            float radius = float(r);
            if (radius > stroke_px) {
                break;
            }
            vec2 d = mesh_id_texel * radius;
            edge = edge ||
                mismatched_id(id, id_at(UV + vec2( d.x, 0.0))) ||
                mismatched_id(id, id_at(UV + vec2(-d.x, 0.0))) ||
                mismatched_id(id, id_at(UV + vec2(0.0,  d.y))) ||
                mismatched_id(id, id_at(UV + vec2(0.0, -d.y)));
        }
    }
    // Never return from Godot's built-in fragment() entry point. Writing
    // one deterministic transparent result also avoids undefined output.
    COLOR = vec4(ink_color.rgb, edge ? ink_color.a : 0.0);
}
