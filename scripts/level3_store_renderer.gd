extends Node2D
class_name Level3StoreRenderer

const TILE_SIZE: int = 48

var _map: PackedStringArray = PackedStringArray()

func setup(map_data: PackedStringArray) -> void:
    _map = map_data
    z_index = -20
    queue_redraw()

func _ready() -> void:
    z_index = -20
    queue_redraw()

func _draw() -> void:
    if _map.is_empty():
        draw_rect(Rect2(-2000.0, -2000.0, 4000.0, 4000.0), Color(0.025, 0.028, 0.034, 1.0), true)
        return

    var width := _map[0].length()
    var height := _map.size()
    var world_size := Vector2(float(width * TILE_SIZE), float(height * TILE_SIZE))

    draw_rect(
        Rect2(Vector2(-TILE_SIZE * 2.0, -TILE_SIZE * 2.0), world_size + Vector2(TILE_SIZE * 4.0, TILE_SIZE * 4.0)),
        Color(0.018, 0.020, 0.024, 1.0),
        true
    )

    draw_rect(
        Rect2(Vector2.ZERO, world_size),
        Color(0.075, 0.064, 0.058, 1.0),
        true
    )

    for y in range(height):
        for x in range(width):
            _draw_tile(Vector2i(x, y))

    _draw_store_fixtures()
    _draw_wall_lighting()
    _draw_entrances()
    _draw_exit_markings()

func _draw_tile(cell: Vector2i) -> void:
    var position := Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
    var rect := Rect2(position, Vector2(TILE_SIZE, TILE_SIZE))
    var tile := _map[cell.y][cell.x]

    if tile == "#":
        draw_rect(rect, Color(0.105, 0.095, 0.090, 1.0), true)
        draw_rect(rect.grow(-2.0), Color(0.155, 0.145, 0.140, 1.0), true)
        draw_line(
            position + Vector2(2.0, 3.0),
            position + Vector2(TILE_SIZE - 2.0, 3.0),
            Color(0.29, 0.25, 0.23, 0.75),
            2.0
        )
        draw_line(
            position + Vector2(3.0, TILE_SIZE - 3.0),
            position + Vector2(TILE_SIZE - 3.0, TILE_SIZE - 3.0),
            Color(0.055, 0.050, 0.048, 0.80),
            2.0
        )
        return

    var floor_color := Color(0.17, 0.145, 0.125, 1.0)
    if (cell.x + cell.y) % 2 == 0:
        floor_color = Color(0.185, 0.155, 0.132, 1.0)

    draw_rect(rect, floor_color, true)

    draw_line(
        position + Vector2(0.0, TILE_SIZE - 1.0),
        position + Vector2(TILE_SIZE, TILE_SIZE - 1.0),
        Color(0.31, 0.25, 0.20, 0.32),
        1.0
    )

    draw_line(
        position + Vector2(TILE_SIZE - 1.0, 0.0),
        position + Vector2(TILE_SIZE - 1.0, TILE_SIZE),
        Color(0.07, 0.06, 0.055, 0.22),
        1.0
    )

    if tile == "D":
        draw_rect(rect.grow(-3.0), Color(0.24, 0.20, 0.18, 1.0), true)
        draw_rect(rect.grow(-8.0), Color(0.09, 0.10, 0.12, 1.0), true)
        draw_line(
            position + Vector2(TILE_SIZE * 0.5, 9.0),
            position + Vector2(TILE_SIZE * 0.5, TILE_SIZE - 9.0),
            Color(0.42, 0.34, 0.29, 1.0),
            2.0
        )

func _draw_store_fixtures() -> void:
    _draw_shelf(Vector2(16.0, 1.0), Vector2(7.0, 0.70))
    _draw_shelf(Vector2(24.0, 1.0), Vector2(5.0, 0.70))
    _draw_shelf(Vector2(9.0, 8.0), Vector2(4.0, 0.70))
    _draw_shelf(Vector2(16.0, 8.0), Vector2(5.0, 0.70))
    _draw_shelf(Vector2(22.0, 8.0), Vector2(5.0, 0.70))

    _draw_freezer(Vector2(25.0, 13.5), Vector2(3.8, 2.0))
    _draw_counter(Vector2(2.0, 1.0), Vector2(5.4, 0.65))
    _draw_register(Vector2(4.3, 1.45))
    _draw_drinks(Vector2(27.0, 2.0), 5)
    _draw_drinks(Vector2(27.0, 3.0), 5)

    for x in range(10, 14):
        _draw_product(Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, 8 * TILE_SIZE + 16.0), Color(0.80, 0.32, 0.22, 1.0))
        _draw_product(Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, 8 * TILE_SIZE + 32.0), Color(0.28, 0.56, 0.78, 1.0))

    for x in range(16, 21):
        _draw_product(Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, 8 * TILE_SIZE + 16.0), Color(0.92, 0.67, 0.20, 1.0))
        _draw_product(Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, 8 * TILE_SIZE + 32.0), Color(0.44, 0.73, 0.32, 1.0))

