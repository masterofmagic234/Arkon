extends Node2D
class_name Level3Store

const StoreData = preload("res://scripts/level3_store_data.gd")
const EnemyScript = preload("res://scripts/level3_enemy.gd")
const DoorScene = preload("res://scenes/level3_door.tscn")
const PickupScript = preload("res://scripts/level3_pickup.gd")
const AssetVisual = preload("res://scripts/level3_asset_visual.gd")
const BloodParticlesScene = preload("res://scenes/level3_blood_particles.tscn")
const ProjectileScene = preload("res://scenes/level3_projectile.tscn")
const WeaponData = preload("res://scripts/weapon_data.gd")

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
var _death_timer: float = 0.0
var _clear_timer: float = -1.0
var _hint_timer: float = 0.0

var _doors: Array[Level3Door] = []
var _enemies: Array[Level3Enemy] = []

func _ready() -> void:
    _build_static_world()
    _configure_camera()
    _create_doors()
    _create_pickups()

    player.global_position = _scaled_cell_world(StoreData.player_spawn())
    player.controls_enabled = true

    player.fire_requested.connect(_on_player_fire_requested)
    player.action_requested.connect(_on_player_action_requested)
    player.throw_requested.connect(_on_player_throw_requested)
    player.weapon_changed.connect(_on_player_weapon_changed)
    player.died.connect(_on_player_died)

    dialogue.finished.connect(_on_dialogue_finished)

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
    _set_hint("Зачистите ночное кафе. Диалоги временно отключены.")
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("mission_changed"):
        bus.mission_changed.emit(&"level3", &"started")

func _start_intro_dialogue() -> void:
    if is_instance_valid(dialogue):
        dialogue.start_dialogue(StoreData.get_intro_dialogue())

func _process(delta: float) -> void:
    _hint_timer = maxf(0.0, _hint_timer - delta)
    if _clear_timer >= 0.0:
        _clear_timer -= delta
        if _clear_timer <= 0.0:
            _clear_timer = -1.0
            _level_complete_started = true
            player.controls_enabled = false
            dialogue.start_dialogue(StoreData.get_clear_dialogue())

    if _player_dead:
        _death_timer -= delta
        if _death_timer <= 0.0:
            get_tree().reload_current_scene()
        return

    var dialogue_active := dialogue.is_active()
    var movement := _get_move_input()
    var aim := _get_aim_input()

    var mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
    if dialogue_active:
        if mouse_pressed:
            # The same physical click that advances the final dialogue line
            # must not become a gameplay shot on the next frame.
            _mouse_fire_suppressed = true
        _mouse_fire_held = false
    else:
        if not mouse_pressed:
            _mouse_fire_suppressed = false
        _mouse_fire_held = mouse_pressed and not _mouse_fire_suppressed

    var action_down := Input.is_key_pressed(KEY_E)
    if action_down and not _keyboard_action_down:
        _pending_action = true
    _keyboard_action_down = action_down

    var throw_down := Input.is_key_pressed(KEY_Q)
    if throw_down and not _keyboard_throw_down:
        _pending_throw = true
    _keyboard_throw_down = throw_down

    _sprint_held = _sprint_held or Input.is_key_pressed(KEY_SHIFT)

    if dialogue_active or _level_complete_started:
        movement = Vector2.ZERO
        _fire_held = false
        _mouse_fire_held = false
        _pending_action = false
        _pending_throw = false

    player.set_input(
        movement,
        aim,
        _fire_held or _mouse_fire_held,
        _pending_action,
        _pending_throw,
        _sprint_held
    )
    _pending_action = false
    _pending_throw = false

    _update_hud()

func _get_move_input() -> Vector2:
    if _mobile_move.length_squared() > 0.02:
        return _mobile_move
    return Input.get_vector("l3_move_left", "l3_move_right", "l3_move_up", "l3_move_down")

func _get_aim_input() -> Vector2:
    if _mobile_aim.length_squared() > 0.04:
        return _mobile_aim.normalized()
    var mouse_vector := get_global_mouse_position() - player.global_position
    if mouse_vector.length_squared() > 0.04:
        return mouse_vector.normalized()
    return player.get_aim_direction()

func _scaled_cell_world(cell: Vector2i) -> Vector2:
    return StoreData.cell_to_world(cell) * LAYOUT_SCALE


func _build_static_world() -> void:
    # Walls and furniture collisions are authored in level3_layout.tscn.
    pass


