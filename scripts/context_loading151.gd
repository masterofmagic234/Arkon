extends CanvasLayer
## Persistent transition artwork stays on screen through scene construction.
signal retry_requested
signal menu_requested

const Theme151 = preload("res://scripts/pixel_interface_theme.gd")
const ART := {
    &"level1": "res://assets/loading151/garden.png",
    &"level2": "res://assets/loading151/pursuit.png",
    &"level3": "res://assets/loading151/diner.png",
}
var screen: Control
var background: TextureRect
var shade: ColorRect
var frame: Panel
var chapter: Label
var title: Label
var description: Label
var status: Label
var progress: ProgressBar
var retry: Button
var menu: Button
var active := false
var failed := false
var target: StringName
var context: Dictionary = {}
var artwork_ready := false
var displayed_progress := 0.0
var _clock := 0.0
var _fade: Tween

func _ready() -> void:
    layer = 120
    process_mode = Node.PROCESS_MODE_ALWAYS
    screen = Control.new()
    screen.name = "ContextLoadingScreen"
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(screen)
    background = TextureRect.new()
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.add_child(background)
    shade = ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    screen.add_child(shade)
    frame = Panel.new()
    screen.add_child(frame)
    chapter = _label(15)
    title = _label(30)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description = _label(20)
    description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status = _label(14)
    progress = ProgressBar.new()
    progress.show_percentage = false
    progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_child(progress)
    retry = Button.new()
    retry.text = "ПОВТОРИТЬ"
    frame.add_child(retry)
    retry.pressed.connect(func(): retry_requested.emit())
    menu = Button.new()
    menu.text = "В МЕНЮ"
    frame.add_child(menu)
    menu.pressed.connect(func(): menu_requested.emit())
    screen.resized.connect(_layout)
    screen.hide()
    set_process(false)

func _label(font_size: int) -> Label:
    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    frame.add_child(label)
    return label

func present(level_id: StringName, data: Dictionary) -> void:
    if _fade != null and _fade.is_running(): _fade.kill()
    target = level_id
    context = data.duplicate(true)
    active = true
    failed = false
    displayed_progress = 0.0
    _clock = 0.0
    var palette: Dictionary = Theme151.RACE if level_id == &"level2" else Theme151.GARDEN
    if level_id == &"level3":
        palette = {"background":Color("180e22"), "inset":Color("130c1c"), "accent":Color("e951a8"), "text":Color("d2fff5"), "muted":Color("baa7bd"), "rule":Color("56324e")}
    var path: String = ART.get(level_id, "")
    artwork_ready = not path.is_empty() and ResourceLoader.exists(path)
    background.texture = load(path) as Texture2D if artwork_ready else null
    background.modulate = Color(.66, .70, .73)
    shade.color = Color(palette.inset, .46 if artwork_ready else 1.0)
    frame.add_theme_stylebox_override("panel", Theme151.frame(Color(palette.background, .95), palette.accent, 2, 8))
    for label in [chapter, title, description, status]: Theme151.label(label, palette.text)
    chapter.add_theme_color_override("font_color", palette.accent)
    status.add_theme_color_override("font_color", palette.muted)
    chapter.text = data.get("chapter", "ACORN HUNTER")
    title.text = data.get("title", "НОЧЬ ПРОДОЛЖАЕТСЯ")
    description.text = data.get("description", "")
    progress.add_theme_stylebox_override("background", Theme151.frame(palette.inset, palette.rule, 1))
    progress.add_theme_stylebox_override("fill", Theme151.frame(palette.accent, palette.accent, 0))
    for button in [retry, menu]:
        Theme151.button(button, palette)
        button.hide()
    screen.modulate.a = 1.0
    screen.show()
    set_progress(0.0)
    set_process(true)
    _layout()

func set_progress(value: float) -> void:
    displayed_progress = maxf(displayed_progress, clampf(value, 0.0, 1.0))
    progress.value = displayed_progress * 100.0

func show_failure() -> void:
    failed = true
    status.text = "НЕ УДАЛОСЬ ОТКРЫТЬ УРОВЕНЬ"
    retry.show()
    menu.show()
    retry.grab_focus()
    _layout()

func dismiss() -> void:
    if not active: return
    set_progress(1.0)
    if DisplayServer.get_name() != "headless":
        _fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        _fade.tween_property(screen, "modulate:a", 0.0, .18)
        await _fade.finished
    screen.hide()
    # The full-screen artwork is needed only while loading. Keeping the hidden
    # TextureRect populated retains its GPU texture for the entire next level.
    background.texture = null
    artwork_ready = false
    active = false
    failed = false
    set_process(false)

func _layout() -> void:
    var size_ := screen.get_viewport_rect().size
    var fit := maxf(.35, minf(size_.x / 1280.0, size_.y / 720.0))
    frame.scale = Vector2.ONE * fit
    var width := minf(1030.0, size_.x / fit - 64.0)
    frame.size = Vector2(width, 274 if failed else 228)
    frame.position = Vector2((size_.x - width * fit) * .5, maxf(22 * fit, size_.y - (frame.size.y + 38) * fit))
    chapter.position = Vector2(25, 18); chapter.size = Vector2(width - 50, 23)
    title.position = Vector2(25, 49); title.size = Vector2(width - 50, 48)
    description.position = Vector2(25, 107); description.size = Vector2(width - 50, 56)
    progress.position = Vector2(25, 176); progress.size = Vector2(width - 50, 5)
    status.position = Vector2(25, 194); status.size = Vector2(width - 50, 23)
    retry.position = Vector2(25, 230); retry.size = Vector2(200, 32)
    menu.position = Vector2(240, 230); menu.size = Vector2(200, 32)

func _process(delta: float) -> void:
    _clock += delta
    if not failed:
        status.text = "ЗАГРУЗКА" + ".".repeat(1 + int(_clock * 2.0) % 3)
    # Physical held actions must not bleed from the departing scene into play.
    for action in InputMap.get_actions():
        if String(action).begins_with("l1_") or String(action).begins_with("l3_") or String(action).begins_with("race_"):
            Input.action_release(action)

func _input(event: InputEvent) -> void:
    if active and not failed and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventJoypadButton):
        get_viewport().set_input_as_handled()
