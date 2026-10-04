extends Node
class_name RaceMovementComponent

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

const ENGINE_FORCE := 42.0
const BRAKE_FORCE := 28.0
const MAX_STEERING_ANGLE := deg_to_rad(28.0)
const GRID_START_Z := 18.0
const GRID_SPACING_Z := 5.0
const TRACK_EDGE_HARD_LIMIT := 1.8

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

var grid_index := 0
var segment_index := 0
var segment_progress := 0.0
var last_segment_index := -1
var lap := 0
var position := 1
var finish_time := -1.0
var finish_position := 0

var track_yaw := 0.0
var race_active := false
var finished := false
var lap_elapsed := 0.0
var best_lap := -1.0

var track_pattern: Array = []
var track_x := PackedFloat32Array()
var progress_emit_timer := 0.0
var signal_bus: Node = null
var _lap_armed := true

func _ready() -> void:
    vehicle = get_parent() as VehicleBody3D

func setup(
        racer_ref: Node,
        player_flag: bool,
        grid_slot: int,
        lane_x: float,
        pattern: Array,
        tx: PackedFloat32Array
) -> void:
    racer = racer_ref
    is_player = player_flag
    grid_index = grid_slot
    track_pattern = pattern
    track_x = tx
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
    _lap_armed = true

    if vehicle == null:
        vehicle = racer as VehicleBody3D
    if vehicle == null:
        push_error("[Level2] RaceMovementComponent requires a VehicleBody3D parent.")
        return

    vehicle.mass = 900.0
    vehicle.linear_damp = 0.10
    vehicle.angular_damp = 1.65
    vehicle.gravity_scale = 1.0
    vehicle.sleeping = false

    var start_z := GRID_START_Z - float(grid_index) * GRID_SPACING_Z
    var start_track_pos := clampf(
        start_z / maxf(RaceLevelData.SEGMENT_HEIGHT, 0.001),
        0.0,
        float(maxi(track_pattern.size() - 1, 0))
    )
    var center_x := RaceMath.track_center_x(start_track_pos, track_x)
    var start_y := RaceMath.track_elevation(start_track_pos, track_pattern.size()) + 1.0

    # Track data increases world Z. VehicleBody3D's forward is local -Z, so
    # face the grid down +Z at spawn; thereafter physics owns orientation.
    vehicle.global_position = Vector3(
        center_x + lane_x,
        start_y,
        start_z
    )
    vehicle.global_rotation = Vector3(0.0, PI, 0.0)
    vehicle.linear_velocity = Vector3.ZERO
    vehicle.angular_velocity = Vector3.ZERO

    _update_world_pose()

func start_race() -> void:
    race_active = true
    finished = false
    _lap_armed = true

func stop_race() -> void:
    race_active = false
    throttle = 0.0
    brake_in = 1.0
    if vehicle != null:
        vehicle.engine_force = 0.0
        vehicle.steering = 0.0
        vehicle.brake = BRAKE_FORCE
    if finished:
        speed = 0.0

func set_inputs(
        steer: float,
        th: float,
        br: float
) -> void:
    steer_in = clampf(steer, -1.0, 1.0)
    throttle = clampf(th, 0.0, 1.0)
    brake_in = clampf(br, 0.0, 1.0)

func tick(dt: float) -> void:
    if vehicle == null or track_pattern.is_empty() or track_x.is_empty() or finished:
        return

    if is_player:
        _read_player_input()

    if race_active:
        lap_elapsed += dt

    _apply_vehicle_controls()

    # Sample the physical body. Position/orientation are no longer synthesized
    # from a fake lateral value; VehicleBody3D owns the actual movement.
    _update_world_pose()
    _update_race_progress()
    _apply_offroad_penalty(dt)

    progress_emit_timer -= dt
    if progress_emit_timer <= 0.0:
        progress_emit_timer = 0.10
        if racer != null and signal_bus != null:
            signal_bus.emit_signal(
                "racer_progress_changed",
                racer,
                progress(track_pattern.size())
            )

