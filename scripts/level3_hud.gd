extends CanvasLayer
class_name Level3HUD
@onready var _pause_manager: Node = get_node("/root/PauseManager")
var world: Level3Store
var mobile_active := OS.has_feature("mobile")
var _touches: Dictionary = {}
var _cards: Array[Control] = []
var _title: Label
var _room: Label
var _pause: Button
var _cycle: Button
var _map: Control
var _overlay: Control
var _panel: Panel
var _overlay_title: Label
var _overlay_text: Label
var _resume: Button
var _retry: Button
var _menu: Button
var _tick := 0.0
var _health_bar: ProgressBar
var _fade: ColorRect

func bind(store: Level3Store) -> void:
    world = store
    process_mode = Node.PROCESS_MODE_ALWAYS
    _cards.append(_card())
    _cards.append(_card())
    _cards.append(_card())
    _title = _label("НОЧНАЯ СМЕНА",24,Color("e4eee8"))
    _room = _label("ACORN DINER   /   02:17",12,Color("a8bbc0"))
    _pause = _button("Ⅱ",func(): _pause_manager.toggle())
    _cycle = _button("СМЕНИТЬ",func(): world.player.switch_next_weapon())
    _map = Control.new()
    _map.set_script(load("res://scripts/level3_minimap.gd"))
    _map.world = world
    add_child(_map)
    _health_bar = ProgressBar.new()
    _health_bar.show_percentage = false
    _health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color("25363f")
    bg.set_corner_radius_all(2)
    var fill := bg.duplicate() as StyleBoxFlat
    fill.bg_color = Color("abd6b8")
    _health_bar.add_theme_stylebox_override("background",bg)
    _health_bar.add_theme_stylebox_override("fill",fill)
    add_child(_health_bar)
    for label in [world.objective_label,world.weapon_label,world.hint_label,world.status_label]: label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    for button in _game_buttons():
        button.mouse_filter=Control.MOUSE_FILTER_IGNORE
        button.focus_mode=Control.FOCUS_NONE
        button.add_theme_font_size_override("font_size",14)
        button.add_theme_stylebox_override("normal",_button_style(Color("18323c")))
    world.fire_button.text="ОГОНЬ"
    world.action_button.text="ДЕЙСТВИЕ"
    world.throw_button.text="БРОСОК"
    world.sprint_button.text="БЕГ"
    world.move_joystick.caption="ДВИЖЕНИЕ"
    world.aim_joystick.caption="ПРИЦЕЛ"
    _build_overlay()
    _fade=ColorRect.new()
    _fade.color=Color(0.018,0.032,0.046,0.0)
    _fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _fade.z_index=200
    add_child(_fade)
    get_viewport().size_changed.connect(_layout)
    _pause_manager.pause_state_changed.connect(_on_pause)
    _layout()

func _exit_tree() -> void:
    if _pause_manager.pause_state_changed.is_connected(_on_pause): _pause_manager.pause_state_changed.disconnect(_on_pause)

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text=text
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(label)
    return label
func _card() -> Panel:
    var card := Panel.new()
    card.mouse_filter=Control.MOUSE_FILTER_IGNORE
    card.z_index=-1
    var style := StyleBoxFlat.new()
    style.bg_color=Color(0.025,0.047,0.066,0.91)
    style.border_color=Color(0.37,0.50,0.53,0.4)
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    card.add_theme_stylebox_override("panel",style)
    add_child(card)
    return card
func _button_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color=Color(color,0.84)
    style.border_color=Color(0.56,0.73,0.76,0.44)
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    return style
func _button(text: String, action: Callable) -> Button:
    var button := Button.new()
    button.text=text
    button.focus_mode=Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size",16)
    button.add_theme_stylebox_override("normal",_button_style(Color("223c46")))
    button.add_theme_stylebox_override("hover",_button_style(Color("3c5760")))
    button.add_theme_stylebox_override("pressed",_button_style(Color("43666b")))
    button.pressed.connect(action)
    add_child(button)
    return button
func _place(control: Control, position_: Vector2, size_: Vector2) -> void:
    control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    control.position=position_
    control.size=size_
