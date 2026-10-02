extends SceneTree

const LevelData = preload("res://scripts/level_data.gd")
const Level1Player = preload("res://scripts/level1_player.gd")
const Level1Enemy = preload("res://scripts/level1_enemy.gd")
const Level1Acorn = preload("res://scripts/level1_acorn.gd")
const Level1Key = preload("res://scripts/level1_key.gd")
const Level1PineCone = preload("res://scripts/level1_pinecone.gd")
const Hitbox3DComponent = preload("res://scripts/components/hitbox_3d_component.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    for action in ["l1_move_left", "l1_move_right", "l1_move_forward", "l1_move_backward", "l1_turn_left", "l1_turn_right", "l1_fire"]:
        if not InputMap.has_action(action):
            _fail("Missing Level 1 InputMap action: %s" % action)
            return

    var bus := root.get_node_or_null("SignalBus")
    if bus == null:
        _fail("SignalBus autoload missing")
        return

    for action in ["l1_move_left", "l1_move_right", "l1_move_forward", "l1_move_backward", "l1_turn_left", "l1_turn_right", "l1_fire"]:
        if not InputMap.has_action(action):
            _fail("Missing Level 1 InputMap action: %s" % action)
            return

    var layout_scene := load("res://scenes/level1_layout.tscn") as PackedScene
    var player_scene := load("res://scenes/level1_player.tscn") as PackedScene
    var enemy_scene := load("res://scenes/level1_enemy.tscn") as PackedScene
    var acorn_scene := load("res://scenes/level1_acorn.tscn") as PackedScene
    var key_scene := load("res://scenes/level1_key.tscn") as PackedScene
    var pine_scene := load("res://scenes/level1_pinecone.tscn") as PackedScene

    if layout_scene == null or player_scene == null or enemy_scene == null:
        _fail("Level 1 core PackedScenes could not be loaded")
        return

    if acorn_scene == null or key_scene == null or pine_scene == null:
        _fail("Level 1 pickup PackedScenes could not be loaded")
        return

    var layout := layout_scene.instantiate() as Node3D
    if layout == null:
        _fail("Level 1 layout did not instantiate")
        return
    root.add_child(layout)

    var wall_root := layout.get_node_or_null("Walls")
    if wall_root == null or wall_root.get_child_count() < 400:
        _fail("Expanded Level 1 wall set is missing")
        return

    for door_name in ["Door01", "Door02", "Door03"]:
        var door := layout.find_child(door_name, true, false)
        if door == null or not door.has_method("open"):
            _fail("Missing Level 1 door: %s" % door_name)
            return
        if int(door.get("required_key")) != int(door_name.right(2)):
            _fail("Wrong key requirement on %s" % door_name)
            return
        if door.get_node_or_null("Proximity/CollisionShape3D") == null:
            _fail("Missing door proximity trigger on %s" % door_name)
            return

    var game := Node3D.new()
    game.name = "Game"
    root.add_child(game)

    var player := player_scene.instantiate() as Level1Player
    game.add_child(player)
    if player.get_node_or_null("Health") == null:
        _fail("Player HealthComponent missing")
        return

    var enemy := enemy_scene.instantiate() as Level1Enemy
    enemy.name = "SquirrelSmoke"
    enemy.squirrel_kind = 0
    enemy.position = Vector3(4.0, 0.95, 4.0)
    game.add_child(enemy)

    var hitbox := enemy.get_node_or_null("Hitbox") as Hitbox3DComponent
    if hitbox == null or hitbox.get_node_or_null("CollisionShape3D") == null:
        _fail("Enemy 3D hitbox component missing")
        return

    var stunned_event := false
    var on_stunned := func(entity: Node, _duration: float) -> void:
        if entity == enemy:
            stunned_event = true
    bus.entity_stunned.connect(on_stunned)

    enemy.take_damage(1, player)
    if enemy.health.current_health != 1 or enemy.defeated:
        _fail("Enemy first damage failed")
        return

    enemy.take_damage(1, player)
    if not enemy.defeated or enemy.health.current_health != 0 or not stunned_event:
        _fail("Enemy defeat/stun contract failed")
        return

    bus.entity_stunned.disconnect(on_stunned)

    var acorn := acorn_scene.instantiate() as Level1Acorn
    acorn.name = "AcornSmoke"
    acorn.item_id = &"AcornSmoke"
    game.add_child(acorn)

    var item_event := false
    var on_item := func(kind: StringName, item_id: StringName, amount: int, collector: Node) -> void:
        if kind == &"acorn" and item_id == &"AcornSmoke" and amount == 1 and collector == player:
            item_event = true

    bus.item_collected.connect(on_item)
    acorn._on_body_entered(player)
    if not item_event:
        _fail("Acorn item_collected fact was not published")
        return
    bus.item_collected.disconnect(on_item)

    var key := key_scene.instantiate() as Level1Key
    key.name = "KeySmoke"
    key.item_id = &"KeySmoke"
    game.add_child(key)

    var key_event := false
    var on_key := func(kind: StringName, item_id: StringName, amount: int, collector: Node) -> void:
        if kind == &"key" and item_id == &"KeySmoke" and amount == 1 and collector == player:
            key_event = true

    bus.item_collected.connect(on_key)
    key._on_body_entered(player)
    if not key_event:
        _fail("Key item_collected fact was not published")
        return
    bus.item_collected.disconnect(on_key)

    var pine := pine_scene.instantiate() as Level1PineCone
    pine.name = "FakePineConeSmoke"
    pine.position = Vector3(12.0, 0.45, 12.0)
    game.add_child(pine)
    player.health.reset(LevelData.MAX_HP)

    var hp_before := player.get_hp()
    pine._on_body_entered(player)
    if player.get_hp() != hp_before - 12:
        _fail("Fake pine cone damage failed")
        return

    print("LEVEL1 SMOKE TEST: PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL1 SMOKE TEST: " + message)
    quit(1)
