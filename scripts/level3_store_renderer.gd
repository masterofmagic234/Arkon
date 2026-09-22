extends Node2D
class_name Level3StoreRenderer

const TILE_SIZE: int = 48
const AssetVisual = preload("res://scripts/level3_asset_visual.gd")
const StoreData = preload("res://scripts/level3_store_data.gd")

const FLOOR_PATH := "res://assets/level3/source/Floor/sprFloor_strip4.png"
const WALL_H_PATH := "res://assets/level3/source/Walls/sprWallBrickH.png"
const WALL_V_PATH := "res://assets/level3/source/Walls/sprWallBrickV.png"
const DOORFRAME_PATH := "res://assets/level3/source/Walls/sprDoorframeSoft.png"

var _map: PackedStringArray = PackedStringArray()
var _floor_texture: Texture2D
var _wall_h_texture: Texture2D
var _wall_v_texture: Texture2D
var _doorframe_texture: Texture2D
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
    if _doorframe_texture == null:
        _doorframe_texture = AssetVisual.first_frame_texture(DOORFRAME_PATH)

func _draw() -> void:
    if _map.is_empty():
        draw_rect(
            Rect2(-2000.0, -2000.0, 4000.0, 4000.0),
            Color(0.01, 0.012, 0.015, 1.0),
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
        Color(0.012, 0.013, 0.016, 1.0),
        true
    )

    _draw_floor_base()
    _draw_walls()
    _draw_door_openings()
    _draw_room_accents()
    _draw_entry_exit_accents()

func _draw_floor_base() -> void:
    for region_data in StoreData.get_room_floor_regions():
        var cell_rect: Rect2 = region_data["rect"]
        var color: Color = region_data["color"]
        var world_rect := Rect2(
            cell_rect.position * float(TILE_SIZE),
            cell_rect.size * float(TILE_SIZE)
        )
        draw_rect(world_rect, color, true)

    for y in range(_map.size()):
        for x in range(_map[y].length()):
            if _map[y][x] == "#":
                continue
            var cell := Vector2i(x, y)
            var rect := Rect2(
                Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE),
                Vector2(TILE_SIZE, TILE_SIZE)
            )
            draw_rect(
                rect.grow(-0.5),
                Color(0.02, 0.018, 0.022, 0.12),
                true
            )

            if _floor_texture != null:
                draw_texture_rect(
                    _floor_texture,
                    rect,
                    false,
                    Color(0.9, 0.9, 0.9, 0.12)
                )

func _draw_walls() -> void:
    for y in range(_map.size()):
        for x in range(_map[y].length()):
            if _map[y][x] != "#":
                continue

            var cell := Vector2i(x, y)
            var position := Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
            var rect := Rect2(position, Vector2(TILE_SIZE, TILE_SIZE))

            draw_rect(
                rect,
                Color(0.035, 0.026, 0.029, 1.0),
                true
            )

            var above_walkable := _is_walkable(Vector2i(x, y - 1))
            var below_walkable := _is_walkable(Vector2i(x, y + 1))
            var left_walkable := _is_walkable(Vector2i(x - 1, y))
            var right_walkable := _is_walkable(Vector2i(x + 1, y))

            if above_walkable:
                _draw_wall_band_h(rect.position + Vector2(0.0, 1.0), TILE_SIZE, 15.0)
            if below_walkable:
                _draw_wall_band_h(rect.position + Vector2(0.0, TILE_SIZE - 16.0), TILE_SIZE, 15.0)
            if left_walkable:
                _draw_wall_band_v(rect.position + Vector2(1.0, 0.0), 15.0, TILE_SIZE)
            if right_walkable:
                _draw_wall_band_v(rect.position + Vector2(TILE_SIZE - 16.0, 0.0), 15.0, TILE_SIZE)

            if above_walkable or below_walkable or left_walkable or right_walkable:
                draw_rect(
                    rect.grow(-18.0),
                    Color(0.015, 0.012, 0.014, 0.55),
                    true
                )

func _draw_wall_band_h(origin: Vector2, width: float, height: float) -> void:
    draw_rect(
        Rect2(origin, Vector2(width, height)),
        Color(0.18, 0.06, 0.08, 1.0),
        true
    )
    if _wall_h_texture != null:
        draw_texture_rect(
            _wall_h_texture,
            Rect2(origin, Vector2(width, height)),
            true
        )
    draw_line(
        origin + Vector2(0.0, height - 1.0),
        origin + Vector2(width, height - 1.0),
        Color(0.01, 0.008, 0.01, 0.85),
        2.0
    )

