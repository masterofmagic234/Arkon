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

    # Runtime node cache. These are resolved once when the minimap is created;
    # _draw() must never recursively search the whole Level 1 scene tree.
    var acorn_nodes: Dictionary = {}
    var squirrel_nodes: Dictionary = {}
    var key_nodes: Dictionary = {}
    var door_nodes: Dictionary = {}
    var refresh_timer := 0.0

    func setup(game_node: Node) -> void:
        game = game_node
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        set_anchors_preset(Control.PRESET_TOP_LEFT)

        acorn_nodes.clear()
        squirrel_nodes.clear()
        key_nodes.clear()
        door_nodes.clear()

        for node in game.get_tree().get_nodes_in_group("level1_acorn"):
            if node is Node3D:
                acorn_nodes[node.name] = node
        for node in game.get_tree().get_nodes_in_group("level1_enemy"):
            if node is Node3D:
                squirrel_nodes[node.name] = node
        for node in game.get_tree().get_nodes_in_group("level1_key"):
            if node is Node3D:
                key_nodes[node.name] = node
        for node in game.get_tree().get_nodes_in_group("level1_door"):
            if node is Node3D:
                door_nodes[node.name] = node

    func set_player_state(pos: Vector3, yaw: float) -> void:
        game_position = pos
        game_yaw = yaw
        queue_redraw()

    func set_initial_state() -> void:
        acorn_names = acorn_nodes.keys()
        squirrel_names = squirrel_nodes.keys()
        stunned = {}
        queue_redraw()

    func remove_item(item_kind: StringName, item_id: StringName) -> void:
        var id := String(item_id)
        if item_kind == &"acorn":
            acorn_names.erase(id)
            acorn_nodes.erase(id)
        elif item_kind == &"key":
            key_nodes.erase(id)
        queue_redraw()

    func remove_enemy(enemy: Node) -> void:
        if enemy == null:
            return
        var id := String(enemy.name)
        squirrel_names.erase(id)
        squirrel_nodes.erase(id)
        stunned.erase(id)
        queue_redraw()

    func remove_door(object_id: StringName) -> void:
        door_nodes.erase(String(object_id))
        queue_redraw()
    func _world_to_map(world: Vector2) -> Vector2:
        return (world - MAP_WORLD_ORIGIN) * MAP_SCALE

    func _draw() -> void:
        if game == null:
            return

        var bounds := Rect2(Vector2.ZERO, size).grow(-MAP_EDGE_MARGIN)

        for name in acorn_names:
            var node := acorn_nodes.get(name) as Node3D
            if is_instance_valid(node) and node.visible:
                _dot(_world_to_map(Vector2(node.global_position.x, node.global_position.z)), 3.6, Color(0.90, 0.58, 0.18, 1.0), bounds)

        for name in squirrel_names:
            var node := squirrel_nodes.get(name) as Node3D
            if is_instance_valid(node):
                var dot_color := Color(0.86, 0.28, 0.24, 1.0) if not stunned.has(name) else Color(0.72, 0.68, 0.42, 0.9)
                _dot(_world_to_map(Vector2(node.global_position.x, node.global_position.z)), 3.0, dot_color, bounds)

        for name in key_nodes.keys():
            var key := key_nodes.get(name) as Node3D
            if is_instance_valid(key) and key.visible:
                _dot(_world_to_map(Vector2(key.global_position.x, key.global_position.z)), 3.4, Color(1.0, 0.86, 0.20, 1.0), bounds)

        for name in door_nodes.keys():
            var door := door_nodes.get(name) as Node3D
            if is_instance_valid(door) and not bool(door.get("is_open")):
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


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    var map_label := get_node_or_null("Label") as Label
    if map_label:
        map_label.visible = false

    call_deferred("_bind_world")

func _exit_tree() -> void:
    if SignalBus.item_collected.is_connected(_on_item_collected):
        SignalBus.item_collected.disconnect(_on_item_collected)
    if SignalBus.enemy_defeated.is_connected(_on_enemy_defeated):
        SignalBus.enemy_defeated.disconnect(_on_enemy_defeated)
    if SignalBus.object_interacted.is_connected(_on_object_interacted):
        SignalBus.object_interacted.disconnect(_on_object_interacted)

func _bind_world() -> void:
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
    dynamic_layer.set_initial_state()

    if not SignalBus.item_collected.is_connected(_on_item_collected):
        SignalBus.item_collected.connect(_on_item_collected)
    if not SignalBus.enemy_defeated.is_connected(_on_enemy_defeated):
        SignalBus.enemy_defeated.connect(_on_enemy_defeated)
    if not SignalBus.object_interacted.is_connected(_on_object_interacted):
        SignalBus.object_interacted.connect(_on_object_interacted)

func _process(delta: float) -> void:
    if dynamic_layer == null:
        return

    refresh_timer = maxf(0.0, refresh_timer - delta)
    if refresh_timer > 0.0:
        return
    refresh_timer = 0.10

    var player := get_tree().get_first_node_in_group("level1_player") as Node3D
    if player == null:
        return

    var pos := player.global_position
    var yaw := player.rotation.y
    if game_position.distance_squared_to(pos) < 0.000001 and is_equal_approx(game_yaw, yaw):
        return

    game_position = pos
    game_yaw = yaw
    dynamic_layer.set_player_state(pos, yaw)

func _on_item_collected(item_kind: StringName, item_id: StringName, _amount: int, _collector: Node) -> void:
    if dynamic_layer != null:
        dynamic_layer.remove_item(item_kind, item_id)

func _on_enemy_defeated(enemy: Node) -> void:
    if dynamic_layer != null:
        dynamic_layer.remove_enemy(enemy)

func _on_object_interacted(object_id: StringName, state: StringName) -> void:
    if dynamic_layer != null and state == &"opened":
        dynamic_layer.remove_door(object_id)
