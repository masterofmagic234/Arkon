extends Control

const INTRO_DURATION: float = 14.0
const ZOOM_AMOUNT: float = 0.025
const PAN_AMOUNT: Vector2 = Vector2(-8.0, -4.0)

# Coordinates are in the 1280x720 logical scene. The actual doorway opening
# in the artwork is around x=995..1085. Keep the mask fixed there and move it
# only by the same tiny pan as the background.
const DOOR_MASK_POSITION: Vector2 = Vector2(990.0, 140.0)
const DOOR_MASK_SIZE: Vector2 = Vector2(100.0, 400.0)

var elapsed: float = 0.0
var finished: bool = false

# Local to DarinaMask. The sprite is intentionally mostly outside the mask so
# only the part actually inside the doorway can be seen.
var darina_start: Vector2 = Vector2(92.0, 255.0)
var darina_rest: Vector2 = Vector2(82.0, 255.0)

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

    # Explicit position/size is used instead of Control offsets. This avoids
    # the layout system resetting the doorway mask to the screen origin.
    darina_mask.position = DOOR_MASK_POSITION
    darina_mask.size = DOOR_MASK_SIZE
    darina_mask.clip_contents = true
    darina.position = darina_start
    darina.modulate.a = 0.0

    room_open.modulate.a = 0.0
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
    darina_mask.position = DOOR_MASK_POSITION + pan

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

    # First she is hidden in the dark hallway, then she leans through the
    # doorway. The mask makes the door jamb occlude the rest of her sprite.
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
