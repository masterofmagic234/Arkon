extends Node2D
class_name Level3Store
@onready var _pause_manager: Node = get_node("/root/PauseManager")

const StoreData = preload("res://scripts/level3_store_data.gd")
const EnemyScene = preload("res://scenes/level3_enemy.tscn")
const DoorScene = preload("res://scenes/level3_door.tscn")
const PickupScene = preload("res://scenes/level3_pickup.tscn")
const AssetVisual = preload("res://scripts/level3_asset_visual.gd")
const EnvironmentScene = preload("res://scripts/level3_environment.gd")
const Navigation = preload("res://scripts/level3_navigation.gd")
const Effects = preload("res://scripts/level3_effects.gd")
const ProjectileScene = preload("res://scenes/level3_projectile.tscn")
const WeaponData = preload("res://scripts/weapon_data.gd")
const BloodStainLayer = preload("res://scripts/level3_blood_stain_layer.gd")

const LAYOUT_SCALE: float = 1.5
const CHUNK_WIDTH: float = 512.0
const CHUNK_HEIGHT: float = 384.0

@onready var player: Level3Player = $Player
@onready var enemies_root: Node2D = $Enemies
@onready var doors_root: Node2D = $Doors
@onready var pickups_root: Node2D = $Pickups
@onready var dialogue: Level3Dialogue = $HUD/Dialogue
@onready var objective_label: Label = $HUD/Objective
@onready var weapon_label: Label = $HUD/Weapon
@onready var hint_label: Label = $HUD/Hint
@onready var status_label: Label = $HUD/Status
@onready var move_joystick: Level3TouchJoystick = $HUD/MoveJoystick
@onready var aim_joystick: Level3TouchJoystick = $HUD/AimJoystick
@onready var fire_button: Button = $HUD/Fire
@onready var action_button: Button = $HUD/Action
@onready var throw_button: Button = $HUD/Throw
@onready var sprint_button: Button = $HUD/Sprint
@onready var camera: Camera2D = $Player/Camera2D
@onready var world_renderer: Level3StoreRenderer = $WorldRenderer
@onready var layouts_root: Node2D = $Level3Layouts
@onready var map_layer: Level3MapLayer = $MapLayer

var _mobile_move: Vector2 = Vector2.ZERO
var _mobile_aim: Vector2 = Vector2.ZERO
var _fire_held: bool = false
var _mouse_fire_held: bool = false
var _mouse_fire_suppressed: bool = false
var _sprint_held: bool = false
var _pending_action: bool = false
var _pending_throw: bool = false
var _keyboard_action_down: bool = false
var _keyboard_throw_down: bool = false

var _enemies_alive: int = 0
var _level_complete_started: bool = false
var _player_dead: bool = false
var order_collected := false
var navigation = Navigation.new()
var environment: Level3Environment
var effects: Level3Effects
var hud: Level3HUD
var feedback: Control
var audio: Node2D
var _last_mobile_aim := Vector2.RIGHT
var _hud_timer := 0.0
var _step_timer := 0.0
var _camera_kick := Vector2.ZERO
var _body_shape := CircleShape2D.new()
var _body_query := PhysicsShapeQueryParameters2D.new()
var _hint_timer: float = 0.0

var _doors: Array[Level3Door] = []
var _enemies: Array[Level3Enemy] = []
var _signal_bus: Node = null
var _projectile_pool: ObjectPool = null

