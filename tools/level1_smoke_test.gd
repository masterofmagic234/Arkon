extends SceneTree

const LevelData = preload("res://scripts/level_data.gd")
const GameState = preload("res://scripts/game_state.gd")
const EnemyController = preload("res://scripts/enemy_controller.gd")
const PickupController = preload("res://scripts/pickup_controller.gd")
const WorldQueries = preload("res://scripts/world_queries.gd")

class WorldSpriteStub:
    func hide_pickup(node: MeshInstance3D) -> void:
        node.visible = false
    func apply_squirrel_type(_node: MeshInstance3D, _kind: int) -> void:
        pass
    func apply_squirrel_stunned(_node: MeshInstance3D, _kind: int = 0) -> void:
        pass
    func animate_squirrel(_node: MeshInstance3D, _phase: float, _state: int = 0,
            _speed: float = 0.0, _direction: Vector3 = Vector3.ZERO,
            _dt: float = 0.016) -> void:
        pass

class AudioStub:
    func play_pickup() -> void:
        pass
    func play_damage() -> void:
        pass
    func play_squirrel_hit() -> void:
        pass

class MessageStub:
    func set_text(_text: String) -> void:
        pass
    func clear() -> void:
        pass

class MissionStub:
    func show_complete(_count: int) -> void:
        pass
    func show_failed() -> void:
        pass

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var state = GameState.new()
    state.setup(LevelData)
    if state.acorns.size() != 4:
        _fail("Expected 4 acorns, got %d" % state.acorns.size())
        return
    if state.squirrels.size() != 5:
        _fail("Expected 5 squirrels, got %d" % state.squirrels.size())
        return

    var game := Node3D.new()
    game.name = "Game"
    root.add_child(game)

    var player := CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3.ZERO
    game.add_child(player)

    var acorn := MeshInstance3D.new()
    acorn.name = "Acorn01"
    acorn.mesh = QuadMesh.new()
    acorn.position = Vector3.ZERO
    acorn.visible = true
    game.add_child(acorn)

    var squirrel := MeshInstance3D.new()
    squirrel.name = "Squirrel01"
    squirrel.mesh = QuadMesh.new()
    squirrel.position = Vector3(8.0, 0.95, 8.0)
    game.add_child(squirrel)

    var hitbox := Area3D.new()
    hitbox.name = "Hitbox"
    hitbox.collision_layer = LevelData.SQUIRREL_LAYER
    hitbox.collision_mask = 0
    squirrel.add_child(hitbox)

    var collision := CollisionShape3D.new()
    collision.name = "Collision"
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.0, 1.8, 0.4)
    collision.shape = shape
    hitbox.add_child(collision)

    var world_sprites := WorldSpriteStub.new()
    var audio := AudioStub.new()
    var messages := MessageStub.new()
    var mission := MissionStub.new()

    var pickup := PickupController.new()
    pickup.setup(game, player, state, world_sprites, audio, messages, mission, Callable(), Callable())
    pickup.update()
    if state.collected != 1 or state.acorns.has("Acorn01") or acorn.visible:
        _fail("Acorn pickup failed")
        return

    var enemy := EnemyController.new()
    enemy.setup(game, player, state, world_sprites, audio, messages, Callable())
    if enemy.squirrel_ais.size() != 5:
        _fail("Expected 5 AI entries after registry sync, got %d" % enemy.squirrel_ais.size())
        return

    for squirrel_id in state.squirrels:
        var node := game.get_node_or_null(squirrel_id) as MeshInstance3D
        if node == null:
            _fail("Missing squirrel node after spawn: %s" % squirrel_id)
            return
        var spawned_hitbox := node.get_node_or_null("Hitbox") as Area3D
        var spawned_collision := node.get_node_or_null("Hitbox/Collision") as CollisionShape3D
        if spawned_hitbox == null or spawned_collision == null or spawned_collision.shape == null:
            _fail("Missing hitbox after spawn: %s" % squirrel_id)
            return
        if spawned_hitbox.collision_layer != LevelData.SQUIRREL_LAYER:
            _fail("Wrong squirrel collision layer: %s" % squirrel_id)
            return

    enemy.hit_squirrel("Squirrel01")
    if int(state.squirrel_hp.get("Squirrel01", -1)) != 1:
        _fail("Squirrel damage failed")
        return

    enemy.hit_squirrel("Squirrel01")
    if not state.stunned.has("Squirrel01"):
        _fail("Squirrel stun failed")
        return

    var collider := game.get_node("Squirrel01/Hitbox/Collision")
    var resolved_id := WorldQueries.find_squirrel_from_collider(collider, state.squirrels)
    if resolved_id != "Squirrel01":
        _fail("Collider-to-squirrel mapping failed: %s" % resolved_id)
        return

    enemy.update(0.016)

    print("LEVEL1 SMOKE TEST: PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL1 SMOKE TEST: " + message)
    quit(1)
