class_name WorldQueries
extends RefCounted

# Pure world queries. No runtime state is stored here.
static func find_squirrel_from_collider(collider: Object, squirrel_names: Array) -> String:
    var node := collider as Node
    while node != null:
        if squirrel_names.has(node.name):
            return node.name
        node = node.get_parent()
    return ""

static func is_wall(x: float, z: float, cell_size: float, map_width: int, map_height: int, canonical_map: Array) -> bool:
    var cell_x := int(floor((x - LevelData.MAP_WORLD_ORIGIN.x) / cell_size))
    var cell_z := int(floor((z - LevelData.MAP_WORLD_ORIGIN.y) / cell_size))
    if cell_x < 0 or cell_x >= map_width or cell_z < 0 or cell_z >= map_height:
        return true
    return canonical_map[cell_z].substr(cell_x, 1) == "#"
