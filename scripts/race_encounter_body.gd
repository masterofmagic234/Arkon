extends RefCounted
## A Camry travelling toward the player, or a heavy parked roadblock car.
## Signed world velocity is deliberate: a frontal collision is not a rear tap.
const Data=preload("res://scripts/race_level_data.gd")
const Math=preload("res://scripts/race_math.gd")
const Barriers=preload("res://scripts/race_barriers.gd")
var world_x := 0.0
var world_z := 0.0
var heading_yaw := PI
var speed := 0.0
var lateral_offset := -2.5
var lateral_velocity := 0.0
var impact_velocity := 0.0
var brake_in := 0.0
var old_position := Vector2.ZERO
var old_heading := PI
var velocity := Vector2.ZERO
var cruise_speed := 25.0
var desired_speed := 25.0
var cruise_lane := -2.5
var lane := -2.5
var is_roadblock := false
var collided := false
var recovery := 0.0
var serial := 0

func place(z: float,offset: float,track: PackedFloat32Array,block: bool=false) -> void:
    world_z=z;lane=offset;cruise_lane=offset;lateral_offset=offset;is_roadblock=block
    desired_speed=0 if block else cruise_speed
    world_x=Math.track_center_x(z/40,track)+offset
    heading_yaw=PI*.5 if block else PI+atan2(Math.track_center_slope(z/40,track),40)
    velocity=Vector2.ZERO if block else Vector2(0,-cruise_speed)
    speed=velocity.length();brake_in=0;collided=false;recovery=0
    snapshot()

func snapshot() -> void:
    old_position=Vector2(world_x,world_z);old_heading=heading_yaw

func tick(delta: float,pattern: Array,track: PackedFloat32Array) -> void:
    if is_roadblock:
        if velocity.length_squared()>.002:
            var next:=Barriers.sweep(Vector2(world_x,world_z),Vector2(world_x,world_z)+velocity*delta,pattern,track,heading_yaw)
            world_x=next.x;world_z=next.y;velocity*=exp(-2.8*delta)
        speed=velocity.length();lateral_offset=world_x-Math.track_center_x(world_z/40,track)
        return
    recovery=maxf(0,recovery-delta)
    if recovery>0:
        var next:=Barriers.sweep(Vector2(world_x,world_z),Vector2(world_x,world_z)+velocity*delta,pattern,track,heading_yaw)
        world_x=next.x;world_z=next.y;velocity*=exp(-1.8*delta)
        brake_in=1
    else:
        var start:=Vector2(world_x,world_z)
        var forward:=move_toward(velocity.y,-desired_speed,9.0*delta)
        world_z+=forward*delta
        lateral_offset=move_toward(lateral_offset,lane,delta*1.4)
        world_x=Math.track_center_x(world_z/40,track)+lateral_offset
        velocity=(Vector2(world_x,world_z)-start)/maxf(delta,.0001)
        heading_yaw=atan2(velocity.x,velocity.y) if velocity.length()>.1 else heading_yaw
        brake_in=1 if desired_speed<cruise_speed-2 else 0
    speed=velocity.length();lateral_velocity=velocity.x
    lateral_offset=world_x-Math.track_center_x(world_z/40,track)

func contact_velocity() -> Vector2:return velocity
func contact_inverse_mass() -> float:return .28 if is_roadblock else 1.0
func apply_contact_velocity(next: Vector2) -> void:
    velocity=next;speed=next.length();lateral_velocity=next.x
    recovery=2.0;collided=true;brake_in=1
func resolve_contact(correction: Vector2,pattern: Array,track: PackedFloat32Array) -> void:
    var next:=Barriers.sweep(Vector2(world_x,world_z),Vector2(world_x,world_z)+correction,pattern,track,heading_yaw)
    world_x=next.x;world_z=next.y;lateral_offset=world_x-Math.track_center_x(world_z/40,track)
