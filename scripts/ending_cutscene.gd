extends Control
## The original opening room is reused byte-for-byte beneath local acting layers.
const PixelStyle = preload("res://scripts/pixel_interface_theme.gd")
const ROOM_PATH := "res://assets/cinematics/ending151/room.png"
const ROOM_SHA256 := "6baa5984fb110c6bfab3a992d8157d129c3b52a01a7ed5721cb2149e6a25344f"
const ORIGINAL_ROOM_PATH := "res://art/intro/runway144/keyframes/01-sleep.png"
const BASE := Vector2(1280,720)
const SOURCE_SIZE := Vector2(1672,941)
const NIGHT = preload("res://shaders/cinematics/ending_night151.gdshader")
const NARRATION := "Хоть кошмары снятся нам временами, в них мало хорошего. Но одно всё-таки есть: самое приятное осознание, что всё это был лишь сон."
const HER_MESSAGE := "Ты не поверишь что мне только что приснилось......"
const HIS_MESSAGE := "вещай, любимая"
const NARRATION_AT := 29.0
const TWIST_AT := 49.5
const REVEAL_AT := 51.3
const CREDITS_AT := 55.5
const FINISH_AT := 84.0
const CREDITS_MUSIC_PATH := "res://assets/audio158/wenn.ogg"
var bed_polygon := PackedVector2Array([Vector2(88,386),Vector2(174,339),Vector2(204,270),Vector2(272,226),Vector2(342,224),Vector2(394,252),Vector2(440,337),Vector2(476,390),Vector2(509,449),Vector2(510,515),Vector2(456,554),Vector2(397,582),Vector2(284,594),Vector2(166,587),Vector2(118,551),Vector2(92,484)])

var ready_for_playback := false
var ready_for_play := false
var elapsed := 0.0
var finishing := false
var finish_reason := ""
var event_log: Array[String] = []
var _last_stage := ""
var _audio_fired: Dictionary = {}
var _frame: Control
var _world: Node2D
var _room: TextureRect
var _wake: Polygon2D
var _phone: Polygon2D
var _sweat: Node2D
var _old_phone_patch: Polygon2D
var _squirrel: TextureRect
var _craft: TextureRect
var _phone_screen: Panel
var _phone_surface: Panel
var _phone_chat: ScrollContainer
var _phone_messages: VBoxContainer
var _phone_font: SystemFont
var _phone_bold_font: SystemFont
var _her_row: HBoxContainer
var _his_row: HBoxContainer
var _her_bubble: PanelContainer
var _her_text: Label
var _his_bubble: PanelContainer
var _his_text: Label
var _typing: Label
var _draft: Label
var _draft_placeholder: Label
var _subtitle_panel: Panel
var _subtitle: Label
var _credits: Control
var _credits_body: Control
var _credits_height := 0.0
var _pause_overlay: Panel
var _pause_button: Button
var _sound_button: Button
var _skip_button: Button
var _fade: ColorRect
var _audio: Dictionary = {}
var _reveal_voice: AudioStreamPlayer
var _credits_music: AudioStreamPlayer
var _credits_music_started := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _build_scene()
    resized.connect(_fit)
    PauseManager.pause_state_changed.connect(_on_pause)
    _fit()
    ready_for_playback = true
    ready_for_play = true
    _update_frame()
    _on_pause(PauseManager.is_paused)

func _panel(parent: Node, rect: Rect2, background: Color, border: Color) -> Panel:
    var p := Panel.new();p.position=rect.position;p.size=rect.size
    p.add_theme_stylebox_override("panel",PixelStyle.frame(background,border,2,0))
    p.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(p);return p

func _label(parent: Node, value: String, rect: Rect2, font_size := 22, colour := Color("d9dbea")) -> Label:
    var label := Label.new();label.text=value;label.position=rect.position;label.size=rect.size
    label.add_theme_font_override("font",PixelStyle.font());label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",colour);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label

