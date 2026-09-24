extends RefCounted

# Gameplay orchestration only. Input and scene lifecycle remain in game.gd.
const LevelData = preload("res://scripts/level_data.gd")
const CombatQuery = preload("res://scripts/combat_query.gd")
const WorldQueries = preload("res://scripts/world_queries.gd")
const WorldSpriteView = preload("res://scripts/world_sprite_view.gd")
const AmmoMath = preload("res://scripts/ammo_math.gd")
const FireQuery = preload("res://scripts/fire_query.gd")
const MissionStateQuery = preload("res://scripts/mission_state_query.gd")

var root
var player
var camera
var game_state
var world_sprite_view
var combat_feedback
var audio_controller
var message_view
var mission_view
var enemy_controller
var pickup_controller
var on_mission_end: Callable

func setup(root_node, player_node, camera_node, state, world_sprites, feedback, audio, messages, mission, enemy, pickup, mission_end_callback: Callable) -> void:
    root = root_node
    player = player_node
    camera = camera_node
    game_state = state
    world_sprite_view = world_sprites
    combat_feedback = feedback
    audio_controller = audio
    message_view = messages
    mission_view = mission
    enemy_controller = enemy
    pickup_controller = pickup
    on_mission_end = mission_end_callback

func handle_fire() -> void:
    if not FireQuery.can_fire(game_state.mission_complete, game_state.mission_failed, game_state.fire_cooldown, game_state.ammo):
        if game_state.ammo <= 0 and not MissionStateQuery.is_finished(game_state.mission_complete, game_state.mission_failed) and game_state.fire_cooldown <= 0.0:
            set_message("Пусто. Даже белки в шоке.", 1.2)
        return
    game_state.ammo = AmmoMath.consume_one(game_state.ammo)
    game_state.fire_cooldown = 0.18
    game_state.recoil_time = 0.10
    combat_feedback.recoil()
    combat_feedback.show_muzzle()
    audio_controller.play_shoot()

    var hit := CombatQuery.raycast(root.get_world_3d(), camera)
    if hit.is_empty():
        miss()
        return

    var squirrel := WorldQueries.find_squirrel_from_collider(hit.get("collider"), game_state.squirrels)
    if squirrel == "" or enemy_controller.is_disabled(squirrel):
        miss()
        return

    enemy_controller.hit_squirrel(squirrel)
    combat_feedback.show_hit()
    await root.get_tree().create_timer(0.35).timeout
    if MissionStateQuery.is_active(game_state.mission_complete, game_state.mission_failed):
        combat_feedback.hide_hit()

func miss() -> void:
    combat_feedback.show_miss()
    set_message("Мимо. Белки делают вид, что ничего не заметили.", 1.1)
    await root.get_tree().create_timer(0.22).timeout
    if MissionStateQuery.is_active(game_state.mission_complete, game_state.mission_failed):
        combat_feedback.hide_hit()

func update(delta: float) -> void:
    # Pickups are the mission's primary interaction and must not be gated by
    # enemy AI. Run them first so an enemy-side runtime problem cannot prevent
    # acorns from being collected.
    if pickup_controller != null:
        pickup_controller.update()
    # Pickup completion/failure has priority over enemy damage from the same
    # physics tick. Never allow a last-acorn completion and a death state to
    # coexist in the same frame.
    if MissionStateQuery.is_finished(game_state.mission_complete, game_state.mission_failed):
        return
    if enemy_controller != null:
        enemy_controller.update(delta)

func fail() -> void:
    game_state.mission_failed = true
    if on_mission_end.is_valid():
        on_mission_end.call()
    mission_view.show_failed()

func set_message(text: String, duration: float) -> void:
    message_view.set_text(text)
    game_state.message_time = duration
