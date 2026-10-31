extends CanvasLayer
# Presentation and pause lifecycle; the drivetrain and shared chase camera stay
# entirely in their existing owners.
const PixelTheme = preload("res://scripts/pixel_interface_theme.gd")
const PALETTE = PixelTheme.RACE
# The road and upper dialogue keep their existing palette. Only the driving
# controls use these quieter translucent surfaces.
const DASH_TEXT := Color(.78,.88,.85,.88)
const DASH_MUTED := Color(.55,.68,.65,.72)
const DASH_RULE := Color(.40,.60,.56,.38)
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
var radio_panel: PanelContainer
var radio_speaker: Label
var radio_text: Label
var radio_footer: Label
var radio_rule: ColorRect
var dashboard_rule: ColorRect
var speed_card: Panel
var telemetry_card: Panel
var map_card: Panel
var finished := false
var ended := false
var _timer := 0.0
var _lap := 0
var desktop_controls := OS.get_name() == "Windows"
var keyboard_hint: Label

func bind(level: Node2D) -> void:
    world=level
    layer=3
    process_mode=Node.PROCESS_MODE_ALWAYS
    route_label=_label("БЕЛИЧЬЯ ПОГОНЯ   /   240SX",16,PALETTE.text)
    bend_label=_label("",14,PALETTE.accent)
    sign_notice_panel=PanelContainer.new()
    sign_notice_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var sign_style := _style(PALETTE.background,0)
    sign_style.content_margin_left=12;sign_style.content_margin_right=12
    sign_style.content_margin_top=7;sign_style.content_margin_bottom=7
    sign_notice_panel.add_theme_stylebox_override("panel",sign_style)
    add_child(sign_notice_panel)
    sign_notice=_label("",20,Color("e5f2df"))
    sign_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    sign_notice.reparent(sign_notice_panel,false)
    sign_notice_panel.visible=false
    radio_panel=PanelContainer.new();radio_panel.name="RadioSubtitles"
    radio_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    var radio_style := PixelTheme.frame(PALETTE.background,PALETTE.accent,2,8)
    radio_style.content_margin_left=14;radio_style.content_margin_right=14
    radio_style.content_margin_top=9;radio_style.content_margin_bottom=10
    radio_panel.add_theme_stylebox_override("panel",radio_style)
    add_child(radio_panel)
    var radio_lines:=VBoxContainer.new();radio_lines.mouse_filter=Control.MOUSE_FILTER_IGNORE
    radio_lines.add_theme_constant_override("separation",3);radio_panel.add_child(radio_lines)
    radio_speaker=_label("",12,PALETTE.accent);radio_speaker.reparent(radio_lines,false)
    radio_rule=ColorRect.new();radio_rule.color=PALETTE.accent
    radio_rule.custom_minimum_size=Vector2(0,2);radio_rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
    radio_lines.add_child(radio_rule)
    radio_text=_label("",17,PALETTE.text);radio_text.reparent(radio_lines,false)
    radio_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var footer_rule:=ColorRect.new();footer_rule.color=PALETTE.rule
    footer_rule.custom_minimum_size=Vector2(0,1);footer_rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
    radio_lines.add_child(footer_rule)
    radio_footer=_label("БЕЛИЧИЙ ЯЗЫК · СУБТИТРЫ",10,PALETTE.muted)
    radio_footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;radio_footer.reparent(radio_lines,false)
    radio_panel.visible=false
    pause_button=_button("II",func(): get_node("/root/PauseManager").toggle())
    keyboard_hint=_label("W / ↑  ГАЗ\nS / ↓  ТОРМОЗ / НАЗАД\nA / D / ← / →  РУЛЬ\nESC  ПАУЗА",14,DASH_MUTED)
    keyboard_hint.name="DesktopDrivingHint"
    keyboard_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    rpm_label=_label("900 ОБ/МИН",12,PALETTE.muted)
    rpm_bar=ProgressBar.new()
    rpm_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
    rpm_bar.show_percentage=false
    rpm_bar.max_value=7000
    rpm_bar.add_theme_stylebox_override("background",PixelTheme.frame(PALETTE.rule,PALETTE.rule,0))
    rpm_bar.add_theme_stylebox_override("fill",PixelTheme.frame(PALETTE.accent,PALETTE.accent,0))
    add_child(rpm_bar)
    overlay=Control.new()
    overlay.mouse_filter=Control.MOUSE_FILTER_STOP
    overlay.z_index=20
    add_child(overlay)
    var shade := ColorRect.new()
    shade.color=Color(.025,.075,.085,.96)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(shade)
    title=_label("ПАУЗА",30,PALETTE.accent)
    summary=_label("Погоня приостановлена.",16,PALETTE.text)
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
    _build_dashboard_frames()
    for label in [world.message_label,world.countdown_label]:PixelTheme.label(label,PALETTE.text)
    _pedal_style(world.gas_button,false)
    _pedal_style(world.brake_button,true)
    world.brake_button.text="ТОРМОЗ / R"
    world.joystick.add_theme_stylebox_override("panel",PixelTheme.frame(Color(.02,.045,.05,.32),DASH_RULE,1))
    world.joystick_knob.add_theme_stylebox_override("panel",PixelTheme.frame(Color(.45,.66,.63,.45),Color(.63,.81,.78,.42),1))
    layout()

