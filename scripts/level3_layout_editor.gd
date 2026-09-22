@tool
extends Node2D

const TILE_SIZE := 16

func _ready() -> void:
    queue_redraw()

func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        queue_redraw()

func _draw() -> void:
    if not Engine.is_editor_hint():
        return

    var map := [
        "################################",
        "#........#............#........#",
        "#........#............#........#",
        "#........D............D........#",
        "#........D............D........#",
        "#........#............#........#",
        "#..###...#............#...###..#",
        "####DD#########DD########DD####",
        "#.......#................#.....#",
        "#.......#................#.....#",
        "#.......D................D.....#",
        "#.......D................D.....#",
        "#.......#................#.....#",
        "#.......#................#.....#",
        "#....##.#................#.##..#",
        "####DD####################DD####",
        "#...........#..................#",
        "#...........#..................#",
        "#...........#..................#",
        "#...........D..................#",
        "#...........D..................#",
        "#...........#..................#",
        "#..............................#",
        "################################"
    ]

    for y in range(map.size()):
        for x in range(map[y].length()):
            if map[y][x] != "#":
                draw_rect(
                    Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE)),
                    Color(0.10, 0.095, 0.10, 1.0),
                    true
                )

    for y in range(map.size()):
        for x in range(map[y].length()):
            if map[y][x] != "#":
                continue
            var p := Vector2(x * TILE_SIZE, y * TILE_SIZE)
            var up := y > 0 and map[y - 1][x] != "#"
            var down := y + 1 < map.size() and map[y + 1][x] != "#"
            var left := x > 0 and map[y][x - 1] != "#"
            var right := x + 1 < map[y].length() and map[y][x + 1] != "#"
            if up or down:
                draw_rect(Rect2(p + Vector2(0, 6), Vector2(TILE_SIZE, 4)), Color(0.44, 0.10, 0.12, 1.0), true)
            if left or right:
                draw_rect(Rect2(p + Vector2(6, 0), Vector2(4, TILE_SIZE)), Color(0.44, 0.10, 0.12, 1.0), true)

    for y in range(map.size()):
        for x in range(map[y].length()):
            if map[y][x] == "D":
                draw_rect(
                    Rect2(Vector2(x * TILE_SIZE + 1, y * TILE_SIZE + 1), Vector2(TILE_SIZE - 2, TILE_SIZE - 2)),
                    Color(0.025, 0.020, 0.025, 1.0),
                    true
                )