func _ready() -> void:
    _projectile_pool = ObjectPool.new(ProjectileScene, 24, self, 64)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _pause_manager.resume()
    var blood_layer := BloodStainLayer.new()
    blood_layer.name = "BloodStainLayer"
    blood_layer.z_index = -4
    add_child(blood_layer)

    _body_shape.radius=7.8
    _body_query.shape=_body_shape
    _body_query.collision_mask=1
    _body_query.collide_with_areas=false
    effects = Effects.new()
    effects.name = "CombatEffects"
    add_child(effects)
    _build_static_world()
    _configure_camera()
    _create_doors()
    _create_pickups()

    var spawn_position := _scaled_cell_world(StoreData.player_spawn())
    if not _is_spawn_clear(spawn_position):
        _fail_spawn_position(spawn_position)
        return
    player.global_position = spawn_position
    camera.global_position = spawn_position
    camera.reset_smoothing()
    player.controls_enabled = true

    player.edge_inputs_consumed.connect(_on_edges_consumed)
    player.fire_requested.connect(_on_player_fire_requested)
    player.action_requested.connect(_on_player_action_requested)
    player.throw_requested.connect(_on_player_throw_requested)

    _signal_bus = get_node_or_null("/root/SignalBus")
    if _signal_bus != null:
        _signal_bus.weapon_changed.connect(_on_bus_weapon_changed)
        _signal_bus.entity_died.connect(_on_bus_entity_died)
        _signal_bus.enemy_defeated.connect(_on_bus_enemy_defeated)
        _signal_bus.item_collected.connect(_on_bus_item_collected)

    dialogue.visible = false

    move_joystick.vector_changed.connect(_on_move_joystick_changed)
    aim_joystick.vector_changed.connect(_on_aim_joystick_changed)
    fire_button.button_down.connect(_on_fire_button_down)
    fire_button.button_up.connect(_on_fire_button_up)
    action_button.pressed.connect(_on_action_button_pressed)
    throw_button.pressed.connect(_on_throw_button_pressed)
    sprint_button.button_down.connect(_on_sprint_button_down)
    sprint_button.button_up.connect(_on_sprint_button_up)

    world_renderer.setup(StoreData.get_map())
    map_layer.build_from_resource(StoreData.MAP_DATA)
    _update_hud()
    _spawn_enemies()
    hud = $HUD
    hud.bind(self)
    feedback=preload("res://scripts/player_feedback.gd").new()
    hud.add_child(feedback)
    feedback.bind(player)
    var reticle := Node2D.new()
    reticle.set_script(load("res://scripts/level3_reticle.gd"))
    reticle.world=self
    reticle.name="Reticle"
    add_child(reticle)
    _set_hint("Заказ ждёт на кухне. Сначала разберись с охраной.")
    _initialize_navigation.call_deferred()
    if _signal_bus != null and _signal_bus.has_signal("mission_changed"):
        _signal_bus.mission_changed.emit(&"level3", &"started")

func _exit_tree() -> void:
    _projectile_pool.release_all()
    _projectile_pool = null
    if _signal_bus != null:
        if _signal_bus.weapon_changed.is_connected(_on_bus_weapon_changed):
            _signal_bus.weapon_changed.disconnect(_on_bus_weapon_changed)
        if _signal_bus.entity_died.is_connected(_on_bus_entity_died):
            _signal_bus.entity_died.disconnect(_on_bus_entity_died)
        if _signal_bus.enemy_defeated.is_connected(_on_bus_enemy_defeated):
            _signal_bus.enemy_defeated.disconnect(_on_bus_enemy_defeated)
        if _signal_bus.item_collected.is_connected(_on_bus_item_collected):
            _signal_bus.item_collected.disconnect(_on_bus_item_collected)

func _process(delta: float) -> void:
    _hint_timer = maxf(0.0,_hint_timer-delta)
    if _player_dead or _level_complete_started: return
    var movement := _get_move_input()
    var aim := _get_aim_input()
    # Mobile firing must come only from the explicit FIRE button. Mouse emulation
    # of a movement touch must never become an accidental trigger.
    var fire_pressed := false
    if not OS.has_feature("mobile"):
        if hud==null or not hud.mobile_active:
            fire_pressed = Input.is_action_pressed("l3_fire") and get_viewport().gui_get_hovered_control()==null
    if not Input.is_action_pressed("l3_fire"): _mouse_fire_suppressed=false
    _mouse_fire_held = fire_pressed and not _mouse_fire_suppressed
    if player.throwable==&"": _pending_throw=false
    player.set_input(movement,aim,_fire_held or _mouse_fire_held,_pending_action,_pending_throw,_sprint_held or Input.is_action_pressed("l3_sprint"))
    # Edge actions stay pending until Level3Player consumes them in its fixed
    # physics tick, and then its acknowledgement clears the director latch.
    _hud_timer-=delta
    if _hud_timer<=0:
        _hud_timer=0.1
        _update_hud()

func _get_move_input() -> Vector2:
    if _mobile_move.length_squared() > 0.02:
        return _mobile_move
    return Input.get_vector("l3_move_left", "l3_move_right", "l3_move_up", "l3_move_down")

func _get_aim_input() -> Vector2:
    if _mobile_aim.length_squared()>0.015:
        _last_mobile_aim=_mobile_aim.normalized()
        return _last_mobile_aim
    if hud!=null and hud.mobile_active: return _last_mobile_aim
    var mouse_vector := get_global_mouse_position()-player.global_position
    return mouse_vector.normalized() if mouse_vector.length_squared()>4.0 else player.get_aim_direction()