func _configure_camera() -> void:
    var min_left := 0.0
    var min_top := 0.0
    var max_right := CHUNK_WIDTH
    var max_bottom := CHUNK_HEIGHT

    for layout_node in layouts_root.get_children():
        if not layout_node is Node2D:
            continue

        var layout_pos := (layout_node as Node2D).position
        min_left = minf(min_left, layout_pos.x)
        min_top = minf(min_top, layout_pos.y)
        max_right = maxf(max_right, layout_pos.x + CHUNK_WIDTH)
        max_bottom = maxf(max_bottom, layout_pos.y + CHUNK_HEIGHT)

    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 12.0
    camera.zoom = Vector2(1.75, 1.75)
    camera.limit_left = int(min_left * LAYOUT_SCALE)
    camera.limit_top = int(min_top * LAYOUT_SCALE)
    camera.limit_right = int(max_right * LAYOUT_SCALE)
    camera.limit_bottom = int(max_bottom * LAYOUT_SCALE)
    camera.drag_horizontal_enabled = false
    camera.drag_vertical_enabled = false


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


func _create_pickups() -> void:
    for pickup_data in StoreData.get_pickups():
        var pickup := PickupScript.new() as Level3Pickup
        var cell: Vector2i = pickup_data["cell"]
        var kind: StringName = pickup_data["kind"]
        pickup.name = "Pickup_%s_%02d_%02d" % [String(kind), cell.x, cell.y]
        pickups_root.add_child(pickup)
        pickup.setup(kind, _scaled_cell_world(cell))
        pickup.collected.connect(_on_pickup_collected)

func _spawn_enemies() -> void:
    if not _enemies.is_empty():
        return

    for index in range(StoreData.get_enemy_spawns().size()):
        var spawn_data: Dictionary = StoreData.get_enemy_spawns()[index]
        var enemy := EnemyScript.new() as Level3Enemy
        var cell: Vector2i = spawn_data["cell"]
        var kind: StringName = spawn_data["kind"]
        enemy.name = "Enemy_%02d_%s" % [index + 1, String(kind)]
        enemies_root.add_child(enemy)
        enemy.global_position = _scaled_cell_world(cell)
        enemy.setup(self, player, kind, float(spawn_data["patrol_radius"]) * LAYOUT_SCALE)
        enemy.shot_requested.connect(_on_enemy_shot_requested)
        enemy.defeated.connect(_on_enemy_defeated)
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
    var query := PhysicsRayQueryParameters2D.create(origin, end, 1 | 2)
    query.exclude = [shooter.get_rid()]
    var result := get_world_2d().direct_space_state.intersect_ray(query)

    if result.is_empty():
        _draw_shot_feedback(origin, end, Color(1.0, 0.86, 0.40, 0.55))
        _spawn_projectile_visual(origin, end, Callable(), spawn_muzzle_flash)
        return

    var hit_position: Vector2 = result["position"]
    _draw_shot_feedback(origin, hit_position, Color(1.0, 0.80, 0.30, 0.82))

    var collider := result["collider"] as Node
    if collider is Level3Enemy:
        var enemy := collider as Level3Enemy
        var enemy_id := enemy.get_instance_id()
        var should_apply_hit := not shot_hit_cache.has(enemy_id)
        if should_apply_hit:
            shot_hit_cache[enemy_id] = true

        if should_apply_hit:
            _spawn_projectile_visual(
                origin,
                hit_position,
                func() -> void:
                    if not is_instance_valid(enemy) or enemy.state == enemy.State.DEAD:
                        return
                    # The raycast found a target instantly, but damage is synced
                    # to the visible projectile. Revalidate that the same enemy
                    # is still at the impact point so a dodged target is not hit
                    # by a ghost projectile.
                    if enemy.global_position.distance_to(hit_position) > 24.0:
                        return
                    if not has_line_of_sight(hit_position, enemy.global_position):
                        return
                    _spawn_blood_feedback(hit_position, -direction, true, 1.25)
                    enemy.receive_hit(impact_damage, shooter),
                spawn_muzzle_flash
            )
        else:
            # Keep the pellet visible, but do not apply duplicate damage/blood.
            _spawn_projectile_visual(origin, hit_position, Callable(), spawn_muzzle_flash)
        return

    # Player hitscan never needs to damage its own shooter: the query excludes
    # the shooter RID, and enemy fire uses the separate projectile path.
    _spawn_projectile_visual(origin, hit_position, Callable(), spawn_muzzle_flash)

