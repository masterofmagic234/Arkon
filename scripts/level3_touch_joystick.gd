extends Control
class_name Level3TouchJoystick

signal vector_changed(value: Vector2)
signal released

@export var active_radius: float = 72.0

var _pointer_id: int = -1000
var _active: bool = false
var _value: Vector2 = Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and not _active:
            _pointer_id = event.index
            _active = true
            _update_from_position(event.position)
            accept_event()
        elif not event.pressed and _active and event.index == _pointer_id:
            _release()
            accept_event()
        return

    if event is InputEventScreenDrag and _active and event.index == _pointer_id:
        _update_from_position(event.position)
        accept_event()
        return

    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed and not _active:
                _pointer_id = -1
                _active = true
                _update_from_position(event.position)
                accept_event()
            elif not event.pressed and _active and _pointer_id == -1:
                _release()
                accept_event()
        return

    if event is InputEventMouseMotion and _active and _pointer_id == -1:
        _update_from_position(event.position)
        accept_event()

func _update_from_position(local_position: Vector2) -> void:
    var center := size * 0.5
    var offset := local_position - center
    var safe_radius := maxf(active_radius, 1.0)
    _value = offset.limit_length(safe_radius) / safe_radius
    vector_changed.emit(_value)
    queue_redraw()

func _release() -> void:
    _active = false
    _pointer_id = -1000
    _value = Vector2.ZERO
    vector_changed.emit(_value)
    released.emit()
    queue_redraw()

func get_value() -> Vector2:
    return _value

func _draw() -> void:
    var center := size * 0.5
    draw_circle(center, active_radius, Color(0.04, 0.05, 0.07, 0.58))
    draw_arc(center, active_radius, 0.0, TAU, 48, Color(0.75, 0.82, 0.90, 0.48), 2.0)
    var knob_center := center + _value * active_radius
    draw_circle(knob_center, active_radius * 0.32, Color(0.85, 0.90, 0.96, 0.82))
    draw_circle(knob_center, active_radius * 0.32, Color(0.15, 0.18, 0.24, 1.0), false, 2.0)
