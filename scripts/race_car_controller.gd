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

    if allow_control:
        speed = RaceMath.step_speed(speed, throttle, brake_in, delta, max_speed, RaceLevelData.PLAYER_ACCEL, RaceLevelData.PLAYER_BRAKE, RaceLevelData.PLAYER_DRAG)

        if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NFS_UNDERGROUND2:
            steer_applied = move_toward(
                steer_applied,
                steer_in,
                RaceLevelData.NFS_STEER_INPUT_RESPONSE * delta
            )
        else:
            steer_applied = steer_in

        var d := RaceMath.steering_delta(
            steer_applied,
            speed,
            delta,
            RaceLevelData.PLAYER_STEER_RATE,
            max_speed
        )

        if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NFS_UNDERGROUND2:
            var low_speed_grip := clampf(
                (speed - RaceLevelData.NFS_LOW_SPEED_LATERAL_LOCK) / 4.0,
                0.0,
                1.0
            )
            var desired_lateral_velocity := 0.0
            if low_speed_grip > 0.0:
                desired_lateral_velocity = (
                    d / maxf(delta, 0.0001)
                    * speed
                    * 0.12
                    * low_speed_grip
                )
            var grip_blend := 1.0 - exp(
                -RaceLevelData.NFS_LATERAL_GRIP_RESPONSE * maxf(delta, 0.0)
            )
            lateral_velocity = lerpf(
                lateral_velocity,
                desired_lateral_velocity,
                grip_blend
            )
            lateral_offset += lateral_velocity * delta
        else:
            # NES tribute profile keeps the original direct arcade response.
            lateral_offset += d * maxf(speed, 4.0) * 0.12
            lateral_velocity = (
                d * maxf(speed, 4.0) * 0.12
                / maxf(delta, 0.0001)
            )
    else:
        speed = maxf(speed - 6.0 * delta, 0.0)
        lateral_velocity = move_toward(
            lateral_velocity,
            0.0,
            RaceLevelData.NFS_LATERAL_GRIP_RESPONSE * maxf(delta, 0.0)
        )

    var advance: float = speed * delta / RaceLevelData.SEGMENT_HEIGHT
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
        speed = maxf(speed - penalty * delta, 0.0)

    if abs_lateral > hard_limit:
        lateral_offset = sign(lateral_offset) * hard_limit
        speed = maxf(speed - RaceLevelData.OFFROAD_HARD_PENALTY * delta, 0.0)

    # The renderer and physics share the same continuous centerline. World X/Z
    # are presentation-space coordinates derived from that authoritative track
    # position rather than a discrete segment sample.
    world_x = center + lateral_offset

    # Preserve each car's physical start-grid offset as it accelerates out of
    # the line. Progress is still measured from the canonical race origin, so
    # this only prevents the render-space teleport from negative grid Z to 0.
    var canonical_world_z := track_position * RaceLevelData.SEGMENT_HEIGHT
    world_z = canonical_world_z - grid_world_z_offset
    if RaceLevelData.ACTIVE_HANDLING_PROFILE == RaceLevelData.HandlingProfile.NFS_UNDERGROUND2:
        var target_heading_yaw := (
            -steer_applied * RaceLevelData.NFS_MAX_HEADING_YAW
        )
        heading_yaw = lerp_angle(
            heading_yaw,
            target_heading_yaw,
            1.0 - exp(-RaceLevelData.NFS_HEADING_RESPONSE * maxf(delta, 0.0))
        )
        travel_yaw = clampf(
            atan2(lateral_velocity, maxf(speed, 0.5)),
            -0.18,
            0.18
        )
        slip_angle = clampf(
            heading_yaw - travel_yaw,
            -0.16,
            0.16
        )
    else:
        heading_yaw = -steer_in * 0.10
        travel_yaw = 0.0
        slip_angle = 0.0

    var target_yaw := heading_yaw
    sprite_yaw = lerpf(
        sprite_yaw,
        target_yaw,
        clampf(delta * 8.0, 0.0, 1.0)
    )

func progress(track_size: int) -> float:
    return float(lap) * float(track_size) + float(segment_index) + segment_progress
