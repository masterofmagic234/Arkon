extends Node3D
class_name Level1Navigation

const LevelData = preload("res://scripts/level_data.gd")

var region: NavigationRegion3D

func setup() -> void:
    if region != null:
        return
    region = NavigationRegion3D.new()
    region.name = "Level1NavigationRegion"
    region.position = Vector3(LevelData.MAP_WORLD_ORIGIN.x, 0.0, LevelData.MAP_WORLD_ORIGIN.y)
    region.enabled = true
    add_child(region)

    var nav_mesh := NavigationMesh.new()
    nav_mesh.vertices = _build_vertices()
    _add_walkable_polygons(nav_mesh)
    region.navigation_mesh = nav_mesh

func _build_vertices() -> PackedVector3Array:
    var vertices := PackedVector3Array()
    var cell := float(LevelData.CELL_SIZE)
    for y in range(LevelData.MAP_HEIGHT):
        for x in range(LevelData.MAP_WIDTH):
            if not _is_walkable(Vector2i(x, y)):
                continue
            var base := Vector3(float(x) * cell, 0.0, float(y) * cell)
            vertices.append(base)
            vertices.append(base + Vector3(cell, 0.0, 0.0))
            vertices.append(base + Vector3(cell, 0.0, cell))
            vertices.append(base + Vector3(0.0, 0.0, cell))
    return vertices

func _add_walkable_polygons(nav_mesh: NavigationMesh) -> void:
    var vertex_base := 0
    for y in range(LevelData.MAP_HEIGHT):
        for x in range(LevelData.MAP_WIDTH):
            if not _is_walkable(Vector2i(x, y)):
                continue
            nav_mesh.add_polygon(PackedInt32Array([
                vertex_base, vertex_base + 1, vertex_base + 2, vertex_base + 3
            ]))
            vertex_base += 4

func _is_walkable(cell: Vector2i) -> bool:
    if cell.x < 0 or cell.x >= LevelData.MAP_WIDTH or cell.y < 0 or cell.y >= LevelData.MAP_HEIGHT:
        return false
    var row: String = str(LevelData.CANONICAL_MAP[cell.y])
    return cell.x < row.length() and row[cell.x] != "#"
