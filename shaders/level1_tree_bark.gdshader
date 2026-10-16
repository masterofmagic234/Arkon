shader_type spatial;
render_mode cull_back;
uniform sampler2D bark_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
    vec3 bark = texture(bark_tex,UV).rgb;
    float height = dot(bark,vec3(0.30,0.59,0.11))*0.018;
    vec3 dx = dFdx(VERTEX);
    vec3 dy = dFdy(VERTEX);
    vec3 rx = cross(dy,NORMAL);
    vec3 ry = cross(NORMAL,dx);
    float determinant = dot(dx,rx);
    vec3 gradient = sign(determinant)*(dFdx(height)*rx+dFdy(height)*ry);
    NORMAL = normalize(max(abs(determinant),0.0000001)*NORMAL-gradient);
    ALBEDO = bark*vec3(0.78,0.77,0.73);
    ROUGHNESS = 0.96;
    SPECULAR = 0.12;
}
