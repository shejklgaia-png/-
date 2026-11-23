shader_type spatial;
render_mode unshaded, cull_disabled;

// LABO / REFINE / STORAGE: six distinct procedural image sequences at 24 Hz.
// No ImageTexture uploads, CPU pixel generation, or finite sprite frame limit.
uniform int mode = 0;
uniform float fps = 24.0;

const vec3 BG = vec3(0.016, 0.070, 0.105);
const vec3 DEEP = vec3(0.027, 0.112, 0.147);
const vec3 TRACK = vec3(0.075, 0.23, 0.29);
const vec3 CYAN = vec3(0.26, 0.82, 0.92);
const vec3 AMBER = vec3(0.98, 0.65, 0.26);
const vec3 WHITE = vec3(0.70, 0.94, 1.0);
const float TAU = 6.28318530718;

float rect(vec2 p, vec4 r) {
    return step(r.x, p.x) * step(p.x, r.z) * step(r.y, p.y) * step(p.y, r.w);
}
float line2(vec2 p, vec2 a, vec2 b, float width) {
    vec2 v = b - a;
    float h = clamp(dot(p - a, v) / max(dot(v, v), 0.00001), 0.0, 1.0);
    return 1.0 - smoothstep(width, width * 1.8, length(p - a - v * h));
}
float ring(vec2 p, vec2 ctr, float radius, float width) {
    return 1.0 - smoothstep(width, width * 1.7, abs(length(p - ctr) - radius));
}
float hash1(float v) { return fract(sin(v * 81.43 + 3.2) * 43758.5453); }

