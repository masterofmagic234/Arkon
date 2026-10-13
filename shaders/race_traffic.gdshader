shader_type spatial;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float lamp_energy=0.0;
uniform vec3 camera_world;
uniform vec3 vehicle_origin;
uniform float road_grade=0.0;
// World Z, road centre, ground Y, sector. Authored once per 16m ray slice.
uniform vec4 occlusion_samples[35];
uniform float tunnel_radius=6.1;
varying vec3 world_position;
void vertex() {
    vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_position=vec3(vehicle_origin.x-p.x,vehicle_origin.y+p.y+p.z*road_grade,vehicle_origin.z+p.z);
}
void fragment() {
    // Test the actual view ray, not a car-centre visibility toggle. A hill or
    // portal can hide the lower half while the roof remains visible; cars
    // beyond a curved tunnel cannot show through its opaque side walls.
    float span=world_position.z-camera_world.z;
    if (span>0.01) {
        for (int i=0;i<35;i++) {
            vec4 sample_=occlusion_samples[i];
            if (sample_.x<=camera_world.z || sample_.x>=world_position.z-.08) continue;
            float t=(sample_.x-camera_world.z)/span;
            vec3 p=mix(camera_world,world_position,t);
            float height=p.y-sample_.z;
            float lateral=p.x-sample_.y;
            if (height<-.04) discard;
            if (sample_.w>3.5 && sample_.w<4.5 && lateral*lateral+max(height,0.0)*max(height,0.0)>tunnel_radius*tunnel_radius) discard;
            if (sample_.w>1.5 && sample_.w<2.5 && abs(lateral)>5.5 && height<.48) discard;
        }
    }
    vec3 paint=texture(albedo_texture,UV).rgb;
    float distance_=length(world_position-camera_world);
    ALBEDO=mix(paint,vec3(.11,.17,.22),smoothstep(90.0,480.0,distance_)*.82);
    ROUGHNESS=.5;
    METALLIC=0.0;
    NORMAL_MAP=texture(normal_texture,UV).rgb;
    EMISSION=texture(emission_texture,UV).rgb*lamp_energy;
}
