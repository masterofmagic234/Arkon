shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D panorama : source_color,filter_linear_mipmap;
uniform vec3 deep_color : source_color = vec3(.20,.39,.44);
varying vec2 reflected_uv;
varying float reflection;
varying vec3 world;
void vertex() {
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 vec3 eye=normalize(INV_VIEW_MATRIX[3].xyz-world);vec3 ray=reflect(-eye,vec3(0,1,0));
 reflected_uv=vec2(atan(ray.x,ray.z)/6.2831853+.5,acos(clamp(ray.y,-1.0,1.0))/3.1415927);
 reflection=pow(1.0-max(eye.y,0.0),2.0);
}
void fragment() {
 vec3 sky=texture(panorama,reflected_uv).rgb;
 float ripple=sin(world.x*.6+world.z*.35+TIME*.5)*.014;
 ALBEDO=mix(deep_color,sky,.16+reflection*.26)+ripple;
}
