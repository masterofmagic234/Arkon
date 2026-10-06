extends Control

func _ready() -> void:
    $StartButton.grab_focus()

func _on_start_pressed() -> void:
    # A new run starts directly in Level 1. The unfinished intro is not part of
    # the playable campaign contract and must never block mobile progression.
    GameState.start_new_run()
    SceneFlow.go_to(&"level1")
