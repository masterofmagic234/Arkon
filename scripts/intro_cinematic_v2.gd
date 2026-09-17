extends Control

# Anime intro: room artwork stays as the master background; characters are
# separate layers so the scene can breathe and Darina can enter naturally.
const INTRO_DURATION := 14.0
const ZOOM_AMOUNT := 0.035
const PAN_AMOUNT := Vector2(-10.0, -5.0)
const CAROLINA_BREATH := 0.012

var elapsed := 0.0
var finished := false
var darina_start := Vector2(1260.0, 360.0)
var darina_rest := Vector2(1110.0, 360.0)
var carolina_base := Vector2(275.0, 515.0)

@onready var room: TextureRect = $Room
@onready var carolina: Sprite2D = $Carolina
@onready var darina: Sprite2D = $Darina
@onready var dialogue: Panel = $Dialogue
@onready var speaker: Label = $Dialogue/Speaker
@onready var text_label: Label = $Dialogue/Text
@onready var fade: ColorRect = $Fade

func _ready() -> void:
    $Title.visible = false
    $Subtitle.visible = false
    dialogue.visible = false
    $Prompt.visible = false

    room.pivot_offset = Vector2(640.0, 360.0)
    room.scale = Vector2.ONE
    room.position = Vector2.ZERO

    carolina.position = carolina_base
    carolina.modulate = Color(1, 1, 1, 0)
    darina.position = darina_start
    darina.modulate = Color(1, 1, 1, 0)

    fade.visible = true
    fade.modulate.a = 1.0

    var intro := create_tween()
    intro.tween_property(fade, "modulate:a", 0.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    intro.parallel().tween_property(carolina, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
    if finished:
        return

    elapsed += delta

    var progress := clamp(elapsed / INTRO_DURATION, 0.0, 1.0)
    var zoom := 1.0 + progress * ZOOM_AMOUNT
    room.scale = Vector2(zoom, zoom)
    room.position = PAN_AMOUNT * progress

    # Very subtle breathing keeps the sleeping character alive without turning
    # the intro into a cartoon loop.
    var breathing := sin(elapsed * 1.8) * CAROLINA_BREATH
    carolina.scale = Vector2(1.0, 1.0 + breathing)

    # Darina appears in the doorway after the quiet establishing beat.
    if elapsed < 1.8:
        darina.modulate.a = 0.0
    elif elapsed < 2.8:
        var p := clamp((elapsed - 1.8) / 1.0, 0.0, 1.0)
        p = p * p * (3.0 - 2.0 * p)
        darina.position = darina_start.lerp(darina_rest, p)
        darina.modulate.a = p
    else:
        darina.position = darina_rest
        darina.modulate.a = 1.0

    # Darina's line, then Carolina's irritated answer.
    if elapsed >= 2.5 and elapsed < 7.5:
        dialogue.visible = true
        dialogue.modulate.a = clamp((elapsed - 2.5) / 0.35, 0.0, 1.0)
        speaker.text = "ДАРИНА"
        text_label.text = "Оййй...\nА нам, кстати, поделку на завтра задали.........."
    elif elapsed >= 7.5 and elapsed < 11.5:
        dialogue.visible = true
        dialogue.modulate.a = 1.0
        speaker.text = "КАРОЛИНА"
        text_label.text = "...Ладно. Где эти жёлуди?"
    elif elapsed >= 11.5:
        dialogue.visible = false
        darina.modulate.a = max(0.0, 1.0 - (elapsed - 11.5) / 0.7)

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
