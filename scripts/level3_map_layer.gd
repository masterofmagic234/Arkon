extends TileMapLayer
class_name Level3MapLayer

const TILE_SIZE: int = 16
var navigation_region: NavigationRegion2D

func build_from_resource(map_data: Resource) -> void:
    if map_data == null:
        return
    visible = false
    _build_tileset()
    clear()
    var size: Vector2i = map_data.map_size()
    for y in range(size.y):
        for x in range(size.x):
            var cell := Vector2i(x, y)
            var tile_type: int = map_data.tile_at(cell)
            set_cell(cell, 0, Vector2i(0, 0) if tile_type == 0 else Vector2i(1, 0), 0)
    _build_navigation(map_data)

func _build_tileset() -> void:
    if tile_set != null:
        return
    var tileset := TileSet.new()
    tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
    var source := TileSetAtlasSource.new()
    source.texture = load("res://assets/level3/map_tiles.svg") as Texture2D
    source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
    source.create_tile(Vector2i(0, 0))
    source.create_tile(Vector2i(1, 0))
    tileset.add_source(source, 0)
    tile_set = tileset

func _build_navigation(map_data: Resource) -> void:
    if navigation_region != null and is_instance_valid(navigation_region):
        navigation_region.queue_free()
    navigation_region = NavigationRegion2D.new()
    navigation_region.name = "NavigationRegion2D"
    add_child(navigation_region)
    var navigation := NavigationPolygon.new()
    var vertices := PackedVector2Array()
    var polygons: Array[PackedInt32Array] = []
    var size: Vector2i = map_data.map_size()

    for y in range(size.y):
        for x in range(size.x):
            if map_data.tile_at(Vector2i(x, y)) == 1:
                continue
            var base := Vector2(float(x * TILE_SIZE), float(y * TILE_SIZE))
            var index := vertices.size()
            vertices.append(base)
            vertices.append(base + Vector2(TILE_SIZE, 0))
            vertices.append(base + Vector2(TILE_SIZE, TILE_SIZE))
            vertices.append(base + Vector2(0, TILE_SIZE))
            polygons.append(PackedInt32Array([index,index+1,index+2,index+3]))

    navigation.vertices = vertices
    for polygon in polygons:
        navigation.add_polygon(polygon)
    navigation_region.navigation_polygon = navigation
    navigation_region.enabled = true
