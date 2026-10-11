shader_type spatial;
render_mode cull_disabled;
varying float height_;
void vertex() {
    vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    height_=UV.y;
    VERTEX.x+=sin(TIME*1.25+p.x*0.61+p.z*0.73)*0.075*UV.y*UV.y;
}
void fragment() {
    ALBEDO=mix(vec3(0.095,0.18,0.105),vec3(0.34,0.43,0.18),height_);
    ROUGHNESS=0.95;
    SPECULAR=0.14;
}
