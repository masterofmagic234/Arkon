extends Control

# Cinematic presentation for the final anime intro artwork.
# The artwork is the source of truth; this layer adds only camera movement,
# fades, and the transition into Level 1.
const INTRO_DURATION := 14.0
const ZOOM_AMOUNT := 0.035
const PAN_AMOUNT := Vector2(-10.0, -5.0)

var elapsed := 0.0
var finished := false

@onready var room: TextureRect = $Room
@onready var fade: ColorRect = $Fade

func _ready() -> void:
    $Title.visible = false
    $Subtitle.visible = false
    $Dialogue.visible = false
    $Prompt.visible = false

    room.pivot_offset = Vector2(640.0, 360.0)
    room.scale = Vector2.ONE
    room.position = Vector2.ZERO

    fade.visible = true
    fade.modulate.a = 1.0

    var intro := create_tween()
    intro.tween_property(fade, "modulate:a", 0.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
    if finished:
        return

    elapsed += delta
    var progress := clamp(elapsed / INTRO_DURATION, 0.0, 1.0)
    var zoom := 1.0 + progress * ZOOM_AMOUNT
    room.scale = Vector2(zoom, zoom)
    room.position = PAN_AMOUNT * progress

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
    outro.tween_property(fade, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    outro.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))