func _draw_shelf(cell_origin: Vector2, cell_size: Vector2) -> void:
    var rect := Rect2(
        cell_origin * TILE_SIZE,
        cell_size * TILE_SIZE
    )
    draw_rect(rect, Color(0.27, 0.18, 0.13, 1.0), true)
    draw_rect(rect.grow(-3.0), Color(0.38, 0.26, 0.18, 1.0), true)
    draw_line(
        rect.position + Vector2(0.0, rect.size.y * 0.35),
        rect.position + Vector2(rect.size.x, rect.size.y * 0.35),
        Color(0.12, 0.09, 0.075, 0.90),
        3.0
    )
    draw_line(
        rect.position + Vector2(0.0, rect.size.y * 0.68),
        rect.position + Vector2(rect.size.x, rect.size.y * 0.68),
        Color(0.12, 0.09, 0.075, 0.90),
        3.0
    )

func _draw_counter(cell_origin: Vector2, cell_size: Vector2) -> void:
    var rect := Rect2(cell_origin * TILE_SIZE, cell_size * TILE_SIZE)
    draw_rect(rect, Color(0.17, 0.11, 0.09, 1.0), true)
    draw_rect(rect.grow(-3.0), Color(0.43, 0.28, 0.18, 1.0), true)
    draw_line(
        rect.position + Vector2(0.0, rect.size.y * 0.30),
        rect.position + Vector2(rect.size.x, rect.size.y * 0.30),
        Color(0.72, 0.55, 0.32, 0.65),
        3.0
    )

func _draw_register(world_position: Vector2) -> void:
    draw_rect(Rect2(world_position * TILE_SIZE, Vector2(26.0, 20.0)), Color(0.10, 0.11, 0.12, 1.0), true)
    draw_rect(Rect2(world_position * TILE_SIZE + Vector2(5.0, 4.0), Vector2(16.0, 8.0)), Color(0.18, 0.43, 0.34, 1.0), true)

func _draw_freezer(cell_origin: Vector2, cell_size: Vector2) -> void:
    var rect := Rect2(cell_origin * TILE_SIZE, cell_size * TILE_SIZE)
    draw_rect(rect, Color(0.13, 0.17, 0.19, 1.0), true)
    draw_rect(rect.grow(-5.0), Color(0.25, 0.48, 0.54, 0.35), true)
    draw_line(
        rect.position + Vector2(rect.size.x * 0.5, 5.0),
        rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 5.0),
        Color(0.70, 0.83, 0.85, 0.55),
        2.0
    )
    draw_line(
        rect.position + Vector2(5.0, 12.0),
        rect.position + Vector2(rect.size.x - 5.0, 12.0),
        Color(0.73, 0.85, 0.86, 0.40),
        2.0
    )

func _draw_drinks(cell_origin: Vector2, count: int) -> void:
    for i in range(count):
        var position := Vector2(
            (cell_origin.x + float(i) * 0.75) * TILE_SIZE,
            cell_origin.y * TILE_SIZE
        )
        draw_rect(Rect2(position, Vector2(16.0, 26.0)), Color(0.28, 0.60, 0.70, 1.0), true)
        draw_rect(Rect2(position + Vector2(3.0, 4.0), Vector2(10.0, 6.0)), Color(0.85, 0.74, 0.30, 0.85), true)

func _draw_product(world_position: Vector2, color: Color) -> void:
    draw_circle(world_position, 5.0, color)
    draw_circle(world_position + Vector2(1.0, -1.0), 2.0, color.lightened(0.30))

func _draw_wall_lighting() -> void:
    var width := _map[0].length()
    var height := _map.size()

    for x in range(width):
        if _map[0][x] == "#":
            var center_x := float(x * TILE_SIZE) + TILE_SIZE * 0.5
            draw_rect(
                Rect2(center_x - 18.0, 20.0, 36.0, 5.0),
                Color(1.0, 0.76, 0.38, 0.72),
                true
            )

    for y in range(height):
        if _map[y][0] == "#":
            var center_y := float(y * TILE_SIZE) + TILE_SIZE * 0.5
            draw_circle(Vector2(20.0, center_y), 5.0, Color(1.0, 0.64, 0.25, 0.60))

func _draw_entrances() -> void:
    var top_left := Vector2(8.0 * TILE_SIZE, 0.0)
    draw_rect(Rect2(top_left + Vector2(2.0, 4.0), Vector2(3.0 * TILE_SIZE, 10.0)), Color(0.78, 0.14, 0.10, 1.0), true)
    draw_rect(Rect2(top_left + Vector2(2.0, 14.0), Vector2(3.0 * TILE_SIZE, 5.0)), Color(1.0, 0.72, 0.20, 0.75), true)

func _draw_exit_markings() -> void:
    var map_width := _map[0].length()
    var y := float((_map.size() - 1) * TILE_SIZE)
    for x in range(4, map_width - 4):
        if x % 2 == 0:
            draw_rect(
                Rect2(float(x * TILE_SIZE), y + 6.0, TILE_SIZE, 8.0),
                Color(0.85, 0.72, 0.24, 0.55),
                true
            )
