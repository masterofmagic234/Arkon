extends Control

@onready var intro_button: Button = $LevelButtons/IntroButton
@onready var level1_button: Button = $LevelButtons/Level1Button
@onready var level2_button: Button = $LevelButtons/Level2Button
@onready var level3_button: Button = $LevelButtons/Level3Button
@onready var graphics_button: Button = $GraphicsButton
var graphics_panel

func _ready() -> void:
    intro_button.grab_focus()
    # A device without a supported Vulkan driver can fall back. Display the
    # active renderer, not just the renderer requested in the project settings.
    var method := RenderingServer.get_current_rendering_method()
    var driver := RenderingServer.get_current_rendering_driver_name()
    var renderer_name: String={"forward_plus":"Forward+","mobile":"Mobile","gl_compatibility":"Compatibility"}.get(method,method)
    var driver_name: String={"vulkan":"Vulkan","opengl3":"OpenGL","opengl3_es":"OpenGL ES","d3d12":"Direct3D 12","metal":"Metal"}.get(driver,driver)
    $RendererStatus.text="%s  ·  %s / %s"%[ProjectSettings.get_setting("application/config/version",""),renderer_name,driver_name]
    level1_button.text="ПРОДОЛЖИТЬ — БОТАНИЧЕСКИЙ САД" if FileAccess.file_exists(preload("res://scripts/botanical_state.gd").PATH) else "LEVEL 1 — БОТАНИЧЕСКИЙ САД"
    intro_button.text="НОВОЕ ПРИКЛЮЧЕНИЕ — С НАЧАЛА"
    var checkpoint=preload("res://scripts/botanical_state.gd").new();checkpoint.load_save()
    $Mode.text="НОЧНОЙ САД · БЕЛИЧИЙ ДОЗОР · ПРОРЫВ К МАШИНЕ"
    graphics_panel=preload("res://scripts/graphics_panel156.gd").new()
    graphics_panel.name="GraphicsPanel156"
    add_child(graphics_panel)
    graphics_panel.closed.connect(_on_graphics_closed)

func _on_graphics_pressed() -> void:
    graphics_panel.open_panel()

func _on_graphics_closed() -> void:
    graphics_button.grab_focus()

func _hide_graphics() -> void:
    if is_instance_valid(graphics_panel):graphics_panel.close_panel()

func _unhandled_input(event: InputEvent) -> void:
    # There is no pause overlay at the title screen. A child graphics modal
    # handles Escape first; a plain-menu Escape must not pause the scene tree.
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()

func _start_level(level_id: StringName) -> void:
    # Direct debug launch always starts from a clean run. SceneFlow remains the
    # single owner of scene navigation; GameState only receives the reset.
    _hide_graphics()
    GameState.start_new_run()
    SceneFlow.go_to(level_id)

func _on_level1_pressed() -> void:
    _hide_graphics()
    if FileAccess.file_exists(preload("res://scripts/botanical_state.gd").PATH):SceneFlow.go_to(&"level1")
    else:_start_level(&"level1")

func _on_level2_pressed() -> void:
    _start_level(&"level2")

func _on_level3_pressed() -> void:
    _start_level(&"level3")

func _on_intro_pressed() -> void:
    _start_level(&"intro")