func _scaled_cell_world(cell: Vector2i) -> Vector2:
    return StoreData.cell_to_world(cell) * LAYOUT_SCALE


func _build_static_world() -> void:
    environment=EnvironmentScene.new()
    environment.name="DinerEnvironment"
    add_child(environment)
    var audio_script = load("res://scripts/level3_audio.gd")
    if audio_script!=null:
        audio=Node2D.new()
        audio.set_script(audio_script)
        audio.name="DinerAudio"
        add_child(audio)

func _is_spawn_clear(position: Vector2) -> bool:
    var shape := CircleShape2D.new()
    shape.radius = 7.0
    var params := PhysicsShapeQueryParameters2D.new()
    params.shape = shape
    params.transform = Transform2D(0.0, position)
    params.collision_mask = 1
    params.collide_with_bodies = true
    params.collide_with_areas = false
    params.exclude = [player.get_rid()]
    return get_world_2d().direct_space_state.intersect_shape(params, 8).is_empty()


func _fail_spawn_position(position: Vector2) -> void:
    push_error(
        "Level 3 player spawn intersects authored collision at %s" % position
    )
    player.controls_enabled = false


func _configure_camera() -> void:
    var size_ := Vector2(StoreData.map_size())*StoreData.TILE_SIZE*LAYOUT_SCALE
    camera.reparent(self,true)
    camera.ignore_rotation=true
    camera.position_smoothing_enabled=true
    camera.position_smoothing_speed=9.0
    camera.zoom=Vector2.ONE*1.70
    camera.limit_left=-96
    camera.limit_top=-76
    camera.limit_right=int(size_.x+72)
    camera.limit_bottom=int(size_.y+162)
    camera.drag_horizontal_enabled=false
    camera.drag_vertical_enabled=false

func _create_doors() -> void:
    _doors.clear()

    for layout_node in layouts_root.get_children():
        if not layout_node is Node2D:
            continue

        var door_group := layout_node.get_node_or_null("Doors")
        if door_group == null:
            continue

        for door_node in door_group.get_children():
            if door_node is Level3Door:
                _doors.append(door_node as Level3Door)
                door_node.opened.connect(func(d: Level3Door):
                    if audio!=null: audio.play_at(&"door",d.global_position))
                door_node.slammed.connect(func(d: Level3Door):
                    if audio!=null: audio.play_at(&"door",d.global_position))


func _create_pickups() -> void:
    for pickup_data in StoreData.get_pickups():
        var cell: Vector2i = pickup_data["cell"]
        var kind: StringName = pickup_data["kind"]
        var pickup := PickupScene.instantiate() as Level3Pickup
        if pickup == null:
            continue
        pickup.name = "Pickup_%s_%02d_%02d" % [String(kind), cell.x, cell.y]
        pickup.kind = kind
        pickup.global_position = _scaled_cell_world(cell)
        pickups_root.add_child(pickup)

func _spawn_enemies() -> void:
    if not _enemies.is_empty():
        return

    for index in range(StoreData.get_enemy_spawns().size()):
        var spawn_data: Dictionary = StoreData.get_enemy_spawns()[index]
        var cell: Vector2i = spawn_data["cell"]
        var kind: StringName = spawn_data["kind"]
        var enemy := EnemyScene.instantiate() as Level3Enemy
        if enemy == null:
            continue
        enemy.name = "Enemy_%02d_%s" % [index + 1, String(kind)]
        enemy.enemy_kind = kind
        enemy.patrol_radius = float(spawn_data["patrol_radius"]) * LAYOUT_SCALE
        enemy.global_position = _scaled_cell_world(cell)
        enemies_root.add_child(enemy)
        enemy.shot_requested.connect(_on_enemy_shot_requested)
        _enemies.append(enemy)

    _enemies_alive = _enemies.size()
    objective_label.text = "ЦЕЛЬ: ЗАЧИСТИТЬ МАГАЗИН — %d" % _enemies_alive

func has_line_of_sight(from_position: Vector2, to_position: Vector2) -> bool:
    var query := PhysicsRayQueryParameters2D.create(from_position, to_position, 1)
    var result := get_world_2d().direct_space_state.intersect_ray(query)
    return result.is_empty()

func is_combat_paused() -> bool:
    return is_instance_valid(dialogue) and dialogue.is_active() or _level_complete_started or _player_dead