func _button(parent: Node, value: String, rect: Rect2, action: Callable) -> Button:
    var b := Button.new();b.text=value;b.position=rect.position;b.size=rect.size
    PixelStyle.button(b,{"text":Color("e2e0ee"),"background":Color("111421"),"accent":Color("9d91bd"),"inset":Color("080c17"),"muted":Color("827e91"),"rule":Color("464358")})
    b.add_theme_font_size_override("font_size",16);b.focus_mode=Control.FOCUS_NONE;b.pressed.connect(action);parent.add_child(b);return b

func _night_material() -> ShaderMaterial:
    var m := ShaderMaterial.new();m.shader=NIGHT;m.set_shader_parameter("recolour_sleeping_pajamas",false)
    return m

func _texture(parent: Node, path: String, rect: Rect2) -> TextureRect:
    var t := TextureRect.new();t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode=TextureRect.STRETCH_SCALE;t.texture=load(path);t.position=rect.position;t.size=rect.size
    t.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(t);return t

func _polygon(parent: Node, path: String, points: PackedVector2Array) -> Polygon2D:
    var p := Polygon2D.new();p.texture=load(path);p.polygon=points;p.uv=points
    p.material=_night_material();parent.add_child(p);return p

func _build_scene() -> void:
    var black := ColorRect.new();black.color=Color.BLACK;black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);black.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(black)
    _frame=Control.new();_frame.name="CinematicFrame";_frame.size=BASE;_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_frame)
    _world=Node2D.new();_world.name="CanonicalBedroom";_frame.add_child(_world)
    _room=_texture(_world,ROOM_PATH,Rect2(Vector2.ZERO,SOURCE_SIZE));_room.material=_night_material()
    _wake=_polygon(_world,"res://assets/cinematics/ending151/wake.png",bed_polygon)
    _phone=_polygon(_world,"res://assets/cinematics/ending151/phone.png",bed_polygon)
    (_wake.material as ShaderMaterial).set_shader_parameter("acting_layer",true)
    (_phone.material as ShaderMaterial).set_shader_parameter("acting_layer",true)
    (_phone.material as ShaderMaterial).set_shader_parameter("phone_pose",true)
    _sweat=Node2D.new();_sweat.name="PerspirationGlints";_world.add_child(_sweat)
    for trace in [[Vector2(300,354),Vector2(299,357),Vector2(300,360)],[Vector2(323,426),Vector2(322,429),Vector2(323,431)]]:
        var glint:=Line2D.new();glint.points=PackedVector2Array(trace);glint.width=1.35
        glint.default_color=Color(.55,.71,.91,.68);glint.antialiased=true;_sweat.add_child(glint)
    _old_phone_patch=_polygon(_world,"res://assets/cinematics/ending151/phone.png",PackedVector2Array([Vector2(375,630),Vector2(580,630),Vector2(580,725),Vector2(375,725)]))
    _craft=_texture(_world,"res://assets/cinematics/ending151/craft.png",Rect2(1461,495,74,78));_craft.modulate=Color(.54,.63,.86,1)
    _squirrel=_texture(_world,"res://assets/cinematics/ending151/squirrel.png",Rect2(872,226,182,155));_squirrel.modulate=Color(.66,.75,.96,1)
    # Original indoor leaves remain in front of the animal outside the glass.
    _polygon(_world,ROOM_PATH,PackedVector2Array([Vector2(842,385),Vector2(865,354),Vector2(883,370),Vector2(907,344),Vector2(927,356),Vector2(951,365),Vector2(981,378),Vector2(1005,359),Vector2(1036,373),Vector2(1069,391),Vector2(1069,514),Vector2(842,514)]))
    _build_phone()
    _subtitle_panel=_panel(_frame,Rect2(110,578,1060,116),Color(.025,.035,.065,.94),Color("9a90b9"))
    _subtitle=_label(_subtitle_panel,"",Rect2(24,19,1012,85),23);_subtitle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _build_credits()
    _pause_button=_button(_frame,"II",Rect2(1218,20,44,42),_toggle_pause)
    _sound_button=_button(_frame,"ЗВУК",Rect2(1118,20,90,42),_toggle_sound)
    _skip_button=_button(_frame,"К ТИТРАМ",Rect2(954,20,154,42),skip_to_credits)
    _pause_overlay=_panel(_frame,Rect2(390,250,500,226),Color(.025,.035,.065,.97),Color("aaa0c9"))
    var paused := _label(_pause_overlay,"ПАУЗА",Rect2(24,24,452,45),30);paused.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _button(_pause_overlay,"ПРОДОЛЖИТЬ",Rect2(65,90,370,48),_resume)
    _button(_pause_overlay,"К ТИТРАМ",Rect2(65,152,370,48),skip_to_credits)
    _fade=ColorRect.new();_fade.color=Color.BLACK;_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_fade)
    for pair in [["gasp","res://assets/cinematics/ending151/gasp.ogg"],["narration","res://assets/cinematics/ending151/narration.ogg"],["twist","res://assets/cinematics/ending151/twist.ogg"],["squirrel","res://assets/level1/audio/voices149/voice_squirrel_warn_01.wav"]]:
        var audio := AudioStreamPlayer.new();audio.stream=load(pair[1]);audio.process_mode=Node.PROCESS_MODE_ALWAYS;audio.bus="Master";add_child(audio);_audio[pair[0]]=audio
    _reveal_voice=_audio.twist
    _credits_music=AudioStreamPlayer.new()
    _credits_music.name="CreditsMusic"
    _credits_music.bus="Master"
    _credits_music.process_mode=Node.PROCESS_MODE_ALWAYS
    add_child(_credits_music)
    if ResourceLoader.exists(CREDITS_MUSIC_PATH):
        _credits_music.stream=load(CREDITS_MUSIC_PATH) as AudioStream

