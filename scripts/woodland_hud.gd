extends CanvasLayer

# The woodland interface owns touch fingers, never the mission state.
# Desktop world input remains with the director; emulated mouse events cannot fire.
const CREAM := Color("eee8d8")
const MUTED := Color("c0c7b9")
const AMBER := Color("dfb474")
const MOVE_ACTIONS := ["l1_move_left", "l1_move_right", "l1_move_forward", "l1_move_backward"]

class Thumbstick extends Control:
    var displacement := Vector2.ZERO
    func _draw() -> void:
        var center := size * 0.5
        draw_circle(center, size.x * 0.47, Color(0.06, 0.09, 0.07, 0.23))
        draw_arc(center, size.x * 0.47, 0.0, TAU, 64, Color(0.91, 0.89, 0.80, 0.38), 1.5, true)
        draw_circle(center + displacement, size.x * 0.19, Color(0.91, 0.89, 0.80, 0.57))

class RouteMap extends Control:
    var director: Node
    func _draw() -> void:
        if not is_instance_valid(director):return
        var points=[Vector2(.12,.17),Vector2(.37,.17),Vector2(.62,.17),Vector2(.87,.17),Vector2(.87,.67),Vector2(.62,.67),Vector2(.37,.67),Vector2(.12,.67)]
        var font=ThemeDB.fallback_font
        var s=size.x/554.0
        for i in range(7):draw_line(points[i]*size,points[i+1]*size,Color("65765d"),3*s,true)
        for i in range(8):
            var p: Vector2=points[i]*size
            var here: bool=i==director.region_index
            var color=Color("dfb474") if here else (Color("9dbb86") if director.journey.completed.has(i) else Color("8c9989"))
            if here:draw_arc(p,19*s,0,TAU,32,color,2*s,true)
            draw_circle(p,13*s,color)
            draw_string(font,p+Vector2(-4,5)*s,str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14*s,Color("17211c"))
            var words: PackedStringArray=director.JourneyState.TITLES[i].split(" ")
            for line in range(words.size()):
                draw_string(font,p+Vector2(-64,36+line*16)*s,words[line],HORIZONTAL_ALIGNMENT_CENTER,128*s,12*s,Color("eee8d8"))
            if here:draw_string(font,p+Vector2(-54,-29)*s,"ТЫ ЗДЕСЬ",HORIZONTAL_ALIGNMENT_CENTER,108*s,11*s,color)

var director: Node
var player: Node
var root: Control
var mission: Label
var mission_hint: Label
var chapter: Label
var supplies: Label
var lanterns: Label
var trail: Label
var prompt: Label
var toast: Label
var desktop_hint: Label
var crosshair: Label
var map_button: Button
var map_panel: Panel
var map_label: Label
var map_graph: RouteMap
var map_footer: Label
var map_open := false
var pause_button: Button
var mute_button: Button
var fire_button: Button
var interact_button: Button
var dash_button: Button
var quiet_button: Button
var joystick: Thumbstick
var boss_panel: Panel
var boss_name: Label
var boss_health: ProgressBar
var modal: Panel
var modal_title: Label
var modal_body: Label
var resume_button: Button
var retry_button: Button
var joystick_touch_id := -1
var look_touch_id := -1
var fire_touch_id := -1
var fire_held := false
var movement_owned := false
var mobile_preview := false
var mobile := false
var message_remaining := 0.0
var scale_factor := 1.0
var _last_modal := ""

func setup(owner_: Node) -> void:
    director = owner_
    player = director.player
    if is_inside_tree():
        _layout();_refresh()

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 10
    _build()
    get_viewport().size_changed.connect(_layout)
    PauseManager.pause_state_changed.connect(_on_pause_changed)
    _layout()

