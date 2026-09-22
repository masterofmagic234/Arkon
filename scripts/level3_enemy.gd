extends CharacterBody2D
class_name Level3Enemy

enum State {
    IDLE,
    ALERT,
    STUNNED,
    DEAD
}

signal shot_requested(origin: Vector2, direction: Vector2)
signal defeated(enemy: Level3Enemy)

@export var move_speed: float = 105.0
@export var vision_range: float = 520.0
@export var preferred_distance: float = 260.0
@export var attack_range: float = 34.0
@export var patrol_radius: float = 90.0
@export var ranged: bool = true

var target: Level3Player
var world: Node2D
var spawn_position: Vector2
var last_known_position: Vector2
var state: State = State.IDLE

var _stun_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _patrol_target: Vector2

func setup(level_world: Node2D, player: Level3Player, enemy_kind: StringName, radius: float) -> void:
    world = level_world
    target = player
    ranged = enemy_kind != &"melee"
    patrol_radius = radius
    spawn_position = global_position
    last_known_position = global_position
    _patrol_target = global_position
    if enemy_kind == &"melee":
        move_speed = 118.0
        vision_range = 430.0
        attack_range = 34.0
    else:
        move_speed = 96.0
        vision_range = 520.0
        preferred_distance = 270.0
    collision_layer = 2
    collision_mask = 1 | 2
    z_index = 15
    var shape := CircleShape2D.new()
    shape.radius = 13.0
    var collider := CollisionShape2D.new()
    collider.shape = shape
    add_child(collider)
    queue_redraw()

func _physics_process(delta: float) -> void:
    if state == State.DEAD:
        return

    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)

    if state == State.STUNNED:
        _stun_timer -= delta
        velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
        move_and_slide()
        if _stun_timer <= 0.0:
            state = State.IDLE
        queue_redraw()
        return

    if target == null or target.is_dead:
        velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
        move_and_slide()
        return

    var distance_to_target := global_position.distance_to(target.global_position)
    var sees_target: bool = distance_to_target <= vision_range and world.has_line_of_sight(global_position, target.global_position)

    if sees_target:
        state = State.ALERT
        last_known_position = target.global_position

    match state:
        State.IDLE:
            _update_idle_patrol(delta)
        State.ALERT:
            _update_alert(delta, distance_to_target)
        State.STUNNED, State.DEAD:
            pass

    move_and_slide()
    queue_redraw()

func _update_idle_patrol(delta: float) -> void:
    if global_position.distance_to(_patrol_target) < 12.0:
        var angle := randf() * TAU
        var distance := randf_range(22.0, patrol_radius)
        _patrol_target = spawn_position + Vector2.from_angle(angle) * distance

    if world.has_line_of_sight(global_position, _patrol_target):
        var direction := global_position.direction_to(_patrol_target)
        velocity = velocity.move_toward(direction * move_speed * 0.45, 700.0 * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)

func _update_alert(delta: float, distance_to_target: float) -> void:
    var direction := global_position.direction_to(last_known_position)
    if ranged:
        if distance_to_target > preferred_distance + 50.0:
            velocity = velocity.move_toward(direction * move_speed, 850.0 * delta)
        elif distance_to_target < preferred_distance - 60.0:
            velocity = velocity.move_toward(-direction * move_speed, 850.0 * delta)
        else:
            velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)

        if distance_to_target <= vision_range and world.has_line_of_sight(global_position, target.global_position) and _attack_cooldown <= 0.0:
            _attack_cooldown = 0.85
            var shot_direction := global_position.direction_to(target.global_position)
            shot_requested.emit(global_position + shot_direction * 15.0, shot_direction)
    else:
        velocity = velocity.move_toward(direction * move_speed, 1000.0 * delta)
        if distance_to_target <= attack_range and _attack_cooldown <= 0.0:
            _attack_cooldown = 0.9
            if world.has_line_of_sight(global_position, target.global_position):
                target.take_damage(100)

func hear_noise(noise_position: Vector2) -> void:
    if state == State.DEAD:
        return
    if global_position.distance_to(noise_position) <= 520.0:
        state = State.ALERT
        last_known_position = noise_position

func stun(duration: float = 3.2) -> void:
    if state == State.DEAD:
        return
    state = State.STUNNED
    _stun_timer = duration
    velocity = Vector2.ZERO
    queue_redraw()

func kill() -> void:
    if state == State.DEAD:
        return
    state = State.DEAD
    velocity = Vector2.ZERO
    set_physics_process(false)
    var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collision_shape != null:
        collision_shape.disabled = true
    defeated.emit(self)
    queue_free()

func is_stunned() -> bool:
    return state == State.STUNNED

func _draw() -> void:
    var body_color := Color(0.68, 0.22, 0.23, 1.0) if ranged else Color(0.76, 0.43, 0.17, 1.0)
    if state == State.STUNNED:
        body_color = Color(0.96, 0.78, 0.18, 1.0)
    draw_circle(Vector2.ZERO, 13.0, body_color)
    draw_circle(Vector2(0, -4), 7.0, Color(0.90, 0.72, 0.56, 1.0))
    draw_circle(Vector2(-3, -5), 1.8, Color(0.05, 0.05, 0.05, 1.0))
    draw_circle(Vector2(3, -5), 1.8, Color(0.05, 0.05, 0.05, 1.0))
    if ranged:
        draw_line(Vector2(0, 0), Vector2(25, 0), Color(0.10, 0.10, 0.12, 1.0), 4.0, true)
    else:
        draw_line(Vector2(0, 0), Vector2(18, 0), Color(0.45, 0.22, 0.08, 1.0), 5.0, true)
    if state == State.STUNNED:
        for i in range(3):
            var angle := float(i) * TAU / 3.0
            draw_circle(Vector2.from_angle(angle) * 20.0, 2.5, Color(1.0, 0.88, 0.25, 1.0))
