shader_type spatial;
render_mode unshaded, cull_disabled;
uniform int mode;
const vec3 BG = vec3(0.016, 0.070, 0.105);
const vec3 TRACK = vec3(0.055, 0.19, 0.24);
const vec3 CYAN = vec3(0.19, 0.84, 0.92);
const vec3 AMBER = vec3(1.0, 0.61, 0.16);

void fragment() {
    vec2 p = UV;
    vec3 c = BG;
    float t = TIME;
    if (mode == 0) {
        float progress = fract(t / 5.0);
        // Printed cross-section grows upward from the bed.
        float half_width = 0.30 - 0.14 * abs(p.y - 0.49);
        float head = 0.71 - 0.49 * progress;
        if (abs(p.x-0.5) < half_width && p.y > head && p.y < 0.72) {
            c = mix(TRACK, CYAN, step(0.20, fract(p.y*13.0)));
        }
        if (abs(p.y-head)<0.025 && abs(p.x-0.5)<0.36) { c = AMBER; }
        if (p.y>0.81 && p.y<0.91) { c = p.x<progress ? CYAN : TRACK; }
    } else if (mode == 1) {
        float wave = 0.52 + 0.22*sin(p.x*8.0-t*2.0) + 0.09*sin(p.x*16.0-t*4.0);
        c = mix(BG, TRACK, step(wave,p.y));
        if (abs(p.y-wave)<0.045) { c = CYAN; }
    } else if (mode == 2) {
        float channel = floor(p.x*5.0);
        float top = 0.50 + 0.28*sin(t*1.7+channel*1.4);
        if (fract(p.x*5.0)>0.18 && p.y<0.86) {
            c = p.y>top ? (channel>2.5 ? AMBER : CYAN) : TRACK;
        }
    } else if (mode == 3) {
        vec2 d = (p-vec2(0.5,0.44))*vec2(1.45,1.0);
        if (abs(length(d)-0.29)<0.055) {
            float sector = fract(atan(d.y,d.x)*0.477465-t*0.55);
            c = sector>0.19 ? CYAN : TRACK;
        }
    } else if (mode == 4) {
        float y = p.y*4.0 + floor(t*1.25);
        float item = mod(floor(y),7.0);
        if (fract(y)>0.25 && fract(y)<0.75) {
            if (p.x<0.16) { c = AMBER; }
            else if (p.x>0.24 && p.x<0.52+0.06*item) { c = CYAN; }
        }
    } else {
        if (p.y>0.22 && p.y<0.78 && p.x>0.12 && p.x<0.88) {
            c = mix(TRACK,CYAN,step(0.0,sin(p.x*61.0)+0.5*sin(p.x*97.0)));
        }
        if (abs(p.x-(0.50+0.39*sin(t*2.0)))<0.036) { c = AMBER; }
    }
    if (min(min(p.x,1.0-p.x),min(p.y,1.0-p.y))<0.055) { c = BG; }
    ALBEDO = c;
}