void fragment() {
    vec2 p = UV;
    float tick = floor(TIME * fps);
    float t = tick / fps;
    vec3 c = BG;

    float inside = rect(p, vec4(0.052, 0.12, 0.948, 0.94));
    c = mix(c, DEEP, inside);
    float grid_x = 1.0 - smoothstep(0.002, 0.005, abs(fract(p.x * 14.0) - 0.5));
    float grid_y = 1.0 - smoothstep(0.002, 0.005, abs(fract(p.y * 12.0) - 0.5));
    c = mix(c, TRACK, inside * max(grid_x, grid_y) * 0.26);
    // Fixed labels / decorative miniature status ledgers across six modes.
    c = mix(c, CYAN, rect(p, vec4(0.08, 0.13, 0.69, 0.156)));
    c = mix(c, TRACK, rect(p, vec4(0.08, 0.18, 0.91, 0.188)));
    for (int i = 0; i < 4; i++) {
        float x = 0.08 + float(i) * 0.095;
        c = mix(c, TRACK, rect(p, vec4(x, 0.895, x + 0.065, 0.913)));
    }

    if (mode == 0) { // PRINT: print nozzle, shell layering and percent rail
        float progress = fract(t / 9.0);
        float layer_top = 0.75 - 0.42 * progress;
        float side = 0.19 + 0.07 * sin((p.y - 0.56) * 4.0);
        float shell = step(abs(p.x - 0.50), side)
            * step(layer_top, p.y) * step(p.y, 0.76);
        float hatch = step(0.25, fract((p.x + p.y) * 37.0));
        c = mix(c, mix(TRACK, CYAN, hatch), shell);
        float nozzle_x = 0.5 + 0.27 * sin(t * 2.8);
        c = mix(c, AMBER, rect(p, vec4(nozzle_x - 0.042, layer_top - 0.090,
            nozzle_x + 0.042, layer_top - 0.028)));
        c = mix(c, WHITE, line2(p, vec2(nozzle_x, layer_top - 0.028),
            vec2(nozzle_x, layer_top + 0.020), 0.006));
        c = mix(c, CYAN, rect(p, vec4(0.12, 0.811, 0.12 + 0.76 * progress, 0.851)));
        c = mix(c, WHITE, line2(p, vec2(0.12 + 0.76 * progress, 0.797),
            vec2(0.12 + 0.76 * progress, 0.861), 0.004));
    } else if (mode == 1) { // FLOW: three animated material exchange channels
        for (int i = 0; i < 3; i++) {
            float y = 0.34 + float(i) * 0.15;
            float wave = y + 0.022 * sin(p.x * 16.0 - t * (1.6 + float(i) * 0.7));
            float band = rect(p, vec4(0.10, y - 0.064, 0.90, y + 0.064));
            c = mix(c, TRACK, band * 0.68);
            c = mix(c, CYAN, band * (1.0 - smoothstep(0.005, 0.012, abs(p.y - wave))));
            float pos = 0.11 + 0.78 * fract(t * (0.19 + float(i) * 0.09) + float(i) * 0.33);
            c = mix(c, (i == 1) ? AMBER : WHITE,
                ring(p, vec2(pos, y), 0.017, 0.009));
        }
        float flow = 0.4 + 0.33 * sin(t * 1.23);
        c = mix(c, CYAN, rect(p, vec4(0.12, 0.83, 0.12 + 0.76 * flow, 0.855)));
    } else if (mode == 2) { // PURITY: cycling spectroscopy columns and analysis trace
        for (int i = 0; i < 5; i++) {
            float x = 0.17 + float(i) * 0.145;
            float value = 0.25 + 0.58 * (0.5 + 0.5 * sin(t * 1.55 + float(i) * 1.4));
            float upper = 0.76 - value * 0.48;
            c = mix(c, (i >= 3) ? AMBER : CYAN,
                rect(p, vec4(x, upper, x + 0.085, 0.77)));
            c = mix(c, WHITE, line2(p, vec2(x, upper), vec2(x + 0.085, upper), 0.005));
        }
        float scan = 0.13 + 0.75 * fract(t * 0.18);
        c = mix(c, CYAN, line2(p, vec2(scan, 0.30), vec2(scan, 0.82), 0.003));
        c = mix(c, AMBER, rect(p, vec4(0.08, 0.84, 0.32, 0.858))
            * (0.5 + 0.5 * step(0.5, fract(t * 2.0))));
    } else if (mode == 3) { // RECYCLE: rotating material ring and moving particles
        vec2 ctr = vec2(0.50, 0.52);
        float angle = t * 0.8;
        c = mix(c, TRACK, ring(p, ctr, 0.255, 0.018));
        c = mix(c, CYAN, ring(p, ctr, 0.215, 0.007));
        for (int i = 0; i < 6; i++) {
            float a = angle + float(i) * TAU / 6.0;
            vec2 start = ctr + 0.10 * vec2(cos(a), sin(a));
            vec2 end = ctr + 0.22 * vec2(cos(a), sin(a));
            c = mix(c, CYAN, line2(p, start, end, 0.011));
        }
        for (int i = 0; i < 4; i++) {
            float a = -angle * 1.9 + float(i) * TAU * 0.25;
            vec2 pt = ctr + 0.31 * vec2(cos(a), sin(a));
            c = mix(c, AMBER, ring(p, pt, 0.013, 0.008));
        }
        c = mix(c, AMBER, ring(p, ctr, 0.055, 0.018));
        c = mix(c, CYAN, rect(p, vec4(0.13, 0.846,
            0.13 + 0.74 * (0.25 + 0.65 * fract(t / 7.0)), 0.868)));
    } else if (mode == 4) { // INVENTORY: 24 Hz scrolling rows, dynamic stock bars
        float scroll = (p.y - 0.29) * 10.0 + t * 0.82;
        float row = floor(scroll);
        float rowline = step(0.19, fract(scroll)) * step(fract(scroll), 0.69);
        float vis = rect(p, vec4(0.10, 0.29, 0.90, 0.83)) * rowline;
        float amount = 0.22 + 0.72 * hash1(row + floor(t * 0.4) * 4.0);
        float selected = 1.0 - step(0.16, abs(mod(row, 5.0) - mod(floor(t * 0.55), 5.0)));
        c = mix(c, mix(TRACK, CYAN, selected),
            vis * rect(p, vec4(0.13, 0.20, 0.39, 0.87)));
        c = mix(c, mix(CYAN, AMBER, selected),
            vis * rect(p, vec4(0.48, 0.20, 0.48 + 0.39 * amount, 0.87)));
        c = mix(c, WHITE, vis * rect(p, vec4(0.41, 0.20, 0.43, 0.87)));
    } else { // SCANNER: tracking viewport, sweep line and sensor texture
        vec2 center = vec2(0.50 + 0.14 * sin(t * 0.67), 0.53 + 0.12 * sin(t * 0.93));
        float body = rect(p, vec4(0.12, 0.28, 0.88, 0.79));
        float columns = floor(p.x * 40.0);
        float rows = floor(p.y * 35.0);
        float signal = step(0.70, hash1(columns * 7.0 + rows * 17.0 + floor(t * 6.0)));
        c = mix(c, TRACK, body * signal * 0.65);
        float sx = 0.14 + 0.72 * fract(t / 2.7);
        c = mix(c, CYAN, body * line2(p, vec2(sx, 0.28), vec2(sx, 0.79), 0.008));
        c = mix(c, AMBER, body * ring(p, center, 0.17, 0.008));
        c = mix(c, WHITE, body * (line2(p, center - vec2(0.11, 0),
            center + vec2(0.11, 0), 0.004) +
            line2(p, center - vec2(0, 0.13), center + vec2(0, 0.13), 0.004)));
    }
    // Physical screen bezel & subtle phosphor banding; no temporal interpolation.
    float bezel = 1.0 - rect(p, vec4(0.04, 0.045, 0.96, 0.955));
    c = mix(c, BG * 0.55, bezel);
    c *= 0.975 + 0.025 * sin((p.y * 185.0 + t * 1.2) * TAU);
    ALBEDO = clamp(c, vec3(0.0), vec3(1.0));
}
