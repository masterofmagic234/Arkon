shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform vec2 logical_size=vec2(1280.0,496.0);
uniform bool ground_mesh=false;
uniform sampler2D coverage_texture : filter_linear, repeat_disable;
varying float reciprocal_depth;
varying vec4 coverage_color;
vec3 linear_from_srgb(vec3 c) {
    return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));
}
void vertex() {
    reciprocal_depth=ground_mesh ? UV.y : VERTEX.z;
    coverage_color=COLOR;
    vec2 ndc=vec2(VERTEX.x/logical_size.x*2.0-1.0,1.0-VERTEX.y/logical_size.y*2.0);
    // Match Godot's render-target Y correction when overriding POSITION.
    ndc.y*=sign(PROJECTION_MATRIX[1][1]);
    // Reverse-Z depth test chooses the nearest actual scenery fragment;
    // no painter-order approximation or aircraft-centre visibility toggle.
    float depth=clamp(reciprocal_depth*0.8,0.0,1.0);
    POSITION=vec4(ndc,mix(CLIP_SPACE_FAR,1.0,depth),1.0);
}
void fragment() {
    if (reciprocal_depth<=0.0) discard;
    if (!ground_mesh && texture(coverage_texture,UV).a*coverage_color.a<0.35) discard;
    float value=floor(clamp(reciprocal_depth*0.8,0.0,1.0)*16777215.0+0.5);
    vec3 encoded=vec3(floor(value/65536.0),floor(mod(value,65536.0)/256.0),mod(value,256.0))/255.0;
    // The texture is data. Cancel the Forward+ linear -> sRGB output transform
    // so its 24-bit payload survives the LDR target without depth quantization.
    ALBEDO=OUTPUT_IS_SRGB ? encoded : linear_from_srgb(encoded);
}
