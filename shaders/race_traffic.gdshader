shader_type spatial;
#include "res://shaders/race_fleet_livery.gdshaderinc"
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float lamp_energy=0.0;
uniform float camera_visibility=1.0;
uniform vec3 camera_world;
uniform vec3 vehicle_origin;
uniform float road_grade=0.0;
// World Z, road centre, ground Y, sector. Authored once per 16m ray slice.
uniform vec4 occlusion_samples[35];
// A uniform loop bound avoids enormous unrolled discard control flow on
// older Compatibility shader compilers (including the CI Mesa driver).
uniform int occlusion_sample_count=35;
uniform float tunnel_radius=6.1;
varying vec3 world_position;
void vertex() {
    fleet_position=(VERTEX-fleet_center)*fleet_scale;
    fleet_surface_normal=NORMAL;
    vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_position=vec3(vehicle_origin.x-p.x,vehicle_origin.y+p.y+p.z*road_grade,vehicle_origin.z+p.z);
}
void fragment() {
    // Keep the ordinary opaque/depth-tested pass. Only a car intersecting the
    // chase camera's sight corridor receives this stable ordered coverage;
    // this needs no alpha blend, screen texture or additional viewport.
    if (camera_visibility<=0.001) discard;
    if (camera_visibility<0.999) {
        vec2 cell=mod(floor(FRAGCOORD.xy),4.0);
        vec2 low=mod(cell,2.0);
        vec2 high=floor(cell*0.5);
        float fine=2.0*low.x+3.0*low.y-4.0*low.x*low.y;
        float coarse=2.0*high.x+3.0*high.y-4.0*high.x*high.y;
        if ((4.0*fine+coarse+0.5)/16.0>camera_visibility) discard;
    }
    // Test the actual view ray, not a car-centre visibility toggle. A hill or
    // portal can hide the lower half while the roof remains visible; cars
    // beyond a curved tunnel cannot show through its opaque side walls.
    float span=world_position.z-camera_world.z;
    bool hidden=false;
    if (abs(span)>0.01) {
        for (int i=0;i<occlusion_sample_count;i++) {
            vec4 sample_=occlusion_samples[i];
            float t=(sample_.x-camera_world.z)/span;
            if (t<=0.0 || t>=1.0-.08/abs(span)) continue;
            vec3 p=mix(camera_world,world_position,t);
            float height=p.y-sample_.z;
            float lateral=p.x-sample_.y;
            hidden=height<-.04;
            hidden=hidden || (sample_.w>3.5 && sample_.w<4.5 && lateral*lateral+max(height,0.0)*max(height,0.0)>tunnel_radius*tunnel_radius);
            hidden=hidden || (sample_.w>1.5 && sample_.w<2.5 && abs(lateral)>5.5 && height<.48);
            if (hidden) break;
        }
    }
    if (hidden) discard;
    vec3 paint=texture(albedo_texture,UV).rgb;
    vec3 fleet_emission=vec3(0.0);
    float fleet_roughness=0.5;
    bool fleet_accessory=fleet_livery && COLOR.g>0.1;
    if (fleet_livery) {
        bool beacon=COLOR.g>0.1 && COLOR.g<0.9;
        if (beacon) {
            if (!fleet_police) discard;
            paint=vec3(0.018,0.025,0.030);
            fleet_roughness=0.33;
            if (COLOR.g<0.35 || COLOR.g>0.65) {
                bool blue=COLOR.g>0.65;
                vec3 lamp=blue ? vec3(0.025,0.22,1.0) : vec3(1.0,0.035,0.018);
                float lit=step(0.5,fract(fleet_flash*0.5+(blue ? 0.0 : 0.5)));
                paint=lamp*0.38;
                fleet_emission=lamp*(0.18+lit*4.8);
            }
        } else {
            if (fleet_accessory) paint=COLOR.r>0.5 ? vec3(0.37,0.09,0.12) : vec3(0.025,0.032,0.038);
            vec4 coat=fleet_paint(paint,normalize(fleet_surface_normal),COLOR);
            paint=coat.rgb;fleet_emission=paint*coat.a;
            fleet_roughness=0.42;
        }
    }
    float distance_=length(world_position-camera_world);
    ALBEDO=mix(paint,vec3(.11,.17,.22),smoothstep(90.0,480.0,distance_)*.82);
    ROUGHNESS=fleet_roughness;
    METALLIC=0.0;
    NORMAL_MAP=fleet_accessory ? vec3(0.5,0.5,1.0) : texture(normal_texture,UV).rgb;
    EMISSION=texture(emission_texture,UV).rgb*lamp_energy+fleet_emission;
}
