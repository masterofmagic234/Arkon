extends Node
class_name RaceHudPanelPseudo3D

const RaceMath = preload("res://scripts/race_math.gd")
const RaceLevelData = preload("res://scripts/race_level_data.gd")

@onready var speed_label: Label = get_node_or_null("../Panel/Speed") as Label
@onready var gear_label: Label = get_node_or_null("../Panel/Gear") as Label
@onready var lap_label: Label = get_node_or_null("../Panel/Lap") as Label
@onready var pos_label: Label = get_node_or_null("../Panel/Pos") as Label
@onready var time_label: Label = get_node_or_null("../Panel/Time") as Label
@onready var best_label: Label = get_node_or_null("../Panel/Best") as Label
@onready var countdown_label: Label = get_node_or_null("../Panel/Countdown") as Label
@onready var message_label: Label = get_node_or_null("../Message") as Label

var player_movement = null
var message_timer := 0.0
var go_timer := 0.0

func _ready() -> void:
    pass

func bind(player_ref) -> void:
    player_movement = player_ref
    set_lap(1, RaceLevelData.TOTAL_LAPS)
    set_position(
        player_movement.position if player_movement != null else 1,
        RaceLevelData.RACER_COUNT
    )
    set_time(0.0, 0.0, -1.0)


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

        var sp: float = float(player_movement.speed)
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
        if gear_label:
            gear_label.text = str(gear)

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
        lap_label.text = "%d/%d" % [lap, total]

func set_position(pos: int, total: int) -> void:
    if pos_label:
        pos_label.text = "%d/%d" % [pos, total]

func set_time(_race: float, _last: float, best: float) -> void:
    if time_label:
        time_label.text = RaceMath.format_time(_race)
    if best_label:
        best_label.text = RaceMath.format_time(best) if best >= 0.0 else "--:--.--"

func set_speed(kmh: int) -> void:
    if speed_label:
        speed_label.text = "%d" % kmh

func show_countdown(text: String) -> void:
    if countdown_label:
        countdown_label.text = text
        countdown_label.visible = true

func hide_countdown() -> void:
    if countdown_label:
        countdown_label.visible = false
