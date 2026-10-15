extends Control

@onready var level1_button: Button = $LevelButtons/Level1Button
@onready var level2_button: Button = $LevelButtons/Level2Button
@onready var level3_button: Button = $LevelButtons/Level3Button

func _ready() -> void:
    level1_button.grab_focus()
    # A device without a supported Vulkan driver can fall back. Display the
    # active renderer, not just the renderer requested in the project settings.
    var method := RenderingServer.get_current_rendering_method()
    var driver := RenderingServer.get_current_rendering_driver_name()
    var renderer_name: String={"forward_plus":"Forward+","mobile":"Mobile","gl_compatibility":"Compatibility"}.get(method,method)
    var driver_name: String={"vulkan":"Vulkan","opengl3":"OpenGL","opengl3_es":"OpenGL ES","d3d12":"Direct3D 12","metal":"Metal"}.get(driver,driver)
    $RendererStatus.text="%s  ·  %s / %s"%[ProjectSettings.get_setting("application/config/version",""),renderer_name,driver_name]

func _start_level(level_id: StringName) -> void:
    # Direct debug launch always starts from a clean run. SceneFlow remains the
    # single owner of scene navigation; GameState only receives the reset.
    GameState.start_new_run()
    SceneFlow.go_to(level_id)

func _on_level1_pressed() -> void:
    _start_level(&"level1")

func _on_level2_pressed() -> void:
    _start_level(&"level2")

func _on_level3_pressed() -> void:
    _start_level(&"level3")
