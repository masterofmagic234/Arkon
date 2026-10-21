shader_type spatial;
render_mode cull_back, vertex_lighting;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world;
varying vec3 face;
void vertex() {
    world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    face=abs(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
    vec2 uv=face.x>face.z ? world.zy : world.xy;
    if (face.y>max(face.x,face.z)) uv=world.xz;
    float grain=dot(texture(detail_tex,uv*.32).rgb,vec3(.30,.59,.11));
    float texture_weight=step(.25,COLOR.a);
    float wood=step(.75,COLOR.a);
    float groove=smoothstep(.32,.48,abs(fract(uv.x*3.5+grain*.12)-.5));
    float variation=(.55+grain*1.8)*mix(1.0,.84+groove*.24,wood);
    ALBEDO=COLOR.rgb*mix(1.0,variation,texture_weight);
    ROUGHNESS=.90;SPECULAR=.15;
}