func _build() -> void:
    root = Control.new()
    root.name = "WoodlandInterface"
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    chapter = _label("ЛЕСНОЙ ДОЗОР  /  01", 13, AMBER)
    mission = _label("Зажгите три сигнальных фонаря", 22, CREAM)
    mission_hint = _label("", 16, CREAM)
    mission_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lanterns = _label("ЗАДАЧИ  0 / 3", 14, MUTED)
    trail = _label("",15,AMBER)
    supplies = _label("100  ЗДОРОВЬЕ    38  ШИШКИ", 16, CREAM)
    prompt = _label("", 19, CREAM)
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast = _label("", 17, CREAM)
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desktop_hint = _label("WASD  идти    Мышь  обзор    ЛКМ  рогатка    E  действие    Shift  рывок    C  тихо", 13, MUTED)
    desktop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    crosshair = _label("·", 32, Color(0.96, 0.94, 0.85, 0.85))
    crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_button = _button("КАРТА",14)
    map_button.pressed.connect(_toggle_map)
    map_panel=Panel.new();map_panel.mouse_filter=Control.MOUSE_FILTER_STOP
    map_panel.add_theme_stylebox_override("panel",_panel_style(Color("17211c"),14));root.add_child(map_panel)
    map_label=_label("",18,CREAM,map_panel)
    map_graph=RouteMap.new();map_graph.mouse_filter=Control.MOUSE_FILTER_IGNORE;map_panel.add_child(map_graph)
    map_footer=_label("Все тропы открыты. Следуй указателям.\nЗаверши 8 заданий и вернись к машине.",15,MUTED,map_panel)
    map_panel.hide()
    pause_button = _button("II", 18)
    pause_button.pressed.connect(_open_pause)
    mute_button = _button("♪", 18)
    mute_button.tooltip_text = "Звуки леса"
    mute_button.pressed.connect(_toggle_sound)
    fire_button = _button("ОГОНЬ", 15)
    interact_button = _button("ДЕЙСТВИЕ", 14)
    interact_button.pressed.connect(_interact)
    dash_button = _button("РЫВОК", 13)
    dash_button.pressed.connect(_dash)
    quiet_button = _button("ТИХО", 13)
    quiet_button.pressed.connect(_quiet)
    # Fire is handled exclusively by touch IDs below. A mouse emulated from
    # a finger on another control can never trigger button_down here.
    fire_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    joystick = Thumbstick.new()
    joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(joystick)
    boss_panel = Panel.new()
    boss_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.07, 0.06, 0.68), 10))
    boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(boss_panel)
    boss_name = _label("СТРАЖ СТАРОГО ДУБА", 13, CREAM, boss_panel)
    boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_health = ProgressBar.new()
    boss_health.show_percentage = false
    boss_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_health.add_theme_stylebox_override("background", _panel_style(Color("3c4439"), 2))
    boss_health.add_theme_stylebox_override("fill", _panel_style(AMBER, 2))
    boss_panel.add_child(boss_health)
    modal = Panel.new()
    modal.name = "PauseAndRetry"
    modal.add_theme_stylebox_override("panel", _panel_style(Color("17211c"), 14))
    modal.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(modal)
    modal_title = _label("ПАУЗА", 26, CREAM, modal)
    modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    modal_body = _label("Лес подождёт.", 17, MUTED, modal)
    modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    resume_button = _button("ПРОДОЛЖИТЬ", 16, modal)
    resume_button.pressed.connect(func(): PauseManager.resume())
    retry_button = _button("НАЧАТЬ ЗАНОВО", 16, modal)
    retry_button.pressed.connect(_restart)
    modal.hide()

func _label(text_: String, font_size: int, color: Color, parent_: Control = null) -> Label:
    var label := Label.new()
    label.text = text_
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.add_theme_font_size_override("font_size", font_size)
    (root if parent_ == null else parent_).add_child(label)
    return label

func _button(text_: String, font_size: int, parent_: Control = null) -> Button:
    var button := Button.new()
    button.text = text_
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", font_size)
    button.add_theme_color_override("font_color", CREAM)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.12, 0.09, 0.68), 12))
    button.add_theme_stylebox_override("hover", _panel_style(Color(0.20, 0.27, 0.20, 0.88), 12))
    button.add_theme_stylebox_override("pressed", _panel_style(Color(0.36, 0.33, 0.22, 0.92), 12))
    (root if parent_ == null else parent_).add_child(button)
    return button

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.border_color = Color(0.83, 0.84, 0.74, 0.23)
    style.set_border_width_all(1)
    return style

func set_mobile_preview(enabled: bool) -> void:
    mobile_preview = enabled
    if is_inside_tree():
        _layout()

