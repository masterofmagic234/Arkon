extends Node2D
class_name Level3StoreRenderer

const TILE_SIZE: int = 48
const AssetVisual = preload("res://scripts/level3_asset_visual.gd")
const StoreData = preload("res://scripts/level3_store_data.gd")

const FLOOR_PATH := "res://assets/level3/source/Floor/sprFloor_strip4.png"
const WALL_H_PATH := "res://assets/level3/source/Walls/sprWallBrickH.png"
const WALL_V_PATH := "res://assets/level3/source/Walls/sprWallBrickV.png"
const SHELF_PATH := "res://assets/level3/source/Furniture/sprShelvesDown_strip4.png"
const STORE_SHELF_PATH := "res://assets/level3/source/Furniture/sprStoreShelf_strip3.png"
const FREEZER_PATH := "res://assets/level3/source/Furniture/sprFreezer_strip2.png"
const VENDING_PATH := "res://assets/level3/source/Furniture/sprVendingMachine.png"
const REGISTER_PATH := "res://assets/level3/source/Furniture/sprRegister.png"
const DRINK_PATH := "res://assets/level3/source/Items/sprDrink.png"
const CHIPS_PATH := "res://assets/level3/source/Items/sprChipsBag.png"

var _map: PackedStringArray = PackedStringArray()
var _floor_texture: Texture2D
var _wall_h_texture: Texture2D
var _wall_v_texture: Texture2D
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
    if _floor_texture == null:
        _floor_texture = AssetVisual.first_frame_texture(FLOOR_PATH)
    if _wall_h_texture == null:
        _wall_h_texture = AssetVisual.first_frame_texture(WALL_H_PATH)
    if _wall_v_texture == null:
        _wall_v_texture = AssetVisual.first_frame_texture(WALL_V_PATH)

func _draw() -> void:
    if _map.is_empty():
        draw_rect(
            Rect2(-2000.0, -2000.0, 4000.0, 4000.0),
            Color(0.015, 0.018, 0.022, 1.0),
            true
        )
        return

    var width := _map[0].length()
    var height := _map.size()
    var world_size := Vector2(float(width * TILE_SIZE), float(height * TILE_SIZE))

    draw_rect(
        Rect2(
            Vector2(-TILE_SIZE * 2.0, -TILE_SIZE * 2.0),
            world_size + Vector2(TILE_SIZE * 4.0, TILE_SIZE * 4.0)
        ),
        Color(0.012, 0.014, 0.018, 1.0),
        true
    )

    for y in range(height):
        for x in range(width):
            _draw_tile(Vector2i(x, y))

    _draw_store_lighting()
    _draw_entrance_strip()
    _draw_exit_strip()

func _draw_tile(cell: Vector2i) -> void:
    var position := Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
    var rect := Rect2(position, Vector2(TILE_SIZE, TILE_SIZE))
    var tile := _map[cell.y][cell.x]

    if tile != "#":
        if _floor_texture != null:
            draw_texture_rect(_floor_texture, rect, true)
        else:
            draw_rect(rect, Color(0.15, 0.13, 0.12, 1.0), true)

        draw_rect(
            rect.grow(-1.0),
            Color(0.02, 0.025, 0.03, 0.07),
            true
        )

        if tile == "D":
            draw_rect(
                rect.grow(-4.0),
                Color(0.07, 0.075, 0.08, 0.60),
                true
            )
        return

    draw_rect(rect, Color(0.035, 0.028, 0.026, 1.0), true)

    var above_walkable := _is_walkable(Vector2i(cell.x, cell.y - 1))
    var below_walkable := _is_walkable(Vector2i(cell.x, cell.y + 1))
    var left_walkable := _is_walkable(Vector2i(cell.x - 1, cell.y))
    var right_walkable := _is_walkable(Vector2i(cell.x + 1, cell.y))

    if _wall_h_texture != null:
        if above_walkable:
            draw_texture_rect(
                _wall_h_texture,
                Rect2(position, Vector2(TILE_SIZE, 9.0)),
                true
            )
        if below_walkable:
            draw_texture_rect(
                _wall_h_texture,
                Rect2(position + Vector2(0.0, TILE_SIZE - 9.0), Vector2(TILE_SIZE, 9.0)),
                true
            )

    if _wall_v_texture != null:
        if left_walkable:
            draw_texture_rect(
                _wall_v_texture,
                Rect2(position, Vector2(9.0, TILE_SIZE)),
                true
            )
        if right_walkable:
            draw_texture_rect(
                _wall_v_texture,
                Rect2(position + Vector2(TILE_SIZE - 9.0, 0.0), Vector2(9.0, TILE_SIZE)),
                true
            )

