extends CharacterBody2D
class_name Level3Enemy
const SquirrelAnimator = preload("res://scripts/level3_squirrel_animator.gd")
enum State { IDLE, ALERT, STUNNED, DEAD }
signal shot_requested(shooter, origin: Vector2, direction: Vector2)
@export var move_speed := 82.0
@export var vision_range := 340.0
@export var preferred_distance := 170.0
@export var attack_range := 39.0
@export var patrol_radius := 48.0
@export var ranged := true
@export var enemy_kind: StringName = &"gunman"
var target: Level3Player
var world: Node2D
var spawn_position: Vector2
var last_known_position: Vector2
var state: State = State.IDLE
var _stun_timer := 0.0
var _attack_cooldown := 0.4
var _windup := 0.0
var _locked_aim := Vector2.RIGHT
var _sees_target := false
var _sense_timer := 0.0
var _route_timer := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _last_goal := Vector2.INF
var _direct_clear := false
var _patrol_target := Vector2.ZERO
var _patrol_phase := 0.0
var _aim_direction := Vector2.RIGHT
var _animator := SquirrelAnimator.new()
@onready var _visual: AnimatedSprite2D = %Visual
@onready var _weapon_visual: Sprite2D = %WeaponVisual
@onready var _health_component: HealthComponent = %Health
@onready var _hitbox_component: HitboxComponent = %Hitbox
@onready var _collision_shape: CollisionShape2D = %CollisionShape2D

func _ready() -> void:
    world = get_parent().get_parent() as Node2D
    target = world.get_node("Player") as Level3Player
    spawn_position = global_position
    last_known_position = global_position
    _patrol_target = global_position
    collision_layer = 2
    collision_mask = 1|2
    z_index = 14
    ranged = enemy_kind==&"gunman"
    move_speed = 77.0 if ranged else (100.0 if enemy_kind==&"butcher" else 93.0)
    _sense_timer = float(posmod(hash(name),10))*0.01
    _patrol_phase = float(posmod(hash(name),100))*0.0628
    _health_component.died.connect(_on_health_died)
    _animator.configure(_visual,enemy_kind,_patrol_phase)
    _weapon_visual.visible = false

func _physics_process(delta: float) -> void:
    if state==State.DEAD:
        if not world.is_combat_paused(): _update_visual(delta)
        return
    if world.is_combat_paused() or not world.navigation.ready:
        velocity = Vector2.ZERO
        _visual.pause()
        return
    _attack_cooldown = maxf(0,_attack_cooldown-delta)
    _route_timer -= delta
    if state==State.STUNNED:
        _stun_timer -= delta
        velocity = velocity.move_toward(Vector2.ZERO,800*delta)
        move_and_slide()
        _visual.modulate = Color(1,0.9,0.65)
        if _stun_timer<=0:
            state = State.ALERT
            _visual.modulate = Color.WHITE
        _update_visual(delta)
        queue_redraw()
        return
    if target==null or target.is_dead: return
    _sense_timer -= delta
    if _sense_timer<=0:
        _sense_timer = 0.1
        _sees_target = global_position.distance_to(target.global_position)<=vision_range and world.has_line_of_sight(global_position,target.global_position)
        if _sees_target:
            state = State.ALERT
            last_known_position = target.global_position
    if _windup>0:
        _windup -= delta
        velocity = velocity.move_toward(Vector2.ZERO,1100*delta)
        rotation = _locked_aim.angle()
        if _windup<=0: _resolve_attack()
    elif state==State.IDLE:
        if global_position.distance_to(_patrol_target)<8.0:
            _patrol_phase += 1.45
            _patrol_target = spawn_position+Vector2.from_angle(_patrol_phase)*patrol_radius*0.65
        _follow(_patrol_target,move_speed*0.38,delta)
    else:
        var distance := global_position.distance_to(last_known_position)
        _aim_direction = global_position.direction_to(last_known_position)
        if _sees_target:
            rotation = _aim_direction.angle()
            if ranged:
                if distance>preferred_distance+35:
                    _follow(last_known_position,move_speed,delta)
                elif distance<preferred_distance-55:
                    var retreat := global_position-_aim_direction*35
                    if world.is_body_path_clear(global_position,retreat):
                        velocity = velocity.move_toward(-_aim_direction*move_speed*0.55,750*delta)
                    else: velocity = velocity.move_toward(Vector2.ZERO,950*delta)
                else: velocity = velocity.move_toward(Vector2.ZERO,950*delta)
            else: _follow(last_known_position,move_speed,delta)
            if _attack_cooldown<=0 and (ranged or distance<=attack_range):
                _locked_aim = _aim_direction
                _windup = 0.48 if ranged else 0.34
                _attack_cooldown = 1.35 if ranged else 1.10
        elif distance<14:
            state = State.IDLE
            _path.clear()
            _patrol_target = global_position
            velocity = velocity.move_toward(Vector2.ZERO,950*delta)
        else: _follow(last_known_position,move_speed*0.80,delta)
    move_and_slide()
    if state==State.IDLE and velocity.length_squared()>10: rotation = velocity.angle()
    _update_visual(delta)
    queue_redraw()

