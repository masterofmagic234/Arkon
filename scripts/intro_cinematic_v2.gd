extends Control

# Intro uses two matching master backgrounds:
# 1) the perfect closed-door room
# 2) the same room with the door slightly open
# Darina is layered into a clipped doorway region so she physically reads
# as someone peeking out from behind the door jamb.
const INTRO_DURATION: float = 14.0
const ZOOM_AMOUNT: float = 0.025
const PAN_AMOUNT: Vector2 = Vector2(-8.0, -4.0)

var elapsed: float = 0.0
var finished: bool = false

# Darina's coordinates are local to DarinaMask. The mask itself is positioned
# over the dark doorway opening, so everything outside that opening is hidden.
var darina_start: Vector2 = Vector2(105.0, 255.0)
var darina_rest: Vector2 = Vector2(60.0, 255.0)

@onready var room_closed: TextureRect = $RoomClosed
@onready var room_open: TextureRect = $RoomOpen
@onready var darina_mask: Control = $DarinaMask
@onready var darina: Sprite2D = $DarinaMask/Darina
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
    darina.position = darina_start
    darina.modulate.a = 0.0

    fade.visible = true
    fade.modulate.a = 1.0

    var intro: Tween = create_tween()
    intro.tween_property(fade, "modulate:a", 0.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
    if finished:
        return

    elapsed += delta

    # Very subtle camera drift keeps the illustrated room alive without
    # changing the composition.
    var progress: float = clampf(elapsed / INTRO_DURATION, 0.0, 1.0)
    var zoom: float = 1.0 + progress * ZOOM_AMOUNT
    var pan: Vector2 = PAN_AMOUNT * progress
    room_closed.scale = Vector2(zoom, zoom)
    room_open.scale = Vector2(zoom, zoom)
    room_closed.position = pan
    room_open.position = pan
    # Keep the doorway mask aligned with the drifting background.
    darina_mask.position = pan

    # Establishing shot: Carolina sleeps with the door closed.
    # At ~2.2s the matching open-door artwork crossfades in.
    if elapsed < 2.15:
        room_open.modulate.a = 0.0
        darina.modulate.a = 0.0
    elif elapsed < 2.75:
        var door_p: float = clampf((elapsed - 2.15) / 0.60, 0.0, 1.0)
        door_p = door_p * door_p * (3.0 - 2.0 * door_p)
        room_open.modulate.a = door_p
        darina.modulate.a = 0.0
    else:
        room_open.modulate.a = 1.0

    # Darina emerges from inside the dark doorway. The mask prevents her
    # body from appearing over the wall/desk area to the right of the jamb.
    if elapsed < 3.0:
        darina.modulate.a = 0.0
    elif elapsed < 4.0:
        var p: float = clampf((elapsed - 3.0) / 1.0, 0.0, 1.0)
        p = p * p * (3.0 - 2.0 * p)
        darina.position = darina_start.lerp(darina_rest, p)
        darina.modulate.a = p
    elif elapsed < 11.0:
        darina.position = darina_rest
        darina.modulate.a = 1.0
    else:
        darina.modulate.a = clampf(1.0 - (elapsed - 11.0) / 0.7, 0.0, 1.0)

    # Dialogue appears after Darina has visibly entered the doorway.
    if elapsed >= 3.8 and elapsed < 8.0:
        dialogue.visible = true
        dialogue.modulate.a = clampf((elapsed - 3.8) / 0.35, 0.0, 1.0)
        speaker.text = "ДАРИНА"
        text_label.text = "Оййй...\nА нам, кстати, поделку на завтра задали.........."
    elif elapsed >= 8.0 and elapsed < 11.0:
        dialogue.visible = true
        dialogue.modulate.a = 1.0
        speaker.text = "КАРОЛИНА"
        text_label.text = "...Ладно. Где эти жёлуди?"
    else:
        dialogue.visible = false

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

    var outro: Tween = create_tween()
    outro.tween_property(fade, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    outro.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))
