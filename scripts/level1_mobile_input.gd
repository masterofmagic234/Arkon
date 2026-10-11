extends CanvasLayer
class_name Level1MobileInput

const LevelData = preload("res://scripts/level_data.gd")
const JoystickMath = preload("res://scripts/joystick_math.gd")

const BASE_VIEWPORT_SIZE := Vector2(1280.0, 720.0)

@onready var top_panel: Panel = $Top
@onready var count_label: Label = $Count
@onready var carolina: TextureRect = $Carolina
@onready var hp_ammo_label: Label = $HPAmmo
@onready var mute_button: Button = $Mute
@onready var crosshair: Label = $Crosshair
@onready var hit_marker: Label = $HitMarker
@onready var message_label: Label = $Message
@onready var joystick: Panel = $Joystick
@onready var knob: Panel = $Joystick/Knob
@onready var fire_button: Button = $Fire
@onready var weapon: TextureRect = $Weapon
@onready var minimap: Control = $Minimap
@onready var mission: Panel = $Mission
@onready var player: Node = get_parent().get_node_or_null("Player")

var joystick_touch_id := -1
var ui_scale := 1.0
var look_touch_id := -1
var fire_held := false
var fire_touch_id := -1
var look_area: Control
var pause_button: Button
var pause_panel: Panel
var reticle: Control

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_park_ui()
    if not get_viewport().size_changed.is_connected(_layout_responsive_ui):
        get_viewport().size_changed.connect(_layout_responsive_ui)

    _layout_responsive_ui()
    PauseManager.pause_state_changed.connect(_on_pause_changed)

    if not joystick.gui_input.is_connected(_on_joystick_gui_input):
        joystick.gui_input.connect(_on_joystick_gui_input)

    if not fire_button.button_down.is_connected(_on_fire_button_down):
        fire_button.button_down.connect(_on_fire_button_down)

    if not fire_button.button_up.is_connected(_on_fire_button_up):
        fire_button.button_up.connect(_on_fire_button_up)
    fire_button.gui_input.connect(_on_fire_gui_input)

func _exit_tree() -> void:
    if get_viewport().size_changed.is_connected(_layout_responsive_ui):
        get_viewport().size_changed.disconnect(_layout_responsive_ui)

    _release_move_actions()
    if PauseManager.pause_state_changed.is_connected(_on_pause_changed):
        PauseManager.pause_state_changed.disconnect(_on_pause_changed)

func _on_fire_button_down() -> void:
    # Mobile fire is explicit. Do not synthesize the l1_fire InputMap action:
    # the project emulates mouse events from touch, and a touch on the movement
    # stick would otherwise look like a left mouse click.
    fire_held = true
    if player != null and player.has_method("request_fire"):
        player.request_fire()

func _on_fire_button_up() -> void:
    if fire_touch_id>=0: return
    fire_held = false

func _on_fire_gui_input(event: InputEvent) -> void:
    if PauseManager.is_paused: return
    if event is InputEventScreenTouch:
        if event.pressed and fire_touch_id == -1:
            fire_touch_id = event.index
            _on_fire_button_down()
        elif not event.pressed and event.index == fire_touch_id:
            fire_touch_id = -1
            _on_fire_button_up()
        fire_button.accept_event()

func _process(_delta: float) -> void:
    if fire_held and not PauseManager.is_paused and is_instance_valid(player):
        player.request_fire()

