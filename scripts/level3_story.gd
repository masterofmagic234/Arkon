extends Node2D
## The diner starts peacefully. The police-style assault is a physical arrival,
## not enemies materialising in rooms. All clocks stop with the game pause.
const Data = preload("res://scripts/level3_store_data.gd")
const Visual = preload("res://scripts/level3_asset_visual.gd")
const Lines = preload("res://scripts/level3_dialogue_lines.gd")
const Vehicle = preload("res://scripts/level3_vehicle_visual.gd")
const Director = preload("res://scripts/level3_raid_director.gd")
const CAR_POSITION := Vector2(156, 873.6)
const RECEPTION := Vector2(180, 660)
const CHEF_POSITION := Vector2(696, 100)
const BREACH := Vector2(12, 432)
const VAN_STOP := Director.VAN_STOP
const STACKS = [Vector2(130,800),Vector2(193,800),Vector2(1007,800),Vector2(1066,800),Vector2(-31,113),Vector2(-31,269),Vector2(-31,432),Vector2(96,-31),Vector2(252,-31),Vector2(372,-31)]
const STACK_AIMS = [Vector2(156,756),Vector2(156,756),Vector2(1020,756),Vector2(1020,756),Vector2(12,113),Vector2(12,269),Vector2(12,432),Vector2(96,12),Vector2(252,12),Vector2(372,12)]
var world
var phase: StringName = &"street"
var history: Array[StringName] = [&"street"]
var clock := 0.0
var car
var van
var chef: AnimatedSprite2D
var window_body: StaticBody2D
var glass_broken := false
var flashbang_detonated := false
var deployment_count := 0
var deployed_positions: Array[Vector2] = []
var deployed_facings: Array[float] = []
var boarding_started := false
var boarding_finished := false
var raid_skipped := false
var shot: StringName = &""
var shot_history: Array[StringName] = []
var shot_extent := Vector2.ZERO
var _last_van := Vector2.ZERO
var _skids: Array[Line2D] = []
var _arrival_sounds: Array[AudioStreamPlayer2D] = []
var _flash: ColorRect
var _flash_layer: CanvasLayer
var _grenade: Node2D
var _flash_clock := -1.0
var _spawn_clock := 0.0
var _camera_start := Vector2.ZERO
var _return_clock := 0.0
var _board_from := Vector2.ZERO
var _car_body: StaticBody2D
var _van_body: StaticBody2D
var _chef_clock := 0.0
var _cinematic_listener: AudioListener2D
var _player_listener: AudioListener2D
var _gameplay_camera_smoothing := true

func setup(store) -> void:
    world = store
    world.player.set_combat_enabled(false)
    world.pickups_root.hide()
    name = "DinerStory"
    _make_vehicle_props()
    _make_chef()
    _make_breach_glass()
    _make_bounds()
    _flash_layer = CanvasLayer.new()
    _flash_layer.layer = 6
    add_child(_flash_layer)
    _flash = ColorRect.new()
    _flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _flash.color = Color(1, .98, .87, 0)
    _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _flash_layer.add_child(_flash)
    world.dialogue.finished.connect(_on_dialogue_finished)
    for child in world.player.get_children():
        if child is AudioListener2D: _player_listener = child
    _cinematic_listener = AudioListener2D.new()
    _cinematic_listener.name = "CinematicListener"
    world.camera.add_child(_cinematic_listener)

func controls_locked() -> bool:
    return phase in [&"reception", &"conversation", &"arrival", &"deployment", &"breach", &"return", &"aftermath", &"boarding"]

func camera_locked() -> bool:
    return phase in [&"arrival", &"deployment", &"breach", &"return", &"boarding"]

func is_raid_cinematic() -> bool:
    return phase in [&"arrival", &"deployment", &"breach", &"return"]

func combat_available() -> bool:
    return phase == &"assault"

func _phase(value: StringName) -> void:
    phase = value
    clock = 0.0
    history.append(value)
    world.clear_inputs()
    if world.hud != null:
        world.hud.clear_touches()
        world.hud.set_cinematic_mode(camera_locked(), is_raid_cinematic())
    world.player.controls_enabled = not controls_locked()
    world.player.set_combat_enabled(combat_available())
    if camera_locked() and is_instance_valid(_cinematic_listener): _cinematic_listener.make_current()
    elif is_instance_valid(_player_listener): _player_listener.make_current()
    world._update_hud()

