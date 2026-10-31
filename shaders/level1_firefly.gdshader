shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
varying float pulse;
varying vec3 glow_color;
void vertex() {
    float phase=INSTANCE_CUSTOM.r*6.2831853;
    float time=TIME*(0.38+INSTANCE_CUSTOM.g*0.42)+phase;
    vec3 p=MODEL_MATRIX[3].xyz+vec3(sin(time)*0.27,sin(time*1.37+phase)*0.18,cos(time*0.83)*0.26);
    float scale_=length(MODEL_MATRIX[0].xyz);
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale_,INV_VIEW_MATRIX[1]*scale_,INV_VIEW_MATRIX[2]*scale_,vec4(p,1.0));
    pulse=0.32+pow(0.5+0.5*sin(TIME*(1.1+INSTANCE_CUSTOM.g)+phase),2.0)*0.68;
    glow_color=mix(vec3(0.62,0.94,0.84),vec3(1.0,0.83,0.46),INSTANCE_CUSTOM.b);
}
void fragment() {
    vec2 p=(UV-0.5)*2.0;
    float r=dot(p,p);
    float halo=exp(-r*4.8)*(1.0-smoothstep(0.70,1.0,r));
    float core=1.0-smoothstep(0.018,0.075,r);
    // Compatibility's unshaded additive pass uses ALBEDO for its color.
    ALBEDO=glow_color*(halo*0.32+core*2.0)*pulse;
    ALPHA=max(halo*pulse,core);
}
