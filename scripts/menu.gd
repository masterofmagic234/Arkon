extends Control

@onready var level1_button: Button = $LevelButtons/Level1Button
@onready var level2_button: Button = $LevelButtons/Level2Button
@onready var level3_button: Button = $LevelButtons/Level3Button

func _ready() -> void:
    level1_button.grab_focus()

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
