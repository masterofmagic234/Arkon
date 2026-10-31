extends CanvasLayer
## A deliberately paused, readable field guide before the earned boss fight.
const ART := "res://assets/level1/guardian153/combat-guide.png"
const ThemeStyle=preload("res://scripts/pixel_interface_theme.gd")
var director: Node
var panel: Panel
var continue_button: Button
var _body: Control
var _title: Label
var _art: TextureRect
var _steps: Array[Label]=[]
var _hint: Label
var _elapsed:=0.0
var _owns_pause:=false
var _closed:=false
var _hud_process_mode:=Node.PROCESS_MODE_INHERIT
var _hud_suspended:=false
var _hud_was_visible:=true
var _player_input_was_enabled:=false
var _player_suspended:=false

func present(owner_: Node) -> void:
    director=owner_;layer=90;process_mode=Node.PROCESS_MODE_ALWAYS
    var backdrop:=ColorRect.new();backdrop.color=Color(0.025,.045,.065,.92);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(backdrop)
    panel=Panel.new();panel.add_theme_stylebox_override("panel",ThemeStyle.frame(Color("101b20"),Color("6bc8c2"),2,8));add_child(panel)
    # A plain child isolates wrapped-label minimum heights from the outer
    # panel. Initial zero-width VBox measurement otherwise expands it beyond
    # the phone screen before the first container layout has completed.
    _body=Control.new();panel.add_child(_body)
    _title=Label.new();_title.text="СТРАЖ ОРАНЖЕРЕИ";_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ThemeStyle.label(_title,Color("dcebe4"));_body.add_child(_title)
    _art=TextureRect.new();_art.name="GuardianSketch";_art.texture=load(ART);_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;_body.add_child(_art)
    for text in ["1 · ЧИТАЙ ЗАМАХ\nСтраж опускает голову\nперед прямым рывком.","2 · УЙДИ В СТОРОНУ\nРывок поперёк атаки.\nНе отступай по её линии.","3 · ЛОВИ ПЕРЕДЫШКУ\nСтреляй в открывшуюся\nгрудь, пока он отдыхает."]:
        var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;ThemeStyle.label(label,Color("c7d9d3"));_body.add_child(label);_steps.append(label)
    _hint=Label.new();_hint.text="Ворота остаются открыты: можно отойти и вернуться.";_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;ThemeStyle.label(_hint,Color("91aaa4"));_body.add_child(_hint)
    continue_button=Button.new();continue_button.name="Continue";continue_button.text="ГОТОВА";ThemeStyle.button(continue_button,ThemeStyle.RACE);continue_button.pressed.connect(dismiss);_body.add_child(continue_button)
    get_viewport().size_changed.connect(_layout);_layout()
    if is_instance_valid(director.hud):
        _hud_was_visible=director.hud.root.visible
        director.hud.release_controls();director.hud.root.hide()
        _hud_process_mode=director.hud.process_mode
        director.hud.process_mode=Node.PROCESS_MODE_DISABLED
        _hud_suspended=true
    _player_input_was_enabled=director.player.input_enabled
    _player_suspended=true
    director.player.stop();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    _owns_pause=not PauseManager.is_paused
    if _owns_pause:PauseManager.set_paused(true)

func _layout(settled:=false) -> void:
    if panel==null:return
    var size_: Vector2=get_viewport().get_visible_rect().size
    var ui_scale: float=clampf(minf(size_.x/1280.0,size_.y/720.0),1.0,1.75)
    var width: float=minf(1060,size_.x/ui_scale-32);var height: float=minf(560,size_.y/ui_scale-24)
    panel.position=(size_-Vector2(width,height)*ui_scale)*.5;panel.size=Vector2(width,height)*ui_scale
    _body.position=Vector2.ZERO;_body.size=Vector2(width,height);_body.scale=Vector2.ONE*ui_scale
    var short: bool=height<500
    var margin:=14.0 if short else 20.0
    var gap:=8.0 if short else 12.0
    var content: float=width-margin*2
    var title_height:=28.0 if short else 34.0
    var step_height:=88.0 if short else 104.0
    var hint_height:=30.0
    var button_height:=44.0 if short else 48.0
    var art_height: float=height-margin*2-title_height-step_height-hint_height-button_height-gap*4
    _title.add_theme_font_size_override("font_size",20 if short else 24)
    _title.position=Vector2(margin,margin);_title.size=Vector2(content,title_height)
    _art.position=Vector2(margin,margin+title_height+gap);_art.size=Vector2(content,art_height)
    var steps_y:=_art.position.y+art_height+gap
    var step_width:=(content-gap*2)/3.0
    for index in range(_steps.size()):
        var label:=_steps[index]
        label.add_theme_font_size_override("font_size",15 if short else 16)
        label.position=Vector2(margin+index*(step_width+gap),steps_y);label.size=Vector2(step_width,step_height)
    _hint.add_theme_font_size_override("font_size",12 if short else 14)
    _hint.position=Vector2(margin,steps_y+step_height+gap);_hint.size=Vector2(content,hint_height)
    continue_button.position=Vector2(margin,_hint.position.y+hint_height+gap);continue_button.size=Vector2(content,button_height)
    # Width changes update a wrapped Label's minimum height on the next
    # container pass. Apply the bounded heights again after that measurement.
    if not settled:_layout.call_deferred(true)

func _process(delta: float) -> void:_elapsed+=delta

func _input(event: InputEvent) -> void:
    var close_action: bool=event.is_action_pressed(&"ui_cancel")
    var close_key: bool=event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE] or event.keycode in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE])
    if close_action or close_key:
        get_viewport().set_input_as_handled()
        if _elapsed>.35:dismiss()

func dismiss() -> void:
    if _closed:return
    _closed=true
    _restore_hud()
    if _owns_pause:PauseManager.resume()
    _restore_player()
    if is_instance_valid(director) and director.player.desktop_mode:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
    queue_free()

func _exit_tree() -> void:
    _restore_hud()
    if not _closed and _owns_pause and is_instance_valid(director):
        PauseManager.resume()
    _restore_player()

func _restore_hud() -> void:
    if not _hud_suspended:return
    _hud_suspended=false
    if is_instance_valid(director) and is_instance_valid(director.hud):
        director.hud.process_mode=_hud_process_mode
        director.hud.root.visible=_hud_was_visible;director.hud.release_controls()

func _restore_player() -> void:
    if not _player_suspended:return
    _player_suspended=false
    if is_instance_valid(director) and is_instance_valid(director.player):
        if _player_input_was_enabled:director.player.resume()
        else:director.player.input_enabled=false
