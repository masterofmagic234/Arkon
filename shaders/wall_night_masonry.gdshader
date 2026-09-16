shader_type spatial;
render_mode cull_back, unshaded;

uniform sampler2D wall_texture : source_color, filter_nearest, repeat_disable;

void fragment() {
    // Each source wall is an 8-panel 4096x512 strip. Do NOT cycle through
    // panels: several panels contain giant signs/text. Panel 3 is the clean
    // masonry panel shared by all six styles.
    //
    // Crop that panel to the same aspect ratio as the physical 1.8 x 2.6
    // wall face, so the artwork is neither stretched nor repeated.
    const float clean_segment_center = 3.5 / 8.0;
    const float crop_y0 = 0.08;
    const float crop_h = 0.92;
    const float crop_w = 0.0796;

    vec2 uv = vec2(
        clean_segment_center - crop_w * 0.5 + UV.x * crop_w,
        crop_y0 + UV.y * crop_h
    );

    vec4 tex = texture(wall_texture, uv);
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
