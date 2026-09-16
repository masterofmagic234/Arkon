extends Control

const INTRO_DURATION := 14.0
var elapsed := 0.0
var finished := false

@onready var room: TextureRect = $Room
@onready var dialogue: Panel = $Dialogue
@onready var fade: ColorRect = $Fade
@onready var prompt: Label = $Prompt

func _ready() -> void:
    dialogue.modulate.a = 0.0
    prompt.modulate.a = 0.0
    fade.color.a = 1.0
    var intro := create_tween()
    intro.tween_property(fade, "color:a", 0.0, 1.2)
    intro.parallel().tween_property(prompt, "modulate:a", 0.75, 1.0)

func _process(delta: float) -> void:
    if finished:
        return
    elapsed += delta
    var zoom := 1.0 + min(elapsed / INTRO_DURATION, 1.0) * 0.035
    room.scale = Vector2(zoom, zoom)
    room.position = Vector2(-640.0, -360.0) * (zoom - 1.0)
    if elapsed >= 4.0 and elapsed < 11.5:
        dialogue.modulate.a = clamp((elapsed - 4.0) / 0.7, 0.0, 1.0)
    elif elapsed >= 11.5:
        dialogue.modulate.a = 0.0
    if elapsed >= INTRO_DURATION:
        _start_game()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed and elapsed > 1.5:
        _start_game()
    elif event is InputEventMouseButton and event.pressed and elapsed > 1.5:
        _start_game()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _start_game()

func _start_game() -> void:
    if finished:
        return
    finished = true
    var tween := create_tween()
    tween.tween_property(fade, "color:a", 1.0, 0.9)
    tween.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))
