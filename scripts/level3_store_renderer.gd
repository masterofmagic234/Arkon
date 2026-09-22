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
    pass

