extends SpringArm3D
class_name Level2Camera3D

const BASE_SPRING_LENGTH := 8.5
const HIGH_SPEED_SPRING_LENGTH := 10.0
const BASE_FOV := 68.0
const HIGH_SPEED_FOV := 74.0

var vehicle: VehicleBody3D = null
var camera: Camera3D = null

func _ready() -> void:
    collision_mask = 1
    margin = 0.35
    call_deferred("_bind_player")

func _bind_player() -> void:
    vehicle = get_parent() as VehicleBody3D
    camera = get_node_or_null("Camera3D") as Camera3D

func _process(_delta: float) -> void:
    if vehicle == null or camera == null:
        return

    var movement := vehicle.get_node_or_null(
        "RaceMovementComponent"
    ) as RaceMovementComponent
    var speed_norm := 0.0
    if movement != null:
        speed_norm = clampf(
            movement.speed / maxf(
                RaceLevelData.PLAYER_MAX_SPEED,
                0.001
            ),
            0.0,
            1.0
        )

    spring_length = lerpf(
        BASE_SPRING_LENGTH,
        HIGH_SPEED_SPRING_LENGTH,
        speed_norm
    )
    camera.fov = lerpf(
        BASE_FOV,
        HIGH_SPEED_FOV,
        speed_norm
    )
