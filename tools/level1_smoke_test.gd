extends SceneTree

const LevelData = preload("res://scripts/level_data.gd")
const WorldQueries = preload("res://scripts/world_queries.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://game.tscn") as PackedScene
    if packed == null:
        _fail("Could not load game.tscn")
        return

    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    var state = game.game_state
    if state == null:
        _fail("GameState was not initialized")
        return
    if state.acorns.size() != 4:
        _fail("Expected 4 acorns, got %d" % state.acorns.size())
        return
    if state.squirrels.size() != 5:
        _fail("Expected 5 squirrels, got %d" % state.squirrels.size())
        return

    for squirrel_id in state.squirrels:
        var squirrel = game.get_node_or_null(squirrel_id) as MeshInstance3D
        if squirrel == null:
            _fail("Missing squirrel node: %s" % squirrel_id)
            return
        var hitbox = squirrel.get_node_or_null("Hitbox") as Area3D
        var collision = squirrel.get_node_or_null("Hitbox/Collision") as CollisionShape3D
        if hitbox == null or collision == null or collision.shape == null:
            _fail("Missing squirrel hitbox: %s" % squirrel_id)
            return
        if hitbox.collision_layer != LevelData.SQUIRREL_LAYER:
            _fail("Wrong squirrel collision layer: %s" % squirrel_id)
            return

    var acorn = game.get_node_or_null("Acorn01") as MeshInstance3D
    if acorn == null:
        _fail("Acorn01 node missing")
        return

    game.player.global_position = acorn.global_position
    game.pickup_controller.update()
    if state.collected != 1 or state.acorns.has("Acorn01"):
        _fail("Acorn pickup failed")
        return

    game.enemy_controller.hit_squirrel("Squirrel01")
    if int(state.squirrel_hp.get("Squirrel01", -1)) != 1:
        _fail("Squirrel damage failed")
        return

    game.enemy_controller.hit_squirrel("Squirrel01")
    if not state.stunned.has("Squirrel01"):
        _fail("Squirrel stun failed")
        return

    var collider = game.get_node("Squirrel01/Hitbox/Collision")
    var resolved_id := WorldQueries.find_squirrel_from_collider(collider, state.squirrels)
    if resolved_id != "Squirrel01":
        _fail("Collider-to-squirrel mapping failed: %s" % resolved_id)
        return

    print("LEVEL1 SMOKE TEST: PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL1 SMOKE TEST: " + message)
    quit(1)
