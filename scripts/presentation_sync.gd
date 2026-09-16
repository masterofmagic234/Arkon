extends RefCounted

# Presentation-only bridge. It does not own gameplay state.
func sync_hud(hud_view, collected: int, acorn_count: int, hp: int, ammo: int) -> void:
    hud_view.update_status(collected, acorn_count, hp, ammo)

func sync_minimap(minimap_view, player: CharacterBody3D, acorns: Array, squirrels: Array, stunned: Dictionary) -> void:
    minimap_view.set_game_state(player.global_position, player.rotation.y, acorns, squirrels, stunned)
