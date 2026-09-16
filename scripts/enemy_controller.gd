extends RefCounted

# Enemy-side controller. Owns squirrel AI, damage, stun state and defeat checks.
# It does not own input, player movement, HUD, or scene lifecycle.
const LevelData = preload("res://scripts/level_data.gd")
const WorldCollision = preload("res://scripts/world_collision.gd")
const SquirrelMotionMath = preload("res://scripts/squirrel_motion_math.gd")
const SquirrelQuery = preload("res://scripts/squirrel_query.gd")
const SquirrelAttackQuery = preload("res://scripts/squirrel_attack_query.gd")
const HealthMath = preload("res://scripts/health_math.gd")
const DeathQuery = preload("res://scripts/death_query.gd")
const SceneLookup = preload("res://scripts/scene_lookup.gd")

var root
var player
var game_state
var world_sprite_view
var audio_controller
var message_view
var on_mission_fail: Callable

func setup(root_node, player_node, state, world_sprites, audio, messages, mission_fail_callback: Callable) -> void:
    root = root_node
    player = player_node
    game_state = state
    world_sprite_view = world_sprites
    audio_controller = audio
    message_view = messages
    on_mission_fail = mission_fail_callback

func update(delta: float) -> void:
    var player_pos := Vector2(player.global_position.x, player.global_position.z)
    for name in game_state.squirrels:
        if game_state.stunned.has(name):
            continue
        var node = SceneLookup.mesh_node(root, name)
        if node == null:
            continue
        var home: Vector2 = game_state.squirrel_home[name]
        var dist := home.distance_to(player_pos)
        if SquirrelQuery.should_chase(dist):
            var proposed := SquirrelMotionMath.proposed_position(home, player_pos, delta, 0.45)
            if not WorldCollision.is_wall(proposed.x, proposed.y):
                game_state.squirrel_home[name] = proposed
                node.position.x = proposed.x
                node.position.z = proposed.y
        world_sprite_view.animate_squirrel(node, float(game_state.squirrel_phase[name]))
        if SquirrelAttackQuery.can_attack(dist, game_state.damage_cooldown, LevelData.SQUIRREL_ATTACK_DISTANCE):
            game_state.damage_cooldown = 0.8
            game_state.hp = HealthMath.apply_damage(game_state.hp, 12)
            audio_controller.play_damage()
            set_message(LevelData.DAMAGE_LINES.pick_random(), 1.2)
            if DeathQuery.is_dead(game_state.hp):
                fail()

func is_disabled(name: String) -> bool:
    return game_state.stunned.has(name)

func hit_squirrel(name: String) -> void:
    if name == "" or game_state.stunned.has(name):
        return
    game_state.squirrel_hp[name] = HealthMath.apply_damage(int(game_state.squirrel_hp.get(name, 2)), 1)
    var target = SceneLookup.mesh_node(root, name)
    audio_controller.play_squirrel_hit()
    if int(game_state.squirrel_hp[name]) <= 0:
        game_state.stunned[name] = true
        if target != null:
            world_sprite_view.apply_squirrel_stunned(target)
        set_message(LevelData.STUN_LINES.pick_random(), 2.0)
    else:
        set_message(LevelData.HIT_LINES.pick_random() + "\nЕщё один раз — и белка отдыхает.", 1.4)

func fail() -> void:
    game_state.mission_failed = true
    if on_mission_fail.is_valid():
        on_mission_fail.call()

func set_message(text: String, duration: float) -> void:
    message_view.set_text(text)
    game_state.message_time = duration
