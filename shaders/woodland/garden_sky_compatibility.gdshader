shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
void sky() {
    // HDR panorama samples already contain linear radiance. The GL sky path
    // expects sRGB and decodes it before applying the environment tonemapper.
    vec3 radiance = max(texture(panorama, SKY_COORDS).rgb, vec3(0.0));
    COLOR = max(vec3(1.055) * pow(radiance, vec3(.416666667)) - .055, vec3(0.0));
}