func _game_buttons() -> Array[Button]: return [world.fire_button,world.action_button,world.throw_button,world.sprint_button,_cycle]

func _layout() -> void:
    if world==null: return
    var size_ := get_viewport().get_visible_rect().size
    var width := size_.x
    var height := size_.y
    _place(_cards[0],Vector2(20,18),Vector2(minf(396,width*0.40),88))
    _place(_title,Vector2(36,27),Vector2(minf(372,width*.40-32),34))
    _place(world.objective_label,Vector2(36,67),Vector2(minf(372,width*.40-32),26))
    world.objective_label.add_theme_font_size_override("font_size",15)
    _place(_room,Vector2(width*0.5-120,23),Vector2(240,24))
    _room.visible=width>=1150
    _title.add_theme_font_size_override("font_size",22 if width<1150 else 24)
    _room.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _place(_pause,Vector2(width-76,20),Vector2(52,42))
    _place(_map,Vector2(width-218,76),Vector2(194,140))
    var footer_y := height-69 if not mobile_active else 119.0
    _place(_cards[1],Vector2(20,footer_y-8),Vector2(170,55))
    _place(world.status_label,Vector2(34,footer_y),Vector2(152,25))
    world.status_label.add_theme_font_size_override("font_size",15)
    world.status_label.add_theme_color_override("font_color",Color("cae7d3"))
    _place(_health_bar,Vector2(34,footer_y+27),Vector2(142,5))
    _place(_cards[2],Vector2(width-382,height-80 if not mobile_active else 224),Vector2(358,59))
    _place(world.weapon_label,Vector2(width-367,height-71 if not mobile_active else 235),Vector2(329,47))
    world.weapon_label.add_theme_font_size_override("font_size",16)
    world.weapon_label.add_theme_color_override("font_color",Color("d2ddd7"))
    _place(world.hint_label,Vector2(width*0.5-300,height-43),Vector2(600,28))
    world.hint_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    world.hint_label.add_theme_font_size_override("font_size",13)
    var r := clampf(height*0.115,53,76)
    _place(world.move_joystick,Vector2(27,height-2*r-26),Vector2.ONE*r*2)
    _place(world.aim_joystick,Vector2(width-2*r-27,height-2*r-26),Vector2.ONE*r*2)
    world.move_joystick.active_radius=r-3
    world.aim_joystick.active_radius=r-3
    _place(world.fire_button,Vector2(width-157,height-2*r-108),Vector2(127,66))
    world.fire_button.add_theme_stylebox_override("normal",_button_style(Color("673330")))
    _place(world.action_button,Vector2(width-295,height-140),Vector2(113,56))
    _place(world.throw_button,Vector2(width-295,height-71),Vector2(113,49))
    _place(world.sprint_button,Vector2(38,height-2*r-92),Vector2(118,50))
    _place(_cycle,Vector2(width-295,height-2*r-108),Vector2(113,49))
    for control in _game_buttons()+[world.move_joystick,world.aim_joystick]: control.visible=mobile_active
    _place(_overlay,Vector2.ZERO,size_)
    _place(_panel,size_*0.5-Vector2(220,164),Vector2(440,328))
    _place(_overlay_title,Vector2(31,27),Vector2(378,44))
    _place(_overlay_text,Vector2(31,79),Vector2(378,47))
    _place(_resume,Vector2(31,139),Vector2(378,46))
    _place(_retry,Vector2(31,195),Vector2(378,46))
    _place(_menu,Vector2(31,251),Vector2(378,46))
    _place(_fade,Vector2.ZERO,size_)

func _build_overlay() -> void:
    _overlay=Control.new()
    _overlay.z_index=150
    _overlay.mouse_filter=Control.MOUSE_FILTER_STOP
    add_child(_overlay)
    var dark := ColorRect.new()
    dark.color=Color(0.015,0.027,0.04,0.78)
    dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay.add_child(dark)
    _panel=Panel.new()
    _panel.add_theme_stylebox_override("panel",_button_style(Color("132c38")))
    _overlay.add_child(_panel)
    _overlay_title=_label("ПАУЗА",28,Color("e5ede5"))
    _overlay_text=_label("Передохни. Ночная смена подождёт.",15,Color("a1b9bf"))
    _resume=_button("ПРОДОЛЖИТЬ",func(): _pause_manager.resume())
    _retry=_button("НАЧАТЬ ЗАНОВО",func(): _navigate(&"level3"))
    _menu=_button("ВЫБОР УРОВНЯ",func(): _navigate(&"menu"))
    for node in [_overlay_title,_overlay_text,_resume,_retry,_menu]: node.reparent(_panel,false)
    _overlay.visible=false
