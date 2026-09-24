extends Node2D
class_name Level3StoreRenderer

const TILE_SIZE: int = 16
const AssetVisual = preload("res://scripts/level3_asset_visual.gd")
const StoreData = preload("res://scripts/level3_store_data.gd")

const WALL_H_TEXTURES := [
    "res://assets/level3/source/Walls/sprWallBrickH.png",
    "res://assets/level3/source/Walls/sprWallHeavyH.png",
    "res://assets/level3/source/Walls/sprWallSoftH.png",
    "res://assets/level3/source/Walls/sprWallHospitalH.png"
]
const WALL_V_TEXTURES := [
    "res://assets/level3/source/Walls/sprWallBrickV.png",
    "res://assets/level3/source/Walls/sprWallHeavyV.png",
    "res://assets/level3/source/Walls/sprWallSoftV.png",
    "res://assets/level3/source/Walls/sprWallHospitalV.png"
]
const CORNER_TEXTURES := [
    "res://assets/level3/source/Walls/sprCornerBrick.png",
    "res://assets/level3/source/Walls/sprCorner.png",
    "res://assets/level3/source/Walls/sprWalls_strip8.png"
]

var _map: PackedStringArray = PackedStringArray()
var _wall_h_textures: Array[Texture2D] = []
var _wall_v_textures: Array[Texture2D] = []
var _corner_textures: Array[Texture2D] = []
var _visual_nodes: Array[Node2D] = []

func setup(map_data: PackedStringArray) -> void:
    _map = map_data
    z_index = -20
    _load_textures()
    queue_redraw()

func _ready() -> void:
    z_index = -20
    scale = Vector2(1.5, 1.5)
    _load_textures()

func _load_textures() -> void:
    if _wall_h_textures.is_empty():
        for path in WALL_H_TEXTURES:
            var tex := AssetVisual.first_frame_texture(path)
            if tex != null:
                _wall_h_textures.append(tex)
    if _wall_v_textures.is_empty():
        for path in WALL_V_TEXTURES:
            var tex := AssetVisual.first_frame_texture(path)
            if tex != null:
                _wall_v_textures.append(tex)
    if _corner_textures.is_empty():
        for path in CORNER_TEXTURES:
            var tex := AssetVisual.first_frame_texture(path)
            if tex != null:
                _corner_textures.append(tex)

func _draw() -> void:
    if _map.is_empty():
        return

    # This renderer is a fallback foundation beneath the authored Level 3
    # layout. It keeps the map visually meaningful even when layout sprites or
    # the hidden TileMapLayer are unavailable.
    var map_width := _map[0].length()
    var map_height := _map.size()
    var world_size := Vector2(map_width * TILE_SIZE, map_height * TILE_SIZE)

    draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.025, 0.028, 0.035, 1.0), true)

    for y in range(map_height):
        var row: String = _map[y]
        for x in range(map_width):
            if x >= row.length():
                continue
            var tile := row.substr(x, 1)
            if tile != "#":
                continue

            var rect := Rect2(
                Vector2(x * TILE_SIZE, y * TILE_SIZE),
                Vector2(TILE_SIZE, TILE_SIZE)
            )
            var tex := _wall_texture_for_cell(x, y)
            if tex != null:
                draw_texture_rect(tex, rect, false, Color.WHITE)
            else:
                draw_rect(rect, Color(0.09, 0.095, 0.11, 1.0), true)

func _wall_texture_for_cell(x: int, y: int) -> Texture2D:
    var left_open := _is_walkable(x - 1, y)
    var right_open := _is_walkable(x + 1, y)
    var up_open := _is_walkable(x, y - 1)
    var down_open := _is_walkable(x, y + 1)

    if (left_open or right_open) and not (up_open or down_open):
        if not _wall_v_textures.is_empty():
            return _wall_v_textures[posmod(x + y, _wall_v_textures.size())]
    elif (up_open or down_open) and not (left_open or right_open):
        if not _wall_h_textures.is_empty():
            return _wall_h_textures[posmod(x + y, _wall_h_textures.size())]

    if not _corner_textures.is_empty():
        return _corner_textures[posmod(x * 3 + y, _corner_textures.size())]
    return null

func _is_walkable(x: int, y: int) -> bool:
    if y < 0 or y >= _map.size():
        return false
    if x < 0 or x >= _map[y].length():
        return false
    var tile := _map[y].substr(x, 1)
    return tile != "#"

