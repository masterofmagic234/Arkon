extends RefCounted

# Состояние одной машины Level 2.

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

var is_player: bool = false
var world_x: float = 0.0
var world_z: float = 0.0
var speed: float = 0.0
var steer_in: float = 0.0
var throttle: float = 0.0
var brake_in: float = 0.0
var grid_index: int = 0
# The start-grid offset is visual world-space separation only. Progress remains
# anchored at segment 0 so race ordering and renderer projection stay unchanged.
var grid_world_z_offset: float = 0.0
var segment_index: int = 0
var segment_progress: float = 0.0
var last_segment_index: int = -1
var lap: int = 0
var position: int = 1
var finish_time: float = -1.0
var sprite_yaw: float = 0.0
var lateral_offset: float = 0.0
var steer_applied: float = 0.0
var lateral_velocity: float = 0.0
var heading_yaw: float = 0.0
var travel_yaw: float = 0.0
var slip_angle: float = 0.0
var distance_travelled: float = 0.0
var longitudinal_acceleration: float = 0.0
var steering_angle: float = 0.0
var offroad_amount: float = 0.0
var _heading: float = 0.0

func setup(player_flag: bool) -> void:
    is_player = player_flag

func place_on_grid(grid_slot: int, lane_x: float, track_x: PackedFloat32Array) -> void:
    grid_index = grid_slot
    segment_index = 0
    segment_progress = 0.0
    lateral_offset = lane_x
    world_x = RaceMath.track_center_x(0.0, track_x) + lateral_offset
    grid_world_z_offset = float(grid_slot) * 0.6 * RaceLevelData.SEGMENT_HEIGHT
    world_z = -grid_world_z_offset

func set_inputs(steer: float, th: float, br: float) -> void:
    steer_in = clampf(steer, -1.0, 1.0)
    throttle = clampf(th, 0.0, 1.0)
    brake_in = clampf(br, 0.0, 1.0)
    if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NES_TRIBUTE:
        steer_applied = steer_in