func _update_visual(delta: float) -> void:
    _animator.update(delta,velocity,rotation,_windup,.48 if ranged else .34,state==State.STUNNED,state==State.DEAD)

func _follow(goal: Vector2, speed_: float, delta: float) -> void:
    # The collider radius is respected by the sampled route. A visible ray alone
    # is insufficient around the edge of a chair or a wall corner.
    if _route_timer<=0:
        _direct_clear=world.is_body_path_clear(global_position,goal)
        _route_timer=0.24
        if not _direct_clear and (goal.distance_to(_last_goal)>12 or _path_index>=_path.size()):
            _path=world.navigation.path(global_position,goal)
            _path_index=0
            _last_goal=goal
    if _direct_clear:
        velocity=velocity.move_toward(global_position.direction_to(goal)*speed_,850*delta)
        return
    while _path_index<_path.size() and global_position.distance_to(_path[_path_index])<2.5: _path_index+=1
    if _path_index>=_path.size():
        velocity = velocity.move_toward(Vector2.ZERO,900*delta)
        return
    var waypoint := _path[_path_index]
    for door in world._doors:
        if not door.is_open and not door.is_opening and global_position.distance_to(door.global_position)<34:
            door.interact(global_position)
    velocity = velocity.move_toward(global_position.direction_to(waypoint)*speed_,850*delta)

func _resolve_attack() -> void:
    if state!=State.ALERT or target.is_dead: return
    _animator.attack()
    if ranged:
        shot_requested.emit(self,global_position+_locked_aim*16,_locked_aim)
    else:
        var offset := target.global_position-global_position
        if offset.length()<=attack_range+4 and offset.normalized().dot(_locked_aim)>0.55 and world.has_line_of_sight(global_position,target.global_position): target.take_damage(22,self)

func hear_noise(at: Vector2) -> void:
    if state==State.DEAD or state==State.STUNNED: return
    if global_position.distance_to(at)<=250:
        state = State.ALERT
        last_known_position = at
        _route_timer = 0

func stun(duration: float = 3.2, knockback_velocity: Vector2 = Vector2.ZERO) -> void:
    if state==State.DEAD: return
    state = State.STUNNED
    _stun_timer = duration
    _windup = 0
    velocity = knockback_velocity
    _animator.interrupt()
    _update_visual(0)
    var bus := get_node_or_null("/root/SignalBus")
    if bus!=null: bus.entity_stunned.emit(self,duration)

func is_stunned() -> bool: return state==State.STUNNED
func receive_hit(amount: int = 100, source: Node = null) -> void:
    if state!=State.DEAD: _hitbox_component.receive_hit(amount,source)
func take_damage(amount: int = 100, source: Node = null) -> void:
    if state!=State.DEAD: _health_component.apply_damage(amount,source)
func kill() -> void:
    if state==State.DEAD: return
    state = State.DEAD
    if not _health_component.is_dead: _health_component.force_kill()
    velocity = Vector2.ZERO
    _windup = 0
    _collision_shape.set_deferred("disabled",true)
    _hitbox_component.set_deferred("collision_layer",0)
    _hitbox_component.set_deferred("monitorable",false)
    collision_layer = 0
    _animator.fall()
    _update_visual(0)
    _visual.modulate = Color(0.75,0.70,0.72)
    z_index = -2
    var bus := get_node_or_null("/root/SignalBus")
    if bus!=null: bus.enemy_defeated.emit(self)
    queue_redraw()
func _on_health_died() -> void: kill()

func _draw() -> void:
    if state==State.DEAD: return
    draw_circle(Vector2(1,3),8,Color(0.01,0.015,0.025,0.30))
    if state==State.STUNNED:
        draw_arc(Vector2.ZERO,15,0,TAU,24,Color(1,0.78,0.3,0.80),1.3,true)
    elif _windup>0:
        var mat_color := Color(1.0,0.37,0.32,0.8) if ranged else Color(1.0,0.76,0.25,0.8)
        var aim := _locked_aim.rotated(-rotation)
        draw_line(aim*13,aim*(74 if ranged else 37),mat_color,1.0,true)
        draw_arc(Vector2.ZERO,15,0,TAU*(1.0-_windup/(0.48 if ranged else 0.34)),24,mat_color,1.4,true)
