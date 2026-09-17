extends Control

# ACORN HUNTER intro cinematic.
# The timeline is data-driven: each beat describes the visual/dialogue state
# that becomes active when elapsed crosses its start_time.
const INTRO_DURATION: float = 17.0
const ZOOM_AMOUNT: float = 0.025
const PAN_AMOUNT: Vector2 = Vector2(-8.0, -4.0)

const DIALOGUE_DATA: Array[Dictionary] = [
    {
        "speaker": "ДАРИНА",
        "text": "Оййй...\nА нам, кстати, поделку на завтра задали..........",
        "start_time": 4.4,
        "end_time": 7.0,
    },
    {
        "speaker": "ДАРИНА",
        "text": "А я уже хотела с игрушкой играть...",
        "start_time": 8.8,
        "end_time": 11.4,
    },
    {
        "speaker": "КАРОЛИНА",
        "text": "...Ладно. Сделаем эту поделку.",
        "start_time": 11.4,
        "end_time": 14.6,
    },
    {
        "speaker": "ДАРИНА",
        "text": "УРААА! А жёлуди потом найдём?",
        "start_time": 14.6,
        "end_time": INTRO_DURATION,
    },
]

# Every visual/dialogue state change is represented once here. Overlapping
# concerns are split at their boundaries, so _process() only advances through
# this ordered list instead of repeatedly evaluating a collection of timers.
const TIMELINE: Array[Dictionary] = [
    {"start_time": 0.0, "end_time": 2.2, "sprite": "none", "dialogue": -1, "title": true, "door": 0.0},
    {"start_time": 2.2, "end_time": 2.9, "sprite": "none", "dialogue": -1, "title": false, "door": 1.0},
    {"start_time": 2.9, "end_time": 3.0, "sprite": "none", "dialogue": -1, "title": false, "door": 1.0},
    {"start_time": 3.0, "end_time": 4.4, "sprite": "peek", "dialogue": -1, "title": false, "door": 1.0},
    {"start_time": 4.4, "end_time": 5.0, "sprite": "peek", "dialogue": 0, "title": false, "door": 1.0},
    {"start_time": 5.0, "end_time": 7.0, "sprite": "toy", "dialogue": 0, "title": false, "door": 1.0},
    {"start_time": 7.0, "end_time": 8.8, "sprite": "toy", "dialogue": -1, "title": false, "door": 1.0},
    {"start_time": 8.8, "end_time": 11.4, "sprite": "sad", "dialogue": 1, "title": false, "door": 1.0},
    {"start_time": 11.4, "end_time": 14.6, "sprite": "happy", "dialogue": 2, "title": false, "door": 1.0},
    {"start_time": 14.6, "end_time": INTRO_DURATION, "sprite": "happy", "dialogue": 3, "title": false, "door": 1.0},
]

var elapsed: float = 0.0
var finished: bool = false
var current_beat_index: int = -1

@onready var room_closed: TextureRect = $RoomClosed
@onready var room_open: TextureRect = $RoomOpen
@onready var peek_mask: Control = $PeekMask
@onready var darina_peek: Sprite2D = $PeekMask/DarinaPeek
@onready var darina_toy: Sprite2D = $DarinaToy
@onready var darina_sad: Sprite2D = $DarinaSad
@onready var darina_happy: Sprite2D = $DarinaHappy
@onready var title: Label = $Title
@onready var subtitle: Label = $Subtitle
@onready var dialogue: Panel = $Dialogue
@onready var speaker: Label = $Dialogue/Speaker
@onready var text_label: Label = $Dialogue/Text
@onready var prompt: Label = $Prompt
@onready var fade: ColorRect = $Fade

