extends Node
class_name RaceMovementComponent

const RaceLevelData = preload("res://scripts/race_level_data.gd")

const DRIVE_FORCE := 2200.0
const BRAKE_FORCE := 3200.0
const YAW_DAMPING := 8.0
const DRIVE_ACCELERATION := 18.0
const BRAKE_ACCELERATION := 24.0
const MAX_YAW_RATE := 2.8

const GRID_START_DISTANCE := 2.0
const GRID_SPACING_DISTANCE := 4.0
const ROAD_WIDTH := 4.8
const ROAD_SHOULDER := 1.2

var racer: Node = null
var vehicle: VehicleBody3D = null
var is_player := false

var lateral_offset := 0.0
var world_x := 0.0
var world_z := 0.0
var speed := 0.0
var steer_in := 0.0
var throttle := 0.0
var brake_in := 0.0

var external_input_enabled := false
var external_steer := 0.0
var external_throttle := 0.0
var external_brake := 0.0

var grid_index := 0
var segment_index := 0
var segment_progress := 0.0
var track_progress := 0.0
var previous_track_progress := 0.0
var track_length := 0.0

var track_centerline := PackedVector3Array()
var track_cumulative := PackedFloat32Array()

var position := 1
var lap := 0
var finish_time := -1.0
var finish_position := 0

var track_yaw := 0.0
var race_active := false
var finished := false
var lap_elapsed := 0.0
var best_lap := -1.0
var progress_emit_timer := 0.0
var signal_bus: Node = null

func _ready() -> void:
    vehicle = get_parent() as VehicleBody3D

func setup(
        racer_ref: Node,
        player_flag: bool,
        grid_slot: int,
        lane_x: float,
        pattern: Array,
        _unused_track_x: PackedFloat32Array
) -> void:
    racer = racer_ref
    is_player = player_flag
    grid_index = grid_slot

    track_centerline.clear()
    for point in pattern:
        if point is Vector3:
            track_centerline.append(point)

    track_cumulative.clear()
    track_length = _build_cumulative_lengths()

    signal_bus = get_node_or_null("/root/SignalBus")
    race_active = false
    finished = false
    lap = 0
    lap_elapsed = 0.0
    best_lap = -1.0
    finish_time = -1.0
    finish_position = 0
    progress_emit_timer = 0.0
    steer_in = 0.0
    throttle = 0.0
    brake_in = 0.0
    external_input_enabled = false
    external_steer = 0.0
    external_throttle = 0.0
    external_brake = 0.0

    if vehicle == null:
        vehicle = racer as VehicleBody3D
    if vehicle == null or track_length <= 1.0:
        push_error(
            "[Level2] Authored movement setup failed."
        )
        return

    vehicle.mass = 900.0
    vehicle.linear_damp = 0.08
    vehicle.angular_damp = 1.35
    vehicle.gravity_scale = 1.0
    vehicle.can_sleep = false
    vehicle.freeze = true
    vehicle.continuous_cd = true
    vehicle.axis_lock_angular_x = true
    vehicle.axis_lock_angular_z = true
    vehicle.sleeping = false

    var start_distance := fposmod(
        GRID_START_DISTANCE
        - float(grid_index) * GRID_SPACING_DISTANCE,
        track_length
    )
    var start_position := _path_position(start_distance)
    var start_tangent := _path_tangent(start_distance)
    var start_right := Vector3.UP.cross(start_tangent)

    if start_right.length_squared() < 0.0001:
        start_right = Vector3.RIGHT
    else:
        start_right = start_right.normalized()

    vehicle.global_position = (
        start_position
        + start_right * lane_x
        + Vector3.UP * 0.05
    )
    vehicle.look_at(
        vehicle.global_position + start_tangent,
        Vector3.UP
    )
    vehicle.linear_velocity = Vector3.ZERO
    vehicle.angular_velocity = Vector3.ZERO
    speed = 0.0

    track_progress = start_distance
    previous_track_progress = start_distance
    _update_world_pose()

func start_race() -> void:
    race_active = true
    finished = false

func stop_race() -> void:
    race_active = false
    throttle = 0.0
    brake_in = 1.0

    if vehicle != null:
        var velocity := vehicle.linear_velocity
        velocity.x = 0.0
        velocity.z = 0.0
        vehicle.linear_velocity = velocity
        vehicle.engine_force = 0.0
        vehicle.steering = 0.0
        vehicle.brake = 0.0

func set_inputs(steer: float, th: float, br: float) -> void:
    steer_in = clampf(steer, -1.0, 1.0)
    throttle = clampf(th, 0.0, 1.0)
    brake_in = clampf(br, 0.0, 1.0)

func set_external_input(
        steer: float,
        th: float,
        br: float
) -> void:
    external_input_enabled = true
    external_steer = clampf(steer, -1.0, 1.0)
    external_throttle = clampf(th, 0.0, 1.0)
    external_brake = clampf(br, 0.0, 1.0)

func clear_external_input() -> void:
    external_input_enabled = false
    external_steer = 0.0
    external_throttle = 0.0
    external_brake = 0.0

