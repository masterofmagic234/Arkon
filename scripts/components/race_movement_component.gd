extends Node
class_name RaceMovementComponent

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

const ENGINE_FORCE := 42.0
const BRAKE_FORCE := 28.0
const MAX_STEERING_ANGLE := deg_to_rad(28.0)
const GRID_START_PROGRESS := 0.45
const GRID_SPACING_PROGRESS := 0.12
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
var track_progress := 0.0
var previous_track_progress := 0.0
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

    if vehicle == null:
        vehicle = racer as VehicleBody3D
    if vehicle == null:
        push_error("[Level2] RaceMovementComponent requires a VehicleBody3D parent.")
        return

    vehicle.mass = 900.0
    vehicle.linear_damp = 0.08
    vehicle.angular_damp = 1.35
    vehicle.gravity_scale = 1.0
    vehicle.can_sleep = false
    vehicle.continuous_cd = true
    vehicle.sleeping = false

    var start_progress := fposmod(
        GRID_START_PROGRESS
        - float(grid_index) * GRID_SPACING_PROGRESS,
        float(maxi(track_pattern.size(), 1))
    )
    var start_position := RaceMath.track_world_position(
        start_progress,
        track_x,
        track_pattern.size(),
        RaceLevelData.SEGMENT_HEIGHT
    )
    var start_tangent := RaceMath.track_world_tangent(
        start_progress,
        track_x,
        track_pattern.size(),
        RaceLevelData.SEGMENT_HEIGHT
    )
    var start_right := Vector3.UP.cross(start_tangent).normalized()

    # VehicleBody3D uses local -Z as forward. look_at() aligns that axis with
    # the real track tangent, so the car immediately follows the physical road.
    vehicle.global_position = (
        start_position
        + start_right * lane_x
        + Vector3.UP * 0.13
    )
    vehicle.look_at(
        vehicle.global_position + start_tangent,
        Vector3.UP
    )
    vehicle.linear_velocity = Vector3.ZERO
    vehicle.angular_velocity = Vector3.ZERO

    _update_world_pose()

func start_race() -> void:
    race_active = true
    finished = false

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
    if (
        vehicle == null
        or track_pattern.is_empty()
        or track_x.is_empty()
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
            signal_bus.emit_signal(
                "racer_progress_changed",
                racer,
                progress(track_pattern.size())
            )

func progress(track_size: int) -> float:
    if track_size <= 0:
        return 0.0
    return float(lap) * float(track_size) + track_progress

func set_render_alpha(_alpha: float) -> void:
    # Retained as a compatibility seam for existing HUD/minimap consumers.
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

func get_ai_target_point(
        ahead_segments: float,
        lane_bias: float = 0.0
) -> Vector3:
    if (
        track_pattern.is_empty()
        or track_x.is_empty()
        or vehicle == null
    ):
        return vehicle.global_position if vehicle != null else Vector3.ZERO

    var n := track_pattern.size()
    var target_progress := fposmod(
        track_progress + ahead_segments,
        float(n)
    )
    var target := RaceMath.track_world_position(
        target_progress,
        track_x,
        n,
        RaceLevelData.SEGMENT_HEIGHT
    )
    var tangent := RaceMath.track_world_tangent(
        target_progress,
        track_x,
        n,
        RaceLevelData.SEGMENT_HEIGHT
    )
    var right := Vector3.UP.cross(tangent)
    if right.length_squared() > 0.0001:
        right = right.normalized()

    target += right * (
        lane_bias
        * RaceLevelData.ROAD_WIDTH
        * 0.5
        * 0.55
    )
    return target

func _apply_vehicle_controls() -> void:
    if vehicle == null:
        return

    if not race_active:
        vehicle.engine_force = 0.0
        vehicle.steering = 0.0
        vehicle.brake = BRAKE_FORCE
        return

    var forward_speed := get_forward_speed()
    speed = maxf(forward_speed, 0.0)

    var speed_norm := clampf(
        speed / maxf(
            RaceLevelData.PLAYER_MAX_SPEED,
            0.001
        ),
        0.0,
        1.0
    )
    var steering_authority := lerpf(
        0.70,
        1.0,
        speed_norm
    )

    # Input convention is negative=left, positive=right. VehicleBody3D's
    # positive steering rotates the front wheels toward local left, so invert
    # the input to preserve the game's established control direction.
    vehicle.steering = (
        -steer_in
        * MAX_STEERING_ANGLE
        * steering_authority
    )

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
    var steer_target := Input.get_axis(
        "race_left",
        "race_right"
    )
    steer_in = move_toward(
        steer_in,
        steer_target,
        RaceLevelData.PLAYER_STEER_RESPONSE
        * RaceLevelData.SIMULATION_STEP
    )

    throttle = (
        1.0
        if Input.is_action_pressed("race_accel")
        else 0.0
    )
    brake_in = (
        1.0
        if Input.is_action_pressed("race_brake")
        else 0.0
    )

func _update_world_pose() -> void:
    if vehicle == null or track_pattern.is_empty():
        return

    world_x = vehicle.global_position.x
    world_z = vehicle.global_position.z

    var n := track_pattern.size()
    var old_progress := track_progress
    track_progress = RaceMath.nearest_track_progress(
        vehicle.global_position,
        track_x,
        n,
        RaceLevelData.SEGMENT_HEIGHT,
        track_progress
    )

    segment_index = clampi(
        int(floor(track_progress)),
        0,
        maxi(n - 1, 0)
    )
    segment_progress = track_progress - float(segment_index)

    var center := RaceMath.track_world_position(
        track_progress,
        track_x,
        n,
        RaceLevelData.SEGMENT_HEIGHT
    )
    var tangent := RaceMath.track_world_tangent(
        track_progress,
        track_x,
        n,
        RaceLevelData.SEGMENT_HEIGHT
    )
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
        and old_progress > float(n) * 0.75
        and track_progress < float(n) * 0.25
        and get_forward_speed() > 1.0
    ):
        _complete_lap()

    previous_track_progress = old_progress

