extends CanvasLayer
# Presentation and pause lifecycle; the drivetrain and shared chase camera stay
# entirely in their existing owners.
var world: Node2D
var pause_button: Button
var overlay: Control
var title: Label
var summary: Label
var resume_button: Button
var continue_button: Button
var route_label: Label
var bend_label: Label
var sign_notice: Label
var sign_notice_panel: PanelContainer
var rpm_bar: ProgressBar
var rpm_label: Label
var finished := false
var ended := false
var _timer := 0.0
var _lap := 0

func bind(level: Node2D) -> void:
    world=level
    layer=3
    process_mode=Node.PROCESS_MODE_ALWAYS
    route_label=_label("БЕЛИЧЬЯ ПОГОНЯ   /   240SX",18,Color("d5e9e5"))
    bend_label=_label("Уйди от белок. Объезжай шипы.",15,Color("cfb88f"))
    sign_notice_panel=PanelContainer.new()
    sign_notice_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var sign_style := _style(Color(.025,.09,.11,.94),7)
    sign_style.content_margin_left=12;sign_style.content_margin_right=12
    sign_style.content_margin_top=7;sign_style.content_margin_bottom=7
    sign_notice_panel.add_theme_stylebox_override("panel",sign_style)
    add_child(sign_notice_panel)
    sign_notice=_label("",20,Color("e5f2df"))
    sign_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    sign_notice.reparent(sign_notice_panel,false)
    sign_notice_panel.visible=false
    pause_button=_button("Ⅱ",func(): get_node("/root/PauseManager").toggle())
    rpm_label=_label("900 ОБ/МИН",12,Color("96b6b9"))
    rpm_bar=ProgressBar.new()
    rpm_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    rpm_bar.show_percentage=false
    rpm_bar.max_value=7000
    rpm_bar.add_theme_stylebox_override("background",_style(Color("21343c"),2))
    rpm_bar.add_theme_stylebox_override("fill",_style(Color("84c6bd"),2))
    add_child(rpm_bar)
    overlay=Control.new()
    overlay.mouse_filter=Control.MOUSE_FILTER_STOP
    overlay.z_index=20
    add_child(overlay)
    var shade := ColorRect.new()
    shade.color=Color(0.018,0.03,0.05,0.94)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(shade)
    title=_label("ПАУЗА",30,Color("e2ebe2"))
    summary=_label("Погоня приостановлена.",16,Color("9cb6bc"))
    resume_button=_button("ПРОДОЛЖИТЬ",func(): get_node("/root/PauseManager").resume())
    continue_button=_button("К НОЧНОМУ КАФЕ →",_continue_campaign)
    var retry := _button("НА СТАРТ",func(): get_node("/root/SceneFlow").go_to(&"level2"))
    retry.name="Retry"
    var menu := _button("В МЕНЮ",func(): get_node("/root/SceneFlow").go_to(&"menu"))
    menu.name="Menu"
    for control in [title,summary,resume_button,continue_button,retry,menu]: control.reparent(overlay,false)
    overlay.visible=false
    get_node("/root/PauseManager").pause_state_changed.connect(_on_pause)
    get_viewport().size_changed.connect(layout)
    for child in world.hud_background.get_children():
        if child is Control: child.mouse_filter=Control.MOUSE_FILTER_IGNORE
    world.minimap.mouse_filter=Control.MOUSE_FILTER_IGNORE
    world.minimap.z_index=2
    world.message_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    world.hud_background.add_theme_stylebox_override("panel",_style(Color("0e1922"),0))
    layout()

