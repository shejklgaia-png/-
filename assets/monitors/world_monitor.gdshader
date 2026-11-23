shader_type spatial;
render_mode unshaded, cull_disabled;

// Each screen independently produces an unbounded 24 fps image sequence on GPU.
// The original authored atlas provides its typography and static visual identity.
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform int mode = 0; // N01..N06 = 0..5, B01..B05 = 6..10
uniform float fps = 24.0;
uniform float atlas_fps = 1.0;
uniform float phase = 0.0;

const vec3 BG = vec3(0.018, 0.077, 0.104);
const vec3 PANEL = vec3(0.031, 0.123, 0.164);
const vec3 GRID = vec3(0.095, 0.247, 0.298);
const vec3 CYAN = vec3(0.36, 0.86, 0.95);
const vec3 BLUE = vec3(0.16, 0.53, 0.71);
const vec3 AMBER = vec3(0.98, 0.69, 0.35);
const vec3 WHITE = vec3(0.73, 0.93, 1.0);
const float TAU = 6.28318530718;

float box(vec2 p, vec4 r) {
    return step(r.x, p.x) * step(p.x, r.z) * step(r.y, p.y) * step(p.y, r.w);
}
float line2(vec2 p, vec2 a, vec2 b, float width) {
    vec2 ab = b - a;
    float u = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.00001), 0.0, 1.0);
    return 1.0 - smoothstep(width, width * 1.7, length(p - a - ab * u));
}
float edge_ring(vec2 p, vec2 center, float radius, float width, float aspect) {
    vec2 v = (p - center) * vec2(aspect, 1.0);
    return 1.0 - smoothstep(width, width * 1.7, abs(length(v) - radius));
}
float hash1(float x) {
    return fract(sin(x * 73.173 + 3.1415) * 43758.5453);
}
float region(vec2 p) { return box(p, vec4(0.060, 0.315, 0.945, 0.870)); }

