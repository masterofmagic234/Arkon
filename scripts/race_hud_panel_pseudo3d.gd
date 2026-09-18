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

func _process(_delta: float) -> void:
    if race_state == null or player_car == null:
        return
    speed_label.text = "%d" % int(player_car.speed * 8.0)
    var sp: float = player_car.speed
    var g: int = 1
    if sp > 26.0: g = 6
    elif sp > 22.0: g = 5
    elif sp > 18.0: g = 4
    elif sp > 12.0: g = 3
    elif sp > 6.0: g = 2
    gear_label.text = str(g)
    lap_label.text = "%d/%d" % [race_state.lap + 1, race_state.total_laps]
    pos_label.text = "%d/%d" % [race_state.position, race_state.racer_count]
    time_label.text = RaceMath.format_time(race_state.lap_time)
    best_label.text = RaceMath.format_time(race_state.best_lap) if race_state.best_lap > 0.0 else "--:--.--"
    if not race_state.race_started:
        var n: int = int(ceil(race_state.countdown))
        countdown_label.text = str(n) if n > 0 else "GO!"
        countdown_label.visible = true
    else:
        countdown_label.visible = false