func _phone_style(background: Color, radius: int, padding := Vector4.ZERO) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color=background
    style.set_corner_radius_all(radius)
    style.content_margin_left=padding.x
    style.content_margin_top=padding.y
    style.content_margin_right=padding.z
    style.content_margin_bottom=padding.w
    return style

func _phone_box(parent: Node, background: Color, radius: int, padding := Vector4.ZERO) -> PanelContainer:
    var box := PanelContainer.new()
    box.add_theme_stylebox_override("panel",_phone_style(background,radius,padding))
    box.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(box)
    return box

func _phone_text(parent: Node, value: String, font_size: int, colour: Color, bold := false, wrap := true) -> Label:
    # Configure shaping before inserting text. Manual size-before-text labels
    # can retain their initial unwrapped minimum width after font replacement.
    # Every phone label is then sized by its Container, never by a stale rect.
    var label := Label.new()
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
    label.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
    label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    label.add_theme_font_override("font",_phone_bold_font if bold else _phone_font)
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",colour)
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.text=value
    parent.add_child(label)
    return label

func _phone_message(parent: HBoxContainer, value: String, outgoing: bool) -> PanelContainer:
    var bubble := _phone_box(parent,Color("244b43") if outgoing else Color("22313b"),14,Vector4(13,10,13,7))
    bubble.custom_minimum_size.x=268 if outgoing else 208
    bubble.size_flags_horizontal=Control.SIZE_SHRINK_END if outgoing else Control.SIZE_SHRINK_BEGIN
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation",4)
    bubble.add_child(content)
    var message := _phone_text(content,value,18,Color("edf4f1"))
    message.name="MessageText"
    var timestamp := _phone_text(content,"21:40  ✓✓" if outgoing else "21:40",10,Color("9cbbb0") if outgoing else Color("96a9b4"),false,false)
    timestamp.name="MessageTimestamp"
    timestamp.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    if outgoing:_her_text=message
    else:_his_text=message
    return bubble

