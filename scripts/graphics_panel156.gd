extends Control
## Menu-only graphics chooser. The automatic preset is already active on boot;
## opening this panel is optional and never gates starting the story.
signal closed

const MODE_LABELS := {
    "auto":"Авто",
    "low":"Производительность",
    "balanced":"Баланс",
    "high":"Качество",
}
const MODE_ORDER: Array[String] = ["auto","low","balanced","high"]
var mode_buttons: Dictionary = {}
var current_line: Label
var reset_button: Button
var close_button: Button
var panel: PanelContainer
var scroll: ScrollContainer
var _settings: Node

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_STOP
    z_index=100
    var shade:=ColorRect.new()
    shade.name="ModalShade"
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color=Color(.005,.012,.018,.90)
    shade.mouse_filter=Control.MOUSE_FILTER_STOP
    add_child(shade)

    panel=PanelContainer.new();panel.name="Panel"
    panel.add_theme_stylebox_override("panel",_style(Color(.035,.055,.060,.99),Color(.38,.66,.57,.75),12))
    add_child(panel)
    var margin:=MarginContainer.new()
    for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,24)
    panel.add_child(margin)
    scroll=ScrollContainer.new();scroll.name="Scroll"
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    scroll.follow_focus=true
    margin.add_child(scroll)
    var body:=VBoxContainer.new();body.name="Content"
    body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation",10)
    scroll.add_child(body)

    var title:=Label.new();title.name="Title";title.text="ГРАФИКА"
    title.add_theme_font_size_override("font_size",30)
    title.add_theme_color_override("font_color",Color(.90,.97,.92))
    body.add_child(title)
    current_line=Label.new();current_line.name="CurrentProfile"
    current_line.custom_minimum_size.y=42
    current_line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    current_line.add_theme_font_size_override("font_size",20)
    current_line.add_theme_color_override("font_color",Color(.67,.85,.76))
    body.add_child(current_line)
    var help:=Label.new();help.name="Help"
    help.text="Авто подбирает настройки для этого устройства."
    help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    help.add_theme_font_size_override("font_size",17)
    help.add_theme_color_override("font_color",Color(.63,.72,.69))
    body.add_child(help)

    var options:=VBoxContainer.new();options.name="Modes"
    options.add_theme_constant_override("separation",8)
    body.add_child(options)
    var group:=ButtonGroup.new()
    for mode in MODE_ORDER:
        var button:=_button(MODE_LABELS[mode])
        button.name="Mode_"+mode
        button.toggle_mode=true;button.button_group=group
        button.pressed.connect(_choose_mode.bind(mode))
        options.add_child(button);mode_buttons[mode]=button
    var actions:=HBoxContainer.new();actions.name="Actions"
    actions.add_theme_constant_override("separation",12)
    body.add_child(actions)
    reset_button=_button("Повторить подбор")
    reset_button.name="Redetect";reset_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    reset_button.pressed.connect(_redetect)
    actions.add_child(reset_button)
    close_button=_button("Закрыть")
    close_button.name="Close";close_button.custom_minimum_size.x=160
    close_button.pressed.connect(close_panel)
    actions.add_child(close_button)
    _keep_focus_inside()

    _settings=get_node_or_null("/root/GraphicsSettings")
    if _settings!=null and _settings.has_signal("settings_changed"):
        _settings.connect("settings_changed",_refresh)
    resized.connect(_layout)
    _layout();_refresh();hide();set_process_unhandled_input(false)

func _style(background: Color,border: Color,radius: int=8) -> StyleBoxFlat:
    var result:=StyleBoxFlat.new()
    result.bg_color=background;result.border_color=border
    result.set_border_width_all(1);result.set_corner_radius_all(radius)
    result.content_margin_left=18;result.content_margin_right=18
    result.content_margin_top=10;result.content_margin_bottom=10
    return result

