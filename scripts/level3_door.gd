extends Node2D
class_name Level3Door

const AssetVisual = preload("res://scripts/level3_asset_visual.gd")

signal opened(door: Level3Door)
signal slammed(door: Level3Door)
signal closed(door: Level3Door)

@export var open_speed: float = 12.0
@export var slam_speed: float = 30.0
@export var close_speed: float = 7.5
@export var auto_close_delay: float = 3.0

var is_open: bool = false
var is_opening: bool = false
var is_slammed: bool = false
var locked: bool = false

var _target_rotation: float = 0.0
var _closed_rotation: float = 0.0
var _close_timer: float = -1.0

@onready var body: AnimatableBody2D = $Body
@onready var body_shape: CollisionShape2D = $Body/CollisionShape2D
@onready var hit_area: Area2D = $HitArea
@onready var door_sprite: Sprite2D = $Body/Sprite2D
@onready var frame_sprite: Sprite2D = $FrameSprite

func setup(world_position: Vector2, locked_state: bool = false, initial_rotation: float = 0.0, texture_path: String = "res://assets/level3/source/Doors/sprDoorH.png") -> void:
    global_position = world_position
    locked = locked_state
    rotation = initial_rotation
    _closed_rotation = initial_rotation
    _target_rotation = initial_rotation
    var custom_texture := AssetVisual.first_frame_texture(texture_path)
    if custom_texture != null:
        door_sprite.texture = custom_texture

func _ready() -> void:
    hit_area.monitoring = false
    hit_area.body_entered.connect(_on_hit_area_body_entered)
    body_shape.disabled = false
    door_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    door_sprite.scale = Vector2(1.0, 1.0)
    door_sprite.visible = true
    z_index = 12
    frame_sprite.scale = Vector2(0.65, 0.65)
    frame_sprite.z_index = -1

func _physics_process(delta: float) -> void:
    if is_opening:
        var speed := slam_speed if is_slammed else open_speed
        rotation = rotate_toward(rotation, _target_rotation, speed * delta)

        if is_equal_approx(rotation, _target_rotation):
            rotation = _target_rotation
            is_opening = false
            is_open = true
            is_slammed = false
            body_shape.disabled = true
            hit_area.monitoring = false
            _close_timer = auto_close_delay
            opened.emit(self)

    elif is_open:
        _close_timer -= delta
        if _close_timer <= 0.0:
            _begin_close()

    else:
        if not is_equal_approx(rotation, _closed_rotation):
            rotation = rotate_toward(rotation, _closed_rotation, close_speed * delta)
            if is_equal_approx(rotation, _closed_rotation):
                rotation = _closed_rotation
                body_shape.disabled = false
                closed.emit(self)

func interact(interactor_position: Vector2, dynamic_slam: bool = false) -> bool:
    if locked or is_opening:
        return false

    if is_open:
        _close_timer = auto_close_delay
        return true

    var to_interactor := interactor_position - global_position
    if to_interactor.length_squared() <= 0.001:
        to_interactor = Vector2.DOWN.rotated(global_rotation)

    var door_normal := Vector2.DOWN.rotated(global_rotation).normalized()
    var side := to_interactor.normalized().dot(door_normal)

    # Push the door away from the player. The sign chooses the side of the hinge.
    var open_direction := -1.0 if side >= 0.0 else 1.0
    _target_rotation = _closed_rotation + open_direction * PI * 0.5

    is_opening = true
    is_slammed = dynamic_slam
    _close_timer = -1.0

    if is_slammed:
        hit_area.monitoring = true
        slammed.emit(self)

    return true

func _begin_close() -> void:
    is_opening = false
    is_open = false
    is_slammed = false
    _target_rotation = _closed_rotation
    _close_timer = -1.0
    body_shape.disabled = false
    hit_area.monitoring = false

func _on_hit_area_body_entered(hit_body: Node2D) -> void:
    if not is_slammed:
        return

    if hit_body is Level3Enemy:
        var enemy := hit_body as Level3Enemy
        var push_dir := (enemy.global_position - global_position).normalized()
        enemy.velocity = push_dir * 170.0
        enemy.stun(2.6)
        is_slammed = false
        hit_area.monitoring = false
