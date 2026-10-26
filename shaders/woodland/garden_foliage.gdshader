shader_type spatial;
render_mode cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
// Preserve the imported alpha channel and all mip levels, but let depth and
// normal variants fetch one channel instead of decoding the color block too.
uniform sampler2D alpha_mask : filter_linear_mipmap_anisotropic;
uniform bool separate_alpha = true;
void fragment() {
    float coverage = separate_alpha ? texture(alpha_mask, UV).r : texture(atlas, UV).a;
    if (coverage < .38) discard;
    vec4 c = texture(atlas, UV);
    ALBEDO = c.rgb * COLOR.rgb * vec3(.62, .76, .62);
    ROUGHNESS = .92;
    BACKLIGHT = vec3(.17, .20, .08);
}