func _build_phone() -> void:
    # This insert is a physical portrait phone, not another game HUD panel.
    # It remains inside the original insert area and follows the cinematic fit.
    _phone_font=SystemFont.new()
    _phone_font.font_names=PackedStringArray(["Noto Sans","Roboto","DejaVu Sans","sans-serif"])
    _phone_bold_font=SystemFont.new()
    _phone_bold_font.font_names=_phone_font.font_names
    _phone_bold_font.font_weight=600
    _phone_screen=Panel.new()
    _phone_screen.name="PhoneDevice"
    _phone_screen.position=Vector2(468,27)
    _phone_screen.size=Vector2(344,666)
    _phone_screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _phone_screen.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
    var chassis := _phone_style(Color("090c10"),34)
    chassis.set_border_width_all(2)
    chassis.border_color=Color("65717a")
    chassis.shadow_color=Color(0,0,0,.7)
    chassis.shadow_size=18
    chassis.shadow_offset=Vector2(0,8)
    _phone_screen.add_theme_stylebox_override("panel",chassis)
    _frame.add_child(_phone_screen)
    for rect in [Rect2(-3,135,4,48),Rect2(-3,191,4,33),Rect2(343,158,4,68)]:
        var hardware := Panel.new()
        hardware.position=rect.position;hardware.size=rect.size
        hardware.add_theme_stylebox_override("panel",_phone_style(Color("66727a"),2))
        hardware.mouse_filter=Control.MOUSE_FILTER_IGNORE
        _phone_screen.add_child(hardware)
    _phone_surface=Panel.new()
    _phone_surface.name="PhoneDisplay"
    _phone_surface.position=Vector2(8,10)
    _phone_surface.size=Vector2(328,646)
    _phone_surface.clip_contents=true
    _phone_surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _phone_surface.add_theme_stylebox_override("panel",_phone_style(Color("101b24"),27))
    _phone_screen.add_child(_phone_surface)
    var app := VBoxContainer.new()
    app.name="PhoneAppLayout"
    app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    app.add_theme_constant_override("separation",0)
    app.mouse_filter=Control.MOUSE_FILTER_IGNORE
    _phone_surface.add_child(app)
    var status := HBoxContainer.new()
    status.custom_minimum_size.y=42
    status.add_theme_constant_override("separation",0)
    app.add_child(status)
    var time_margin := MarginContainer.new()
    time_margin.add_theme_constant_override("margin_left",22)
    status.add_child(time_margin)
    var time := _phone_text(time_margin,"21:40",12,Color("ecf2f5"),true,false)
    time.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    var status_space := Control.new();status_space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status.add_child(status_space)
    var indicators := Control.new();indicators.custom_minimum_size=Vector2(76,42);status.add_child(indicators)
    for bar in range(4):
        var signal_bar := ColorRect.new()
        signal_bar.color=Color("d7e0e5")
        signal_bar.position=Vector2(bar*4,25-bar*2)
        signal_bar.size=Vector2(2,4+bar*2)
        signal_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
        indicators.add_child(signal_bar)
    var battery := Panel.new();battery.position=Vector2(29,18);battery.size=Vector2(23,11)
    var battery_style := _phone_style(Color.TRANSPARENT,3)
    battery_style.set_border_width_all(1);battery_style.border_color=Color("d7e0e5")
    battery.add_theme_stylebox_override("panel",battery_style);indicators.add_child(battery)
    var charge := Panel.new();charge.position=Vector2(2,2);charge.size=Vector2(15,7)
    charge.add_theme_stylebox_override("panel",_phone_style(Color("d7e0e5"),1));battery.add_child(charge)
    var battery_tip := Panel.new();battery_tip.position=Vector2(53,21);battery_tip.size=Vector2(2,5)
    battery_tip.add_theme_stylebox_override("panel",_phone_style(Color("d7e0e5"),1));indicators.add_child(battery_tip)
    var camera_island := Panel.new();camera_island.position=Vector2(114,6);camera_island.size=Vector2(100,23)
    camera_island.add_theme_stylebox_override("panel",_phone_style(Color("030507"),12))
    _phone_surface.add_child(camera_island)
    var lens := Panel.new();lens.position=Vector2(80,7);lens.size=Vector2(8,8)
    lens.add_theme_stylebox_override("panel",_phone_style(Color("162433"),4));camera_island.add_child(lens)
    var header := _phone_box(app,Color.TRANSPARENT,0,Vector4(15,3,15,12))
    header.name="PhoneContactHeader"
    header.custom_minimum_size.y=74
    var header_row := HBoxContainer.new();header_row.add_theme_constant_override("separation",10);header.add_child(header_row)
    var back := _phone_text(header_row,"‹",30,Color("cedee8"),false,false)
    back.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
    back.custom_minimum_size.x=15;back.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    var avatar := _phone_box(header_row,Color("42666a"),21)
    avatar.custom_minimum_size=Vector2(42,42);avatar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    var initial := _phone_text(avatar,"Д",21,Color("e8f2ef"),true,false)
    initial.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;initial.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    var contact := VBoxContainer.new();contact.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    contact.size_flags_vertical=Control.SIZE_SHRINK_CENTER;contact.add_theme_constant_override("separation",1);header_row.add_child(contact)
    _phone_text(contact,"Данил",18,Color("e9f0f3"),true,false)
    _phone_text(contact,"в сети",12,Color("8fb8b0"),false,false)
    var menu := _phone_text(header_row,"⋮",24,Color("ccd9df"),false,false)
    menu.size_flags_horizontal=Control.SIZE_SHRINK_END;menu.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    _phone_chat=ScrollContainer.new()
    _phone_chat.name="ConversationViewport"
    _phone_chat.size_flags_vertical=Control.SIZE_EXPAND_FILL
    _phone_chat.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    _phone_chat.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
    _phone_chat.mouse_filter=Control.MOUSE_FILTER_IGNORE
    app.add_child(_phone_chat)
    var conversation_margin := MarginContainer.new()
    conversation_margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    for side in ["left","right"]:conversation_margin.add_theme_constant_override("margin_"+side,16)
    conversation_margin.add_theme_constant_override("margin_top",10)
    conversation_margin.add_theme_constant_override("margin_bottom",12)
    _phone_chat.add_child(conversation_margin)
    _phone_messages=VBoxContainer.new()
    _phone_messages.name="Messages"
    _phone_messages.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    _phone_messages.add_theme_constant_override("separation",12)
    conversation_margin.add_child(_phone_messages)
    var date := _phone_box(_phone_messages,Color("1c2b35"),10,Vector4(9,4,9,4))
    date.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
    _phone_text(date,"Сегодня · 21:40",10,Color("9eb0ba"),false,false)
    var message_gap := Control.new();message_gap.custom_minimum_size.y=6;_phone_messages.add_child(message_gap)
    _her_row=HBoxContainer.new();_her_row.name="OutgoingMessageRow";_phone_messages.add_child(_her_row)
    var outgoing_space := Control.new();outgoing_space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_her_row.add_child(outgoing_space)
    _her_bubble=_phone_message(_her_row,HER_MESSAGE,true)
    _her_bubble.name="TayaMessage"
    _typing=_phone_text(_phone_messages,"Данил печатает...",12,Color("9cbbb4"))
    _his_row=HBoxContainer.new();_his_row.name="IncomingMessageRow";_phone_messages.add_child(_his_row)
    _his_bubble=_phone_message(_his_row,HIS_MESSAGE,false)
    _his_bubble.name="DanilMessage"
    var incoming_space := Control.new();incoming_space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_his_row.add_child(incoming_space)
    var composer_margin := MarginContainer.new()
    for side in ["left","right"]:composer_margin.add_theme_constant_override("margin_"+side,12)
    composer_margin.add_theme_constant_override("margin_top",8)
    composer_margin.add_theme_constant_override("margin_bottom",6)
    app.add_child(composer_margin)
    var composer := _phone_box(composer_margin,Color("20313c"),23,Vector4(12,8,8,8))
    composer.name="MessageComposer";composer.custom_minimum_size.y=50
    var composer_row := HBoxContainer.new();composer_row.add_theme_constant_override("separation",8);composer.add_child(composer_row)
    var plus := _phone_text(composer_row,"+",23,Color("a8bec9"),false,false)
    plus.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;plus.custom_minimum_size.x=18;plus.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    var draft_stack := VBoxContainer.new();draft_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;draft_stack.size_flags_vertical=Control.SIZE_SHRINK_CENTER;composer_row.add_child(draft_stack)
    _draft=_phone_text(draft_stack,"",16,Color("dbe8ed"))
    _draft.name="DraftText";_draft.custom_minimum_size.y=24
    _draft_placeholder=_phone_text(draft_stack,"Сообщение",15,Color("8ea3af"))
    _draft_placeholder.custom_minimum_size.y=24
    var send := _phone_box(composer_row,Color("7eb8a5"),16)
    send.custom_minimum_size=Vector2(32,32);send.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    var send_arrow := _phone_text(send,"↑",21,Color("122c29"),true,false)
    send_arrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;send_arrow.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    var home := CenterContainer.new();home.custom_minimum_size.y=24;app.add_child(home)
    var home_bar := _phone_box(home,Color("c8d3d9"),2)
    home_bar.custom_minimum_size=Vector2(92,4)