func _setup_park_ui() -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025,0.045,0.06,0.83)
    style.border_color = Color(0.65,0.51,0.29,0.45)
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    top_panel.add_theme_stylebox_override("panel",style)
    var title := $Top/Title as Label
    title.text = "ЛУННЫЙ ПАРК"
    title.add_theme_font_size_override("font_size",18)
    title.add_theme_color_override("font_color",Color(0.96,0.77,0.44))
    title.position = Vector2(16,10)
    var status := $Top/Status as Label
    status.position = Vector2(16,35)
    status.add_theme_font_size_override("font_size",14)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    count_label.add_theme_font_size_override("font_size",17)
    hp_ammo_label.add_theme_font_size_override("font_size",16)
    message_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
    message_label.add_theme_constant_override("shadow_offset_x",2)
    message_label.add_theme_constant_override("shadow_offset_y",2)
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    crosshair.visible = false
    reticle = Control.new()
    reticle.name = "ParkReticle"
    reticle.set_script(preload("res://scripts/level1_reticle.gd"))
    add_child(reticle)
    hit_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    look_area = Control.new()
    look_area.name = "LookArea"
    look_area.mouse_filter = Control.MOUSE_FILTER_STOP
    look_area.visible = OS.has_feature("mobile")
    add_child(look_area)
    move_child(look_area,0)
    look_area.gui_input.connect(_on_look_input)
    pause_button = Button.new()
    pause_button.name = "Pause"
    pause_button.text = "Ⅱ"
    pause_button.add_theme_font_size_override("font_size",22)
    add_child(pause_button)
    pause_button.pressed.connect(PauseManager.toggle)
    pause_panel = Panel.new()
    pause_panel.name = "PausePanel"
    pause_panel.add_theme_stylebox_override("panel",style)
    pause_panel.visible = false
    add_child(pause_panel)
    var heading := Label.new()
    heading.text = "ПАРК ПОДОЖДЁТ"
    heading.position = Vector2(24,25)
    heading.size = Vector2(332,48)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size",24)
    pause_panel.add_child(heading)
    for i in range(3):
        var b := Button.new()
        b.text = ["Продолжить","Начать заново","В меню"][i]
        b.position = Vector2(45,100+i*57)
        b.size = Vector2(290,44)
        pause_panel.add_child(b)
        if i == 0: b.pressed.connect(PauseManager.resume)
        elif i == 1: b.pressed.connect(func(): SceneFlow.go_to(&"level1"))
        else: b.pressed.connect(func(): SceneFlow.go_to(&"menu"))
    var retry := Button.new()
    retry.name = "Retry"
    retry.text = "Ещё попытка"
    retry.position = Vector2(30,315)
    retry.size = Vector2(260,45)
    mission.add_child(retry)
    retry.pressed.connect(func(): SceneFlow.go_to(&"level1"))
    var menu := $Mission/Menu as Button
    menu.position = Vector2(330,315)
    menu.size = Vector2(260,45)

func _on_pause_changed(paused: bool) -> void:
    pause_panel.visible = paused
    fire_held = false
    fire_touch_id = -1
    look_touch_id = -1
    joystick_touch_id = -1
    _release_move_actions()
    _reset_knob()
    if not OS.has_feature("mobile"):
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)

func _on_look_input(event: InputEvent) -> void:
    if PauseManager.is_paused: return
    if event is InputEventScreenTouch:
        if event.pressed and look_touch_id == -1:
            look_touch_id = event.index
        elif not event.pressed and look_touch_id == event.index:
            look_touch_id = -1
        look_area.accept_event()
    elif event is InputEventScreenDrag and event.index == look_touch_id:
        if is_instance_valid(player): player.handle_touch_look(event.relative)
        look_area.accept_event()

