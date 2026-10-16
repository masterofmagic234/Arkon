extends RefCounted
# A presentation pose interpolated between completed simulation steps. Physics,
# input, contacts, ranking and audio continue to use the authoritative car.
const FIELDS := [&"world_x",&"world_z",&"speed",&"heading_yaw",&"steer_applied",&"steering_angle",&"lateral_offset",&"lateral_velocity",&"slip_angle",&"distance_travelled",&"longitudinal_acceleration",&"brake_in"]
var source
var previous: Dictionary={}
var current: Dictionary={}
var pose: Dictionary={}
func setup(car) -> void:
    source=car
    capture();previous=current.duplicate();pose=current.duplicate()
func capture() -> void:
    previous=current.duplicate()
    for field in FIELDS: current[field]=float(source.get(field))
func sample(fraction: float) -> void:
    for field in FIELDS:
        pose[field]=lerp_angle(previous[field],current[field],fraction) if field==&"heading_yaw" else lerpf(previous[field],current[field],fraction)
func _get(field: StringName):
    return pose[field] if pose.has(field) else source.get(field)
func track_phase() -> float: return float(pose.world_z)/40.0
func physical_progress(_size: int) -> float: return track_phase()
func progress(_size: int) -> float: return track_phase()+source.grid_world_z_offset/40.0
func road_center_at(z: float) -> float: return source.road_center_at(z)