func objective() -> String:
    match phase:
        &"street": return "ЗАЙДИ В ЗАКУСОЧНУЮ · Позови сотрудника у кассы"
        &"reception": return "ЕСТЬ КТО-НИБУДЬ?"
        &"kitchen": return "НАЙДИ СОТРУДНИКА НА КУХНЕ"
        &"conversation": return "ЗАКАЗ НА ИМЯ ТАИ"
        &"arrival", &"deployment", &"breach", &"return": return "БЕЛИЧИЙ СПЕЦНАЗ · ДЕЙСТВИЕ / ENTER — ПРОПУСТИТЬ"
        &"assault": return "ОТБЕЙ ШТУРМ · Противников: %d" % world._enemies_alive
        &"cleared": return "ВЕРНИСЬ К ПОВАРУ НА КУХНЮ"
        &"aftermath": return "ТВОЯ ПИЦЦА ВСЁ ЕЩЁ ГОРЯЧАЯ"
        &"pizza": return "ЗАБЕРИ ПИЦЦУ ПЕРЕД ПОВАРОМ"
        &"exit": return "ВЕРНИСЬ К 240 · Дверь откроется сама"
        &"boarding": return "ПОРА ДОМОЙ"
    return ""

func interaction() -> Dictionary:
    if phase == &"street" and world.player.global_position.distance_to(RECEPTION) < 55:
        return {"kind": &"reception", "label": "ПОЗВАТЬ СОТРУДНИКА"}
    if phase in [&"kitchen", &"cleared"] and world.player.global_position.distance_to(CHEF_POSITION) < 112:
        var room: Dictionary = Data.room_at(world.player.global_position / 1.5)
        if room.id == &"kitchen":
            return {"kind": &"chef", "label": "СПРОСИТЬ ПРО ПИЦЦУ" if phase == &"kitchen" else "ПОГОВОРИТЬ С ПОВАРОМ"}
    return {}

func interact(kind: StringName) -> void:
    if kind == &"reception" and phase == &"street":
        _phase(&"reception")
        world.dialogue.start_dialogue(Lines.RECEPTION)
    elif kind == &"chef" and phase == &"kitchen":
        _phase(&"conversation")
        world.dialogue.start_dialogue(Lines.KITCHEN)
    elif kind == &"chef" and phase == &"cleared":
        _phase(&"aftermath")
        world.dialogue.start_dialogue(Lines.AFTERMATH)

func _on_dialogue_finished() -> void:
    if phase == &"reception": _phase(&"kitchen")
    elif phase == &"conversation": begin_raid()
    elif phase == &"aftermath":
        _phase(&"pizza")
        world.environment.order_marker.show()

func begin_raid() -> void:
    if phase in [&"arrival", &"deployment", &"breach", &"return", &"assault"]: return
    _camera_start = world.camera.global_position
    _gameplay_camera_smoothing = world.camera.position_smoothing_enabled
    world.camera.position_smoothing_enabled = false
    world.pickups_root.hide()
    _phase(&"arrival")
    van.show()
    van.transform = Director.arrival_transform(0)
    van.scale = Vector2.ONE * 1.005
    _camera_shot(Director.arrival_shot(0))
    _last_van = van.position
    for side in [-1, 1]:
        var skid := Line2D.new()
        skid.z_index = -6
        skid.width = 4.0
        skid.default_color = Color(.015,.022,.026,.78)
        add_child(skid)
        _skids.append(skid)
    _arrival_sounds = [_loop_sound("res://assets/vehicle_audio/engine_6300_load.wav", -13), _loop_sound("res://assets/vehicle_audio/tire_scrub.wav", -10)]

func skip_raid() -> void:
    if not is_raid_cinematic() or get_tree().paused: return
    raid_skipped = true
    _stop_arrival_sounds()
    van.position = VAN_STOP
    van.rotation = Director.VAN_STOP_ROTATION
    van.door_open_amount = 1.0
    _solid_van()
    # Skip commits the same arrival result; normal playback never uses this path.
    while deployment_count < 10: _deploy_one(true)
    deployed_positions.clear()
    deployed_facings.clear()
    for index in range(world._enemies.size()):
        var enemy = world._enemies[index]
        enemy.global_position = STACKS[index]
        enemy.staging_path.clear()
        enemy.velocity = Vector2.ZERO
        enemy.rotation = enemy.global_position.direction_to(STACK_AIMS[index]).angle()
        deployed_positions.append(enemy.global_position)
        deployed_facings.append(enemy.rotation)
    _break_glass()
    flashbang_detonated = true
    _flash_clock = .9
    _begin_assault()
    world.camera.zoom = Vector2.ONE * 1.7
    world.camera.global_position = world.player.global_position
    world.camera.reset_smoothing()

