shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float layer_phase = 0.0;
uniform float layer_opacity : hint_range(0.0,1.0) = 0.85;
uniform float phase_time = 0.0;
float hash21(vec2 p) {
    p = fract(p*vec2(123.34,456.21));
    p += dot(p,p+45.32);
    return fract(p.x*p.y);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),
        mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float flow(vec2 p) {
    return 0.57*noise2(p)+0.28*noise2(p*2.07+19.1)+0.15*noise2(p*4.11-8.3);
}
void fragment() {
    float h = 1.0-UV.y;
    float t = phase_time + layer_phase*7.13;
    // Slow broad eddies plus faster ascending detail. Base remains fixed.
    vec2 q = vec2(UV.x*5.2,h*3.8-t*1.18);
    float sway = (flow(vec2(UV.x*3.0,h*2.0-t*0.67)+layer_phase)-0.5)*0.42;
    q.x += sway*smoothstep(0.04,0.75,h)*4.2;
    float large = flow(q);
    float fine = noise2(vec2(q.x*3.2,q.y*2.2-t*0.53));
    float envelope = smoothstep(0.0,0.13,UV.x)*smoothstep(0.0,0.13,1.0-UV.x);
    float limit = 0.36+0.86*large+0.12*(fine-0.5);
    float density = smoothstep(-0.075,0.11,limit-h);
    density *= envelope*smoothstep(0.0,0.035,h)*(1.0-smoothstep(0.82,1.0,h));
    density *= mix(0.63,1.0,smoothstep(0.15,0.77,fine));
    // Blue reaction zone near burner; luminous soot develops farther up.
    float blue = 1.0-smoothstep(0.065,0.27,h);
    float core = smoothstep(0.36,0.8,large)*smoothstep(0.12,0.29,h)*
        (1.0-smoothstep(0.58,0.85,h));
    vec3 orange = mix(vec3(0.96,0.19,0.018),vec3(1.0,0.63,0.095),core);
    orange = mix(orange,vec3(1.0,0.91,0.56),pow(core,3.0)*0.58);
    orange = mix(orange,vec3(0.72,0.09,0.015),smoothstep(0.65,0.98,h)*0.58);
    vec3 blue_tint = mix(vec3(0.025,0.22,0.84),vec3(0.65,0.88,1.0),fine*0.72);
    ALBEDO = mix(orange,blue_tint,blue);
    ALPHA = density * layer_opacity;
}
