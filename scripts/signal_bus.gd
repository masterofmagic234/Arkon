extends Node

signal health_changed(actor: Node, current: int, maximum: int)
signal weapon_changed(actor: Node, weapon: StringName, ammo: int)
signal enemy_defeated(enemy_id: StringName)
signal mission_changed(level_id: StringName, status: StringName)
signal level_completed(level_id: StringName)
signal combat_event(kind: StringName, position: Vector2)
