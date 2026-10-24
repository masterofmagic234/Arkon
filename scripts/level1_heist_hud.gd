extends Control
# Presentation reads the director; button callbacks issue only local commands.
var director: Node3D
var heading: Label
var detail: Label
var alarm_bar: ProgressBar
var prompt: Button
var dash: Button
var quiet: Button
var tips: Label
var task_panel: Panel
var refresh := 0.0

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    task_panel=Panel.new(); task_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new(); style.bg_color=Color(.055,.13,.16,.86)
    style.border_color=Color("71877a"); style.set_border_width_all(0); style.set_corner_radius_all(9)
    task_panel.add_theme_stylebox_override("panel",style)
    add_child(task_panel)
    heading=_label(15); detail=_label(13); task_panel.add_child(heading); task_panel.add_child(detail)
    alarm_bar=ProgressBar.new(); alarm_bar.show_percentage=false; alarm_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    alarm_bar.max_value=100
    var fill := StyleBoxFlat.new(); fill.bg_color=Color("e4b06a"); fill.set_corner_radius_all(3)
    alarm_bar.add_theme_stylebox_override("fill",fill)
    var bg := StyleBoxFlat.new(); bg.bg_color=Color("273842"); bg.set_corner_radius_all(3)
    alarm_bar.add_theme_stylebox_override("background",bg); task_panel.add_child(alarm_bar)
    prompt=Button.new(); prompt.name="Interact"; prompt.add_theme_stylebox_override("normal",style)
    prompt.add_theme_font_size_override("font_size",16); add_child(prompt)
    prompt.pressed.connect(func(): director.request_interact())
    _bind_pointer(prompt)
    dash=Button.new(); dash.name="Dash"; dash.add_theme_stylebox_override("normal",style); add_child(dash)
    dash.pressed.connect(func(): director.game.player.request_dash())
    _bind_pointer(dash)
    quiet=Button.new(); quiet.name="Quiet"; quiet.add_theme_stylebox_override("normal",style); add_child(quiet)
    quiet.pressed.connect(func(): director.game.player.toggle_quiet())
    _bind_pointer(quiet)
    tips=_label(13); add_child(tips)
    get_viewport().size_changed.connect(_layout)
    _layout(); _refresh()

func _bind_pointer(button: Button) -> void:
    # Explicit finger ownership also works with multiple concurrent touches.
    # Disable BaseButton's mouse activation so emulated mouse events cannot
    # toggle an action a second time after a real touch has activated it.
    button.button_mask=0
    button.focus_mode=Control.FOCUS_NONE
    button.gui_input.connect(_on_button_input.bind(button))

func _on_button_input(event: InputEvent, button: Button) -> void:
    if button.disabled or not director.available(): return
    if event is InputEventScreenTouch:
        var owner_: int=button.get_meta("finger",-1)
        if event.pressed and owner_<0:
            button.set_meta("finger",event.index)
            button.modulate=Color(.78,.95,.90)
        elif not event.pressed and owner_==event.index:
            button.set_meta("finger",-1)
            button.modulate=Color.WHITE
            if not event.canceled and Rect2(Vector2.ZERO,button.size).has_point(event.position): button.pressed.emit()
        button.accept_event()
    elif event is InputEventScreenDrag:
        button.accept_event()
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if event.device!=InputEvent.DEVICE_ID_EMULATION:
            if event.pressed: button.set_meta("mouse_down",true)
            elif button.get_meta("mouse_down",false):
                button.set_meta("mouse_down",false)
                if Rect2(Vector2.ZERO,button.size).has_point(event.position): button.pressed.emit()
        button.accept_event()

func release_controls() -> void:
    for button: Button in [prompt,dash,quiet]:
        button.set_meta("finger",-1)
        button.set_meta("mouse_down",false)
        button.modulate=Color.WHITE