func _build_credits() -> void:
    _credits=Control.new();_credits.name="Credits";_credits.size=BASE;_frame.add_child(_credits)
    var background := ColorRect.new();background.size=BASE;background.color=Color(.012,.018,.032,.97);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;_credits.add_child(background)
    _credits_body=Control.new();_credits_body.position=Vector2(220,170);_credits_body.size=Vector2(840,600);_credits.add_child(_credits_body)
    for pair in [["ACORN HUNTER",46],["ОПЕРАЦИЯ «ЖЁЛУДЬ»",27],["",16],["Автор проекта",20],["masterofmagic234",29],["",16],["Одна очень длинная ночь Таи",24],["Дарине — шесть жёлудей.\nТае — спокойных снов.",23],["",16],["Иллюстрации и катсцены",18],["Материалы проекта и предоставленные автором референсы",19],["",16],["Шрифт — DejaVu / Bitstream Vera",18],["DejaVu Fonts contributors · Stepan Roh",18],["Иллюстрации — ImageGen · озвучивание — Runway",18],["Остальные авторы и лицензии — в материалах игры",18],["",16],["СПАСИБО ЗА ИГРУ",31],["...и не забывайте закрывать окна.",20]]:
        var label := Label.new();label.text=pair[0];label.position=Vector2(0,_credits_height)
        label.size=Vector2(840,ceilf(float(pair[1])*1.4)*(String(pair[0]).count("\n")+1))
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_override("font",PixelStyle.font());label.add_theme_font_size_override("font_size",pair[1]);label.add_theme_color_override("font_color",Color("d3cbe7"));_credits_body.add_child(label)
        _credits_height+=label.size.y+30
    _credits_body.size.y=_credits_height
    _button(_credits,"В ГЛАВНОЕ МЕНЮ",Rect2(465,644,350,50),finish_to_menu)