func _is_walkable(cell: Vector2i) -> bool:
    if cell.y < 0 or cell.y >= _map.size():
        return false
    if cell.x < 0 or cell.x >= _map[cell.y].length():
        return false
    return _map[cell.y][cell.x] != "#"

func _rebuild_store_visuals() -> void:
    for node in _visual_nodes:
        if is_instance_valid(node):
            node.queue_free()
    _visual_nodes.clear()

    # Props are placed from the same tactical layout used by collision generation.
    for entry in StoreData.get_furniture_layout():
        var tile_position: Vector2 = entry["position"]
        var sprite_scale: Vector2 = entry["scale"]
        _add_static_sprite(
            String(entry["texture"]),
            tile_position * float(TILE_SIZE),
            sprite_scale,
            int(entry["z"])
        )

    # Small visual clutter stays attached to furniture rather than on combat lanes.
    for entry in StoreData.get_product_layout():
        var product_position: Vector2 = entry["position"]
        _add_static_sprite(
            String(entry["texture"]),
            product_position * float(TILE_SIZE) + Vector2(0.0, -5.0),
            Vector2(1.15, 1.15),
            5
        )

func _cell_to_world(cell: Vector2i) -> Vector2:
    return Vector2(
        float(cell.x * TILE_SIZE) + TILE_SIZE * 0.5,
        float(cell.y * TILE_SIZE) + TILE_SIZE * 0.5
    )

func _add_static_sprite(
    path: String,
    position: Vector2,
    scale: Vector2,
    z_value: int
) -> void:
    var sprite := AssetVisual.static_sprite(path, scale)
    if sprite == null or sprite.texture == null:
        return

    sprite.position = position
    sprite.z_index = z_value
    add_child(sprite)
    _visual_nodes.append(sprite)

func _draw_store_lighting() -> void:
    var width := _map[0].length()

    for x in range(width):
        if _is_walkable(Vector2i(x, 1)):
            var center_x := float(x * TILE_SIZE) + TILE_SIZE * 0.5
            draw_rect(
                Rect2(center_x - 14.0, 21.0, 28.0, 4.0),
                Color(1.0, 0.68, 0.32, 0.32),
                true
            )

func _draw_entrance_strip() -> void:
    var top_left := Vector2(8.0 * TILE_SIZE, 0.0)
    draw_rect(
        Rect2(top_left + Vector2(2.0, 4.0), Vector2(3.0 * TILE_SIZE, 7.0)),
        Color(0.86, 0.12, 0.08, 0.85),
        true
    )
    draw_rect(
        Rect2(top_left + Vector2(2.0, 13.0), Vector2(3.0 * TILE_SIZE, 5.0)),
        Color(1.0, 0.73, 0.18, 0.72),
        true
    )

func _draw_exit_strip() -> void:
    var map_width := _map[0].length()
    var y := float((_map.size() - 1) * TILE_SIZE)
    for x in range(4, map_width - 4):
        if x % 2 == 0:
            draw_rect(
                Rect2(float(x * TILE_SIZE), y + 6.0, TILE_SIZE, 7.0),
                Color(0.96, 0.76, 0.24, 0.52),
                true
            )
