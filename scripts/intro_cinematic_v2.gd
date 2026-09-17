extends Control

# Darina is animated from the original six-pose source sheet:
# peek -> toy -> sad -> happy.
const INTRO_DURATION: float = 17.0
const ZOOM_AMOUNT: float = 0.025
const PAN_AMOUNT: Vector2 = Vector2(-8.0, -4.0)

var elapsed: float = 0.0
var finished: bool = false

@onready var room_closed: TextureRect = $RoomClosed
@onready var room_open: TextureRect = $RoomOpen
@onready var peek_mask: Control = $PeekMask
@onready var darina_peek: Sprite2D = $PeekMask/DarinaPeek
@onready var darina_toy: Sprite2D = $DarinaToy
@onready var darina_sad: Sprite2D = $DarinaSad
@onready var darina_happy: Sprite2D = $DarinaHappy
@onready var dialogue: Panel = $Dialogue
@onready var speaker: Label = $Dialogue/Speaker
@onready var text_label: Label = $Dialogue/Text
@onready var fade: ColorRect = $Fade

func _ready() -> void:
    $Title.visible = false
    $Subtitle.visible = false
    dialogue.visible = false
    $Prompt.visible = false

    room_closed.pivot_offset = Vector2(640.0, 360.0)
    room_open.pivot_offset = Vector2(640.0, 360.0)
    room_closed.scale = Vector2.ONE
    room_open.scale = Vector2.ONE
    room_closed.position = Vector2.ZERO
    room_open.position = Vector2.ZERO
    room_open.modulate.a = 0.0

    # The peek pose is clipped to the doorway side so she visibly comes from
    # behind the jamb rather than appearing beside the computer.
    peek_mask.position = Vector2(875.0, 135.0)
    peek_mask.size = Vector2(145.0, 430.0)
    peek_mask.clip_contents = true
    darina_peek.position = Vector2(128.0, 275.0)

    # Full-body poses share one consistent VN-style scale and baseline.
    darina_toy.position = Vector2(1035.0, 405.0)
    darina_sad.position = Vector2(1035.0, 435.0)
    darina_happy.position = Vector2(1035.0, 435.0)
    for sprite in [darina_peek, darina_toy, darina_sad, darina_happy]:
        sprite.scale = Vector2(0.65, 0.65)
        sprite.modulate.a = 0.0

    fade.visible = true
    fade.modulate.a = 1.0
    var intro: Tween = create_tween()
    intro.tween_property(fade, "modulate:a", 0.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
    if finished:
        return

    elapsed += delta

    var progress: float = clampf(elapsed / INTRO_DURATION, 0.0, 1.0)
    var zoom: float = 1.0 + progress * ZOOM_AMOUNT
    var pan: Vector2 = PAN_AMOUNT * progress
    room_closed.scale = Vector2(zoom, zoom)
    room_open.scale = Vector2(zoom, zoom)
    room_closed.position = pan
    room_open.position = pan
    peek_mask.position = Vector2(875.0, 135.0) + pan

    # 0.0-2.2: quiet establishing shot, door closed.
    if elapsed < 2.2:
        room_open.modulate.a = 0.0
    elif elapsed < 2.9:
        var door_p: float = clampf((elapsed - 2.2) / 0.7, 0.0, 1.0)
        door_p = door_p * door_p * (3.0 - 2.0 * door_p)
        room_open.modulate.a = door_p
    else:
        room_open.modulate.a = 1.0

    # Four clean character beats.
    _set_alpha(darina_peek, 0.0)
    _set_alpha(darina_toy, 0.0)
    _set_alpha(darina_sad, 0.0)
    _set_alpha(darina_happy, 0.0)

    if elapsed < 3.0:
        pass
    elif elapsed < 5.0:
        # Peek: slowly lean out of the doorway.
        var p: float = _smoothstep((elapsed - 3.0) / 2.0)
        darina_peek.position = Vector2(142.0, 275.0).lerp(Vector2(118.0, 275.0), p)
        _set_alpha(darina_peek, p)
    elif elapsed < 8.8:
        # Enter with the toy, moving from the doorway toward the room.
        var p: float = _smoothstep((elapsed - 5.0) / 2.0)
        darina_toy.position = Vector2(1065.0, 410.0).lerp(Vector2(1015.0, 405.0), p)
        _set_alpha(darina_toy, 1.0)
    elif elapsed < 12.5:
        # Sad pose: she has just remembered the homework.
        _set_alpha(darina_sad, 1.0)
    else:
        # Happy pose: emotional release before the game starts.
        _set_alpha(darina_happy, 1.0)

    # Dialogue follows the visual beats rather than appearing before Darina.
    if elapsed >= 4.4 and elapsed < 7.0:
        dialogue.visible = true
        dialogue.modulate.a = clampf((elapsed - 4.4) / 0.35, 0.0, 1.0)
        speaker.text = "ДАРИНА"
        text_label.text = "Оййй...\nА нам, кстати, поделку на завтра задали.........."
    elif elapsed >= 8.8 and elapsed < 11.4:
        dialogue.visible = true
        dialogue.modulate.a = 1.0
        speaker.text = "ДАРИНА"
        text_label.text = "А я уже хотела с игрушкой играть..."
    elif elapsed >= 11.4 and elapsed < 14.6:
        dialogue.visible = true
        dialogue.modulate.a = 1.0
        speaker.text = "КАРОЛИНА"
        text_label.text = "...Ладно. Сделаем эту поделку."
    elif elapsed >= 14.6 and elapsed < INTRO_DURATION:
        dialogue.visible = true
        dialogue.modulate.a = 1.0
        speaker.text = "ДАРИНА"
        text_label.text = "УРААА! А жёлуди потом найдём?"
    else:
        dialogue.visible = false

    if elapsed >= INTRO_DURATION:
        _start_game()

func _smoothstep(value: float) -> float:
    var p: float = clampf(value, 0.0, 1.0)
    return p * p * (3.0 - 2.0 * p)

func _set_alpha(sprite: Sprite2D, value: float) -> void:
    sprite.modulate.a = clampf(value, 0.0, 1.0)

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

    var outro: Tween = create_tween()
    outro.tween_property(fade, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    outro.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))
