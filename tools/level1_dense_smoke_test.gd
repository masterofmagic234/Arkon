extends SceneTree

const LevelData = preload("res://scripts/level_data.gd")
const WorldCollision = preload("res://scripts/world_collision.gd")

const EXPECTED_WALLS := 508

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if LevelData.MAP_WIDTH != 56 or LevelData.MAP_HEIGHT != 16:
        _fail("Unexpected map dimensions")
        return

    if LevelData.CANONICAL_MAP.size() != LevelData.MAP_HEIGHT:
        _fail("Map row count mismatch")
        return

    for row in LevelData.CANONICAL_MAP:
        if str(row).length() != LevelData.MAP_WIDTH:
            _fail("Map row width mismatch")
            return

    var scene := load("res://scenes/level1_layout_experimental.tscn") as PackedScene
    if scene == null:
        _fail("Experimental layout scene failed to load")
        return

    var layout := scene.instantiate() as Node3D
    if layout == null:
        _fail("Experimental layout failed to instantiate")
        return
    root.add_child(layout)

    await process_frame

    var walls := layout.get_node_or_null("Walls")
    if walls == null or walls.get_child_count() != EXPECTED_WALLS:
        _fail("Expected %d wall cells, got %s" % [EXPECTED_WALLS, walls.get_child_count() if walls != null else -1])
        return

    if LevelData.ACORN_NAMES.size() != 8 or LevelData.ACORN_POSITIONS.size() != 8:
        _fail("Acorn definition count mismatch")
        return
    if LevelData.KEY_NAMES.size() != 3 or LevelData.DOOR_NAMES.size() != 3:
        _fail("Key/door definition count mismatch")
        return
    if LevelData.SQUIRREL_NAMES.size() != 12:
        _fail("Expected 12 squirrels")
        return

    var pickups := layout.get_node("Pickups")
    for id in LevelData.ACORN_NAMES:
        if pickups.get_node_or_null(id) == null:
            _fail("Missing acorn: %s" % id)
            return
    for id in LevelData.KEY_NAMES:
        if pickups.get_node_or_null(id) == null:
            _fail("Missing key: %s" % id)
            return
    if layout.find_child("FakePineCone", true, false) == null:
        _fail("Fake pine cone pickup missing")
        return

    var enemies := layout.get_node("Enemies")
    for id in LevelData.SQUIRREL_NAMES:
        var enemy := enemies.get_node_or_null(id) as MeshInstance3D
        if enemy == null:
            _fail("Missing squirrel: %s" % id)
            return
        if WorldCollision.is_wall(enemy.position.x, enemy.position.z):
            _fail("Squirrel spawned inside a wall: %s" % id)
            return
        if enemy.position.y < 1.2:
            _fail("Squirrel visual center too low: %s (y=%0.2f)" % [id, enemy.position.y])
            return
        if enemy.get_node_or_null("Hitbox/Collision") == null:
            _fail("Squirrel hitbox missing: %s" % id)
            return

    var doors := layout.get_node("Doors")
    for i in range(LevelData.DOOR_NAMES.size()):
        var door := doors.get_node_or_null(LevelData.DOOR_NAMES[i])
        if door == null:
            _fail("Missing door: %s" % LevelData.DOOR_NAMES[i])
            return
        if int(door.get("required_key")) != i + 1:
            _fail("Wrong key requirement on door %d" % (i + 1))
            return

    var decorations := layout.get_node("Decor")
    if decorations.get_node_or_null("Lantern01") == null:
        _fail("Lanterns missing")
        return

    print("LEVEL1 DENSE 4-ZONE SMOKE TEST: PASS")
    quit(0)

func _fail(message: String) -> void:
    push_error("LEVEL1 DENSE 4-ZONE SMOKE TEST: " + message)
    quit(1)