func _process(delta: float) -> void:
    if get_node("/root/SceneFlow").is_loading_gameplay(): return
    if world == null or world._player_dead or world._level_complete_started: return
    clock += delta
    _chef_clock += delta
    if is_instance_valid(chef):
        chef.frame = (int(_chef_clock * 6) % 5) if phase in [&"conversation", &"aftermath"] else (4 if phase in [&"deployment", &"breach", &"return", &"cleared", &"pizza", &"exit"] else 0)
    if _flash_clock >= 0:
        _flash_clock += delta
        _flash.color.a = .94 * maxf(0.0, 1.0 - _flash_clock / 1.0)
        if _flash_clock >= 1.0: _flash_clock = -1.0
    if phase == &"arrival": _arrival(delta)
    elif phase == &"deployment": _deployment(delta)
    elif phase == &"breach": _breach(delta)
    elif phase == &"return":
        # The flash covers this cut back to Carolina; never fly the camera
        # across the whole building after the grenade insert.
        if shot != &"carolina_return":
            shot = &"carolina_return"
            shot_history.append(shot)
            world.camera.global_position = world.player.global_position
            world.camera.zoom = Vector2.ONE * 1.7
            shot_extent = world.get_viewport_rect().size / 1.7
            world.camera.reset_smoothing()
        if clock >= .45: _begin_assault()
    elif phase == &"exit": _auto_board(delta)
    elif phase == &"boarding": _boarding(delta)
    if phase == &"street":
        # The reception line is triggered by physically reaching its counter.
        if world.player.global_position.distance_to(RECEPTION) < 47: interact(&"reception")
    for door in world._doors:
        if door.name in ["Door_06_31", "Door_42_31"] and world.player.global_position.distance_to(door.global_position) < 60 and not door.is_open and not door.is_opening:
            door.interact(world.player.global_position)

func _arrival(_delta: float) -> void:
    var t := clampf(clock / Director.ARRIVAL_DURATION, 0, 1)
    van.transform = Director.arrival_transform(t)
    van.scale = Vector2.ONE * 1.005
    _camera_shot(Director.arrival_shot(clock))
    if _last_van.distance_to(van.position) >= 3 and t < .99:
        for i in range(_skids.size()):
            var wheel := Vector2(-35, -19 if i == 0 else 19).rotated(van.rotation)
            _skids[i].add_point(van.position + wheel)
    _last_van = van.position
    _update_arrival_sound()
    if clock >= Director.ARRIVAL_DURATION:
        van.position = VAN_STOP
        van.rotation = Director.VAN_STOP_ROTATION
        _stop_arrival_sounds()
        _solid_van()
        world.audio.play_at(&"door", van.position)
        _phase(&"deployment")
        _camera_shot(Director.deployment_shot(0))

func _deployment(delta: float) -> void:
    van.door_open_amount = minf(1, clock / .55)
    _camera_shot(Director.deployment_shot(clock))
    _spawn_clock += delta
    if clock > .6 and _spawn_clock >= .18 and deployment_count < 10:
        _spawn_clock = 0
        _deploy_one()
    var positioned := deployment_count == 10
    for enemy in world._enemies:
        if not enemy.staging_path.is_empty(): positioned = false
    if positioned:
        deployed_positions.clear()
        deployed_facings.clear()
        for enemy in world._enemies:
            deployed_positions.append(enemy.global_position)
            deployed_facings.append(enemy.rotation)
        _phase(&"breach")
        world._set_hint("Они окружают здание…")

func _deploy_one(skipped := false) -> void:
    var index := deployment_count
    var target: Vector2 = STACKS[index]
    var enemy = world.spawn_assault_enemy(index, van.to_global(van.inside_socket))
    # All teams first clear the south-facing doorway and rear quarter. Turning
    # directly toward the front entrance used to send them back through the van.
    var points := PackedVector2Array([van.to_global(van.exit_socket), van.to_global(van.outside_socket), Vector2(345,947)])
    if target.x < 0 or target.y < 0:
        points.append(Vector2(-65,947))
        if target.y < 0:
            points.append(Vector2(-65,-65))
            points.append(Vector2(target.x,-65))
        else: points.append(Vector2(-65,target.y))
    elif index < 2:
        points.append(Vector2(240,947))
        points.append(Vector2(240,790))
    else:
        points.append(Vector2(1100,947))
        points.append(Vector2(1100,800))
    points.append(target)
    enemy.stage(points, STACK_AIMS[index])
    if skipped: enemy.global_position = target
    deployment_count += 1

