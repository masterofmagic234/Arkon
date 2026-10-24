shader_type spatial;
render_mode depth_draw_always;
uniform vec4 paint : source_color=vec4(0.2,0.25,0.3,1.0);
uniform float roughness=0.65;
uniform float metallic=0.15;
uniform float emission_energy=0.0;
void fragment() {
    ALBEDO=paint.rgb;
    ROUGHNESS=roughness;
    METALLIC=metallic;
    EMISSION=paint.rgb*emission_energy;
    // After scenery proxies, using ordinary hardware depth testing.
    ALPHA=1.0;
}