func _spawn_projectile_visual(
    start: Vector2,
    end: Vector2,
    on_impact: Callable = Callable(),
    spawn_muzzle_flash: bool = true,
    projectile_speed: float = 650.0,
    projectile_texture: String = "res://assets/level3/source/Combat/sprBullet_strip4.png",
    projectile_fps: float = 14.0,
    projectile_scale: Vector2 = Vector2(2.3, 2.3)
) -> void:
    var bullet := ProjectileScene.instantiate() as Level3Projectile
    if bullet == null:
        return
    add_child(bullet)
    bullet.z_index = 34
    bullet.setup(
        start,
        end,
        projectile_speed,
        on_impact,
        projectile_texture,
        projectile_fps,
        projectile_scale,
        false
    )
    if spawn_muzzle_flash:
        _spawn_muzzle_flash(start, start.direction_to(end).angle())

func _spawn_muzzle_flash(_position: Vector2, angle: float) -> void:
    var flash := AssetVisual.animated_strip(
        "res://assets/level3/source/Combat/sprBulletHit_strip11.png",
        28.0,
        Vector2(1.15, 1.15),
        false
    )
    if flash == null:
        return
    flash.global_position = _position
    flash.rotation = angle
    flash.z_index = 35
    add_child(flash)
    flash.animation_finished.connect(flash.queue_free, CONNECT_ONE_SHOT)

func _draw_shot_feedback(start: Vector2, end: Vector2, color: Color) -> void:
    var tracer := Line2D.new()
    tracer.width = 2.0
    tracer.default_color = color
    tracer.z_index = 30
    add_child(tracer)
    tracer.add_point(start)
    tracer.add_point(end)
    var tween := create_tween()
    tween.tween_property(tracer, "modulate:a", 0.0, 0.07)
    tween.tween_callback(tracer.queue_free)

func _on_player_fire_requested(
    origin: Vector2,
    direction: Vector2,
    weapon: StringName
) -> void:
    if dialogue.is_active() or _level_complete_started or _player_dead:
        return

    _notify_noise(origin)

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
        _notify_noise(player.global_position)

func _on_player_action_requested() -> void:
    if dialogue.is_active() or _level_complete_started or _player_dead:
        return

    var stunned_enemy := _find_nearest_stunned_enemy()
    if stunned_enemy != null:
        _spawn_blood_feedback(stunned_enemy.global_position, -player.get_aim_direction(), true, 1.05)
        stunned_enemy.kill()
        _notify_noise(player.global_position)
        return

    var door := _find_nearest_closed_door()
    if door != null:
        if door.interact(player.global_position, false):
            _set_hint("Дверь открывается.")
        else:
            _set_hint("Дверь не может открыться сейчас.")
        return

    _set_hint("Здесь нечего делать.")

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
    var best: Level3Door = null
    var best_distance := maxf(player.get_action_range() * LAYOUT_SCALE, 64.0)
    for door in _doors:
        if not is_instance_valid(door) or door.is_open:
            continue
        var distance := player.global_position.distance_to(door.get_interaction_position())
        if distance <= best_distance:
            best = door
            best_distance = distance
    return best

func _on_player_throw_requested(origin: Vector2, direction: Vector2) -> void:
    if dialogue.is_active() or _level_complete_started or _player_dead:
        return

    _notify_noise(origin)

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

func _spawn_bottle_projectile(start: Vector2, end: Vector2, target: Level3Enemy) -> void:
    var bottle := ProjectileScene.instantiate() as Level3Projectile
    if bottle == null:
        return
    add_child(bottle)
    bottle.z_index = 33
    bottle.setup(
        start,
        end,
        360.0,
        func() -> void:
            if target != null and is_instance_valid(target):
                if target.state != target.State.DEAD and target.global_position.distance_to(end) <= 48.0:
                    if has_line_of_sight(end, target.global_position):
                        target.stun(3.8)
            _spawn_bottle_impact(end),
        "res://assets/level3/source/Weapons/sprMolotov_strip4.png",
        8.0,
        Vector2(1.45, 1.45),
        false
    )

func _spawn_bottle_impact(position: Vector2) -> void:
    var impact := AssetVisual.animated_strip(
        "res://assets/level3/source/Weapons/sprBreakingBottle_strip4.png",
        18.0,
        Vector2(1.15, 1.15),
        false
    )
    if impact == null:
        return
    impact.global_position = position
    impact.z_index = 34
    add_child(impact)
    impact.animation_finished.connect(impact.queue_free, CONNECT_ONE_SHOT)

func _spawn_blood_feedback(
    _position: Vector2,
    impact_direction: Vector2,
    permanent_puddle: bool,
    strength: float
) -> void:
    var blood := BloodParticlesScene.instantiate() as Level3BloodParticles
    if blood == null:
        return

    blood.global_position = _position
    blood.setup(impact_direction, strength, permanent_puddle)
    add_child(blood)