func _ready() -> void:
    dialogue.visible = false
    prompt.visible = false
    title.visible = true
    subtitle.visible = true

    room_closed.pivot_offset = Vector2(640.0, 360.0)
    room_open.pivot_offset = Vector2(640.0, 360.0)
    room_closed.scale = Vector2.ONE
    room_open.scale = Vector2.ONE
    room_closed.position = Vector2.ZERO
    room_open.position = Vector2.ZERO
    room_open.modulate.a = 0.0

    _setup_responsive_darina_layout()

    for sprite in [darina_peek, darina_toy, darina_sad, darina_happy]:
        sprite.modulate.a = 0.0

    fade.visible = true
    fade.modulate.a = 1.0
    var intro: Tween = create_tween()
    intro.tween_property(fade, "modulate:a", 0.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

    _advance_timeline()

func _setup_responsive_darina_layout() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    var sx: float = viewport_size.x / 1280.0
    var sy: float = viewport_size.y / 720.0

    # PeekMask is anchored in the same proportional region as the original
    # 1280x720 doorway mask. Its size scales with the current viewport too.
    peek_mask.position = Vector2(viewport_size.x * 0.676, viewport_size.y * 0.181)
    peek_mask.size = Vector2(viewport_size.x * 0.117, viewport_size.y * 0.604)
    peek_mask.clip_contents = true

    # Sprite2D positions are viewport-relative rather than fixed screen pixels.
    darina_peek.position = Vector2(peek_mask.size.x * 0.773, peek_mask.size.y * 0.690)
    darina_toy.position = Vector2(viewport_size.x * 0.785, viewport_size.y * 0.542)
    darina_sad.position = Vector2(viewport_size.x * 0.785, viewport_size.y * 0.583)
    darina_happy.position = Vector2(viewport_size.x * 0.785, viewport_size.y * 0.583)

    # Preserve the intended visual scale relative to the 1280x720 design.
    var uniform_scale: float = minf(sx, sy)
    darina_peek.scale = Vector2.ONE * (0.72 * uniform_scale)
    darina_toy.scale = Vector2.ONE * (0.55 * uniform_scale)
    darina_sad.scale = Vector2.ONE * (0.55 * uniform_scale)
    darina_happy.scale = Vector2.ONE * (0.55 * uniform_scale)

func _process(delta: float) -> void:
    if finished:
        return

    elapsed += delta

    if elapsed >= INTRO_DURATION:
        elapsed = INTRO_DURATION
        _advance_timeline()
        _start_game()
        return

    _advance_timeline()
    _update_visual_interpolation()
    prompt.visible = elapsed > 1.0

    var progress: float = clampf(elapsed / INTRO_DURATION, 0.0, 1.0)
    var zoom: float = 1.0 + progress * ZOOM_AMOUNT
    var pan: Vector2 = PAN_AMOUNT * progress
    room_closed.scale = Vector2(zoom, zoom)
    room_open.scale = Vector2(zoom, zoom)
    room_closed.position = pan
    room_open.position = pan
    # The mask follows the same camera pan without losing its responsive base.
    var viewport_size: Vector2 = get_viewport_rect().size
    peek_mask.position = Vector2(viewport_size.x * 0.676, viewport_size.y * 0.181) + pan

func _advance_timeline() -> void:
    var next_index: int = current_beat_index + 1
    while next_index < TIMELINE.size() and elapsed >= float(TIMELINE[next_index]["start_time"]):
        current_beat_index = next_index
        _enter_beat(TIMELINE[current_beat_index])
        next_index += 1

func _enter_beat(beat: Dictionary) -> void:
    var sprite_name: String = String(beat["sprite"])
    _set_sprite_state(sprite_name)

    var dialogue_index: int = int(beat["dialogue"])
    if dialogue_index >= 0:
        _show_dialogue(dialogue_index)
    else:
        dialogue.visible = false

    title.visible = bool(beat["title"])
    subtitle.visible = bool(beat["title"])

    # Door state is set on beat entry; the 2.2-2.9 beat interpolates it below.
    if float(beat["start_time"]) >= 2.9:
        room_open.modulate.a = 1.0
    elif float(beat["start_time"]) < 2.2:
        room_open.modulate.a = 0.0

func _set_sprite_state(sprite_name: String) -> void:
    _set_alpha(darina_peek, 0.0)
    _set_alpha(darina_toy, 0.0)
    _set_alpha(darina_sad, 0.0)
    _set_alpha(darina_happy, 0.0)

    match sprite_name:
        "peek":
            _set_alpha(darina_peek, 0.0)
        "toy":
            _set_alpha(darina_toy, 1.0)
        "sad":
            _set_alpha(darina_sad, 1.0)
        "happy":
            _set_alpha(darina_happy, 1.0)

func _show_dialogue(dialogue_index: int) -> void:
    var data: Dictionary = DIALOGUE_DATA[dialogue_index]
    dialogue.visible = true
    dialogue.modulate.a = 1.0
    speaker.text = String(data["speaker"])
    text_label.text = String(data["text"])

func _update_visual_interpolation() -> void:
    if current_beat_index < 0:
        return

    var beat: Dictionary = TIMELINE[current_beat_index]
    var start_time: float = float(beat["start_time"])
    var end_time: float = float(beat["end_time"])
    var beat_progress: float = 1.0
    if end_time > start_time:
        beat_progress = clampf((elapsed - start_time) / (end_time - start_time), 0.0, 1.0)

    # Title/subtitle establish the scene first, then fade away before Darina.
    if start_time < 2.2 and end_time <= 2.2:
        var title_fade: float = _smoothstep(elapsed / 2.2)
        var title_alpha: float = clampf(title_fade / 0.55, 0.0, 1.0)
        if elapsed > 1.45:
            title_alpha = 1.0 - _smoothstep((elapsed - 1.45) / 0.75)
        title.modulate.a = title_alpha
        subtitle.modulate.a = title_alpha

    # Closed -> open room crossfade.
    if start_time == 2.2:
        room_open.modulate.a = _smoothstep(beat_progress)
    elif start_time >= 2.9:
        room_open.modulate.a = 1.0

    match String(beat["sprite"]):
        "peek":
            if start_time == 3.0:
                var p: float = _smoothstep(beat_progress)
                darina_peek.position = Vector2(get_viewport_rect().size.x * 0.814, get_viewport_rect().size.y * 0.417).lerp(
                    Vector2(get_viewport_rect().size.x * 0.773, get_viewport_rect().size.y * 0.417), p
                )
                _set_alpha(darina_peek, p)
            else:
                _set_alpha(darina_peek, 1.0)
        "toy":
            if start_time == 5.0:
                var p: float = _smoothstep(beat_progress)
                darina_toy.position = Vector2(get_viewport_rect().size.x * 0.836, get_viewport_rect().size.y * 0.563).lerp(
                    Vector2(get_viewport_rect().size.x * 0.785, get_viewport_rect().size.y * 0.542), p
                )
        "sad":
            _set_alpha(darina_sad, 1.0)
        "happy":
            _set_alpha(darina_happy, 1.0)

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
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and elapsed > 1.0:
        _start_game()

func _start_game() -> void:
    if finished:
        return
    finished = true
    prompt.visible = false
    fade.visible = true
    fade.modulate.a = 0.0

    var outro: Tween = create_tween()
    outro.tween_property(fade, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    outro.tween_callback(func(): get_tree().change_scene_to_file("res://game.tscn"))