func _button(label: String) -> Button:
    var button:=Button.new();button.text=label
    button.custom_minimum_size=Vector2(0,64)
    button.add_theme_font_size_override("font_size",21)
    button.add_theme_color_override("font_color",Color(.87,.94,.90))
    button.add_theme_color_override("font_pressed_color",Color(.96,1.0,.97))
    button.add_theme_stylebox_override("normal",_style(Color(.075,.095,.095,.98),Color(.32,.44,.39,.75)))
    button.add_theme_stylebox_override("hover",_style(Color(.11,.17,.15,1),Color(.64,.83,.72,.9)))
    button.add_theme_stylebox_override("pressed",_style(Color(.12,.29,.24,1),Color(.68,.92,.78,1)))
    button.add_theme_stylebox_override("hover_pressed",_style(Color(.15,.33,.27,1),Color(.76,.98,.85,1)))
    var focus:=_style(Color(0,0,0,0),Color(.85,1.0,.91,1))
    focus.set_border_width_all(2)
    button.add_theme_stylebox_override("focus",focus)
    return button

func _layout() -> void:
    if not is_instance_valid(panel):return
    var available:=size-Vector2(32,32)
    var dimensions:=Vector2(minf(760,available.x),minf(570,available.y))
    panel.size=Vector2(maxf(1,dimensions.x),maxf(1,dimensions.y))
    panel.position=(size-panel.size)*.5

func _keep_focus_inside() -> void:
    # Keyboard/gamepad navigation must not select launch buttons under the modal.
    var order: Array[Button]=[]
    for mode in MODE_ORDER:order.append(mode_buttons[mode])
    order.append(reset_button);order.append(close_button)
    for index in range(order.size()):
        var button:=order[index]
        var before:=button.get_path_to(order[(index+order.size()-1)%order.size()])
        var after:=button.get_path_to(order[(index+1)%order.size()])
        button.focus_previous=before;button.focus_next=after
        button.focus_neighbor_top=before;button.focus_neighbor_bottom=after
        button.focus_neighbor_left=button.get_path_to(button)
        button.focus_neighbor_right=button.get_path_to(button)
    reset_button.focus_neighbor_right=reset_button.get_path_to(close_button)
    close_button.focus_neighbor_left=close_button.get_path_to(reset_button)

func _refresh() -> void:
    if not is_instance_valid(current_line):return
    var available:=_settings!=null and _settings.has_method("get_summary")
    for button in mode_buttons.values():button.disabled=not available
    reset_button.disabled=not available
    if not available:
        current_line.text="Настройки графики недоступны."
        return
    var data: Dictionary=_settings.call("get_summary")
    var mode:=str(data.get("mode","auto"))
    var profile:=str(data.get("profile","high"))
    var effective: String=MODE_LABELS.get(profile,"Качество")
    var fps:=int(data.get("target_fps",60))
    var rate: String="%d кадров/с"%fps if fps>0 else "Без лимита кадров"
    current_line.text="Авто · %s · %s"%[effective,rate] if mode=="auto" else "%s · %s"%[effective,rate]
    for key in mode_buttons:mode_buttons[key].set_pressed_no_signal(key==mode)

func open_panel() -> void:
    _refresh();show();_layout();set_process_unhandled_input(true)
    var mode: String="auto"
    if _settings!=null and _settings.has_method("get_summary"):
        mode=str(_settings.call("get_summary").get("mode","auto"))
    var chosen: Button=mode_buttons.get(mode,mode_buttons["auto"])
    chosen.grab_focus()

func close_panel() -> void:
    if not visible:return
    hide();set_process_unhandled_input(false);closed.emit()

func _choose_mode(mode: String) -> void:
    if _settings!=null and _settings.has_method("set_mode"):_settings.call("set_mode",mode)
    _refresh()

func _redetect() -> void:
    if _settings!=null and _settings.has_method("redetect"):_settings.call("redetect")
    _refresh();mode_buttons["auto"].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        close_panel()
