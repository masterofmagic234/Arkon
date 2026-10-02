extends RefCounted

# Pickup-side controller. Owns acorn collection, fake cone interaction and
# objective completion/failure caused by pickups. It does not own input,
# player movement, enemy AI, HUD, or scene lifecycle.
const LevelData = preload("res://scripts/level_data.gd")
const PickupQuery = preload("res://scripts/pickup_query.gd")
const ConeQuery = preload("res://scripts/cone_query.gd")
const HealthMath = preload("res://scripts/health_math.gd")
const DeathQuery = preload("res://scripts/death_query.gd")
const MissionStateQuery = preload("res://scripts/mission_state_query.gd")
const SceneLookup = preload("res://scripts/scene_lookup.gd")

var root
var player
var game_state
var world_sprite_view
var on_mission_fail: Callable

func setup(root_node, player_node, state, world_sprites, mission_fail_callback: Callable) -> void:
    root = root_node
    player = player_node
    game_state = state
    world_sprite_view = world_sprites
    on_mission_fail = mission_fail_callback

func update() -> void:
    if MissionStateQuery.is_finished(game_state.mission_complete, game_state.mission_failed):
        return
    collect_acorns()
    check_fake_cone()

func collect_acorns() -> void:
    for name in game_state.acorns.duplicate():
        var node = SceneLookup.mesh_node(root, name)
        if node != null and PickupQuery.is_in_range(player.global_position, node.global_position, LevelData.ACORN_PICKUP_RADIUS):
            world_sprite_view.hide_pickup(node)
            SignalBus.item_collected.emit(&"acorn", StringName(name), 1, player)

func check_fake_cone() -> void:
    if game_state.fake_cone_found:
        return
    var cone := SceneLookup.mesh_node(root, "FakePineCone") as MeshInstance3D
    if cone != null and ConeQuery.is_in_range(player.global_position, cone.global_position):
        game_state.fake_cone_found = true
        game_state.hp = HealthMath.apply_damage(game_state.hp, 12)
        SignalBus.emit_audio_event(&"damage", Vector3(cone.global_position.x, cone.global_position.y, cone.global_position.z))
        SignalBus.show_message.emit(LevelData.CONE_LINES.pick_random(), 2.4)
        if DeathQuery.is_dead(game_state.hp):
            fail()

func fail() -> void:
    game_state.mission_failed = true
    if on_mission_fail.is_valid():
        on_mission_fail.call()
    mission_view.show_failed()