func _trace_weapon_shot(
    origin: Vector2,
    direction: Vector2,
    shooter: CollisionObject2D,
    max_distance: float = 650.0,
    shot_hit_cache: Dictionary = {},
    spawn_muzzle_flash: bool = true,
    impact_damage: int = 100
) -> void:
    var end := origin + direction.normalized() * max_distance
    var query := PhysicsRayQueryParameters2D.create(origin, end, 1)
    query.exclude = [shooter.get_rid()]
    var result := get_world_2d().direct_space_state.intersect_ray(query)

    var visual_end := end
    if not result.is_empty():
        visual_end = result["position"]

    _draw_shot_feedback(
        origin,
        visual_end,
        Color(1.0, 0.80, 0.30, 0.82) if not result.is_empty() else Color(1.0, 0.86, 0.40, 0.55)
    )

    _spawn_projectile_visual(
        origin,
        visual_end,
        func(impact_position: Vector2, collider: Node) -> void:
            if not collider is HitboxComponent:
                return
            var actor := (collider as HitboxComponent).get_parent()
            if not actor is Level3Enemy:
                return
            var enemy := actor as Level3Enemy
            if enemy.state == enemy.State.DEAD:
                return
            var enemy_id := enemy.get_instance_id()
            if shot_hit_cache.has(enemy_id):
                return
            shot_hit_cache[enemy_id] = true
            _spawn_blood_feedback(
                impact_position,
                -direction,
                true,
                1.25
            )
            enemy.receive_hit(impact_damage, shooter)
            feedback.confirm_hit(),
        spawn_muzzle_flash,
        650.0,
        "res://assets/level3/source/Combat/sprBullet_strip4.png",
        14.0,
        Vector2(1.1, 1.1),
        true,
        1 | 4,
        shooter,
        0
    )

func _acquire_projectile() -> Level3Projectile:
    if _projectile_pool == null:
        var fallback := ProjectileScene.instantiate() as Level3Projectile
        if fallback == null:
            return null
        add_child(fallback)
        return fallback

    var bullet := _projectile_pool.acquire() as Level3Projectile
    if bullet == null:
        return null

    bullet.set_recycle_callback(
        func() -> void:
            if _projectile_pool != null:
                _projectile_pool.release(bullet)
    )
    return bullet

func _spawn_projectile_visual(
    start: Vector2,
    end: Vector2,
    on_impact: Callable = Callable(),
    spawn_muzzle_flash: bool = true,
    projectile_speed: float = 650.0,
    projectile_texture: String = "res://assets/level3/source/Combat/sprBullet_strip4.png",
    projectile_fps: float = 14.0,
    projectile_scale: Vector2 = Vector2(1.1, 1.1),
    collision_enabled: bool = false,
    collision_mask: int = 0,
    ignored_actor: Node = null,
    impact_damage: int = 0
) -> void:
    var bullet := _acquire_projectile()
    if bullet == null:
        return
    bullet.z_index = 34
    bullet.setup(
        start,
        end,
        projectile_speed,
        on_impact,
        projectile_texture,
        projectile_fps,
        projectile_scale,
        collision_enabled,
        collision_mask,
        ignored_actor,
        impact_damage
    )
    if spawn_muzzle_flash:
        _spawn_muzzle_flash(start, start.direction_to(end).angle())

func _spawn_muzzle_flash(at: Vector2, angle: float) -> void: effects.muzzle(at,angle)

func _draw_shot_feedback(start: Vector2, end: Vector2, color: Color) -> void: effects.trace(start,end,color)

func _on_bus_weapon_changed(entity: Node, weapon: StringName, ammo: int) -> void:
    if entity == player:
        _on_player_weapon_changed(weapon, ammo)

func _on_bus_entity_died(entity: Node) -> void:
    if entity == player:
        _on_player_died()

func _on_bus_enemy_defeated(enemy: Node) -> void:
    if enemy is Level3Enemy and _enemies.has(enemy):
        _on_enemy_defeated(enemy as Level3Enemy)

func _on_bus_item_collected(
    item_kind: StringName,
    _item_id: StringName,
    amount: int,
    collector: Node
) -> void:
    if collector != player or amount <= 0:
        return
    _on_pickup_collected(item_kind)