void fragment() {
    vec2 p = UV;
    float tick = floor((TIME + phase) * fps);
    float t = tick / fps;
    // Old atlas frames are only a decorative sub-layer, never the motion clock.
    float frame = mod(floor(t * atlas_fps), 8.0);
    vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
    vec2 grid = vec2(4.0, 2.0);
    vec2 texel = 0.7 * grid / vec2(textureSize(atlas, 0));
    vec2 coord = (cell + mix(texel, vec2(1.0) - texel, p)) / grid;
    vec3 c = texture(atlas, coord).rgb;

    float area = region(p);
    c = mix(c, BG * 0.78 + PANEL * 0.22, area * 0.80);
    // A stable screen grid; all moving elements below use the same 24 Hz tick.
    float gridx = 1.0 - smoothstep(0.003, 0.005, abs(fract(p.x * 16.0) - 0.5));
    float gridy = 1.0 - smoothstep(0.003, 0.005, abs(fract(p.y * 12.0) - 0.5));
    c = mix(c, GRID, area * max(gridx, gridy) * 0.25);

    if (mode == 0) { // N01: active system waveform and 8 utilization lanes
        float wave = 0.565 + 0.055 * sin(p.x * 35.0 - t * 5.5)
            + 0.028 * sin(p.x * 79.0 + t * 2.8);
        float chart = box(p, vec4(0.08, 0.38, 0.70, 0.78));
        float trace = 1.0 - smoothstep(0.007, 0.016, abs(p.y - wave));
        c = mix(c, CYAN, chart * trace);
        float sweep = 0.08 + 0.62 * fract(t / 4.0);
        c = mix(c, BLUE, chart * (1.0 - smoothstep(0.003, 0.008, abs(p.x - sweep))) * 0.8);
        float bar = floor((p.x - 0.74) * 26.0);
        float load = 0.35 + 0.5 * hash1(bar * 1.8 + floor(t * 3.0));
        float fill = box(p, vec4(0.74, 0.82 - load * 0.44, 0.94, 0.82));
        fill *= step(0.18, fract((p.x - 0.74) * 26.0));
        c = mix(c, mix(CYAN, AMBER, step(0.8, load)), fill);
    } else if (mode == 1) { // N02: OS diagnostics, continuous log advancement
        float y = (p.y - 0.33) * 13.0 + t * 1.8;
        float row = floor(y);
        float column = floor(p.x * 24.0);
        float chars = step(0.30, hash1(row * 35.0 + column * 7.0));
        float ribbon = box(p, vec4(0.10, 0.34, 0.90, 0.83));
        float textline = step(0.30, fract(y)) * step(fract(y), 0.58);
        c = mix(c, BLUE, ribbon * textline * chars * step(0.12, fract(p.x * 24.0)) * 0.85);
        float latest = 1.0 - smoothstep(0.0, 0.16, abs(fract(y) - 0.48));
        c = mix(c, CYAN, ribbon * latest * chars * 0.32);
        c = mix(c, AMBER, box(p, vec4(0.075, 0.80, 0.11, 0.835)) * step(0.5, fract(t * 2.0)));
    } else if (mode == 2) { // N03: target acquisition reticle
        vec2 center = vec2(0.50 + 0.20 * sin(t * 0.86), 0.57 + 0.15 * sin(t * 1.25));
        float sight = box(p, vec4(0.09, 0.35, 0.91, 0.84));
        float ring = edge_ring(p, center, 0.142, 0.006, 1.05);
        float cross = line2(p, center - vec2(0.21, 0.0), center + vec2(0.21, 0.0), 0.003)
            + line2(p, center - vec2(0.0, 0.22), center + vec2(0.0, 0.22), 0.003);
        float corners = ring + cross * 0.53;
        c = mix(c, CYAN, sight * clamp(corners, 0.0, 1.0));
        c = mix(c, AMBER, sight * edge_ring(p, center, 0.026, 0.005, 1.0));
    } else if (mode == 3) { // N04: radar sweeping with persistent blips
        vec2 center = vec2(0.5, 0.595);
        vec2 dir = vec2(cos(t * 1.42), sin(t * 1.42));
        vec2 delta = (p - center) * vec2(0.82, 1.0);
        float circle = 0.0;
        for (int i = 1; i <= 3; i++) {
            circle += edge_ring(p, center, float(i) * 0.082, 0.004, 0.82);
        }
        float sweep = line2(p * vec2(0.82, 1.0), center * vec2(0.82, 1.0),
            center * vec2(0.82, 1.0) + dir * 0.25, 0.005);
        float inradar = step(length(delta), 0.253);
        c = mix(c, BLUE, circle * inradar);
        c = mix(c, CYAN, sweep * inradar);
        vec2 dot1 = vec2(0.44, 0.52);
        vec2 dot2 = vec2(0.63, 0.65);
        float blips = (1.0 - smoothstep(0.004, 0.013, length(p - dot1)))
            + (1.0 - smoothstep(0.004, 0.013, length(p - dot2)));
        c = mix(c, AMBER, inradar * blips * (0.6 + 0.4 * sin(t * 3.0) * sin(t * 3.0)));
    } else if (mode == 4) { // N05: archive rows, smooth 24 Hz scroll
        float row = (p.y - 0.34) * 11.0 + t * 0.62;
        float rowid = floor(row);
        float band = step(0.16, fract(row)) * step(fract(row), 0.63);
        float width = 0.36 + 0.38 * hash1(rowid + 8.0);
        float list = box(p, vec4(0.11, 0.35, 0.12 + width, 0.84)) * band;
        c = mix(c, BLUE, list);
        float accent = box(p, vec4(0.11, 0.35, 0.155, 0.84)) * band;
        c = mix(c, CYAN, accent);
        c = mix(c, AMBER, box(p, vec4(0.84, 0.35, 0.875, 0.83)) * band);
    } else if (mode == 5) { // N06: distributed processing lanes
        float col = floor((p.x - 0.10) * 14.0);
        float progress = 0.12 + 0.73 * (0.5 + 0.5 * sin(t * (0.8 + col * 0.12) + col));
        float bars = box(p, vec4(0.10, 0.81 - 0.39 * progress, 0.90, 0.81));
        bars *= step(0.12, fract((p.x - 0.10) * 14.0)) * step(fract((p.x - 0.10) * 14.0), 0.78);
        c = mix(c, mix(BLUE, CYAN, progress), bars);
        float scan = 0.10 + 0.79 * fract(t * 0.12);
        c = mix(c, AMBER, box(p, vec4(scan, 0.37, scan + 0.006, 0.82)));
    } else if (mode == 6) { // B01: retrieved telemetry and timestamp cursor
        float row = floor((p.y - 0.36) * 13.0);
        float cycle = floor(t * 1.75);
        float chars = step(0.32, hash1(row * 11.0 + floor(p.x * 21.0) + cycle));
        float lines = box(p, vec4(0.11, 0.36, 0.88, 0.79));
        lines *= step(0.20, fract((p.y - 0.36) * 13.0))
            * step(fract((p.y - 0.36) * 13.0), 0.48);
        c = mix(c, CYAN, lines * chars * 0.75);
        float selected = mod(floor(t * 1.75), 6.0);
        float high = step(abs(row - selected), 0.1);
        c = mix(c, AMBER, lines * high * 0.74);
    } else if (mode == 7) { // B02: four-resource inventory readout
        float row = floor((p.y - 0.37) * 10.0);
        float active = mod(floor(t * 0.9), 4.0);
        float selected = 1.0 - step(0.2, abs(mod(row, 4.0) - active));
        float rowbox = box(p, vec4(0.09, 0.37, 0.90, 0.79))
            * step(0.18, fract((p.y - 0.37) * 10.0)) * step(fract((p.y - 0.37) * 10.0), 0.69);
        c = mix(c, mix(BLUE, CYAN, selected), rowbox * box(p, vec4(0.14, 0.32, 0.55, 0.83)));
        float amount = 0.28 + 0.60 * hash1(row + floor(t * 1.0));
        c = mix(c, mix(BLUE, AMBER, selected),
            rowbox * box(p, vec4(0.61, 0.32, 0.61 + 0.30 * amount, 0.83)));
    } else if (mode == 8) { // B03: print simulation plus real moving progress
        float progress = fract(t / 8.0);
        float top = 0.76 - 0.38 * progress;
        float cross_section = 0.26 - 0.09 * abs(p.y - 0.57);
        float part = step(abs(p.x - 0.5), cross_section)
            * step(top, p.y) * step(p.y, 0.76);
        float hatch = step(0.27, fract((p.x + p.y) * 43.0));
        c = mix(c, mix(BLUE, CYAN, hatch), part);
        c = mix(c, AMBER, line2(p, vec2(0.18, top), vec2(0.82, top), 0.009));
        c = mix(c, CYAN, box(p, vec4(0.10, 0.81, 0.10 + progress * 0.80, 0.84)));
    } else if (mode == 9) { // B04: reactive power dial and output meter
        vec2 ctr = vec2(0.48, 0.58);
        float angle = -2.4 + 4.8 * (0.5 + 0.5 * sin(t * 0.85));
        vec2 end = ctr + vec2(cos(angle), sin(angle)) * 0.21;
        c = mix(c, BLUE, edge_ring(p, ctr, 0.24, 0.007, 1.0));
        c = mix(c, CYAN, line2(p, ctr, end, 0.009));
        c = mix(c, AMBER, edge_ring(p, ctr, 0.026, 0.006, 1.0));
        float reading = 0.45 + 0.45 * sin(t * 1.20 + 0.5);
        c = mix(c, CYAN, box(p, vec4(0.18, 0.835, 0.18 + 0.66 * reading, 0.854)));
    } else { // B05: blueprints rotate between three designs and scan over them
        float variant = mod(floor(t / 3.0), 3.0);
        float sx = 0.22 + 0.045 * variant;
        float sy = 0.23 - 0.038 * variant;
        float rim = 0.0;
        rim += line2(p, vec2(0.50 - sx, 0.57 - sy), vec2(0.50 + sx, 0.57 - sy), 0.005);
        rim += line2(p, vec2(0.50 + sx, 0.57 - sy), vec2(0.50 + sx, 0.57 + sy), 0.005);
        rim += line2(p, vec2(0.50 + sx, 0.57 + sy), vec2(0.50 - sx, 0.57 + sy), 0.005);
        rim += line2(p, vec2(0.50 - sx, 0.57 + sy), vec2(0.50 - sx, 0.57 - sy), 0.005);
        rim += line2(p, vec2(0.5, 0.57 - sy), vec2(0.5, 0.57 + sy), 0.004);
        rim += line2(p, vec2(0.5 - sx, 0.57), vec2(0.5 + sx, 0.57), 0.004);
        c = mix(c, CYAN, min(rim, 1.0));
        float scan = 0.28 + 0.44 * fract(t * 0.31);
        c = mix(c, AMBER, line2(p, vec2(scan, 0.34), vec2(scan, 0.79), 0.004));
    }

    // Low-contrast phosphor scanlines, fixed at 24 fps and confined to the panel.
    float phosphor = 0.97 + 0.03 * sin((p.y * 220.0 + t * 3.0) * TAU);
    ALBEDO = clamp(c * phosphor, vec3(0.0), vec3(1.0));
}
