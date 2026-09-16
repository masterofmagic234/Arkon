extends Control

const INTRO_DURATION := 14.0
var elapsed := 0.0
var finished := false

@onready var room = $Room
@onready var dialogue = $Dialogue
@onready var speaker = $Dialogue/Speaker
@onready var text_label = $Dialogue/Text
@onready var fade = $Fade
@onready var prompt = $Prompt

func _ready() -> void:
    dialogue.visible = false
    prompt.visible = true
    prompt.modulate.a = 0.0
    fade.color = Color(0, 0, 0, 1)

    var intro_tween := create_tween()
    intro_tween.tween_property(fade, "modulate:a", 0.0, 1.0)
    intro_tween.parallel().tween_property(prompt, "modulate:a", 0.75, 1.0)

func _process(delta: float) -> void:
    if finished:
        return

    elapsed += delta

    var zoom := 1.0 + min(elapsed / INTRO_DURATION, 1.0) * 0.025
    room.scale = Vector2(zoom, zoom)
    room.position = Vector2(-640.0, -360.0) * (zoom - 1.0)

    if elapsed >= 2.5 and elapsed < 7.5:
        dialogue.visible = true
        speaker.text = "ДАРИНА"
        text_label.text = "Оййй... а нам, кстати, поделку на завтра задали.........."
        dialogue.modulate.a = clamp((elapsed - 2.5) / 0.5, 0.0, 1.0)
    elif elapsed >= 7.5 and elapsed < 11.5:
        dialogue.visible = true
        dialogue.modulate.a = 1.0
        speaker.text = "КАРОЛИНА"
        text_label.text = "...Ладно. Где эти жёлуди?"
    elif elapsed >= 11.5:
        dialogue.visible = false
        prompt.visible = false

    if elapsed >= INTRO_DURATION:
        _start_game()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed and elapsed > 1.0:
        _start_game()
    elif event is InputEventMouseButton and event.pressed and elapsed > 1.0:
        _start_game()
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _start_game()

func _start_game() -> void:
    if finished:
        return
    finished = true
    fade.visible = true
    fade.modulate.a = 0.0
    var outro := create_tween()
    outro.tween_property(fade, "modulate:a", 1.0, 0.8)
    outro.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))
