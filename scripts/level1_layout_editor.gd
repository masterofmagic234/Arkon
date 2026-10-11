@tool
extends Node3D

const LevelData = preload("res://scripts/level_data.gd")
const MAP_WIDTH: int = LevelData.MAP_WIDTH
const MAP_HEIGHT: int = LevelData.MAP_HEIGHT
const CELL_SIZE: float = LevelData.CELL_SIZE

func _ready() -> void:
    if Engine.is_editor_hint():
        notify_property_list_changed()

func _get_configuration_warnings() -> PackedStringArray:
    var warnings := PackedStringArray()
    if get_node_or_null("Walls") == null:
        warnings.append("Walls group is missing.")
    if get_node_or_null("Props") == null:
        warnings.append("Props group is missing.")
    if get_node_or_null("Pickups") == null:
        warnings.append("Pickups group is missing.")
    if get_node_or_null("Enemies") == null:
        warnings.append("Enemies group is missing.")
    return warnings
