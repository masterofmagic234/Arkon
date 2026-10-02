extends Node
class_name RaceMovementComponent

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

var racer: Node = null
var is_player: bool = false
var world_x: float = 0.0
var world_z: float = 0.0
var speed: float = 0.0
var steer_in: float = 0.0
var throttle: float = 0.0
var brake_in: float = 0.0
var grid_index: int = 0
var grid_world_z_offset: float = 0.0
var segment_index: int = 0
var segment_progress: float = 0.0
var last_segment_index: int = -1
var lap: int = 0
var position: int = 1
var finish_time: float = -1.0
var finish_position: int = 0
var sprite_yaw: float = 0.0
var race_active: bool = false
var finished: bool = false
var lap_elapsed: float = 0.0
var best_lap: float = -1.0

var track_pattern: Array = []
var track_x: PackedFloat32Array = PackedFloat32Array()
var progress_emit_timer: float = 0.0

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
    _place_on_grid(lane_x)
    race_active = false
    finished = false
    lap_elapsed = 0.0
    best_lap = -1.0
    finish_time = -1.0
    finish_position = 0
    progress_emit_timer = 0.0

func start_race() -> void:
    race_active = true
    finished = false

func stop_race() -> void:
    race_active = false
    throttle = 0.0
    brake_in = 0.0
    if finished:
        speed = 0.0

func set_inputs(steer: float, th: float, br: float) -> void:
    steer_in = clampf(steer, -1.0, 1.0)
    throttle = clampf(th, 0.0, 1.0)
    brake_in = clampf(br, 0.0, 1.0)

func tick(delta: float) -> void:
    if track_pattern.is_empty() or track_x.is_empty() or finished:
        return

    if is_player:
        _read_player_input()

    var max_speed: float = RaceLevelData.PLAYER_MAX_SPEED
    if not is_player:
        max_speed *= 0.92

    if race_active:
        lap_elapsed += delta
        speed = RaceMath.step_speed(
            speed,
            throttle,
            brake_in,
            delta,
            max_speed,
            RaceLevelData.PLAYER_ACCEL,
            RaceLevelData.PLAYER_BRAKE,
            RaceLevelData.PLAYER_DRAG
        )
        var steering := RaceMath.steering_delta(
            steer_in,
            speed,
            delta,
            RaceLevelData.PLAYER_STEER_RATE,
            max_speed
        )
        world_x += steering * maxf(speed, 4.0) * 0.12
    else:
        speed = maxf(speed - 6.0 * delta, 0.0)

    var advance: float = speed * delta / RaceLevelData.SEGMENT_HEIGHT
    segment_progress += advance

    while segment_progress >= 1.0:
        segment_progress -= 1.0
        last_segment_index = segment_index
        segment_index += 1

        if segment_index >= track_pattern.size():
            segment_index = 0
            lap += 1
            if race_active:
                _complete_lap()

    _apply_offroad_penalty(delta)

    var center: float = track_x[segment_index]
    var canonical_world_z := (
        float(segment_index) * RaceLevelData.SEGMENT_HEIGHT
        + segment_progress * RaceLevelData.SEGMENT_HEIGHT
    )
    world_z = canonical_world_z - grid_world_z_offset

    var target_yaw := -steer_in * 0.35
    sprite_yaw = lerpf(
        sprite_yaw,
        target_yaw,
        clampf(delta * 8.0, 0.0, 1.0)
    )

    progress_emit_timer -= delta
    if progress_emit_timer <= 0.0:
        progress_emit_timer = 0.10
        if racer != null:
            SignalBus.racer_progress_changed.emit(racer, progress(track_pattern.size()))

func progress(track_size: int) -> float:
    if track_size <= 0:
        return 0.0
    return float(lap) * float(track_size) + float(segment_index) + segment_progress

func _place_on_grid(lane_x: float) -> void:
    segment_index = 0
    segment_progress = 0.0
    last_segment_index = -1
    lap = 0
    position = grid_index + 1
    speed = 0.0
    steer_in = 0.0
    throttle = 0.0
    brake_in = 0.0
    world_x = track_x[0] + lane_x
    grid_world_z_offset = float(grid_index) * 0.6 * RaceLevelData.SEGMENT_HEIGHT
    world_z = -grid_world_z_offset
    sprite_yaw = 0.0

func _read_player_input() -> void:
    steer_in = Input.get_axis("race_left", "race_right")
    throttle = 1.0 if Input.is_action_pressed("race_accel") else 0.0
    brake_in = 1.0 if Input.is_action_pressed("race_brake") else 0.0

func _apply_offroad_penalty(delta: float) -> void:
    var center: float = track_x[segment_index]
    var half: float = RaceLevelData.ROAD_WIDTH * 0.5
    var lateral_offset: float = world_x - center
    var abs_lateral: float = absf(lateral_offset)
    var hard_limit: float = half + RaceLevelData.OFFROAD_SHOULDER

    if abs_lateral > half:
        var shoulder_progress: float = clampf(
            (abs_lateral - half) / maxf(RaceLevelData.OFFROAD_SHOULDER, 0.001),
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
        world_x = center + sign(lateral_offset) * hard_limit
        speed = maxf(
            speed - RaceLevelData.OFFROAD_HARD_PENALTY * delta,
            0.0
        )

func _complete_lap() -> void:
    var completed_time := lap_elapsed
    if best_lap < 0.0 or completed_time < best_lap:
        best_lap = completed_time
    lap_elapsed = 0.0

    if racer != null:
        SignalBus.racer_lap_completed.emit(
            racer,
            completed_time,
            best_lap
        )