func _layout() -> void:
    if root == null:
        return
    var size_ := get_viewport().get_visible_rect().size
    root.size = size_
    scale_factor = clampf(minf(size_.x / 1280.0, size_.y / 720.0), 0.5, 1.55)
    var s := scale_factor
    for pair in [[chapter, 13], [mission, 22], [mission_hint, 16], [lanterns, 14], [trail,15], [supplies, 16], [prompt, 19], [toast, 17], [desktop_hint, 13], [crosshair, 32], [boss_name, 13], [modal_title, 26], [modal_body, 17]]:
        pair[0].add_theme_font_size_override("font_size", maxi(11, roundi(float(pair[1]) * s)))

    var margin := 30.0 * s
    mobile = mobile_preview or OS.has_feature("mobile")
    _rect(chapter, Vector2(margin, 22 * s), Vector2(size_.x * 0.70, 22 * s))
    _rect(mission, Vector2(margin, 47 * s), Vector2(size_.x - margin * 2.0 - 128 * s, 33 * s))
    _rect(mission_hint, Vector2(margin, 83 * s), Vector2(size_.x - margin * 2.0, 45 * s))
    _rect(lanterns, Vector2(margin, 136 * s), Vector2(250 * s, 26 * s))
    _rect(supplies, Vector2(margin, 165 * s), Vector2(320 * s, 30 * s))
    _rect(trail,Vector2(margin,196*s),Vector2(size_.x-margin*2,24*s))
    _rect(map_button,Vector2(size_.x-margin-202*s,26*s),Vector2(82,44)*s)
    map_button.visible=is_instance_valid(director) and director.has_method("journey_map_text")
    _rect(map_panel,size_*.5-Vector2(305,240)*s,Vector2(610,480)*s)
    _rect(map_label,Vector2(28,22)*s,Vector2(554,52)*s)
    _rect(map_graph,Vector2(28,88)*s,Vector2(554,294)*s)
    _rect(map_footer,Vector2(28,398)*s,Vector2(554,62)*s)
    map_footer.add_theme_font_size_override("font_size",maxi(11,roundi(15*s)))
    map_label.add_theme_font_size_override("font_size",maxi(12,roundi(18*s)))
    _rect(pause_button, Vector2(size_.x - margin - 48 * s, 26 * s), Vector2(48, 44) * s)
    _rect(mute_button, Vector2(size_.x - margin - 106 * s, 26 * s), Vector2(48, 44) * s)
    _rect(prompt, Vector2(size_.x * 0.18, size_.y * 0.66), Vector2(size_.x * 0.64, 54 * s))
    _rect(toast, Vector2(size_.x * 0.20, 230 * s), Vector2(size_.x * 0.60, 62 * s))
    _rect(desktop_hint, Vector2(60 * s, size_.y - 33 * s), Vector2(size_.x - 120 * s, 24 * s))
    _rect(crosshair, size_ * 0.5 - Vector2(15, 24) * s, Vector2(30, 48) * s)
    _rect(joystick, Vector2(margin, size_.y - 193 * s), Vector2(160, 160) * s)
    _rect(fire_button, Vector2(size_.x - margin - 102 * s, size_.y - 182 * s), Vector2(102, 102) * s)
    _rect(interact_button, Vector2(size_.x - margin - 252 * s, size_.y - 147 * s), Vector2(136, 64) * s)
    _rect(dash_button, Vector2(size_.x - margin - 104 * s, size_.y - 66 * s), Vector2(104, 46) * s)
    _rect(quiet_button, Vector2(size_.x - margin - 252 * s, size_.y - 66 * s), Vector2(136, 46) * s)
    for node: Control in [joystick, fire_button, interact_button, dash_button, quiet_button]:
        node.visible = mobile
    desktop_hint.visible = not mobile
    _rect(boss_panel, Vector2(size_.x * 0.5 - 180 * s, 137 * s), Vector2(360, 58) * s)
    _rect(boss_name, Vector2(10, 7) * s, Vector2(340, 22) * s)
    _rect(boss_health, Vector2(18, 37) * s, Vector2(324, 6) * s)
    _rect(modal, size_ * 0.5 - Vector2(230, 155) * s, Vector2(460, 310) * s)
    _rect(modal_title, Vector2(25, 25) * s, Vector2(410, 42) * s)
    _rect(modal_body, Vector2(30, 78) * s, Vector2(400, 62) * s)
    _rect(resume_button, Vector2(45, 162) * s, Vector2(370, 48) * s)
    _rect(retry_button, Vector2(45, 224) * s, Vector2(370, 48) * s)

