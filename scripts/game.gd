extends Node3D

# ACORN HUNTER — LEVEL 1
# Rebuilt from the last proven CLEAN/V6 control foundation.
# World sprites are deliberately MeshInstance3D + QuadMesh, not Sprite3D.
# UI owns touch input: joystick.gui_input + Fire.pressed.

const LevelData = preload("res://scripts/level_data.gd")
const HudView = preload("res://scripts/hud_view.gd")
const AudioController = preload("res://scripts/audio_controller.gd")
const MissionView = preload("res://scripts/mission_view.gd")
const CombatFeedbackView = preload("res://scripts/combat_feedback_view.gd")
const MessageView = preload("res://scripts/message_view.gd")
const MinimapView = preload("res://scripts/minimap_view.gd")
const NavigationController = preload("res://scripts/navigation_controller.gd")
const WorldSpriteView = preload("res://scripts/world_sprite_view.gd")
const RuntimeTimers = preload("res://scripts/runtime_timers.gd")
const PresentationSync = preload("res://scripts/presentation_sync.gd")
const PlayerView = preload("res://scripts/player_view.gd")
const MissionStateQuery = preload("res://scripts/mission_state_query.gd")
const GameState = preload("res://scripts/game_state.gd")
const GameplayController = preload("res://scripts/gameplay_controller.gd")
const PlayerController = preload("res://scripts/player_controller.gd")
const EnemyController = preload("res://scripts/enemy_controller.gd")
const PickupController = preload("res://scripts/pickup_controller.gd")
const WallShader = preload("res://shaders/wall_night_masonry.gdshader")

const WallTextures = [
    preload("res://assets/wall_mural_mossy_stone.png"),
    preload("res://assets/wall_mural_overgrown.png"),
    preload("res://assets/wall_mural_brick_stone.png"),
    preload("res://assets/wall_mural_wooden_fence.png"),
    preload("res://assets/wall_mural_ruined_temple.png"),
    preload("res://assets/wall_mural_autumn.png")
]

var game_state = null
var gameplay_controller
var player_controller
var enemy_controller
var pickup_controller
var audio_controller: AudioController
var hud_view: HudView
var mission_view: MissionView
var combat_feedback: CombatFeedbackView
var message_view: MessageView
var minimap_view: MinimapView
var navigation_controller: NavigationController
var world_sprite_view: WorldSpriteView
var runtime_timers: RuntimeTimers
var presentation_sync: PresentationSync
var player_view: PlayerView

@onready var player: CharacterBody3D = $Player
@onready var camera: Camera3D = $Player/Camera3D
@onready var joystick: Panel = $HUD/Joystick
@onready var knob: Panel = $HUD/Joystick/Knob
@onready var fire_button: Button = $HUD/Fire
@onready var mute_button: Button = $HUD/Mute
@onready var count_label: Label = $HUD/Count
@onready var hp_ammo_label: Label = $HUD/HPAmmo
@onready var message_label: Label = $HUD/Message
@onready var mission_panel: Panel = $HUD/Mission
@onready var mission_title: Label = $HUD/Mission/Title
@onready var mission_body: Label = $HUD/Mission/Body
@onready var weapon: TextureRect = $HUD/Weapon
@onready var muzzle: ColorRect = $HUD/MuzzleFlash
@onready var hit_marker: Label = $HUD/HitMarker
@onready var carolina: TextureRect = $HUD/Carolina
@onready var music: AudioStreamPlayer = $Music
@onready var fx: AudioStreamPlayer = $FX

func _ready() -> void:
    game_state = GameState.new()
    game_state.setup(LevelData)
    _apply_illustrated_wall_materials()
    player_view = PlayerView.new()
    player_view.setup(camera, carolina)
    player_view.apply()
    mission_panel.visible = false
    muzzle.visible = false
    hit_marker.visible = false
    weapon.visible = false
    knob.position = joystick.size * 0.5 - knob.size * 0.5

    fire_button.pressed.connect(_on_fire_pressed)
    mute_button.pressed.connect(_toggle_music)

    hud_view = HudView.new()
    hud_view.setup(count_label, hp_ammo_label)

    mission_view = MissionView.new()
    mission_view.setup(mission_panel, mission_title, mission_body, weapon)

    combat_feedback = CombatFeedbackView.new()
    combat_feedback.setup(weapon, muzzle, hit_marker)

    message_view = MessageView.new()
    message_view.setup(message_label)

    minimap_view = $HUD/Minimap as MinimapView

    world_sprite_view = WorldSpriteView.new()
    runtime_timers = RuntimeTimers.new()
    presentation_sync = PresentationSync.new()

    navigation_controller = NavigationController.new()
    navigation_controller.setup($HUD/Mission/Menu, get_tree())

    audio_controller = AudioController.new()
    audio_controller.setup(music, fx)
    audio_controller.start_music()

    player_controller = PlayerController.new()
    player_controller.setup(player, joystick, knob, audio_controller)

    enemy_controller = EnemyController.new()
    enemy_controller.setup(self, player, game_state, world_sprite_view, audio_controller, message_view, Callable(self, "_on_enemy_fail"))

    pickup_controller = PickupController.new()
    pickup_controller.setup(self, player, game_state, world_sprite_view, audio_controller, message_view, mission_view, Callable(self, "_on_pickup_complete"), Callable(self, "_on_pickup_fail"))

    gameplay_controller = GameplayController.new()
    gameplay_controller.setup(self, player, camera, game_state, world_sprite_view, combat_feedback, audio_controller, message_view, mission_view, enemy_controller, pickup_controller, Callable(self, "_on_mission_end"))

    _update_hud()
    _set_message("Парк открыт. Дубы не прячутся — жёлуди тоже.", 4.0)
    _refresh_minimap()