func _on_player_fire_requested(
    origin: Vector2,
    direction: Vector2,
    weapon: StringName
) -> void:
    if _level_complete_started or _player_dead:
        return

    origin=safe_muzzle(player.global_position,direction,18.0)
    _notify_noise(origin)
    if audio!=null: audio.play_at(weapon,origin)
    _camera_kick=-direction*(3.0 if weapon==&"shotgun" else 1.3)

    if weapon == &"bat":
        _perform_bat_attack(origin, direction)
        return

    if weapon == &"shotgun":
        var shotgun_data := player.get_weapon_data()
        if shotgun_data == null:
            return
        _spawn_muzzle_flash(origin, direction.angle())
        var shotgun_hit_cache: Dictionary = {}
        for spread in shotgun_data.spread_angles:
            _trace_weapon_shot(
                origin,
                direction.rotated(float(spread)),
                player,
                shotgun_data.max_distance,
                shotgun_hit_cache,
                false,
                shotgun_data.damage
            )
        return

    var weapon_data: WeaponData = player.get_weapon_data()
    var max_distance := weapon_data.max_distance if weapon_data != null else 650.0
    var damage := weapon_data.damage if weapon_data != null else 100
    _trace_weapon_shot(origin, direction, player, max_distance, {}, true, damage)

func _perform_bat_attack(origin: Vector2, direction: Vector2) -> void:
    var shape := CircleShape2D.new()
    shape.radius = 48.0 * LAYOUT_SCALE
    var params := PhysicsShapeQueryParameters2D.new()
    params.shape = shape
    params.transform = Transform2D(0.0, origin + direction * 14.0)
    params.collision_mask = 2
    params.exclude = [player.get_rid()]

    var hits := get_world_2d().direct_space_state.intersect_shape(params, 16)
    var nearest_enemy: Level3Enemy = null
    var nearest_distance := INF

    for hit in hits:
        var collider := hit.get("collider") as Node
        if collider is Level3Enemy:
            var enemy := collider as Level3Enemy
            if enemy.state == enemy.State.DEAD:
                continue
            var to_enemy := player.global_position.direction_to(enemy.global_position)
            if absf(direction.angle_to(to_enemy)) > deg_to_rad(70.0):
                continue
            if not has_line_of_sight(player.global_position, enemy.global_position):
                continue
            var distance := player.global_position.distance_to(enemy.global_position)
            if distance < nearest_distance:
                nearest_distance = distance
                nearest_enemy = enemy

    if nearest_enemy != null:
        var bat_data := player.get_weapon_data()
        var bat_damage: int = bat_data.damage if bat_data != null else 100
        _spawn_blood_feedback(nearest_enemy.global_position, -direction, true, 1.05)
        nearest_enemy.receive_hit(bat_damage, player)
        feedback.confirm_hit()
        _notify_noise(player.global_position)

func interaction() -> Dictionary:
    # UI and actual ACTION resolve the same priority, range and line of sight.
    if is_combat_paused(): return {}
    var enemy := _find_nearest_stunned_enemy()
    if enemy!=null: return {"kind":&"finish","target":enemy,"label":"ДОБИТЬ"}
    var pickup := _find_nearest_pickup()
    if pickup!=null:
        var names := {&"bat":"БИТА",&"shotgun":"ДРОБОВИК",&"bottle":"БУТЫЛКА",&"pistol":"ПИСТОЛЕТ"}
        return {"kind":&"pickup","target":pickup,"label":names.get(pickup.kind,"ПОДОБРАТЬ")}
    var order := _scaled_cell_world(StoreData.ORDER_CELL)
    var exit_ := _scaled_cell_world(StoreData.EXIT_CELL)
    if _enemies_alive==0 and not order_collected and player.global_position.distance_to(order)<39 and has_line_of_sight(player.global_position,order):
        return {"kind":&"order","label":"ЗАБРАТЬ ЗАКАЗ"}
    if order_collected and player.global_position.distance_to(exit_)<40 and has_line_of_sight(player.global_position,exit_):
        return {"kind":&"exit","label":"ВЫЙТИ"}
    var door := _find_nearest_closed_door()
    if door!=null: return {"kind":&"door","target":door,"label":"ОТКРЫТЬ"}
    return {}

func _on_player_action_requested() -> void:
    var action := interaction()
    match action.get("kind",&""):
        &"finish":
            var enemy: Level3Enemy=action.target
            _spawn_blood_feedback(enemy.global_position,-player.get_aim_direction(),true,0.9)
            enemy.kill()
            if audio!=null: audio.play_at(&"bat",player.global_position)
        &"pickup": action.target.collect(player)
        &"order":
            order_collected=true
            environment.order_marker.visible=false
            environment.exit_marker.visible=true
            if audio!=null: audio.play_at(&"pickup",player.global_position)
            _set_hint("Заказ у тебя. Пора домой — выход у кассы.")
            _update_hud()
        &"exit": _finish_level()
        &"door": action.target.interact(player.global_position,false)