func _style(color: Color, _radius: int) -> StyleBoxFlat:
    return PixelTheme.frame(color,PALETTE.rule,2)
func _label(text_: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text=text_
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
    label.add_theme_constant_override("shadow_offset_y",2)
    PixelTheme.label(label,color)
    add_child(label)
    return label
func _button(text_: String, action: Callable) -> Button:
    var button := Button.new()
    button.text=text_
    button.focus_mode=Control.FOCUS_NONE
    PixelTheme.button(button,PALETTE)
    button.pressed.connect(action)
    add_child(button)
    return button
func _pedal_style(button: Button, braking: bool) -> void:
    var fill := Color(.085,.05,.05,.34) if braking else Color(.025,.075,.07,.38)
    PixelTheme.label(button,DASH_TEXT)
    button.add_theme_color_override("font_hover_color",DASH_TEXT)
    button.add_theme_color_override("font_pressed_color",DASH_TEXT)
    button.add_theme_stylebox_override("normal",PixelTheme.frame(fill,DASH_RULE,1))
    button.add_theme_stylebox_override("hover",PixelTheme.frame(fill,DASH_RULE,1))
    button.add_theme_stylebox_override("pressed",PixelTheme.frame(fill.lightened(.04),DASH_RULE,1))
    button.add_theme_stylebox_override("focus",PixelTheme.frame(Color.TRANSPARENT,Color.TRANSPARENT,0))
func _build_dashboard_frames() -> void:
    world.hud_background.add_theme_stylebox_override("panel",PixelTheme.frame(Color(.01,.025,.03,.28),Color.TRANSPARENT,0))
    speed_card=Panel.new();telemetry_card=Panel.new();map_card=Panel.new()
    for card in [speed_card,telemetry_card,map_card]:
        card.mouse_filter=Control.MOUSE_FILTER_IGNORE
        card.add_theme_stylebox_override("panel",PixelTheme.frame(Color.TRANSPARENT,Color.TRANSPARENT,0))
    world.hud_background.add_child(speed_card);world.hud_background.move_child(speed_card,0)
    world.hud_background.add_child(telemetry_card);world.hud_background.move_child(telemetry_card,0)
    world.hud_background.add_child(map_card);world.hud_background.move_child(map_card,0)
    dashboard_rule=ColorRect.new();dashboard_rule.color=PALETTE.accent
    dashboard_rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
    world.hud_background.add_child(dashboard_rule)
    dashboard_rule.hide();telemetry_card.hide();map_card.hide()
    rpm_bar.hide();rpm_label.hide()
    world.minimap.hide();world.minimap.set_process(false)
    world.message_label.hide();world.message_label.text=""
func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
    control.position=at
    control.size=dimensions

func layout() -> void:
    if world==null: return
    var v := get_viewport().get_visible_rect().size
    var s := minf(v.x/1280.0,v.y/720.0)
    var top: float = v.y*world.HUD_TOP_FRACTION
    _place(world.hud_background,Vector2(0,top),Vector2(v.x,v.y-top))
    _place(dashboard_rule,Vector2(16,3)*s,Vector2(v.x-32*s,2*s))
    _place(speed_card,Vector2(193,12)*s,Vector2(218,163)*s)
    _place(telemetry_card,Vector2(423,12)*s,Vector2(332,165)*s)
    _place(map_card,Vector2(v.x-486*s,8*s),Vector2(246,188)*s)
    _place(world.joystick,Vector2(24*s,top+25*s),Vector2.ONE*150*s)
    world.joystick_knob.size=Vector2.ONE*58*s
    world.joystick_knob.position=(world.joystick.size-world.joystick_knob.size)*.5
    _place(world.brake_button,Vector2(v.x-294*s,top+13*s),Vector2(270,80)*s)
    _place(world.gas_button,Vector2(v.x-294*s,top+101*s),Vector2(270,100)*s)
    world.brake_button.add_theme_font_size_override("font_size",maxi(11,roundi(18*s)))
    world.gas_button.add_theme_font_size_override("font_size",maxi(12,roundi(22*s)))
    for control in [world.joystick,world.gas_button,world.brake_button]:
        control.visible=not desktop_controls
    keyboard_hint.visible=desktop_controls
    _place(keyboard_hint,Vector2(v.x-294*s,top+27*s),Vector2(270,160)*s)
    keyboard_hint.add_theme_font_size_override("font_size",maxi(11,roundi(17*s)))
    # Keep bindings for finish/statistics, but the live dashboard only needs
    # speed, automatic gear and the remaining escape distance.
    var rects := {
        "SpeedLabel":Rect2(207,16,170,22),"Speed":Rect2(202,37,120,67),"KmhLabel":Rect2(325,77,70,22),
        "GearLabel":Rect2(334,18,66,20),"Gear":Rect2(337,38,60,42),
        "LapLabel":Rect2(438,18,90,24),"Lap":Rect2(438,45,95,44),
        "PosLabel":Rect2(572,18,105,24),"Pos":Rect2(572,45,105,44),
        "TimeLabel":Rect2(438,106,115,22),"Time":Rect2(438,130,144,35),
        "BestLabel":Rect2(445,44,180,22),"Best":Rect2(445,73,180,40)}
    for id in rects:
        var label: Label=world.hud_background.get_node(id)
        var rect_: Rect2=rects[id]
        label.scale=Vector2.ONE*s
        _place(label,rect_.position*s,rect_.size)
        label.add_theme_font_size_override("font_size",14 if id.ends_with("Label") else (54 if id=="Speed" else (28 if id in ["Time","Best"] else 31)))
        PixelTheme.label(label,DASH_MUTED if id.ends_with("Label") else DASH_TEXT)
        label.visible=id not in ["LapLabel","Lap","PosLabel","Pos","TimeLabel","Time"]
    world.hud_background.get_node("SpeedLabel").text="СКОРОСТЬ"
    world.hud_background.get_node("GearLabel").text="АТ"
    world.hud_background.get_node("BestLabel").text="ДО ОТРЫВА"
    _place(rpm_bar,Vector2(207*s,top+147*s),Vector2(190,7)*s)
    _place(rpm_label,Vector2(207*s,top+117*s),Vector2(198,24)*s)
    world.minimap.hide();world.minimap.set_process(false)
    map_card.hide();telemetry_card.hide();dashboard_rule.hide();rpm_bar.hide();rpm_label.hide()
    world.message_label.hide();world.message_label.text=""
    _place(world.message_label,Vector2(v.x*.15,top-44*s),Vector2(v.x*.7,34*s))
    _place(world.countdown_label,Vector2(v.x*.5-130*s,-top+v.y*.24),Vector2(260,125)*s)
    world.countdown_label.add_theme_font_size_override("font_size",roundi(86*s))
    _place(route_label,Vector2(24,22)*s,Vector2(400,30)*s)
    _place(bend_label,Vector2(24,57)*s,Vector2(450,28)*s)
    route_label.add_theme_font_size_override("font_size",maxi(10,roundi(16*s)))
    bend_label.add_theme_font_size_override("font_size",maxi(9,roundi(14*s)))
    world.message_label.add_theme_font_size_override("font_size",maxi(10,roundi(17*s)))
    sign_notice_panel.scale=Vector2.ONE*s
    _place(sign_notice_panel,Vector2(v.x*.5-215*s,20*s),Vector2(430,66))
    # Narrative radio stays above the playfield; the navigation map and the
    # separate tactical warning strip have been removed from the live HUD.
    radio_panel.scale=Vector2.ONE*s
    _place(radio_panel,Vector2(24*s,104*s),Vector2(420,0))
    _place(pause_button,Vector2(v.x-78*s,20*s),Vector2(54,44)*s)
    pause_button.add_theme_font_size_override("font_size",maxi(12,roundi(18*s)))
    _place(overlay,Vector2.ZERO,v)
    var origin := v*.5-Vector2(220,200)*s
    _place(title,origin,Vector2(440,55)*s)
    _place(summary,origin+Vector2(0,64)*s,Vector2(440,76)*s)
    for control in [title,summary]: control.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size",maxi(18,roundi(30*s)))
    summary.add_theme_font_size_override("font_size",maxi(11,roundi(16*s)))
    rpm_label.add_theme_font_size_override("font_size",maxi(9,roundi(12*s)))
    for i in range(4):
        var button: Button=[resume_button,continue_button,overlay.get_node("Retry"),overlay.get_node("Menu")][i]
        _place(button,origin+Vector2(25,153+(maxi(0,i-1) if finished else i)*59)*s,Vector2(390,49)*s)
        button.add_theme_font_size_override("font_size",maxi(11,roundi(16*s)))
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
    rpm_label.text="%d ОБ/МИН   ·   AT %s"%[roundi(car.engine_rpm/100.0)*100,"R" if car.gear<0 else str(car.gear)]
    rpm_bar.modulate=Color("ffb98c") if car.engine_rpm>5800 else Color.WHITE
    var sector: int=preload("res://scripts/race_level_data.gd").sector_at(float(car.world_z))
    route_label.text="БЕЛИЧЬЯ ПОГОНЯ   /   "+preload("res://scripts/race_level_data.gd").SECTOR_NAMES[sector]
    var notice := preload("res://scripts/race_location_signs.gd").notice(float(car.world_z))
    sign_notice_panel.visible=not notice.is_empty() and world.state.race_started
    if not notice.is_empty():
        sign_notice.text=notice.name+"\n"+("ЧЕРЕЗ %d М"%notice.distance if notice.distance>0 else "ВЫ ВЪЕХАЛИ В ЛОКАЦИЮ")
    if not world.state.race_started: return
    var line: Dictionary=world.controller.pursuit.radio.current
    radio_panel.visible=not line.is_empty()
    if not line.is_empty():
        radio_speaker.text="● ЭФИР   /   "+String(line.speaker)
        radio_text.text=String(line.text)
    # Physical spikes, roadblocks, their audio and AI telegraphs remain. There
    # is no redundant text instruction strip over the road.
    world.message_label.text=""
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
        summary.text="W / ↑ · Газ    S / ↓ · Тормоз\nУдержи тормоз стоя — назад 1 км/ч\nA / D · Руль    Esc · Продолжить"
    layout()

func show_finish(success: bool) -> void:
    ended=true
    finished=success
    radio_panel.visible=false
    world.race_input.stop()
    title.text="ТЫ ОТОРВАЛАСЬ ОТ БЕЛОК" if success else "ПОГОНЯ ОСТАНОВЛЕНА"
    summary.text="Лес → поля → мост → тоннель → город\n%.2f км   ·   Время %s"%[preload("res://scripts/race_level_data.gd").route_length()/1000.0,preload("res://scripts/race_math.gd").format_time(world.state.race_time)]
    overlay.visible=true
    layout()

func _continue_campaign() -> void:
    if finished: world.continue_campaign()

func _exit_tree() -> void:
    var pause_=get_node_or_null("/root/PauseManager")
    if pause_!=null and pause_.pause_state_changed.is_connected(_on_pause): pause_.pause_state_changed.disconnect(_on_pause)