func _rect(control: Control, position_: Vector2, size_: Vector2) -> void:
    control.position = position_
    control.size = size_
    # Font reshaping invalidates Label minima on the next idle frame. Apply
    # the requested extent again then so shrinking a phone cannot retain the
    # previous desktop font's minimum height.
    control.set_deferred("size", size_)

func _process(delta: float) -> void:
    message_remaining = maxf(0.0, message_remaining - delta)
    if toast != null:
        toast.visible = message_remaining > 0.0
    if not is_instance_valid(director) or not is_instance_valid(player):
        return
    _refresh()
    if fire_held and _available():
        player.request_fire()

func _refresh() -> void:
    if mission == null or not is_instance_valid(director):
        return
    var objective: String = director.objective_text()
    var first_break := objective.find("\n")
    mission.text = objective if first_break < 0 else objective.left(first_break)
    mission_hint.text = "" if first_break < 0 else objective.substr(first_break + 1)
    lanterns.text = director.area_progress() if director.has_method("area_progress") else "ЗАДАЧИ  %d / 3" % director.stations_lit
    if director.has_method("journey_map_text"):
        chapter.text="ЛЕСНИЧЕСТВО / УЧАСТОК %d ИЗ 8"%(director.region_index+1)
        map_label.text="ЛЕСНИЧЕСТВО · 8 ЛОКАЦИЙ\nВыполнено заданий: %d / 8"%director.journey.completed.size()
        map_graph.director=director
        if map_open:map_graph.queue_redraw()
    trail.visible=director.has_method("trail_hint")
    if trail.visible:trail.text=director.trail_hint()
    map_panel.visible=map_open and PauseManager.is_paused
    if not PauseManager.is_paused:map_open=false
    prompt.text = director.context_text()
    prompt.visible = not prompt.text.is_empty() and not PauseManager.is_paused
    interact_button.disabled = prompt.text.is_empty()
    supplies.text = "%d  ЗДОРОВЬЕ     %d  ШИШКИ" % [player.get_hp(), player.get_ammo()]
    quiet_button.text = "ТИХО ✓" if player.quiet_mode else "ТИХО"
    mute_button.text = "♪×" if GameState.sfx_muted else "♪"
    var tank = director.tank
    boss_panel.visible = is_instance_valid(tank) and director.stage == "cache" and not director.mission_failed
    if boss_panel.visible:
        boss_health.max_value = tank.max_hp
        boss_health.value = tank.hp
    var modal_state := "failed" if director.mission_failed else ("pause" if PauseManager.is_paused and not map_open else "")
    modal.visible = not modal_state.is_empty()
    if modal_state != _last_modal:
        _last_modal = modal_state
        if not modal_state.is_empty():
            release_controls()
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        elif not mobile and not map_open:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    modal_title.text = "ПОПРОБУЕМ ЕЩЁ?" if director.mission_failed else "ПАУЗА"
    modal_body.text = "Белки оказались хитрее. Маршруты и тайники помогут в следующей попытке." if director.mission_failed else "Лес подождёт."
    resume_button.visible = not director.mission_failed
    crosshair.visible = not modal.visible

func notify(text_: String, duration := 3.0) -> void:
    if toast == null:
        return
    toast.text = text_
    message_remaining = duration
    toast.visible = true

func _available() -> bool:
    return is_instance_valid(director) and is_instance_valid(player) and player.input_enabled and not PauseManager.is_paused and not director.mission_failed and not director.mission_complete

