shader_type spatial;
#include "res://shaders/race_airframe_occlusion.gdshaderinc"
uniform vec4 paint : source_color=vec4(0.2,0.25,0.3,1.0);
uniform float roughness=0.65;
uniform float metallic=0.15;
uniform float emission_energy=0.0;
void fragment() {
    if (scenery_hides_airframe(SCREEN_UV,-VERTEX.z)) discard;
    ALBEDO=paint.rgb;
    ROUGHNESS=roughness;
    METALLIC=metallic;
    EMISSION=paint.rgb*emission_energy;
}
