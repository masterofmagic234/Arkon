extends SceneTree

const LevelData = preload("res://scripts/level_data.gd")
# Standalone smoke intentionally avoids preloading gameplay scripts that refer to
# project autoloads. Those dependencies are resolved after the SceneTree is live.
const LEVEL1_PLAYER_SCENE := "res://scenes/level1_player.tscn"
const LEVEL1_ENEMY_SCENE := "res://scenes/level1_enemy.tscn"

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var bus := root.get_node_or_null("SignalBus")
    if bus == null:
        _fail("SignalBus autoload missing")
        return

    if not ResourceLoader.exists("res://assets/grass_tuft_carolina.svg"):
        _fail("Level 1 Carolina grass sprite is missing")
        return

    var grass_script_text := FileAccess.get_file_as_string(
        "res://scripts/level1_grass_generator.gd"
    )
    var grass_environment_text := FileAccess.get_file_as_string(
        "res://scripts/level1_environment.gd"
    )
    if not grass_script_text.contains("const GRASS_HEIGHT := 0.52"):
        _fail("Level 1 grass height regression detected")
        return
    if not grass_script_text.contains("const GRASS_HALF_WIDTH := 0.23"):
        _fail("Level 1 grass width regression detected")
        return
    if not grass_script_text.contains("@export_range(2, 12, 1) var density_per_cell: int = 8"):
        _fail("Level 1 grass density API drifted")
        return
    if not grass_environment_text.contains("grass.density_per_cell = 8"):
        _fail("Level 1 environment is not using the mobile grass preset")
        return

    for action in [
        "l1_move_left",
        "l1_move_right",
        "l1_move_forward",
        "l1_move_backward",
        "l1_fire"
    ]:
        if not InputMap.has_action(action):
            _fail("Missing Level 1 InputMap action: %s" % action)
            return

    var layout_scene := load("res://scenes/level1_layout.tscn") as PackedScene
    var player_scene := load(LEVEL1_PLAYER_SCENE) as PackedScene
    var enemy_scene := load(LEVEL1_ENEMY_SCENE) as PackedScene
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

    var player: Node = player_scene.instantiate()
    game.add_child(player)
    if player.get_node_or_null("Health") == null:
        _fail("Player HealthComponent missing")
        return

    var enemy: Node = enemy_scene.instantiate()
    enemy.name = "SquirrelSmoke"
    enemy.squirrel_kind = 0
    enemy.position = Vector3(4.0, 0.95, 4.0)
    game.add_child(enemy)

    var hitbox := enemy.get_node_or_null("Hitbox")
    if hitbox == null or hitbox.get_node_or_null("CollisionShape3D") == null:
        _fail("Enemy 3D hitbox component missing")
        return

    # Use a shared reference container for signal observation. This avoids
    # relying on local scalar capture semantics inside standalone smoke lambdas.
    var observed := {"stunned": false}
    var on_stunned := func(entity: Node, _duration: float) -> void:
        if entity == enemy:
            observed["stunned"] = true
    bus.entity_stunned.connect(on_stunned)

    enemy.take_damage(1, player)
    if enemy.health.current_health != 1 or enemy.defeated:
        _fail("Enemy first damage failed")
        return

    # The production enemy has a 0.24s invulnerability window. Clear only the
    # test fixture's timer so this assertion isolates the defeat/stun contract.
    enemy.health.invulnerability_timer = 0.0
    enemy.take_damage(1, player)
    if not enemy.defeated or enemy.health.current_health != 0 or not bool(observed["stunned"]):
        _fail(
            "Enemy defeat/stun contract failed: defeated=%s hp=%d stunned=%s connected=%s"
            % [
                str(enemy.defeated),
                int(enemy.health.current_health),
                str(bool(observed["stunned"])),
                str(bus.entity_stunned.is_connected(on_stunned))
            ]
        )
        return

    bus.entity_stunned.disconnect(on_stunned)

    var acorn: Node = acorn_scene.instantiate()
    acorn.name = "AcornSmoke"
    acorn.item_id = &"AcornSmoke"
    game.add_child(acorn)

    var item_event := {"received": false}
    var on_item := func(kind: StringName, item_id: StringName, amount: int, collector: Node) -> void:
        if kind == &"acorn" and item_id == &"AcornSmoke" and amount == 1 and collector == player:
            item_event["received"] = true

    bus.item_collected.connect(on_item)
    acorn.call("_on_body_entered", player)
    if not bool(item_event["received"]):
        _fail("Acorn item_collected fact was not published")
        return
    bus.item_collected.disconnect(on_item)

    var key: Node = key_scene.instantiate()
    key.name = "KeySmoke"
    key.item_id = &"KeySmoke"
    game.add_child(key)

    var key_event := {"received": false}
    var on_key := func(kind: StringName, item_id: StringName, amount: int, collector: Node) -> void:
        if kind == &"key" and item_id == &"KeySmoke" and amount == 1 and collector == player:
            key_event["received"] = true

    bus.item_collected.connect(on_key)
    key.call("_on_body_entered", player)
    if not bool(key_event["received"]):
        _fail("Key item_collected fact was not published")
        return
    bus.item_collected.disconnect(on_key)

    var pine: Node = pine_scene.instantiate()
    pine.name = "FakePineConeSmoke"
    pine.position = Vector3(12.0, 0.45, 12.0)
    game.add_child(pine)
    player.health.reset(LevelData.MAX_HP)

    var hp_before: int = int(player.get_hp())
    pine.call("_on_body_entered", player)
    if player.get_hp() != hp_before - 12:
        _fail("Fake pine cone damage failed")
        return

    # Release the standalone gameplay tree before exiting so Godot can flush
    # scene-owned ObjectDB/resources instead of reporting test-only leaks.
    game.queue_free()
    await process_frame
    print("LEVEL1 SMOKE TEST: PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL1 SMOKE TEST: " + message)
    quit(1)
