extends Node

# Обёртка над HUD-лейблами Level 2.

@onready var lap_label: Label = get_node_or_null("../Lap")
@onready var pos_label: Label = get_node_or_null("../Position")
@onready var time_label: Label = get_node_or_null("../Time")
@onready var speed_label: Label = get_node_or_null("../Speed")
@onready var countdown_label: Label = get_node_or_null("../Countdown")

const RaceMath = preload("res://scripts/race_math.gd")

func set_lap(lap: int, total: int) -> void:
    if lap_label:
        lap_label.text = "КРУГ %d / %d" % [lap, total]

func set_position(pos: int, total: int) -> void:
    if pos_label:
        pos_label.text = "МЕСТО %d / %d" % [pos, total]

func set_time(race: float, _last_lap: float, best: float) -> void:
    if time_label:
        time_label.text = "ВРЕМЯ %s   ЛУЧШИЙ %s" % [RaceMath.format_time(race), RaceMath.format_time(best)]

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