func _notify_noise(noise_position: Vector2) -> void:
    for enemy in _enemies:
        if is_instance_valid(enemy):
            enemy.hear_noise(noise_position)

func _on_enemy_shot_requested(shooter: Level3Enemy, origin: Vector2, _direction: Vector2) -> void:
    if _player_dead or dialogue.is_active() or _level_complete_started:
        return
    if not is_instance_valid(shooter) or shooter.state == shooter.State.DEAD:
        return

    # Aim at the player's current position, but let the projectile continue
    # beyond that snapshot. A dodged shot must be able to pass the player.
    var shot_direction := origin.direction_to(player.global_position)
    var max_distance := 900.0
    var far_end := origin + shot_direction * max_distance
    var query := PhysicsRayQueryParameters2D.create(origin, far_end, 1)
    query.exclude = [shooter.get_rid()]
    var wall_hit := get_world_2d().direct_space_state.intersect_ray(query)
    var end_position := far_end
    if not wall_hit.is_empty():
        end_position = wall_hit["position"]

    _spawn_enemy_projectile(origin, end_position, shooter)

func _spawn_enemy_projectile(start: Vector2, end: Vector2, shooter: Level3Enemy = null) -> void:
    var bullet := ProjectileScene.instantiate() as Level3Projectile
    if bullet == null:
        return
    add_child(bullet)
    bullet.z_index = 34
    bullet.setup(
        start,
        end,
        480.0,
        func() -> void:
            # Damage is delivered by collision with the player's HitboxComponent.
            pass,
        "res://assets/level3/source/Combat/sprBullet_strip4.png",
        10.0,
        Vector2(2.3, 2.3),
        true,
        8,
        shooter,
        20
    )
    _spawn_muzzle_flash(start, start.direction_to(end).angle())

func _on_enemy_defeated(enemy: Level3Enemy) -> void:
    _enemies.erase(enemy)
    _enemies_alive = maxi(0, _enemies_alive - 1)
    objective_label.text = "ЦЕЛЬ: ЗАЧИСТИТЬ МАГАЗИН — %d" % _enemies_alive
    if _enemies_alive == 0 and not _level_complete_started:
        _set_hint("КАФЕ ЗАЧИЩЕНО.")
        var bus := get_node_or_null("/root/SignalBus")
        if bus != null and bus.has_signal("level_completed"):
            bus.level_completed.emit(&"level3")

func _on_pickup_collected(kind: StringName) -> void:
    match kind:
        &"pistol":
            player.equip_weapon(&"pistol", 12)
            _set_hint("Пистолет подобран. ЛКМ / FIRE — стрелять.")
        &"shotgun":
            player.equip_weapon(&"shotgun", 6)
            _set_hint("Дробовик подобран. Один выстрел — несколько направлений.")
        &"bat":
            player.equip_weapon(&"bat")
            _set_hint("Бита в руках. FIRE — удар, ACTION — добивание оглушённого врага.")
        &"bottle":
            player.give_throwable(&"bottle")
            _set_hint("Бутылка готова. THROW — бросок для оглушения.")

func _on_player_weapon_changed(_weapon: StringName, _ammo: int) -> void:
    _update_hud()

func _on_player_died() -> void:
    _player_dead = true
    _death_timer = 1.15
    _fire_held = false
    _sprint_held = false
    _set_hint("КАРОЛИНА ПОГИБЛА")

func _on_dialogue_finished() -> void:
    if _level_complete_started:
        get_tree().change_scene_to_file("res://menu.tscn")
        return

    player.controls_enabled = true
    _spawn_enemies()
    _set_hint("WASD + мышь / левый и правый стики. ACTION — дверь или добивание.")

func _update_hud() -> void:
    var weapon_name := "ПИСТОЛЕТ"
    if player.current_weapon == &"shotgun":
        weapon_name = "ДРОБОВИК"
    elif player.current_weapon == &"bat":
        weapon_name = "БИТА"

    var throwable_name := "НЕТ"
    if player.throwable != &"":
        throwable_name = "БУТЫЛКА"

    weapon_label.text = "ОРУЖИЕ: %s  |  ПАТРОНЫ: %d  |  БРОСКИ: %s" % [
        weapon_name,
        player.ammo,
        throwable_name
    ]

    if _hint_timer <= 0.0:
        status_label.text = "HP: %d / %d" % [player.health, player.max_health]
        if player.current_weapon == &"bat":
            hint_label.text = "FIRE — удар • ACTION — добивание"
        else:
            hint_label.text = "FIRE — стрельба • THROW — бросок • ACTION — дверь/добивание"
        status_label.text = ""


func _set_hint(message: String) -> void:
    hint_label.text = message
    status_label.text = message
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

