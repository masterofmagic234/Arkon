extends Node

signal health_changed(actor: Node, current: int, maximum: int)
signal weapon_changed(actor: Node, weapon: StringName, ammo: int)
signal enemy_defeated(enemy_id: StringName)
signal mission_changed(level_id: StringName, status: StringName)
signal level_completed(level_id: StringName)
signal combat_event(kind: StringName, position: Vector2)

# Level 3 event bus. Actor references are included so the global bus remains
# usable if more than one Level 3 scene or actor is ever active.
signal level3_player_fire_requested(player: Node, origin: Vector2, direction: Vector2, weapon: StringName)
signal level3_player_action_requested(player: Node)
signal level3_player_throw_requested(player: Node, origin: Vector2, direction: Vector2)
signal level3_player_died(player: Node)
signal level3_player_weapon_changed(player: Node, weapon: StringName, ammo: int)
signal level3_enemy_shot_requested(enemy: Node, origin: Vector2, direction: Vector2)
signal level3_enemy_defeated(enemy: Node)
signal level3_pickup_collected(pickup: Node, kind: StringName)
