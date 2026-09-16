class_name WorldCollision
extends RefCounted

# Pure world-grid collision query. No runtime state is stored here.
static func is_wall(x: float, z: float) -> bool:
    var cell_x := int(floor(x / LevelData.CELL_SIZE + 10.0))
    var cell_z := int(floor(z / LevelData.CELL_SIZE + 7.0))
    if cell_x < 0 or cell_x >= LevelData.MAP_WIDTH or cell_z < 0 or cell_z >= LevelData.MAP_HEIGHT:
        return true
    return LevelData.CANONICAL_MAP[cell_z].substr(cell_x, 1) == "1"
