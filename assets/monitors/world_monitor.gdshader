shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D panel : source_color, filter_linear, repeat_disable;
uniform sampler2D readout : source_color, filter_linear, repeat_disable;
uniform sampler2D plans : source_color, filter_linear, repeat_disable;
uniform int mode;

bool inside(vec2 p, vec2 lo, vec2 hi) {
    return all(greaterThanEqual(p, lo)) && all(lessThan(p, hi));
}

vec3 rows(vec2 uv, float group, float offset, float count) {
    float row = mod(uv.y * count + offset, 8.0);
    return texture(readout, vec2(uv.x, (group * 8.0 + row) / 32.0)).rgb;
}

void fragment() {
    vec2 uv = UV;
    vec2 src = uv;
    float t = TIME;
    vec3 ink = vec3(0.0);
    float overlay = 0.0;
    if (mode == 0) {
        vec2 p = uv * vec2(512.0, 240.0);
        if (inside(p, vec2(304.0,75.0), vec2(485.0,153.0))) {
            src.x = (304.0 + mod(p.x - 304.0 + t * 32.0, 181.0)) / 512.0;
        } else if (inside(p, vec2(129.0,71.0), vec2(283.0,194.0))) {
            float row = floor((p.y - 71.0) / 27.0);
            float baseline = 0.5 + 0.1 * row;
            float fill = baseline + 0.09 * sin(t * 1.6 + row);
            float x = (p.x - 129.0) / 154.0;
            src.x = (129.0 + 154.0 * (x < fill ? x * baseline / fill :
                baseline + (x-fill)*(1.0-baseline)/(1.0-fill))) / 512.0;
        }
    } else if (mode == 1 || mode == 6 || mode == 7) {
        vec2 lo = vec2(0.065,0.30);
        vec2 hi = vec2(0.935,0.83);
        if (inside(uv,lo,hi)) {
            vec2 local = (uv-lo)/(hi-lo);
            float group = mode == 1 ? 0.0 : (mode == 6 ? 2.0 : 1.0);
            float shift = mode == 1 ? t * 1.4 : (mode == 6 ? floor(t*1.2) : 4.0*floor(t/3.0));
            ink = rows(local, group, shift, 4.0);
            overlay = 1.0;
        }
    } else if (mode == 2) {
        vec2 p = uv * vec2(240.0,256.0);
        if (inside(p,vec2(18.0,51.0),vec2(222.0,213.0))) {
            src -= vec2(0.073*sin(t),0.032*sin(t*1.6));
            src.y = clamp(src.y, 51.0/256.0, 212.0/256.0);
        }
    } else if (mode == 3 || mode == 9) {
        bool radar = mode == 3;
        float level = 0.5 + 0.49*sin(t*0.8);
        vec2 p = radar ? uv*vec2(184.0,256.0)-vec2(92.0,125.43)
                       : uv*vec2(240.0,256.0)-vec2(120.0,126.33);
        float angle = radar ? t*1.6 : -2.9 + level*2.65;
        vec2 dir = vec2(cos(angle),sin(angle));
        float distance_to_line = length(p - dir*clamp(dot(p,dir),0.0,radar ? 56.0 : 51.0));
        ink = vec3(0.94,0.7,0.32);
        overlay = 1.0-smoothstep(0.7,2.1,distance_to_line);
        if (!radar && inside(uv,vec2(0.33,0.55),vec2(0.68,0.65))) {
            vec2 local = (uv-vec2(0.33,0.55))/vec2(0.35,0.10);
            ink = rows(vec2(local.x*0.36,local.y),3.0,floor(level*8.0),1.0);
            overlay = 1.0;
        }
    } else if (mode == 4 || mode == 5) {
        vec2 p = uv * vec2(320.0,252.0);
        if (mode == 4 && inside(p,vec2(20.0,78.0),vec2(300.0,210.24))) {
            src.y = (78.0 + mod(p.y-78.0+t*16.0,132.24))/252.0;
        } else if (mode == 5 && inside(p,vec2(80.0,67.0),vec2(298.0,210.0))) {
            float scale = 1.0+0.26*sin(t*1.7+floor(p.y/16.53));
            src.x = min(298.0,80.0+(p.x-80.0)/scale)/320.0;
        }
    } else if (mode == 8) {
        vec2 p = uv * vec2(176.0,160.0);
        if (inside(p,vec2(17.0,122.0),vec2(159.0,135.0))) {
            float x = (p.x-17.0)/142.0;
            float fill = clamp(fract(t/9.0)*1.12,0.005,0.995);
            src.x = (17.0+142.0*(x<fill ? x*0.67/fill : 0.67+(x-fill)*0.33/(1.0-fill)))/176.0;
        }
    } else if (mode == 10 && inside(uv,vec2(0.085,0.265),vec2(0.91,0.845))) {
        float page = mod(floor(t/3.5),3.0);
        if (page > 0.5) {
            vec2 local = (uv-vec2(0.085,0.265))/vec2(0.825,0.58);
            ink = texture(plans,vec2(local.x,(page-1.0+local.y)*0.5)).rgb;
            overlay = 1.0;
        }
    }
    ALBEDO = mix(texture(panel,src).rgb,ink,overlay);
}