func tick(dt: float) -> void:
    if (
        vehicle == null
        or track_centerline.size() < 2
        or track_length <= 1.0
        or finished
    ):
        return

    if is_player:
        _read_player_input()

    if race_active:
        lap_elapsed += dt

    _apply_vehicle_controls()
    _update_world_pose()
    _apply_offroad_penalty(dt)

    progress_emit_timer -= dt
    if progress_emit_timer <= 0.0:
        progress_emit_timer = 0.10
        if racer != null and signal_bus != null:
            signal_bus.emit_signal(&"racer_progress_changed", racer, progress(track_length))

func progress(_ignored: float = 0.0) -> float:
    return float(lap) * track_length + track_progress

func get_render_progress() -> float:
    return progress(track_length)

func get_render_world_x() -> float:
    return world_x

func get_render_world_z() -> float:
    return world_z

func get_render_track_yaw() -> float:
    return track_yaw

func get_physical_vehicle() -> VehicleBody3D:
    return vehicle

func get_track_length() -> float:
    return track_length

func get_track_position_at_distance(
        distance: float
) -> Vector3:
    return _path_position(
        fposmod(distance, track_length)
    )

func get_track_tangent_at_distance(
        distance: float
) -> Vector3:
    return _path_tangent(
        fposmod(distance, track_length)
    )

func get_curve_severity(
        ahead_distance: float
) -> float:
    var a := _path_tangent(track_progress)
    var b := _path_tangent(
        track_progress + ahead_distance
    )
    return clampf(
        (1.0 - clampf(a.dot(b), -1.0, 1.0)) * 2.2,
        0.0,
        1.0
    )

func get_ai_target_point(
        ahead_distance: float,
        lane_bias: float = 0.0
) -> Vector3:
    var target := _path_position(
        track_progress + ahead_distance
    )
    var tangent := _path_tangent(
        track_progress + ahead_distance
    )
    var right := Vector3.UP.cross(tangent)

    if right.length_squared() > 0.0001:
        target += right.normalized() * (
            lane_bias * ROAD_WIDTH * 0.35
        )

    return target

func _apply_vehicle_controls() -> void:
    if not race_active:
        speed = move_toward(
            speed,
            0.0,
            BRAKE_ACCELERATION * RaceLevelData.SIMULATION_STEP
        )
        vehicle.linear_velocity = Vector3.ZERO
        vehicle.angular_velocity = Vector3.ZERO
        return

    var target_speed := (
        throttle
        * RaceLevelData.PLAYER_MAX_SPEED
    )
    if brake_in > 0.0:
        target_speed = 0.0

    var acceleration := (
        BRAKE_ACCELERATION
        if brake_in > 0.0
        else DRIVE_ACCELERATION
    )
    speed = move_toward(
        speed,
        target_speed,
        acceleration * RaceLevelData.SIMULATION_STEP
    )

    var speed_norm := clampf(
        speed
        / maxf(RaceLevelData.PLAYER_MAX_SPEED, 0.001),
        0.0,
        1.0
    )

    # VehicleBody3D's wheel solver was fighting the deterministic arcade
    # controller on the imported track. Keep the VehicleBody3D as the
    # gameplay collider/visual parent, but drive its pose explicitly.
    var next_progress := fposmod(
        track_progress
        + speed * RaceLevelData.SIMULATION_STEP,
        track_length
    )
    var tangent := _path_tangent(next_progress)
    var right := Vector3.UP.cross(tangent)
    if right.length_squared() < 0.0001:
        right = Vector3.RIGHT
    else:
        right = right.normalized()

    lateral_offset += (
        steer_in
        * lerpf(2.2, 5.0, speed_norm)
        * RaceLevelData.SIMULATION_STEP
    )
    lateral_offset = clampf(
        lateral_offset,
        -ROAD_WIDTH * 0.43,
        ROAD_WIDTH * 0.43
    )

    var center := _path_position(next_progress)
    vehicle.global_position = (
        center
        + right * lateral_offset
        + Vector3.UP * 0.05
    )

    var path_yaw := atan2(
        tangent.x,
        tangent.z
    )
    var steering_yaw := (
        steer_in
        * lerpf(0.08, 0.35, speed_norm)
    )
    vehicle.global_rotation = Vector3(
        0.0,
        path_yaw + steering_yaw,
        0.0
    )
    vehicle.linear_velocity = Vector3.ZERO
    vehicle.angular_velocity = Vector3.ZERO
    track_progress = next_progress

func get_forward_speed() -> float:
    return speed

func _read_player_input() -> void:
    if external_input_enabled:
        steer_in = move_toward(
            steer_in,
            external_steer,
            RaceLevelData.PLAYER_STEER_RESPONSE
            * RaceLevelData.SIMULATION_STEP
        )
        throttle = external_throttle
        brake_in = external_brake
        return

    steer_in = move_toward(
        steer_in,
        Input.get_axis("race_left", "race_right"),
        RaceLevelData.PLAYER_STEER_RESPONSE
        * RaceLevelData.SIMULATION_STEP
    )
    throttle = 1.0 if Input.is_action_pressed(
        "race_accel"
    ) else 0.0
    brake_in = 1.0 if Input.is_action_pressed(
        "race_brake"
    ) else 0.0