func _breach(delta: float) -> void:
    _camera_shot(Director.breach_shot())
    if clock > .8 and not glass_broken:
        _break_glass()
        _grenade = Node2D.new()
        _grenade.set_script(load("res://scripts/level3_flashbang_visual.gd"))
        _grenade.position = Vector2(-26,432)
        _grenade.z_index = 28
        add_child(_grenade)
    if is_instance_valid(_grenade) and clock < 1.6:
        var t := clampf((clock - .8) / .8, 0, 1)
        _grenade.position = Vector2(-26,432).lerp(Vector2(96,427), t) + Vector2(0,-sin(t * PI)*26)
        _grenade.rotation = t * TAU * 2
    if clock >= 1.8 and not flashbang_detonated:
        flashbang_detonated = true
        if is_instance_valid(_grenade): _grenade.queue_free()
        world.audio.play_at(&"shotgun", Vector2(96,427))
        world.effects.glass(Vector2(96,427))
        _flash_clock = 0
        _flash.color.a = .94
        var distance: float = world.player.global_position.distance_to(Vector2(96,427))
        if distance < 290 and world.has_line_of_sight(Vector2(96,427), world.player.global_position):
            world.player.apply_flashbang(1.7 * (1.0 - distance / 350.0))
    if clock > 2.25: _phase(&"return")

func _camera_shot(description: Dictionary) -> void:
    var cut: bool = shot != description.id
    shot = description.id
    shot_extent = description.extent
    if cut: shot_history.append(shot)
    world.camera.global_position = description.focus
    world.camera.zoom = Vector2.ONE * Director.zoom_for(world.get_viewport_rect().size, shot_extent)
    if cut: world.camera.reset_smoothing()

func _break_glass() -> void:
    if glass_broken: return
    glass_broken = true
    window_body.get_node("CollisionShape2D").set_deferred("disabled",true)
    world.environment.break_window_at(BREACH)
    world.audio.play_at(&"glass", BREACH)
    world.effects.glass(BREACH)
    world.navigation.ready = false
    world.refresh_navigation_after_physics.call_deferred()

func _begin_assault() -> void:
    world.pickups_root.show()
    world.camera.global_position = world.player.global_position
    world.camera.zoom = Vector2.ONE * 1.7
    world.camera.position_smoothing_enabled = _gameplay_camera_smoothing
    world.camera.reset_smoothing()
    _phase(&"assault")
    for enemy in world._enemies:
        enemy.begin_assault(world.player.global_position)
    world._set_hint("Светошумовая в зале! Белки идут на штурм.")

func on_cleared() -> void:
    if phase != &"assault": return
    _phase(&"cleared")
    world._set_hint("Кажется, повар ещё не понял, что произошло. Вернись к нему.")

func on_order_collected() -> void:
    _phase(&"exit")
    world.environment.exit_marker.show()
    world.environment.exit_marker.global_position = CAR_POSITION + Vector2(39,0)

func _auto_board(delta: float) -> void:
    var door: Vector2 = car.to_global(car.boarding_socket)
    var distance: float = world.player.global_position.distance_to(door)
    car.door_open_amount = move_toward(car.door_open_amount, 1.0 if distance < 73 else 0.0, delta * 4.2)
    if distance < 35:
        boarding_started = true
        _board_from = world.player.global_position
        world.player.collision_layer = 0
        world.player.collision_mask = 0
        _phase(&"boarding")
        world.camera.zoom = Vector2.ONE * 1.7
        world.camera.global_position = CAR_POSITION
        world.audio.play_at(&"door", CAR_POSITION)

func _boarding(_delta: float) -> void:
    car.door_open_amount = minf(1, clock / .2 + .6)
    if clock < .55:
        world.player.global_position = _board_from.lerp(car.to_global(car.inside_socket), smoothstep(0,1,clock/.55))
        world.player.modulate.a = 1.0 - smoothstep(.32,.55,clock)
    else:
        world.player.hide()
        car.door_open_amount = maxf(0,1.0-(clock-.55)/.4)
    if clock >= 1.0 and not boarding_finished:
        boarding_finished = true
        world._finish_level()

