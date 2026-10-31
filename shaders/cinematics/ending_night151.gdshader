shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/cinematics/pajamas151.gdshaderinc"
uniform bool recolour_sleeping_pajamas = false;
uniform bool acting_layer = false;
uniform bool phone_pose = false;
uniform float motion_time = 0.0;
varying vec4 modulation;
void vertex() { modulation = COLOR; }
float rectangle151(vec2 p, vec4 r) {
    vec2 low = smoothstep(r.xy,r.xy+vec2(.006),p);
    vec2 high = 1.0-smoothstep(r.zw-vec2(.006),r.zw,p);
    return low.x*low.y*high.x*high.y;
}
void fragment() {
    vec2 source_uv = UV;
    if (acting_layer) {
        // Subpixel chest breathing remains inside the authored person patch.
        float chest = rectangle151(UV,vec4(.118,.398,.283,.603));
        source_uv.y += sin(motion_time*1.72)*.00052*chest;
        if (phone_pose) {
            float hands = rectangle151(UV,vec4(.163,.474,.252,.606));
            source_uv.x += sin(motion_time*19.7)*.00038*hands;
            source_uv.y += sin(motion_time*15.2)*.00028*hands;
        }
    }
    vec4 image = texture(TEXTURE,source_uv);
    vec3 colour = recolour_sleeping_pajamas ? garment_colour151(UV,image.rgb,0.0) : image.rgb;
    float warm = smoothstep(.06,.4,colour.r-colour.b);
    vec3 night = colour*vec3(.27,.34,.53);
    float luminance = dot(colour,vec3(.2126,.7152,.0722));
    night = mix(night,vec3(.13,.19,.30)*luminance,warm*.64);
    // Lamps and screens are off; the original window remains the only light source.
    float fixtures = max(rectangle151(UV,vec4(.379,.365,.452,.506)),
                         rectangle151(UV,vec4(.837,.326,.995,.548)));
    fixtures = max(fixtures,rectangle151(UV,vec4(.329,.211,.371,.278)));
    night *= mix(1.0,.17,fixtures);
    float window = rectangle151(UV,vec4(.502,.103,.638,.529));
    night = mix(night,colour*vec3(.63,.74,.91),window*.67);
    COLOR = vec4(night,image.a)*modulation;
}