func _update_world_pose() -> void:
    var old_progress := track_progress
    track_progress = _nearest_track_distance(
        vehicle.global_position,
        track_progress
    )

    world_x = vehicle.global_position.x
    world_z = vehicle.global_position.z

    segment_progress = (
        track_progress
        / maxf(track_length, 0.001)
    )
    segment_index = int(
        floor(
            segment_progress
            * float(track_centerline.size())
        )
    ) % track_centerline.size()

    var center := _path_position(track_progress)
    var tangent := _path_tangent(track_progress)
    var right := Vector3.UP.cross(tangent)

    if right.length_squared() > 0.0001:
        right = right.normalized()

    lateral_offset = (
        vehicle.global_position - center
    ).dot(right)
    track_yaw = atan2(
        tangent.x,
        tangent.z
    )

    if (
        race_active
        and old_progress > track_length * 0.75
        and track_progress < track_length * 0.25
        and get_forward_speed() > 1.0
    ):
        _complete_lap()

    previous_track_progress = old_progress

func _apply_offroad_penalty(dt: float) -> void:
    var abs_lateral := absf(lateral_offset)
    if abs_lateral <= ROAD_WIDTH * 0.5:
        return

    var severity := clampf(
        (
            abs_lateral
            - ROAD_WIDTH * 0.5
        ) / maxf(ROAD_SHOULDER, 0.001),
        0.0,
        1.0
    )
    var penalty := lerpf(
        RaceLevelData.OFFROAD_SOFT_PENALTY,
        RaceLevelData.OFFROAD_HARD_PENALTY,
        severity
    )

    speed = maxf(
        0.0,
        speed - penalty * dt
    )

func _complete_lap() -> void:
    var completed_time := lap_elapsed
    if best_lap < 0.0 or completed_time < best_lap:
        best_lap = completed_time

    lap_elapsed = 0.0
    lap += 1

    if racer != null and signal_bus != null:
        signal_bus.emit_signal(&"racer_lap_completed", racer, completed_time, best_lap)

func _build_cumulative_lengths() -> float:
    if track_centerline.size() < 2:
        return 0.0

    track_cumulative.resize(
        track_centerline.size() + 1
    )
    track_cumulative[0] = 0.0

    var total := 0.0
    for i in range(track_centerline.size()):
        total += (
            track_centerline[
                (i + 1) % track_centerline.size()
            ]
            - track_centerline[i]
        ).length()
        track_cumulative[i + 1] = total

    return total

func _find_segment(distance: float) -> int:
    var low := 0
    var high := track_centerline.size() - 1

    while low <= high:
        var mid := (low + high) / 2
        if track_cumulative[mid + 1] < distance:
            low = mid + 1
        else:
            high = mid - 1

    return clampi(
        low,
        0,
        track_centerline.size() - 1
    )

func _path_position(distance: float) -> Vector3:
    if track_centerline.size() < 2:
        return Vector3.ZERO

    var wrapped := fposmod(
        distance,
        track_length
    )
    var segment := _find_segment(wrapped)
    var a := track_cumulative[segment]
    var b := track_cumulative[segment + 1]
    var t := clampf(
        (wrapped - a) / maxf(b - a, 0.0001),
        0.0,
        1.0
    )

    return track_centerline[segment].lerp(
        track_centerline[
            (segment + 1)
            % track_centerline.size()
        ],
        t
    )

func _path_tangent(distance: float) -> Vector3:
    if track_centerline.size() < 2:
        return Vector3(0.0, 0.0, -1.0)

    var segment := _find_segment(
        fposmod(distance, track_length)
    )
    var tangent := (
        track_centerline[
            (segment + 1)
            % track_centerline.size()
        ]
        - track_centerline[segment]
    )
    tangent.y = 0.0

    if tangent.length_squared() < 0.0001:
        return Vector3(0.0, 0.0, -1.0)

    return tangent.normalized()

func _nearest_track_distance(
        point: Vector3,
        hint_distance: float
) -> float:
    var best_sq := INF
    var best_progress := fposmod(
        hint_distance,
        track_length
    )
    var center_segment := _find_segment(
        best_progress
    )

    for offset in range(-10, 11):
        var segment := posmod(
            center_segment + offset,
            track_centerline.size()
        )
        var a := track_centerline[segment]
        var b := track_centerline[
            (segment + 1)
            % track_centerline.size()
        ]
        var ab := b - a
        var t := 0.0
        var len_sq := ab.length_squared()

        if len_sq > 0.0001:
            t = clampf(
                (point - a).dot(ab)
                / len_sq,
                0.0,
                1.0
            )

        var closest := a + ab * t
        var delta := point - closest
        delta.y = 0.0
        var sq := delta.length_squared()

        if sq < best_sq:
            best_sq = sq
            best_progress = (
                track_cumulative[segment]
                + (
                    track_cumulative[segment + 1]
                    - track_cumulative[segment]
                ) * t
            )

    return fposmod(
        best_progress,
        track_length
    )
