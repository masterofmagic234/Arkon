class_name WorldCollision
extends RefCounted

const LevelData = preload("res://scripts/level_data.gd")

# Pure world-grid collision query. Door cells remain blocked for AI/pathing;
# opening a Level1Door removes the physical player collision, while enemies
# keep their zone boundaries intact.
static func is_wall(x: float, z: float) -> bool:
    var cell := LevelData.world_to_cell(x, z)
    if cell.x < 0 or cell.x >= LevelData.MAP_WIDTH or cell.y < 0 or cell.y >= LevelData.MAP_HEIGHT:
        return true
    return LevelData.CANONICAL_MAP[cell.y].substr(cell.x, 1) == "#"
