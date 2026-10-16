shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(0.08,0.17,0.22,0.05);
varying vec2 rain_position;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){rain_position = VERTEX;}
void fragment(){
    // Vertex coordinates keep rain at one physical scale on every exterior
    // panel; untextured Polygon2D UVs do not provide a reliable tiled domain.
    vec2 p = rain_position/vec2(7.0,19.0);
    float column = p.x+p.y*0.30;
    float line_id = floor(column);
    float random = hash(vec2(line_id,2.0));
    float phase = fract(p.y-TIME*(5.0+random*3.0)+random);
    float width = 1.0-smoothstep(0.04,0.13,abs(fract(column)-0.5));
    float streak = (1.0-smoothstep(0.02,0.30,phase))*width*(0.35+random*0.65);
    COLOR = vec4(mix(tint.rgb,vec3(0.35,0.63,0.77),streak),tint.a+streak*0.52);
}
