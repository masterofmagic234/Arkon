extends Node
class_name RaceHud

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

@onready var lap_label: Label = get_node_or_null("../Lap") as Label
@onready var pos_label: Label = get_node_or_null("../Position") as Label
@onready var time_label: Label = get_node_or_null("../Time") as Label
@onready var speed_label: Label = get_node_or_null("../Speed") as Label
@onready var countdown_label: Label = get_node_or_null("../Countdown") as Label
@onready var message_label: Label = get_node_or_null("../Message") as Label

var player_movement: RaceMovementComponent = null
var message_timer := 0.0
var go_timer := 0.0

func _ready() -> void:
    SignalBus.race_countdown_changed.connect(_on_race_countdown_changed)
    SignalBus.race_started.connect(_on_race_started)
    SignalBus.race_time_changed.connect(_on_race_time_changed)
    SignalBus.racer_lap_completed.connect(_on_racer_lap_completed)
    SignalBus.racer_position_changed.connect(_on_racer_position_changed)
    SignalBus.racer_finished.connect(_on_racer_finished)
    SignalBus.show_message.connect(_on_show_message)

func bind(player_ref: RaceMovementComponent) -> void:
    player_movement = player_ref
    set_lap(1, RaceLevelData.TOTAL_LAPS)
    set_position(
        player_movement.position if player_movement != null else 1,
        RaceLevelData.RACER_COUNT
    )
    set_time(0.0, 0.0, -1.0)

func _exit_tree() -> void:
    if SignalBus.race_countdown_changed.is_connected(_on_race_countdown_changed):
        SignalBus.race_countdown_changed.disconnect(_on_race_countdown_changed)
    if SignalBus.race_started.is_connected(_on_race_started):
        SignalBus.race_started.disconnect(_on_race_started)
    if SignalBus.race_time_changed.is_connected(_on_race_time_changed):
        SignalBus.race_time_changed.disconnect(_on_race_time_changed)
    if SignalBus.racer_lap_completed.is_connected(_on_racer_lap_completed):
        SignalBus.racer_lap_completed.disconnect(_on_racer_lap_completed)
    if SignalBus.racer_position_changed.is_connected(_on_racer_position_changed):
        SignalBus.racer_position_changed.disconnect(_on_racer_position_changed)
    if SignalBus.racer_finished.is_connected(_on_racer_finished):
        SignalBus.racer_finished.disconnect(_on_racer_finished)
    if SignalBus.show_message.is_connected(_on_show_message):
        SignalBus.show_message.disconnect(_on_show_message)

func _process(delta: float) -> void:
    if player_movement != null:
        var kmh := int(round(
            clampf(
                player_movement.speed / RaceLevelData.PLAYER_MAX_SPEED,
                0.0,
                1.0
            ) * 100.0
        ))
        set_speed(kmh)

        var sp := player_movement.speed
        var gear := 1
        if sp > 26.0:
            gear = 6
        elif sp > 22.0:
            gear = 5
        elif sp > 18.0:
            gear = 4
        elif sp > 12.0:
            gear = 3
        elif sp > 6.0:
            gear = 2
        var gear_node := get_node_or_null("../Gear") as Label
        if gear_node != null:
            gear_node.text = str(gear)

    if go_timer > 0.0:
        go_timer -= delta
        if go_timer <= 0.0:
            hide_countdown()

    if message_timer > 0.0:
        message_timer -= delta
        if message_timer <= 0.0 and message_label != null:
            message_label.text = ""

func _on_race_countdown_changed(value: int) -> void:
    if value > 0:
        show_countdown(str(value))

func _on_race_started() -> void:
    show_countdown("GO!")
    go_timer = 0.45

func _on_race_time_changed(race_time: float, lap_time: float, best_lap: float) -> void:
    set_time(race_time, lap_time, best_lap)

func _on_racer_lap_completed(
        racer: Node,
        _lap_time: float,
        _best_time: float
) -> void:
    if player_movement == null or racer != player_movement.get_parent():
        return
    set_lap(
        mini(player_movement.lap + 1, RaceLevelData.TOTAL_LAPS),
        RaceLevelData.TOTAL_LAPS
    )

func _on_racer_position_changed(racer: Node, current_position: int) -> void:
    if player_movement == null or racer != player_movement.get_parent():
        return
    set_position(current_position, RaceLevelData.RACER_COUNT)

func _on_racer_finished(racer: Node, _position: int) -> void:
    if player_movement == null or racer != player_movement.get_parent():
        return
    set_lap(RaceLevelData.TOTAL_LAPS, RaceLevelData.TOTAL_LAPS)
    show_countdown("ФИНИШ!")
    go_timer = 1.2

func _on_show_message(text: String, duration: float) -> void:
    if message_label == null:
        return
    message_label.text = text
    message_timer = maxf(duration, 0.0)

func set_lap(lap: int, total: int) -> void:
    if lap_label:
        lap_label.text = "КРУГ %d / %d" % [lap, total]

func set_position(pos: int, total: int) -> void:
    if pos_label:
        pos_label.text = "МЕСТО %d / %d" % [pos, total]

func set_time(race: float, _last_lap: float, best: float) -> void:
    if time_label:
        time_label.text = "ВРЕМЯ %s   ЛУЧШИЙ %s" % [
            RaceMath.format_time(race),
            RaceMath.format_time(best)
        ]

func set_speed(kmh: int) -> void:
    if speed_label:
        speed_label.text = "%d КМ/Ч" % kmh

func show_countdown(text: String) -> void:
    if countdown_label:
        countdown_label.text = text
        countdown_label.visible = true

func hide_countdown() -> void:
    if countdown_label:
        countdown_label.visible = false
