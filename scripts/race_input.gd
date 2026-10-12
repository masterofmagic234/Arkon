extends RefCounted

# A pointer owns its control until release/cancel. Emulated mouse events must
# never release another finger's pedal.
var joystick: Panel
var knob: Panel
var gas_button: Button
var brake_button: Button
var joystick_touch_id := -1
var mouse_joystick_active := false
var steer := 0.0
var throttle := 0.0
var brake := 0.0
var pointers: Dictionary = {}

func setup(stick: Panel, thumb: Panel, gas: Button, brakes: Button) -> void:
    joystick=stick
    knob=thumb
    gas_button=gas
    brake_button=brakes
    for control in [joystick,knob,gas_button,brake_button]: control.mouse_filter=Control.MOUSE_FILTER_IGNORE
    gas_button.focus_mode=Control.FOCUS_NONE
    brake_button.focus_mode=Control.FOCUS_NONE
    _reset_joystick()

func handle_event(event: InputEvent) -> bool:
    var id := -2
    var position_ := Vector2.ZERO
    var pressed := false
    var released := false
    if event is InputEventScreenTouch:
        id=event.index
        position_=event.position
        pressed=event.pressed and not event.canceled
        released=not pressed
    elif event is InputEventScreenDrag:
        id=event.index
        position_=event.position
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1:
        position_=event.position
        pressed=event.pressed
        released=not pressed
    elif event is InputEventMouseMotion and event.device!=-1: position_=event.position
    else: return false
    if released:
        if not pointers.has(id): return false
        _release(id)
        return true
    if pressed:
        if pointers.has(id): return true
        for role in [&"steer",&"gas",&"brake"]:
            var control := _control(role)
            if not control.visible or pointers.values().has(role) or not control.get_global_rect().has_point(position_): continue
            pointers[id]=role
            if role==&"steer":
                joystick_touch_id=id
                mouse_joystick_active=id==-2
                _update_joystick(position_)
            elif role==&"gas": throttle=1.0
            else: brake=1.0
            control.modulate=Color(1.25,1.25,1.16)
            return true
    elif pointers.has(id):
        var role: StringName=pointers[id]
        if role==&"steer": _update_joystick(position_)
        elif not _control(role).get_global_rect().has_point(position_): _release(id)
        return true
    return false

func _control(role: StringName) -> Control:
    return joystick if role==&"steer" else (gas_button if role==&"gas" else brake_button)

func _release(id: int) -> void:
    var role: StringName=pointers[id]
    _control(role).modulate=Color.WHITE
    pointers.erase(id)
    if role==&"steer":
        steer=0.0
        joystick_touch_id=-1
        mouse_joystick_active=false
        _reset_joystick()
    elif role==&"gas": throttle=0.0
    else: brake=0.0

func read() -> Dictionary:
    return {"steer":steer if joystick_touch_id!=-1 else Input.get_axis("race_left","race_right"),
        "throttle":maxf(throttle,Input.get_action_strength("race_accel")),
        "brake":maxf(brake,Input.get_action_strength("race_brake"))}

func stop() -> void:
    for id in pointers.keys(): _release(id)
    steer=0.0
    throttle=0.0
    brake=0.0
    for action in [&"race_left",&"race_right",&"race_accel",&"race_brake"]: Input.action_release(action)
    _reset_joystick()

func _update_joystick(at: Vector2) -> void:
    var center := joystick.size*0.5
    var radius := minf(center.x,center.y)-knob.size.x*0.35
    var offset := (at-joystick.global_position-center).limit_length(radius)
    var raw := clampf(offset.x/radius,-1.0,1.0)
    steer=signf(raw)*maxf(0.0,(absf(raw)-0.06)/0.94)
    knob.position=center-knob.size*0.5+offset

func _reset_joystick() -> void:
    if is_instance_valid(knob): knob.position=joystick.size*0.5-knob.size*0.5
