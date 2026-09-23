extends Control

# Level 1 minimap: one fixed map coordinate system for the expanded linear route.
const LevelData = preload("res://scripts/level_data.gd")
const MAP_SCALE := 3.0
const MAP_WORLD_ORIGIN := LevelData.MAP_WORLD_ORIGIN
const MAP_EDGE_MARGIN := 4.0

var game_position := Vector3.ZERO
var game_yaw := 0.0
var acorn_names: Array = []
var squirrel_names: Array = []
var stunned: Dictionary = {}

var static_layer: StaticLayer
var dynamic_layer: DynamicLayer


class StaticLayer extends Control:
    const LevelData = preload("res://scripts/level_data.gd")
    const CELL_SIZE := LevelData.CELL_SIZE
    const CANONICAL_MAP := LevelData.CANONICAL_MAP
    const MAP_SCALE := 3.0
    const MAP_WORLD_ORIGIN := LevelData.MAP_WORLD_ORIGIN

    var tree_positions: Array[Vector2] = []

    func setup(game: Node) -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        set_anchors_preset(Control.PRESET_TOP_LEFT)
        tree_positions.clear()
        for child in game.find_children("Tree*", "MeshInstance3D", true, false):
            if child is MeshInstance3D:
                tree_positions.append(_world_to_map(Vector2(child.global_position.x, child.global_position.z)))
        queue_redraw()

    func _world_to_map(world: Vector2) -> Vector2:
        return (world - MAP_WORLD_ORIGIN) * MAP_SCALE

    func _draw() -> void:
        for row in range(LevelData.MAP_HEIGHT):
            for col in range(LevelData.MAP_WIDTH):
                if CANONICAL_MAP[row].substr(col, 1) == "1":
                    var world := MAP_WORLD_ORIGIN + Vector2(col, row) * CELL_SIZE
                    var p := _world_to_map(world)
                    draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(0.25, 0.34, 0.30, 0.9))

        for p in tree_positions:
            draw_circle(p, 2.4, Color(0.22, 0.62, 0.28, 0.95))


class DynamicLayer extends Control:
    const LevelData = preload("res://scripts/level_data.gd")
    const MAP_SCALE := 3.0
    const MAP_WORLD_ORIGIN := LevelData.MAP_WORLD_ORIGIN
    const MAP_EDGE_MARGIN := 4.0

    var game_position := Vector3.ZERO
    var game_yaw := 0.0
    var acorn_names: Array = []
    var squirrel_names: Array = []
    var stunned: Dictionary = {}
    var game: Node

    func setup(game_node: Node) -> void:
        game = game_node
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        set_anchors_preset(Control.PRESET_TOP_LEFT)

    func set_state(pos: Vector3, yaw: float, acorns: Array, squirrels: Array, stunned_state: Dictionary) -> void:
        game_position = pos
        game_yaw = yaw
        acorn_names = acorns.duplicate()
        squirrel_names = squirrels.duplicate()
        stunned = stunned_state.duplicate()
        queue_redraw()

    func _world_to_map(world: Vector2) -> Vector2:
        return (world - MAP_WORLD_ORIGIN) * MAP_SCALE

    func _draw() -> void:
        if game == null:
            return

        var bounds := Rect2(Vector2.ZERO, size).grow(-MAP_EDGE_MARGIN)

        for name in acorn_names:
            var node := game.find_child(name, true, false) as Node3D
            if node != null and node.visible:
                _dot(_world_to_map(Vector2(node.global_position.x, node.global_position.z)), 3.6, Color(0.90, 0.58, 0.18, 1.0), bounds)

        for name in squirrel_names:
            var node := game.find_child(name, true, false) as Node3D
            if node != null:
                var dot_color := Color(0.86, 0.28, 0.24, 1.0) if not stunned.has(name) else Color(0.72, 0.68, 0.42, 0.9)
                _dot(_world_to_map(Vector2(node.global_position.x, node.global_position.z)), 3.0, dot_color, bounds)

        for name in LevelData.KEY_NAMES:
            var key := game.find_child(name, true, false) as Node3D
            if key != null and key.visible:
                _dot(_world_to_map(Vector2(key.global_position.x, key.global_position.z)), 3.4, Color(1.0, 0.86, 0.20, 1.0), bounds)

        for name in LevelData.DOOR_NAMES:
            var door := game.find_child(name, true, false) as Node3D
            if door != null and not bool(door.get("is_open")):
                var p := _world_to_map(Vector2(door.global_position.x, door.global_position.z))
                if bounds.has_point(p):
                    draw_rect(Rect2(p - Vector2(2.0, 6.0), Vector2(4.0, 12.0)), Color(0.62, 0.32, 0.16, 0.95))

        var player_pos := _world_to_map(Vector2(game_position.x, game_position.z))
        var facing := Vector2(-sin(game_yaw), -cos(game_yaw)) * 9.0
        if bounds.has_point(player_pos):
            draw_line(player_pos, player_pos + facing, Color(0.35, 0.75, 1.0, 0.95), 2.0)
            draw_circle(player_pos, 4.2, Color(0.9, 0.95, 0.95, 1.0))

    func _dot(pos: Vector2, radius: float, color: Color, bounds: Rect2) -> void:
        if bounds.has_point(pos):
            draw_circle(pos, radius, color)


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    var map_label := get_node_or_null("Label") as Label
    if map_label:
        map_label.visible = false

    var game := get_tree().current_scene
    if game == null:
        return

    static_layer = StaticLayer.new()
    static_layer.name = "StaticLayer"
    static_layer.size = size
    add_child(static_layer)
    move_child(static_layer, 0)
    static_layer.setup(game)

    dynamic_layer = DynamicLayer.new()
    dynamic_layer.name = "DynamicLayer"
    dynamic_layer.size = size
    add_child(dynamic_layer)
    move_child(dynamic_layer, 1)
    dynamic_layer.setup(game)


func set_game_state(pos: Vector3, yaw: float, acorns: Array, squirrels: Array, stunned_state: Dictionary) -> void:
    game_position = pos
    game_yaw = yaw
    acorn_names = acorns.duplicate()
    squirrel_names = squirrels.duplicate()
    stunned = stunned_state.duplicate()
    if dynamic_layer:
        dynamic_layer.set_state(pos, yaw, acorn_names, squirrel_names, stunned)
