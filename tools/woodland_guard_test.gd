extends SceneTree
# A real physics/hitscan encounter fixture. No simulated damage or forced
# health writes: the production player shoots the production guard hitboxes.
# Gameplay scripts reference project autoloads. Load them only after startup,
# as the existing standalone smoke fixtures do.
var Guard: Script
var PlayerScene: PackedScene
var Combat: Script

class FixtureDirector extends Node3D:
    var player: Node
    var stage := "lanterns"

var fixture: FixtureDirector
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    Guard = load("res://scripts/woodland_guard.gd")
    PlayerScene = load("res://scenes/level1_player.tscn")
    Combat = load("res://scripts/combat_query.gd")
    # Dummy audio does not retire real-time SFX voices while this fixture runs
    # faster than real time. Match the existing standalone smoke convention;
    # this singleton-only test setting is never persisted.
    root.get_node("GameState").set("sfx_muted", true)
    fixture = FixtureDirector.new()
    root.add_child(fixture)
    current_scene = fixture
    var floor_ := _solid(Vector3(0,-0.1,0), Vector3(80,0.2,80))
    floor_.name = "PhysicalFloor"
    fixture.player = PlayerScene.instantiate()
    fixture.player.position = Vector3(0,0.875,8)
    fixture.player.collision_mask = 1 | 8
    fixture.add_child(fixture.player)
    var scout = Guard.new()
    scout.name = "ScoutFixture"
    scout.director = fixture
    fixture.add_child(scout)
    var wall := _solid(Vector3(0,1.5,4), Vector3(5,3,0.5))
    wall.name = "RealSightAndShotBlocker"
    await _frames(5)
    _check(scout.visual.presentation_ready, "Scout presentation must load.")
    _aim(scout)
    var blocked: Dictionary = Combat.raycast(fixture.get_world_3d(), fixture.player.camera)
    _check(blocked.get("collider") == wall, "Physical wall must block the actual weapon ray.")
    var ammo: int = fixture.player.get_ammo()
    await _shoot(scout)
    _check(scout.hp == 3, "Shots cannot damage a scout through the wall.")
    _check(fixture.player.get_ammo() == ammo-1, "Blocked shot still consumes exactly one charge.")
    _check(scout.state == "patrol", "Scout must not see the player through the real wall.")
    wall.queue_free()
    await _frames(3)
    _aim(scout)
    var visible_hit: Dictionary = Combat.raycast(fixture.get_world_3d(), fixture.player.camera)
    _check(visible_hit.get("collider") == scout.hitbox, "Guard capsule must never occlude its hittable area.")
    for i in range(3):
        await _shoot(scout)
    _check(scout.defeated and scout.hp == 0, "Three real player hits must defeat the scout.")
    _check(scout.hitbox.collision_layer == 0, "Defeated scout must leave the hitscan layer.")
    scout.queue_free()
    await _frames(3)

    fixture.player.position = Vector3(0,0.875,7)
    var tank = Guard.new()
    tank.name = "TankFixture"
    tank.is_tank = true
    tank.director = fixture
    fixture.add_child(tank)
    await _frames(4)
    _check(tank.visual.presentation_ready and tank.visual.skeleton_ready, "Supplied tank model and skeleton must load.")
    _check(tank.visual.model_path.ends_with("tank_squirrel.glb"), "Tank must use the user's new GLB.")
    await _shoot(tank)
    _check(tank.hp == 8 and tank.state == "dormant", "Tank stays protected and dormant before lanterns are lit.")
    fixture.stage = "cache"
    await _wait_state(tank, "windup", 120)
    _check(tank.warning_ring.visible and tank.charge_line.visible, "Windup must show both radius and locked charge lane.")
    var locked_direction: Vector3 = tank._charge_direction
    Input.action_press("l1_move_right")
    await _frames(57)
    Input.action_release("l1_move_right")
    _check(fixture.player.position.x > 3.5, "Dodge must use actual movement input.")
    _check(tank._charge_direction.is_equal_approx(locked_direction), "Charge must not retarget after its warning.")
    await _wait_state(tank, "recover", 120)
    _check(fixture.player.get_hp() == 100, "A successful sideways dodge must avoid tank damage.")
    _check(tank.global_position.distance_to(tank.spawn_position) > 7, "Tank must physically travel down its announced lane.")
    _check(not tank.charge_line.visible, "Charge lane must disappear after charge.")
    for i in range(8):
        await _shoot(tank)
    _check(tank.defeated and tank.hp == 0, "Recovery window must accept eight real weapon hits and defeat the tank.")
    _check(tank.visual.stunned, "Defeated tank must retain its resting visual state.")
    await _frames(3)
    _check(tank.body_shape.disabled, "Defeated tank must not block the cache route.")
    Input.action_release("l1_move_right")
    fixture.player.stop()
    await _frames(30)
    current_scene = null
    fixture.queue_free()
    await process_frame
    await process_frame
    if failures.is_empty():
        print("WOODLAND GUARD: PASS — occluded scout, real hitscan, protected tank, locked tell, input dodge, recovery and defeat")
        quit(0)
    else:
        print("WOODLAND GUARD: FAIL ", failures)
        quit(1)

func _solid(position_: Vector3, size_: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    body.position = position_
    var collision := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size_
    collision.shape = box
    body.add_child(collision)
    fixture.add_child(body)
    return body

func _aim(target: Node3D) -> void:
    fixture.player.camera.look_at(target.global_position + Vector3.UP * 1.1, Vector3.UP)

func _shoot(target: Node3D) -> void:
    _aim(target)
    fixture.player.request_fire()
    await _frames(13)

func _frames(count: int) -> void:
    for i in range(count):
        await physics_frame

func _wait_state(guard: Node, expected: String, maximum_frames: int) -> void:
    for i in range(maximum_frames):
        if guard.state == expected: return
        await physics_frame
    _check(false, "Guard did not enter %s within %d frames (actual %s)." % [expected,maximum_frames,guard.state])

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)
