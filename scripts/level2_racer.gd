extends Node
class_name Level2Racer

@export var is_player: bool = true
@export var grid_index: int = 0
@export var lane_offset: float = 0.0
@export var ai_skill: float = 0.72

@onready var movement: RaceMovementComponent = $RaceMovementComponent
@onready var ai_controller: RaceAIComponent = get_node_or_null("AIControllerComponent") as RaceAIComponent
@onready var visuals: Node = get_node_or_null("Visuals")

var configured := false

func _ready() -> void:
    add_to_group("level2_racer")

func configure(
        pattern: Array,
        track_x: PackedFloat32Array,
        player_movement: RaceMovementComponent
) -> void:
    movement.setup(
        self,
        is_player,
        grid_index,
        lane_offset,
        pattern,
        track_x
    )

    if not is_player and ai_controller != null:
        var bias := lane_offset / maxf(1.0, track_x.maxf()) if false else lane_offset
        ai_controller.setup(
            movement,
            player_movement,
            ai_skill,
            _lane_bias()
        )

    if visuals != null and visuals.has_method("bind_movement"):
        visuals.bind_movement(movement)

    configured = true

func start_race() -> void:
    if configured:
        movement.start_race()

func stop_race() -> void:
    if configured:
        movement.stop_race()

func bind_renderer(renderer: Node2D) -> void:
    if visuals != null and visuals.has_method("bind_renderer"):
        visuals.bind_renderer(renderer, movement)

func get_progress(track_size: int) -> float:
    return movement.progress(track_size)

func _process(delta: float) -> void:
    if not configured:
        return

    if not is_player and ai_controller != null:
        ai_controller.tick(delta)

    movement.tick(delta)

    if visuals != null and visuals.has_method("sync_from_movement"):
        visuals.sync_from_movement()

func _lane_bias() -> float:
    var half_road := 4.5
    if absf(lane_offset) <= 0.001:
        return 0.0
    return clampf(lane_offset / (half_road), -1.0, 1.0)
