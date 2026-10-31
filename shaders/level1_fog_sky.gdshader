shader_type sky;
uniform sampler2D panorama : source_color,filter_linear;
uniform vec3 moon_direction = vec3(-.40,.40,-.825);
uniform vec3 fog_color : source_color = vec3(.27,.41,.45);
uniform float horizon=.35;
uniform float blend_width=.38;
void sky() {
 vec3 painted=texture(panorama,SKY_COORDS).rgb;
 COLOR=mix(painted,fog_color,smoothstep(horizon-blend_width,horizon+blend_width,SKY_COORDS.y));
 vec3 m=normalize(moon_direction);vec3 r=normalize(EYEDIR);float disc=smoothstep(cos(.025),cos(.023),dot(r,m));
 vec3 tangent=normalize(cross(m,vec3(0,1,0)));vec3 cut=normalize(m+tangent*.012+vec3(0,.007,0));
 float shade=smoothstep(cos(.024),cos(.022),dot(r,cut));
 COLOR=mix(COLOR,vec3(.92,.84,.63),disc*(1.0-shade));
}
