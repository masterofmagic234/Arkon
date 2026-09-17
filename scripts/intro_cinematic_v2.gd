extends Control

# Darina uses four extracted transparent poses from the original source sheet:
# peek -> toy -> sad -> happy.
const INTRO_DURATION: float = 17.0
const ZOOM_AMOUNT: float = 0.025
const PAN_AMOUNT: Vector2 = Vector2(-8.0, -4.0)
const PEEK_MASK_POSITION: Vector2 = Vector2(865.0, 130.0)

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

    # Only the actual character pixels are in this texture. The mask now
    # simply makes her emerge from the doorway rather than masking a door.
    peek_mask.position = PEEK_MASK_POSITION
    peek_mask.size = Vector2(150.0, 435.0)
    peek_mask.clip_contents = true
    darina_peek.position = Vector2(112.0, 300.0)

    # Full-body poses are kept large enough to read as characters, but leave
    # the dialogue box unobstructed.
    darina_toy.position = Vector2(1005.0, 390.0)
    darina_sad.position = Vector2(1005.0, 420.0)
    darina_happy.position = Vector2(1005.0, 420.0)
    darina_peek.scale = Vector2(0.72, 0.72)
    darina_toy.scale = Vector2(0.55, 0.55)
    darina_sad.scale = Vector2(0.55, 0.55)
    darina_happy.scale = Vector2(0.55, 0.55)
    for sprite in [darina_peek, darina_toy, darina_sad, darina_happy]:
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
    peek_mask.position = PEEK_MASK_POSITION + pan

    # 0.0-2.2: quiet establishing shot, door closed.
    if elapsed < 2.2:
        room_open.modulate.a = 0.0
    elif elapsed < 2.9:
        var door_p: float = clampf((elapsed - 2.2) / 0.7, 0.0, 1.0)
        door_p = door_p * door_p * (3.0 - 2.0 * door_p)
        room_open.modulate.a = door_p
    else:
        room_open.modulate.a = 1.0

    _set_alpha(darina_peek, 0.0)
    _set_alpha(darina_toy, 0.0)
    _set_alpha(darina_sad, 0.0)
    _set_alpha(darina_happy, 0.0)

    if elapsed < 3.0:
        pass
    elif elapsed < 5.0:
        # 1. Darina peeks from the doorway.
        var p: float = _smoothstep((elapsed - 3.0) / 2.0)
        darina_peek.position = Vector2(138.0, 300.0).lerp(Vector2(105.0, 300.0), p)
        _set_alpha(darina_peek, p)
    elif elapsed < 8.8:
        # 2. She enters the room carrying her toy.
        var p: float = _smoothstep((elapsed - 5.0) / 2.0)
        darina_toy.position = Vector2(1070.0, 405.0).lerp(Vector2(1005.0, 390.0), p)
        _set_alpha(darina_toy, 1.0)
    elif elapsed < 12.5:
        # 3. She becomes sad after remembering the homework.
        _set_alpha(darina_sad, 1.0)
    else:
        # 4. She becomes happy again when Carolina agrees to help.
        _set_alpha(darina_happy, 1.0)

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