func progress(track_size: int) -> float:
    if track_size <= 0:
        return 0.0

    var loop_progress := clampf(
        world_z / maxf(RaceLevelData.SEGMENT_HEIGHT, 0.001),
        0.0,
        float(track_size)
    )
    return float(lap) * float(track_size) + loop_progress

func set_render_alpha(_alpha: float) -> void:
    # Kept as an architectural no-op so HUD/minimap consumers do not need a
    # second interface after the renderer migration.
    pass

func get_render_progress() -> float:
    return progress(track_pattern.size())

func get_render_world_x() -> float:
    return world_x

func get_render_world_z() -> float:
    return world_z

func get_render_track_yaw() -> float:
    return track_yaw

func get_physical_vehicle() -> VehicleBody3D:
    return vehicle

func get_ai_target_point(ahead_segments: float, lane_bias: float = 0.0) -> Vector3:
    if track_pattern.is_empty() or track_x.is_empty() or vehicle == null:
        return vehicle.global_position if vehicle != null else Vector3.ZERO

    var n := track_pattern.size()
    var current_loop := clampf(
        world_z / maxf(RaceLevelData.SEGMENT_HEIGHT, 0.001),
        0.0,
        float(n - 0.001)
    )
    var target_loop := fposmod(current_loop + ahead_segments, float(n))
    var target_x := RaceMath.track_center_x(target_loop, track_x)
    var road_half := RaceLevelData.ROAD_WIDTH * 0.5
    target_x += lane_bias * road_half * 0.55

    var target_z := target_loop * RaceLevelData.SEGMENT_HEIGHT
    var dz := target_z - world_z
    var track_len := float(n) * RaceLevelData.SEGMENT_HEIGHT
    if dz < -track_len * 0.5:
        target_z += track_len
    elif dz > track_len * 0.5:
        target_z -= track_len

    return Vector3(
        target_x,
        RaceMath.track_elevation(target_loop, n),
        target_z
    )

func _apply_vehicle_controls() -> void:
    if vehicle == null:
        return

    if not race_active:
        vehicle.engine_force = 0.0
        vehicle.steering = 0.0
        vehicle.brake = 14.0
        return

    var forward_speed := get_forward_speed()
    speed = maxf(forward_speed, 0.0)

    var speed_norm := clampf(
        speed / maxf(RaceLevelData.PLAYER_MAX_SPEED, 0.001),
        0.0,
        1.0
    )
    var steering_authority := lerpf(0.70, 1.0, speed_norm)
    # Godot's positive wheel steering rotates toward local -X (left). Our
    # gameplay input convention is negative=left, positive=right.
    vehicle.steering = -steer_in * MAX_STEERING_ANGLE * steering_authority

    var engine := throttle * ENGINE_FORCE
    if speed > RaceLevelData.PLAYER_MAX_SPEED:
        engine = 0.0
        vehicle.brake = maxf(
            brake_in * BRAKE_FORCE,
            clampf(
                (speed - RaceLevelData.PLAYER_MAX_SPEED) * 3.0,
                0.0,
                8.0
            )
        )
    else:
        vehicle.brake = brake_in * BRAKE_FORCE

    vehicle.engine_force = engine

func get_forward_speed() -> float:
    if vehicle == null:
        return 0.0
    var forward := -vehicle.global_transform.basis.z
    return vehicle.linear_velocity.dot(forward)

func _read_player_input() -> void:
    var steer_target := Input.get_axis("race_left", "race_right")
    steer_in = move_toward(
        steer_in,
        steer_target,
        RaceLevelData.PLAYER_STEER_RESPONSE
        * RaceLevelData.SIMULATION_STEP
    )

    throttle = 1.0 if Input.is_action_pressed("race_accel") else 0.0
    brake_in = 1.0 if Input.is_action_pressed("race_brake") else 0.0

