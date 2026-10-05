extends Node
class_name RaceDirector

const RaceLevelData = preload("res://scripts/race_level_data.gd")
const RaceAuthoredTrackData = preload(
    "res://scripts/race_authored_track_data.gd"
)
const Level2Racer = preload("res://scripts/level2_racer.gd")

var track_pattern: Array = []
var track_x := PackedFloat32Array()
var track_centerline := PackedVector3Array()
var track_length := 0.0
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
var signal_bus: Node = null

func _ready() -> void:
    process_priority = 100
    signal_bus = get_node_or_null(
        "/root/SignalBus"
    )
    if signal_bus == null:
        push_error(
            "[Level2] RaceDirector: SignalBus unavailable."
        )

func setup(racers_ref: Array) -> void:
    if signal_bus == null:
        return

    var callback := Callable(
        self,
        "_on_racer_lap_completed"
    )
    if signal_bus.is_connected(
        "racer_lap_completed",
        callback
    ):
        signal_bus.disconnect(
            "racer_lap_completed",
            callback
        )
    signal_bus.connect(
        "racer_lap_completed",
        callback
    )

    track_centerline = (
        RaceAuthoredTrackData.build_centerline()
    )
    track_length = _calculate_track_length()
    track_pattern = Array(track_centerline)
    track_x = PackedFloat32Array()

    racers = racers_ref.filter(
        func(node): return node is Level2Racer
    )

    player = null
    for racer in racers:
        if racer.is_player:
            player = racer
            break

    if (
        player == null
        or racers.size() != RaceLevelData.RACER_COUNT
        or track_centerline.size() < 20
    ):
        push_error(
            "[Level2] Authored London race setup failed."
        )
        return

    for racer in racers:
        racer.configure(
            track_pattern,
            track_x
        )

    racers.sort_custom(
        Callable(self, "_compare_grid")
    )
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
    signal_bus.emit_signal(&"race_countdown_changed", 3)
    signal_bus.emit_signal(&"show_message", "ОПЕРАЦИЯ «ЖЁЛУДЬ»: ГОНКА", 2.4)

func _process(delta: float) -> void:
    if player == null or track_length <= 1.0:
        return

    if not race_started:
        countdown = maxf(
            0.0,
            countdown - delta
        )
        var next_value := int(
            ceil(countdown)
        )
        if next_value != _countdown_value:
            _countdown_value = next_value
            signal_bus.emit_signal(&"race_countdown_changed", next_value)
        if countdown <= 0.0:
            _start_race()
        return

    if race_finished:
        return

    race_time += delta
    _time_emit_timer -= delta
    if _time_emit_timer <= 0.0:
        _time_emit_timer = 0.10
        signal_bus.emit_signal(&"race_time_changed", race_time, player.movement.lap_elapsed, player.movement.best_lap)

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

    signal_bus.emit_signal(&"race_started")
    signal_bus.emit_signal(&"race_time_changed", 0.0, 0.0, -1.0)

func _on_racer_lap_completed(
        racer: Node,
        _lap_time: float,
        _best_time: float
) -> void:
    if race_finished or not race_started:
        return

    var level2_racer := racer as Level2Racer
    if level2_racer == null:
        return

    if level2_racer.movement.lap < RaceLevelData.TOTAL_LAPS:
        return

    _finish_racer(level2_racer)

func _finish_racer(
        racer: Level2Racer
) -> void:
    if racer.movement.finished:
        return

    _emit_ranking(true)
    _finish_order += 1
    racer.movement.finished = true
    racer.movement.finish_position = _finish_order
    racer.movement.finish_time = race_time
    racer.stop_race()

    signal_bus.emit_signal(&"racer_finished", racer, _finish_order)

    if racer == player:
        race_finished = true
        signal_bus.emit_signal(&"race_time_changed", race_time, player.movement.lap_elapsed, player.movement.best_lap)
        signal_bus.emit_signal(&"level_completed", &"level2")
    elif _finish_order >= racers.size():
        race_finished = true

func _emit_ranking(force: bool) -> void:
    var ordered := racers.duplicate()
    ordered.sort_custom(
        Callable(self, "_compare_progress")
    )

    for i in ordered.size():
        var racer := ordered[i] as Level2Racer
        if racer == null:
            continue

        var next_position := i + 1
        if (
            force
            or int(_positions.get(
                racer,
                -1
            )) != next_position
        ):
            _positions[racer] = next_position
            racer.movement.position = next_position
            signal_bus.emit_signal(&"racer_position_changed", racer, next_position)

func _compare_grid(
        a: Level2Racer,
        b: Level2Racer
) -> bool:
    return a.grid_index < b.grid_index

func _compare_progress(
        a: Level2Racer,
        b: Level2Racer
) -> bool:
    if a.movement.finished and b.movement.finished:
        return (
            a.movement.finish_position
            < b.movement.finish_position
        )
    if a.movement.finished:
        return true
    if b.movement.finished:
        return false
    if not race_started:
        return a.grid_index < b.grid_index

    return (
        a.movement.progress(track_length)
        > b.movement.progress(track_length)
    )

func get_player_movement() -> RaceMovementComponent:
    return (
        player.movement
        if player != null
        else null
    )

func _calculate_track_length() -> float:
    if track_centerline.size() < 2:
        return 0.0

    var total := 0.0
    for i in range(track_centerline.size()):
        total += (
            track_centerline[
                (i + 1) % track_centerline.size()
            ]
            - track_centerline[i]
        ).length()
    return total

func _exit_tree() -> void:
    if signal_bus == null:
        return

    var callback := Callable(
        self,
        "_on_racer_lap_completed"
    )
    if signal_bus.is_connected(
        "racer_lap_completed",
        callback
    ):
        signal_bus.disconnect(
            "racer_lap_completed",
            callback
        )