func _fit() -> void:
    if not is_instance_valid(_frame):return
    var fit := minf(size.x/BASE.x,size.y/BASE.y)
    _frame.scale=Vector2.ONE*fit;_frame.position=(size-BASE*fit)*.5
    # The game is landscape, but a resized/portrait window must not turn the
    # phone insert into tiny text inside the letterboxed bedroom. Only the
    # insert grows; the original room composition and camera remain unchanged.
    if is_instance_valid(_phone_screen):
        var phone_zoom := 1.6 if size.y>size.x else 1.0
        _phone_screen.scale=Vector2.ONE*phone_zoom
        _phone_screen.position=BASE*.5-_phone_screen.size*phone_zoom*.5

func _process(delta: float) -> void:
    if not ready_for_playback or finishing:return
    _apply_audio_settings()
    if PauseManager.is_paused:return
    elapsed+=delta
    _update_frame()
    _trigger_audio()
    if elapsed>=FINISH_AT:finish_to_menu()

func stage_at(t: float) -> String:
    if t>=CREDITS_AT:return "credits"
    if t>=REVEAL_AT:return "squirrel"
    if t>=TWIST_AT:return "twist"
    if t>=26:return "window"
    if t>=24:return "typing_room"
    if t>=10:return "phone_chat"
    if t>=6.6:return "take_phone"
    if t>=1.4:return "wake"
    return "sleep"

