shader_type sky;
uniform bool compatibility_output=false;
void sky() {
    float up=clamp(EYEDIR.y,0.0,1.0);
    vec3 horizon=vec3(.055,.080,.135);
    vec3 zenith=vec3(.010,.019,.052);
    vec3 color=mix(horizon,zenith,pow(up,.55));
    vec3 moon=normalize(vec3(-.48,.64,-.59));
    float disc=smoothstep(.99970,.99986,dot(EYEDIR,moon));
    float halo=pow(max(dot(EYEDIR,moon),0.0),140.0)*.045;
    vec2 cell=floor(SKY_COORDS*vec2(760.0,380.0));
    float random=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
    vec2 point=fract(SKY_COORDS*vec2(760.0,380.0))-.5;
    float star=step(.9975,random)*(1.0-smoothstep(.02,.23,length(point)))*smoothstep(.12,.45,up);
    vec3 radiance=color+vec3(.55,.61,.72)*disc+vec3(.55,.63,.82)*halo+vec3(.25,.30,.40)*star;
    COLOR=compatibility_output?max(vec3(1.055)*pow(max(radiance,vec3(0.0)),vec3(.416666667))-.055,vec3(0.0)):radiance;
}