func _input(event: InputEvent) -> void:
    if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
        return
    if event is InputEventScreenTouch:
        if not event.pressed:
            if event.index == joystick_touch_id:
                joystick_touch_id = -1
                _set_move(Vector2.ZERO)
                joystick.displacement = Vector2.ZERO
                joystick.queue_redraw()
                get_viewport().set_input_as_handled()
            elif event.index == look_touch_id:
                look_touch_id = -1
                get_viewport().set_input_as_handled()
            elif event.index == fire_touch_id:
                fire_touch_id = -1
                fire_held = false
                get_viewport().set_input_as_handled()
            return
        if map_button.visible and map_button.get_global_rect().has_point(event.position):
            _toggle_map();get_viewport().set_input_as_handled();return
        if not _available():return
        var point: Vector2 = event.position
        if mobile and joystick.get_global_rect().has_point(point) and joystick_touch_id < 0:
            joystick_touch_id = event.index
            _update_stick(point)
        elif mobile and fire_button.get_global_rect().has_point(point) and fire_touch_id < 0:
            fire_touch_id = event.index
            fire_held = true
            player.request_fire()
        elif mobile and interact_button.get_global_rect().has_point(point):
            _interact()
        elif mobile and dash_button.get_global_rect().has_point(point):
            _dash()
        elif mobile and quiet_button.get_global_rect().has_point(point):
            _quiet()
        elif pause_button.get_global_rect().has_point(point):
            _open_pause()
        elif mute_button.get_global_rect().has_point(point):
            _toggle_sound()
        elif point.x > root.size.x * 0.42 and look_touch_id < 0:
            look_touch_id = event.index
        else:
            return
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if not _available():
            return
        if event.index == joystick_touch_id:
            _update_stick(event.position)
            get_viewport().set_input_as_handled()
        elif event.index == look_touch_id:
            player.handle_touch_look(event.relative / scale_factor)
            get_viewport().set_input_as_handled()
        elif event.index == fire_touch_id:
            get_viewport().set_input_as_handled()

func _update_stick(point: Vector2) -> void:
    var radius := joystick.size.x * 0.32
    var offset := (point - joystick.get_global_rect().get_center()).limit_length(radius)
    joystick.displacement = offset
    joystick.queue_redraw()
    _set_move(offset / radius)

func _set_move(axis: Vector2) -> void:
    movement_owned = axis.length_squared() > 0.0
    for index in range(MOVE_ACTIONS.size()):
        var strength: float = [-axis.x, axis.x, -axis.y, axis.y][index]
        if strength > 0.1:
            Input.action_press(MOVE_ACTIONS[index], strength)
        else:
            Input.action_release(MOVE_ACTIONS[index])

func release_controls() -> void:
    if movement_owned or joystick_touch_id >= 0:
        for action: String in MOVE_ACTIONS:
            Input.action_release(action)
    movement_owned = false
    joystick_touch_id = -1
    look_touch_id = -1
    fire_touch_id = -1
    fire_held = false
    if joystick != null:
        joystick.displacement = Vector2.ZERO
        joystick.queue_redraw()
    if is_instance_valid(player):
        player.fire_requested = false

func _interact() -> void:
    if _available():
        director.interact()

func _dash() -> void:
    if _available():
        player.request_dash()

func _quiet() -> void:
    if _available():
        player.toggle_quiet()

func _open_pause() -> void:
    if is_instance_valid(director) and not director.mission_failed:
        # One Android finger also produces an emulated mouse activation of the
        # Button. Those events can span separate frames at low FPS. Opening
        # pause is idempotent so the queued release cannot resume the game;
        # Continue and the pause keyboard action remain explicit resume paths.
        PauseManager.set_paused(true)

func _toggle_sound() -> void:
    AudioManager.toggle_sfx()
    mute_button.text = "♪×" if GameState.sfx_muted else "♪"

func _restart() -> void:
    release_controls()
    if is_instance_valid(director):
        director.restart()

func _on_pause_changed(paused: bool) -> void:
    if paused:
        release_controls()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        release_controls()
        if is_instance_valid(director) and not director.mission_failed:
            PauseManager.set_paused(true)

func _exit_tree() -> void:
    release_controls()
    if is_instance_valid(get_viewport()) and get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.disconnect(_layout)
    if PauseManager.pause_state_changed.is_connected(_on_pause_changed):
        PauseManager.pause_state_changed.disconnect(_on_pause_changed)

func _toggle_map() -> void:
    if not is_instance_valid(director) or not director.has_method("journey_map_text"):return
    if map_open:
        map_open=false;PauseManager.resume()
    else:
        release_controls();map_open=true;PauseManager.set_paused(true)
    _refresh()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M:
        _toggle_map();get_viewport().set_input_as_handled()