func _update_frame() -> void:
    var stage := stage_at(elapsed)
    if stage!=_last_stage:event_log.append(stage);_last_stage=stage
    var woke := smoothstep(1.4,2.3,elapsed)
    var took_phone := smoothstep(6.6,8.1,elapsed)
    _wake.modulate.a=woke*(1-took_phone);_phone.modulate.a=took_phone
    _old_phone_patch.modulate.a=took_phone
    for actor in [_wake,_phone]:
        (actor.material as ShaderMaterial).set_shader_parameter("motion_time",elapsed)
    _sweat.visible=woke>.01 and took_phone<.99
    _sweat.modulate.a=woke*(1-took_phone)*(.55+.17*sin(elapsed*2.1))
    _phone_screen.visible=elapsed>=10 and elapsed<24
    _her_bubble.visible=elapsed>=13.6
    _her_row.visible=_her_bubble.visible
    _her_text.visible_characters=-1
    _typing.visible=elapsed>=18 and elapsed<20.2
    _his_bubble.visible=elapsed>=20.2
    _his_row.visible=_his_bubble.visible
    _draft.text=HER_MESSAGE.substr(0,clampi(int((elapsed-10.6)*18),0,HER_MESSAGE.length())) if elapsed<13.6 else ""
    _draft.visible=not _draft.text.is_empty()
    _draft_placeholder.visible=_draft.text.is_empty()
    var zoom_progress := smoothstep(26,48,elapsed)
    var focus := Vector2(836,470.5).lerp(Vector2(946,344),zoom_progress)
    var zoom := lerpf(1.0,3.0,zoom_progress)
    _world.scale=BASE/SOURCE_SIZE*zoom;_world.position=BASE*.5-focus*_world.scale
    var reveal := smoothstep(REVEAL_AT,REVEAL_AT+.72,elapsed)
    _squirrel.visible=elapsed>=REVEAL_AT and elapsed<CREDITS_AT
    _squirrel.modulate.a=reveal
    _squirrel.position.y=226+(1-reveal)*39
    _subtitle_panel.visible=elapsed>=NARRATION_AT and elapsed<CREDITS_AT
    if elapsed<TWIST_AT:
        if elapsed<34.4:_subtitle.text="Хоть кошмары снятся нам временами,\nв них мало хорошего."
        elif elapsed<38.8:_subtitle.text="Но одно всё-таки есть:\nсамое приятное осознание..."
        elif elapsed<48.0:_subtitle.text="...что всё это был лишь сон."
        else:_subtitle.text="......"
    else:_subtitle.text="......Или нет??"
    _credits.visible=elapsed>=CREDITS_AT
    # Fit the complete credits roll into its actual duration, including the
    # closing line on smaller screens. Font metrics determine the scroll range.
    var end_y := minf(170.0,565.0-_credits_height)
    var roll := smoothstep(CREDITS_AT,FINISH_AT-3.0,elapsed)
    _credits_body.position.y=lerpf(170.0,end_y,roll)
    _skip_button.visible=elapsed<CREDITS_AT
    _fade.color.a=1-smoothstep(0,1.0,elapsed)
    if elapsed>=CREDITS_AT-.8 and elapsed<CREDITS_AT:_fade.color.a=smoothstep(CREDITS_AT-.8,CREDITS_AT,elapsed)
    elif elapsed>=CREDITS_AT:_fade.color.a=1-smoothstep(CREDITS_AT,CREDITS_AT+.5,elapsed)
    if elapsed>=FINISH_AT-.8:_fade.color.a=smoothstep(FINISH_AT-.8,FINISH_AT,elapsed)