func _find_nearest_stunned_enemy() -> Level3Enemy:
    var best: Level3Enemy = null
    var best_distance := player.get_action_range() * LAYOUT_SCALE
    var aim := player.get_aim_direction()
    for enemy in _enemies:
        if not is_instance_valid(enemy) or not enemy.is_stunned():
            continue
        var distance := player.global_position.distance_to(enemy.global_position)
        if distance > best_distance:
            continue
        var to_enemy := player.global_position.direction_to(enemy.global_position)
        if absf(aim.angle_to(to_enemy)) > deg_to_rad(75.0):
            continue
        if not has_line_of_sight(player.global_position, enemy.global_position):
            continue
        best = enemy
        best_distance = distance
    return best

func _find_nearest_closed_door() -> Level3Door:
    var best: Level3Door=null
    var distance_ := 41.0
    for door in _doors:
        if not is_instance_valid(door) or door.is_open or door.is_opening: continue
        var distance := player.global_position.distance_to(door.global_position)
        if distance>distance_: continue
        var query := PhysicsRayQueryParameters2D.create(player.global_position,door.global_position,1)
        query.exclude=[door.pivot.get_rid()]
        if not get_world_2d().direct_space_state.intersect_ray(query).is_empty(): continue
        best=door
        distance_=distance
    return best

func _on_player_throw_requested(origin: Vector2, direction: Vector2) -> void:
    if dialogue.is_active() or _level_complete_started or _player_dead:
        return

    _notify_noise(origin)

    origin=safe_muzzle(player.global_position,direction,12.0)
    var target := _find_throw_target(origin, direction)
    var target_position := target.global_position if target != null else _find_throw_endpoint(origin, direction)
    _spawn_bottle_projectile(origin, target_position, target)
    _set_hint("Бутылка летит." if target != null else "Бутылка разбилась о стену.")

func _find_throw_target(origin: Vector2, direction: Vector2) -> Level3Enemy:
    var best: Level3Enemy = null
    var best_distance := 190.0
    for enemy in _enemies:
        if not is_instance_valid(enemy) or enemy.state == enemy.State.DEAD:
            continue
        var offset := enemy.global_position - origin
        var distance := offset.length()
        if distance > best_distance:
            continue
        var normalized_offset := offset.normalized()
        if absf(direction.angle_to(normalized_offset)) > deg_to_rad(34.0):
            continue
        if not has_line_of_sight(origin, enemy.global_position):
            continue
        best = enemy
        best_distance = distance
    return best

func _find_throw_endpoint(origin: Vector2, direction: Vector2) -> Vector2:
    var max_distance := 190.0
    var end := origin + direction.normalized() * max_distance
    var query := PhysicsRayQueryParameters2D.create(origin, end, 1)
    var result := get_world_2d().direct_space_state.intersect_ray(query)
    if result.is_empty():
        return end
    return result["position"]

func _spawn_bottle_projectile(start: Vector2, end: Vector2, _target: Level3Enemy) -> void:
    _spawn_projectile_visual(start,end,
        func(at: Vector2, collider: Node) -> void:
            if collider is HitboxComponent:
                var actor := (collider as HitboxComponent).get_parent()
                if actor is Level3Enemy: actor.stun(3.8)
            _spawn_bottle_impact(at),
        false,360.0,"res://assets/level3/source/Weapons/sprMolotov_strip4.png",8.0,Vector2(0.86,0.86),true,1|4,player,0)

func _spawn_bottle_impact(at: Vector2) -> void:
    effects.glass(at)
    if audio!=null: audio.play_at(&"glass",at)

func _spawn_blood_feedback(at: Vector2, direction: Vector2, permanent: bool, strength: float) -> void: effects.blood(at,direction,permanent,strength)

func _notify_noise(noise_position: Vector2) -> void:
    for enemy in _enemies:
        if is_instance_valid(enemy):
            enemy.hear_noise(noise_position)

func _on_enemy_shot_requested(shooter: Level3Enemy, origin: Vector2, direction: Vector2) -> void:
    if _player_dead or _level_complete_started:
        return
    if not is_instance_valid(shooter) or shooter.state == shooter.State.DEAD:
        return

    origin=safe_muzzle(shooter.global_position,direction,16.0)
    # Aim at the player's current position, but let the projectile continue
    # beyond that snapshot. A dodged shot must be able to pass the player.
    var shot_direction := direction.normalized()
    var max_distance := 900.0
    var far_end := origin + shot_direction * max_distance
    var query := PhysicsRayQueryParameters2D.create(origin, far_end, 1)
    query.exclude = [shooter.get_rid()]
    var wall_hit := get_world_2d().direct_space_state.intersect_ray(query)
    var end_position := far_end
    if not wall_hit.is_empty():
        end_position = wall_hit["position"]

    _spawn_enemy_projectile(origin, end_position, shooter)
    if audio!=null: audio.play_at(&"enemy_shot",origin)

