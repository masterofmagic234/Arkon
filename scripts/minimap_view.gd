extends Control

# ACORN HUNTER — optimized minimap.
# Static world geometry is drawn once by StaticLayer and then moved with the
# player. Only the dynamic layer is redrawn when gameplay state changes.

const LevelData = preload("res://scripts/level_data.gd")
const CELL_SIZE := LevelData.CELL_SIZE
const CANONICAL_MAP := LevelData.CANONICAL_MAP
const MAP_SCALE := 4.5
const MAP_EDGE_MARGIN := 4.0

var game_position := Vector3.ZERO
var game_yaw := 0.0
var acorn_names: Array = []
var squirrel_names: Array = []
var stunned: Dictionary = {}

var static_layer: StaticLayer
var dynamic_layer: DynamicLayer


class StaticLayer extends Control:
	var tree_positions: Array[Vector2] = []

	func setup(game: Node) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		tree_positions.clear()

		for child in game.get_children():
			if child is MeshInstance3D and child.name.begins_with("Tree"):
				tree_positions.append(Vector2(child.global_position.x, child.global_position.z) * MAP_SCALE)

		queue_redraw()

	func _draw() -> void:
		for row in range(14):
			for col in range(20):
				if CANONICAL_MAP[row].substr(col, 1) == "1":
					var p := Vector2(
						(col - 9.5) * CELL_SIZE,
						(row - 6.5) * CELL_SIZE
					) * MAP_SCALE
					draw_rect(
						Rect2(p - Vector2(3.0, 3.0), Vector2(6.0, 6.0)),
						Color(0.25, 0.34, 0.30, 0.85)
					)

		for p in tree_positions:
				draw_circle(p, 2.0, Color(0.82, 0.55, 0.28, 0.95))


class DynamicLayer extends Control:
	var game_position := Vector3.ZERO
	var game_yaw := 0.0
	var acorn_names: Array = []
	var squirrel_names: Array = []
	var stunned: Dictionary = {}
	var game: Node

	func setup(game_node: Node) -> void:
		game = game_node
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	func set_state(pos: Vector3, yaw: float, acorns: Array, squirrels: Array, stunned_state: Dictionary) -> void:
		game_position = pos
		game_yaw = yaw
		acorn_names = acorns.duplicate()
		squirrel_names = squirrels.duplicate()
		stunned = stunned_state.duplicate()
		queue_redraw()

	func _draw() -> void:
		if game == null:
			return

		var center := size * 0.5
		var bounds := Rect2(Vector2.ZERO, size).grow(-MAP_EDGE_MARGIN)

		for name in acorn_names:
			var node := game.get_node_or_null(name) as Node3D
			if node:
				_dot(
					center + Vector2(node.global_position.x - game_position.x, node.global_position.z - game_position.z) * MAP_SCALE,
					4.0,
					bounds
				)

		for name in squirrel_names:
			var node := game.get_node_or_null(name) as Node3D
			if node:
				var p := center + Vector2(node.global_position.x - game_position.x, node.global_position.z - game_position.z) * MAP_SCALE
				_dot(p, 3.0, bounds)

		var facing := Vector2(-sin(game_yaw), -cos(game_yaw)) * 9.0
		draw_line(center, center + facing, Color(1.0, 0.78, 0.55, 0.9), 2.0)
		draw_circle(center, 3.5, Color(0.9, 0.95, 0.9, 1.0))

	func _dot(pos: Vector2, radius: float, bounds: Rect2) -> void:
		if bounds.has_point(pos):
			draw_circle(pos, radius, Color(0.82, 0.55, 0.28, 0.95))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	if static_layer:
		# The static layer is a cached canvas item. Moving it changes its
		# transform without rebuilding all wall/tree draw commands.
		static_layer.position = size * 0.5 - Vector2(game_position.x, game_position.z) * MAP_SCALE

	if dynamic_layer:
		dynamic_layer.set_state(pos, yaw, acorn_names, squirrel_names, stunned)
