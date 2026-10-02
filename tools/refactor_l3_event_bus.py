from pathlib import Path

ROOT = Path("scripts")

def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly 1 match, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")

# 1) Expand the existing global bus with Level 3 gameplay events.
replace_once(
    ROOT / "signal_bus.gd",
    'signal combat_event(kind: StringName, position: Vector2)\n',
    '''signal combat_event(kind: StringName, position: Vector2)

# Level 3 event bus. Actor references are included so the global bus remains
# usable if more than one Level 3 scene or actor is ever active.
signal level3_player_fire_requested(player: Node, origin: Vector2, direction: Vector2, weapon: StringName)
signal level3_player_action_requested(player: Node)
signal level3_player_throw_requested(player: Node, origin: Vector2, direction: Vector2)
signal level3_player_died(player: Node)
signal level3_player_weapon_changed(player: Node, weapon: StringName, ammo: int)
signal level3_enemy_shot_requested(enemy: Node, origin: Vector2, direction: Vector2)
signal level3_enemy_defeated(enemy: Node)
signal level3_pickup_collected(pickup: Node, kind: StringName)
'''
)

# 2) Player publishes its local commands/events to the bus. Local signals stay
# intact for scene-level consumers and backwards compatibility.
player_path = ROOT / "level3_player.gd"
replace_once(
    player_path,
    '''    if _action_just_pressed:
        action_requested.emit()

    if _throw_just_pressed and throwable != &"":
        var origin := global_position + _aim_input * 12.0
        throwable = &""
        throw_requested.emit(origin, _aim_input)
''',
    '''    if _action_just_pressed:
        action_requested.emit()
        var bus := get_node_or_null("/root/SignalBus")
        if bus != null and bus.has_signal("level3_player_action_requested"):
            bus.level3_player_action_requested.emit(self)

    if _throw_just_pressed and throwable != &"":
        var origin := global_position + _aim_input * 12.0
        throwable = &""
        throw_requested.emit(origin, _aim_input)
        var bus := get_node_or_null("/root/SignalBus")
        if bus != null and bus.has_signal("level3_player_throw_requested"):
            bus.level3_player_throw_requested.emit(self, origin, _aim_input)
'''
)
replace_once(
    player_path,
    '''    _play_fire_animation()
    fire_requested.emit(global_position + _aim_input * 18.0, _aim_input, current_weapon)
''',
    '''    _play_fire_animation()
    var origin := global_position + _aim_input * 18.0
    fire_requested.emit(origin, _aim_input, current_weapon)
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("level3_player_fire_requested"):
        bus.level3_player_fire_requested.emit(self, origin, _aim_input, current_weapon)
'''
)
replace_once(
    player_path,
    '''    died.emit()
    if _visual != null:
        _visual.modulate = Color(0.65, 0.20, 0.20, 1.0)
''',
    '''    died.emit()
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("level3_player_died"):
        bus.level3_player_died.emit(self)
    if _visual != null:
        _visual.modulate = Color(0.65, 0.20, 0.20, 1.0)
'''
)
replace_once(
    player_path,
    '''    current_weapon = weapon
    ammo = current_ammo
    weapon_changed.emit(current_weapon, ammo)
''',
    '''    current_weapon = weapon
    ammo = current_ammo
    weapon_changed.emit(current_weapon, ammo)
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("level3_player_weapon_changed"):
        bus.level3_player_weapon_changed.emit(self, current_weapon, ammo)
'''
)

# 3) Enemy publishes combat events to the bus while preserving its local API.
enemy_path = ROOT / "level3_enemy.gd"
replace_once(
    enemy_path,
    '''            var shot_direction := global_position.direction_to(target.global_position)
            shot_requested.emit(self, global_position + shot_direction * 15.0, shot_direction)
''',
    '''            var shot_direction := global_position.direction_to(target.global_position)
            var shot_origin := global_position + shot_direction * 15.0
            shot_requested.emit(self, shot_origin, shot_direction)
            var bus := get_node_or_null("/root/SignalBus")
            if bus != null and bus.has_signal("level3_enemy_shot_requested"):
                bus.level3_enemy_shot_requested.emit(self, shot_origin, shot_direction)
'''
)
replace_once(
    enemy_path,
    '''    defeated.emit(self)
    var bus := get_node_or_null("/root/SignalBus")
''',
    '''    defeated.emit(self)
    var bus := get_node_or_null("/root/SignalBus")
    if bus != null and bus.has_signal("level3_enemy_defeated"):
        bus.level3_enemy_defeated.emit(self)
'''
)
# Keep the existing generic enemy_defeated event immediately after the new L3 event.
replace_once(
    enemy_path,
    '''    if bus != null and bus.has_signal("enemy_defeated"):
        bus.enemy_defeated.emit(StringName(name))
''',
    '''    if bus != null and bus.has_signal("enemy_defeated"):
        bus.enemy_defeated.emit(StringName(name))
'''
)

