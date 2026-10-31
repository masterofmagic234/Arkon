extends Control
class_name Level3Dialogue
## Modal arcade conversation: pixel face, typewriter, reveal/advance, no auto-skip.

signal started
signal line_changed(index: int)
signal finished

const Portraits = preload("res://scripts/level3_dialogue_portraits.gd")
const Voice = preload("res://scripts/dialogue_voice158.gd")
const FONT_PATH := "res://assets/level3/dialogue/dialogue-mono-bold.ttf"
const LETTERS_PER_SECOND := 39.0
const MOUTH_CADENCE := [0, 1, 2, 1, 0, 1, 0, 2]

@onready var panel: Panel = $Panel
@onready var speaker_label: Label = $Panel/Speaker
@onready var text_label: Label = $Panel/Text
@onready var prompt_label: Label = $Panel/Prompt

var portrait: TextureRect
var portrait_border: Panel
var _lines: Array[Dictionary] = []
var _index := -1
var _active := false
var _letter_count := 0.0
var _clock := 0.0
var _line_clock := 0.0
var _guard := 0.0
var _fully_revealed := false
var _touches: Dictionary = {}
var _suppress_mouse_until := 0
var current_portrait_key := "carolina"
var portrait_frame := -1
var _layout_root: Control
var _speaker_rule: ColorRect
var _footer_rule: ColorRect
var voice

func _ready() -> void:
    voice = Voice.new()
    add_child(voice)
    visible = false
    z_index = 100
    # Modal presses are consumed in _input, leaving the real pause button free.
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _layout_root = Control.new()
    _layout_root.name = "PixelFrame"
    _layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_layout_root)
    panel.reparent(_layout_root, false)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color("180e22")
    style.border_color = Color("e951a8")
    style.set_border_width_all(2)
    style.shadow_color = Color(0, 0, 0, .75)
    style.shadow_size = 8
    panel.add_theme_stylebox_override("panel", style)
    portrait_border = Panel.new()
    portrait_border.name = "PortraitBorder"
    portrait_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var border := StyleBoxFlat.new()
    border.bg_color = Color("130c1c")
    border.border_color = Color("9af1e9")
    border.set_border_width_all(2)
    portrait_border.add_theme_stylebox_override("panel", border)
    panel.add_child(portrait_border)
    portrait = TextureRect.new()
    portrait.name = "AnimatedPortrait"
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait_border.add_child(portrait)
    _speaker_rule = ColorRect.new()
    _speaker_rule.color = Color("e951a8")
    _speaker_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(_speaker_rule)
    _footer_rule = ColorRect.new()
    _footer_rule.color = Color("56324e")
    _footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(_footer_rule)
    var font := load(FONT_PATH) as FontFile
    if font != null:
        font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
        font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
        for label in [speaker_label, text_label, prompt_label]:
            label.add_theme_font_override("font", font)
    for label in [speaker_label, text_label, prompt_label]:
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.add_theme_color_override("font_outline_color", Color("0b0812"))
        label.add_theme_constant_override("outline_size", 2)
    speaker_label.add_theme_color_override("font_color", Color("fa79bf"))
    speaker_label.add_theme_font_size_override("font_size", 22)
    text_label.add_theme_color_override("font_color", Color("d2fff5"))
    text_label.add_theme_font_size_override("font_size", 24)
    text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    prompt_label.add_theme_color_override("font_color", Color("baa7bd"))
    prompt_label.add_theme_font_size_override("font_size", 13)
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    get_viewport().size_changed.connect(_layout)
    _layout()

func _layout() -> void:
    if _layout_root == null: return
    var viewport := get_viewport_rect().size
    var fit := minf(viewport.x / 1280.0, viewport.y / 720.0)
    fit = maxf(fit, .25)
    _layout_root.scale = Vector2.ONE * fit
    var logical := viewport / fit
    _layout_root.size = logical
    _place(panel, Vector2(24, logical.y - 232), Vector2(logical.x - 48, 208))
    _place(portrait_border, Vector2(10, 10), Vector2(188, 188))
    _place(portrait, Vector2(3, 3), Vector2(182, 182))
    var left := 220.0
    var right := panel.size.x - 22
    _place(speaker_label, Vector2(left, 13), Vector2(right - left, 29))
    _place(_speaker_rule, Vector2(left, 47), Vector2(right - left, 2))
    _place(text_label, Vector2(left, 61), Vector2(right - left, 106))
    _place(_footer_rule, Vector2(left, 176), Vector2(right - left, 1))
    _place(prompt_label, Vector2(left, 184), Vector2(right - left, 20))