func _style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color=color
    style.border_color=Color("354952")
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    return style
func _label(text_: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text=text_
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
    label.add_theme_constant_override("shadow_offset_y",2)
    add_child(label)
    return label
func _button(text_: String, action: Callable) -> Button:
    var button := Button.new()
    button.text=text_
    button.focus_mode=Control.FOCUS_NONE
    button.add_theme_stylebox_override("normal",_style(Color("20333f"),8))
    button.add_theme_stylebox_override("hover",_style(Color("34505b"),8))
    button.add_theme_stylebox_override("pressed",_style(Color("45656b"),8))
    button.pressed.connect(action)
    add_child(button)
    return button
func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
    control.position=at
    control.size=dimensions

func layout() -> void:
    if world==null: return
    var v := get_viewport().get_visible_rect().size
    var s := minf(v.x/1280.0,v.y/720.0)
    var top: float = v.y*world.HUD_TOP_FRACTION
    _place(world.hud_background,Vector2(0,top),Vector2(v.x,v.y-top))
    _place(world.joystick,Vector2(24*s,top+25*s),Vector2.ONE*150*s)
    world.joystick_knob.size=Vector2.ONE*58*s
    world.joystick_knob.position=(world.joystick.size-world.joystick_knob.size)*.5
    _place(world.brake_button,Vector2(v.x-201*s,top+23*s),Vector2(177,64)*s)
    _place(world.gas_button,Vector2(v.x-201*s,top+105*s),Vector2(177,76)*s)
    for button in [world.brake_button,world.gas_button]: button.add_theme_font_size_override("font_size",roundi(19*s))
    world.brake_button.add_theme_stylebox_override("normal",_style(Color("49332f"),8))
    world.gas_button.add_theme_stylebox_override("normal",_style(Color("24463f"),8))
    # Every original label remains bound to RaceController, with one layout.
    var rects := {
        "SpeedLabel":Rect2(207,16,170,22),"Speed":Rect2(202,37,120,67),"KmhLabel":Rect2(325,77,70,22),
        "GearLabel":Rect2(334,18,66,20),"Gear":Rect2(337,38,60,42),
        "LapLabel":Rect2(438,18,90,24),"Lap":Rect2(438,45,95,44),
        "PosLabel":Rect2(572,18,105,24),"Pos":Rect2(572,45,105,44),
        "TimeLabel":Rect2(438,106,115,22),"Time":Rect2(438,130,144,35),
        "BestLabel":Rect2(598,106,126,22),"Best":Rect2(598,130,150,35)}
    for id in rects:
        var label: Label=world.hud_background.get_node(id)
        var rect_: Rect2=rects[id]
        label.scale=Vector2.ONE*s
        _place(label,rect_.position*s,rect_.size)
        label.add_theme_font_size_override("font_size",14 if id.ends_with("Label") else (54 if id=="Speed" else (28 if id in ["Time","Best"] else 31)))
        label.add_theme_color_override("font_color",Color("a6bcc1") if id.ends_with("Label") else Color("e1eee6"))
    world.hud_background.get_node("SpeedLabel").text="СКОРОСТЬ"
    world.hud_background.get_node("GearLabel").text="АТ"
    world.hud_background.get_node("LapLabel").text="ПРОГРЕСС"
    world.hud_background.get_node("BestLabel").text="ДО ОТРЫВА"
    world.hud_background.get_node("PosLabel").text="ПРЕСЛЕДУЮТ"
    _place(rpm_bar,Vector2(207*s,top+147*s),Vector2(190,7)*s)
    _place(rpm_label,Vector2(207*s,top+117*s),Vector2(198,24)*s)
    _place(world.minimap,Vector2(v.x-478*s,top+12*s),Vector2(230,180)*s)
    _place(world.message_label,Vector2(v.x*.15,top-44*s),Vector2(v.x*.7,34*s))
    _place(world.countdown_label,Vector2(v.x*.5-130*s,-top+v.y*.24),Vector2(260,125)*s)
    world.countdown_label.add_theme_font_size_override("font_size",roundi(86*s))
    _place(route_label,Vector2(24,22)*s,Vector2(400,30)*s)
    _place(bend_label,Vector2(24,57)*s,Vector2(450,28)*s)
    route_label.add_theme_font_size_override("font_size",maxi(10,roundi(18*s)))
    bend_label.add_theme_font_size_override("font_size",maxi(9,roundi(15*s)))
    world.message_label.add_theme_font_size_override("font_size",maxi(10,roundi(19*s)))
    sign_notice_panel.scale=Vector2.ONE*s
    _place(sign_notice_panel,Vector2(v.x*.5-215*s,20*s),Vector2(430,66))
    _place(pause_button,Vector2(v.x-78*s,20*s),Vector2(54,44)*s)
    _place(overlay,Vector2.ZERO,v)
    var origin := v*.5-Vector2(220,200)*s
    _place(title,origin,Vector2(440,55)*s)
    _place(summary,origin+Vector2(0,64)*s,Vector2(440,76)*s)
    for control in [title,summary]: control.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    for i in range(4):
        var button: Button=[resume_button,continue_button,overlay.get_node("Retry"),overlay.get_node("Menu")][i]
        _place(button,origin+Vector2(25,153+(maxi(0,i-1) if finished else i)*59)*s,Vector2(390,49)*s)
    continue_button.visible=finished
    resume_button.visible=not ended
    # Resume/continue share the primary row; retry/menu stay stable.
    _place(resume_button,origin+Vector2(25,153)*s,Vector2(390,49)*s)
    _place(continue_button,resume_button.position,resume_button.size)
    _place(overlay.get_node("Retry"),origin+Vector2(25,212)*s,Vector2(390,49)*s)
    _place(overlay.get_node("Menu"),origin+Vector2(25,271)*s,Vector2(390,49)*s)

func _process(delta: float) -> void:
    if world==null or get_tree().paused or world.state.race_finished: return
    _timer-=delta
    if _timer>0: return
    _timer=.08
    var car=world.controller.player
    rpm_bar.value=car.engine_rpm
    rpm_label.text="%d ОБ/МИН   ·   AT %d"%[roundi(car.engine_rpm/100.0)*100,car.gear]
    rpm_bar.modulate=Color("ffb98c") if car.engine_rpm>5800 else Color.WHITE
    var sector: int=preload("res://scripts/race_level_data.gd").sector_at(float(car.world_z))
    route_label.text="БЕЛИЧЬЯ ПОГОНЯ   /   "+preload("res://scripts/race_level_data.gd").SECTOR_NAMES[sector]
    var notice := preload("res://scripts/race_location_signs.gd").notice(float(car.world_z))
    sign_notice_panel.visible=not notice.is_empty() and world.state.race_started
    if not notice.is_empty():
        sign_notice.text=notice.name+"\n"+("ЧЕРЕЗ %d М"%notice.distance if notice.distance>0 else "ВЫ ВЪЕХАЛИ В ЛОКАЦИЮ")
    if not world.state.race_started: return
    var warning: String=world.controller.pursuit.warning_text(car)
    if warning.is_empty():
        for ai in world.controller.ais:
            if ai.attack_phase==&"warn": warning="БЕЛКА %s · ГОТОВИТ ТАРАН"%("СПРАВА" if ai.attack_side>0 else "СЛЕВА")
    world.message_label.text=warning
    world.message_label.add_theme_color_override("font_color",Color("ffc786") if car.puncture_remaining<=0 else Color("ff9f88"))
    var tangent := atan2(preload("res://scripts/race_math.gd").track_center_slope(car.track_phase()+.8,world.controller.track_x),40.0)
    var upcoming := wrapf(tangent-float(car.heading_yaw),-PI,PI)
    bend_label.text="ОБОЧИНА · ВЕРНИСЬ НА АСФАЛЬТ" if car.offroad_amount>.2 else ("ПРЯМАЯ" if absf(upcoming)<.035 else ("↰ ЛЕВЫЙ ПОВОРОТ" if upcoming<0 else "ПРАВЫЙ ПОВОРОТ ↱"))

func _on_pause(paused: bool) -> void:
    if world==null: return
    world.race_input.stop()
    world.controller.player.set_inputs(0,0,0)
    overlay.visible=paused or ended
    if not ended:
        title.text="ПАУЗА"
        summary.text="W / ↑ · Газ    S / ↓ · Тормоз\nA / D · Руль    Esc · Продолжить"
    layout()

func show_finish(success: bool) -> void:
    ended=true
    finished=success
    world.race_input.stop()
    title.text="ТЫ ОТОРВАЛСЯ ОТ БЕЛОК" if success else "ПОГОНЯ ОСТАНОВЛЕНА"
    summary.text="Лес → поля → мост → тоннель → город\n%.2f км   ·   Время %s"%[preload("res://scripts/race_level_data.gd").route_length()/1000.0,preload("res://scripts/race_math.gd").format_time(world.state.race_time)]
    overlay.visible=true
    layout()

func _continue_campaign() -> void:
    if finished: world.continue_campaign()

func _exit_tree() -> void:
    var pause_=get_node_or_null("/root/PauseManager")
    if pause_!=null and pause_.pause_state_changed.is_connected(_on_pause): pause_.pause_state_changed.disconnect(_on_pause)