func _spawn_enemy_projectile(start: Vector2, end: Vector2, shooter: Level3Enemy = null) -> void:
    var bullet := _acquire_projectile()
    if bullet == null:
        return
    bullet.z_index = 34
    bullet.setup(
        start,
        end,
        380.0,
        func(_impact_position: Vector2, _collider: Node) -> void:
            # Damage is delivered by the projectile's authoritative swept query.
            pass,
        "res://assets/level3/source/Combat/sprBullet_strip4.png",
        10.0,
        Vector2(1.1, 1.1),
        true,
        1 | 8,
        shooter,
        8
    )
    _spawn_muzzle_flash(start, start.direction_to(end).angle())

func _on_enemy_defeated(enemy: Level3Enemy) -> void:
    _enemies.erase(enemy)
    _enemies_alive=_enemies.size()
    if _enemies_alive==0:
        environment.order_marker.visible=true
        _set_hint("Тихо. Забери заказ на кухне.")
        if _signal_bus!=null: _signal_bus.mission_changed.emit(&"level3",&"cleared")
    _update_hud()

func _on_pickup_collected(kind: StringName) -> void:
    match kind:
        &"pistol": player.equip_weapon(&"pistol",12)
        &"shotgun":
            player.equip_weapon(&"shotgun",6)
            _set_hint("Дробовик. TAB / СМЕНИТЬ — смена оружия.")
        &"bat":
            player.equip_weapon(&"bat")
            _set_hint("Бита. Патроны не нужны. TAB / СМЕНИТЬ — смена оружия.")
        &"bottle":
            player.give_throwable(&"bottle")
            _set_hint("Бутылка. Q / БРОСОК — оглушить, E / ДЕЙСТВИЕ — добить.")
        &"ammo":
            player.add_ammo(12)
            _set_hint("+12 патронов для пистолета")
        &"medkit":
            player.heal(35)
            _set_hint("Аптечка: +35 здоровья")
    if audio!=null: audio.play_at(&"pickup",player.global_position)
    _update_hud()

func _on_player_weapon_changed(_weapon: StringName, _ammo: int) -> void:
    _update_hud()

func _on_player_died() -> void:
    if _player_dead: return
    _player_dead=true
    clear_inputs()
    hud.show_defeat()
    if _signal_bus!=null: _signal_bus.mission_changed.emit(&"level3",&"failed")

func _update_hud() -> void:
    if not is_instance_valid(player): return
    objective_label.text="Охрана: %d / %d"%[_enemies_alive,StoreData.ENEMY_SPAWNS.size()] if _enemies_alive>0 else ("Заказ у тебя · Вернись к выходу" if order_collected else "Забери заказ на кухне")
    var data := player.get_weapon_data()
    var name_ := data.display_name if data!=null else "ПИСТОЛЕТ"
    weapon_label.text="%s   %s\n%s"%[name_,("%02d"%player.ammo) if player.current_weapon!=&"bat" else "∞","Бутылка готова" if player.throwable!=&"" else ("TAB · Смена оружия" if hud==null or not hud.mobile_active else "")]
    status_label.text="ЗДОРОВЬЕ   %d"%player.health
    var context := interaction()
    var action: String=context.get("label","")
    action_button.text=action if not action.is_empty() else "ДЕЙСТВИЕ"
    action_button.self_modulate=Color(1.18,1.28,1.16) if not context.is_empty() else Color.WHITE
    if not action.is_empty():
        hint_label.text=("ДЕЙСТВИЕ · " if hud!=null and hud.mobile_active else "E · ")+action
    elif _hint_timer<=0:
        if player.ammo==0 and player.current_weapon!=&"bat":
            hint_label.text="Нет патронов · Смени оружие или подбери боезапас"
        else:
            hint_label.text="" if hud!=null and hud.mobile_active else "WASD · Движение     ЛКМ · Огонь     Q · Бросок     E · Действие     TAB · Оружие"

func _set_hint(message: String) -> void:
    hint_label.text = message
    _hint_timer = 2.6

