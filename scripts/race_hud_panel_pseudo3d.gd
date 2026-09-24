extends Node

const RaceMath = preload("res://scripts/race_math.gd")

@onready var speed_label: Label = get_node_or_null("../Panel/Speed")
@onready var gear_label: Label = get_node_or_null("../Panel/Gear")
@onready var lap_label: Label = get_node_or_null("../Panel/Lap")
@onready var pos_label: Label = get_node_or_null("../Panel/Pos")
@onready var time_label: Label = get_node_or_null("../Panel/Time")
@onready var best_label: Label = get_node_or_null("../Panel/Best")
@onready var countdown_label: Label = get_node_or_null("../Panel/Countdown")

var race_state = null
var player_car = null

func bind(state, player_ref) -> void:
    race_state = state
    player_car = player_ref

func set_lap(lap: int, total: int) -> void:
    if lap_label:
        lap_label.text = "%d/%d" % [lap, total]

func set_position(pos: int, total: int) -> void:
    if pos_label:
        pos_label.text = "%d/%d" % [pos, total]

func set_time(race: float, last: float, best: float) -> void:
    if time_label:
        time_label.text = RaceMath.format_time(race)
    if best_label:
        best_label.text = RaceMath.format_time(best) if best > 0.0 else "--:--.--"

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

func _process(_delta: float) -> void:
    if race_state == null or player_car == null:
        return
    # Oka-scale speedometer: 100 is the top of the current physics range
    # and should already feel completely insane.
    var kmh: int = int(round(clampf(player_car.speed / 32.0, 0.0, 1.0) * 100.0))
    speed_label.text = "%d" % kmh
    var sp: float = player_car.speed
    var g: int = 1
    if sp > 26.0: g = 6
    elif sp > 22.0: g = 5
    elif sp > 18.0: g = 4
    elif sp > 12.0: g = 3
    elif sp > 6.0: g = 2
    gear_label.text = str(g)
    # RaceController owns lap/position/time/best-lap display. Keeping those
    # assignments out of _process() prevents the total race timer from being
    # replaced by the current lap timer every frame.
    if not race_state.race_started:
        var n: int = int(ceil(race_state.countdown))
        countdown_label.text = str(n) if n > 0 else "GO!"
        countdown_label.visible = true
    else:
        countdown_label.visible = false
