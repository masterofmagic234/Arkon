extends Node
class_name RaceDirector

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceMath = preload("res://scripts/race_math.gd")
const Level2Racer = preload("res://scripts/level2_racer.gd")

var track_pattern: Array = []
var track_x: PackedFloat32Array = PackedFloat32Array()
var racers: Array = []
var player: Level2Racer = null

var countdown := 3.0
var race_started := false
var race_finished := false
var race_time := 0.0

var _countdown_value := -1
var _time_emit_timer := 0.0
var _ranking_timer := 0.0
var _finish_order := 0
var _positions: Dictionary = {}

func _ready() -> void:
    process_priority = 100

func setup(racers_ref: Array) -> void:
    if SignalBus.racer_lap_completed.is_connected(_on_racer_lap_completed):
        SignalBus.racer_lap_completed.disconnect(_on_racer_lap_completed)
    SignalBus.racer_lap_completed.connect(_on_racer_lap_completed)

    track_pattern = RaceLevelData.get_track_pattern()
    var closure_error := RaceMath.track_closure_error(track_pattern)
    if absf(closure_error) > 0.001:
        push_error(
            "[Level2] Track is not closed laterally. "
            + "Net turn shift = %.3f. Fix RaceTrackData instead of "
            + "bending the centerline at runtime."
            % closure_error
        )
        return

    track_x = RaceMath.accumulate_track_x(track_pattern)
    racers = racers_ref.filter(func(node): return node is Level2Racer)

    player = null
    for racer in racers:
        if racer.is_player:
            player = racer
            break

    if player == null or track_pattern.is_empty():
        push_error("[Level2] RaceDirector requires a player and non-empty track.")
        return

    for racer in racers:
        racer.configure(
            track_pattern,
            track_x
        )

    racers.sort_custom(Callable(self, "_compare_grid"))
    _positions.clear()
    countdown = 3.0
    race_started = false
    race_finished = false
    race_time = 0.0
    _countdown_value = 3
    _time_emit_timer = 0.0
    _ranking_timer = 0.0
    _finish_order = 0

    _emit_ranking(true)
    SignalBus.race_countdown_changed.emit(3)
    SignalBus.show_message.emit(
        "ОПЕРАЦИЯ «ЖЁЛУДЬ»: ГОНКА",
        2.4
    )

func _process(delta: float) -> void:
    if player == null or track_pattern.is_empty():
        return

    if not race_started:
        countdown = maxf(0.0, countdown - delta)
        var next_value := int(ceil(countdown))
        if next_value != _countdown_value:
            _countdown_value = next_value
            SignalBus.race_countdown_changed.emit(next_value)

        if countdown <= 0.0:
            _start_race()
        return

    if race_finished:
        return

    race_time += delta

    _time_emit_timer -= delta
    if _time_emit_timer <= 0.0:
        _time_emit_timer = 0.10
        SignalBus.race_time_changed.emit(
            race_time,
            player.movement.lap_elapsed,
            player.movement.best_lap
        )

    _ranking_timer -= delta
    if _ranking_timer <= 0.0:
        _ranking_timer = 0.10
        _emit_ranking(false)

func _start_race() -> void:
    if race_started or race_finished:
        return

    race_started = true
    countdown = 0.0
    for racer in racers:
        racer.start_race()

    SignalBus.race_started.emit()
    SignalBus.race_time_changed.emit(0.0, 0.0, -1.0)

func _on_racer_lap_completed(
        racer: Node,
        _lap_time: float,
        _best_time: float
) -> void:
    if race_finished or not race_started:
        return
    if racer == null or not racer.is_in_group("level2_racer"):
        return

    var level2_racer := racer as Level2Racer
    if level2_racer == null:
        return

    if level2_racer.movement.lap < RaceLevelData.TOTAL_LAPS:
        return

    _finish_racer(level2_racer)

func _finish_racer(racer: Level2Racer) -> void:
    if racer.movement.finished:
        return

    _emit_ranking(true)
    _finish_order += 1
    racer.movement.finished = true
    racer.movement.finish_position = _finish_order
    racer.movement.finish_time = race_time
    racer.stop_race()

    SignalBus.racer_finished.emit(racer, _finish_order)

    if racer == player:
        race_finished = true
        SignalBus.race_time_changed.emit(
            race_time,
            player.movement.lap_elapsed,
            player.movement.best_lap
        )
        SignalBus.level_completed.emit(&"level2")
    elif _finish_order >= racers.size():
        race_finished = true

func _emit_ranking(force: bool) -> void:
    var ordered := racers.duplicate()
    ordered.sort_custom(Callable(self, "_compare_progress"))

    for i in ordered.size():
        var racer := ordered[i] as Level2Racer
        if racer == null:
            continue
        var next_position := i + 1
        if force or int(_positions.get(racer, -1)) != next_position:
            _positions[racer] = next_position
            racer.movement.position = next_position
            SignalBus.racer_position_changed.emit(
                racer,
                next_position
            )

func _compare_grid(a: Level2Racer, b: Level2Racer) -> bool:
    return a.grid_index < b.grid_index

func _compare_progress(a: Level2Racer, b: Level2Racer) -> bool:
    if a.movement.finished and b.movement.finished:
        return a.movement.finish_position < b.movement.finish_position
    if a.movement.finished:
        return true
    if b.movement.finished:
        return false

    if not race_started:
        return a.grid_index < b.grid_index

    return a.get_progress(track_pattern.size()) > b.get_progress(track_pattern.size())

func get_player_movement() -> RaceMovementComponent:
    return player.movement if player != null else null

func _exit_tree() -> void:
    if SignalBus.racer_lap_completed.is_connected(_on_racer_lap_completed):
        SignalBus.racer_lap_completed.disconnect(_on_racer_lap_completed)
