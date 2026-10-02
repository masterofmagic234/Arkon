extends Camera3D
class_name Level2Camera3D

var player_movement: RaceMovementComponent = null

func _ready() -> void:
    call_deferred("_bind_player")

func _bind_player() -> void:
    player_movement = get_node_or_null(
        "../Racers/Player/RaceMovementComponent"
    ) as RaceMovementComponent

func _process(_delta: float) -> void:
    if player_movement == null:
        return

    var target := Vector3(
        player_movement.world_x,
        0.0,
        player_movement.world_z
    )
    global_position = target + Vector3(0.0, 11.0, -7.0)
    look_at(target, Vector3.UP)
