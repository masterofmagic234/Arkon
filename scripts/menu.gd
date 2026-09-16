extends Control

func _ready() -> void:
    $StartButton.grab_focus()

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://game.tscn")