func _trigger_audio() -> void:
    for cue in [["gasp",1.4],["narration",NARRATION_AT],["twist",TWIST_AT],["squirrel",REVEAL_AT+.22]]:
        if elapsed>=cue[1] and not _audio_fired.has(cue[0]):
            _audio_fired[cue[0]]=true
            var p: AudioStreamPlayer=_audio[cue[0]];p.play()
    if elapsed>=CREDITS_AT:_start_credits_music()

func _start_credits_music() -> void:
    if _credits_music_started or not is_instance_valid(_credits_music) or _credits_music.stream==null:return
    _credits_music_started=true
    for key in _audio:(_audio[key] as AudioStreamPlayer).stop()
    AudioManager.register_music(_credits_music)
    _credits_music.stream_paused=PauseManager.is_paused

func _apply_audio_settings() -> void:
    for key in _audio:
        var p: AudioStreamPlayer=_audio[key]
        p.volume_db=-80 if GameState.sfx_muted else GameState.sfx_volume_db-(-1 if key=="narration" else 3)
    _sound_button.text="ЗВУК ×" if GameState.sfx_muted else "ЗВУК ✓"

func _toggle_sound() -> void:
    AudioManager.toggle_sfx();_apply_audio_settings()

func _toggle_pause() -> void:
    if not finishing:PauseManager.toggle()

func _resume() -> void:PauseManager.resume()

func _on_pause(paused: bool) -> void:
    if not is_instance_valid(_pause_overlay):return
    _pause_overlay.visible=paused
    _pause_button.text="▶" if paused else "II"
    for key in _audio:(_audio[key] as AudioStreamPlayer).stream_paused=paused
    if is_instance_valid(_credits_music):_credits_music.stream_paused=paused

func skip_to_credits() -> void:
    if finishing:return
    for key in _audio:(_audio[key] as AudioStreamPlayer).stop()
    elapsed=CREDITS_AT;_audio_fired={"gasp":true,"narration":true,"twist":true,"squirrel":true}
    PauseManager.resume();_update_frame();finish_reason="skipped_to_credits"
    _start_credits_music()

func finish_to_menu() -> void:
    if finishing:return
    finishing=true;finish_reason="credits_finished" if finish_reason.is_empty() else finish_reason
    for key in _audio:(_audio[key] as AudioStreamPlayer).stop()
    if is_instance_valid(_credits_music):_credits_music.stop()
    PauseManager.resume();SceneFlow.go_to(&"menu")

func seek_for_capture(time: float) -> void:
    # Explicitly staged native acceptance only; ordinary playback never seeks.
    elapsed=clampf(time,0,FINISH_AT-.01)
    for key in _audio:(_audio[key] as AudioStreamPlayer).stop()
    if is_instance_valid(_credits_music):_credits_music.stop()
    _credits_music_started=elapsed>=CREDITS_AT
    _audio_fired={"gasp":true,"narration":true,"twist":true,"squirrel":true};_update_frame()

func _unhandled_input(event: InputEvent) -> void:
    if finishing:return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
            if elapsed>=CREDITS_AT:finish_to_menu()
            else:skip_to_credits()
            get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    if is_instance_valid(_credits_music):
        _credits_music.stop()
        _credits_music.stream=null
    for key in _audio:
        var p: AudioStreamPlayer=_audio[key]
        if is_instance_valid(p):p.stop();p.stream=null