func _draw_wall_band_v(origin: Vector2, width: float, height: float) -> void:
    draw_rect(
        Rect2(origin, Vector2(width, height)),
        Color(0.18, 0.06, 0.08, 1.0),
        true
    )
    if _wall_v_texture != null:
        draw_texture_rect(
            _wall_v_texture,
            Rect2(origin, Vector2(width, height)),
            true
        )
    draw_line(
        origin + Vector2(width - 1.0, 0.0),
        origin + Vector2(width - 1.0, height),
        Color(0.01, 0.008, 0.01, 0.85),
        2.0
    )

func _draw_door_openings() -> void:
    for cell in StoreData.get_door_cells():
        var center := StoreData.cell_to_world(cell)
        var vertical := is_equal_approx(StoreData.door_rotation(cell), PI * 0.5)
        var opening_size := Vector2(44.0, 18.0)
        if vertical:
            opening_size = Vector2(18.0, 44.0)

        draw_rect(
            Rect2(center - opening_size * 0.5, opening_size),
            Color(0.008, 0.008, 0.010, 0.98),
            true
        )
        draw_rect(
            Rect2(center - opening_size * 0.5 - Vector2(2.0, 2.0), opening_size + Vector2(4.0, 4.0)),
            Color(0.30, 0.11, 0.10, 0.95),
            false,
            2.0
        )

        if _doorframe_texture != null:
            var frame_size := Vector2(54.0, 22.0)
            if vertical:
                frame_size = Vector2(22.0, 54.0)
            draw_texture_rect(
                _doorframe_texture,
                Rect2(center - frame_size * 0.5, frame_size),
                false,
                Color(1.0, 0.68, 0.45, 0.75)
            )

func _draw_room_accents() -> void:
    # Top service line: a continuous warm light, like a working back room.
    for x in range(10, 22):
        draw_rect(
            Rect2(float(x * TILE_SIZE) + 7.0, 54.0, TILE_SIZE - 14.0, 3.0),
            Color(1.0, 0.68, 0.34, 0.24),
            true
        )

    # Main hall: long shadows under the wall line and table islands.
    draw_line(
        Vector2(9.0 * TILE_SIZE, 8.0 * TILE_SIZE + 4.0),
        Vector2(22.0 * TILE_SIZE, 8.0 * TILE_SIZE + 4.0),
        Color(0.02, 0.018, 0.022, 0.45),
        5.0
    )
    draw_line(
        Vector2(9.0 * TILE_SIZE, 15.0 * TILE_SIZE - 4.0),
        Vector2(22.0 * TILE_SIZE, 15.0 * TILE_SIZE - 4.0),
        Color(0.02, 0.018, 0.022, 0.45),
        5.0
    )

    # Subtle floor seams: broad, low-contrast rather than a noisy checkerboard.
    for y in [2, 5, 10, 13, 17]:
        draw_line(
            Vector2(1.0 * TILE_SIZE, float(y * TILE_SIZE)),
            Vector2(31.0 * TILE_SIZE, float(y * TILE_SIZE)),
            Color(0.35, 0.30, 0.32, 0.05),
            1.0
        )

func _draw_entry_exit_accents() -> void:
    var entrance_rect := Rect2(
        Vector2(1.1 * TILE_SIZE, 18.0 * TILE_SIZE),
        Vector2(5.5 * TILE_SIZE, 1.0 * TILE_SIZE)
    )
    draw_rect(entrance_rect, Color(0.77, 0.11, 0.08, 0.30), true)

    var back_exit_rect := Rect2(
        Vector2(25.0 * TILE_SIZE, 18.0 * TILE_SIZE),
        Vector2(5.0 * TILE_SIZE, 1.0 * TILE_SIZE)
    )
    draw_rect(back_exit_rect, Color(0.98, 0.72, 0.22, 0.16), true)

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

    for entry in StoreData.get_furniture_layout():
        var tile_position: Vector2 = entry["position"]
        var sprite_scale: Vector2 = entry["scale"]
        _add_static_sprite(
            String(entry["texture"]),
            tile_position * float(TILE_SIZE),
            sprite_scale,
            int(entry["z"])
        )

    for entry in StoreData.get_product_layout():
        var product_position: Vector2 = entry["position"]
        _add_static_sprite(
            String(entry["texture"]),
            product_position * float(TILE_SIZE) + Vector2(0.0, -5.0),
            Vector2(1.10, 1.10),
            5
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