func tick(delta: float, allow_control: bool, track_pattern: Array, track_x: PackedFloat32Array) -> void:
    var max_speed: float = RaceLevelData.PLAYER_MAX_SPEED
    if not is_player:
        max_speed *= 0.92

    var previous_speed := speed
    var previous_center := RaceMath.track_center_x(float(segment_index) + segment_progress, track_x)
    var dt := maxf(delta, 0.0)
    if allow_control:
        var drive_limit := max_speed
        var asphalt_edge := RaceLevelData.ROAD_WIDTH * 0.5 + RaceLevelData.OFFROAD_VEHICLE_HALF_WIDTH + RaceLevelData.OFFROAD_ASPHALT_MARGIN
        if absf(lateral_offset) > asphalt_edge:
            var shoulder := clampf((absf(lateral_offset) - asphalt_edge) / RaceLevelData.OFFROAD_SHOULDER, 0.0, 1.0)
            drive_limit *= lerpf(0.85, 0.55, shoulder)
        speed = RaceMath.step_speed(speed, throttle, brake_in, dt, drive_limit, RaceLevelData.PLAYER_ACCEL, RaceLevelData.PLAYER_BRAKE, RaceLevelData.PLAYER_DRAG)
        var response := RaceLevelData.NFS_STEER_INPUT_RESPONSE
        if absf(steer_in) < absf(steer_applied):
            response *= 1.35
        steer_applied = move_toward(steer_applied, steer_in, response * dt)
        var speed_ratio := clampf(speed / max_speed, 0.0, 1.0)
        steering_angle = steer_applied * lerpf(0.48, 0.20, speed_ratio)
        var moving := clampf((speed - RaceLevelData.NFS_LOW_SPEED_LATERAL_LOCK) / 3.0, 0.0, 1.0)
        var target_heading := steer_applied * RaceLevelData.NFS_MAX_HEADING_YAW * lerpf(1.0, 0.48, speed_ratio)
        _heading = lerp_angle(_heading, target_heading, 1.0 - exp(-RaceLevelData.NFS_HEADING_RESPONSE * moving * dt))
        var desired_lateral := sin(_heading) * speed * moving
        var grip := RaceLevelData.NFS_LATERAL_GRIP_RESPONSE * lerpf(1.0, 0.72, speed_ratio)
        lateral_velocity = lerpf(lateral_velocity, desired_lateral, 1.0 - exp(-grip * dt))
        if moving <= 0.0:
            # Wheels can steer at rest; the chassis cannot translate or yaw.
            lateral_velocity = 0.0
        if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NES_TRIBUTE:
            lateral_velocity = steer_in * speed * 0.28 * moving
            _heading = atan2(lateral_velocity, maxf(speed, 0.001))
        lateral_offset += lateral_velocity * dt
    else:
        speed = maxf(speed - 6.0 * dt, 0.0)
        lateral_velocity = 0.0
        steer_applied = move_toward(steer_applied, 0.0, 8.0 * dt)
        steering_angle = 0.0

    # speed is total speed; lateral travel cannot create extra forward speed.
    var forward_speed := sqrt(maxf(speed * speed - lateral_velocity * lateral_velocity, 0.0))
    var advance: float = forward_speed * dt / RaceLevelData.SEGMENT_HEIGHT
    segment_progress += advance
    while segment_progress >= 1.0:
        segment_progress -= 1.0
        last_segment_index = segment_index
        segment_index += 1
        if segment_index >= track_pattern.size():
            segment_index = 0
            lap += 1

    var track_position := float(segment_index) + segment_progress
    var center: float = RaceMath.track_center_x(track_position, track_x)
    # Keep actual world-X motion independent of the road centre. A bend must
    # require steering rather than carrying the car around automatically.
    lateral_offset -= center - previous_center
    var half: float = RaceLevelData.ROAD_WIDTH * 0.5
    var abs_lateral: float = absf(lateral_offset)
    # A car is not "off-road" merely because its center crossed the asphalt
    # edge. Allow for the vehicle half-width so speed loss starts when the
    # body actually reaches the shoulder.
    var road_edge_with_vehicle: float = (
        half
        + RaceLevelData.OFFROAD_VEHICLE_HALF_WIDTH
        + RaceLevelData.OFFROAD_ASPHALT_MARGIN
    )
    var hard_limit: float = road_edge_with_vehicle + RaceLevelData.OFFROAD_SHOULDER

    offroad_amount = clampf((abs_lateral - road_edge_with_vehicle) / RaceLevelData.OFFROAD_SHOULDER, 0.0, 1.0)
    if abs_lateral > road_edge_with_vehicle:
        var shoulder_progress: float = clampf(
            (abs_lateral - road_edge_with_vehicle) / maxf(RaceLevelData.OFFROAD_SHOULDER, 0.001),
            0.0,
            1.0
        )
        var penalty: float = lerpf(
            RaceLevelData.OFFROAD_SOFT_PENALTY,
            RaceLevelData.OFFROAD_HARD_PENALTY,
            shoulder_progress
        )
        var min_drive_speed := 0.0
        if allow_control and throttle > 0.01 and brake_in < 0.01:
            min_drive_speed = RaceLevelData.OFFROAD_MIN_DRIVE_SPEED
        speed = maxf(speed - penalty * dt, minf(speed, min_drive_speed))

    if abs_lateral > hard_limit:
        lateral_offset = sign(lateral_offset) * hard_limit
        if signf(lateral_velocity) == signf(lateral_offset):
            lateral_velocity = 0.0

    # The renderer and physics share the same continuous centerline. World X/Z
    # are presentation-space coordinates derived from that authoritative track
    # position rather than a discrete segment sample.
    world_x = center + lateral_offset

    # Preserve each car's physical start-grid offset as it accelerates out of
    # the line. Progress is still measured from the canonical race origin, so
    # this only prevents the render-space teleport from negative grid Z to 0.
    var canonical_world_z := track_position * RaceLevelData.SEGMENT_HEIGHT
    world_z = canonical_world_z - grid_world_z_offset
    heading_yaw = _heading
    travel_yaw = atan2(lateral_velocity, maxf(forward_speed, 0.001)) if speed > 0.001 else heading_yaw
    slip_angle = clampf(wrapf(heading_yaw - travel_yaw, -PI, PI), -0.20, 0.20)
    sprite_yaw = heading_yaw
    longitudinal_acceleration = (speed - previous_speed) / maxf(dt, 0.0001)
    distance_travelled += speed * dt

func progress(track_size: int) -> float:
    return float(lap) * float(track_size) + float(segment_index) + segment_progress
