class_name MissionProgressQuery
extends RefCounted

# Pure mission-progress checks. State mutation remains in game.gd.
static func is_complete(collected: int, acorn_count: int) -> bool:
    return collected == acorn_count
