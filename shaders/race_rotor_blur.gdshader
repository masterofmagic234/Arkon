shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,fog_disabled;
void fragment() {
    vec2 p=(UV-0.5)*2.0;
    float radius=length(p);
    float coverage=smoothstep(0.13,0.24,radius)*(1.0-smoothstep(0.88,1.0,radius));
    ALBEDO=vec3(0.10,0.13,0.15);
    ALPHA=coverage*0.12;
}