func _layout_responsive_ui() -> void:
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
        return

    ui_scale = clampf(
        minf(
            viewport_size.x / BASE_VIEWPORT_SIZE.x,
            viewport_size.y / BASE_VIEWPORT_SIZE.y
        ),
        0.72,
        1.35
    )
    var margin := clampf(
        minf(viewport_size.x, viewport_size.y) * 0.026,
        16.0,
        32.0
    )

    top_panel.position = Vector2(margin,margin)
    top_panel.size = Vector2(330,86)*ui_scale
    $Top/Title.size = Vector2(300,24)*ui_scale
    $Top/Status.size = Vector2(300,38)*ui_scale
    count_label.position = Vector2(margin,margin+93*ui_scale)
    count_label.size = Vector2(330,30)*ui_scale
    var button_size := Vector2(48,44)*ui_scale
    mute_button.size = button_size
    mute_button.position = Vector2(viewport_size.x-margin-button_size.x*2-8,margin)
    pause_button.size = button_size
    pause_button.position = Vector2(viewport_size.x-margin-button_size.x,margin)
    carolina.size = Vector2(42,42)*ui_scale
    carolina.position = Vector2(margin,viewport_size.y-margin-50*ui_scale)
    hp_ammo_label.size = Vector2(235,45)*ui_scale
    hp_ammo_label.position = carolina.position+Vector2(54,0)*ui_scale
    crosshair.size = Vector2(30,30)
    crosshair.position = viewport_size*0.5-crosshair.size*0.5
    reticle.size = Vector2(30,30)
    reticle.position = viewport_size*0.5-reticle.size*0.5
    reticle.queue_redraw()
    hit_marker.size = Vector2(40,40)
    hit_marker.position = viewport_size*0.5-hit_marker.size*0.5
    message_label.size = Vector2(minf(760*ui_scale,viewport_size.x-margin*2),64*ui_scale)
    message_label.position = Vector2((viewport_size.x-message_label.size.x)*0.5,viewport_size.y*0.72)
    joystick.size = Vector2(160,160)*ui_scale
    joystick.position = Vector2(margin,viewport_size.y-margin-joystick.size.y)
    knob.size = Vector2(64,64)*ui_scale
    knob.position = joystick.size*0.5-knob.size*0.5
    fire_button.size = Vector2(112,112)*ui_scale
    fire_button.position = Vector2(viewport_size.x-margin-fire_button.size.x,viewport_size.y-margin-fire_button.size.y)
    fire_button.text = "ОГЛУШИТЬ"
    fire_button.add_theme_font_size_override("font_size",16)
    weapon.size = Vector2(260,195)*ui_scale
    weapon.position = Vector2(viewport_size.x*0.66-weapon.size.x*0.5,viewport_size.y-weapon.size.y)
    var flash := $MuzzleFlash as ColorRect
    flash.size = Vector2(28,40)*ui_scale
    flash.position = weapon.position+Vector2(136,23)*ui_scale
    minimap.size = Vector2(160,122)*ui_scale
    minimap.position = Vector2(viewport_size.x-margin-minimap.size.x,margin+60*ui_scale)
    var map_frame := minimap.get_node("Frame") as Control
    map_frame.size = minimap.size
    mission.size = Vector2(640,380)
    mission.scale = Vector2.ONE*ui_scale
    mission.position = (viewport_size-mission.size*ui_scale)*0.5
    pause_panel.size = Vector2(380,310)
    pause_panel.position = (viewport_size-pause_panel.size)*0.5
    look_area.position = Vector2(viewport_size.x*0.43,margin+60)
    look_area.size = Vector2(viewport_size.x*0.57,viewport_size.y-margin-60)
    if OS.has_feature("mobile"):
        carolina.position.y = margin+186*ui_scale
        carolina.position.x = viewport_size.x-margin-235*ui_scale
        hp_ammo_label.position = carolina.position+Vector2(50,0)*ui_scale
        hp_ammo_label.size.x = 185*ui_scale

func _on_joystick_gui_input(event: InputEvent) -> void:
    if PauseManager.is_paused: return
    if event is InputEventScreenTouch:
        if event.pressed and joystick_touch_id == -1:
            joystick_touch_id = event.index
            _update_joystick(event.position)
            joystick.accept_event()
        elif event.index == joystick_touch_id:
            joystick_touch_id = -1
            _release_move_actions()
            _reset_knob()
            joystick.accept_event()

    elif event is InputEventScreenDrag and event.index == joystick_touch_id:
        _update_joystick(event.position)
        joystick.accept_event()

    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and joystick_touch_id == -1:
            joystick_touch_id = -2
            _update_joystick(event.position)
            joystick.accept_event()
        elif joystick_touch_id == -2:
            joystick_touch_id = -1
            _release_move_actions()
            _reset_knob()
            joystick.accept_event()

    elif event is InputEventMouseMotion and joystick_touch_id == -2:
        _update_joystick(event.position)
        joystick.accept_event()

func _update_joystick(position: Vector2) -> void:
    var center := joystick.size * 0.5
    var radius := LevelData.JOYSTICK_RADIUS * ui_scale
    var delta := JoystickMath.clamped_delta(position, center, radius)
    var axis := JoystickMath.axis_from_delta(delta, radius)

    _set_axis_actions(axis)
    knob.position = center - knob.size * 0.5 + delta

func _set_axis_actions(axis: Vector2) -> void:
    _set_action("l1_move_left", -axis.x)
    _set_action("l1_move_right", axis.x)
    _set_action("l1_move_forward", -axis.y)
    _set_action("l1_move_backward", axis.y)

func _release_move_actions() -> void:
    for action in [
        "l1_move_left",
        "l1_move_right",
        "l1_move_forward",
        "l1_move_backward"
    ]:
        Input.action_release(action)

func _set_action(action: StringName, strength: float) -> void:
    if strength > 0.001:
        Input.action_press(action, minf(strength, 1.0))
    else:
        Input.action_release(action)

func _reset_knob() -> void:
    knob.position = joystick.size * 0.5 - knob.size * 0.5
