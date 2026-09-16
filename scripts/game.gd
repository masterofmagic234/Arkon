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
    # The old weapon.png is a broken low-detail placeholder. Keep the fire control,
    # but do not render that artifact over the lower-right corner of the screen.
    weapon.visible = false
    knob.position = joystick.size * 0.5 - knob.size * 0.5

    # PlayerController owns the joystick UI input path. Fire remains gameplay-owned.
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
    # AudioController owns all music/SFX routing; game.gd only wires it.

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
    var textures: Array[Texture2D] = [
        load("res://assets/wall_mural_mossy_stone.png"),
        load("res://assets/wall_mural_overgrown.png"),
        load("res://assets/wall_mural_brick_stone.png"),
        load("res://assets/wall_mural_wooden_fence.png"),
        load("res://assets/wall_mural_ruined_temple.png"),
        load("res://assets/wall_mural_autumn.png")
    ]

    # The scene contains decorative 1x1 mural planes stretched across whole
    # corridors. They were causing the long vertical smear visible in-game.
    # Hide those planes and texture the real wall boxes instead.
    var mural_count := 0
    for node in find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := node as MeshInstance3D
        if mesh_instance != null and mesh_instance.name.begins_with("IllustratedWall"):
            mesh_instance.visible = false
            mural_count += 1

    var wall_index := 0
    for node in find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := node as MeshInstance3D
        if mesh_instance == null:
            continue
        var wall_root := mesh_instance.get_parent()
        if wall_root == null or not wall_root.name.begins_with("MapWall"):
            continue
        if mesh_instance.mesh == null:
            continue

        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
        material.cull_mode = BaseMaterial3D.CULL_BACK
        material.roughness = 1.0
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        material.uv1_triplanar = true
        material.uv1_world_triplanar = true
        material.uv1_scale = Vector3(1.0, 1.0, 1.0)
        material.albedo_color = Color(0.9, 0.9, 0.9, 1.0)
        material.albedo_texture = textures[wall_index % textures.size()]
        mesh_instance.material_override = material
        wall_index += 1

    print("ACORN HUNTER: wall boxes textured with triplanar murals: ", wall_index, "; hidden mural planes: ", mural_count)

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
    # Billboard materials handle camera-facing orientation.
    pass

func _refresh_minimap() -> void:
    presentation_sync.sync_minimap(minimap_view, player, game_state.acorns, game_state.squirrels, game_state.stunned)