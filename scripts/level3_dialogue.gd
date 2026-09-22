extends Control
class_name Level3Dialogue

signal finished

@onready var panel: Panel = $Panel
@onready var speaker_label: Label = $Panel/Speaker
@onready var text_label: Label = $Panel/Text
@onready var prompt_label: Label = $Panel/Prompt

var _lines: Array[Dictionary] = []
var _index: int = -1
var _active: bool = false

func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP

func start_dialogue(lines: Array[Dictionary]) -> void:
    _lines = lines.duplicate(true)
    _index = -1
    _active = not _lines.is_empty()
    visible = _active
    if _active:
        _advance()

func advance() -> void:
    if not _active:
        return
    if _index + 1 >= _lines.size():
        _finish()
        return
    _advance()

func _advance() -> void:
    _index += 1
    var entry: Dictionary = _lines[_index]
    speaker_label.text = String(entry.get("speaker", ""))
    text_label.text = String(entry.get("text", ""))
    prompt_label.text = "ТАПНИТЕ, ЧТОБЫ ПРОДОЛЖИТЬ"

func _finish() -> void:
    _active = false
    visible = false
    finished.emit()

func is_active() -> bool:
    return _active

func _gui_input(event: InputEvent) -> void:
    if not _active:
        return
    if event is InputEventScreenTouch and event.pressed:
        advance()
        accept_event()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        advance()
        accept_event()

func _unhandled_input(event: InputEvent) -> void:
    if not _active:
        return
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
            advance()
