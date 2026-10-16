shader_type sky;

uniform sampler2D panorama : filter_linear, source_color;
uniform sampler2D moon_tex : source_color, filter_linear;
uniform vec3 moon_direction = vec3(-0.40,0.40,-0.825);
uniform vec3 fog_color : source_color = vec3(0.12, 0.17, 0.25);
uniform float horizon : hint_range(0.35, 0.65, 0.01) = 0.50;
uniform float blend_width : hint_range(0.01, 0.20, 0.01) = 0.08;

void sky() {
    vec3 sky_color = texture(panorama, SKY_COORDS).rgb * 0.9;

    // Keep the lower hemisphere consistent with the long mobile fog range.
    // Never expose a mismatched panorama through distant world gaps.
    // Keep the actual starry sky above the horizon, but turn the lower
    // hemisphere into the same blue fog color used by the Level 1 cutoff.
    // SKY_COORDS.y is 0 at the top of the panorama and 1 at the bottom.
    // The previous mask was inverted, so it fogged the actual sky above the
    // horizon and left the lower, unrendered world area showing the panorama.
    float lower_mask = smoothstep(horizon - blend_width, horizon + blend_width, SKY_COORDS.y);
    COLOR = mix(sky_color, fog_color, lower_mask);
    vec3 moon_dir=normalize(moon_direction);
    vec3 ray=normalize(EYEDIR);
    float disc=smoothstep(cos(0.022),cos(0.020),dot(ray,moon_dir));
    if (disc>0.0) {
        vec3 right=normalize(cross(moon_dir,vec3(0.0,1.0,0.0)));
        vec3 up=cross(right,moon_dir);
        vec2 uv=vec2(dot(ray,right),-dot(ray,up))/0.044+0.5;
        vec4 moon=texture(moon_tex,uv);
        COLOR=mix(COLOR,moon.rgb*vec3(1.0,0.94,0.79)*2.8,disc*moon.a);
    }
}