func _apply_offroad_penalty(dt: float) -> void:
    if vehicle == null or track_pattern.is_empty():
        return

    var n := track_pattern.size()
    var center := RaceMath.track_world_position(
        track_progress,
        track_x,
        n,
        RaceLevelData.SEGMENT_HEIGHT
    )
    var tangent := RaceMath.track_world_tangent(
        track_progress,
        track_x,
        n,
        RaceLevelData.SEGMENT_HEIGHT
    )
    var right := Vector3.UP.cross(tangent)
    if right.length_squared() < 0.0001:
        return
    right = right.normalized()

    var half := RaceLevelData.ROAD_WIDTH * 0.5
    var abs_lateral := absf(lateral_offset)

    if abs_lateral > half:
        var shoulder_progress := clampf(
            (abs_lateral - half)
            / maxf(
                RaceLevelData.OFFROAD_SHOULDER,
                0.001
            ),
            0.0,
            1.0
        )
        var penalty := lerpf(
            RaceLevelData.OFFROAD_SOFT_PENALTY,
            RaceLevelData.OFFROAD_HARD_PENALTY,
            shoulder_progress
        )

        var velocity := vehicle.linear_velocity
        var speed_now := velocity.length()
        if speed_now > 0.0:
            vehicle.linear_velocity = (
                velocity
                * maxf(
                    0.0,
                    1.0 - (
                        penalty * dt / speed_now
                    )
                )
            )

    if abs_lateral > half + TRACK_EDGE_HARD_LIMIT:
        var excess := abs_lateral - (
            half + TRACK_EDGE_HARD_LIMIT
        )
        var inward := -sign(lateral_offset) * right
        var correction_force := clampf(
            excess * vehicle.mass * 5.0,
            0.0,
            vehicle.mass * 8.0
        )
        vehicle.apply_central_force(
            inward * correction_force
        )

        var lateral_velocity := vehicle.linear_velocity.dot(right)
        if sign(lateral_velocity) == sign(lateral_offset):
            vehicle.apply_central_force(
                inward
                * absf(lateral_velocity)
                * vehicle.mass
                * 1.5
            )

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