func _make_vehicle_props() -> void:
    car = Vehicle.new()
    car.kind = "240"
    car.position = CAR_POSITION
    car.rotation = PI * .5
    car.scale = Vector2.ONE * 1.23
    car.z_index = -5
    add_child(car)
    _car_body = _body("Parked240Body", CAR_POSITION, Vector2(52,103))
    van = Vehicle.new()
    van.kind = "van"
    van.position = Director.VAN_START
    van.scale = Vector2.ONE * 1.005
    van.z_index = -4
    add_child(van)
    van.hide()

func _solid_van() -> void:
    if is_instance_valid(_van_body): return
    _van_body = StaticBody2D.new()
    _van_body.name = "ArrivedVanBody"
    _van_body.position = VAN_STOP
    _van_body.rotation = Director.VAN_STOP_ROTATION
    _van_body.collision_layer = 1
    _van_body.collision_mask = 0
    for rect: Rect2 in [Rect2(-58,-8,116,30), Rect2(-58,-23,42,15), Rect2(18,-23,40,15)]:
        var shape := RectangleShape2D.new()
        shape.size = rect.size
        var collision := CollisionShape2D.new()
        collision.shape = shape
        collision.position = rect.get_center()
        _van_body.add_child(collision)
    add_child(_van_body)

func _make_chef() -> void:
    chef = Visual.animated_strip("res://assets/level3/source/NPCs/sprNicklasServe_strip30.png", 6, Vector2.ONE * 1.1)
    chef.position = CHEF_POSITION
    chef.rotation = PI * .5
    chef.z_index = 17
    chef.pause()
    add_child(chef)
    _body("KitchenEmployeeBody",CHEF_POSITION,Vector2(15,15))

func _make_breach_glass() -> void:
    window_body = _body("WestGlass", BREACH, Vector2(24,48))

func _make_bounds() -> void:
    var night := Polygon2D.new()
    night.name = "ContinuousNightBackground"
    night.polygon = PackedVector2Array([Vector2(-1600,-1400),Vector2(2800,-1400),Vector2(2800,2200),Vector2(-1600,2200)])
    night.color = Color("101d29")
    night.z_index = -100
    add_child(night)
    _body("StreetSouth",Vector2(576,1000),Vector2(1490,24))
    _body("StreetWest",Vector2(-158,400),Vector2(24,1200))
    _body("StreetEast",Vector2(1310,400),Vector2(24,1200))
    _body("StreetNorth",Vector2(576,-158),Vector2(1490,24))

func _body(id: String, at: Vector2, dimensions: Vector2) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.name = id
    body.position = at
    body.collision_layer = 1
    body.collision_mask = 0
    var collision := CollisionShape2D.new()
    collision.name = "CollisionShape2D"
    var shape := RectangleShape2D.new()
    shape.size = dimensions
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    return body

func _loop_sound(path: String, db: float) -> AudioStreamPlayer2D:
    var sound := AudioStreamPlayer2D.new()
    var stream := load(path).duplicate() as AudioStream
    if stream is AudioStreamWAV:
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_end = int(stream.get_length()*stream.mix_rate)
    elif stream is AudioStreamOggVorbis: stream.loop = true
    sound.stream = stream
    sound.max_distance = 1400
    sound.set_meta("base_db",db)
    van.add_child(sound)
    sound.volume_db = -80 if get_node("/root/GameState").sfx_muted else get_node("/root/GameState").sfx_volume_db + db
    sound.play()
    return sound

func _update_arrival_sound() -> void:
    var t := clampf(clock / Director.ARRIVAL_DURATION,0,1)
    for index in range(_arrival_sounds.size()):
        var sound := _arrival_sounds[index]
        var envelope := -7.0*smoothstep(.65,1,t) if index == 0 else -12.0*(1.0-smoothstep(0,.2,t))-8.0*smoothstep(.82,1,t)
        sound.pitch_scale = lerpf(1.14,.72,smoothstep(.15,1,t)) if index == 0 else lerpf(1.03,.9,t)
        sound.volume_db = -80 if get_node("/root/GameState").sfx_muted else get_node("/root/GameState").sfx_volume_db + float(sound.get_meta("base_db")) + envelope

func _stop_arrival_sounds() -> void:
    for sound in _arrival_sounds:
        sound.stop()
        sound.stream = null
        sound.queue_free()
    _arrival_sounds.clear()

func _exit_tree() -> void:
    _stop_arrival_sounds()
