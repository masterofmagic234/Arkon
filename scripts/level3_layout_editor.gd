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

    # Subtle 16px tactical grid/floor guide.
    for y in range(map.size()):
        for x in range(map[y].length()):
            if map[y][x] == "#":
                continue
            draw_rect(
                Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE)),
                Color(0.10, 0.095, 0.10, 1.0),
                true
            )
            draw_rect(
                Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE)),
                Color(1.0, 1.0, 1.0, 0.035),
                false,
                1.0
            )

    # Mark the two-tile door openings without drawing replacement walls.
    for y in range(map.size()):
        for x in range(map[y].length()):
            if map[y][x] == "D":
                draw_rect(
                    Rect2(Vector2(x * TILE_SIZE + 1, y * TILE_SIZE + 1), Vector2(TILE_SIZE - 2, TILE_SIZE - 2)),
                    Color(0.04, 0.03, 0.04, 1.0),
                    true
                )
