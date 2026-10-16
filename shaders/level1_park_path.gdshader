shader_type spatial;
render_mode cull_back;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 sett_color : source_color = vec3(0.31,0.36,0.39);
uniform vec3 joint_color : source_color = vec3(0.12,0.16,0.17);
varying vec2 world_xz;
void vertex() { world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
    vec3 detail=texture(ground_tex,world_xz*0.14).rgb;
    float grain=dot(detail,vec3(0.30,0.59,0.11));
    float edge=smoothstep(0.0,0.13,UV.x)*smoothstep(0.0,0.13,1.0-UV.x);
    // Staggered blue-grey garden setts retain one texture sample. Thin joints
    // and small per-stone variation give the path a readable physical scale.
    vec2 cells=vec2(UV.x*3.0,UV.y*3.2);
    cells.x+=mod(floor(cells.y),2.0)*0.5;
    vec2 joint=abs(fract(cells)-0.5);
    float seam=smoothstep(0.44,0.49,max(joint.x,joint.y));
    float shade=0.91+0.09*sin(dot(floor(cells),vec2(5.31,9.17)));
    vec3 gravel=mix(sett_color*(0.68+grain*1.1)*shade,joint_color,seam);
    ALBEDO=mix(detail*vec3(0.74,0.82,0.72),gravel,edge);
    ROUGHNESS=0.80;
    SPECULAR=0.20;
}
