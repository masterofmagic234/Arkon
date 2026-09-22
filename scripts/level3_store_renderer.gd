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
    _rebuild_store_visuals()
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
    if _map.is_empty():
        return

    var width := _map[0].length()
    var height := _map.size()
    var world_size := Vector2(float(width * TILE_SIZE), float(height * TILE_SIZE))

    draw_rect(
        Rect2(Vector2.ZERO, world_size),
        Color(0.010, 0.010, 0.013, 1.0),
        true
    )

    _draw_room_floors()
    _draw_floor_vignette()
    _draw_architecture()
    _draw_doorway_frames()
    _draw_room_lighting()
    _draw_entry_exit_accents()

func _draw_room_floors() -> void:
    for region_data in StoreData.get_room_floor_regions():
        var cell_rect: Rect2 = region_data["rect"]
        var color: Color = region_data["color"]
        var world_rect := Rect2(
            cell_rect.position * float(TILE_SIZE),
            cell_rect.size * float(TILE_SIZE)
        )
        draw_rect(world_rect, color, true)

        var texture_path: String = region_data["texture"]
        var texture := AssetVisual.first_frame_texture(texture_path)
        if texture != null:
            draw_texture_rect(
                texture,
                world_rect.grow(-4.0),
                true,
                Color(1.0, 1.0, 1.0, float(region_data["alpha"]))
            )

func _draw_floor_vignette() -> void:
    for y in range(_map.size()):
        for x in range(_map[y].length()):
            if _map[y][x] == "#":
                continue

            var rect := Rect2(
                Vector2(x * TILE_SIZE, y * TILE_SIZE),
                Vector2(TILE_SIZE, TILE_SIZE)
            )

            draw_rect(
                rect,
                Color(0.0, 0.0, 0.0, 0.025),
                true
            )


func _draw_architecture() -> void:
    for y in range(_map.size()):
        for x in range(_map[y].length()):
            if _map[y][x] != "#":
                continue

            var cell := Vector2i(x, y)
            var position := Vector2(x * TILE_SIZE, y * TILE_SIZE)

            var above_walkable := _is_walkable(Vector2i(x, y - 1))
            var below_walkable := _is_walkable(Vector2i(x, y + 1))
            var left_walkable := _is_walkable(Vector2i(x - 1, y))
            var right_walkable := _is_walkable(Vector2i(x + 1, y))
            var style_index := _wall_style_index(cell)

            if above_walkable or below_walkable:
                var wall_y := 8.0
                if above_walkable and not below_walkable:
                    wall_y = 3.0
                elif below_walkable and not above_walkable:
                    wall_y = 13.0
                _draw_wall_face_h(position + Vector2(0.0, wall_y - 2.0), style_index)

            if left_walkable or right_walkable:
                var wall_x := 8.0
                if left_walkable and not right_walkable:
                    wall_x = 3.0
                elif right_walkable and not left_walkable:
                    wall_x = 13.0
                _draw_wall_face_v(position + Vector2(wall_x - 2.0, 0.0), style_index)

func _draw_wall_face_h(origin: Vector2, style_index: int) -> void:
    var face_rect := Rect2(origin, Vector2(TILE_SIZE, 4.0))
    draw_rect(face_rect, Color(0.10, 0.045, 0.055, 1.0), true)

    if not _wall_h_textures.is_empty():
        var texture := _wall_h_textures[style_index % _wall_h_textures.size()]
        draw_texture_rect(texture, face_rect, true)

func _draw_wall_face_v(origin: Vector2, style_index: int) -> void:
    var face_rect := Rect2(origin, Vector2(4.0, TILE_SIZE))
    draw_rect(face_rect, Color(0.10, 0.045, 0.055, 1.0), true)

    if not _wall_v_textures.is_empty():
        var texture := _wall_v_textures[style_index % _wall_v_textures.size()]
        draw_texture_rect(texture, face_rect, true)


func _draw_doorway_frames() -> void:
    # Door frames are real scene nodes. Do not paint another fake frame over them.
    pass


func _draw_room_lighting() -> void:
    # Lighting comes from room/furniture art; no giant debug-style circles.
    pass


func _draw_entry_exit_accents() -> void:
    draw_rect(
        Rect2(Vector2(1.2 * TILE_SIZE, 18.05 * TILE_SIZE), Vector2(5.0 * TILE_SIZE, 0.90 * TILE_SIZE)),
        Color(0.75, 0.08, 0.06, 0.24),
        true
    )

func _wall_style_index(cell: Vector2i) -> int:
    if cell.y <= 6:
        if cell.x >= 23:
            return 2
        if cell.x >= 10:
            return 0
        return 1

    if cell.y >= 16:
        return 2 if cell.x <= 11 else 1

    if cell.x >= 24:
        return 3
    return 0

func _is_walkable(cell: Vector2i) -> bool:
    if cell.y < 0 or cell.y >= _map.size():
        return false
    if cell.x < 0 or cell.x >= _map[cell.y].length():
        return false
    return _map[cell.y][cell.x] != "#"

func _rebuild_store_visuals() -> void:
    # Visual props now live in the mouse-editable Level3Layout scene.
    pass


func _add_asset(path: String, position: Vector2, scale: Vector2, z_value: int) -> void:
    var sprite := AssetVisual.static_sprite(path, scale)
    if sprite == null or sprite.texture == null:
        return

    sprite.position = position
    sprite.z_index = z_value
    add_child(sprite)
    _visual_nodes.append(sprite)
