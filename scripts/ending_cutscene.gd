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
var _her_bubble: Panel
var _her_text: Label
var _his_bubble: Panel
var _typing: Label
var _draft: Label
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

func _night_material(sleeping := false) -> ShaderMaterial:
    var m := ShaderMaterial.new();m.shader=NIGHT;m.set_shader_parameter("recolour_sleeping_pajamas",sleeping)
    if sleeping:preload("res://scripts/cinematic_garment151.gd").apply(m,0,0)
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
    _room=_texture(_world,ROOM_PATH,Rect2(Vector2.ZERO,SOURCE_SIZE));_room.material=_night_material(true)
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

func _build_phone() -> void:
    _phone_screen=_panel(_frame,Rect2(402,34,476,652),Color("0a1018"),Color("6e778a"))
    var header := _panel(_phone_screen,Rect2(14,14,448,86),Color("15232b"),Color("2c424a"))
    _label(header,"ДАНИЛ",Rect2(22,17,365,34),25,Color("dcfff8"))
    _label(header,"в сети",Rect2(24,53,365,22),15,Color("82b7a9"))
    _label(_phone_screen,"СЕГОДНЯ · 21:40",Rect2(90,120,300,30),15,Color("8d9ba8")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    _her_bubble=_panel(_phone_screen,Rect2(64,179,383,152),Color("284d48"),Color("507e70"))
    _her_text=_label(_her_bubble,HER_MESSAGE,Rect2(18,15,348,114),22,Color("e3f4ed"))
    _label(_her_bubble,"21:40  ✓✓",Rect2(246,124,122,20),13,Color("abd5be"))
    _typing=_label(_phone_screen,"Данил печатает...",Rect2(29,354,400,38),17,Color("9fc8c4"))
    _his_bubble=_panel(_phone_screen,Rect2(25,407,365,91),Color("192c36"),Color("365767"))
    _label(_his_bubble,HIS_MESSAGE,Rect2(17,14,332,52),22,Color("e4eef5"))
    _label(_his_bubble,"21:40",Rect2(278,66,67,18),13,Color("9ab0bd"))
    var input := _panel(_phone_screen,Rect2(21,559,434,68),Color("14202b"),Color("354756"))
    _draft=_label(input,"",Rect2(16,16,400,42),19,Color("c1d0de"))

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
    _her_text.visible_characters=-1
    _typing.visible=elapsed>=18 and elapsed<20.2
    _his_bubble.visible=elapsed>=20.2
    _draft.text=HER_MESSAGE.substr(0,clampi(int((elapsed-10.6)*18),0,HER_MESSAGE.length())) if elapsed<13.6 else ""
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

func skip_to_credits() -> void:
    if finishing:return
    for key in _audio:(_audio[key] as AudioStreamPlayer).stop()
    elapsed=CREDITS_AT;_audio_fired={"gasp":true,"narration":true,"twist":true,"squirrel":true}
    PauseManager.resume();_update_frame();finish_reason="skipped_to_credits"

func finish_to_menu() -> void:
    if finishing:return
    finishing=true;finish_reason="credits_finished" if finish_reason.is_empty() else finish_reason
    for key in _audio:(_audio[key] as AudioStreamPlayer).stop()
    PauseManager.resume();SceneFlow.go_to(&"menu")

func seek_for_capture(time: float) -> void:
    # Explicitly staged native acceptance only; ordinary playback never seeks.
    elapsed=clampf(time,0,FINISH_AT-.01)
    for key in _audio:(_audio[key] as AudioStreamPlayer).stop()
    _audio_fired={"gasp":true,"narration":true,"twist":true,"squirrel":true};_update_frame()

func _unhandled_input(event: InputEvent) -> void:
    if finishing:return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
            if elapsed>=CREDITS_AT:finish_to_menu()
            else:skip_to_credits()
            get_viewport().set_input_as_handled()

func _exit_tree() -> void:
    for key in _audio:
        var p: AudioStreamPlayer=_audio[key]
        if is_instance_valid(p):p.stop();p.stream=null
