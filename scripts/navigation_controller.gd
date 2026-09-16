class_name NavigationController
extends RefCounted

# Presentation/navigation helper. It owns only scene navigation; gameplay state
# remains in game.gd.

var menu_button: Button
var tree: SceneTree

func setup(button: Button, scene_tree: SceneTree) -> void:
    menu_button = button
    tree = scene_tree
    menu_button.pressed.connect(_on_menu_pressed)

func _on_menu_pressed() -> void:
    tree.change_scene_to_file("res://menu.tscn")