func _on_move_joystick_changed(value: Vector2) -> void:
    _mobile_move = value

func _on_aim_joystick_changed(value: Vector2) -> void:
    _mobile_aim = value

func _on_fire_button_down() -> void:
    _fire_held = true

func _on_fire_button_up() -> void:
    _fire_held = false

func _on_action_button_pressed() -> void:
    _pending_action = true

func _on_throw_button_pressed() -> void:
    _pending_throw = true

func _on_sprint_button_down() -> void:
    _sprint_held = true

func _on_sprint_button_up() -> void:
    _sprint_held = false


func _initialize_navigation() -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if not is_inside_tree(): return
    navigation.build(self,Vector2(StoreData.map_size())*StoreData.TILE_SIZE*LAYOUT_SCALE,_doors)
    for enemy in _enemies:
        if not _is_spawn_clear(enemy.global_position): push_error("Level 3 enemy spawn intersects scenery: "+str(enemy.name))
    for pickup in pickups_root.get_children():
        if not _is_spawn_clear(pickup.global_position): push_error("Level 3 pickup intersects scenery: "+str(pickup.name))

func _on_edges_consumed() -> void:
    _pending_action=false
    _pending_throw=false

func _input(event: InputEvent) -> void:
    if _player_dead or _level_complete_started or get_tree().paused: return
    if event.is_action_pressed("l3_action") and not event.is_echo():
        _pending_action=true
        get_viewport().set_input_as_handled()
    elif event.is_action_pressed("l3_throw") and not event.is_echo():
        _pending_throw=true
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_node_ready() and not _level_complete_started:
        clear_inputs()
        if hud!=null: hud.clear_touches()
        _pause_manager.set_paused(true)

func clear_inputs() -> void:
    _mobile_move=Vector2.ZERO
    _mobile_aim=Vector2.ZERO
    _fire_held=false
    _mouse_fire_held=false
    _sprint_held=false
    _pending_action=false
    _pending_throw=false
    _mouse_fire_suppressed=true
    for action in ["l3_move_left","l3_move_right","l3_move_up","l3_move_down","l3_fire","l3_action","l3_throw","l3_sprint"]: Input.action_release(action)
    if is_instance_valid(player): player.clear_controls()

func is_body_path_clear(from: Vector2, to: Vector2) -> bool:
    _body_query.transform=Transform2D(0,from)
    _body_query.motion=to-from
    var cast := get_world_2d().direct_space_state.cast_motion(_body_query)
    return cast.size()==2 and cast[0]>0.999

func _find_nearest_pickup() -> Level3Pickup:
    var best: Level3Pickup
    var distance_ := 32.0
    for child in pickups_root.get_children():
        var pickup := child as Level3Pickup
        if pickup==null or pickup.consumed or pickup.is_automatic(): continue
        var distance := player.global_position.distance_to(pickup.global_position)
        if distance<=distance_ and has_line_of_sight(player.global_position,pickup.global_position):
            best=pickup
            distance_=distance
    return best

func _physics_process(delta: float) -> void:
    if _player_dead or _level_complete_started: return
    _camera_kick=_camera_kick.move_toward(Vector2.ZERO,18*delta)
    var offset := player.get_aim_direction()*26+player.velocity*0.08+_camera_kick
    camera.global_position=player.global_position+offset
    _step_timer-=delta
    if player.velocity.length()>40 and _step_timer<=0 and audio!=null:
        _step_timer=0.26 if _sprint_held or Input.is_action_pressed("l3_sprint") else 0.34
        audio.play_at(&"step",player.global_position)

func _finish_level() -> void:
    if _level_complete_started or not order_collected or _enemies_alive>0: return
    _level_complete_started=true
    player.controls_enabled=false
    clear_inputs()
    hud.clear_touches()
    await hud.fade_out()
    if _signal_bus!=null:
        _signal_bus.emit_signal(&"mission_changed",&"level3",&"completed")
        _signal_bus.emit_signal(&"level_completed", &"level3")

func safe_muzzle(center: Vector2, direction: Vector2, distance_: float) -> Vector2:
    # An extended muzzle must not spawn beyond a thin wall/closed door when
    # the body is pressed against it. Start on the actor's side of that wall.
    var end := center+direction.normalized()*distance_
    var ray := PhysicsRayQueryParameters2D.create(center,end,1)
    var collision := get_world_2d().direct_space_state.intersect_ray(ray)
    return collision.position-direction.normalized() if not collision.is_empty() else end