func _label(size_: int) -> Label:
    var label := Label.new(); label.add_theme_font_size_override("font_size",size_)
    label.add_theme_color_override("font_color",Color("ecdfc8")); label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_shadow_color",Color(0,0,0,.9)); label.add_theme_constant_override("shadow_offset_y",1)
    return label

func _layout() -> void:
    var view := get_viewport().get_visible_rect().size
    var scale_ := clampf(minf(view.x/1280,view.y/720),.72,1.35)
    task_panel.size=Vector2(390,64)*scale_
    task_panel.position=Vector2((view.x-task_panel.size.x)*.5,18)
    heading.position=Vector2(15,5)*scale_; heading.size=Vector2(365,22)*scale_
    heading.add_theme_font_size_override("font_size",roundi(15*scale_))
    detail.position=Vector2(15,24)*scale_; detail.size=Vector2(363,33)*scale_
    detail.add_theme_font_size_override("font_size",roundi(13*scale_)); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    alarm_bar.position=Vector2(15,57)*scale_; alarm_bar.size=Vector2(360,2)*scale_
    prompt.size=Vector2(400,48)*scale_; prompt.position=Vector2((view.x-prompt.size.x)*.5,view.y*.58)
    prompt.add_theme_font_size_override("font_size",roundi(16*scale_))
    dash.size=Vector2(72,62)*scale_; dash.position=Vector2(view.x-228*scale_,view.y-88*scale_)
    quiet.size=Vector2(72,38)*scale_; quiet.position=Vector2(view.x-228*scale_,view.y-142*scale_)
    for button in [quiet,dash]:button.add_theme_font_size_override("font_size",roundi(14*scale_))
    tips.position=Vector2(24,view.y-146*scale_); tips.size=Vector2(460,28)*scale_
    tips.add_theme_font_size_override("font_size",roundi(13*scale_))

func _process(delta: float) -> void:
    refresh-=delta
    if refresh>0: return
    refresh=.10
    _refresh()

func _refresh() -> void:
    if not is_instance_valid(director) or not is_instance_valid(director.game): return
    var active_: bool=director.available()
    visible=active_
    if not active_:
        release_controls()
        return
    for device in director.devices:
        if is_instance_valid(device.title):device.title.visible=device==director.focus or device==director.action
    var player: Node=director.game.player
    heading.text="ДЛЯ ДАРИНЫ   ·   "+("ТРЕВОГА" if director.alarm>=70 else "ПОИСКИ" if director.alarm>=30 else "ТИХО")
    heading.modulate=Color("f2a081") if director.alarm>=70 else Color("a5e3d2")
    detail.text=director.objective()
    alarm_bar.value=director.alarm
    if director.escape_started:
        var remaining := maxi(0,ceili(director.ESCAPE_BONUS_TIME-director.escape_elapsed))
        detail.text += " · бонус %d:%02d" % [remaining/60,remaining%60] if remaining>0 else " · доберись до машины"
    elif director.scan_exposure>0:
        detail.text="ЛУЧ ВИДИТ ТЕБЯ · уйди за стену или используй рывок"
    prompt.visible=is_instance_valid(director.focus) or is_instance_valid(director.action)
    if director.action:
        prompt.text="%s · %d%% · нажми, чтобы отменить" % ["ОТКЛЮЧАЕМ" if director.action.kind=="relay" else "СНИМАЕМ ПЕЧАТЬ",roundi(100*director.action_progress/director.action_duration)]
    elif director.focus:
        prompt.text=("" if OS.has_feature("mobile") else "[E] ")+director.focus.description()
    dash.visible=OS.has_feature("mobile"); quiet.visible=dash.visible
    dash.text="РЫВОК" if player.dash_cooldown<=0 else "%.1f с" % player.dash_cooldown
    dash.disabled=player.dash_cooldown>0
    quiet.text="ТИХО ✓" if player.quiet_mode else "ТИХО"
    tips.visible=not OS.has_feature("mobile")
    tips.text="E · действие     Shift · рывок     C · тихий шаг"+ ("   [ТИХО]" if player.quiet_mode else "")
