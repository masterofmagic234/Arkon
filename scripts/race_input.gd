extends RefCounted

# Touch input adapter for Level 2.
# Keeps UI/touch state outside the race controller and exposes one neutral
# steer/throttle/brake snapshot to gameplay.

const JoystickMath = preload("res://scripts/joystick_math.gd")

var joystick: Panel
var knob: Panel
var gas_button: Button
var brake_button: Button

var joystick_touch_id: int = -1
var mouse_joystick_active: bool = false
var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0

func setup(joystick_node: Panel, knob_node: Panel, gas_node: Button, brake_node: Button) -> void:
    joystick = joystick_node
    knob = knob_node
    gas_button = gas_node
    brake_button = brake_node

    if joystick != null:
        knob.position = joystick.size * 0.5 - knob.size * 0.5
        joystick.gui_input.connect(_on_joystick_gui_input)
    if gas_button != null:
        gas_button.button_down.connect(_on_gas_down)
        gas_button.button_up.connect(_on_gas_up)
    if brake_button != null:
        brake_button.button_down.connect(_on_brake_down)
        brake_button.button_up.connect(_on_brake_up)

func read() -> Dictionary:
    # Keyboard remains supported as a desktop fallback; touch values take
    # precedence while a touch control is actively held.
    var keyboard_steer := Input.get_axis("race_left", "race_right")
    var keyboard_throttle := 1.0 if Input.is_action_pressed("race_accel") else 0.0
    var keyboard_brake := 1.0 if Input.is_action_pressed("race_brake") else 0.0

    return {
        "steer": steer if joystick_touch_id != -1 or mouse_joystick_active else keyboard_steer,
        "throttle": maxf(throttle, keyboard_throttle),
        "brake": maxf(brake, keyboard_brake),
    }

func stop() -> void:
    steer = 0.0
    throttle = 0.0
    brake = 0.0
    joystick_touch_id = -1
    mouse_joystick_active = false
    _reset_joystick()

func _on_gas_down() -> void:
    throttle = 1.0

func _on_gas_up() -> void:
    throttle = 0.0

func _on_brake_down() -> void:
    brake = 1.0

func _on_brake_up() -> void:
    brake = 0.0

func _on_joystick_gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            joystick_touch_id = event.index
            _update_joystick(event.position)
            joystick.accept_event()
        elif event.index == joystick_touch_id:
            joystick_touch_id = -1
            steer = 0.0
            _reset_joystick()
            joystick.accept_event()
    elif event is InputEventScreenDrag and event.index == joystick_touch_id:
        _update_joystick(event.position)
        joystick.accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            mouse_joystick_active = true
            _update_joystick(event.position)
            joystick.accept_event()
        elif mouse_joystick_active:
            mouse_joystick_active = false
            steer = 0.0
            _reset_joystick()
            joystick.accept_event()
    elif event is InputEventMouseMotion and mouse_joystick_active:
        _update_joystick(event.position)
        joystick.accept_event()

func _update_joystick(position: Vector2) -> void:
    if joystick == null or knob == null:
        return
    var center := joystick.size * 0.5
    var delta := JoystickMath.clamped_delta(position, center, 88.0)
    var axis := JoystickMath.axis_from_delta(delta, 88.0)
    steer = clampf(axis.x, -1.0, 1.0)
    knob.position = center - knob.size * 0.5 + delta

func _reset_joystick() -> void:
    if joystick != null and knob != null:
        knob.position = joystick.size * 0.5 - knob.size * 0.5