func _update_world_pose() -> void:
    if vehicle == null or track_pattern.is_empty():
        return

    world_x = vehicle.global_position.x
    world_z = vehicle.global_position.z

    var loop_position := clampf(
        world_z / maxf(RaceLevelData.SEGMENT_HEIGHT, 0.001),
        0.0,
        float(track_pattern.size() - 0.001)
    )
    segment_index = clampi(
        int(floor(loop_position)),
        0,
        maxi(track_pattern.size() - 1, 0)
    )
    segment_progress = loop_position - float(segment_index)

    var center := RaceMath.track_center_x(loop_position, track_x)
    lateral_offset = world_x - center

    track_yaw = RaceMath.track_heading(
        loop_position,
        track_x,
        RaceLevelData.SEGMENT_HEIGHT
    )

func _update_race_progress() -> void:
    if vehicle == null or track_pattern.is_empty() or not race_active:
        return

    var track_length_world := (
        float(track_pattern.size())
        * RaceLevelData.SEGMENT_HEIGHT
    )

    if world_z >= track_length_world - 1.5 and _lap_armed:
        _lap_armed = false
        _complete_lap()

        if lap < RaceLevelData.TOTAL_LAPS:
            _reset_for_next_lap()

    if world_z < track_length_world * 0.55:
        _lap_armed = true

func _reset_for_next_lap() -> void:
    if vehicle == null:
        return

    var loop_position := 0.5
    var center := RaceMath.track_center_x(loop_position, track_x)
    var y := RaceMath.track_elevation(loop_position, track_pattern.size()) + 1.0

    # The physical circuit is a long 3D strip. Crossing the finish line resets
    # the vehicle to the same real start area for the next lap, with momentum
    # preserved only as a forward scalar to avoid an unphysical explosion.
    var carry_speed := minf(
        maxf(get_forward_speed(), 0.0),
        RaceLevelData.PLAYER_MAX_SPEED
    )
    vehicle.global_position = Vector3(
        center + lateral_offset,
        y,
        loop_position * RaceLevelData.SEGMENT_HEIGHT
    )
    vehicle.global_rotation = Vector3(0.0, PI, 0.0)
    vehicle.linear_velocity = Vector3(0.0, 0.0, carry_speed)
    vehicle.angular_velocity = Vector3.ZERO
    world_z = vehicle.global_position.z

func _apply_offroad_penalty(dt: float) -> void:
    if vehicle == null:
        return

    var half := RaceLevelData.ROAD_WIDTH * 0.5
    var abs_lateral := absf(lateral_offset)

    if abs_lateral > half:
        var shoulder_progress := clampf(
            (abs_lateral - half)
            / maxf(RaceLevelData.OFFROAD_SHOULDER, 0.001),
            0.0,
            1.0
        )
        var penalty := lerpf(
            RaceLevelData.OFFROAD_SOFT_PENALTY,
            RaceLevelData.OFFROAD_HARD_PENALTY,
            shoulder_progress
        )
        var v := vehicle.linear_velocity
        var speed_now := v.length()
        if speed_now > 0.0:
            vehicle.linear_velocity = v * maxf(
                0.0,
                1.0 - (penalty * dt / speed_now)
            )

    if abs_lateral > RaceLevelData.ROAD_WIDTH * 0.5 + TRACK_EDGE_HARD_LIMIT:
        var clamped_x := RaceMath.track_center_x(
            world_z / maxf(RaceLevelData.SEGMENT_HEIGHT, 0.001),
            track_x
        ) + sign(lateral_offset) * (
            half + TRACK_EDGE_HARD_LIMIT
        )
        var pos := vehicle.global_position
        pos.x = clamped_x
        vehicle.global_position = pos
        lateral_offset = pos.x - RaceMath.track_center_x(
            world_z / maxf(RaceLevelData.SEGMENT_HEIGHT, 0.001),
            track_x
        )
        vehicle.linear_velocity *= 0.70

func _complete_lap() -> void:
    var completed_time := lap_elapsed

    if best_lap < 0.0 or completed_time < best_lap:
        best_lap = completed_time

    lap_elapsed = 0.0
    lap += 1

    if racer != null and signal_bus != null:
        signal_bus.emit_signal(
            "racer_lap_completed",
            racer,
            completed_time,
            best_lap
        )