func _navigate(level: StringName) -> void:
    clear_touches()
    world.clear_inputs()
    _pause_manager.resume()
    get_node("/root/SceneFlow").go_to(level)
func _on_pause(paused: bool) -> void:
    if world==null: return
    clear_touches()
    world.clear_inputs()
    _overlay.visible=paused or world._player_dead
    if not world._player_dead:
        _overlay_title.text="ПАУЗА"
        _overlay_text.text="Передохни. Ночная смена подождёт."
        _resume.visible=true
func show_defeat() -> void:
    clear_touches()
    _overlay.visible=true
    _overlay_title.text="СМЕНА НЕ ОКОНЧЕНА"
    _overlay_text.text="Попробуй другой проход или используй укрытие."
    _resume.visible=false
    _pause_manager.set_paused(true)
func fade_out() -> void:
    var tween := create_tween()
    tween.tween_property(_fade,"color:a",1.0,0.55)
    await tween.finished
func clear_touches() -> void:
    _touches.clear()
    if world!=null:
        world.move_joystick._release()
        world.aim_joystick._release()
        for button in _game_buttons(): button.modulate=Color.WHITE

func _input(event: InputEvent) -> void:
    if world==null: return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_TAB and not get_tree().paused:
        world.player.switch_next_weapon()
        get_viewport().set_input_as_handled()
        return
    if not (event is InputEventScreenTouch or event is InputEventScreenDrag): return
    if not mobile_active:
        mobile_active=true
        _layout()
    if get_tree().paused or world._player_dead or world._level_complete_started: return
    if event is InputEventScreenTouch:
        if not event.pressed or event.canceled:
            if _touches.has(event.index): _release_role(event.index)
            return
        for role in [&"move",&"aim",&"fire",&"action",&"throw",&"sprint",&"cycle"]:
            var control := _control_for(role)
            if not control.get_global_rect().has_point(event.position) or _touches.values().has(role): continue
            _touches[event.index]=role
            if role==&"move" or role==&"aim": control.begin_pointer(event.index,event.position)
            else:
                control.modulate=Color(1.22,1.22,1.15)
                match role:
                    &"fire": world._on_fire_button_down()
                    &"action": world._on_action_button_pressed()
                    &"throw": world._on_throw_button_pressed()
                    &"sprint": world._on_sprint_button_down()
                    &"cycle": world.player.switch_next_weapon()
            get_viewport().set_input_as_handled()
            return
    elif _touches.has(event.index):
        var role: StringName = _touches[event.index]
        var control := _control_for(role)
        if role==&"move" or role==&"aim": control.update_pointer(event.position)
        elif not control.get_global_rect().has_point(event.position): _release_role(event.index)
        get_viewport().set_input_as_handled()
func _control_for(role: StringName) -> Control:
    match role:
        &"move": return world.move_joystick
        &"aim": return world.aim_joystick
        &"fire": return world.fire_button
        &"action": return world.action_button
        &"throw": return world.throw_button
        &"sprint": return world.sprint_button
        _: return _cycle
func _release_role(id: int) -> void:
    var role: StringName = _touches[id]
    var control := _control_for(role)
    if role==&"move" or role==&"aim": control._release()
    elif role==&"fire": world._on_fire_button_up()
    elif role==&"sprint": world._on_sprint_button_up()
    control.modulate=Color.WHITE
    _touches.erase(id)
    get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
    if world==null: return
    _tick-=delta
    if _tick>0: return
    _tick=0.1
    _health_bar.value=world.player.health
    var room := Level3StoreData.room_at(world.player.global_position/1.5)
    _room.text="%s   /   02:17"%room["title"]