func _apply_illustrated_wall_materials() -> void:
    # The old wall system had two independent visual layers: oversized mural
    # planes plus MapWall boxes. That made it possible for artwork to float,
    # cross passages, or become visually hollow. Replace the concept entirely.
    #
    # The canonical map is now the single source of truth. For every '1' cell
    # we create exactly one solid wall body with matching visual mesh and
    # collision. There are no extra mural planes and no hidden geometry that
    # can accidentally obstruct the player.

    for node in find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := node as MeshInstance3D
        if mesh_instance == null:
            continue
        if mesh_instance.name.begins_with("IllustratedWall"):
            mesh_instance.visible = false
        elif mesh_instance.name == "Mesh" and mesh_instance.get_parent() != null and mesh_instance.get_parent().name.begins_with("MapWall"):
            mesh_instance.visible = false

    for node in find_children("*", "StaticBody3D", true, false):
        var old_wall := node as StaticBody3D
        if old_wall == null or not old_wall.name.begins_with("MapWall"):
            continue
        old_wall.collision_layer = 0
        old_wall.collision_mask = 0

    var old_generated := get_node_or_null("CanonicalWalls")
    if old_generated != null:
        old_generated.queue_free()

    var walls_root := Node3D.new()
    walls_root.name = "CanonicalWalls"
    add_child(walls_root)

    var wall_count := 0
    for row in range(LevelData.MAP_HEIGHT):
        var row_data: String = LevelData.CANONICAL_MAP[row]
        for column in range(LevelData.MAP_WIDTH):
            if row_data[column] != "1":
                continue

            var wall := StaticBody3D.new()
            wall.name = "Wall_%02d_%02d" % [row, column]
            wall.position = Vector3(
                -17.1 + float(column) * LevelData.CELL_SIZE,
                1.3,
                -11.7 + float(row) * LevelData.CELL_SIZE
            )
            wall.collision_layer = LevelData.WORLD_LAYER
            wall.collision_mask = 0
            walls_root.add_child(wall)

            var visual := MeshInstance3D.new()
            visual.name = "Visual"
            var box := BoxMesh.new()
            box.size = Vector3(LevelData.CELL_SIZE, 2.6, LevelData.CELL_SIZE)
            visual.mesh = box

            var style_index := _wall_location_style(wall.position)
            var material := ShaderMaterial.new()
            material.shader = WallShader
            material.set_shader_parameter("wall_texture", WallTextures[style_index])
            visual.material_override = material
            wall.add_child(visual)

            var collision := CollisionShape3D.new()
            collision.name = "Collision"
            var shape := BoxShape3D.new()
            shape.size = Vector3(LevelData.CELL_SIZE, 2.6, LevelData.CELL_SIZE)
            collision.shape = shape
            wall.add_child(collision)

            wall_count += 1

    print("ACORN HUNTER: canonical wall rebuild complete; solid cells=", wall_count)

func _wall_location_style(wall_position: Vector3) -> int:
    var column := clampi(int(round((wall_position.x + 17.1) / 1.8)), 0, 19)
    var row := clampi(int(round((wall_position.z + 11.7) / 1.8)), 0, 13)
    var zone_column := 0 if column <= 6 else (1 if column <= 12 else 2)
    var zone_row := 0 if row <= 6 else 1
    return zone_row * 3 + zone_column

func _physics_process(delta: float) -> void:
    if MissionStateQuery.is_finished(game_state.mission_complete, game_state.mission_failed):
        player_controller.stop()
        return

    game_state.foot_timer = player_controller.update(delta, game_state.foot_timer)

    var timers := runtime_timers.tick(delta, {
        "fire_cooldown": game_state.fire_cooldown,
        "damage_cooldown": game_state.damage_cooldown,
        "recoil_time": game_state.recoil_time,
        "message_time": game_state.message_time
    })
    game_state.fire_cooldown = timers["fire_cooldown"]
    game_state.damage_cooldown = timers["damage_cooldown"]
    game_state.recoil_time = timers["recoil_time"]
    game_state.message_time = timers["message_time"]

    if game_state.message_time <= 0.0:
        message_view.clear()
    if game_state.recoil_time <= 0.0:
        combat_feedback.set_idle_weapon()
    combat_feedback.update_muzzle(delta)

    gameplay_controller.update(delta)
    _update_hud()
    _refresh_minimap()

func _on_fire_pressed() -> void:
    gameplay_controller.handle_fire()

func _on_mission_end() -> void:
    player_controller.stop()

func _on_enemy_fail() -> void:
    gameplay_controller.fail()

func _on_pickup_complete() -> void:
    player_controller.stop()

func _on_pickup_fail() -> void:
    gameplay_controller.fail()

func _update_hud() -> void:
    presentation_sync.sync_hud(hud_view, game_state.collected, LevelData.ACORN_COUNT, game_state.hp, game_state.ammo)

func _set_message(text: String, duration: float) -> void:
    message_view.set_text(text)
    game_state.message_time = duration

func _toggle_music() -> void:
    var is_muted := audio_controller.toggle_music()
    mute_button.text = "×" if is_muted else "♪"
    _set_message("Музыка выключена." if is_muted else "Музыка возвращена. Белки снова слышат угрозу.", 1.6)

func _face_world_sprites() -> void:
    pass

func _refresh_minimap() -> void:
    presentation_sync.sync_minimap(minimap_view, player, game_state.acorns, game_state.squirrels, game_state.stunned)