# 4) Pickup publishes collection to the bus.
pickup_path = ROOT / "level3_pickup.gd"
replace_once(
    pickup_path,
    '''        consumed = true
        collected.emit(kind)
        queue_free()
''',
    '''        consumed = true
        collected.emit(kind)
        var bus := get_node_or_null("/root/SignalBus")
        if bus != null and bus.has_signal("level3_pickup_collected"):
            bus.level3_pickup_collected.emit(self, kind)
        queue_free()
'''
)

# 5) Store consumes Level 3 events through SignalBus instead of wiring every
# gameplay actor directly. Touch UI signals remain local because those are UI.
store_path = ROOT / "level3_store.gd"
replace_once(
    store_path,
    '''    player.fire_requested.connect(_on_player_fire_requested)
    player.action_requested.connect(_on_player_action_requested)
    player.throw_requested.connect(_on_player_throw_requested)
    player.weapon_changed.connect(_on_player_weapon_changed)
    player.died.connect(_on_player_died)

    dialogue.finished.connect(_on_dialogue_finished)
''',
    '''    var bus := get_node_or_null("/root/SignalBus")
    if bus != null:
        bus.connect("level3_player_fire_requested", Callable(self, "_on_bus_player_fire_requested"))
        bus.connect("level3_player_action_requested", Callable(self, "_on_bus_player_action_requested"))
        bus.connect("level3_player_throw_requested", Callable(self, "_on_bus_player_throw_requested"))
        bus.connect("level3_player_weapon_changed", Callable(self, "_on_bus_player_weapon_changed"))
        bus.connect("level3_player_died", Callable(self, "_on_bus_player_died"))
        bus.connect("level3_enemy_shot_requested", Callable(self, "_on_bus_enemy_shot_requested"))
        bus.connect("level3_enemy_defeated", Callable(self, "_on_bus_enemy_defeated"))
        bus.connect("level3_pickup_collected", Callable(self, "_on_bus_pickup_collected"))

    dialogue.finished.connect(_on_dialogue_finished)
'''
)
replace_once(
    store_path,
    '''        enemies_root.add_child(enemy)
        enemy.shot_requested.connect(_on_enemy_shot_requested)
        enemy.defeated.connect(_on_enemy_defeated)
        _enemies.append(enemy)
''',
    '''        enemies_root.add_child(enemy)
        _enemies.append(enemy)
'''
)
replace_once(
    store_path,
    '''        pickups_root.add_child(pickup)
        pickup.collected.connect(_on_pickup_collected)
''',
    '''        pickups_root.add_child(pickup)
'''
)

# Add thin bus adapters immediately before the existing local gameplay handlers.
marker = 'func _on_player_fire_requested(\n'
text = store_path.read_text(encoding="utf-8")
if marker not in text:
    raise SystemExit("level3_store.gd: player fire handler marker not found")
adapters = '''func _on_bus_player_fire_requested(actor: Node, origin: Vector2, direction: Vector2, weapon: StringName) -> void:
    if actor == player:
        _on_player_fire_requested(origin, direction, weapon)

func _on_bus_player_action_requested(actor: Node) -> void:
    if actor == player:
        _on_player_action_requested()

func _on_bus_player_throw_requested(actor: Node, origin: Vector2, direction: Vector2) -> void:
    if actor == player:
        _on_player_throw_requested(origin, direction)

func _on_bus_player_weapon_changed(actor: Node, _weapon: StringName, _ammo: int) -> void:
    if actor == player:
        _on_player_weapon_changed(_weapon, _ammo)

func _on_bus_player_died(actor: Node) -> void:
    if actor == player:
        _on_player_died()

func _on_bus_enemy_shot_requested(actor: Node, origin: Vector2, direction: Vector2) -> void:
    if actor is Level3Enemy:
        _on_enemy_shot_requested(actor as Level3Enemy, origin, direction)

func _on_bus_enemy_defeated(actor: Node) -> void:
    if actor is Level3Enemy:
        _on_enemy_defeated(actor as Level3Enemy)

func _on_bus_pickup_collected(_pickup: Node, kind: StringName) -> void:
    _on_pickup_collected(kind)

'''
store_path.write_text(text.replace(marker, adapters + marker, 1), encoding="utf-8")

# Remove the direct generic SignalBus level-complete emission from the local
# defeated path only after the Event Bus migration remains responsible for it.
# (The level_completed signal is still global; it is an actual mission event.)
