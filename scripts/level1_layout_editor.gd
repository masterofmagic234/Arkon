@tool
extends Node3D

const MAP_WIDTH: int = 20
const MAP_HEIGHT: int = 14
const CELL_SIZE: float = 1.8

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
