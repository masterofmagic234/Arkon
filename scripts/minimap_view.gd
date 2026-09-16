extends Control

var game_position := Vector3.ZERO
var game_yaw := 0.0
var acorn_names: Array = []
var squirrel_names: Array = []
var stunned: Dictionary = {}

const LevelData = preload("res://scripts/level_data.gd")
const CELL_SIZE := LevelData.CELL_SIZE
const CANONICAL_MAP := LevelData.CANONICAL_MAP


func set_game_state(pos: Vector3, yaw: float, acorns: Array, squirrels: Array, stunned_state: Dictionary) -> void:
    game_position = pos
    game_yaw = yaw
    acorn_names = acorns.duplicate()
    squirrel_names = squirrels.duplicate()
    stunned = stunned_state.duplicate()
    queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var center := size * 0.5
    var scale := 4.5
    var game := get_tree().current_scene
    if game == null:
        return

    for row in range(14):
        for col in range(20):
            if CANONICAL_MAP[row].substr(col, 1) == "1":
                var wp := center + Vector2((col - 9.5) * CELL_SIZE - game_position.x, (row - 6.5) * CELL_SIZE - game_position.z) * scale
                if Rect2(Vector2.ZERO, size).grow(-4.0).has_point(wp):
                    draw_rect(Rect2(wp - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(0.25, 0.34, 0.30, 0.85))

    for child in game.get_children():
        if child is MeshInstance3D and child.name.begins_with("Tree"):
            _dot(center + Vector2(child.global_position.x - game_position.x, child.global_position.z - game_position.z) * scale, 2.0)

    for name in acorn_names:
        var node := game.get_node_or_null(name) as Node3D
        if node:
            _dot(center + Vector2(node.global_position.x - game_position.x, node.global_position.z - game_position.z) * scale, 4.0)

    for name in squirrel_names:
        var node := game.get_node_or_null(name) as Node3D
        if node:
            var p := center + Vector2(node.global_position.x - game_position.x, node.global_position.z - game_position.z) * scale
            _dot(p, 3.0)

    var facing := Vector2(-sin(game_yaw), -cos(game_yaw)) * 9.0
    draw_line(center, center + facing, Color(1.0, 0.78, 0.55, 0.9), 2.0)
    draw_circle(center, 3.5, Color(0.9, 0.95, 0.9, 1.0))

func _dot(pos: Vector2, radius: float) -> void:
    if Rect2(Vector2.ZERO, size).grow(-4.0).has_point(pos):
        draw_circle(pos, radius, Color(0.82, 0.55, 0.28, 0.95))
