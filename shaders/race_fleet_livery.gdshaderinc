// Authored fleet paint and artwork share the existing opaque Body surface.
// semantic.r is the audited exterior paint gate; glass/chrome/tires stay original.
uniform bool fleet_livery = false;
uniform bool fleet_police = false;
uniform vec4 fleet_tint : source_color = vec4(0.23,0.34,0.40,1.0);
uniform int fleet_unit_number = 7;
uniform float fleet_flash = 0.0;
uniform float fleet_scale = 4.88283;
uniform vec3 fleet_center = vec3(0.0);
uniform float fleet_half_width = 1.08;
uniform float fleet_rear_z = -2.44;
uniform float fleet_front_z = 2.44;
uniform sampler2D fleet_badge : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D fleet_marks : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 fleet_position;
varying vec3 fleet_surface_normal;

bool fleet_inside(vec2 uv) {
    return uv.x>0.0 && uv.x<1.0 && uv.y>0.0 && uv.y<1.0;
}
vec4 fleet_badge_stamp(vec2 uv) {
    if (!fleet_inside(uv)) return vec4(0.0);
    return texture(fleet_badge,uv);
}
float fleet_word_stamp(vec2 uv,bool rear) {
    if (!fleet_inside(uv)) return 0.0;
    vec2 atlas = rear ? vec2(0.625+uv.x*0.375,uv.y*0.375) : vec2(uv.x*0.625,uv.y*0.375);
    return texture(fleet_marks,atlas).a;
}
float fleet_digit(vec2 uv,float digit) {
    if (!fleet_inside(uv)) return 0.0;
    return texture(fleet_marks,vec2((digit+uv.x)*0.1,0.5+uv.y*0.5)).a;
}
float fleet_number_stamp(vec2 uv) {
    if (!fleet_inside(uv)) return 0.0;
    float value=float(fleet_unit_number);
    float digit=uv.x<0.5 ? floor(value/10.0) : mod(value,10.0);
    return fleet_digit(vec2(fract(uv.x*2.0),uv.y),digit);
}

vec4 fleet_paint(vec3 original,vec3 normal_,vec4 semantic) {
    // Part ownership provides full coat coverage, including the donor's pale
    // pink highlights. Real glass, chrome and tires have a zero paint gate.
    // The source contributes restrained luminance detail, never its red hue.
    float painted=semantic.r;
    if (painted<0.001) return vec4(original,0.0);
    float detail=clamp(0.78+dot(original,vec3(0.2126,0.7152,0.0722))*0.85,0.78,1.06);
    vec3 coat=fleet_tint.rgb;
    float reflective=0.0;
    vec3 p=fleet_position;
    if (fleet_police) {
        vec3 graphite=vec3(0.025,0.043,0.052);
        vec3 ivory=vec3(0.73,0.77,0.70);
        vec3 petrol=vec3(0.025,0.25,0.23);
        vec3 brass=vec3(0.48,0.34,0.12);
        coat=graphite;
        float side=step(0.40,abs(normal_.x))*step(fleet_half_width*0.48,abs(p.x));
        if (side>0.5) {
            // Broad ivory doors; graphite sill and roof, continuous petrol
            // stripe and a fine brass keyline. Badge is on the front door.
            if (p.z> -1.25 && p.z<1.30 && p.y>0.48 && p.y<1.08) coat=ivory;
            if (p.y>0.49 && p.y<0.61) {coat=petrol;reflective=0.07;}
            if (p.y>0.62 && p.y<0.635) {coat=brass;reflective=0.08;}
            float orientation=p.x>0.0 ? -1.0 : 1.0;
            vec2 badge_uv=vec2((p.z-0.36)*orientation/0.48+0.5,0.5-(p.y-0.82)/0.48);
            vec4 badge=fleet_badge_stamp(badge_uv);
            coat=mix(coat,badge.rgb,badge.a);
            vec2 words_uv=vec2((p.z+0.55)*orientation/0.92+0.5,0.5-(p.y-0.83)/0.25);
            float lettering=fleet_word_stamp(words_uv,false);
            coat=mix(coat,graphite,lettering);
            vec2 number_uv=vec2((p.z-1.48)*orientation/0.36+0.5,0.5-(p.y-0.88)/0.18);
            float number=fleet_number_stamp(number_uv);
            coat=mix(coat,ivory,number);
        }
        // Hood badge. Projection is only onto upward-facing paint; the
        // original windscreen mask and window geometry remain untouched.
        if (normal_.y>0.55 && p.z>0.65 && p.z<1.95) {
            vec2 hood_uv=vec2(p.x/0.62+0.5,(p.z-0.86)/0.78);
            vec4 hood_badge=fleet_badge_stamp(hood_uv);
            coat=mix(coat,hood_badge.rgb,hood_badge.a);
            reflective=max(reflective,hood_badge.a*0.025);
        }
        // The rear is read most often during a chase. Preserve the actual
        // lamp lenses and license plate, adding clear bumper chevrons/text.
        if (normal_.z< -0.45 && p.z<fleet_rear_z+0.65) {
            if (p.y>0.31 && p.y<0.59) {
                float chevron=step(0.5,fract((abs(p.x)+p.y*0.85)*4.0));
                coat=mix(petrol,ivory,chevron);reflective=0.10;
            }
            vec2 rear_uv=vec2(0.5-p.x/1.05,0.5-(p.y-0.89)/0.20);
            float rear_words=fleet_word_stamp(rear_uv,true);
            coat=mix(coat,ivory,rear_words);reflective=max(reflective,rear_words*0.05);
        }
        // Aerial unit number is painted on the original roof surface.
        if (normal_.y>0.75 && p.z> -0.95 && p.z<0.30 && p.y>1.18) {
            vec2 roof_uv=vec2(p.x/0.70+0.5,0.5+(p.z+0.34)/0.72);
            float roof_number=fleet_number_stamp(roof_uv);
            coat=mix(coat,ivory,roof_number);reflective=max(reflective,roof_number*0.035);
        }
    }
    return vec4(mix(original,coat*detail,painted),reflective*painted);
}