func _place(control: Control, position_: Vector2, size_: Vector2) -> void:
    control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    control.position = position_
    control.size = size_

func start_dialogue(lines: Array[Dictionary]) -> void:
    voice.stop_voice()
    _lines = lines.duplicate(true)
    _index = -1
    _clock = 0.0
    _touches.clear()
    _active = not _lines.is_empty()
    visible = _active
    if not _active: return
    var hud := get_parent()
    if hud.has_method("clear_touches"): hud.clear_touches()
    started.emit()
    _next_line()

func advance() -> void:
    if not _active or get_tree().paused or _guard > 0.0: return
    # The same button first reveals the current line, then advances the page.
    if not _fully_revealed:
        text_label.visible_characters = -1
        _fully_revealed = true
        _guard = .13
        _update_prompt()
        _update_portrait()
        return
    if _index + 1 >= _lines.size():
        _finish()
    else:
        _next_line()

func _next_line() -> void:
    _index += 1
    var entry := _lines[_index]
    voice.play_dialogue(entry)
    speaker_label.text = String(entry.get("speaker", ""))
    text_label.text = String(entry.get("text", ""))
    text_label.visible_characters = 0
    _letter_count = 0.0
    _fully_revealed = text_label.text.is_empty()
    _line_clock = 0.0
    _guard = .13
    current_portrait_key = Portraits.key_for(entry)
    portrait_frame = -1
    _update_portrait()
    _update_prompt()
    line_changed.emit(_index)

func _update_prompt() -> void:
    prompt_label.text = "ТАП / ENTER — ДАЛЬШЕ" if _fully_revealed else "ТАП / ENTER — ПОКАЗАТЬ ТЕКСТ"

func _process(delta: float) -> void:
    if not _active or get_tree().paused: return
    _clock += delta
    _line_clock += delta
    _guard = maxf(0.0, _guard - delta)
    if not _fully_revealed:
        _letter_count += delta * LETTERS_PER_SECOND
        text_label.visible_characters = mini(floori(_letter_count), text_label.text.length())
        if text_label.visible_characters >= text_label.text.length():
            text_label.visible_characters = -1
            _fully_revealed = true
            _update_prompt()
    _update_portrait()

func _update_portrait() -> void:
    if portrait == null: return
    var frame := 0
    var blink_phase := fmod(_clock + (.35 if current_portrait_key.begins_with("chef") else 0.0), 3.45)
    if blink_phase > 3.29:
        frame = 3
    elif not _fully_revealed or (is_instance_valid(voice) and voice.playing):
        frame = MOUTH_CADENCE[posmod(floori(_line_clock * 10.0), MOUTH_CADENCE.size())]
        if current_portrait_key == "chef" and frame == 2: frame = 1
    if frame != portrait_frame:
        portrait_frame = frame
        portrait.texture = Portraits.frame(current_portrait_key, frame)

func _finish() -> void:
    if not _active: return
    voice.stop_voice()
    _active = false
    visible = false
    _touches.clear()
    var hud := get_parent()
    if hud.has_method("clear_touches"): hud.clear_touches()
    finished.emit()

func cancel_dialogue() -> void:
    voice.stop_voice()
    _active = false
    visible = false
    _touches.clear()

func is_active() -> bool:
    return _active

func _on_pause_button(position_: Vector2) -> bool:
    var hud := get_parent()
    var pause_button: Variant = hud.get("_pause")
    if pause_button is Control and is_instance_valid(pause_button):
        return pause_button.get_global_rect().has_point(position_)
    return false

func _input(event: InputEvent) -> void:
    if not _active or get_tree().paused: return
    if event is InputEventKey:
        if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E] or event.is_action("l3_action"):
            if event.pressed and not event.echo: advance()
            get_viewport().set_input_as_handled()
        return
    if event is InputEventScreenTouch:
        if _on_pause_button(event.position): return
        _suppress_mouse_until = Time.get_ticks_msec() + 350
        if event.pressed:
            var first := _touches.is_empty()
            _touches[event.index] = true
            if first: advance()
        else:
            _touches.erase(event.index)
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if not _on_pause_button(event.position): get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        if _on_pause_button(event.position): return
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() >= _suppress_mouse_until:
            advance()
        get_viewport().set_input_as_handled()
